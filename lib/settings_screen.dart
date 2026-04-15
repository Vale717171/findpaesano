import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'main.dart';
import 'edit_profile_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _saveTheme(ThemeMode mode) async {
    themeNotifier.value = mode;
    final prefs = await SharedPreferences.getInstance();
    final key = mode == ThemeMode.dark
        ? 'dark'
        : mode == ThemeMode.light
            ? 'light'
            : 'system';
    await prefs.setString('themeMode', key);
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account'),
        content: const Text(
          'Are you sure? All your data will be permanently deleted. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Deleting your account...'),
            ],
          ),
        ),
      );
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final uid = user.uid;

      // ── STEP 1: delete the Firebase Auth account first ──────────────
      // If this fails with requires-recent-login we stop here — no
      // Firestore data has been touched yet, so the account is intact.
      try {
        await user.delete();
      } on FirebaseAuthException catch (e) {
        if (context.mounted) Navigator.of(context).pop(); // close spinner
        if (e.code == 'requires-recent-login') {
          // Sign the user out so they can re-authenticate, then retry.
          await FirebaseAuth.instance.signOut();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Please sign in again to confirm account deletion.',
                ),
              ),
            );
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ${e.message}')),
            );
          }
        }
        return; // abort — Firestore data is untouched
      }

      // ── STEP 2: Auth account deleted — now clean up Firestore ────────
      final allRefs = <DocumentReference>[];

      final messages = await FirebaseFirestore.instance
          .collection('messages')
          .where('authorUid', isEqualTo: uid)
          .get();
      allRefs.addAll(messages.docs.map((d) => d.reference));

      final sentRequests = await FirebaseFirestore.instance
          .collection('chatRequests')
          .where('fromUid', isEqualTo: uid)
          .get();
      allRefs.addAll(sentRequests.docs.map((d) => d.reference));

      final receivedRequests = await FirebaseFirestore.instance
          .collection('chatRequests')
          .where('toUid', isEqualTo: uid)
          .get();
      allRefs.addAll(receivedRequests.docs.map((d) => d.reference));

      final chats = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: uid)
          .get();
      for (final chatDoc in chats.docs) {
        allRefs.add(chatDoc.reference);
        final chatMessages =
            await chatDoc.reference.collection('messages').get();
        allRefs.addAll(chatMessages.docs.map((d) => d.reference));
      }

      final blockedUsers = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('blockedUsers')
          .get();
      allRefs.addAll(blockedUsers.docs.map((d) => d.reference));

      for (int i = 0; i < allRefs.length; i += 400) {
        final batch = FirebaseFirestore.instance.batch();
        final chunk =
            allRefs.sublist(i, min(i + 400, allRefs.length));
        for (final ref in chunk) {
          batch.delete(ref);
        }
        await batch.commit();
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .delete();

      // Chiude il dialog di caricamento
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _openBuyMeACoffee() async {
    final uri = Uri.parse('https://buymeacoffee.com/vale71');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // ── PROFILO ──────────────────────────────────
          _SectionHeader('Profile'),

          // Mostra i dati reali dell'utente (non l'UID grezzo)
          StreamBuilder<DocumentSnapshot>(
            stream: uid != null
                ? FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .snapshots()
                : const Stream.empty(),
            builder: (context, snapshot) {
              final data =
                  snapshot.data?.data() as Map<String, dynamic>?;
              final flag = data?['countryFlag'] ?? '🌍';
              final nickname = data?['nickname'] ?? '...';
              final country = data?['countryName'] ?? '';
              final status = data?['travelStatus'];
              final destination = data?['destination'] as String?;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.grey[100],
                  child: Text(flag,
                      style: const TextStyle(fontSize: 22)),
                ),
                title: Text(
                  nickname,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  status == 'planning' &&
                          (destination?.isNotEmpty ?? false)
                      ? '$country · Planning → $destination'
                      : country,
                ),
                trailing: TextButton(
                  onPressed: data == null
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  EditProfileScreen(userData: data),
                            ),
                          ),
                  child: const Text('Edit'),
                ),
              );
            },
          ),

          const Divider(),

          // ── ASPETTO ───────────────────────────────────
          _SectionHeader('Appearance'),

          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeNotifier,
            builder: (context, themeMode, _) {
              return ListTile(
                leading: Icon(
                  themeMode == ThemeMode.dark
                      ? Icons.dark_mode
                      : themeMode == ThemeMode.light
                          ? Icons.light_mode
                          : Icons.brightness_auto,
                ),
                title: const Text('Theme'),
                subtitle: Text(
                  themeMode == ThemeMode.dark
                      ? 'Dark'
                      : themeMode == ThemeMode.light
                          ? 'Light'
                          : 'System default',
                ),
                onTap: () => showModalBottomSheet(
                  context: context,
                  builder: (context) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading:
                            const Icon(Icons.brightness_auto),
                        title: const Text('System default'),
                        onTap: () {
                          _saveTheme(ThemeMode.system);
                          Navigator.pop(context);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.light_mode),
                        title: const Text('Light'),
                        onTap: () {
                          _saveTheme(ThemeMode.light);
                          Navigator.pop(context);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.dark_mode),
                        title: const Text('Dark'),
                        onTap: () {
                          _saveTheme(ThemeMode.dark);
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const Divider(),

          // ── PRIVACY ───────────────────────────────────
          _SectionHeader('Privacy'),

          ListTile(
            leading: const Icon(Icons.block),
            title: const Text('Blocked users'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const BlockedUsersScreen()),
            ),
          ),

          const Divider(),

          // ── SUPPORTO ─────────────────────────────────
          _SectionHeader('Support'),

          ListTile(
            leading: const Icon(Icons.coffee,
                color: Color(0xFFFFDD00)),
            title: const Text('Buy me a coffee'),
            subtitle: const Text('Support FlagPost ☕'),
            trailing: const Icon(Icons.open_in_new, size: 16),
            onTap: _openBuyMeACoffee,
          ),

          const Divider(),

          // ── LEGAL ─────────────────────────────────────
          _SectionHeader('Legal'),

          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.open_in_new, size: 16),
            onTap: () => launchUrl(
              Uri.parse('https://vale717171.github.io/flagpost-privacy/'),
              mode: LaunchMode.externalApplication,
            ),
          ),

          ListTile(
            leading: const Icon(Icons.gavel_outlined),
            title: const Text('Terms and Conditions'),
            trailing: const Icon(Icons.open_in_new, size: 16),
            onTap: () => launchUrl(
              Uri.parse('https://www.privacypolicies.com/live/8c94f054-2778-430a-96df-f7cf545922b2'),
              mode: LaunchMode.externalApplication,
            ),
          ),

          const Divider(),

          // ── DANGER ZONE ───────────────────────────────
          _SectionHeader('Danger zone'),

          ListTile(
            leading: const Icon(Icons.delete_forever,
                color: Colors.red),
            title: const Text(
              'Delete account and data',
              style: TextStyle(color: Colors.red),
            ),
            subtitle: const Text(
                'Permanently removes your profile and all data'),
            onTap: () => _deleteAccount(context),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// SCHERMATA UTENTI BLOCCATI
// ─────────────────────────────────────────────────
class BlockedUsersScreen extends StatelessWidget {
  const BlockedUsersScreen({super.key});

  Future<void> _unblock(String blockedUid) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('blockedUsers')
        .doc(blockedUid)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Blocked users')),
      body: StreamBuilder<QuerySnapshot>(
        stream: uid != null
            ? FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .collection('blockedUsers')
                .snapshots()
            : const Stream.empty(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No blocked users',
                    style: TextStyle(
                        color: Colors.grey[400], fontSize: 16),
                  ),
                ],
              ),
            );
          }

          final blockedDocs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: blockedDocs.length,
            itemBuilder: (context, index) {
              final blockedUid = blockedDocs[index].id;

              // Carica il profilo dell'utente bloccato
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(blockedUid)
                    .get(),
                builder: (context, userSnapshot) {
                  final userData = userSnapshot.data?.data()
                      as Map<String, dynamic>?;
                  final flag = userData?['countryFlag'] ?? '🌍';
                  final nickname =
                      userData?['nickname'] ?? 'Unknown user';

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey[100],
                      child: Text(flag,
                          style: const TextStyle(fontSize: 22)),
                    ),
                    title: Text(nickname),
                    trailing: TextButton(
                      onPressed: () async {
                        await _unblock(blockedUid);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            SnackBar(
                                content: Text(
                                    '$nickname unblocked.')),
                          );
                        }
                      },
                      child: const Text(
                        'Unblock',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
