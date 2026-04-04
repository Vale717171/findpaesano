import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RadarScreen extends StatefulWidget {
  const RadarScreen({super.key});

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen> {
  Position? _currentPosition;
  bool _isLoading = true;
  String? _error;
  double _radiusKm = 5.0;
  final MapController _mapController = MapController();

  String? _myCountryCode;
  String? _myCountryFlag;

  StreamSubscription<Position>? _positionSubscription;

  // ── Ricerca città ─────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  LatLng? _searchCenter;   // se non null, distanze calcolate da qui
  String? _searchLabel;    // nome della città cercata
  bool _isSearching = false;

  // ── Privacy: zoom massimo per mostrare i marker ──
  // Sopra questo livello i marker spariscono (visibile solo il contatore)
  static const double _maxMarkerZoom = 13.0;
  double _currentZoom = 12.0;

  // Banner privacy: visibile ad ogni avvio, dismissibile
  bool _showPrivacyBanner = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _initLocation();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (mounted) {
      final data = doc.data();
      setState(() {
        _myCountryCode = data?['countryCode'] as String?;
        _myCountryFlag = data?['countryFlag'] as String?;
      });
      // Se l'utente sta pianificando un viaggio, centra la mappa sulla destinazione
      final status = data?['travelStatus'] as String?;
      final destination = data?['destination'] as String?;
      if (status == 'planning' && destination != null && destination.isNotEmpty) {
        _searchCity(destination);
      }
    }
  }

  LatLng _fuzzyPosition(double lat, double lng) {
    final random = Random();
    final latOffset = (random.nextDouble() - 0.5) * 0.036;
    final lngOffset = (random.nextDouble() - 0.5) * 0.036;
    return LatLng(lat + latOffset, lng + lngOffset);
  }

  Future<void> _initLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _error = 'GPS disabled. Please enable location services.';
            _isLoading = false;
          });
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              _error = 'Location permission denied.';
              _isLoading = false;
            });
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _error =
                'Location permission permanently denied. Enable it from Settings.';
            _isLoading = false;
          });
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('GPS timeout. Move outside and retry.'),
      );

      if (mounted) {
        setState(() {
          _currentPosition = position;
          _isLoading = false;
        });
      }
      await _savePosition(position);
      _startPositionStream();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'GPS error: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _startPositionStream() {
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 100,
      ),
    ).listen(
      (position) {
        if (mounted) setState(() => _currentPosition = position);
        _savePosition(position);
      },
      onError: (_) {},
    );
  }

  Future<void> _refreshPosition() async {
    // Torna alla propria posizione e cancella la ricerca
    _clearSearch();
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 15));

      if (mounted) {
        setState(() => _currentPosition = position);
        _mapController.move(
          LatLng(position.latitude, position.longitude),
          _radiusKm <= 1 ? 14 : _radiusKm <= 5 ? 12 : 10,
        );
      }
      await _savePosition(position);
    } catch (_) {}
  }

  Future<void> _savePosition(Position position) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final fuzzy = _fuzzyPosition(position.latitude, position.longitude);
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'location': GeoPoint(fuzzy.latitude, fuzzy.longitude),
      'locationUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Geocodifica con OpenStreetMap Nominatim (gratuito, no API key) ──
  Future<void> _searchCity(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;

    setState(() => _isSearching = true);

    try {
      final client = HttpClient();
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(q)}&format=json&limit=1&addressdetails=0',
      );
      final request = await client.getUrl(uri);
      // Nominatim richiede uno User-Agent identificativo
      request.headers.set('User-Agent', 'app.findpaesano');
      final response = await request.close();
      final body = await utf8.decodeStream(response);
      client.close();

      final results = jsonDecode(body) as List;

      if (results.isEmpty) {
        if (mounted) {
          setState(() => _isSearching = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('City "$q" not found.')),
          );
        }
        return;
      }

      final first = results[0] as Map<String, dynamic>;
      final lat = double.parse(first['lat'] as String);
      final lon = double.parse(first['lon'] as String);
      // Prende solo la prima parte del nome (es. "Perugia" da "Perugia, Umbria, Italy")
      final cityName =
          (first['display_name'] as String).split(',')[0].trim();

      if (mounted) {
        setState(() {
          _searchCenter = LatLng(lat, lon);
          _searchLabel = cityName;
          _isSearching = false;
        });
        _mapController.move(
          LatLng(lat, lon),
          _radiusKm <= 1 ? 14 : _radiusKm <= 5 ? 12 : 10,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search error: $e')),
        );
      }
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchCenter = null;
      _searchLabel = null;
    });
    if (_currentPosition != null) {
      _mapController.move(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        _radiusKm <= 1 ? 14 : _radiusKm <= 5 ? 12 : 10,
      );
    }
  }

  double _distanceKm(
      double lat1, double lng1, double lat2, double lng2) {
    const earthRadius = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) *
            cos(_toRad(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRad(double deg) => deg * pi / 180;

  Future<void> _sendSignal(BuildContext context,
      Map<String, dynamic> user, String otherUid) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final myDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final myData = myDoc.data() ?? {};

      final existing = await FirebaseFirestore.instance
          .collection('chatRequests')
          .where('fromUid', isEqualTo: currentUser.uid)
          .where('toUid', isEqualTo: otherUid)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existing.docs.isNotEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Signal already sent! Waiting for response...')),
          );
        }
        return;
      }

      final existingChats = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: currentUser.uid)
          .get();

      final alreadyChatting = existingChats.docs.any((doc) {
        final data = doc.data();
        final participants = data['participants'] as List<dynamic>;
        return participants.contains(otherUid) &&
            data['closedBy'] == null;
      });

      if (alreadyChatting) {
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'You already have an active chat with this user.')),
          );
        }
        return;
      }

      await FirebaseFirestore.instance
          .collection('chatRequests')
          .add({
        'fromUid': currentUser.uid,
        'fromNickname': myData['nickname'] ?? 'Anonymous',
        'fromFlag': myData['countryFlag'] ?? '🌍',
        'toUid': otherUid,
        'toNickname': user['nickname'] ?? 'Anonymous',
        'toFlag': user['countryFlag'] ?? '🌍',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Signal sent! 👋 Waiting for response...')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Getting your location...'),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_off,
                    size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _error = null;
                    });
                    _initLocation();
                  },
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final myLat = _currentPosition!.latitude;
    final myLng = _currentPosition!.longitude;

    // Punto di riferimento per il calcolo distanze:
    // se l'utente ha cercato una città, usa quella; altrimenti usa la posizione GPS
    final refLat = _searchCenter?.latitude ?? myLat;
    final refLng = _searchCenter?.longitude ?? myLng;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Radar'),
        actions: [
          PopupMenuButton<double>(
            icon: const Icon(Icons.tune),
            onSelected: (value) =>
                setState(() => _radiusKm = value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 1.0, child: Text('1 km')),
              const PopupMenuItem(value: 5.0, child: Text('5 km')),
              const PopupMenuItem(
                  value: 20.0, child: Text('20 km')),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('location', isNotEqualTo: null)
            .snapshots(),
        builder: (context, snapshot) {
          final currentUid =
              FirebaseAuth.instance.currentUser?.uid;
          final nearbyUsers = <Map<String, dynamic>>[];

          if (snapshot.hasData) {
            for (final doc in snapshot.data!.docs) {
              if (doc.id == currentUid) continue;
              final data =
                  doc.data() as Map<String, dynamic>;
              final location =
                  data['location'] as GeoPoint?;
              if (location == null) continue;

              if (_myCountryCode != null &&
                  data['countryCode'] != _myCountryCode) {
                continue;
              }

              final dist = _distanceKm(
                refLat, refLng,
                location.latitude, location.longitude,
              );

              if (dist <= _radiusKm) {
                nearbyUsers.add(
                    {...data, 'uid': doc.id, 'distance': dist});
              }
            }
          }

          return Stack(
            children: [
              // ── Mappa ─────────────────────────────
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: LatLng(myLat, myLng),
                  initialZoom: _radiusKm <= 1
                      ? 14
                      : _radiusKm <= 5
                          ? 12
                          : 10,
                  onMapEvent: (event) {
                    if (event is MapEventMove || event is MapEventMoveEnd) {
                      final zoom = event.camera.zoom;
                      if ((zoom - _currentZoom).abs() > 0.2) {
                        setState(() => _currentZoom = zoom);
                      }
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'app.findpaesano',
                  ),
                  MarkerLayer(
                    markers: [
                      // Marker posizione reale dell'utente
                      Marker(
                        point: LatLng(myLat, myLng),
                        width: 40,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF2196F3),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue
                                    .withValues(alpha: 0.4),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Center(
                            child: _myCountryFlag != null
                                ? Text(_myCountryFlag!,
                                    style: const TextStyle(
                                        fontSize: 16))
                                : const Icon(Icons.person,
                                    color: Colors.white,
                                    size: 20),
                          ),
                        ),
                      ),
                      // Marker compatrioti — visibili solo fino a zoom 13
                      // (privacy: sopra quella soglia spariscono)
                      if (_currentZoom <= _maxMarkerZoom)
                        ...nearbyUsers.map((user) {
                        final location =
                            user['location'] as GeoPoint;
                        return Marker(
                          point: LatLng(location.latitude,
                              location.longitude),
                          width: 44,
                          height: 44,
                          child: GestureDetector(
                            onTap: () =>
                                _showUserInfo(context, user),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color:
                                      const Color(0xFF2196F3),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black
                                        .withValues(alpha: 0.2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  user['countryFlag'] ?? '🌍',
                                  style: const TextStyle(
                                      fontSize: 20),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),

              // ── Barra di ricerca città ─────────────
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color:
                            Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _searchCity,
                    decoration: InputDecoration(
                      hintText: 'Search a city...',
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 14),
                      prefixIcon: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              ),
                            )
                          : const Icon(Icons.search,
                              color: Colors.grey),
                      suffixIcon: _searchLabel != null
                          ? IconButton(
                              icon: const Icon(Icons.close,
                                  color: Colors.grey),
                              onPressed: _clearSearch,
                            )
                          : null,
                    ),
                  ),
                ),
              ),

              // ── Badge: raggio + contatore compatrioti ──
              Positioned(
                top: 80,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _searchLabel != null
                        ? const Color(0xFF2196F3)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color:
                            Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _searchLabel != null
                            ? Icons.location_on
                            : Icons.radar,
                        size: 16,
                        color: _searchLabel != null
                            ? Colors.white
                            : const Color(0xFF2196F3),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _searchLabel != null
                            ? '$_searchLabel · '
                                '${nearbyUsers.length} compatriot'
                                '${nearbyUsers.length == 1 ? '' : 's'}'
                            : '${_radiusKm.toInt()} km · '
                                '${nearbyUsers.length} compatriot'
                                '${nearbyUsers.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: _searchLabel != null
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Banner privacy (dismissibile, si resetta ad ogni avvio) ──
              if (_showPrivacyBanner)
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF2196F3).withValues(alpha: 0.4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.shield,
                            color: Color(0xFF2196F3), size: 18),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Your privacy is protected. Other users never see your exact location — only an approximate area of a few km.',
                            style: TextStyle(fontSize: 12, height: 1.4),
                          ),
                        ),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _showPrivacyBanner = false),
                          child: const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.close,
                                size: 18, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ── Avviso privacy: marker nascosti a zoom alto ──
              if (_currentZoom > _maxMarkerZoom)
                Positioned(
                  bottom: 80,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '🔍 Zoom out to see users',
                        style: TextStyle(
                            color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),

      // FAB: torna alla propria posizione (cancella anche la ricerca)
      floatingActionButton: FloatingActionButton(
        onPressed: _refreshPosition,
        backgroundColor: const Color(0xFF2196F3),
        tooltip: 'My location',
        child: const Icon(Icons.my_location, color: Colors.white),
      ),
    );
  }

  void _showUserInfo(
      BuildContext context, Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(user['countryFlag'] ?? '🌍',
                style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 8),
            Text(
              user['nickname'] ?? 'Anonymous',
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(user['countryName'] ?? '',
                style: TextStyle(color: Colors.grey[600])),
            if (user['travelStatus'] != null) ...[
              const SizedBox(height: 4),
              Text(
                user['travelStatus'] == 'planning' &&
                        (user['destination'] as String?)
                                ?.isNotEmpty ==
                            true
                    ? '🔍 Planning → ${user['destination']}'
                    : '✈️ Currently here',
                style: TextStyle(
                    color: Colors.grey[500], fontSize: 13),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              '${(user['distance'] as double).toStringAsFixed(1)} km away',
              style: TextStyle(
                  color: Colors.grey[500], fontSize: 13),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _sendSignal(
                    context, user, user['uid'] as String),
                icon: const Icon(Icons.wifi_tethering),
                label: const Text('Send signal'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
