import 'dart:convert';
import 'package:flutter/services.dart';

class StarterTip {
  final String title;
  final String body;

  StarterTip({required this.title, required this.body});

  factory StarterTip.fromJson(Map<String, dynamic> json) {
    return StarterTip(
      title: json['title'] as String,
      body: json['body'] as String,
    );
  }
}

class StarterContent {
  StarterContent._privateConstructor();
  static final StarterContent instance = StarterContent._privateConstructor();

  Map<String, dynamic>? _cachedData;

  Future<void> _loadIfNeeded() async {
    if (_cachedData != null) return;
    try {
      final String jsonString = await rootBundle.loadString(
        'assets/starter_tips.json',
      );
      _cachedData = jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      // In case of error (e.g. file missing), cache an empty map to avoid repeated failures.
      _cachedData = {};
    }
  }

  Future<List<StarterTip>> tipsFor({
    required String locationKey,
    required String category,
  }) async {
    await _loadIfNeeded();

    if (_cachedData == null || _cachedData!.isEmpty) {
      return [];
    }

    final normalizedLocation = locationKey.trim().toLowerCase();

    final cities = _cachedData!['cities'] as Map<String, dynamic>?;
    final fallback = _cachedData!['fallback'] as Map<String, dynamic>?;

    // 1. Check exact city key
    if (cities != null && cities.containsKey(normalizedLocation)) {
      final cityData = cities[normalizedLocation] as Map<String, dynamic>;
      return _extractTips(
        cityData['categories'] as Map<String, dynamic>?,
        category,
        fallback,
      );
    }

    // 2. Check aliases
    if (cities != null) {
      for (final cityKey in cities.keys) {
        final cityData = cities[cityKey] as Map<String, dynamic>;
        final aliases =
            (cityData['aliases'] as List<dynamic>?)?.cast<String>() ?? [];
        if (aliases.contains(normalizedLocation)) {
          return _extractTips(
            cityData['categories'] as Map<String, dynamic>?,
            category,
            fallback,
          );
        }
      }
    }

    // 3. Fallback
    return _extractFallbackTips(category, fallback);
  }

  List<StarterTip> _extractTips(
    Map<String, dynamic>? categories,
    String category,
    Map<String, dynamic>? fallback,
  ) {
    if (categories != null && categories.containsKey(category)) {
      final tipsList = categories[category] as List<dynamic>?;
      if (tipsList != null && tipsList.isNotEmpty) {
        return tipsList
            .map((t) => StarterTip.fromJson(t as Map<String, dynamic>))
            .toList();
      }
    }
    return _extractFallbackTips(category, fallback);
  }

  List<StarterTip> _extractFallbackTips(
    String category,
    Map<String, dynamic>? fallback,
  ) {
    if (fallback != null && fallback.containsKey(category)) {
      final tipsList = fallback[category] as List<dynamic>?;
      if (tipsList != null && tipsList.isNotEmpty) {
        return tipsList
            .map((t) => StarterTip.fromJson(t as Map<String, dynamic>))
            .toList();
      }
    }
    return [];
  }
}
