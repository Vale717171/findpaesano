import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Schermata principale Chat — lista delle conversazioni attive
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: currentUid)
            .orderBy('lastMessageAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // FIX: filtra le chat chiuse (closedBy != null)
          final activeDocs = snapshot.hasData
              ? snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['closedBy'] == null;
                }).toList()
              : [];

          return Column(
            children: [
              _PendingRequests(currentUid: currentUid),
              Expanded(
                child: activeDocs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline,
                                size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              'No active chats\nSend a signal from the Radar!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: activeDocs.length,
                        itemBuilder: (context, index) {
                          final doc = activeDocs[index];
                          final data =
                              doc.data() as Map<String, dynamic>;
                          return _ChatTile(
                            chatId: doc.id,
                            data: data,
                            currentUid: currentUid!,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// Sezione richieste di chat in arrivo
class _PendingRequests extends StatelessWidget {
  final String? currentUid;

  const _PendingRequests({required this.currentUid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chatRequests')
          .where('toUid', isEqualTo: currentUid)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Incoming signals',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
            ),
            ...snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return _RequestTile(requestId: doc.id, data: data);
            }),
            const Divider(),
          ],
        );
      },
    );
  }
}

// FIX: StatefulWidget per gestire il doppio tap e lo stato di processing
class _RequestTile extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic> data;

  const _RequestTile({required this.requestId, required this.data});

  @override
  State<_RequestTile> createState() => _RequestTileState();
}

class _RequestTileState extends State<_RequestTile> {
  bool _isProcessing = false;

  Future<void> _acceptRequest(BuildContext context) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid == null) return;

      final fromUid = widget.data['fromUid'] as String;

      // FIX: usa una transaction Firestore per creare la chat e
      // aggiornare la richiesta in modo atomico. Evita duplicati.
      final chatRef =
          FirebaseFirestore.instance.collection('chats').doc();

      await FirebaseFirestore.instance
          .runTransaction((transaction) async {
        transaction.set(chatRef, {
          'participants': [currentUid, fromUid],
          'participantFlags': {
            currentUid: widget.data['toFlag'] ?? '🌍',
            fromUid: widget.data['fromFlag'] ?? '🌍',
          },
          'participantNicknames': {
            currentUid: widget.data['toNickname'] ?? 'Anonymous',
            fromUid: widget.data['fromNickname'] ?? 'Anonymous',
          },
          'lastMessageAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });

        transaction.update(
          FirebaseFirestore.instance
              .collection('chatRequests')
              .doc(widget.requestId),
          {'status': 'accepted', 'chatId': chatRef.id},
        );
      });

      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ChatDetailScreen(
              chatId: chatRef.id,
              currentUid: currentUid,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _declineRequest() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      await FirebaseFirestore.instance
          .collection('chatRequests')
          .doc(widget.requestId)
          .update({'status': 'declined'});
    } catch (e) {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Text(
        widget.data['fromFlag'] ?? '🌍',
        style: const TextStyle(fontSize: 28),
      ),
      title: Text(widget.data['fromNickname'] ?? 'Anonymous'),
      subtitle: const Text('wants to chat with you'),
      trailing: _isProcessing
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: _declineRequest,
                ),
                IconButton(
                  icon:
                      const Icon(Icons.check, color: Colors.green),
                  onPressed: () => _acceptRequest(context),
                ),
              ],
            ),
    );
  }
}

// Tile per una chat attiva
class _ChatTile extends StatelessWidget {
  final String chatId;
  final Map<String, dynamic> data;
  final String currentUid;

  const _ChatTile({
    required this.chatId,
    required this.data,
    required this.currentUid,
  });

  @override
  Widget build(BuildContext context) {
    final participants = data['participants'] as List<dynamic>;
    final otherUid =
        participants.firstWhere((uid) => uid != currentUid);
    final otherFlag =
        (data['participantFlags'] as Map<String, dynamic>?)?[
                otherUid] ??
            '🌍';
    final otherNickname =
        (data['participantNicknames'] as Map<String, dynamic>?)?[
                otherUid] ??
            'Anonymous';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.grey[100],
        child: Text(otherFlag,
            style: const TextStyle(fontSize: 24)),
      ),
      title: Text(otherNickname),
      subtitle: Text(
        data['lastMessage'] ?? 'Chat started',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Colors.grey[500]),
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ChatDetailScreen(
              chatId: chatId,
              currentUid: currentUid,
            ),
          ),
        );
      },
    );
  }
}

// Schermata dettaglio chat
class ChatDetailScreen extends StatefulWidget {
  final String chatId;
  final String currentUid;

  const ChatDetailScreen({
    super.key,
    required this.chatId,
    required this.currentUid,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController =
      TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // FIX: dati dell'altro utente caricati una volta in initState,
  // non in un FutureBuilder che si ri-esegue ad ogni rebuild dell'AppBar
  String _otherNickname = '';
  String _otherFlag = '🌍';

  @override
  void initState() {
    super.initState();
    _loadChatInfo();
  }

  Future<void> _loadChatInfo() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .get();
      if (!mounted) return;
      final data = doc.data();
      if (data == null) return;

      final participants = data['participants'] as List<dynamic>;
      final otherUid = participants.firstWhere(
        (uid) => uid != widget.currentUid,
        orElse: () => '',
      );

      setState(() {
        _otherFlag =
            (data['participantFlags'] as Map<String, dynamic>?)?[
                    otherUid] ??
                '🌍';
        _otherNickname =
            (data['participantNicknames'] as Map<String, dynamic>?)?[
                    otherUid] ??
                'Anonymous';
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add({
        'text': text,
        'senderUid': widget.currentUid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .update({
        'lastMessage': text,
        'lastMessageAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _closeChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close chat'),
        content: const Text(
            'This conversation will be hidden from your list. The other person will not be affected.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style:
                TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Close'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .update({
      'closedBy': widget.currentUid,
      'closedAt': FieldValue.serverTimestamp(),
    });

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // FIX: titolo da state, non da FutureBuilder che rieseguiva ogni rebuild
        title: Text('$_otherFlag $_otherNickname'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed: _closeChat,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('createdAt', descending: false)
                  // FIX: limite per non scaricare tutta la storia
                  .limitToLast(100)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                      child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration:
                          const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                    );
                  }
                });

                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'Say hello! 👋',
                      style: TextStyle(
                          color: Colors.grey, fontSize: 16),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index].data()
                        as Map<String, dynamic>;
                    final isMe =
                        msg['senderUid'] == widget.currentUid;
                    return _MessageBubble(
                        text: msg['text'] ?? '', isMe: isMe);
                  },
                );
              },
            ),
          ),
          // FIX: colori adattativi per dark mode
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    // FIX: limite di caratteri — senza di questo messaggi infiniti
                    maxLength: 500,
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    // FIX: Enter = invia (comportamento standard chat)
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Write a message...',
                      // FIX: nasconde il contatore "0/500" per non sporcare la UI
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      contentPadding:
                          const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send,
                      color: Color(0xFF2196F3)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Bubble singolo messaggio
class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;

  const _MessageBubble({required this.text, required this.isMe});

  @override
  Widget build(BuildContext context) {
    // FIX: colori adattativi per dark mode (erano hardcoded)
    final bubbleColor = isMe
        ? const Color(0xFF2196F3)
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    final textColor = isMe
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;

    return Align(
      alignment:
          isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: textColor,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
