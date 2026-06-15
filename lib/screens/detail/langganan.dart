import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../detail_screen.dart';

class LanggananScreen extends StatelessWidget {
  final List<QueryDocumentSnapshot> items;

  const LanggananScreen({super.key, required this.items});

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
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF121212)
          : const Color(0xFFF4F6FF),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : const Color(0xFF1A1A2E),
        title: Text(
          'Langganan',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            letterSpacing: -0.4,
          ),
        ),
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 16,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ),
      ),
      body: items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF3FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.bookmark_outline_rounded,
                      size: 36,
                      color: Color(0xFF6C8EF5),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Belum ada langganan',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Ikuti penjual favoritmu untuk\nmelihat produk terbaru mereka',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF9E9E9E),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.88,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final doc = items[index];
                  final ikan = doc.data() as Map<String, dynamic>;
                  return _GridFishCard(
                    doc: doc,
                    ikan: ikan,
                    formatCurrency: _formatCurrency,
                  );
                },
              ),
            ),
    );
  }
}

class _GridFishCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final Map<String, dynamic> ikan;
  final Function(String) formatCurrency;

  const _GridFishCard({
    required this.doc,
    required this.ikan,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
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
          children: [
            Expanded(
              flex: 62,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(14),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: gambarString.isNotEmpty
                          ? Image.memory(
                              base64Decode(gambarString),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _buildPlaceholder(isDark),
                            )
                          : _buildPlaceholder(isDark),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C8EF5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bookmark_rounded,
                            size: 9,
                            color: Colors.white,
                          ),
                          SizedBox(width: 3),
                          Text(
                            'Langganan',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 38,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                    Text(
                      'Rp ${formatCurrency(harga)}',
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(bool isDark) {
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
}
