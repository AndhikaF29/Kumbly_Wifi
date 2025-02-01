import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../login_screen.dart';
import '../../theme/app_theme.dart';
import 'detail_tagihan_petugas_screen.dart';

class PetugasHomeScreen extends StatefulWidget {
  const PetugasHomeScreen({super.key});

  @override
  State<PetugasHomeScreen> createState() => _PetugasHomeScreenState();
}

class _PetugasHomeScreenState extends State<PetugasHomeScreen> {
  String _searchQuery = '';
  String _filterStatus = 'semua';

  Future<void> _updateStatusTagihan(String tagihanId, String statusBaru) async {
    try {
      if (statusBaru == 'Sudah dibayar') {
        // Tampilkan dialog input jumlah pembayaran
        final double? jumlahBayar = await _showPaymentInputDialog(tagihanId);
        if (jumlahBayar == null) return; // Batalkan jika user cancel

        final tagihanDoc = await FirebaseFirestore.instance
            .collection('tagihan')
            .doc(tagihanId)
            .get();
        final tagihanData = tagihanDoc.data() as Map<String, dynamic>;
        final double totalTagihan = (tagihanData['jumlah'] ?? 0).toDouble();
        final double totalSebelumnya =
            (tagihanData['totalDibayar'] ?? 0).toDouble();
        final double totalSetelahBayar = totalSebelumnya + jumlahBayar;

        // Hitung sisa dan status pembayaran
        final double sisaTagihan = totalTagihan - totalSetelahBayar;
        final String statusPembayaran = totalSetelahBayar >= totalTagihan
            ? 'Sudah dibayar'
            : 'Bayar Sebagian';

        // Data untuk update tagihan
        final updateData = {
          'status': statusPembayaran,
          'tanggalBayar': Timestamp.now(),
          'jumlahDibayar': jumlahBayar,
          'sisaTagihan': sisaTagihan,
          'totalDibayar': totalSetelahBayar,
          'riwayatPembayaran': FieldValue.arrayUnion([
            {
              'tanggal': Timestamp.now(),
              'jumlah': jumlahBayar,
              'petugasId': FirebaseAuth.instance.currentUser?.uid,
            }
          ]),
        };

        await FirebaseFirestore.instance
            .collection('tagihan')
            .doc(tagihanId)
            .update(updateData);

        // Tambahkan riwayat pembayaran
        await FirebaseFirestore.instance.collection('riwayat_pembayaran').add({
          'tagihanId': tagihanId,
          'pelangganId': tagihanData['pelangganId'],
          'tanggalBayar': Timestamp.now(),
          'jumlahBayar': jumlahBayar,
          'totalTagihan': totalTagihan,
          'sisaTagihan': sisaTagihan,
          'statusPembayaran': statusPembayaran,
          'metodePembayaran': 'Tunai',
          'petugasId': FirebaseAuth.instance.currentUser?.uid,
          'periode': tagihanData['periode'],
          'keterangan': statusPembayaran == 'Sudah dibayar'
              ? 'Pembayaran Lunas'
              : 'Pembayaran Sebagian (Sisa: ${NumberFormat.currency(
                  locale: 'id_ID',
                  symbol: 'Rp ',
                  decimalDigits: 0,
                ).format(sisaTagihan)})',
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(statusPembayaran == 'Sudah dibayar'
                  ? 'Pembayaran lunas berhasil dicatat'
                  : 'Pembayaran sebagian berhasil dicatat (Sisa: ${NumberFormat.currency(
                      locale: 'id_ID',
                      symbol: 'Rp ',
                      decimalDigits: 0,
                    ).format(sisaTagihan)})'),
              backgroundColor: statusPembayaran == 'Sudah dibayar'
                  ? Colors.green
                  : Colors.orange,
            ),
          );
        }
      } else {
        // Logika untuk status Belum dibayar
        final updateData = {
          'status': statusBaru,
          'tanggalBayar': null,
          'jumlahDibayar': 0,
          'sisaTagihan': null,
          'totalDibayar': 0,
          'riwayatPembayaran': [],
        };

        await FirebaseFirestore.instance
            .collection('tagihan')
            .doc(tagihanId)
            .update(updateData);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<double?> _showPaymentInputDialog(String tagihanId) async {
    final TextEditingController paymentController = TextEditingController();
    final tagihanDoc = await FirebaseFirestore.instance
        .collection('tagihan')
        .doc(tagihanId)
        .get();
    final tagihanData = tagihanDoc.data() as Map<String, dynamic>;
    final double totalTagihan = (tagihanData['jumlah'] ?? 0).toDouble();
    final double? sisaTagihan =
        (tagihanData['sisaTagihan'] ?? totalTagihan).toDouble();

    String formatNumber(String value) {
      if (value.isEmpty) return '';
      value = value.replaceAll('.', '');
      final number = int.tryParse(value) ?? 0;
      return NumberFormat('#,###', 'id_ID').format(number);
    }

    return showDialog<double>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.payment_rounded,
                        size: 40,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Input Pembayaran',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(thickness: 1),
                const SizedBox(height: 10),

                // Info Tagihan
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Tagihan:',
                            style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            NumberFormat.currency(
                              locale: 'id_ID',
                              symbol: 'Rp ',
                              decimalDigits: 0,
                            ).format(totalTagihan),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      if (sisaTagihan != totalTagihan) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Sisa Tagihan:',
                              style: TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              NumberFormat.currency(
                                locale: 'id_ID',
                                symbol: 'Rp ',
                                decimalDigits: 0,
                              ).format(sisaTagihan),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[700],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Input Field
                TextField(
                  controller: paymentController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Jumlah Pembayaran',
                    prefixText: 'Rp ',
                    hintText: '1.000.000',
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppTheme.primaryColor),
                    ),
                  ),
                  onChanged: (value) {
                    final formatted = formatNumber(value);
                    paymentController.value = TextEditingValue(
                      text: formatted,
                      selection:
                          TextSelection.collapsed(offset: formatted.length),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Batal',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          final payment = double.tryParse(paymentController.text
                              .replaceAll(RegExp(r'[^0-9]'), ''));
                          if (payment != null && payment > 0) {
                            Navigator.of(context).pop(payment);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Masukkan jumlah pembayaran yang valid'),
                              ),
                            );
                          }
                        },
                        child: const Text(
                          'Simpan',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool?> _showConfirmationDialog(
      BuildContext context, String tagihanId, bool newStatus) {
    final status = newStatus ? 'Sudah dibayar' : 'Belum dibayar';

    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Konfirmasi ${newStatus ? 'Pembayaran' : 'Pembatalan'}'),
          content: Text(
              'Apakah Anda yakin ingin mengubah status tagihan menjadi "$status"?'),
          actions: [
            TextButton(
              child: const Text('Batal'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: Text(
                'Ya, ${newStatus ? 'Tandai Dibayar' : 'Batalkan'}',
                style: TextStyle(
                  color: newStatus ? Colors.green : Colors.orange,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _showLogoutConfirmation() {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Konfirmasi Keluar'),
          content: const Text('Apakah Anda yakin ingin keluar dari aplikasi?'),
          actions: [
            TextButton(
              child: const Text('Batal'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text(
                'Keluar',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFinancialSummary(List<QueryDocumentSnapshot> tagihan) {
    double totalHarusDibayar = 0;
    double totalSudahDibayar = 0;
    int sudahBayar = tagihan.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['status'] == 'Sudah dibayar';
    }).length;
    int bayarSebagian = tagihan.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['status'] == 'Bayar Sebagian';
    }).length;
    int belumBayar = tagihan.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['status'] == 'Belum dibayar';
    }).length;

    for (var doc in tagihan) {
      final data = doc.data() as Map<String, dynamic>;
      final jumlah = (data['jumlah'] ?? 0).toDouble();
      totalHarusDibayar += jumlah;
      totalSudahDibayar += (data['totalDibayar'] ?? 0).toDouble();
    }

    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 0,
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: Colors.green, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '$sudahBayar\nLunas',
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.2,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 0,
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.incomplete_circle,
                          color: Colors.orange[700], size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '$bayarSebagian\nSebagian',
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.2,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 0,
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.pending, color: Colors.orange, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '$belumBayar\nBelum',
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.2,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF6A1B9A),
                  Color(0xFF8E24AA),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Pendapatan yang Harus Terkumpul',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatter.format(totalHarusDibayar),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle,
                          color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Terkumpul ${formatter.format(totalSudahDibayar)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.logout, color: Colors.white),
          onPressed: () async {
            bool? confirm = await _showLogoutConfirmation();
            if (confirm == true) {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              }
            }
          },
        ),
        title: const Text(
          'Detail Tagihan',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            color: AppTheme.secondaryColor,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // Search Bar
                  TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Cari nama pelanggan...',
                      hintStyle: TextStyle(
                          color: const Color.fromARGB(255, 24, 23, 23)),
                      prefixIcon: const Icon(Icons.search,
                          color: AppTheme.primaryColor),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppTheme.primaryColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Filter Status
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _filterStatus,
                        icon: const Icon(Icons.filter_list,
                            color: AppTheme.primaryColor),
                        items: const [
                          DropdownMenuItem(
                            value: 'semua',
                            child: Text('Semua Status'),
                          ),
                          DropdownMenuItem(
                            value: 'Sudah dibayar',
                            child: Text('Sudah Dibayar'),
                          ),
                          DropdownMenuItem(
                            value: 'Bayar Sebagian',
                            child: Text('Bayar Sebagian'),
                          ),
                          DropdownMenuItem(
                            value: 'Belum dibayar',
                            child: Text('Belum Dibayar'),
                          ),
                        ],
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() => _filterStatus = newValue);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance.collection('tagihan').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                var tagihan = snapshot.data?.docs ?? [];

                // Filter berdasarkan status
                if (_filterStatus != 'semua') {
                  tagihan = tagihan.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return data['status'] == _filterStatus;
                  }).toList();
                }

                // Filter berdasarkan pencarian
                if (_searchQuery.isNotEmpty) {
                  return FutureBuilder<List<QueryDocumentSnapshot?>>(
                    future: Future.wait<QueryDocumentSnapshot?>(
                      tagihan.map((doc) async {
                        final data = doc.data() as Map<String, dynamic>;
                        final pelangganDoc = await FirebaseFirestore.instance
                            .collection('pelanggan')
                            .doc(data['pelangganId'])
                            .get();
                        final pelangganData = pelangganDoc.data();
                        final nama = (pelangganData?['nama'] ?? '')
                            .toString()
                            .toLowerCase();
                        return nama.contains(_searchQuery.toLowerCase())
                            ? doc
                            : null;
                      }),
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final filteredTagihan = snapshot.data
                              ?.where((doc) => doc != null)
                              .cast<QueryDocumentSnapshot>()
                              .toList() ??
                          [];

                      return Column(
                        children: [
                          _buildFinancialSummary(filteredTagihan),
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: filteredTagihan.length,
                              itemBuilder: (context, index) {
                                final data = filteredTagihan[index].data()
                                    as Map<String, dynamic>;
                                final tagihanId = filteredTagihan[index].id;
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            DetailTagihanScreen(
                                          tagihanId: tagihanId,
                                          tagihanData: data,
                                        ),
                                      ),
                                    );
                                  },
                                  child: _buildTagihanCard(data, tagihanId),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  );
                }

                return Column(
                  children: [
                    _buildFinancialSummary(tagihan),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: tagihan.length,
                        itemBuilder: (context, index) {
                          final data =
                              tagihan[index].data() as Map<String, dynamic>;
                          final tagihanId = tagihan[index].id;
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DetailTagihanScreen(
                                    tagihanId: tagihanId,
                                    tagihanData: data,
                                  ),
                                ),
                              );
                            },
                            child: _buildTagihanCard(data, tagihanId),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagihanCard(Map<String, dynamic> tagihanData, String tagihanId) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('pelanggan')
          .doc(tagihanData['pelangganId'])
          .get(),
      builder: (context, snapshotPelanggan) {
        if (snapshotPelanggan.connectionState == ConnectionState.waiting) {
          return Card(
            elevation: 3,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const ListTile(
              title: Text('Memuat data...'),
            ),
          );
        }

        final pelangganData =
            snapshotPelanggan.data?.data() as Map<String, dynamic>?;
        final formatter = NumberFormat.currency(
          locale: 'id_ID',
          symbol: 'Rp ',
          decimalDigits: 0,
        );

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                spreadRadius: 1,
                blurRadius: 1,
                offset: const Offset(6, 6),
              ),
              BoxShadow(
                color: Colors.grey.withOpacity(0.25),
                spreadRadius: 3,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            leading: CircleAvatar(
              backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
              child: Text(
                (pelangganData?['nama'] ?? '?')[0].toUpperCase(),
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              pelangganData?['nama'] ?? 'Nama tidak tersedia',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${tagihanData['periode'] ?? '-'} • ${formatter.format(tagihanData['jumlah'] ?? 0)}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
                if (tagihanData['status'] == 'Bayar Sebagian')
                  Text(
                    'Sisa: ${formatter.format(tagihanData['sisaTagihan'] ?? 0)}',
                    style: TextStyle(
                      color: Colors.orange[700],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: tagihanData['status'] == 'Sudah dibayar'
                        ? const Color(0xFFF5F9F7)
                        : tagihanData['status'] == 'Bayar Sebagian'
                            ? const Color(0xFFFFF3E0)
                            : const Color(0xFFFDF4ED),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tagihanData['status'] == 'Sudah dibayar'
                        ? 'Lunas'
                        : tagihanData['status'] == 'Bayar Sebagian'
                            ? 'Sebagian'
                            : 'Belum',
                    style: TextStyle(
                      color: tagihanData['status'] == 'Sudah dibayar'
                          ? const Color(0xFF2E7D32)
                          : tagihanData['status'] == 'Bayar Sebagian'
                              ? Colors.orange[800]
                              : const Color(0xFFE65100),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: tagihanData['status'] == 'Sudah dibayar',
                  onChanged: (bool value) async {
                    bool? shouldUpdate = await _showConfirmationDialog(
                      context,
                      tagihanId,
                      value,
                    );
                    if (shouldUpdate == true) {
                      await _updateStatusTagihan(
                        tagihanId,
                        value ? 'Sudah dibayar' : 'Belum dibayar',
                      );
                    }
                  },
                  activeColor: const Color(0xFF2E7D32),
                  inactiveTrackColor: const Color(0xFFFFE0B2),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Tambah fungsi untuk cek koneksi Firestore
  Future<void> _checkFirestoreConnection() async {
    try {
      final result =
          await FirebaseFirestore.instance.collection('tagihan').limit(1).get();
      print('Firestore test connection: ${result.docs.length} documents found');
    } catch (e) {
      print('Firestore connection error: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _checkFirestoreConnection();
  }
}
