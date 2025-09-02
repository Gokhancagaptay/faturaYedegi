import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fatura_yeni/features/dashboard/models/invoice_model.dart';
import 'package:fatura_yeni/core/services/api_service.dart';
import 'package:fatura_yeni/core/services/storage_service.dart';

enum InvoiceStatusFilter { approved, pending, all }

class StatusInvoicesScreen extends StatefulWidget {
  final InvoiceStatusFilter filter;
  const StatusInvoicesScreen({super.key, required this.filter});

  @override
  State<StatusInvoicesScreen> createState() => _StatusInvoicesScreenState();
}

class _StatusInvoicesScreenState extends State<StatusInvoicesScreen> {
  final ApiService _apiService = ApiService();
  final StorageService _storage = StorageService();
  late Future<List<Invoice>> _allInvoicesFuture;

  @override
  void initState() {
    super.initState();
    _allInvoicesFuture = _loadAllInvoices();
  }

  Future<List<Invoice>> _loadAllInvoices() async {
    try {
      final token = await _storage.getToken();
      if (token == null) throw Exception('Authentication token not found.');
      final res = await _apiService.getInvoices(token);
      final data = (res['invoices'] as List<dynamic>);
      return data.map((e) => Invoice.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  bool _matchesFilter(Invoice i) {
    switch (widget.filter) {
      case InvoiceStatusFilter.approved:
        return i.status == 'approved' ||
            (i.status == 'processed' && i.isApproved == true);
      case InvoiceStatusFilter.pending:
        return i.status == 'uploading' ||
            i.status == 'queued' ||
            i.status == 'processing' ||
            (i.status == 'processed' && i.isApproved != true);
      case InvoiceStatusFilter.all:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = () {
      switch (widget.filter) {
        case InvoiceStatusFilter.approved:
          return 'Onaylanan Faturalar';
        case InvoiceStatusFilter.pending:
          return 'Beklemede Faturalar';
        case InvoiceStatusFilter.all:
          return 'Toplam Faturalar';
      }
    }();

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder<List<Invoice>>(
        future: _allInvoicesFuture,
        builder: (context, snapshot) {
          final invoices = (snapshot.data ?? []).where(_matchesFilter).toList();
          // Paket id'si yok modelde; backend cevabında varsa eklememiş olabiliriz. Geçici olarak "Bilinmeyen Paket" altında gruplayalım.
          // İyileştirme: ApiService.getPackages ile paket->fatura eşlemesi alınabilir.
          final groups = <String, List<Invoice>>{};
          for (final inv in invoices) {
            final pkgName = 'Paket';
            groups.putIfAbsent(pkgName, () => []).add(inv);
          }

          if (groups.isEmpty) {
            return const Center(child: Text('Kayıt bulunamadı'));
          }

          return ListView(
            children: groups.entries.map((e) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.key,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...e.value.map((inv) => _invoiceTile(inv)),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildFileTypeIcon(String? fileName) {
    if (fileName == null) {
      return const Icon(Icons.description, color: Color(0xFF6B7280));
    }

    final extension = fileName.split('.').last.toLowerCase();
    IconData iconData;
    Color iconColor;

    switch (extension) {
      case 'pdf':
        iconData = Icons.picture_as_pdf;
        iconColor = const Color(0xFFDC2626);
        break;
      case 'doc':
      case 'docx':
        iconData = Icons.description;
        iconColor = const Color(0xFF2563EB);
        break;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
        iconData = Icons.image;
        iconColor = const Color(0xFF059669);
        break;
      default:
        iconData = Icons.description;
        iconColor = const Color(0xFF6B7280);
    }

    return Icon(iconData, color: iconColor);
  }

  Widget _invoiceTile(Invoice invoice) {
    final fmt = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(6),
            ),
            child: invoice.thumbnailUrl != null &&
                    invoice.thumbnailUrl!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      invoice.thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildFileTypeIcon(invoice.fileName);
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                            strokeWidth: 2,
                          ),
                        );
                      },
                    ),
                  )
                : _buildFileTypeIcon(invoice.fileName),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    invoice.sellerName.isNotEmpty
                        ? invoice.sellerName
                        : (invoice.fileName ?? 'Fatura'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(DateFormat('d MMMM yyyy', 'tr_TR').format(invoice.date),
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF6B7280))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(fmt.format(invoice.totalAmount),
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
