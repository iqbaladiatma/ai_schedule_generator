import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:ai_schedule_generator/auth/google_auth.dart';

class ScheduleResultScreen extends StatefulWidget {
  final String scheduleResult;
  const ScheduleResultScreen({super.key, required this.scheduleResult});

  @override
  State<ScheduleResultScreen> createState() => _ScheduleResultScreenState();
}

class _ScheduleResultScreenState extends State<ScheduleResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('=== RAW SCHEDULE RESULT ===');
    debugPrint(widget.scheduleResult);

    final sections = _splitScheduleAndTips(widget.scheduleResult);
    final scheduleSection = sections.$1;
    final tipsSection = sections.$2;

    debugPrint('=== SCHEDULE SECTION ===');
    debugPrint(scheduleSection);
    if (scheduleSection.isEmpty) debugPrint('WARNING: scheduleSection is EMPTY');
    debugPrint('=== TIPS SECTION ===');
    debugPrint(tipsSection);
    if (tipsSection.isEmpty) debugPrint('WARNING: tipsSection is EMPTY');

    return Scaffold(
      backgroundColor: const Color(0xFFF0F7FF),
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          // Gradient header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 260,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1E3A8A),
                    Color(0xFF2563EB),
                    Color(0xFF3B82F6),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -20,
                    right: -30,
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withAlpha(10),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 30,
                    left: -20,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withAlpha(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Curved bottom
          Positioned(
            top: 230,
            left: 0,
            right: 0,
            child: Container(
              height: 50,
              decoration: const BoxDecoration(
                color: Color(0xFFF0F7FF),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    // Info card
                    _buildInfoCard(),
                    const SizedBox(height: 16),
                    // Main content
                    Expanded(
                      child: _buildContentCards(scheduleSection, tipsSection),
                    ),
                    const SizedBox(height: 16),
                    // Action buttons
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withAlpha(30),
          ),
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.event_note_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Hasil Jadwal',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withAlpha(30),
            ),
          ),
          child: IconButton(
            icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 20),
            tooltip: "Salin Semua Teks",
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.scheduleResult));
              _showSnackBar('Semua teks berhasil disalin!');
            },
          ),
        ),
        Container(
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withAlpha(30),
            ),
          ),
          child: IconButton(
            icon: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 20),
            tooltip: "Ekspor ke Google Calendar",
            onPressed: () async {
              final sections = _splitScheduleAndTips(widget.scheduleResult);
              await _ensureLoggedInAndExport(sections.$1);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withAlpha(15),
            Colors.white.withAlpha(8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withAlpha(25),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.amber,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Jadwal & tips disusun otomatis oleh AI berdasarkan prioritas Anda.",
              style: TextStyle(
                color: Colors.white.withAlpha(220),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentCards(String scheduleSection, String tipsSection) {
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: _buildScheduleCard(scheduleSection),
        ),
        const SizedBox(height: 14),
        if (tipsSection.trim().isNotEmpty)
          Expanded(
            flex: 2,
            child: _buildTipsCard(tipsSection),
          ),
      ],
    );
  }

  Widget _buildScheduleCard(String scheduleSection) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withAlpha(10),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF2563EB).withAlpha(12),
                    const Color(0xFF3B82F6).withAlpha(6),
                  ],
                ),
                border: const Border(
                  bottom: BorderSide(
                    color: Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.schedule_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Jadwal Optimal',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withAlpha(15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 12, color: Color(0xFF10B981)),
                        SizedBox(width: 4),
                        Text(
                          'AI Generated',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: MarkdownBody(
                  data: scheduleSection.isEmpty ? "_Tidak ada data jadwal_" : scheduleSection,
                  selectable: true,
                  styleSheet: _markdownStyleSheet(),
                  builders: {'table': TableBuilder()},
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipsCard(String tipsSection) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withAlpha(10),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFF59E0B).withAlpha(12),
                    const Color(0xFFFBBF24).withAlpha(5),
                  ],
                ),
                border: const Border(
                  bottom: BorderSide(
                    color: Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.lightbulb_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Tips Produktif',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: MarkdownBody(
                  data: tipsSection.isEmpty ? "_Tidak ada tips tersedia_" : tipsSection,
                  selectable: true,
                  styleSheet: _markdownStyleSheet(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text(
              "Buat Ulang",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withAlpha(60),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () async {
                final sections = _splitScheduleAndTips(widget.scheduleResult);
                await _ensureLoggedInAndExport(sections.$1);
              },
              icon: const Icon(Icons.calendar_month_rounded, size: 18),
              label: const Text(
                "Export ke Calendar",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  MarkdownStyleSheet _markdownStyleSheet() {
    return MarkdownStyleSheet(
      p: const TextStyle(
        fontSize: 15,
        height: 1.7,
        color: Color(0xFF475569),
      ),
      h1: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: Color(0xFF0F172A),
        letterSpacing: -0.5,
      ),
      h2: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: Color(0xFF0F172A),
        letterSpacing: -0.3,
      ),
      h3: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Color(0xFF2563EB),
      ),
      tableBorder: TableBorder.all(
        color: const Color(0xFFE2E8F0),
        width: 1,
        borderRadius: BorderRadius.circular(8),
      ),
      tableHeadAlign: TextAlign.center,
      tablePadding: const EdgeInsets.all(12),
      tableCellsDecoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
      ),
      tableColumnWidth: const FlexColumnWidth(),
      strong: const TextStyle(
        fontWeight: FontWeight.w700,
        color: Color(0xFF0F172A),
      ),
      em: const TextStyle(
        fontStyle: FontStyle.italic,
        color: Color(0xFF64748B),
      ),
      listBullet: const TextStyle(
        color: Color(0xFF2563EB),
      ),
      blockquote: const TextStyle(
        color: Color(0xFF64748B),
        fontStyle: FontStyle.italic,
      ),
      blockquoteDecoration: const BoxDecoration(
        border: Border(
          left: BorderSide(
            color: Color(0xFF2563EB),
            width: 4,
          ),
        ),
      ),
      code: TextStyle(
        backgroundColor: const Color(0xFFF0F4FF),
        color: const Color(0xFF2563EB),
        fontSize: 13,
        fontFamily: 'monospace',
      ),
    );
  }

  Future<void> _ensureLoggedInAndExport(String markdownSchedule) async {
    try {
      if (markdownSchedule.trim().isEmpty) {
        _showSnackBar('Belum ada jadwal yang bisa diekspor.', isError: true);
        return;
      }

      var user = googleSignIn.currentUser;
      user ??= await googleSignIn.signInSilently(suppressErrors: true);
      if (user == null) {
        user = await signInWithGoogle();
        if (user == null) {
          if (mounted) _showSnackBar('Login diperlukan untuk ekspor', isError: true);
          return;
        }
      }

      // Check if we already have the calendar scope
      final bool alreadyHasScopes = await googleSignIn.canAccessScopes([
        'https://www.googleapis.com/auth/calendar',
      ]);

      if (!alreadyHasScopes) {
        try {
          final bool isAuthorized = await googleSignIn.requestScopes([
            'https://www.googleapis.com/auth/calendar',
          ]);

          if (!isAuthorized) {
            if (mounted) {
              _showSnackBar('Izin akses ke Google Calendar diperlukan', isError: true);
            }
            return;
          }
        } catch (e) {
          final errorStr = e.toString().toLowerCase();
          if (errorStr.contains('popup_closed') || errorStr.contains('popup')) {
            if (mounted) {
              _showSnackBar(
                'Popup izin diblokir browser. Coba izinkan popup atau restart app.',
                isError: true,
              );
            }
            return;
          }
          rethrow;
        }
      }

      final client = await googleSignIn.authenticatedClient();

      if (client == null) {
        if (mounted) {
          _showSnackBar('Gagal mendapatkan Client Autentikasi. Coba logout lalu login ulang.', isError: true);
        }
        return;
      }

      final calendarApi = gcal.CalendarApi(client);
      final events = _parseMarkdownToEvents(markdownSchedule);

      if (events.isEmpty) {
        if (mounted) _showSnackBar('Tidak ada baris jadwal yang dikenali', isError: true);
        return;
      }

      if (mounted) _showSnackBar('Mengekspor ${events.length} event...');

      int successCount = 0;
      for (final event in events) {
        try {
          await calendarApi.events.insert(event, 'primary');
          successCount++;
        } catch (e) {
          debugPrint('Failed to insert event: $e');
        }
      }

      if (mounted) {
        if (successCount > 0) {
          _showSnackBar('✅ Berhasil ekspor $successCount event ke Calendar');
        } else {
          _showSnackBar('Gagal mengekspor event ke Calendar', isError: true);
        }
      }
    } catch (e) {
      debugPrint('Export error: $e');
      if (mounted) _showSnackBar('Gagal ekspor ke Calendar: $e', isError: true);
    }
  }

  List<gcal.Event> _parseMarkdownToEvents(String markdown) {
    final lines = markdown.split('\n');
    final List<gcal.Event> events = [];
    final today = DateTime.now();
    const String timeZone = 'Asia/Jakarta';

    debugPrint('=== PARSING EVENTS ===');
    debugPrint('Today: ${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}');

    for (final rawLine in lines) {
      var line = rawLine.trim();
      if (line.isEmpty) continue;
      if (!line.startsWith('|')) continue;
      if (line.contains(':---') || line.contains('---:')) continue;
      if (line.contains('Waktu') && line.contains('Kegiatan')) continue;

      if (line.startsWith('|')) line = line.substring(1);
      if (line.endsWith('|')) line = line.substring(0, line.length - 1);

      final cols = line.split('|').map((c) => c.trim()).toList();
      if (cols.length < 2) continue;

      final timePart = cols[0];
      final titlePart = cols[1];
      final descPart = cols.length >= 3 ? cols[2] : '';

      if (!timePart.contains('-')) continue;

      final timeRange = timePart.split('-');
      if (timeRange.length != 2) continue;

      try {
        final startStr = timeRange[0].trim();
        final endStr = timeRange[1].trim();

        final startHour = int.parse(startStr.split(':')[0]);
        final startMin = int.parse(startStr.split(':')[1]);
        final endHour = int.parse(endStr.split(':')[0]);
        final endMin = int.parse(endStr.split(':')[1]);

        final startDateTime = DateTime(
          today.year, today.month, today.day, startHour, startMin,
        );
        final endDateTime = DateTime(
          today.year, today.month, today.day, endHour, endMin,
        );

        debugPrint('Event: $titlePart | $startHour:$startMin - $endHour:$endMin | $descPart');

        final event = gcal.Event(
          summary: titlePart,
          description: descPart.isNotEmpty
              ? '$descPart\n\n📅 Dibuat oleh AI Schedule Generator'
              : '📅 Dibuat oleh AI Schedule Generator',
          start: gcal.EventDateTime(
            dateTime: startDateTime,
            timeZone: timeZone,
          ),
          end: gcal.EventDateTime(
            dateTime: endDateTime,
            timeZone: timeZone,
          ),
          colorId: '9',
        );
        events.add(event);
      } catch (_) {
        continue;
      }
    }

    debugPrint('Total events parsed: ${events.length}');
    return events;
  }

  (String, String) _splitScheduleAndTips(String fullText) {
    final lower = fullText.toLowerCase();
    const scheduleMarker = '## jadwal untuk kalender';
    const tipsMarker = '## tips produktif';

    final idxSchedule = lower.indexOf(scheduleMarker);
    if (idxSchedule == -1) {
      return (fullText.trim(), '');
    }

    final idxTips = lower.indexOf(tipsMarker, idxSchedule);
    if (idxTips == -1) {
      final scheduleSection = fullText.substring(idxSchedule).trim();
      return (scheduleSection, '');
    }

    final scheduleSection = fullText.substring(idxSchedule, idxTips).trim();
    final tipsSection = fullText.substring(idxTips).trim();
    return (scheduleSection, tipsSection);
  }
}

class TableBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    dynamic element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    return null;
  }
}
