import 'dart:convert';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/carousel.dart';
import '../widgets/more.dart';
import 'detail_screen.dart';
import 'detail/disarankan.dart';
import 'detail/langganan.dart';
import 'detail/terdekat.dart';
import 'post_screen.dart';
import 'error/login.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController searchController = TextEditingController();
  String searchQuery = '';

  // Koordinat dari ALAMAT LENGKAP (untuk keperluan lain jika ada)
  double? userLatitude;
  double? userLongitude;
  bool hasFullAddress = false;

  // Koordinat REAL-TIME (digunakan untuk section Terdekat)
  double? realTimeLatitude;
  double? realTimeLongitude;
  bool isRealTimeLocationActive = false;

  final List<String> kategoriOptions = [
    'Semua',
    'Ikan Air Tawar',
    'Ikan Laut',
    'Ikan Hias',
    'Udang',
    'Kepiting',
    'Lobster',
    'Lainnya',
  ];
  String selectedCategory = 'Semua';

  String _formatCurrency(String priceStr) {
    try {
      final price = int.parse(priceStr);
      return price.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]}.',
      );
    } catch (e) {
      return priceStr;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserAddress();
    _listenToUserChanges();
  }

  void _listenToUserChanges() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen((doc) {
            if (doc.exists && mounted) {
              final data = doc.data();

              // Koordinat dari alamat lengkap
              final lat = (data?['latitude'] ?? 0.0) as double?;
              final lng = (data?['longitude'] ?? 0.0) as double?;

              // Koordinat real-time (field terpisah)
              final rtLat = (data?['realTimeLatitude'] ?? 0.0) as double?;
              final rtLng = (data?['realTimeLongitude'] ?? 0.0) as double?;

              final isRealTimeValue = data?['isRealTimeLocation'];
              final isRealTime = (isRealTimeValue is bool)
                  ? isRealTimeValue
                  : false;

              setState(() {
                userLatitude = (lat != null && lat != 0.0) ? lat : null;
                userLongitude = (lng != null && lng != 0.0) ? lng : null;
                hasFullAddress = userLatitude != null && userLongitude != null;

                isRealTimeLocationActive = isRealTime;

                // Real-time koordinat hanya valid jika toggle ON dan nilai ada
                // PENTING: Gunakan rtLat langsung (jangan filter 0.0) karena koordinat
                // dari GPS selalu memiliki nilai (kecil kemungkinan tepat 0.0)
                realTimeLatitude = isRealTime ? rtLat : null;
                realTimeLongitude = isRealTime ? rtLng : null;
              });
            }
          });
    }
  }

  void _loadUserAddress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists && mounted) {
          final data = doc.data();

          final lat = (data?['latitude'] ?? 0.0) as double?;
          final lng = (data?['longitude'] ?? 0.0) as double?;

          final rtLat = (data?['realTimeLatitude'] ?? 0.0) as double?;
          final rtLng = (data?['realTimeLongitude'] ?? 0.0) as double?;

          final isRealTimeValue = data?['isRealTimeLocation'];
          final isRealTime = (isRealTimeValue is bool)
              ? isRealTimeValue
              : false;

          setState(() {
            userLatitude = (lat != null && lat != 0.0) ? lat : null;
            userLongitude = (lng != null && lng != 0.0) ? lng : null;
            hasFullAddress = userLatitude != null && userLongitude != null;

            isRealTimeLocationActive = isRealTime;

            realTimeLatitude = isRealTime ? rtLat : null;
            realTimeLongitude = isRealTime ? rtLng : null;
          });
        }
      } catch (e) {
        debugPrint('Error loading user address: $e');
      }
    }
  }

  Widget _buildFishCard(QueryDocumentSnapshot doc, double cardWidth) {
    final ikan = doc.data() as Map<String, dynamic>? ?? {};
    final lokasiText = ikan['lokasi']?.toString() ?? '-';
    final harga = ikan['harga']?.toString() ?? '0';
    final nama = ikan['nama']?.toString() ?? 'Tanpa Nama';
    final gambarString = ikan['gambar']?.toString() ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetailScreen(ikanId: doc.id)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C8EF5).withOpacity(isDark ? 0.05 : 0.10),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 112,
                child: gambarString.isNotEmpty
                    ? Image.memory(
                        base64Decode(gambarString),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholder(),
                      )
                    : _buildPlaceholder(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nama,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 11,
                        color: isDark
                            ? const Color(0xFFB0B0B0)
                            : const Color(0xFF9E9E9E),
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          lokasiText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? const Color(0xFFB0B0B0)
                                : const Color(0xFF9E9E9E),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Rp ${_formatCurrency(harga)}',
                    style: const TextStyle(
                      color: Color(0xFF6C8EF5),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? const Color(0xFF2A2A3E) : const Color(0xFFEEF3FF),
      child: Center(
        child: Icon(
          Icons.set_meal_rounded,
          size: 38,
          color: isDark ? const Color(0xFF9BAFFF) : const Color(0xFF6C8EF5),
        ),
      ),
    );
  }

  /// Grid 2 kolom — dipakai saat tidak ada kondisi khusus
  Widget _buildDisarankanGrid(List<QueryDocumentSnapshot> items) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth - 32 - 10) / 2;

    return Wrap(
      spacing: 10,
      runSpacing: 12,
      children: items.map((doc) {
        return SizedBox(
          width: cardWidth,
          child: _buildFishCard(doc, cardWidth),
        );
      }).toList(),
    );
  }

  /// Haversine formula — hasil dalam meter
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371000;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  /// Filter berdasarkan radius dari koordinat REAL-TIME user
  List<QueryDocumentSnapshot> _filterItemsByRadius(
    List<QueryDocumentSnapshot> items,
    double userLat,
    double userLon,
    double radiusMeters,
  ) {
    return items.where((doc) {
      final ikan = doc.data() as Map<String, dynamic>;
      final lat = ikan['latitude'] as double?;
      final lon = ikan['longitude'] as double?;
      if (lat == null || lon == null) return false;
      final distance = _calculateDistance(userLat, userLon, lat, lon);
      return distance <= radiusMeters;
    }).toList();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // Helper: apakah user sedang punya langganan?
  // Digunakan untuk menentukan layout section Disarankan.
  // ─────────────────────────────────────────────
  Widget _buildBodyContent(List<QueryDocumentSnapshot> filteredData) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Section Terdekat: hanya muncul jika toggle real-time ON
    // dan koordinat real-time tersedia
    final bool canShowNearby =
        isRealTimeLocationActive &&
        realTimeLatitude != null &&
        realTimeLongitude != null;

    final List<QueryDocumentSnapshot> nearbyItems = canShowNearby
        ? _filterItemsByRadius(
            filteredData,
            realTimeLatitude!,
            realTimeLongitude!,
            2000, // 2km radius
          )
        : [];

    final currentUser = FirebaseAuth.instance.currentUser;

    // Jika user belum login → tidak ada langganan, cek toggle untuk layout
    if (currentUser == null) {
      if (isRealTimeLocationActive) {
        // Toggle ON: Disarankan horizontal scroll
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MoreSectionWidget(
              title: 'Disarankan',
              items: filteredData,
              detailBuilder: (id) => DetailScreen(ikanId: id),
              onSeeMore: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DisarankanScreen(items: filteredData),
                ),
              ),
            ),
            if (nearbyItems.isNotEmpty)
              MoreSectionWidget(
                title: 'Terdekat',
                items: nearbyItems,
                detailBuilder: (id) => DetailScreen(ikanId: id),
                onSeeMore: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TerdekatScreen(items: nearbyItems),
                  ),
                ),
              ),
            const SizedBox(height: 80),
          ],
        );
      }

      // Toggle OFF + belum login → grid 2 kolom
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Disarankan',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                letterSpacing: -0.3,
              ),
            ),
          ),
          _buildDisarankanGrid(filteredData),
          const SizedBox(height: 80),
        ],
      );
    }

    // User sudah login → cek apakah punya langganan
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('langganan')
          .snapshots(),
      builder: (context, subSnapshot) {
        final hasSubscription =
            subSnapshot.hasData && subSnapshot.data!.docs.isNotEmpty;

        final bool useGridLayout =
            !isRealTimeLocationActive && !hasSubscription;

        // ── Hitung item Langganan ─────────────────────────────────────────
        List<QueryDocumentSnapshot> subscribedProducts = [];
        if (hasSubscription) {
          final subscribedUsernames = subSnapshot.data!.docs
              .map((doc) => doc['username'] as String)
              .toList();

          final shouldLimitItems = subscribedUsernames.length > 4;
          final itemsPerUser = shouldLimitItems ? 2 : 999;

          final Map<String, List<QueryDocumentSnapshot>> productsByUser = {};
          for (final username in subscribedUsernames) {
            productsByUser[username] = filteredData
                .where((doc) {
                  final ikan = doc.data() as Map<String, dynamic>;
                  return ikan['username']?.toString() == username;
                })
                .take(itemsPerUser)
                .toList();
          }

          subscribedProducts = productsByUser.values
              .expand((list) => list)
              .toList();
        }

        // ── Render ─────────────────────────────────────────────────────────
        if (useGridLayout) {
          // Grid 2 kolom — toggle OFF dan belum subscribe siapapun
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Disarankan',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              _buildDisarankanGrid(filteredData),
              const SizedBox(height: 80),
            ],
          );
        }

        // Horizontal scroll — toggle ON atau sudah subscribe
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Disarankan — selalu horizontal scroll di sini
            MoreSectionWidget(
              title: 'Disarankan',
              items: filteredData,
              detailBuilder: (id) => DetailScreen(ikanId: id),
              onSeeMore: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DisarankanScreen(items: filteredData),
                ),
              ),
            ),

            // Langganan — tampil jika punya subscription (terlepas toggle)
            if (hasSubscription && subscribedProducts.isNotEmpty)
              MoreSectionWidget(
                title: 'Langganan',
                items: subscribedProducts,
                detailBuilder: (id) => DetailScreen(ikanId: id),
                onSeeMore: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LanggananScreen(items: subscribedProducts),
                  ),
                ),
              ),

            // Terdekat — hanya muncul jika toggle real-time ON dan ada item dalam radius
            if (nearbyItems.isNotEmpty)
              MoreSectionWidget(
                title: 'Terdekat',
                items: nearbyItems,
                detailBuilder: (id) => DetailScreen(ikanId: id),
                onSeeMore: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TerdekatScreen(items: nearbyItems),
                  ),
                ),
              ),

            const SizedBox(height: 80),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF121212)
          : const Color(0xFFF4F6FF),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black,
        automaticallyImplyLeading: false,
        title: Text(
          'WONGIWAK',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            fontWeight: FontWeight.w800,
            fontSize: 22,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
              child: CircleAvatar(
                radius: 19,
                backgroundColor: isDark
                    ? const Color(0xFF2A2A3E)
                    : const Color(0xFFEEF3FF),
                child: Icon(
                  Icons.person_rounded,
                  color: isDark
                      ? const Color(0xFF9BAFFF)
                      : const Color(0xFF6C8EF5),
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF6C8EF5),
        foregroundColor: Colors.white,
        elevation: 4,
        onPressed: () {
          if (FirebaseAuth.instance.currentUser == null) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoginErrorScreen()),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PostScreen(isLogin: true)),
            );
          }
        },
        child: const Icon(Icons.add_rounded, size: 26),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),

              CarouselWidget(
                images: const [
                  'assets/images/Carousel1.png',
                  'assets/images/Carousel2.png',
                  'assets/images/Carousel3.png',
                ],
                height: 180,
              ),
              const SizedBox(height: 16),

              // Search bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: searchController,
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value.toLowerCase();
                    });
                  },
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Cari ikan, kategori, atau lokasi...',
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: isDark
                          ? const Color(0xFF9BAFFF)
                          : const Color(0xFF9E9E9E),
                      size: 20,
                    ),
                    border: InputBorder.none,
                    hintStyle: TextStyle(
                      color: isDark
                          ? Colors.grey.shade600
                          : const Color(0xFFBDBDBD),
                      fontSize: 14,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Kategori chips
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: kategoriOptions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final category = kategoriOptions[index];
                    final bool active = category == selectedCategory;
                    return GestureDetector(
                      onTap: () => setState(() => selectedCategory = category),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? const Color(0xFF6C8EF5)
                              : (isDark
                                    ? const Color(0xFF1E1E1E)
                                    : Colors.white),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: active
                              ? [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF6C8EF5,
                                    ).withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : [],
                          border: Border.all(
                            color: active
                                ? const Color(0xFF6C8EF5)
                                : (isDark
                                      ? Colors.grey.shade700
                                      : Colors.grey.shade200),
                          ),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            color: active
                                ? Colors.white
                                : (isDark
                                      ? Colors.grey.shade400
                                      : const Color(0xFF6B6B80)),
                            fontWeight: active
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 22),

              // Main data stream
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('ikan')
                    .orderBy('created_at', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(
                          color: Color(0xFF6C8EF5),
                        ),
                      ),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Text(
                          'Belum ada data ikan',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    );
                  }

                  final allData = snapshot.data!.docs;

                  final filteredData = allData.where((doc) {
                    final ikan = doc.data() as Map<String, dynamic>;
                    final nama = (ikan['nama']?.toString() ?? '').toLowerCase();
                    final kategori = (ikan['kategori']?.toString() ?? '')
                        .toLowerCase();
                    final lokasi = (ikan['lokasi']?.toString() ?? '')
                        .toLowerCase();
                    final matchesSearch =
                        searchQuery.isEmpty ||
                        nama.contains(searchQuery) ||
                        kategori.contains(searchQuery) ||
                        lokasi.contains(searchQuery);
                    final matchesCategory =
                        selectedCategory == 'Semua' ||
                        kategori == selectedCategory.toLowerCase();
                    return matchesSearch && matchesCategory;
                  }).toList();

                  if (filteredData.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Text(
                          'Tidak ditemukan ikan yang cocok',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    );
                  }

                  return _buildBodyContent(filteredData);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
