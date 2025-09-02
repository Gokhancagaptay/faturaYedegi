import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fatura_yeni/core/services/api_service.dart';
import 'package:fatura_yeni/core/services/storage_service.dart';
import 'package:fatura_yeni/models/invoice_detail.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

// --- ANA EKRAN WIDGET'I ---
class InvoiceDetailScreen extends StatefulWidget {
  final String invoiceId;
  final String? packageId;

  const InvoiceDetailScreen({
    super.key,
    required this.invoiceId,
    this.packageId,
  });

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  final ApiService _api = ApiService();
  final StorageService _storage = StorageService();
  late Future<InvoiceDetail?> _invoiceFuture;
  final _formKey = GlobalKey<FormState>();

  bool _isEditMode = false;
  InvoiceDetail? _originalInvoice;
  InvoiceDetail? _editableInvoice;
  int? _hoveredProductIndex;

  // Düzenlenebilir alanlar için Controller'lar
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _invoiceFuture = _loadInvoiceDetail();
  }

  Future<InvoiceDetail?> _loadInvoiceDetail() async {
    try {
      final token = await _storage.getToken();
      if (token == null) throw Exception('Yetkilendirme token\'ı bulunamadı.');
      if (widget.packageId == null) throw Exception('Paket ID bulunamadı.');
      final data = await _api.getInvoiceDetail(
          token, widget.packageId!, widget.invoiceId);
      if (data == null) {
        throw Exception('API\'den fatura detayı alınamadı.');
      }
      _originalInvoice = InvoiceDetail.fromJson(data);
      _editableInvoice = InvoiceDetail.fromJson(data); // Deep copy for editing
      _initializeControllers();
      return _originalInvoice;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fatura yüklenemedi: $e')),
        );
      }
      return null;
    }
  }

  void _initializeControllers() {
    _controllers.clear();
    final structured = _editableInvoice?.structured;
    if (structured == null) return;

    _controllers['odenecek_tutar'] =
        TextEditingController(text: structured.odenecekTutar);
    _controllers['satici_unvani'] =
        TextEditingController(text: structured.saticiUnvani);
    _controllers['fatura_tarihi'] =
        TextEditingController(text: structured.faturaTarihi);
    _controllers['fatura_numarasi'] =
        TextEditingController(text: structured.faturaNumarasi);

    // Diğer alanlar için controller'ları oluştur
    for (var key in structured.otherFields.keys) {
      _controllers['other_${key}'] = TextEditingController(
          text: structured.otherFields[key]?.toString() ?? '');
    }

    // Ürün kalemleri için controller'ları oluştur
    for (var i = 0; i < (structured.urunKalemleri.length); i++) {
      final item = structured.urunKalemleri[i];
      // `malHizmet` için (displayName'in ana parçası)
      _controllers['product_${i}_mal_hizmet'] =
          TextEditingController(text: item.malHizmet);

      // Diğer tüm alanları için
      for (var key in item.fields.keys) {
        _controllers['product_${i}_${key}'] =
            TextEditingController(text: item.fields[key]?.toString() ?? '');
      }
    }
  }

  /* YENİ KALEM EKLEME ÖZELLİĞİ, YENİ GEREKSİNİMLERLE KALDIRILDI
  void _addNewProductItem() {
    setState(() {
      final newItemIndex = _editableInvoice!.structured.urunKalemleri.length;
      final newUrunKalemi = UrunKalemi(
        malHizmet: '',
        siraNo: (newItemIndex + 1).toString(),
        fields: { // Varsayılan boş alanlar
          'birim_fiyat': '',
          'kdv_orani': '',
          'miktar': '',
        },
      );
      _editableInvoice!.structured.urunKalemleri.add(newUrunKalemi);

      // Yeni kalem için controller'ları oluştur
      _controllers['product_${newItemIndex}_mal_hizmet'] =
          TextEditingController(text: '');
      _controllers['product_${newItemIndex}_birim_fiyat'] =
          TextEditingController(text: '');
      _controllers['product_${newItemIndex}_kdv_orani'] =
          TextEditingController(text: '');
      _controllers['product_${newItemIndex}_miktar'] =
          TextEditingController(text: '');
    });
  }
  */

  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
      // Reset changes if toggling off without saving
      if (!_isEditMode) {
        _editableInvoice =
            InvoiceDetail.fromJson(jsonDecode(jsonEncode(_originalInvoice)));
        _initializeControllers(); // Reset controller values
      }
    });
  }

  Future<void> _saveChanges() async {
    // --- HATA AYIKLAMA İÇİN EKLENDİ ---
    print('--- ID DEĞERLERİNİ KONTROL ET ---');
    print('packageId: "${widget.packageId}"');
    print('invoiceId: "${widget.invoiceId}"');
    print('-----------------------------');
    // --- HATA AYIKLAMA SONU ---

    // packageId ve invoiceId'nin null veya boş olup olmadığını en başta kontrol et
    final packageId = widget.packageId;
    final invoiceId = widget.invoiceId;

    if (packageId == null || packageId.isEmpty || invoiceId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Hata: Paket veya Fatura ID bulunamadı. Değişiklikler kaydedilemedi.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Form doğrulamasını kontrol et
    if (_formKey.currentState?.validate() ?? false) {
      _formKey.currentState!.save(); // onSaved'leri tetikler

      // Arayüzü kilitlemek ve kullanıcıya işlem yapıldığını göstermek için
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Dialog(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 20),
                  Text("Değişiklikler kaydediliyor..."),
                ],
              ),
            ),
          );
        },
      );

      try {
        final token = await _storage.getToken();
        if (token == null)
          throw Exception('Yetkilendirme token\'ı bulunamadı.');

        final success = await _api.updateInvoiceStructuredData(
          token: token,
          packageId: packageId, // Güvenli, null ve boş olmayan değişkeni kullan
          invoiceId: invoiceId, // Güvenli, boş olmayan değişkeni kullan
          updatedData: _editableInvoice!.structured.toJson(),
        );

        if (!mounted) return; // Async sonrası mounted kontrolü
        Navigator.of(context).pop(); // "Kaydediliyor" dialog'unu kapat

        if (success) {
          setState(() {
            // Orijinal veriyi güncel haliyle değiştir
            _originalInvoice = InvoiceDetail.fromJson(
                jsonDecode(jsonEncode(_editableInvoice!.toJson())));
            _isEditMode = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text("Değişiklikler başarıyla kaydedildi."),
                  backgroundColor: Colors.green),
            );
          }
        } else {
          throw Exception('API güncellemesi başarısız oldu.');
        }
      } catch (e) {
        if (!mounted) return; // Async sonrası mounted kontrolü
        Navigator.of(context).pop(); // "Kaydediliyor" dialog'unu kapat
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text("Hata: Değişiklikler kaydedilemedi. $e"),
                backgroundColor: Colors.red),
          );
        }
      }
    } else {
      ScaffoldMessenger.of((context)).showSnackBar(
        const SnackBar(
            content: Text("Lütfen hatalı alanları düzeltin."),
            backgroundColor: Colors.orange),
      );
    }
  }

  Future<void> _approveInvoice() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Faturayı Onayla'),
          content: const Text(
              'Bu faturadaki bilgilerin doğruluğunu onaylamak üzeresiniz. Bu işlem geri alınamaz. Devam etmek istiyor musunuz?'),
          actions: <Widget>[
            TextButton(
              child: const Text('İptal'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Onayla'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    // Mounted check before showing dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => const Dialog(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text("Onaylanıyor..."),
          ]),
        ),
      ),
    );

    try {
      final token = await _storage.getToken();
      if (token == null) throw Exception('Yetkilendirme token\'ı bulunamadı.');

      await _api.approveInvoice(token, widget.packageId!, widget.invoiceId);

      if (!mounted) return; // Async sonrası mounted kontrolü
      Navigator.of(context).pop(); // "Onaylanıyor" dialog'unu kapat

      setState(() {
        _originalInvoice?.structured.isApproved = true;
        _originalInvoice?.structured.status = 'approved';
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Fatura başarıyla onaylandı."),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return; // Async sonrası mounted kontrolü
      Navigator.of(context).pop(); // "Onaylanıyor" dialog'unu kapat
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Hata: Fatura onaylanamadı. $e"),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<InvoiceDetail?>(
      future: _invoiceFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
              backgroundColor: const Color(0xFFF3F4F6),
              body: Center(
                  child: CircularProgressIndicator(
                      color: const Color(0xFF1E3A8A))));
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return Scaffold(
              backgroundColor: const Color(0xFFF3F4F6),
              appBar: AppBar(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                title: const Text("Fatura Detayı"),
              ),
              body: Center(
                  child: Text('Fatura verisi yüklenemedi: ${snapshot.error}')));
        }

        final invoice = _isEditMode ? _editableInvoice! : _originalInvoice!;

        return Scaffold(
          backgroundColor: const Color(0xFFF3F4F6),
          // LayoutBuilder ile responsive tasarım
          body: LayoutBuilder(
            builder: (context, constraints) {
              // Geniş ekranlar için web/desktop arayüzü
              if (constraints.maxWidth > 900) {
                return _buildWebLayout(context, invoice);
              }
              // Dar ekranlar için mobil arayüzü
              return _buildMobileLayout(context, invoice);
            },
          ),
          // Alt bar sadece mobilde görünsün
          bottomNavigationBar: LayoutBuilder(builder: (context, constraints) {
            if (constraints.maxWidth <= 900) {
              return _buildBottomBar(context, invoice);
            }
            return const SizedBox.shrink(); // Web'de alt bar olmayacak
          }),
        );
      },
    );
  }

  // --- MOBİL ARYÜZ ---
  Widget _buildMobileLayout(BuildContext context, InvoiceDetail invoice) {
    return Form(
      key: _formKey,
      child: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context, invoice),
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                [
                  _buildSmartSummaryCard(context, invoice.structured,
                      isWeb: false),
                  const SizedBox(height: 16),
                  _buildProductItemsList(context, invoice.structured,
                      isWeb: false),
                  const SizedBox(height: 16),
                  _buildOtherFieldsCard(context, invoice.structured,
                      isWeb: false),
                  const SizedBox(height: 16),
                  _buildOcrRawDataCard(context, invoice.structured),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WEB ARYÜÜ (YENİ TASARIM) ---
  Widget _buildWebLayout(BuildContext context, InvoiceDetail invoice) {
    return Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Text(invoice.originalName, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 16),
              IconButton(
                icon: Icon(_isEditMode ? Icons.close : Icons.edit_outlined),
                onPressed: _toggleEditMode,
                tooltip: _isEditMode
                    ? "Değişiklikleri İptal Et"
                    : "Faturayı Düzenle",
              ),
            ],
          ),
          elevation: 1,
          shadowColor: Colors.black.withAlpha(25), // withOpacity(0.1)
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        body: Row(
          children: [
            Expanded(
              flex: 60,
              child: Container(
                color: Colors.blueGrey[900],
                alignment: Alignment.center,
                child: GestureDetector(
                  onTap: () => _showImageDialog(context, invoice.thumbnailUrl),
                  child: InteractiveViewer(
                    child: Image.network(
                      invoice.thumbnailUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(
                              child: Text('Fatura önizlemesi yüklenemedi.',
                                  style: TextStyle(color: Colors.white))),
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                            child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ));
                      },
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 40,
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildSmartSummaryCard(context, invoice.structured,
                                isWeb: true),
                            const SizedBox(height: 20),
                            _buildProductItemsList(context, invoice.structured,
                                isWeb: true),
                            const _SectionDivider(),
                            _buildOtherFieldsCard(context, invoice.structured,
                                isWeb: true),
                            const _SectionDivider(),
                            _buildOcrRawDataCard(context, invoice.structured),
                          ],
                        ),
                      ),
                    ),
                    _buildBottomBar(context, invoice),
                  ],
                ),
              ),
            ),
          ],
        ));
  }

  // --- YENİ TASARIM BİLEŞENLERİ ---

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF1E3A8A), size: 20),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF1E3A8A),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartSummaryCard(
      BuildContext context, StructuredInvoice structuredData,
      {required bool isWeb}) {
    // Mobil için mevcut davranışı koru
    if (!isWeb) {
      final List<Widget> summaryRows = [];
      if (structuredData.saticiUnvani != null &&
          structuredData.saticiUnvani!.isNotEmpty) {
        summaryRows.add(_buildInfoRow(
            "Satıcı Ünvanı", structuredData.saticiUnvani,
            controller: _controllers['satici_unvani']));
      }
      if (structuredData.faturaTarihi != null &&
          structuredData.faturaTarihi!.isNotEmpty) {
        summaryRows.add(_buildInfoRow(
            "Fatura Tarihi", structuredData.faturaTarihi,
            controller: _controllers['fatura_tarihi']));
      }
      if (structuredData.faturaNumarasi != null &&
          structuredData.faturaNumarasi!.isNotEmpty) {
        summaryRows.add(_buildInfoRow(
            "Fatura Numarası", structuredData.faturaNumarasi,
            controller: _controllers['fatura_numarasi']));
      }
      return Card(
        color: Colors.white,
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildInfoRow("Ödenecek Tutar", structuredData.odenecekTutar,
                  isLarge: true, controller: _controllers['odenecek_tutar']),
              if (summaryRows.isNotEmpty) const Divider(height: 24),
              ...summaryRows,
            ],
          ),
        ),
      );
    }

    // WEB: Dinamik ve esnek özet kartı
    final otherDetails = <Widget>[];
    if (structuredData.saticiUnvani != null &&
        structuredData.saticiUnvani!.isNotEmpty) {
      otherDetails.add(_buildInfoRow(
          "Satıcı Ünvanı", structuredData.saticiUnvani,
          isWeb: true, controller: _controllers['satici_unvani']));
    }
    if (structuredData.faturaTarihi != null &&
        structuredData.faturaTarihi!.isNotEmpty) {
      otherDetails.add(_buildInfoRow(
          "Fatura Tarihi", structuredData.faturaTarihi,
          isWeb: true, controller: _controllers['fatura_tarihi']));
    }
    if (structuredData.faturaNumarasi != null &&
        structuredData.faturaNumarasi!.isNotEmpty) {
      otherDetails.add(_buildInfoRow(
          "Fatura Numarası", structuredData.faturaNumarasi,
          isWeb: true, controller: _controllers['fatura_numarasi']));
    }

    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12), // withOpacity(0.05)
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: const Border(
          left: BorderSide(
            color: Color(0xFF1E3A8A),
            width: 4,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize:
            MainAxisSize.min, // Kartın yüksekliğini içeriğine göre ayarla
        children: [
          _isEditMode
              ? _buildEditableTitleRow(
                  'Ödenecek Tutar', // label
                  structuredData.odenecekTutar, // initialValue
                  onSaved: (newValue) {
                    _editableInvoice!.structured.odenecekTutar = newValue;
                  },
                )
              : Text(structuredData.odenecekTutar ?? 'N/A',
                  style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                      letterSpacing: 0.5)),
          !_isEditMode
              ? Text(
                  NumberFormat.currency(locale: 'tr_TR', symbol: '₺').format(
                      double.tryParse(structuredData.odenecekTutar
                                  ?.replaceAll(',', '.') ??
                              '0.0') ??
                          0.0),
                  style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.black),
                )
              : const SizedBox.shrink(),
          // Sadece diğer detaylar varsa ayraç ve listeyi göster
          if (otherDetails.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            ...otherDetails,
          ]
        ],
      ),
    );
  }

  Widget _buildInfoRow(String title, String? value,
      {bool isLarge = false,
      bool isWeb = false,
      TextEditingController? controller}) {
    final bool isValueMissing = value == null || value.isEmpty;

    if (_isEditMode) {
      return _buildEditableInfoRow(title, value, onSaved: (newValue) {
        final structured = _editableInvoice?.structured;
        if (structured == null) return;

        if (controller == _controllers['odenecek_tutar']) {
          structured.odenecekTutar = newValue;
        } else if (controller == _controllers['satici_unvani']) {
          structured.saticiUnvani = newValue;
        } else if (controller == _controllers['fatura_tarihi']) {
          structured.faturaTarihi = newValue;
        } else if (controller == _controllers['fatura_numarasi']) {
          structured.faturaNumarasi = newValue;
        } else {
          // Diğer alanlar veya ürün kalemleri için anahtarı bul
          _controllers.forEach((key, value) {
            if (value == controller) {
              if (key.startsWith('other_')) {
                final originalKey = key.substring(6);
                structured.otherFields[originalKey] = newValue;
              } else if (key.startsWith('product_')) {
                final parts = key.split('_');
                final itemIndex = int.parse(parts[1]);
                final fieldKey =
                    parts.sublist(2).join('_'); // handles keys with underscores

                if (itemIndex < structured.urunKalemleri.length) {
                  if (fieldKey == 'mal_hizmet') {
                    structured.urunKalemleri[itemIndex].malHizmet =
                        newValue ?? '';
                  } else {
                    structured.urunKalemleri[itemIndex].fields[fieldKey] =
                        newValue;
                  }
                }
              }
            }
          });
        }
      });
    }

    if (!isWeb) {
      // Mobil için eski kod
      if (isLarge) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(color: Color(0xFF323232), fontSize: 14)),
            Text(
              isValueMissing
                  ? '0.00'
                  : NumberFormat.currency(locale: 'tr_TR', symbol: '₺').format(
                      double.tryParse(value.replaceAll(',', '.')) ?? 0.0),
              style: const TextStyle(
                  color: Colors.black,
                  fontSize: 32,
                  fontWeight: FontWeight.bold),
            ),
          ],
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(color: Color(0xFF323232), fontSize: 12)),
            Text(
              isValueMissing ? '' : value,
              style: TextStyle(
                  color: isValueMissing
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF323232),
                  fontSize: 16,
                  fontWeight:
                      isValueMissing ? FontWeight.bold : FontWeight.normal),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(
              flex: 2,
              child: Text(title.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                      letterSpacing: 0.5))),
          Expanded(
            flex: 3,
            child: isValueMissing
                ? Row(children: const [
                    Icon(Icons.warning_amber_rounded,
                        color: Color(0xFFF59E0B), size: 16),
                    SizedBox(width: 4),
                    Text("Belirtilmemiş",
                        style:
                            TextStyle(color: Color(0xFFF59E0B), fontSize: 14)),
                  ])
                : Text(value,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF323232))),
          ),
        ],
      ),
    );
  }

  // --- EDİT MODU İÇİN YARDIMCI WIDGET'LAR ---

  Widget _buildEditableInfoRow(String label, String? initialValue,
      {required Function(String?) onSaved, bool isNumeric = false}) {
    String controllerKey = '$label-$initialValue-${onSaved.hashCode}';
    if (!_controllers.containsKey(controllerKey)) {
      _controllers[controllerKey] = TextEditingController(text: initialValue);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      // Wrap with SingleChildScrollView to prevent overflow on smaller screens
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: _controllers[controllerKey],
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8.0),
                border: UnderlineInputBorder(),
              ),
              keyboardType: isNumeric
                  ? TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
              onSaved: onSaved,
              validator: (value) {
                // Allow empty values
                if (value == null || value.isEmpty) {
                  return null;
                }
                // For numeric fields (but not 'Miktar'), validate if it's a valid number
                // Allows both comma and dot for decimals.
                if (isNumeric && label != 'Miktar') {
                  final number = double.tryParse(value.replaceAll(',', '.'));
                  if (number == null) {
                    return 'Geçerli bir sayı girin';
                  }
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableTitleRow(String label, String? initialValue,
      {required Function(String?) onSaved}) {
    String controllerKey = '$label-$initialValue-${onSaved.hashCode}';
    if (!_controllers.containsKey(controllerKey)) {
      _controllers[controllerKey] = TextEditingController(text: initialValue);
    }
    return TextFormField(
      controller: _controllers[controllerKey],
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      decoration: const InputDecoration(
        isDense: true,
        border: InputBorder.none,
      ),
      onSaved: onSaved,
      validator: (value) {
        // Allow empty values, so no validation needed here anymore.
        return null;
      },
    );
  }

  Widget _buildProductItemsList(
      BuildContext context, StructuredInvoice structured,
      {required bool isWeb}) {
    // Ürün kalemleri listesini ve "Yeni Ekle" butonunu (düzenleme modunda) içeren bir Column
    final List<Widget> children = [
      if (isWeb) ...[
        _buildSectionHeader(
            "Ürün ve Hizmet Kalemleri", Icons.shopping_cart_outlined),
        const SizedBox(height: 8),
      ] else ...[
        const Text("Ürün ve Hizmet Kalemleri",
            style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
      ],
      ...structured.urunKalemleri.asMap().entries.map((entry) {
        // Mevcut ürün kalemi render etme mantığı
        return _buildProductItem(context, entry.key, entry.value, isWeb: isWeb);
      }),
      /* YENİ KALEM EKLEME ÖZELLİĞİ, YENİ GEREKSİNİMLERLE KALDIRILDI
      if (_isEditMode)
        Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add_circle_outline),
              label: const Text("Yeni Kalem Ekle"),
              onPressed: _addNewProductItem,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1E3A8A),
                side: const BorderSide(color: Color(0xFF1E3A8A)),
              ),
            ),
          ),
        ),
      */
    ];

    if (structured.urunKalemleri.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment:
          isWeb ? CrossAxisAlignment.start : CrossAxisAlignment.stretch,
      children: children,
    );
  }

  // Ürün kalemlerini render etmek için yeni bir yardımcı fonksiyon
  Widget _buildProductItem(BuildContext context, int index, UrunKalemi item,
      {required bool isWeb}) {
    if (!isWeb) {
      final validFields = item.fields.entries.where((entry) {
        final value = entry.value;
        return value != null && value.toString().isNotEmpty;
      }).toList();

      if (_isEditMode) {
        return Card(
          color: Colors.white,
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildEditableInfoRow(
                  "Ürün Adı",
                  _controllers['product_${index}_mal_hizmet']!.text,
                  onSaved: (newValue) {
                    final structured = _editableInvoice?.structured;
                    if (structured == null) return;
                    if (item.malHizmet != newValue) {
                      structured.urunKalemleri[index].malHizmet =
                          newValue ?? '';
                    }
                  },
                ),
                const Divider(height: 20),
                ...validFields.map((field) => _buildEditableInfoRow(
                      _formatFieldName(field.key),
                      _controllers['product_${index}_${field.key}']!.text,
                      onSaved: (newValue) {
                        final structured = _editableInvoice?.structured;
                        if (structured == null) return;
                        if (field.key == 'birim_fiyat') {
                          structured.urunKalemleri[index]
                              .fields['birim_fiyat'] = newValue;
                        } else if (field.key == 'kdv_orani') {
                          structured.urunKalemleri[index].fields['kdv_orani'] =
                              newValue;
                        } else if (field.key == 'miktar') {
                          structured.urunKalemleri[index].fields['miktar'] =
                              newValue;
                        } else {
                          structured.urunKalemleri[index].fields[field.key] =
                              newValue;
                        }
                      },
                      isNumeric: ['birim_fiyat', 'kdv_orani', 'miktar']
                          .contains(field.key),
                    )),
              ],
            ),
          ),
        );
      }

      return Card(
          color: Colors.white,
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      item.displayName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const Divider(height: 20),
                    Wrap(
                        spacing: 24.0,
                        runSpacing: 12.0,
                        children: validFields.map((entry) {
                          return SizedBox(
                              width: 180,
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _formatFieldName(entry.key),
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      entry.value.toString(),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF323232),
                                      ),
                                    ),
                                  ]));
                        }).toList())
                  ])));
    }

    // WEB
    final validFields = item.fields.entries
        .where((e) => e.value != null && e.value.toString().isNotEmpty)
        .toList();

    if (_isEditMode) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 20.0),
        child: Card(
          color: Colors.white,
          elevation: 2,
          shadowColor: Colors.black.withAlpha(25), // withOpacity(0.1)
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildEditableInfoRow(
                  "Ürün Adı",
                  _controllers['product_${index}_mal_hizmet']!.text,
                  onSaved: (newValue) {
                    final structured = _editableInvoice?.structured;
                    if (structured == null) return;
                    if (item.malHizmet != newValue) {
                      structured.urunKalemleri[index].malHizmet =
                          newValue ?? '';
                    }
                  },
                ),
                const Divider(height: 20),
                Wrap(
                  spacing: 24.0,
                  runSpacing: 16.0,
                  children: validFields.map((field) {
                    return SizedBox(
                      width: 150,
                      child: _buildEditableInfoRow(
                        _formatFieldName(field.key),
                        _controllers['product_${index}_${field.key}']!.text,
                        onSaved: (newValue) {
                          final structured = _editableInvoice?.structured;
                          if (structured == null) return;
                          if (field.key == 'birim_fiyat') {
                            structured.urunKalemleri[index]
                                .fields['birim_fiyat'] = newValue;
                          } else if (field.key == 'kdv_orani') {
                            structured.urunKalemleri[index]
                                .fields['kdv_orani'] = newValue;
                          } else if (field.key == 'miktar') {
                            structured.urunKalemleri[index].fields['miktar'] =
                                newValue;
                          } else {
                            structured.urunKalemleri[index].fields[field.key] =
                                newValue;
                          }
                        },
                        isNumeric: ['birim_fiyat', 'kdv_orani', 'miktar']
                            .contains(field.key),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
            child: Text(
              item.displayName,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF323232)),
            ),
          ),
          MouseRegion(
            onEnter: (_) => setState(() => _hoveredProductIndex = index),
            onExit: (_) => setState(() => _hoveredProductIndex = null),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: Card(
                color: _hoveredProductIndex == index
                    ? const Color(0xFFF9FAFB)
                    : Colors.white,
                elevation: _hoveredProductIndex == index ? 6 : 2,
                shadowColor: Colors.black.withAlpha(25), // withOpacity(0.1)
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Wrap(
                    spacing: 24.0, // Yatay boşluk
                    runSpacing: 16.0, // Dikey boşluk
                    children: validFields.map((field) {
                      return SizedBox(
                        width: 150,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatFieldName(field.key).toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7280),
                                  letterSpacing: 0.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              field.value.toString(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF323232),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtherFieldsCard(
      BuildContext context, StructuredInvoice structured,
      {required bool isWeb}) {
    // Değeri olan alanları ETKİN bir şekilde filtrele
    final validOtherFields = structured.otherFields.entries
        .where((e) => e.value != null && e.value.toString().trim().isNotEmpty)
        .toList();

    if (validOtherFields.isEmpty) return const SizedBox.shrink();

    if (!isWeb) {
      // Mobil için eski kod...
      return Card(
        color: Colors.white,
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("📝 İncelenecek Diğer Alanlar",
                  style: TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const Divider(),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 4, // Genişlik / Yükseklik oranı
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 8,
                ),
                itemCount: validOtherFields.length,
                itemBuilder: (context, index) {
                  final entry = validOtherFields[index];
                  final value = entry.value;
                  final isValueMissing =
                      value == null || (value is String && value.isEmpty);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isEditMode)
                        TextFormField(
                          controller: _controllers['other_${entry.key}'],
                          decoration: InputDecoration(
                              labelText: _formatFieldName(entry.key)),
                          onChanged: (newValue) {
                            _editableInvoice
                                ?.structured.otherFields[entry.key] = newValue;
                          },
                        )
                      else ...[
                        Text(_formatFieldName(entry.key),
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                        Text(
                          isValueMissing ? "-" : value.toString(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isValueMissing
                                ? Colors.grey[400]
                                : const Color(0xFF323232),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ]
                    ],
                  );
                },
              )
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("İncelenecek Diğer Alanlar", Icons.info_outline),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 250,
            childAspectRatio: 4,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
          ),
          itemCount: validOtherFields.length,
          itemBuilder: (context, index) {
            final entry = validOtherFields[index];
            return _isEditMode
                ? _buildEditableInfoRow(_formatFieldName(entry.key),
                    _controllers['other_${entry.key}']!.text,
                    onSaved: (newValue) {
                    final structured = _editableInvoice?.structured;
                    if (structured == null) return;
                    structured.otherFields[entry.key] = newValue;
                  }, isNumeric: false)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_formatFieldName(entry.key).toUpperCase(),
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                              letterSpacing: 0.5)),
                      Text(
                        entry.value.toString(),
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF323232)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  );
          },
        ),
      ],
    );
  }

  // --- DİĞER WIDGETLAR (SliverAppBar, OcrDataCard, BottomBar vb.) ---

  Widget _buildSliverAppBar(BuildContext context, InvoiceDetail invoice) {
    return SliverAppBar(
      backgroundColor: const Color(0xFF1E3A8A),
      expandedHeight: 250.0,
      floating: false,
      pinned: true,
      leading: const BackButton(color: Colors.white),
      actions: [
        IconButton(
          icon: Icon(_isEditMode ? Icons.close : Icons.edit_outlined,
              color: Colors.white),
          onPressed: _toggleEditMode,
          tooltip: _isEditMode ? "Değişiklikleri İptal Et" : "Faturayı Düzenle",
        ),
        IconButton(
          icon: const Icon(Icons.image_outlined, color: Colors.white),
          onPressed: () => _showImageViewer(context, invoice.fileUrl),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          invoice.originalName,
          style: const TextStyle(color: Colors.white, fontSize: 16.0),
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        background: GestureDetector(
          onTap: () => _showImageViewer(context, invoice.fileUrl),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                invoice.thumbnailUrl,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(color: Colors.grey[700]),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(0.0, 0.5),
                    end: Alignment.center,
                    colors: <Color>[
                      Color(0x60000000),
                      Color(0x00000000),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOcrRawDataCard(
      BuildContext context, StructuredInvoice structured) {
    return Card(
      color: Colors.white,
      elevation: 2,
      child: ExpansionTile(
        title: const Text("⚠️ OCR Tarafından Okunan Ham Bilgileri Göster",
            style: TextStyle(
                color: Color(0xFF323232), fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.keyboard_arrow_down),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0).copyWith(top: 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(4)),
              child: Text(structured.aliciUnvan),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, InvoiceDetail invoice) {
    final bool isApproved = invoice.structured.status == 'approved';
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25), // withOpacity(0.1)
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isEditMode)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save_alt_outlined),
                label: const Text('Değişiklikleri Kaydet'),
                onPressed: _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(0xFF1E3A8A), // Ana tema rengi (Mavi)
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ElevatedButton(
            onPressed: isApproved || _isEditMode ? null : _approveInvoice,
            style: ButtonStyle(
              padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(vertical: 16)),
              backgroundColor: WidgetStateProperty.resolveWith<Color>(
                (Set<WidgetState> states) {
                  if (states.contains(WidgetState.disabled)) {
                    return Colors.grey;
                  }
                  if (states.contains(WidgetState.hovered)) {
                    return const Color(0xFF1E3A8A)
                        .withAlpha(230); // withOpacity(0.9)
                  }
                  return const Color(0xFF1E3A8A); // Koyu mavi
                },
              ),
              shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
            ),
            child: Text(
              isApproved ? 'Fatura Onaylandı' : 'Faturayı Onayla',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // --- YARDIMCI FONKSİYONLAR ---
  String _formatFieldName(String key) {
    return key.replaceAll('_', ' ').split(' ').map((str) {
      if (str.isEmpty) return '';
      return str[0].toUpperCase() + str.substring(1);
    }).join(' ');
  }

  void _showImageViewer(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        // Kenar boşluklarını kaldırarak tam ekran olmasını sağla
        insetPadding: EdgeInsets.zero,
        // Arka planı yarı saydam yaparak arkadaki ekranın görünmesini sağla
        backgroundColor: Colors.black.withAlpha(191), // ~0.75 opacity
        child: Stack(
          children: [
            // PDF görüntüleyiciyi merkeze yerleştir
            Center(
              child: SfPdfViewer.network(url),
            ),
            // Sol üste konumlandırılmış kapatma butonu
            Positioned(
              top: 40.0, // Status bar için güvenli alan
              left: 16.0,
              child: CircleAvatar(
                backgroundColor: Colors.black.withAlpha(128), // ~0.5 opacity
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImageDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: EdgeInsets.zero,
        backgroundColor: Colors.black.withAlpha(191),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Center(
                      child: Text('Fatura önizlemesi yüklenemedi.',
                          style: TextStyle(color: Colors.white))),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                        child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ));
                  },
                ),
              ),
            ),
            Positioned(
              top: 40.0,
              left: 16.0,
              child: CircleAvatar(
                backgroundColor: Colors.black.withAlpha(128),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Bölüm ayıracı için özel bir widget
class _SectionDivider extends StatelessWidget {
  const _SectionDivider();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32.0),
      child: Divider(color: Colors.grey[300], thickness: 1),
    );
  }
}
