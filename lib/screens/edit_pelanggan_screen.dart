import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

class EditPelangganScreen extends StatefulWidget {
  final String pelangganId;
  final Map<String, dynamic> pelangganData;

  const EditPelangganScreen({
    super.key,
    required this.pelangganId,
    required this.pelangganData,
  });

  @override
  State<EditPelangganScreen> createState() => _EditPelangganScreenState();
}

class _EditPelangganScreenState extends State<EditPelangganScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _alamatController = TextEditingController();
  final _nomorHPController = TextEditingController();
  final _biayaBulananController = TextEditingController();
  final List<String> _statusOptions = ['Aktif', 'Nonaktif'];
  List<String> _paketOptions = [];
  Map<String, int> _paketHarga = {};
  String? _selectedStatus;
  String? _selectedPaket;

  @override
  void initState() {
    super.initState();
    _loadPaketOptions();
    _selectedStatus = widget.pelangganData['status'];
    _selectedPaket = widget.pelangganData['paket'];
    _namaController.text = widget.pelangganData['nama'] ?? '';
    _alamatController.text = widget.pelangganData['alamat'] ?? '';
    _nomorHPController.text = widget.pelangganData['noHp'] ?? '';
    _biayaBulananController.text =
        (widget.pelangganData['biayaBulanan'] ?? '').toString();
  }

  @override
  void dispose() {
    _namaController.dispose();
    _alamatController.dispose();
    _nomorHPController.dispose();
    _biayaBulananController.dispose();
    super.dispose();
  }

  Future<void> _loadPaketOptions() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('paket_wifi')
          .orderBy('nama')
          .get();

      setState(() {
        _paketOptions = [];
        _paketHarga = {};

        for (var doc in snapshot.docs) {
          final data = doc.data();
          final namaPaket = data['nama'] as String;
          final hargaPaket = data['harga'] as int;

          _paketOptions.add(namaPaket);
          _paketHarga[namaPaket] = hargaPaket;
        }

        // Update selected paket dan biaya bulanan
        if (_selectedPaket != null && _paketHarga.containsKey(_selectedPaket)) {
          _biayaBulananController.text = _paketHarga[_selectedPaket].toString();
        } else if (_paketOptions.isNotEmpty) {
          _selectedPaket = _paketOptions[0];
          _biayaBulananController.text =
              _paketHarga[_paketOptions[0]].toString();
        }
      });
    } catch (e) {
      print('Error loading paket options: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal memuat data paket WiFi'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updatePelanggan() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await FirebaseFirestore.instance
          .collection('pelanggan')
          .doc(widget.pelangganId)
          .update({
        'nama': _namaController.text.trim(),
        'alamat': _alamatController.text.trim(),
        'noHp': _nomorHPController.text.trim(),
        'status': _selectedStatus,
        'paket': _selectedPaket,
        'biayaBulanan': int.parse(_biayaBulananController.text.trim()),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data pelanggan berhasil diperbarui'),
            backgroundColor: Colors.green,
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit Pelanggan',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Container(
            height: 100,
            color: AppTheme.primaryColor,
          ),
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Informasi Pelanggan',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Nama
                          TextFormField(
                            controller: _namaController,
                            decoration: const InputDecoration(
                              labelText: 'Nama',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Nama tidak boleh kosong';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Alamat
                          TextFormField(
                            controller: _alamatController,
                            decoration: const InputDecoration(
                              labelText: 'Alamat',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.location_on),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Alamat tidak boleh kosong';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // No HP
                          TextFormField(
                            controller: _nomorHPController,
                            decoration: const InputDecoration(
                              labelText: 'No. HP',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.phone),
                            ),
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'No. HP tidak boleh kosong';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Informasi Layanan',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Status
                          DropdownButtonFormField<String>(
                            value: _selectedStatus,
                            decoration: const InputDecoration(
                              labelText: 'Status',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.toggle_on),
                            ),
                            items: _statusOptions.map((status) {
                              return DropdownMenuItem(
                                value: status,
                                child: Text(status),
                              );
                            }).toList(),
                            onChanged: (value) =>
                                setState(() => _selectedStatus = value),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Pilih status pelanggan';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Paket
                          DropdownButtonFormField<String>(
                            value: _selectedPaket,
                            decoration: const InputDecoration(
                              labelText: 'Paket',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.wifi),
                            ),
                            items: _paketOptions.map((paket) {
                              return DropdownMenuItem(
                                value: paket,
                                child: Text(paket),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedPaket = value;
                                // Update biaya bulanan otomatis
                                if (value != null &&
                                    _paketHarga.containsKey(value)) {
                                  _biayaBulananController.text =
                                      _paketHarga[value].toString();
                                }
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Pilih paket WiFi';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Biaya Bulanan (readonly)
                          TextFormField(
                            controller: _biayaBulananController,
                            decoration: const InputDecoration(
                              labelText: 'Biaya Bulanan',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.attach_money),
                            ),
                            readOnly: true, // Tidak bisa diedit manual
                            enabled: false, // Disable field
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _updatePelanggan,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.save, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Simpan Perubahan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
