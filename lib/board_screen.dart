import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'starter_content.dart';

const List<Map<String, dynamic>> kCategories = [
  {'label': 'Food', 'icon': Icons.restaurant, 'color': Color(0xFFFF9800)},
  {'label': 'Places', 'icon': Icons.place, 'color': Color(0xFF4CAF50)},
  {
    'label': 'Transport',
    'icon': Icons.directions_bus,
    'color': Color(0xFF2196F3),
  },
  {'label': 'Warning', 'icon': Icons.warning, 'color': Color(0xFFF44336)},
  {'label': 'Other', 'icon': Icons.more_horiz, 'color': Color(0xFF9E9E9E)},
];

const List<Map<String, String>> kSuggestedCities = [
  {'name': 'Rome', 'country': 'Italy'},
  {'name': 'Milan', 'country': 'Italy'},
  {'name': 'London', 'country': 'United Kingdom'},
  {'name': 'Paris', 'country': 'France'},
  {'name': 'Barcelona', 'country': 'Spain'},
  {'name': 'Berlin', 'country': 'Germany'},
  {'name': 'Lisbon', 'country': 'Portugal'},
  {'name': 'Vienna', 'country': 'Austria'},
  {'name': 'New York City', 'country': 'United States'},
  {'name': 'Tokyo', 'country': 'Japan'},
];

// ── Board screen ────────────────────────────────────────────────────────────
// L'utente deve prima scegliere una località prima di vedere i messaggi.
// I messaggi sono sempre filtrati per località: niente caos globale.

