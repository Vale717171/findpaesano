import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_picker/country_picker.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const EditProfileScreen({super.key, required this.userData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nicknameController;
  late TextEditingController _destinationController;
  Country? _selectedCountry;
  late String? _travelStatus;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController(
      text: widget.userData['nickname'] as String? ?? '',
    );
    _destinationController = TextEditingController(
      text: widget.userData['destination'] as String? ?? '',
    );
    _travelStatus = widget.userData['travelStatus'] as String?;
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  bool get _canSave {
    if (_nicknameController.text.trim().isEmpty) return false;
    if (_travelStatus == 'planning' &&
        _destinationController.text.trim().isEmpty) {
      return false;
    }
    return true;
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final updates = <String, dynamic>{
        'nickname': _nicknameController.text.trim(),
        'travelStatus': _travelStatus,
        'destination': _travelStatus == 'planning'
            ? _destinationController.text.trim()
            : null,
      };

      // Il paese viene aggiornato solo se l'utente l'ha cambiato
      if (_selectedCountry != null) {
        updates['countryCode'] = _selectedCountry!.countryCode;
        updates['countryName'] = _selectedCountry!.name;
        updates['countryFlag'] = _selectedCountry!.flagEmoji;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update(updates);

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentFlag = _selectedCountry?.flagEmoji ??
        widget.userData['countryFlag'] ??
        '🌍';
    final currentCountryName = _selectedCountry?.name ??
        widget.userData['countryName'] ??
        'Select country';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit profile'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: (!_canSave || _isLoading) ? null : _save,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Nickname ─────────────────────────────
            _sectionLabel('Nickname'),
            TextField(
              controller: _nicknameController,
              maxLength: 20,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Your nickname',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: Color(0xFF2196F3), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Nazionalità ───────────────────────────
            _sectionLabel('Nationality'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => showCountryPicker(
                context: context,
                showPhoneCode: false,
                onSelect: (c) => setState(() => _selectedCountry = c),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[400]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Text(currentFlag,
                        style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(currentCountryName,
                          style: const TextStyle(fontSize: 16)),
                    ),
                    const Icon(Icons.arrow_forward_ios,
                        size: 16, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Stato di viaggio ──────────────────────
            _sectionLabel('Status'),
            const SizedBox(height: 8),
            _StatusCard(
              label: '✈️ I\'m already there!',
              subtitle: 'Use my current location',
              isSelected: _travelStatus == 'here',
              onTap: () => setState(() {
                _travelStatus = 'here';
                _destinationController.clear();
              }),
            ),
            const SizedBox(height: 8),
            _StatusCard(
              label: '🔍 Planning my trip',
              subtitle: 'I want info about a destination',
              isSelected: _travelStatus == 'planning',
              onTap: () => setState(() => _travelStatus = 'planning'),
            ),
            if (_travelStatus == 'planning') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _destinationController,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText:
                      'Where are you going? (e.g. Tokyo, Reykjavik...)',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color(0xFF2196F3), width: 2),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
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

class _StatusCard extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusCard({
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2196F3)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2196F3)
                : Colors.grey[300]!,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : null,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: isSelected
                    ? Colors.white70
                    : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
