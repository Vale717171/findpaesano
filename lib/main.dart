import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'onboarding_screen.dart';
import 'settings_screen.dart';
import 'board_screen.dart';
import 'radar_screen.dart';
import 'chat_screen.dart';
import 'app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  final prefs = await SharedPreferences.getInstance();
  final savedTheme = prefs.getString('themeMode') ?? 'system';
  themeNotifier.value = savedTheme == 'dark'
      ? ThemeMode.dark
      : savedTheme == 'light'
          ? ThemeMode.light
          : ThemeMode.system;

  runApp(const FindPaesanoApp());
}

final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

class FindPaesanoApp extends StatefulWidget {
  const FindPaesanoApp({super.key});

  @override
  State<FindPaesanoApp> createState() => _FindPaesanoAppState();
}

class _FindPaesanoAppState extends State<FindPaesanoApp> {
  bool _nonEssentialInitStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_nonEssentialInitStarted) return;
    _nonEssentialInitStarted = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeNonEssentialServices();
    });
  }

  Future<void> _initializeNonEssentialServices() async {
    // Keep the first frame cheap: ads can load after the app is already
    // visible. Theme restoration happens before runApp() to avoid a startup
    // flicker when the user explicitly chose light or dark mode.
    unawaited(MobileAds.instance.initialize());
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'FlagPost',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),
          routes: {
            '/home': (context) => const MainScreen(),
          },
          home: const _AppBootstrapScreen(),
        );
      },
    );
  }
}

class _AppBootstrapScreen extends StatefulWidget {
  const _AppBootstrapScreen();

  @override
  State<_AppBootstrapScreen> createState() => _AppBootstrapScreenState();
}

class _AppBootstrapScreenState extends State<_AppBootstrapScreen> {
  User? _user;
  bool _authResolved = false;
  bool _profileResolved = false;
  bool _hasCompletedProfile = false;
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;
      setState(() {
        _user = user;
        _authResolved = true;
        _profileResolved = user == null;
        _hasCompletedProfile = false;
      });

      if (user != null) {
        _loadUserProfile(user.uid);
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadUserProfile(String uid) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = snapshot.data();
      final nickname = data?['nickname'] as String? ?? '';

      if (!mounted || _user?.uid != uid) return;
      setState(() {
        _profileResolved = true;
        _hasCompletedProfile = nickname.isNotEmpty;
      });
    } catch (_) {
      if (!mounted || _user?.uid != uid) return;
      setState(() {
        _profileResolved = true;
        _hasCompletedProfile = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_authResolved) {
      return const _AppLaunchScreen();
    }

    if (_user == null) {
      return const OnboardingScreen();
    }

    if (!_profileResolved) {
      return const _AppLaunchScreen(
        message: 'Loading your notes…',
      );
    }

    return _hasCompletedProfile
        ? const MainScreen()
        : const OnboardingScreen();
  }
}

class _AppLaunchScreen extends StatelessWidget {
  final String message;

  const _AppLaunchScreen({
    this.message = 'Getting your notebook ready…',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: AppTheme.travelBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(
                    child: Image.asset('assets/icon.png', height: 46),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'FlagPost',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.mutedInk,
                  ),
                ),
                const SizedBox(height: 20),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  Widget? _radarScreen;
  Widget? _chatScreen;

  // 0 = Board, 1 = Nearby, 2 = Chat
  // Initialize RadarScreen lazily to avoid requesting GPS at startup.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.travelBlue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Image.asset('assets/icon.png', height: 24),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('FlagPost'),
                  Text(
                    'Local notes before local mistakes',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.mutedInk,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          const BoardScreen(),
          _radarScreen ?? const SizedBox.shrink(),
          _chatScreen ?? const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Badge: conta i segnali in arrivo e lo mostra sull'icona Chat
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseAuth.instance.currentUser != null
                ? FirebaseFirestore.instance
                    .collection('chatRequests')
                    .where('toUid',
                        isEqualTo:
                            FirebaseAuth.instance.currentUser!.uid)
                    .where('status', isEqualTo: 'pending')
                    .snapshots()
                : const Stream.empty(),
            builder: (context, snapshot) {
              final pendingCount =
                  snapshot.data?.docs.length ?? 0;
              return NavigationBar(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (index) {
                  if (index == 1) {
                    _radarScreen ??= const RadarScreen();
                  } else if (index == 2) {
                    _chatScreen ??= const ChatScreen();
                  }
                  setState(() => _selectedIndex = index);
                },
                destinations: [
                  const NavigationDestination(
                    icon: Icon(Icons.forum),
                    label: 'Boards',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.radar),
                    label: 'Nearby',
                  ),
                  NavigationDestination(
                    icon: pendingCount > 0
                        ? Badge(
                            label: Text('$pendingCount'),
                            child: const Icon(Icons.chat),
                          )
                        : const Icon(Icons.chat),
                    label: 'Chat',
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
