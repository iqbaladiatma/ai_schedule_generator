// lib/ui/home_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ai_schedule_generator/services/gemini_service.dart';
import 'package:ai_schedule_generator/auth/google_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_web/web_only.dart' as web
    if (dart.library.io) 'package:google_sign_in/google_sign_in.dart';
import 'dart:ui';

import 'schedule_result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  GoogleSignInAccount? _currentUser;

  final List<Map<String, dynamic>> tasks = [];
  final TextEditingController taskController = TextEditingController();
  final TextEditingController durationController = TextEditingController();
  String? priority;
  bool isLoading = false;

  late AnimationController _fabController;
  late Animation<double> _fabScale;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fabScale = CurvedAnimation(
      parent: _fabController,
      curve: Curves.easeOutBack,
    );

    googleSignIn.onCurrentUserChanged.listen((account) {
      if (mounted) {
        setState(() => _currentUser = account);
      }
    });
    
    // Attempt silent sign in but catch errors
    googleSignIn.signInSilently(suppressErrors: true).then((account) {
      if (account != null && mounted) {
        setState(() => _currentUser = account);
      }
    }).catchError((error) {
      debugPrint("Silent sign-in error: $error");
      return null;
    });

    _fabController.forward();
  }

  @override
  void dispose() {
    taskController.dispose();
    durationController.dispose();
    _fabController.dispose();
    super.dispose();
  }

  void _addTask() {
    if (taskController.text.isNotEmpty &&
        durationController.text.isNotEmpty &&
        priority != null) {
      setState(() {
        tasks.add({
          "name": taskController.text,
          "priority": priority!,
          "duration": int.tryParse(durationController.text) ?? 30,
        });
      });
      taskController.clear();
      durationController.clear();
      setState(() => priority = null);

      // Haptic feedback
      HapticFeedback.lightImpact();
    }
  }

  void _generateSchedule() async {
    if (tasks.isEmpty) {
      _showSnackBar("⚠ Harap tambahkan tugas dulu!", isError: true);
      return;
    }
    setState(() => isLoading = true);
    try {
      String schedule = await GeminiService.generateSchedule(tasks);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ScheduleResultScreen(scheduleResult: schedule),
        ),
      );
    } catch (e) {
      _showSnackBar("Error: $e", isError: true);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          // Gradient background
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 300,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF6366F1),
                    Color(0xFF8B5CF6),
                    Color(0xFFA855F7),
                  ],
                ),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 16),
                // Header section
                _buildHeader(),
                const SizedBox(height: 24),
                // Input form
                _buildInputForm(),
                const SizedBox(height: 16),
                // Task list
                Expanded(child: _buildTaskList()),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabScale,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Color(0xFF6366F1).withAlpha(60),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: FloatingActionButton.extended(
            onPressed: isLoading ? null : _generateSchedule,
            backgroundColor: Colors.transparent,
            elevation: 0,
            icon: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.auto_awesome, color: Colors.white),
            label: Text(
              isLoading ? "Memproses..." : "Buat Jadwal AI",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: const Text(
        'AI Schedule Generator',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
        if (_currentUser == null)
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.login, color: Colors.white),
              tooltip: 'Login dengan Google',
              onPressed: () async {
                if (kIsWeb) {
                  // On web, show a dialog with Google renderButton
                  _showGoogleSignInDialog();
                } else {
                  final account = await signInWithGoogle();
                  if (!context.mounted) return;
                  if (account == null) {
                    _showSnackBar('Login dibatalkan', isError: true);
                    return;
                  }
                  _showSnackBar('Halo, ${account.displayName ?? account.email}');
                }
              },
            ),
          )
        else
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: PopupMenuButton<String>(
              icon: CircleAvatar(
                backgroundColor: Colors.white,
                radius: 16,
                child: _currentUser!.photoUrl != null
                    ? ClipOval(
                        child: Image.network(
                          _currentUser!.photoUrl!,
                          width: 32,
                          height: 32,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.person, color: Color(0xFF6366F1), size: 20);
                          },
                        ),
                      )
                    : const Icon(Icons.person, color: Color(0xFF6366F1), size: 20),
              ),
              onSelected: (value) async {
                if (value == 'logout') await signOutFromGoogle();
              },
              itemBuilder: (context) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentUser!.displayName ?? 'Pengguna',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        _currentUser!.email ?? '',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Color(0xFFEF4444), size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Logout',
                        style: TextStyle(color: Color(0xFFEF4444)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(25),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.schedule,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Selamat Datang!',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Buat Jadwal Optimalmu',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withAlpha(40),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.lightbulb_outline,
                  color: Colors.amber,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tambahkan tugas dengan prioritas, lalu AI akan menyusun jadwal optimal untukmu.',
                    style: TextStyle(
                      color: Colors.white.withAlpha(230),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputForm() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withAlpha(20),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.add_task,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Tambah Tugas Baru',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: taskController,
                  decoration: InputDecoration(
                    labelText: "Nama Tugas",
                    hintText: 'Contoh: Rapat tim, Olahraga, Belajar...',
                    prefixIcon: Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.task_alt,
                        size: 18,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: durationController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: "Durasi",
                          hintText: 'Menit',
                          prefixIcon: Container(
                            margin: const EdgeInsets.all(12),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withAlpha(20),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.timer_outlined,
                              size: 18,
                              color: Color(0xFF8B5CF6),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: _buildPrioritySelector(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _addTask,
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text(
                      "Tambah ke Daftar",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrioritySelector() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonFormField<String>(
        value: priority,
        decoration: InputDecoration(
          labelText: "Prioritas",
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _getPriorityColor().withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.flag,
              size: 18,
              color: _getPriorityColor(),
            ),
          ),
        ),
        items: [
          _buildPriorityItem("Tinggi", const Color(0xFFEF4444), Icons.priority_high),
          _buildPriorityItem("Sedang", const Color(0xFFF59E0B), Icons.flag),
          _buildPriorityItem("Rendah", const Color(0xFF10B981), Icons.low_priority),
        ],
        onChanged: (val) => setState(() => priority = val),
        icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
        dropdownColor: Colors.white,
      ),
    );
  }

  Color _getPriorityColor() {
    if (priority == "Tinggi") return const Color(0xFFEF4444);
    if (priority == "Sedang") return const Color(0xFFF59E0B);
    if (priority == "Rendah") return const Color(0xFF10B981);
    return const Color(0xFF64748B);
  }

  DropdownMenuItem<String> _buildPriorityItem(
      String label, Color color, IconData icon) {
    return DropdownMenuItem(
      value: label,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList() {
    if (tasks.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Daftar Tugas',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withAlpha(15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${tasks.length} tugas',
                  style: const TextStyle(
                    color: Color(0xFF6366F1),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return _buildTaskItem(task, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTaskItem(Map<String, dynamic> task, int index) {
    final color = _getColorForPriority(task['priority']);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: Key('${task['name']}_$index'),
        direction: DismissDirection.endToStart,
        background: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_outline, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Hapus',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        onDismissed: (_) {
          setState(() => tasks.removeAt(index));
          HapticFeedback.lightImpact();
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withAlpha(20),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: color.withAlpha(30),
              width: 1,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withAlpha(180)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: color.withAlpha(40),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  task['name'][0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            title: Text(
              task['name'],
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: Color(0xFF1E293B),
              ),
            ),
            subtitle: Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 14,
                  color: const Color(0xFF64748B),
                ),
                const SizedBox(width: 4),
                Text(
                  '${task['duration']} menit',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withAlpha(15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    task['priority'],
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            trailing: IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: const Color(0xFFEF4444).withAlpha(150),
              ),
              onPressed: () {
                setState(() => tasks.removeAt(index));
                HapticFeedback.lightImpact();
              },
            ),
          ),
        ),
      ),
    );
  }

  Color _getColorForPriority(String priority) {
    if (priority == "Tinggi") return const Color(0xFFEF4444);
    if (priority == "Sedang") return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }

  void _showGoogleSignInDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        // Listen for successful sign-in to auto-close dialog
        final subscription = googleSignIn.onCurrentUserChanged.listen((account) {
          if (account != null && Navigator.of(dialogContext).canPop()) {
            Navigator.of(dialogContext).pop();
            _showSnackBar('Halo, ${account.displayName ?? account.email}');
          }
        });

        return WillPopScope(
          onWillPop: () async {
            subscription.cancel();
            return true;
          },
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.login,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Login dengan Google',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Klik tombol di bawah untuk login dengan akun Google Anda.',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                // Official Google Sign-In renderButton widget
                _buildGoogleRenderButton(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGoogleRenderButton() {
    // Use the official Google Identity Services renderButton from google_sign_in_web
    // This renders the official Google-hosted sign-in button widget
    // without using the deprecated popup-based signIn() method.
    if (kIsWeb) {
      return web.renderButton(
        configuration: web.GSIButtonConfiguration(
          type: web.GSIButtonType.standard,
          theme: web.GSIButtonTheme.outline,
          size: web.GSIButtonSize.large,
          text: web.GSIButtonText.signinWith,
          shape: web.GSIButtonShape.rectangular,
          minimumWidth: 280,
        ),
      );
    }
    // Fallback for non-web (should not reach here)
    return const SizedBox.shrink();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF6366F1).withAlpha(20),
                  const Color(0xFF8B5CF6).withAlpha(10),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Icon(
              Icons.inbox_outlined,
              size: 50,
              color: Color(0xFF6366F1),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Belum ada tugas',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tambahkan tugas pertama Anda\ndi atas untuk memulai!',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}