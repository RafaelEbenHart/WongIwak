import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:wongiwak/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late User? currentUser;
  late TextEditingController usernameController;
  late TextEditingController locationController;
  late TextEditingController occupationController;
  late TextEditingController alamatController;

  XFile? selectedImage;
  Uint8List? selectedImageBytes;
  bool isUploading = false;
  bool isLoadingAlamat = false;
  double? latitude;
  double? longitude;
  bool isRealTimeLocationActive = false;
  bool isDarkMode = false;
  StreamSubscription? _locationStream;

  @override
  void initState() {
    super.initState();
    currentUser = FirebaseAuth.instance.currentUser;
    usernameController = TextEditingController();
    locationController = TextEditingController();
    occupationController = TextEditingController();
    alamatController = TextEditingController();
    _loadDarkModePreference();
    _loadUserData();
  }

  void _loadDarkModePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDarkMode') ?? false;
    setState(() => isDarkMode = isDark);
  }

  @override
  void dispose() {
    _stopLocationStream();
    usernameController.dispose();
    locationController.dispose();
    occupationController.dispose();
    alamatController.dispose();
    super.dispose();
  }

  void _loadUserData() async {
    if (currentUser != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .get();

        if (doc.exists) {
          final data = doc.data();

          if (mounted) {
            setState(() {
              usernameController.text = data?['username'] ?? '';
              locationController.text = data?['location'] ?? '';
              occupationController.text =
                  data?['occupation'] ?? 'Penjual ikan segar';
              alamatController.text = data?['alamat'] ?? '';
              latitude = data?['latitude'] as double?;
              longitude = data?['longitude'] as double?;
              isRealTimeLocationActive = data?['isRealTimeLocation'] ?? false;
            });
          }

          // Jika sebelumnya aktif, langsung nyalakan stream lagi
          if (isRealTimeLocationActive) {
            _startLocationStream();
          }
        }
      } catch (e) {
        debugPrint('Error loading user data: $e');
      }
    }
  }

  void _stopLocationStream() {
    _locationStream?.cancel();
    _locationStream = null;
  }

  Future<void> _startLocationStream() async {
    try {
      debugPrint('📍 SETTINGS: Starting location stream...');

      // Cek & minta izin dulu
      LocationPermission permission = await Geolocator.checkPermission();
      debugPrint('📍 SETTINGS: Permission status = $permission');

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        debugPrint('📍 SETTINGS: Permission requested = $permission');
        if (permission == LocationPermission.denied) {
          _showSnackBar('Izin lokasi ditolak');
          setState(() => isRealTimeLocationActive = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackBar('Izin lokasi ditolak permanen. Cek pengaturan aplikasi');
        setState(() => isRealTimeLocationActive = false);
        return;
      }

      // Ambil posisi pertama kali langsung
      try {
        final initialPosition = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
          ),
        );

        debugPrint(
          '📍 SETTINGS: Initial position = lat=${initialPosition.latitude}, lng=${initialPosition.longitude}',
        );

        if (currentUser != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser!.uid)
              .update({
                'realTimeLatitude': initialPosition.latitude,
                'realTimeLongitude': initialPosition.longitude,
              });
          debugPrint('✅ SETTINGS: Saved initial position to Firestore');
        }
      } catch (e) {
        debugPrint('❌ SETTINGS: Error mengambil posisi awal: $e');
      }

      // Mulai stream — update setiap pindah 200 meter
      _locationStream =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              distanceFilter: 200,
            ),
          ).listen((Position position) async {
            try {
              debugPrint(
                '📍 SETTINGS: Position stream update = lat=${position.latitude}, lng=${position.longitude}',
              );

              // Konversi koordinat → nama kota
              final placemarks = await placemarkFromCoordinates(
                position.latitude,
                position.longitude,
              );

              if (placemarks.isNotEmpty) {
                final place = placemarks.first;
                final kota = place.locality ?? '';
                final provinsi = place.administrativeArea ?? '';
                final lokasiSingkat = kota.isNotEmpty || provinsi.isNotEmpty
                    ? '$kota, $provinsi'.replaceAll(RegExp(', \$'), '').trim()
                    : '';

                if (currentUser != null) {
                  // Update field "location" dan koordinat real-time ke Firestore
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUser!.uid)
                      .update({
                        'location': lokasiSingkat,
                        'realTimeLatitude': position.latitude,
                        'realTimeLongitude': position.longitude,
                      });

                  if (mounted) {
                    setState(() => locationController.text = lokasiSingkat);
                  }
                }
              }
            } catch (e) {
              debugPrint('Error di location stream: $e');
            }
          });
    } catch (e) {
      _showSnackBar('Gagal memulai lacak lokasi real-time');
      debugPrint('Error start location stream: $e');
      setState(() => isRealTimeLocationActive = false);
    }
  }

  Future<void> _toggleRealTimeLocation(bool value) async {
    debugPrint('🔘 SETTINGS: Toggle real-time location = $value');

    setState(() => isRealTimeLocationActive = value);

    if (currentUser == null) {
      _showSnackBar('User tidak login');
      debugPrint('❌ SETTINGS: User not logged in');
      return;
    }

    try {
      // Simpan status toggle ke Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .update({'isRealTimeLocation': value});

      debugPrint('✅ SETTINGS: Saved isRealTimeLocation=$value to Firestore');

      if (value) {
        debugPrint('🔄 SETTINGS: Starting location stream...');
        await _startLocationStream();
        _showSnackBar('Lacak lokasi real-time diaktifkan');
      } else {
        debugPrint('🛑 SETTINGS: Stopping location stream...');
        _stopLocationStream();
        _showSnackBar('Lacak lokasi real-time dimatikan');
      }
    } catch (e) {
      debugPrint('❌ SETTINGS: Error: $e');
      _showSnackBar('Error mengubah pengaturan: $e');
      setState(() => isRealTimeLocationActive = !value);
    }
  }

  Future<void> _ambilAlamatDariGPS() async {
    setState(() => isLoadingAlamat = true);

    try {
      // 1. Cek Service & Permission GPS
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar(
          'Layanan lokasi (GPS) tidak aktif. Silakan nyalakan dulu.',
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar('Izin lokasi ditolak');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackBar('Izin lokasi ditolak permanen. Cek pengaturan aplikasi');
        return;
      }

      // 2. Ambil Titik Koordinat
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // Simpan koordinat ke variabel lokal
      latitude = position.latitude;
      longitude = position.longitude;

      // Simpan koordinat ke Firebase segera
      if (currentUser != null) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser!.uid)
              .update({'latitude': latitude, 'longitude': longitude});
        } catch (e) {
          debugPrint('Error menyimpan koordinat ke Firebase: $e');
        }
      }

      // 3. Terjemahkan Koordinat Menjadi Alamat (Bagian Rawan Null)
      List<Placemark> placemarks = [];
      try {
        placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
      } catch (geocodingError) {
        // Jika geocoding bawaan HP/Emulator gagal, kita tangkap disini agar tidak crash
        debugPrint('Geocoding error: $geocodingError');
        _showSnackBar(
          'Koordinat didapat, tapi gagal menerjemahkan nama jalan.',
        );
        return;
      }

      // 4. Susun Alamat dengan Sangat Aman
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final List<String> alamatList = [];

        // Cek satu-satu dengan pasti kalau datanya tidak null dan tidak kosong
        if (place.street != null && place.street!.trim().isNotEmpty) {
          alamatList.add(place.street!.trim());
        }
        if (place.subLocality != null && place.subLocality!.trim().isNotEmpty) {
          alamatList.add(place.subLocality!.trim());
        }
        if (place.locality != null && place.locality!.trim().isNotEmpty) {
          alamatList.add(place.locality!.trim());
        }
        if (place.subAdministrativeArea != null &&
            place.subAdministrativeArea!.trim().isNotEmpty) {
          alamatList.add(place.subAdministrativeArea!.trim());
        }
        if (place.administrativeArea != null &&
            place.administrativeArea!.trim().isNotEmpty) {
          alamatList.add(place.administrativeArea!.trim());
        }

        final alamatLengkap = alamatList.join(', ');

        if (alamatLengkap.isNotEmpty) {
          setState(() => alamatController.text = alamatLengkap);
          _showSnackBar(
            'Alamat & Koordinat (${latitude?.toStringAsFixed(4)}, ${longitude?.toStringAsFixed(4)}) berhasil disimpan',
          );
        } else {
          // Jaga-jaga kalau semua field alamat dari satelit nilainya kosong
          setState(
            () => alamatController.text =
                '${position.latitude}, ${position.longitude}',
          );
          _showSnackBar(
            'Hanya koordinat (${latitude?.toStringAsFixed(4)}, ${longitude?.toStringAsFixed(4)}) yang disimpan',
          );
        }
      } else {
        _showSnackBar('Alamat tidak ditemukan di titik ini');
      }
    } catch (e) {
      _showSnackBar('Gagal mengambil lokasi. Cek koneksi & GPS.');
      debugPrint('Error detail GPS Utama: $e');
    } finally {
      if (mounted) setState(() => isLoadingAlamat = false);
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 40,
      maxWidth: 600,
      maxHeight: 600,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      if (bytes.length > 800000) {
        _showSnackBar(
          'Ukuran gambar terlalu besar. Pilih gambar maksimal 1MB.',
        );
        return;
      }
      setState(() {
        selectedImage = image;
        selectedImageBytes = bytes;
      });
    }
  }

  void _saveProfile() async {
    if (currentUser == null) {
      _showSnackBar('User tidak login');
      return;
    }

    if (usernameController.text.isEmpty) {
      _showSnackBar('Username harus diisi');
      return;
    }

    setState(() => isUploading = true);

    try {
      Map<String, dynamic> updateData = {
        'username': usernameController.text.trim(),
        'location': locationController.text.trim(),
        'occupation': occupationController.text.trim(),
        'alamat': alamatController.text.trim(),
      };

      // Jika ada koordinat yang tersimpan, sertakan dalam update
      if (latitude != null && longitude != null) {
        updateData['latitude'] = latitude;
        updateData['longitude'] = longitude;
      }

      if (selectedImageBytes != null) {
        try {
          updateData['profileImageBytes'] = Blob(selectedImageBytes!);
        } catch (imageError) {
          _showSnackBar('Error gambar: $imageError');
        }
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .update(updateData);

      if (mounted) {
        _showSuccessDialog(
          'Perubahan Disimpan!',
          'Profil Anda telah berhasil diperbarui.',
        );
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            setState(() {
              selectedImage = null;
              selectedImageBytes = null;
            });
            Navigator.pop(context);
          }
        });
      }
    } catch (e) {
      _showSnackBar('Error menyimpan profil: $e');
    } finally {
      if (mounted) setState(() => isUploading = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showSuccessDialog(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Check Icon dengan Animasi
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 600),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF5E7AC4).withOpacity(0.8),
                              const Color(0xFF5E7AC4),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF5E7AC4).withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                // Judul
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                // Deskripsi
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );

    // Auto-close setelah 1.5 detik
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      appBar: AppBar(
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        automaticallyImplyLeading: false,
        title: Text(
          'Pengaturan Profil',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF5E7AC4),
                              width: 3,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 60,
                            backgroundColor: isDark
                                ? const Color(0xFF2A2A2A)
                                : Colors.grey.shade200,
                            backgroundImage: selectedImageBytes != null
                                ? MemoryImage(selectedImageBytes!)
                                : null,
                            child: selectedImageBytes == null
                                ? Icon(
                                    Icons.person,
                                    size: 60,
                                    color: isDark
                                        ? Colors.grey.shade600
                                        : Colors.grey.shade400,
                                  )
                                : null,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF5E7AC4),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Ubah Foto Profil',
                      style: TextStyle(
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Informasi Profil',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 20),
              _buildTextField(
                label: 'Username',
                controller: usernameController,
                hintText: 'Masukkan username Anda',
              ),
              const SizedBox(height: 16),
              _buildTextField(
                label: 'Pekerjaan/Deskripsi',
                controller: occupationController,
                hintText: 'Misal: Penjual ikan segar',
              ),
              const SizedBox(height: 16),
              _buildTextField(
                label: 'Lokasi (Kota)',
                controller: locationController,
                hintText: 'Masukkan kota/lokasi Anda',
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Alamat Lengkap',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFF9BAFFF)
                          : const Color(0xFF5E7AC4),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: alamatController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText: 'Alamat akan terisi otomatis dari GPS',
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF2A2A3E)
                                : Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: isDark
                                    ? const Color(0xFF444444)
                                    : Colors.grey.shade200,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: isDark
                                    ? const Color(0xFF444444)
                                    : Colors.grey.shade200,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Color(0xFF5E7AC4),
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            hintStyle: TextStyle(
                              color: isDark
                                  ? Colors.grey.shade600
                                  : Colors.grey.shade400,
                            ),
                          ),
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: isLoadingAlamat ? null : _ambilAlamatDariGPS,
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFF5E7AC4),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: isLoadingAlamat
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.my_location,
                                  color: Colors.white,
                                  size: 22,
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 13,
                        color: isDark ? Colors.grey.shade600 : Colors.black38,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Tekan icon GPS untuk mengisi alamat otomatis',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.grey.shade600
                              : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Toggle Lacak Lokasi Real-time
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF444444)
                        : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_searching,
                      color: isDark
                          ? const Color(0xFF9BAFFF)
                          : const Color(0xFF5E7AC4),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lacak Lokasi Real-time',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'Perbarui kota/lokasi otomatis saat berpindah tempat',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: isRealTimeLocationActive,
                      onChanged: _toggleRealTimeLocation,
                      activeColor: const Color(0xFF5E7AC4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Toggle Dark Mode
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF444444)
                        : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.dark_mode_rounded,
                      color: isDark
                          ? const Color(0xFF9BAFFF)
                          : const Color(0xFF5E7AC4),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mode Gelap',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          Text(
                            'Aktifkan tampilan gelap untuk mengurangi kelelahan mata',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.grey.shade500
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: isDarkMode,
                      onChanged: (value) {
                        setState(() => isDarkMode = value);
                        AppTheme.setDarkMode(value);
                      },
                      activeColor: const Color(0xFF5E7AC4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isUploading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5E7AC4),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                  child: isUploading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Simpan Perubahan',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      selectedImage = null;
                      selectedImageBytes = null;
                    });
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFF5E7AC4)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Batal',
                    style: TextStyle(
                      color: Color(0xFF5E7AC4),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hintText,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF5E7AC4),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: isDark ? const Color(0xFF2A2A3E) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF444444) : Colors.grey.shade200,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF444444) : Colors.grey.shade200,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF5E7AC4), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            hintStyle: TextStyle(
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
            ),
          ),
        ),
      ],
    );
  }
}
