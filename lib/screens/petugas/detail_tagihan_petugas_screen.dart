import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Detail Tagihan',
          style: TextStyle(color: Colors.white),
        ),
        elevation: 0,
        backgroundColor: AppTheme.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('pelanggan')
            .doc(tagihanData['pelangganId'])
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final pelangganData = snapshot.data?.data() as Map<String, dynamic>?;

          return Stack(
            children: [
              // Background design dengan secondary color
              Container(
                height: 100,
                color: AppTheme.primaryColor,
              ),

              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Card
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      NumberFormat.currency(
                                        locale: 'id_ID',
                                        symbol: 'Rp ',
                                        decimalDigits: 0,
                                      ).format(tagihanData['jumlah'] ?? 0),
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      tagihanData['periode'] ?? '-',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        tagihanData['status'] == 'Sudah dibayar'
                                            ? Colors.green[100]
                                            : tagihanData['status'] ==
                                                    'Bayar Sebagian'
                                                ? Colors.orange[100]
                                                : Colors.red[100],
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    tagihanData['status'] ?? 'Belum dibayar',
                                    style: TextStyle(
                                      color: tagihanData['status'] ==
                                              'Sudah dibayar'
                                          ? Colors.green[800]
                                          : tagihanData['status'] ==
                                                  'Bayar Sebagian'
                                              ? Colors.orange[800]
                                              : Colors.red[800],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (tagihanData['status'] == 'Bayar Sebagian') ...[
                              const Divider(height: 24),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Sisa Tagihan:',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    NumberFormat.currency(
                                      locale: 'id_ID',
                                      symbol: 'Rp ',
                                      decimalDigits: 0,
                                    ).format(tagihanData['sisaTagihan'] ?? 0),
                                    style: TextStyle(
                                      color: Colors.orange[800],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Informasi Pelanggan
                    _buildSectionTitle('Informasi Pelanggan'),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildInfoRow(
                              Icons.person,
                              'Nama',
                              pelangganData?['nama'] ?? '-',
                            ),
                            const Divider(),
                            _buildInfoRow(
                              Icons.location_on,
                              'Alamat',
                              pelangganData?['alamat'] ?? '-',
                            ),
                            const Divider(),
                            _buildInfoRow(
                              Icons.phone,
                              'No. HP',
                              pelangganData?['noHp'] ?? '-',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Informasi Tagihan
                    _buildSectionTitle('Informasi Tagihan'),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildInfoRow(
                              Icons.wifi,
                              'Paket',
                              tagihanData['paket'] ?? '-',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Status Indicator
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Informasi Pembayaran
                    _buildSectionTitle('Informasi Pembayaran'),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildPaymentInfoRow(
                              'Total Tagihan',
                              tagihanData['jumlah'] ?? 0,
                              bold: true,
                            ),
                            const Divider(),
                            _buildPaymentInfoRow(
                              'Total Dibayar',
                              tagihanData['totalDibayar'] ?? 0,
                              textColor: Colors.green[800],
                            ),
                            const Divider(),
                            _buildPaymentInfoRow(
                              'Sisa Tagihan',
                              tagihanData['sisaTagihan'] ??
                                  tagihanData['jumlah'] ??
                                  0,
                              textColor: Colors.orange[800],
                            ),
                            if (tagihanData['tanggalBayar'] != null) ...[
                              const Divider(),
                              _buildInfoRow(
                                Icons.calendar_today,
                                'Pembayaran Terakhir',
                                DateFormat('dd MMMM yyyy, HH:mm').format(
                                  (tagihanData['tanggalBayar'] as Timestamp)
                                      .toDate(),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Riwayat Pembayaran
                    if ((tagihanData['riwayatPembayaran'] as List?)
                            ?.isNotEmpty ??
                        false) ...[
                      _buildSectionTitle('Riwayat Pembayaran'),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount:
                              (tagihanData['riwayatPembayaran'] as List).length,
                          itemBuilder: (context, index) {
                            final pembayaran = (tagihanData['riwayatPembayaran']
                                as List)[index];
                            return ListTile(
                              title: Text(
                                NumberFormat.currency(
                                  locale: 'id_ID',
                                  symbol: 'Rp ',
                                  decimalDigits: 0,
                                ).format(pembayaran['jumlah']),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                DateFormat('dd MMMM yyyy, HH:mm').format(
                                  (pembayaran['tanggal'] as Timestamp).toDate(),
                                ),
                              ),
                              trailing: const Icon(Icons.receipt_long),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
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

  Widget _buildPaymentInfoRow(String label, num amount,
      {bool bold = false, Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            NumberFormat.currency(
              locale: 'id_ID',
              symbol: 'Rp ',
              decimalDigits: 0,
            ).format(amount),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
