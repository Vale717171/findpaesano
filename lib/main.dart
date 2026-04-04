import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'onboarding_screen.dart';
import 'settings_screen.dart';
import 'board_screen.dart';
import 'radar_screen.dart';
import 'chat_screen.dart';
import 'ad_banner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await MobileAds.instance.initialize();

  // Carica il tema salvato dall'utente
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

class FindPaesanoApp extends StatelessWidget {
  const FindPaesanoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'FlagPost',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF2196F3),
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF2196F3),
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          routes: {
            '/home': (context) => const MainScreen(),
          },
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasData) {
                return const MainScreen();
              }
              return const OnboardingScreen();
            },
          ),
        );
      },
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

  // IndexedStack mantiene tutti gli schermi in memoria:
  // - lo stato non si perde quando cambi tab
  // - RadarScreen non ri-richiede il GPS ogni volta
  final List<Widget> _screens = [
    const RadarScreen(),
    const BoardScreen(),
    const ChatScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/icon.png', height: 32),
            const SizedBox(width: 8),
            const Text('FlagPost'),
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
        children: _screens,
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AdBanner(),
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
                  setState(() => _selectedIndex = index);
                },
                destinations: [
                  const NavigationDestination(
                    icon: Icon(Icons.radar),
                    label: 'Radar',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.forum),
                    label: 'Board',
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
