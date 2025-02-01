import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

class DetailTagihanScreen extends StatelessWidget {
  final String tagihanId;
  final Map<String, dynamic> tagihanData;

  const DetailTagihanScreen({
    super.key,
    required this.tagihanId,
    required this.tagihanData,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Tagihan',
            style: TextStyle(color: Color.fromARGB(255, 255, 255, 255))),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('pelanggan')
            .doc(tagihanData['pelangganId'])
            .get(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final pelangganData = snapshot.data?.data() as Map<String, dynamic>?;

          return Stack(
            children: [
              Container(
                height: 100,
                color: AppTheme.primaryColor,
              ),
              SingleChildScrollView(
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 2,
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Status Section dengan Informasi Pembayaran
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _getStatusColor(tagihanData['status']),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _getStatusIcon(tagihanData['status']),
                                      color: _getStatusTextColor(
                                          tagihanData['status']),
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      tagihanData['status'] ?? 'Belum dibayar',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: _getStatusTextColor(
                                            tagihanData['status']),
                                      ),
                                    ),
                                  ],
                                ),
                                if (tagihanData['status'] ==
                                    'Bayar Sebagian') ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Sisa: ${formatter.format(tagihanData['sisaTagihan'] ?? 0)}',
                                    style: TextStyle(
                                      color: _getStatusTextColor(
                                          tagihanData['status']),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // Informasi Pembayaran Section
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Informasi Pembayaran',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildPaymentInfoRow(
                                  'Total Tagihan',
                                  formatter.format(tagihanData['jumlah'] ?? 0),
                                  bold: true,
                                ),
                                const SizedBox(height: 8),
                                _buildPaymentInfoRow(
                                  'Sudah Dibayar',
                                  formatter
                                      .format(tagihanData['totalDibayar'] ?? 0),
                                  textColor: Colors.green[700],
                                ),
                                if (tagihanData['status'] ==
                                    'Bayar Sebagian') ...[
                                  const SizedBox(height: 8),
                                  _buildPaymentInfoRow(
                                    'Sisa Tagihan',
                                    formatter.format(
                                        tagihanData['sisaTagihan'] ?? 0),
                                    textColor: Colors.orange[700],
                                  ),
                                ],
                                const SizedBox(height: 8),
                                if (tagihanData['tanggalBayar'] != null)
                                  _buildPaymentInfoRow(
                                    'Tanggal Pembayaran Terakhir',
                                    DateFormat('dd MMMM yyyy, HH:mm').format(
                                      (tagihanData['tanggalBayar'] as Timestamp)
                                          .toDate(),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),

                          // Riwayat Pembayaran Section
                          if ((tagihanData['riwayatPembayaran'] as List?)
                                  ?.isNotEmpty ??
                              false) ...[
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Riwayat Pembayaran',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ...List.generate(
                                    (tagihanData['riwayatPembayaran'] as List)
                                        .length,
                                    (index) {
                                      final pembayaran =
                                          (tagihanData['riwayatPembayaran']
                                              as List)[index];
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 8),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  formatter.format(
                                                      pembayaran['jumlah']),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  DateFormat(
                                                          'dd MMM yyyy, HH:mm')
                                                      .format(
                                                    (pembayaran['tanggal']
                                                            as Timestamp)
                                                        .toDate(),
                                                  ),
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const Icon(Icons.receipt_long,
                                                color: Colors.grey),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                          ],

                          // Customer Info Section
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Informasi Pelanggan',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildInfoRow(
                                  Icons.person,
                                  'Nama',
                                  pelangganData?['nama'] ?? '-',
                                ),
                                _buildInfoRow(
                                  Icons.location_on,
                                  'Alamat',
                                  pelangganData?['alamat'] ?? '-',
                                ),
                                _buildInfoRow(
                                  Icons.phone,
                                  'No. HP',
                                  pelangganData?['noHp'] ?? '-',
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),

                          // Payment Info Section
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Informasi Pembayaran',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildInfoRow(
                                  Icons.calendar_today,
                                  'Tanggal Tagihan',
                                  tagihanData['tanggal'] != null
                                      ? DateFormat('dd MMMM yyyy').format(
                                          (tagihanData['tanggal'] as Timestamp)
                                              .toDate())
                                      : '-',
                                ),
                                _buildInfoRow(
                                  Icons.payment,
                                  'Tanggal Pembayaran',
                                  tagihanData['tanggalBayar'] != null &&
                                          tagihanData['tanggalBayar']
                                              is Timestamp
                                      ? DateFormat('dd MMMM yyyy').format(
                                          (tagihanData['tanggalBayar']
                                                  as Timestamp)
                                              .toDate())
                                      : 'Belum dibayar',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentInfoRow(String label, String value,
      {bool bold = false, Color? textColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'Sudah dibayar':
        return Colors.green.shade50;
      case 'Bayar Sebagian':
        return Colors.orange.shade50;
      default:
        return Colors.red.shade50;
    }
  }

  Color _getStatusTextColor(String? status) {
    switch (status) {
      case 'Sudah dibayar':
        return Colors.green;
      case 'Bayar Sebagian':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'Sudah dibayar':
        return Icons.check_circle;
      case 'Bayar Sebagian':
        return Icons.pending_actions;
      default:
        return Icons.pending;
    }
  }

  Future<void> _updateStatus(BuildContext context) async {
    final newStatus =
        tagihanData['status'] == 'Lunas' ? 'Belum dibayar' : 'Lunas';

    try {
      await FirebaseFirestore.instance
          .collection('tagihan')
          .doc(tagihanId)
          .update({'status': newStatus});

      if (context.mounted) {
        Navigator.pop(context); // Kembali ke halaman sebelumnya
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status tagihan diubah menjadi $newStatus'),
            backgroundColor:
                newStatus == 'Lunas' ? Colors.green : Colors.orange,
          ),
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

  Future<void> _showDeleteConfirmation(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Tagihan'),
        content: const Text('Apakah Anda yakin ingin menghapus tagihan ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('tagihan')
                    .doc(tagihanId)
                    .delete();

                if (context.mounted) {
                  Navigator.pop(context); // Tutup dialog
                  Navigator.pop(context); // Kembali ke halaman sebelumnya
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tagihan berhasil dihapus')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}
