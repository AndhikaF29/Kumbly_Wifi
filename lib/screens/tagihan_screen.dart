import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/tagihan_service.dart';
import './detail_tagihan_screen.dart';
import '../theme/app_theme.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:excel/excel.dart';
import 'package:excel/excel.dart' as excel_package;

class TagihanScreen extends StatefulWidget {
  const TagihanScreen({super.key});

  @override
  State<TagihanScreen> createState() => _TagihanScreenState();
}

class _TagihanScreenState extends State<TagihanScreen> {
  String _filterPeriode = 'semua';
  String _filterStatus = 'semua';
  String _searchQuery = '';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  DateTime _getStartDate() {
    final now = DateTime.now();
    switch (_filterPeriode) {
      case 'hari':
        return DateTime(now.year, now.month, now.day);
      case 'minggu':
        final monday = now.subtract(Duration(days: now.weekday - 1));
        return DateTime(monday.year, monday.month, monday.day);
      case 'bulan':
        return DateTime(now.year, now.month, 1);
      case 'bulan_lalu':
        return DateTime(now.year, now.month - 1, 1);
      case 'semua':
      default:
        return DateTime(2000);
    }
  }

  DateTime _getEndDate() {
    final now = DateTime.now();
    switch (_filterPeriode) {
      case 'hari':
        return DateTime(now.year, now.month, now.day, 23, 59, 59);
      case 'minggu':
        final monday = now.subtract(Duration(days: now.weekday - 1));
        final sunday = monday.add(const Duration(days: 6));
        return DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59);
      case 'bulan':
        final lastDay = DateTime(now.year, now.month + 1, 0);
        return DateTime(lastDay.year, lastDay.month, lastDay.day, 23, 59, 59);
      case 'bulan_lalu':
        final lastDay = DateTime(now.year, now.month, 0);
        return DateTime(lastDay.year, lastDay.month, lastDay.day, 23, 59, 59);
      case 'semua':
      default:
        return DateTime.now();
    }
  }

  Future<void> _exportToCSV() async {
    try {
      // Tampilkan dialog pemilihan tanggal
      final DateTimeRange? dateRange = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        initialDateRange: DateTimeRange(
          start: _startDate,
          end: _endDate,
        ),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              primaryColor: AppTheme.primaryColor,
              colorScheme: ColorScheme.light(
                primary: AppTheme.primaryColor,
              ),
            ),
            child: child!,
          );
        },
      );

      if (dateRange == null) return; // User membatalkan pemilihan

      final QuerySnapshot tagihanSnapshot = await FirebaseFirestore.instance
          .collection('tagihan')
          .where('createdAt',
              isGreaterThanOrEqualTo: DateTime(
                dateRange.start.year,
                dateRange.start.month,
                dateRange.start.day,
              ))
          .where('createdAt',
              isLessThanOrEqualTo: DateTime(dateRange.end.year,
                  dateRange.end.month, dateRange.end.day, 23, 59, 59))
          .orderBy('createdAt', descending: true)
          .get();

      if (tagihanSnapshot.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tidak ada data untuk diekspor'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Buat file Excel baru
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Sheet1'];

      // Tambahkan informasi periode yang dipilih
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
        ..value = TextCellValue('Periode Laporan:')
        ..cellStyle = CellStyle(bold: true);

      sheetObject
              .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0))
              .value =
          TextCellValue(
              '${DateFormat('dd MMMM yyyy').format(dateRange.start)} - ${DateFormat('dd MMMM yyyy').format(dateRange.end)}');

      // Tambahkan header
      var headers = [
        'Periode',
        'Nama Pelanggan',
        'Paket',
        'Total Tagihan',
        'Total Dibayar',
        'Status',
        'Tanggal Bayar',
        'Sisa Tagihan',
      ];

      // Tulis header
      for (var i = 0; i < headers.length; i++) {
        sheetObject
            .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          ..value = TextCellValue(headers[i])
          ..cellStyle = CellStyle(
            bold: true,
            horizontalAlign: HorizontalAlign.Center,
          );
      }

      // Variabel untuk total
      double totalTagihan = 0;
      double totalDibayar = 0;
      double totalSisaTagihan = 0;
      int currentRow = 1;

      // Tulis data
      for (var doc in tagihanSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        String tanggalBayar = '-';
        if (data['tanggalBayar'] != null) {
          tanggalBayar = DateFormat('dd/MM/yyyy HH:mm')
              .format((data['tanggalBayar'] as Timestamp).toDate());
        }

        final double jumlah = (data['jumlah'] ?? 0).toDouble();
        final double dibayar = (data['totalDibayar'] ?? 0).toDouble();
        final double sisaTagihan = (data['sisaTagihan'] ?? jumlah).toDouble();

        totalTagihan += jumlah;
        totalDibayar += dibayar;
        totalSisaTagihan += sisaTagihan;

        var rowData = [
          data['periode'] ?? '-',
          data['nama_pelanggan'] ?? '-',
          data['paket'] ?? '-',
          NumberFormat.currency(
            locale: 'id_ID',
            symbol: 'Rp ',
            decimalDigits: 0,
          ).format(jumlah),
          NumberFormat.currency(
            locale: 'id_ID',
            symbol: 'Rp ',
            decimalDigits: 0,
          ).format(dibayar),
          data['status'] ?? 'Belum dibayar',
          tanggalBayar,
          NumberFormat.currency(
            locale: 'id_ID',
            symbol: 'Rp ',
            decimalDigits: 0,
          ).format(sisaTagihan),
        ];

        // Tulis baris data
        for (var i = 0; i < rowData.length; i++) {
          sheetObject
              .cell(CellIndex.indexByColumnRow(
                columnIndex: i,
                rowIndex: currentRow,
              ))
              .value = TextCellValue(rowData[i]);
        }
        currentRow++;
      }

      // Tambah baris kosong
      currentRow++;

      // Tulis total
      var totalRow = [
        'Total Pembayaran',
        '',
        '',
        NumberFormat.currency(
          locale: 'id_ID',
          symbol: 'Rp ',
          decimalDigits: 0,
        ).format(totalTagihan),
        NumberFormat.currency(
          locale: 'id_ID',
          symbol: 'Rp ',
          decimalDigits: 0,
        ).format(totalDibayar),
        '',
        '',
        NumberFormat.currency(
          locale: 'id_ID',
          symbol: 'Rp ',
          decimalDigits: 0,
        ).format(totalSisaTagihan),
      ];

      for (var i = 0; i < totalRow.length; i++) {
        sheetObject.cell(CellIndex.indexByColumnRow(
          columnIndex: i,
          rowIndex: currentRow,
        ))
          ..value = TextCellValue(totalRow[i])
          ..cellStyle = CellStyle(bold: true);
      }

      // Set lebar kolom
      for (var i = 0; i < headers.length; i++) {
        sheetObject.setColumnWidth(i, 15.0);
      }

      // Simpan file
      final directory = await getApplicationDocumentsDirectory();
      final path =
          '${directory.path}/laporan_tagihan_${DateFormat('dd_MM_yyyy').format(DateTime.now())}.xlsx';
      final file = File(path);

      // Pastikan file ditulis dengan benar
      final bytes = excel.encode();
      if (bytes != null) {
        await file.writeAsBytes(bytes);

        // Share file
        await Share.shareXFiles(
          [XFile(path)],
          subject:
              'Laporan Tagihan ${DateFormat('dd MMMM yyyy').format(DateTime.now())}',
        );
      } else {
        throw 'Gagal menghasilkan file Excel';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengekspor data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tagihan', style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: Colors.white,
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download, color: Colors.white),
            onPressed: _exportToCSV,
            tooltip: 'Export ke CSV',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search dan Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  onChanged: (value) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Cari nama pelanggan...',
                    prefixIcon:
                        const Icon(Icons.search, color: AppTheme.subtitleColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Filter Row
                Row(
                  children: [
                    // Periode Filter
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _filterPeriode,
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down,
                                color: AppTheme.subtitleColor),
                            items: const [
                              DropdownMenuItem(
                                  value: 'semua', child: Text('Semua')),
                              DropdownMenuItem(
                                  value: 'bulan', child: Text('Bulan Ini')),
                              DropdownMenuItem(
                                  value: 'bulan_lalu',
                                  child: Text('Bulan Lalu')),
                              DropdownMenuItem(
                                  value: 'minggu', child: Text('Minggu Ini')),
                              DropdownMenuItem(
                                  value: 'hari', child: Text('Hari Ini')),
                            ],
                            onChanged: (value) {
                              if (value != null)
                                setState(() => _filterPeriode = value);
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Status Filter
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _filterStatus,
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down,
                                color: AppTheme.subtitleColor),
                            items: const [
                              DropdownMenuItem(
                                  value: 'semua', child: Text('Semua')),
                              DropdownMenuItem(
                                  value: 'lunas', child: Text('Sudah Dibayar')),
                              DropdownMenuItem(
                                  value: 'sebagian',
                                  child: Text('Bayar Sebagian')),
                              DropdownMenuItem(
                                  value: 'belum', child: Text('Belum Dibayar')),
                            ],
                            onChanged: (value) {
                              if (value != null)
                                setState(() => _filterStatus = value);
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Tombol Tambah
                    Container(
                      height: 48, // Sesuaikan dengan tinggi dropdown
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.add, color: Colors.white),
                        onPressed: () => _showTambahTagihanManual(context),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                // Total Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Pendapatan yang Harus Terkumpul',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('tagihan')
                            .where('createdAt',
                                isGreaterThanOrEqualTo: _getStartDate())
                            .where('createdAt',
                                isLessThanOrEqualTo: _getEndDate())
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData)
                            return const Text('Menghitung...');

                          final docs = snapshot.data!.docs;
                          final total = docs.fold<int>(
                            0,
                            (sum, doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              return sum + (data['jumlah'] ?? 0) as int;
                            },
                          );

                          // Menggunakan totalDibayar untuk menghitung uang yang sudah terkumpul
                          final totalTerkumpul = docs.fold<double>(
                            0,
                            (sum, doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              return sum +
                                  (data['totalDibayar'] ?? 0).toDouble();
                            },
                          );

                          final formatter = NumberFormat.currency(
                            locale: 'id_ID',
                            symbol: 'Rp ',
                            decimalDigits: 0,
                          );

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                formatter.format(total),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.check_circle,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Terkumpul: ${formatter.format(totalTerkumpul)}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                // Status Filter Buttons
                Container(
                  height: 36, // Ukuran yang lebih compact
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _filterStatus = 'belum'),
                          child: Container(
                            decoration: BoxDecoration(
                              color: _filterStatus == 'belum'
                                  ? AppTheme.primaryColor
                                  : Colors.transparent,
                              borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(8),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Belum\nDibayar',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.2,
                                  color: _filterStatus == 'belum'
                                      ? Colors.white
                                      : Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () =>
                              setState(() => _filterStatus = 'sebagian'),
                          child: Container(
                            decoration: BoxDecoration(
                              color: _filterStatus == 'sebagian'
                                  ? Colors.orange
                                  : Colors.transparent,
                            ),
                            child: Center(
                              child: Text(
                                'Bayar\nSebagian',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.2,
                                  color: _filterStatus == 'sebagian'
                                      ? Colors.white
                                      : Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _filterStatus = 'lunas'),
                          child: Container(
                            decoration: BoxDecoration(
                              color: _filterStatus == 'lunas'
                                  ? AppTheme.primaryColor
                                  : Colors.transparent,
                              borderRadius: const BorderRadius.horizontal(
                                right: Radius.circular(8),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Sudah\nDibayar',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.2,
                                  color: _filterStatus == 'lunas'
                                      ? Colors.white
                                      : Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // List Tagihan
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('tagihan')
                  .where('createdAt', isGreaterThanOrEqualTo: _getStartDate())
                  .where('createdAt', isLessThanOrEqualTo: _getEndDate())
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                var tagihan = snapshot.data!.docs;

                // Filter berdasarkan status
                if (_filterStatus != 'semua') {
                  tagihan = tagihan.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    if (_filterStatus == 'lunas') {
                      return data['status'] == 'Sudah dibayar';
                    } else if (_filterStatus == 'sebagian') {
                      return data['status'] == 'Bayar Sebagian';
                    } else if (_filterStatus == 'belum') {
                      return data['status'] == 'Belum dibayar';
                    }
                    return false;
                  }).toList();
                }

                // Filter berdasarkan search query
                if (_searchQuery.isNotEmpty) {
                  tagihan = tagihan.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final namaPelanggan =
                        (data['nama_pelanggan'] ?? '').toString().toLowerCase();
                    return namaPelanggan.contains(_searchQuery.toLowerCase());
                  }).toList();
                }

                // Tampilkan pesan jika tidak ada hasil
                if (tagihan.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: AppTheme.subtitleColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'Tidak ada tagihan yang sesuai'
                              : 'Tidak ada tagihan untuk periode ini',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppTheme.subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: tagihan.length,
                    itemBuilder: (context, index) {
                      final data =
                          tagihan[index].data() as Map<String, dynamic>;
                      final formatter = NumberFormat.currency(
                        locale: 'id_ID',
                        symbol: 'Rp ',
                        decimalDigits: 0,
                      );

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              // Nomor Urut
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Informasi Tagihan
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['nama_pelanggan'] ??
                                          'Tidak tersedia',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          formatter.format(data['jumlah'] ?? 0),
                                          style: TextStyle(
                                            color: Colors.green[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        if (data['status'] ==
                                            'Bayar Sebagian') ...[
                                          Text(
                                            ' • Terbayar: ${formatter.format(data['totalDibayar'] ?? 0)}',
                                            style: TextStyle(
                                              color: Colors.orange[700],
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          data['status'] == 'Sudah dibayar'
                                              ? Icons.check_circle
                                              : data['status'] ==
                                                      'Bayar Sebagian'
                                                  ? Icons.pending_actions
                                                  : Icons.pending,
                                          size: 16,
                                          color:
                                              data['status'] == 'Sudah dibayar'
                                                  ? Colors.green[700]
                                                  : data['status'] ==
                                                          'Bayar Sebagian'
                                                      ? Colors.orange[700]
                                                      : Colors.red[700],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          data['status'] ?? 'Belum dibayar',
                                          style: TextStyle(
                                            color: data['status'] ==
                                                    'Sudah dibayar'
                                                ? Colors.green[700]
                                                : data['status'] ==
                                                        'Bayar Sebagian'
                                                    ? Colors.orange[700]
                                                    : Colors.red[700],
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Tombol Kelola
                              TextButton.icon(
                                onPressed: () => _showTagihanOptions(
                                  context,
                                  tagihan[index].id,
                                  data,
                                ),
                                style: TextButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: const Icon(Icons.more_horiz,
                                    color: Colors.white),
                                label: const Text(
                                  'Kelola',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showTagihanOptions(
    BuildContext context,
    String tagihanId,
    Map<String, dynamic> tagihanData,
  ) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility, color: Colors.blue),
              title: const Text('Lihat Detail'),
              onTap: () {
                Navigator.pop(context);
                _showDetailTagihan(tagihanId, tagihanData);
              },
            ),
            ListTile(
              leading: Icon(
                tagihanData['status'] == 'Sudah dibayar'
                    ? Icons.money_off
                    : Icons.check_circle,
                color: tagihanData['status'] == 'Sudah dibayar'
                    ? Colors.red
                    : Colors.green,
              ),
              title: Text(tagihanData['status'] == 'Sudah dibayar'
                  ? 'Tandai Belum Dibayar'
                  : 'Input Pembayaran'),
              onTap: () async {
                Navigator.pop(context);
                if (tagihanData['status'] == 'Sudah dibayar') {
                  await FirebaseFirestore.instance
                      .collection('tagihan')
                      .doc(tagihanId)
                      .update({
                    'status': 'Belum dibayar',
                    'tanggalBayar': null,
                    'totalDibayar': 0,
                    'sisaTagihan': tagihanData['jumlah'],
                    'riwayatPembayaran': FieldValue.delete(),
                  });
                } else {
                  _showInputPembayaranDialog(context, tagihanId, tagihanData);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Hapus Tagihan'),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(context, tagihanId);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    String tagihanId,
  ) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Tagihan'),
        content: const Text(
          'Apakah Anda yakin ingin menghapus tagihan ini? '
          'Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('tagihan')
                    .doc(tagihanId)
                    .delete();

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tagihan berhasil dihapus'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Gagal menghapus tagihan: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  Future<void> _showTambahTagihanManual(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => const _TambahTagihanDialog(),
    );
  }

  void _showDetailTagihan(String tagihanId, Map<String, dynamic> tagihanData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetailTagihanScreen(
          tagihanId: tagihanId,
          tagihanData: tagihanData,
        ),
      ),
    );
  }

  Future<void> _showInputPembayaranDialog(
    BuildContext context,
    String tagihanId,
    Map<String, dynamic> tagihanData,
  ) async {
    final TextEditingController jumlahBayarController = TextEditingController();
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final double totalTagihan = (tagihanData['jumlah'] ?? 0).toDouble();
    final double sudahDibayar = (tagihanData['totalDibayar'] ?? 0).toDouble();
    final double sisaTagihan =
        (tagihanData['sisaTagihan'] ?? totalTagihan).toDouble();

    String formatNumber(String value) {
      if (value.isEmpty) return '';
      final number = int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      return formatter.format(number).replaceAll('Rp ', '');
    }

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: Column(
          children: [
            const Text(
              'Input Pembayaran',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Divider(thickness: 1),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Info Container
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildInfoRow(
                    'Total Tagihan:',
                    formatter.format(totalTagihan),
                    Colors.black,
                    FontWeight.bold,
                  ),
                  if (sudahDibayar > 0) ...[
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      'Sudah Dibayar:',
                      formatter.format(sudahDibayar),
                      Colors.green[700]!,
                      FontWeight.normal,
                    ),
                  ],
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    'Sisa Tagihan:',
                    formatter.format(sisaTagihan),
                    Colors.red[700]!,
                    FontWeight.normal,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Input Field
            TextField(
              controller: jumlahBayarController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Jumlah Pembayaran',
                labelStyle: TextStyle(color: Colors.grey[600]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppTheme.primaryColor),
                ),
                prefixText: 'Rp ',
                prefixStyle: const TextStyle(color: Colors.black),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) {
                final formatted = formatNumber(value);
                if (formatted != value) {
                  jumlahBayarController.value = TextEditingValue(
                    text: formatted,
                    selection:
                        TextSelection.collapsed(offset: formatted.length),
                  );
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[600],
            ),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final double jumlahBayar = double.tryParse(
                      jumlahBayarController.text
                          .replaceAll(RegExp(r'[^0-9]'), ''),
                    ) ??
                    0;

                if (jumlahBayar <= 0) {
                  throw 'Jumlah pembayaran harus lebih dari 0';
                }

                if (jumlahBayar > sisaTagihan) {
                  throw 'Jumlah pembayaran melebihi sisa tagihan';
                }

                final double totalDibayar = sudahDibayar + jumlahBayar;
                final double sisaTagihanBaru = totalTagihan - totalDibayar;
                final String status =
                    sisaTagihanBaru == 0 ? 'Sudah dibayar' : 'Bayar Sebagian';

                // Buat data riwayat pembayaran baru
                final Map<String, dynamic> riwayatBaru = {
                  'jumlah': jumlahBayar,
                  'tanggal': Timestamp.fromDate(DateTime.now()),
                  'petugasId': FirebaseAuth.instance.currentUser?.uid,
                };

                // Update tagihan dengan riwayat pembayaran baru
                await FirebaseFirestore.instance
                    .collection('tagihan')
                    .doc(tagihanId)
                    .update({
                  'status': status,
                  'tanggalBayar': Timestamp.fromDate(DateTime.now()),
                  'totalDibayar': totalDibayar,
                  'sisaTagihan': sisaTagihanBaru,
                  'riwayatPembayaran': FieldValue.arrayUnion([riwayatBaru]),
                });

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Pembayaran berhasil disimpan'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(e.toString()),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'Simpan',
              style: TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
      String label, String value, Color valueColor, FontWeight fontWeight) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: valueColor,
            fontWeight: fontWeight,
          ),
        ),
      ],
    );
  }
}

class _TambahTagihanDialog extends StatefulWidget {
  const _TambahTagihanDialog({Key? key}) : super(key: key);

  @override
  State<_TambahTagihanDialog> createState() => _TambahTagihanDialogState();
}

class _TambahTagihanDialogState extends State<_TambahTagihanDialog> {
  final _searchController = TextEditingController();
  final _selectedPelanggan =
      <String, Map<String, dynamic>>{}; // Ubah ke Map untuk multiple selection
  final _bulanController = TextEditingController();
  int _jumlahBulan = 1;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tambah Tagihan'),
      content: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Search field
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari nama pelanggan...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // List pelanggan
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('pelanggan')
                    .orderBy('nama')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return Column(
                    children: [
                      // Checkbox Pilih Semua
                      const SizedBox(height: 8),

                      // List Pelanggan
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('tagihan')
                              .where('createdAt',
                                  isGreaterThanOrEqualTo: DateTime(
                                    DateTime.now().year,
                                    DateTime.now().month,
                                  ))
                              .snapshots(),
                          builder: (context, tagihanSnapshot) {
                            if (!tagihanSnapshot.hasData) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }

                            // Buat Set dari pelangganId yang sudah memiliki tagihan bulan ini
                            final pelangganDenganTagihan = Set<String>.from(
                              tagihanSnapshot.data!.docs.map((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                return data['pelangganId'] as String;
                              }),
                            );

                            // Filter pelanggan yang belum memiliki tagihan
                            final filteredPelanggan =
                                snapshot.data!.docs.where((doc) {
                              // Filter berdasarkan pencarian
                              final data = doc.data() as Map<String, dynamic>;
                              final nama =
                                  (data['nama'] ?? '').toString().toLowerCase();
                              final matchSearch = nama.contains(
                                  _searchController.text.toLowerCase());

                              // Filter pelanggan yang belum memiliki tagihan bulan ini
                              final belumAdaTagihan =
                                  !pelangganDenganTagihan.contains(doc.id);

                              return matchSearch && belumAdaTagihan;
                            }).toList();

                            // Update checkbox "Pilih Semua"
                            final allSelected = filteredPelanggan.isNotEmpty &&
                                _selectedPelanggan.length ==
                                    filteredPelanggan.length;

                            return Column(
                              children: [
                                // Checkbox Pilih Semua
                                Container(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  child: Row(
                                    children: [
                                      Checkbox(
                                        value: allSelected,
                                        onChanged: (bool? value) {
                                          setState(() {
                                            if (value == true) {
                                              // Pilih semua pelanggan yang belum memiliki tagihan
                                              for (var doc
                                                  in filteredPelanggan) {
                                                final data = doc.data()
                                                    as Map<String, dynamic>;
                                                _selectedPelanggan[doc.id] =
                                                    data;
                                              }
                                            } else {
                                              // Kosongkan semua pilihan
                                              _selectedPelanggan.clear();
                                            }
                                          });
                                        },
                                      ),
                                      const Text(
                                        'Pilih Semua',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // List Pelanggan yang belum memiliki tagihan
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: filteredPelanggan.length,
                                    itemBuilder: (context, index) {
                                      final data = filteredPelanggan[index]
                                          .data() as Map<String, dynamic>;
                                      final pelangganId =
                                          filteredPelanggan[index].id;
                                      final isSelected = _selectedPelanggan
                                          .containsKey(pelangganId);

                                      return ListTile(
                                        leading: Checkbox(
                                          value: isSelected,
                                          onChanged: (bool? value) {
                                            setState(() {
                                              if (value == true) {
                                                _selectedPelanggan[
                                                    pelangganId] = data;
                                              } else {
                                                _selectedPelanggan
                                                    .remove(pelangganId);
                                              }
                                            });
                                          },
                                        ),
                                        title: Text(data['nama'] ?? ''),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              NumberFormat.currency(
                                                locale: 'id_ID',
                                                symbol: 'Rp ',
                                                decimalDigits: 0,
                                              ).format(
                                                  data['biayaBulanan'] ?? 0),
                                            ),
                                            Text(
                                              'Total ${_jumlahBulan} bulan: ${NumberFormat.currency(
                                                locale: 'id_ID',
                                                symbol: 'Rp ',
                                                decimalDigits: 0,
                                              ).format((data['biayaBulanan'] ?? 0) * _jumlahBulan)}',
                                              style: TextStyle(
                                                color: Colors.green[700],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                        trailing: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              data['paket'] ?? '',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
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
                  );
                },
              ),
            ),

            if (_selectedPelanggan.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pelanggan Terpilih: ${_selectedPelanggan.length}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Total Tagihan: ${NumberFormat.currency(
                        locale: 'id_ID',
                        symbol: 'Rp ',
                        decimalDigits: 0,
                      ).format(_selectedPelanggan.values.fold<int>(0, (int previousValue, pelanggan) => previousValue + ((pelanggan['biayaBulanan'] as int? ?? 0) * _jumlahBulan)))}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _selectedPelanggan.isEmpty
              ? null
              : () async {
                  try {
                    // Buat tagihan untuk setiap pelanggan yang dipilih
                    for (var entry in _selectedPelanggan.entries) {
                      final pelangganId = entry.key;
                      final pelanggan = entry.value;

                      // Buat tagihan sejumlah bulan yang dipilih
                      for (var i = 0; i < _jumlahBulan; i++) {
                        await TagihanService().tambahTagihanManual(
                          namaPelanggan: pelanggan['nama'],
                          pelangganId: pelangganId,
                          jumlah: pelanggan['biayaBulanan'],
                          paket: pelanggan['paket'],
                        );
                      }
                    }

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Berhasil membuat ${_selectedPelanggan.length * _jumlahBulan} tagihan',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
          child: const Text('Simpan'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
