import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:wongiwak/screens/detail_screen.dart';

class PerbandinganScreen extends StatefulWidget {
  final String namaIkan;
  final String kategoriIkan;
  final double userLatitude;
  final double userLongitude;
  final String currentIkanId;
  final int currentHarga;

  const PerbandinganScreen({
    super.key,
    required this.namaIkan,
    required this.kategoriIkan,
    required this.userLatitude,
    required this.userLongitude,
    required this.currentIkanId,
    required this.currentHarga,
  });

  @override
  State<PerbandinganScreen> createState() => _PerbandinganScreenState();
}

class _PerbandinganScreenState extends State<PerbandinganScreen> {
  late Future<List<Map<String, dynamic>>> _perbandinganFuture;

  @override
  void initState() {
    super.initState();
    _perbandinganFuture = _fetchPerbandingan();
  }

  Future<List<Map<String, dynamic>>> _fetchPerbandingan() async {
    try {
      // STEP 1: Query Firestore - filter nama dan kategori yang sama
      final snapshot = await FirebaseFirestore.instance
          .collection('ikan')
          .where('nama', isEqualTo: widget.namaIkan)
          .where('kategori', isEqualTo: widget.kategoriIkan)
          .get();

      final List<Map<String, dynamic>> hasil = [];

      // STEP 2: Filter jarak menggunakan Geolocator (client-side)
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final lat = (data['latitude'] as num?)?.toDouble();
        final lng = (data['longitude'] as num?)?.toDouble();

        // Skip jika tidak ada koordinat
        if (lat == null || lng == null) continue;

        // Hitung jarak antara postingan ini dengan postingan yang sedang dilihat
        final jarak = Geolocator.distanceBetween(
          widget.userLatitude,
          widget.userLongitude,
          lat,
          lng,
        );

        // Hanya ambil yang dalam radius 2km (2000 meter)
        if (jarak <= 2000) {
          hasil.add({...data, 'ikanId': doc.id, 'jarak': jarak});
        }
      }

      // STEP 3: Sort berdasarkan harga termurah ke termahal
      hasil.sort((a, b) {
        final hargaA = int.tryParse(a['harga'].toString()) ?? 0;
        final hargaB = int.tryParse(b['harga'].toString()) ?? 0;
        return hargaA.compareTo(hargaB);
      });

      return hasil;
    } catch (e) {
      debugPrint('Error fetching perbandingan: $e');
      rethrow;
    }
  }

  String formatRupiah(dynamic harga) {
    final number = int.tryParse(harga.toString()) ?? 0;
    final format = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return format.format(number);
  }

  Widget buildAvatar(String? gambar) {
    if (gambar != null && gambar.isNotEmpty) {
      try {
        return CircleAvatar(
          radius: 28,
          backgroundImage: MemoryImage(base64Decode(gambar)),
        );
      } catch (e) {
        debugPrint('Error decoding image: $e');
      }
    }
    return CircleAvatar(
      radius: 28,
      backgroundColor: Colors.blue.shade100,
      child: Icon(Icons.storefront, color: Colors.blue),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back, color: Colors.black),
        ),
        automaticallyImplyLeading: false,
        title: const Text(
          'Perbandingan Harga',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _perbandinganFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final hasil = snapshot.data ?? [];

          if (hasil.isEmpty || hasil.length <= 1) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada penjual ${widget.namaIkan} lain\ndalam radius 1km',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          // Cari harga minimum untuk menandai penjual termurah
          final minHarga = hasil
              .where((item) => item['ikanId'] != widget.currentIkanId)
              .fold<int?>(null, (min, item) {
                final harga = int.tryParse(item['harga'].toString()) ?? 0;
                return min == null || harga < min ? harga : min;
              });

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Subtitle
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Membandingkan harga dari penjual terdekat',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'dengan radius 1km',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                // List penjual
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: hasil.length,
                  itemBuilder: (context, index) {
                    final item = hasil[index];
                    final hargaItem =
                        int.tryParse(item['harga'].toString()) ?? 0;
                    final selisih = hargaItem - widget.currentHarga;
                    final isCurrentSeller =
                        item['ikanId'] == widget.currentIkanId;
                    final isCheapest =
                        hargaItem == minHarga && !isCurrentSeller;

                    String? labelText;
                    Color? labelColor;

                    if (!isCurrentSeller) {
                      if (selisih < 0) {
                        labelText =
                            'Harga lebih murah ${formatRupiah(selisih.abs())}';
                        labelColor = Colors.green;
                      } else if (selisih > 0) {
                        labelText =
                            'Harga lebih mahal ${formatRupiah(selisih)}';
                        labelColor = Colors.red;
                      } else {
                        labelText = 'Harga sama';
                        labelColor = Colors.grey;
                      }
                    }

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                DetailScreen(ikanId: item['ikanId']),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: isCurrentSeller
                              ? Border.all(
                                  color: const Color(0xff6C8EF5),
                                  width: 2,
                                )
                              : Border.all(color: Colors.transparent),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Stack(
                                  children: [
                                    buildAvatar(item['gambar']),
                                    if (isCheapest)
                                      Positioned(
                                        top: -2,
                                        right: -2,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '${item['nama']} / Kg',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isCheapest)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                'Termurah',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.green.shade700,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        formatRupiah(hargaItem),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Color(0xff6C8EF5),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      if (labelText != null)
                                        Text(
                                          labelText,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: labelColor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        )
                                      else if (isCurrentSeller)
                                        Text(
                                          'Penjual saat ini',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: const Color(0xff6C8EF5),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item['alamat'] ??
                                            'Alamat tidak tersedia',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${(item['jarak'] as double).toStringAsFixed(0)} m dari Anda',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade500,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (isCurrentSeller) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xff6C8EF5,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Penjual saat ini',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xff6C8EF5),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}
