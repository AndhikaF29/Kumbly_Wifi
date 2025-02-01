import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

class TagihanService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> generateTagihanBulanan() async {
    try {
      final pelangganSnapshot = await _firestore
          .collection('pelanggan')
          .where('status', isEqualTo: 'Aktif')
          .get();

      if (pelangganSnapshot.docs.isEmpty) {
        throw 'Tidak ada pelanggan aktif';
      }

      final now = DateTime.now();
      final periodeTagihan = DateTime(now.year, now.month);
      final periodeName =
          DateFormat('MMMM yyyy', 'id_ID').format(periodeTagihan);

      final batch = _firestore.batch();
      int tagihanCount = 0;
      List<String> pelangganSudahAda = [];
      List<String> pelangganBerhasilDibuat = [];

      for (var pelanggan in pelangganSnapshot.docs) {
        final pelangganData = pelanggan.data();

        // Cek tagihan yang sudah ada
        final existingTagihan = await _firestore
            .collection('tagihan')
            .where('pelangganId', isEqualTo: pelanggan.id)
            .where('periode', isEqualTo: periodeName)
            .get();

        if (existingTagihan.docs.isEmpty) {
          // Buat tagihan baru jika belum ada
          final tagihanRef = _firestore.collection('tagihan').doc();
          batch.set(tagihanRef, {
            'pelangganId': pelanggan.id,
            'nama_pelanggan': pelangganData['nama'] ?? 'Nama tidak tersedia',
            'jumlah': pelangganData['biayaBulanan'] ?? 0,
            'paket': pelangganData['paket'] ?? 'Paket tidak tersedia',
            'tanggal': Timestamp.fromDate(periodeTagihan),
            'status': 'Belum dibayar',
            'periode': periodeName,
            'createdAt': FieldValue.serverTimestamp(),
          });
          tagihanCount++;
          pelangganBerhasilDibuat
              .add(pelangganData['nama'] ?? 'Nama tidak tersedia');
        } else {
          pelangganSudahAda.add(pelangganData['nama'] ?? 'Nama tidak tersedia');
        }
      }

      if (tagihanCount > 0) {
        await batch.commit();
      }

      return {
        'berhasil': pelangganBerhasilDibuat,
        'sudahAda': pelangganSudahAda,
        'totalBerhasil': tagihanCount,
        'totalSudahAda': pelangganSudahAda.length,
        'periode': periodeName,
      };
    } catch (e) {
      debugPrint('Error generating tagihan: $e');
      rethrow;
    }
  }

  Future<void> tambahTagihanManual({
    required String namaPelanggan,
    required String pelangganId,
    required int jumlah,
    required String paket,
    String? status,
  }) async {
    try {
      final now = DateTime.now();
      final periodeTagihan = DateTime(now.year, now.month, 1);
      final periodeName =
          DateFormat('MMMM yyyy', 'id_ID').format(periodeTagihan);

      // Cek duplikasi
      final existingTagihan = await _firestore
          .collection('tagihan')
          .where('pelangganId', isEqualTo: pelangganId)
          .where('periode', isEqualTo: periodeName)
          .get();

      if (existingTagihan.docs.isNotEmpty) {
        throw 'Tagihan untuk pelanggan ini di periode $periodeName sudah ada';
      }

      await _firestore.collection('tagihan').add({
        'createdAt': FieldValue.serverTimestamp(),
        'jumlah': jumlah,
        'nama_pelanggan': namaPelanggan,
        'paket': paket,
        'pelangganId': pelangganId,
        'periode': periodeName,
        'status': status ?? 'Belum dibayar',
        'tanggal': Timestamp.fromDate(periodeTagihan),
      });
    } catch (e) {
      debugPrint('Error tambah tagihan manual: $e');
      rethrow;
    }
  }
}
