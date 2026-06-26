import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase/client.dart';
import 'screens/home_screen.dart';
import 'screens/tasks_screen.dart';
import 'screens/finance_screen.dart';
import 'screens/goals_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/chat_screen.dart';
import 'theme/app_theme.dart';
import 'theme/app_settings.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.instance.initialize();
  runApp(const LifeSyncApp());
}

class LifeSyncApp extends StatelessWidget {
  const LifeSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    return ListenableBuilder(
      listenable: MultiListenable([
        settings.fontStyle,
        settings.language,
        settings.currency,
        settings.metricSystem,
      ]),
      builder: (context, _) {
        return MaterialApp(
          title: 'LifeSync',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.theme,
          home: const AuthGate(),
        );
      },
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checking = true;
  bool _authFailed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() { _checking = true; _authFailed = false; });

    // If already signed in, proceed immediately
    final existingSession = Supabase.instance.client.auth.currentSession;
    if (existingSession != null && Supabase.instance.client.auth.currentUser != null) {
      setState(() { _checking = false; });
      return;
    }

    // Try anonymous sign-in (requires "Anonymous sign-ins" enabled in Supabase dashboard)
    // If it fails, proceed anyway — screens handle missing auth gracefully
    try {
      await Supabase.instance.client.auth.signInAnonymously();
    } catch (_) {
      // Anonymous auth not enabled or network error — proceed to main screen
      // User can still see the UI; write operations will silently fail
    }
    setState(() { _checking = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: Color(0xFFf7f7f4),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_authFailed) {
      return Scaffold(
        backgroundColor: const Color(0xFFf7f7f4),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off_rounded, size: 56, color: Color(0xFF9CA3AF)),
                const SizedBox(height: 16),
                const Text('Connection Error',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1a1a1a))),
                const SizedBox(height: 8),
                const Text('Could not connect to server.\nCheck your internet connection.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF9CA3AF))),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _init,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.highlight),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return const MainScreen();
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  int _financeRefresh = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      const HomeScreen(),
      const CalendarScreen(),
      const TasksScreen(),
      FinanceScreen(key: ValueKey('finance_$_financeRefresh')),
      const GoalsScreen(),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _currentIndex,
          children: screens,
        ),
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChatScreen()),
              ),
              backgroundColor: AppTheme.highlight,
              child: const Icon(Icons.auto_awesome, color: Colors.white),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() {
          _currentIndex = i;
          if (i == 3) _financeRefresh++;
        }),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month_outlined), activeIcon: Icon(Icons.calendar_month), label: 'Calendar'),
          BottomNavigationBarItem(icon: Icon(Icons.check_box_outlined), activeIcon: Icon(Icons.check_box), label: 'Tasks'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), activeIcon: Icon(Icons.account_balance_wallet), label: 'Finance'),
          BottomNavigationBarItem(icon: Icon(Icons.track_changes_outlined), activeIcon: Icon(Icons.track_changes), label: 'Goals'),
        ],
      ),
    );
  }
}
