import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_picker/country_picker.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentStep = 0;

  Country? _selectedCountry;
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  String? _travelStatus;
  bool _isLoading = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      final userCredential = await FirebaseAuth.instance.signInAnonymously();
      final uid = userCredential.user!.uid;

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'nickname': _nicknameController.text.trim(),
        'countryCode': _selectedCountry!.countryCode,
        'countryName': _selectedCountry!.name,
        'countryFlag': _selectedCountry!.flagEmoji,
        'travelStatus': _travelStatus,
        'destination': _travelStatus == 'planning'
            ? _destinationController.text.trim()
            : null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              LinearProgressIndicator(
                value: (_currentStep + 1) / 3,
                backgroundColor: Colors.grey[200],
                color: const Color(0xFF2196F3),
              ),
              const SizedBox(height: 32),
              Expanded(child: _buildCurrentStep()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0: return _buildCountryStep();
      case 1: return _buildNicknameStep();
      case 2: return _buildTravelStatusStep();
      default: return const SizedBox();
    }
  }

  Widget _buildCountryStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Hey! 👋', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Where are you from?', style: TextStyle(fontSize: 18, color: Colors.grey)),
        const SizedBox(height: 32),
        GestureDetector(
          onTap: () {
            showCountryPicker(
              context: context,
              showPhoneCode: false,
              onSelect: (Country country) {
                setState(() => _selectedCountry = country);
              },
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Text(
                  _selectedCountry?.flagEmoji ?? '🌍',
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(width: 16),
                Text(
                  _selectedCountry?.name ?? 'Tap to select your country',
                  style: TextStyle(
                    fontSize: 16,
                    color: _selectedCountry == null ? Colors.grey : Colors.black87,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _PrivacyNotice(),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _selectedCountry == null ? null : () {
              setState(() => _currentStep = 1);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Next', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _buildNicknameStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${_selectedCountry?.flagEmoji} Welcome!',
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Choose a nickname', style: TextStyle(fontSize: 18, color: Colors.grey)),
        const SizedBox(height: 4),
        const Text('No real name required 😉', style: TextStyle(fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 32),
        TextField(
          controller: _nicknameController,
          maxLength: 20,
          onChanged: (value) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'E.g. Marco_Roma, Traveler99...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2196F3), width: 2),
            ),
          ),
        ),
        const Spacer(),
        Row(
          children: [
            TextButton(
              onPressed: () => setState(() => _currentStep = 0),
              child: const Text('Back'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: _nicknameController.text.trim().isEmpty ? null : () {
                  setState(() => _currentStep = 2);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Next', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTravelStatusStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Almost there! 🌍',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('What\'s your situation?',
            style: TextStyle(fontSize: 18, color: Colors.grey)),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: () => setState(() {
              _travelStatus = 'here';
              _destinationController.clear();
            }),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _travelStatus == 'here' ? const Color(0xFF2196F3) : Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _travelStatus == 'here' ? const Color(0xFF2196F3) : Colors.grey[300]!,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('✈️ I\'m already there!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _travelStatus == 'here' ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Use my current location',
                    style: TextStyle(
                      color: _travelStatus == 'here' ? Colors.white70 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => setState(() => _travelStatus = 'planning'),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _travelStatus == 'planning' ? const Color(0xFF2196F3) : Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _travelStatus == 'planning' ? const Color(0xFF2196F3) : Colors.grey[300]!,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🔍 Planning my trip',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _travelStatus == 'planning' ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('I want info about a destination',
                    style: TextStyle(
                      color: _travelStatus == 'planning' ? Colors.white70 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _PrivacyNotice(),
          if (_travelStatus == 'planning') ...[
            const SizedBox(height: 16),
            TextField(
              controller: _destinationController,
              onChanged: (value) => setState(() {}),
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'Where are you going? (e.g. Tokyo, Reykjavik...)',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF2196F3), width: 2),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              TextButton(
                onPressed: () => setState(() => _currentStep = 1),
                child: const Text('Back'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: (_travelStatus == null ||
                      (_travelStatus == 'planning' && _destinationController.text.trim().isEmpty) ||
                      _isLoading) ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Let\'s go!', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PrivacyNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2196F3).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2196F3).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield, color: Color(0xFF2196F3), size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Your privacy is protected. Other users never see your exact location — only an approximate area of a few km. Your real position is never shared.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
