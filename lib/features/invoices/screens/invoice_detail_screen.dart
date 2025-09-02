import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fatura_yeni/core/services/api_service.dart';
import 'package:fatura_yeni/core/services/storage_service.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';

// --- VERİ MODELLERİ (Final) ---
class InvoiceDetail {
  final String originalName;
  final String fileUrl;
  final String thumbnailUrl;
  final StructuredInvoice structured;

  InvoiceDetail({
    required this.originalName,
    required this.fileUrl,
    required this.thumbnailUrl,
    required this.structured,
  });

  factory InvoiceDetail.fromJson(Map<String, dynamic> json) {
    return InvoiceDetail(
      originalName: json['originalName'] ?? 'N/A',
      fileUrl: json['fileUrl'] ?? '',
      thumbnailUrl: json['thumbnailUrl'] ?? '',
      structured: StructuredInvoice.fromJson(json['structured'] ?? {}),
    );
  }
}

class StructuredInvoice {
  final String? odenecekTutar;
  final String? saticiUnvani;
  final String? faturaTarihi;
  final String? faturaNumarasi;
  final String aliciUnvan; // Ham veri için
  final List<UrunKalemi> urunKalemleri;
  final Map<String, dynamic> otherFields; // Diğer tüm alanlar için

  StructuredInvoice({
    this.odenecekTutar,
    this.saticiUnvani,
    this.faturaTarihi,
    this.faturaNumarasi,
    required this.aliciUnvan,
    required this.urunKalemleri,
    required this.otherFields,
  });

  factory StructuredInvoice.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> structuredData = Map.from(json);

    // Bilinen ve özel olarak işlenen alanları ayıkla
    final odenecekTutar = structuredData.remove('odenecek_tutar')?.toString();
    final saticiUnvani = structuredData.remove('satici_unvani')?.toString();
    final faturaTarihi = structuredData.remove('fatura_tarihi')?.toString();
    final faturaNumarasi = structuredData.remove('fatura_numarasi')?.toString();
    final aliciUnvan =
        structuredData.remove('alici_unvan')?.toString() ?? 'N/A';
    final urunKalemleriList =
        (structuredData.remove('urun_kalemleri') as List? ?? [])
            .map((i) => UrunKalemi.fromJson(i))
            .toList();

    // Geriye kalanlar otherFields'a atanır
    final otherFields = structuredData;

    return StructuredInvoice(
      odenecekTutar: odenecekTutar,
      saticiUnvani: saticiUnvani,
      faturaTarihi: faturaTarihi,
      faturaNumarasi: faturaNumarasi,
      aliciUnvan: aliciUnvan,
      urunKalemleri: urunKalemleriList,
      otherFields: otherFields,
    );
  }
}

class UrunKalemi {
  final String malHizmet;
  final Map<String, dynamic> fields;

  UrunKalemi({required this.malHizmet, required this.fields});