class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key});

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  String? _boardLocation; // nome visualizzato, es. "Rome"
  String? _boardLocationKey; // chiave Firestore (lowercase), es. "rome"
  final _locationController = TextEditingController();

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  // Converte in Title Case: "new york" → "New York"
  String _toTitleCase(String s) => s
      .split(' ')
      .map(
        (w) => w.isEmpty
            ? ''
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}',
      )
      .join(' ');

  void _applyLocation() {
    final raw = _locationController.text.trim();
    if (raw.isEmpty) return;
    setState(() {
      _boardLocationKey = raw.toLowerCase();
      _boardLocation = _toTitleCase(raw);
    });
  }

  void _selectSuggestedCity(String city) {
    _locationController.text = city;
    _applyLocation();
  }

  void _resetLocation() {
    _locationController.clear();
    setState(() {
      _boardLocation = null;
      _boardLocationKey = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('City boards')),
      body: _boardLocation == null ? _buildLocationPicker() : _buildBoard(),
    );
  }

  // ── Schermata "scegli la località" ────────────────────────────────────────
  Widget _buildLocationPicker() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF2196F3).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.location_city,
              size: 36,
              color: Color(0xFF2196F3),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Pick a city',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Every board is organized by city, so tips, warnings and practical notes stay focused on the place you are visiting.',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _locationController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _applyLocation(),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'e.g. Tokyo, Rome, Barcelona...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF2196F3),
                  width: 2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Suggested cities',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kSuggestedCities.map((city) {
              final name = city['name']!;
              final country = city['country']!;
              return ActionChip(
                avatar: const Icon(Icons.location_on_outlined, size: 18),
                label: Text('$name · $country'),
                onPressed: () => _selectSuggestedCity(name),
                backgroundColor: const Color(
                  0xFF2196F3,
                ).withValues(alpha: 0.08),
                side: BorderSide(
                  color: const Color(0xFF2196F3).withValues(alpha: 0.18),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _locationController.text.trim().isEmpty
                  ? null
                  : _applyLocation,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Browse', style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.flag_outlined, size: 16, color: Colors.grey[500]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'See something inappropriate? Tap ··· on any message to report it. Messages reported by multiple users are hidden automatically.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Board con località selezionata ────────────────────────────────────────
  Widget _buildBoard() {
    return Column(
      children: [
        // Barra con la città selezionata e pulsante "Change"
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFF2196F3).withValues(alpha: 0.08),
          child: Row(
            children: [
              const Icon(
                Icons.location_city,
                color: Color(0xFF2196F3),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _boardLocation!,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2196F3),
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'City board',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _resetLocation,
                child: const Text('Change'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: kCategories.length,
            itemBuilder: (context, index) {
              final cat = kCategories[index];
              return _CategoryCard(
                category: cat,
                locationKey: _boardLocationKey!,
                locationDisplay: _boardLocation!,
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Category card (lista canali) ─────────────────────────────────────────────

class _CategoryCard extends StatelessWidget {
  final Map<String, dynamic> category;
  final String locationKey;
  final String locationDisplay;

  const _CategoryCard({
    required this.category,
    required this.locationKey,
    required this.locationDisplay,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        leading: CircleAvatar(
          backgroundColor: (category['color'] as Color).withValues(alpha: 0.15),
          child: Icon(
            category['icon'] as IconData,
            color: category['color'] as Color,
          ),
        ),
        title: Text(
          category['label'] as String,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tips for $locationDisplay'),
            _MessageCount(
              category: category['label'] as String,
              locationKey: locationKey,
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => CategoryScreen(
                category: category,
                locationKey: locationKey,
                locationDisplay: locationDisplay,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Contatore messaggi recenti (filtrato per località) ────────────────────────

class _MessageCount extends StatelessWidget {
  final String category;
  final String locationKey;

  const _MessageCount({required this.category, required this.locationKey});

  @override
  Widget build(BuildContext context) {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('messages')
          .where('locationKey', isEqualTo: locationKey)
          .where('category', isEqualTo: category)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(sevenDaysAgo))
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Text('');
        final count = snapshot.data!.docs.length;
        return Text(
          count == 0
              ? 'No recent messages'
              : '$count message${count == 1 ? '' : 's'} this week',
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        );
      },
    );
  }
}

// ── Schermata categoria (Recent / Archive) ────────────────────────────────────

class CategoryScreen extends StatefulWidget {
  final Map<String, dynamic> category;
  final String locationKey;
  final String locationDisplay;

  const CategoryScreen({
    super.key,
    required this.category,
    required this.locationKey,
    required this.locationDisplay,
  });

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  widget.category['icon'] as IconData,
                  color: widget.category['color'] as Color,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(widget.category['label'] as String),
              ],
            ),
            Text(
              widget.locationDisplay,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Recent'),
            Tab(text: 'Archive'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _MessageList(
            category: widget.category['label'] as String,
            locationKey: widget.locationKey,
            locationDisplay: widget.locationDisplay,
            isArchive: false,
          ),
          _MessageList(
            category: widget.category['label'] as String,
            locationKey: widget.locationKey,
            locationDisplay: widget.locationDisplay,
            isArchive: true,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNewMessageDialog(context),
        backgroundColor: widget.category['color'] as Color,
        child: const Icon(Icons.edit, color: Colors.white),
      ),
    );
  }

  void _showNewMessageDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _NewMessageSheet(
        preselectedCategory: widget.category['label'] as String,
        initialLocation: widget.locationDisplay,
        initialLocationKey: widget.locationKey,
      ),
    );
  }
}

// ── Lista messaggi con paginazione ────────────────────────────────────────────

class _MessageList extends StatefulWidget {
  final String category;
  final String locationKey;
  final String locationDisplay;
  final bool isArchive;

  const _MessageList({
    required this.category,
    required this.locationKey,
    required this.locationDisplay,
    required this.isArchive,
  });

  @override
  State<_MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<_MessageList> {
  int _limit = 50;

  @override
  Widget build(BuildContext context) {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    // Query filtrata per locationKey + category + finestra temporale.
    // NOTA: questa query richiede un indice composito su Firestore.
    // Se vedi un errore in console, clicca il link che Firestore fornisce
    // per creare l'indice automaticamente in Firebase Console.
    final query = widget.isArchive
        ? FirebaseFirestore.instance
              .collection('messages')
              .where('locationKey', isEqualTo: widget.locationKey)
              .where('category', isEqualTo: widget.category)
              .where(
                'createdAt',
                isLessThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo),
              )
              .orderBy('createdAt', descending: true)
              .limit(_limit)
        : FirebaseFirestore.instance
              .collection('messages')
              .where('locationKey', isEqualTo: widget.locationKey)
              .where('category', isEqualTo: widget.category)
              .where(
                'createdAt',
                isGreaterThan: Timestamp.fromDate(sevenDaysAgo),
              )
              .orderBy('createdAt', descending: true)
              .limit(_limit);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _emptyState();
        }

        return StreamBuilder<QuerySnapshot>(
          stream: currentUid != null
              ? FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUid)
                    .collection('blockedUsers')
                    .snapshots()
              : const Stream.empty(),
          builder: (context, blockedSnapshot) {
            final blockedIds = <String>{};
            if (blockedSnapshot.hasData) {
              for (final doc in blockedSnapshot.data!.docs) {
                blockedIds.add(doc.id);
              }
            }

            final filteredDocs = snapshot.data!.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              if (blockedIds.contains(data['authorUid'])) return false;
              // Auto-hide: nascondi i messaggi con 3+ segnalazioni,
              // tranne i propri (l'autore li vede sempre).
              final reportCount = data['reportCount'] as int? ?? 0;
              final isOwn = data['authorUid'] == currentUid;
              if (reportCount >= 3 && !isOwn) return false;
              return true;
            }).toList();

            if (filteredDocs.isEmpty) return _emptyState();

            final hasMore = snapshot.data!.docs.length >= _limit;

            return ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: filteredDocs.length + (hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == filteredDocs.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: TextButton.icon(
                        onPressed: () => setState(() => _limit += 50),
                        icon: const Icon(Icons.expand_more),
                        label: const Text('Load more'),
                      ),
                    ),
                  );
                }
                final doc = filteredDocs[index];
                final data = doc.data() as Map<String, dynamic>;
                return _MessageCard(messageId: doc.id, data: data);
              },
            );
          },
        );
      },
    );
  }

  Widget _emptyState() {
    if (widget.isArchive) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No archived messages',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<List<StarterTip>>(
      future: StarterContent.instance.tipsFor(
        locationKey: widget.locationKey,
        category: widget.category,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final tips = snapshot.data ?? [];

        if (tips.isNotEmpty) {
          return _buildStarterNotesPanel(tips);
        }

        return _buildGenericFallbackPrompt();
      },
    );
  }

  Widget _buildStarterNotesPanel(List<StarterTip> tips) {
    final categoryMeta = kCategories.firstWhere(
      (category) => category['label'] == widget.category,
      orElse: () => kCategories.last,
    );
    final categoryColor = categoryMeta['color'] as Color;
    final categoryIcon = categoryMeta['icon'] as IconData;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: categoryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: categoryColor.withValues(alpha: 0.16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(categoryIcon, color: categoryColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.locationDisplay} ${widget.category}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Official starter notes',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Editorial prompts to seed this city board until travelers add local posts.',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ...tips.asMap().entries.map(
            (entry) => _buildStarterTipCard(
              tip: entry.value,
              index: entry.key + 1,
              color: categoryColor,
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              children: [
                Icon(Icons.edit_note, color: Colors.grey[600], size: 20),
                Text(
                  'Be the first to leave a useful note for ${widget.locationDisplay}.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildStarterTipCard({
    required StarterTip tip,
    required int index,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.withValues(alpha: 0.18)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(12),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$index',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            tip.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      tip.body,
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenericFallbackPrompt() {
    String promptIdeas = '';
    switch (widget.category.toLowerCase()) {
      case 'food':
        promptIdeas = '• cheap meals\n• local dishes\n• places to avoid';
        break;
      case 'transport':
        promptIdeas =
            '• tickets & zones\n• airport transfer\n• common mistakes';
        break;
      case 'places':
        promptIdeas = '• underrated places\n• quiet areas\n• viewpoints';
        break;
      case 'warning':
        promptIdeas =
            '• scams & tourist traps\n• unsafe areas\n• practical cautions';
        break;
      default:
        promptIdeas = '• anything useful that does not fit elsewhere';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.forum_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text(
              'No tips here yet.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Starter prompts',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Useful things to post:\n$promptIdeas',
                    style: TextStyle(color: Colors.grey[700], height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Be the first to leave a useful note for ${widget.locationDisplay}.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Singolo messaggio ─────────────────────────────────────────────────────────

class _MessageCard extends StatelessWidget {
  final String messageId;
  final Map<String, dynamic> data;

  const _MessageCard({required this.messageId, required this.data});

  String _timeAgo(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final diff = DateTime.now().difference(timestamp.toDate());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = data['authorUid'] == currentUid;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _timeAgo(data['createdAt'] as Timestamp?),
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
                const Spacer(),
                if (isOwner)
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      size: 16,
                      color: Colors.grey[400],
                    ),
                    onSelected: (value) {
                      if (value == 'delete') _deleteMessage(context);
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  )
                else
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      size: 16,
                      color: Colors.grey[400],
                    ),
                    onSelected: (value) {
                      if (value == 'report') _reportMessage(context);
                      if (value == 'block') _blockUser(context);
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'report',
                        child: Row(
                          children: [
                            Icon(
                              Icons.flag_outlined,
                              color: Colors.red,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text('Report', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'block',
                        child: Row(
                          children: [
                            Icon(Icons.block, color: Colors.orange, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Block user',
                              style: TextStyle(color: Colors.orange),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              data['text'] as String? ?? '',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              '${data['authorFlag'] ?? ''} ${data['authorNickname'] ?? 'Anonymous'}',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteMessage(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete message'),
        content: const Text('Are you sure you want to delete this message?'),
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

    try {
      await FirebaseFirestore.instance
          .collection('messages')
          .doc(messageId)
          .delete();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Message deleted.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _reportMessage(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report message'),
        content: const Text(
          'Are you sure you want to report this message as inappropriate?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Report'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid == null) return;

      final existing = await FirebaseFirestore.instance
          .collection('reports')
          .where('messageId', isEqualTo: messageId)
          .where('reportedBy', isEqualTo: currentUid)
          .get();

      if (existing.docs.isNotEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You already reported this message.')),
          );
        }
        return;
      }

      // Aggiunge la segnalazione e incrementa il contatore sul messaggio
      final batch = FirebaseFirestore.instance.batch();
      batch.set(FirebaseFirestore.instance.collection('reports').doc(), {
        'messageId': messageId,
        'reportedBy': currentUid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.update(
        FirebaseFirestore.instance.collection('messages').doc(messageId),
        {'reportCount': FieldValue.increment(1)},
      );
      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message reported. Thank you!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _blockUser(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block user'),
        content: const Text(
          'You will no longer see messages from this user. You can unblock them from Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Block'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('blockedUsers')
          .doc(data['authorUid'] as String)
          .set({'blockedAt': FieldValue.serverTimestamp()});

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('User blocked.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

// ── Nuovo messaggio ───────────────────────────────────────────────────────────
// La località è precompilata con quella del board ma è modificabile,
// nel caso l'utente voglia postare per una città diversa da quella che sta guardando.

class _NewMessageSheet extends StatefulWidget {
  final String preselectedCategory;
  final String initialLocation;
  final String initialLocationKey;

  const _NewMessageSheet({
    required this.preselectedCategory,
    required this.initialLocation,
    required this.initialLocationKey,
  });

  @override
  State<_NewMessageSheet> createState() => _NewMessageSheetState();
}

class _NewMessageSheetState extends State<_NewMessageSheet> {
  final _textController = TextEditingController();
  final _locationController = TextEditingController();
  late String _selectedCategory;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.preselectedCategory;
    _locationController.text = widget.initialLocation;
  }

  @override
  void dispose() {
    _textController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  String _toTitleCase(String s) => s
      .split(' ')
      .map(
        (w) => w.isEmpty
            ? ''
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}',
      )
      .join(' ');

  bool get _canPost =>
      _textController.text.trim().isNotEmpty &&
      _locationController.text.trim().isNotEmpty &&
      !_isLoading;

  Future<void> _postMessage() async {
    if (!_canPost) return;
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data() ?? {};

      final locationRaw = _locationController.text.trim();
      final locationDisplay = _toTitleCase(locationRaw);
      final locationKey = locationRaw.toLowerCase();

      await FirebaseFirestore.instance.collection('messages').add({
        'text': _textController.text.trim(),
        'category': _selectedCategory,
        'location': locationDisplay,
        'locationKey': locationKey,
        'authorUid': user.uid,
        'authorNickname': userData['nickname'] ?? 'Anonymous',
        'authorFlag': userData['countryFlag'] ?? '🌍',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'New message',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // ── Località (primo campo, precompilato) ──
          TextField(
            controller: _locationController,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Location',
              hintText: 'e.g. Rome, Tokyo...',
              prefixIcon: const Icon(
                Icons.location_on,
                color: Color(0xFF2196F3),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF2196F3),
                  width: 2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Testo del messaggio ──
          TextField(
            controller: _textController,
            maxLength: 300,
            maxLines: 4,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Write your message...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF2196F3),
                  width: 2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canPost ? _postMessage : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Post', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