  factory UrunKalemi.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> otherFields = Map.from(json);
    final String malHizmet =
        otherFields.remove('mal_hizmet')?.toString() ?? 'N/A';
    return UrunKalemi(malHizmet: malHizmet, fields: otherFields);
  }
}

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
      return InvoiceDetail.fromJson(data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fatura yüklenemedi: $e')),
        );
      }
      return null;
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
                backgroundColor: const Color(0xFF1E3A8A),
              ),
              body: const Center(child: Text('Fatura verisi yüklenemedi.')));
        }

        final invoice = snapshot.data!;
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
    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(context, invoice),
        SliverPadding(
          padding: const EdgeInsets.all(16.0),
          sliver: SliverList(
            delegate: SliverChildListDelegate(
              [
                _buildSmartSummaryCard(context, invoice.structured),
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
    );
  }

  // --- WEB ARYÜZÜ ---
  Widget _buildWebLayout(BuildContext context, InvoiceDetail invoice) {
    return Row(
      children: [
        // Sol Panel: PDF Görüntüleyici
        Expanded(
          flex: 55,
          child: FutureBuilder<Uint8List>(
            future: http.get(Uri.parse(invoice.fileUrl)).then((response) {
              if (response.statusCode == 200) {
                return response.bodyBytes;
              }
              throw Exception('PDF yüklenemedi: ${response.statusCode}');
            }),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return const Center(
                    child: Text('Fatura önizlemesi yüklenemedi.'));
              }
              return SfPdfViewer.memory(snapshot.data!);
            },
          ),
        ),
        // Sağ Panel: Veri Alanı
        Expanded(
          flex: 45,
          child: Container(
            color: const Color(0xFFF3F4F6),
            child: Column(
              children: [
                // Panel Başlığı
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16.0),
                  color: const Color(0xFF1E3A8A),
                  child: Text(
                    invoice.originalName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Kaydırılabilir içerik
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSmartSummaryCard(context, invoice.structured),
                        const SizedBox(height: 16),
                        _buildProductItemsList(context, invoice.structured,
                            isWeb: true),
                        const SizedBox(height: 16),
                        _buildOtherFieldsCard(context, invoice.structured,
                            isWeb: true),
                        const SizedBox(height: 16),
                        _buildOcrRawDataCard(context, invoice.structured),
                      ],
                    ),
                  ),
                ),
                // Sabit Eylem Butonu
                _buildBottomBar(context, invoice),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- PAYLAŞILAN BİLEŞENLER ---
  Widget _buildSliverAppBar(BuildContext context, InvoiceDetail invoice) {
    return SliverAppBar(
      backgroundColor: const Color(0xFF1E3A8A),
      expandedHeight: 250.0,
      floating: false,
      pinned: true,
      leading: const BackButton(color: Colors.white),
      actions: [
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

  Widget _buildSmartSummaryCard(
      BuildContext context, StructuredInvoice structured) {
    return Card(
      color: Colors.white,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInfoRow("Ödenecek Tutar", structured.odenecekTutar,
                isLarge: true),
            const Divider(height: 24),
            _buildInfoRow("Satıcı Ünvanı", structured.saticiUnvani,
                emptyText: "Satıcı Bilgisi Belirtilmemiş"),
            _buildInfoRow("Fatura Tarihi", structured.faturaTarihi,
                emptyText: "Fatura Tarihi Bulunamadı"),
            _buildInfoRow("Fatura Numarası", structured.faturaNumarasi,
                emptyText: "Fatura Numarası Bulunamadı"),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String title, String? value,
      {String emptyText = "", bool isLarge = false}) {
    final bool isValueMissing = value == null || value.isEmpty;

    if (isLarge) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(color: Color(0xFF323232), fontSize: 14)),
          Text(
            isValueMissing
                ? '0.00'
                : NumberFormat.currency(locale: 'tr_TR', symbol: '₺')
                    .format(double.tryParse(value.replaceAll(',', '.')) ?? 0.0),
            style: const TextStyle(
                color: Colors.black, fontSize: 32, fontWeight: FontWeight.bold),
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
            isValueMissing ? emptyText : value,
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

  Widget _buildProductItemsList(
      BuildContext context, StructuredInvoice structured,
      {required bool isWeb}) {
    if (structured.urunKalemleri.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Ürün ve Hizmet Kalemleri",
            style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...structured.urunKalemleri.map((item) => Card(
              color: Colors.white,
              elevation: 1,
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(item.malHizmet,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const Divider(),
                    ...item.fields.entries.map((entry) => Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_formatFieldName(entry.key),
                                  style: const TextStyle(
                                      color: Color(0xFF323232))),
                              // Web'de değerleri sağa yasla
                              if (isWeb) const Spacer(),
                              Text(entry.value.toString(),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildOtherFieldsCard(
      BuildContext context, StructuredInvoice structured,
      {required bool isWeb}) {
    if (structured.otherFields.isEmpty) {
      return const SizedBox.shrink();
    }

    // Web için iki sütunlu Grid yapısı
    if (isWeb) {
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
                itemCount: structured.otherFields.length,
                itemBuilder: (context, index) {
                  final entry = structured.otherFields.entries.elementAt(index);
                  final value = entry.value;
                  final isValueMissing =
                      value == null || (value is String && value.isEmpty);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
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
                    ],
                  );
                },
              )
            ],
          ),
        ),
      );
    }

    // Mobil için tek sütunlu liste yapısı (Mevcut kod)
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
            ...structured.otherFields.entries.map((entry) {
              final value = entry.value;
              final bool isValueMissing =
                  value == null || (value is String && value.isEmpty);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatFieldName(entry.key),
                        style: const TextStyle(fontSize: 14)),
                    Text(
                      isValueMissing ? "-" : value.toString(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isValueMissing
                            ? Colors.grey[400]
                            : const Color(0xFF323232),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
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
    return BottomAppBar(
      color: const Color(0xFFF3F4F6),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E3A8A),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
          ),
          onPressed: () {
            // TODO: Fatura Düzenleme Ekranı'na yönlendirme ekle.
            // Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditInvoiceScreen(invoice: invoice)));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'Fatura Düzenleme ekranı sonraki adımda geliştirilecektir.')),
            );
          },
          child: const Text('Faturayı Düzenle ve Onayla'),
        ),
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
}
