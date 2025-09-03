import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:fatura_yeni/core/services/api_service.dart';
import 'package:fatura_yeni/core/services/storage_service.dart';
import 'package:fatura_yeni/core/services/report_service.dart';
import 'package:fatura_yeni/core/services/websocket_service.dart';

import 'package:fatura_yeni/core/providers/theme_provider.dart';
import 'package:fatura_yeni/core/constants/dashboard_constants.dart';
import 'package:fatura_yeni/features/dashboard/models/invoice_model.dart';
import 'package:fatura_yeni/features/dashboard/providers/dashboard_provider.dart';
import 'package:fatura_yeni/features/auth/screens/login_register_screen.dart';
import 'package:fatura_yeni/features/invoices/screens/invoice_detail_screen.dart';

class PackageDetailScreen extends StatefulWidget {
  final String packageId;

  const PackageDetailScreen({
    super.key,
    required this.packageId,
  });

  @override
  State<PackageDetailScreen> createState() => _PackageDetailScreenState();
}

class _PackageDetailScreenState extends State<PackageDetailScreen> {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  final Set<String> _expandedCards = <String>{};

  Map<String, dynamic>? _packageData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAll();
    _connectWebSocket();
  }

  void _connectWebSocket() {
    // WebSocket connection will be implemented later
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await _storageService.getToken();
      if (token == null) {
        throw Exception('Token bulunamadı');
      }

      // Hem paket detayını hem faturalarını al
      final packageData =
          await _apiService.getPackageDetail(token, widget.packageId);
      final invoicesData =
          await _apiService.getPackageInvoices(token, widget.packageId);

      // Faturalar varsa paket verisine ekle
      if (invoicesData['invoices'] != null) {
        packageData['invoices'] = invoicesData['invoices'];
      } else if (invoicesData['data'] != null) {
        packageData['invoices'] = invoicesData['data'];
      }

      if (!mounted) return;
      setState(() {
        _packageData = packageData;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final colors = DashboardConstants.getColors(isDarkMode);

    return Scaffold(
      backgroundColor: colors['background'],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colors['surface'],
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors['text']),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Paket Raporu', // Başlık güncellendi
          style: TextStyle(
            color: colors['text'],
            fontSize: _getResponsiveFontSize(context, 20),
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          // Yenileme Butonu
          IconButton(
            icon: Icon(Icons.refresh, color: colors['primaryBlue']),
            onPressed: _loadAll,
            tooltip: 'Yenile',
          ),
          // Diğer Eylemler
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: colors['text']),
            onSelected: (value) {
              switch (value) {
                case 'reevaluate':
                  _showReevaluateConfirmation();
                  break;
                case 'logout':
                  _logout();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'reevaluate',
                child: Row(
                  children: [
                    Icon(Icons.refresh_sharp, color: colors['text']),
                    const SizedBox(width: 8),
                    Text('Yeniden Değerlendir',
                        style: TextStyle(color: colors['text'])),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: colors['errorRed']),
                    const SizedBox(width: 8),
                    Text('Çıkış Yap',
                        style: TextStyle(color: colors['errorRed'])),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (_isLoading) {
            return Center(
                child: CircularProgressIndicator(color: colors['primaryBlue']));
          }
          if (_error != null) {
            return _buildErrorState(colors);
          }

          final isWeb = constraints.maxWidth > 800;

          if (isWeb) {
            return _buildWebLayout(colors, isDarkMode);
          } else {
            return _buildMobileLayout(colors, isDarkMode);
          }
        },
      ),
    );
  }

  // =============================================
  // WEB LAYOUT WIDGETS
  // =============================================

  Widget _buildWebLayout(Map<String, dynamic> colors, bool isDarkMode) {
    if (_packageData == null) return const SizedBox.shrink();

    final invoices = _packageData!['invoices'] as List<dynamic>? ?? [];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sol Sütun: Özet
        Expanded(
          flex: 1,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: _buildWebSummaryCardContent(colors, isDarkMode, invoices),
          ),
        ),
        // Sağ Sütun: Faturalar
        Expanded(
          flex: 2,
          child: Container(
            color: colors['background'],
            child: _buildWebInvoicesSection(colors, isDarkMode, invoices),
          ),
        ),
      ],
    );
  }

  Widget _buildWebInvoicesSection(
      Map<String, dynamic> colors, bool isDarkMode, List<dynamic> invoices) {
    if (invoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox,
              size: _getResponsiveContainerSize(context, 48),
              color: colors['textSecondary'],
            ),
            SizedBox(height: _getResponsiveSpacing(context)),
            Text(
              'Bu pakette henüz fatura yok',
              style: TextStyle(
                color: colors['textSecondary'],
                fontSize: _getResponsiveFontSize(context, 16),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      itemCount: invoices.length,
      itemBuilder: (context, index) {
        final invoice = invoices[index];
        // Mobil kart tasarımını web için yeniden kullanıyoruz
        return _buildInvoiceCard(invoice, colors, isDarkMode);
      },
    );
  }

  // =============================================
  // MOBILE LAYOUT WIDGETS
  // =============================================

  Widget _buildMobileLayout(Map<String, dynamic> colors, bool isDarkMode) {
    return CustomScrollView(
      slivers: [
        _buildSmartSummaryCard(
            colors, isDarkMode), // Özet kartı Sliver olarak kalıyor
        _buildInvoicesSection(colors, isDarkMode),
      ],
    );
  }

  Widget _buildErrorState(Map<String, dynamic> colors) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(_getResponsivePadding(context)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: _getResponsiveContainerSize(context, 64),
              color: colors['errorRed'],
            ),
            SizedBox(height: _getResponsiveSpacing(context)),
            Text(
              'Hata Oluştu',
              style: TextStyle(
                color: colors['text'],
                fontSize: _getResponsiveFontSize(context, 20),
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: _getResponsiveSpacing(context) * 0.5),
            Text(
              _humanizeError(_error!),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors['textSecondary'],
                fontSize: _getResponsiveFontSize(context, 14),
              ),
            ),
            SizedBox(height: _getResponsiveSpacing(context) * 1.5),
            ElevatedButton.icon(
              onPressed: _loadAll,
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar Dene'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors['primaryBlue'],
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: _getResponsivePadding(context) * 1.5,
                  vertical: _getResponsivePadding(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Yeni Akıllı Özet Kartı
  Widget _buildSmartSummaryCard(Map<String, dynamic> colors, bool isDarkMode) {
    final invoices = _packageData!['invoices'] as List<dynamic>? ?? [];

    return SliverToBoxAdapter(
      child: Container(
        margin: EdgeInsets.all(_getResponsivePadding(context)),
        padding: EdgeInsets.all(_getResponsivePadding(context) * 1.25),
        decoration: BoxDecoration(
          color: colors['surface'],
          borderRadius: BorderRadius.circular(DashboardConstants.cardRadius),
          boxShadow: DashboardConstants.getCardShadow(isDarkMode),
        ),
        child: _buildSmartSummaryCardContent(colors, isDarkMode, invoices),
      ),
    );
  }

  // Özet kartının içeriği, hem web hem mobil için ortak kullanılacak
  Widget _buildSmartSummaryCardContent(
      Map<String, dynamic> colors, bool isDarkMode, List<dynamic> invoices) {
    final totalAmount = _calculateTotalAmount(invoices);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (colors['primaryBlue'] as Color)
                    .withAlpha(25), // withOpacity yerine withAlpha
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.insights,
                color: colors['primaryBlue'],
                size: _getResponsiveContainerSize(context, 24),
              ),
            ),
            SizedBox(width: _getResponsiveSpacing(context)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Akıllı Özet',
                  style: TextStyle(
                    color: colors['text'],
                    fontSize: _getResponsiveFontSize(context, 18),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Paket detayları ve analiz sonuçları',
                  style: TextStyle(
                    color: colors['textSecondary'],
                    fontSize: _getResponsiveFontSize(context, 14),
                  ),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: _getResponsiveSpacing(context) * 1.5),
        Row(
          children: [
            Expanded(
              child: _buildSummaryItem(
                'Toplam Tutar',
                '₺${totalAmount.toStringAsFixed(2)}',
                Icons.attach_money,
                colors,
              ),
            ),
            SizedBox(width: _getResponsiveSpacing(context)),
            Expanded(
              child: _buildSummaryItem(
                'Fatura Sayısı',
                invoices.length.toString(),
                Icons.receipt_long,
                colors,
              ),
            ),
          ],
        ),
        SizedBox(height: _getResponsiveSpacing(context) * 1.5),
        ElevatedButton.icon(
          onPressed: _showExportOptions,
          icon: const Icon(Icons.download, size: 18),
          label: const Text('Raporu Dışa Aktar'),
          style: ElevatedButton.styleFrom(
            backgroundColor: colors['primaryBlue'],
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  // Web'e özel, zenginleştirilmiş özet kartı içeriği
  Widget _buildWebSummaryCardContent(
      Map<String, dynamic> colors, bool isDarkMode, List<dynamic> invoices) {
    final totalAmount = _calculateTotalAmount(invoices);
    final totalItems = _calculateTotalItems(invoices);
    final totalVat = _calculateTotalVat(invoices);

    // Fatura durum dökümü
    final statusCounts = <String, int>{};
    for (var invoice in invoices) {
      final status = invoice['status'] as String? ?? 'unknown';
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (colors['primaryBlue'] as Color)
                    .withAlpha(25), // withOpacity yerine withAlpha
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.insights,
                color: colors['primaryBlue'],
                size: _getResponsiveContainerSize(context, 24),
              ),
            ),
            SizedBox(width: _getResponsiveSpacing(context)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Akıllı Özet',
                  style: TextStyle(
                    color: colors['text'],
                    fontSize: _getResponsiveFontSize(context, 18),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Paket detayları ve analiz sonuçları',
                  style: TextStyle(
                    color: colors['textSecondary'],
                    fontSize: _getResponsiveFontSize(context, 14),
                  ),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: _getResponsiveSpacing(context) * 1.5),
        Row(
          children: [
            Expanded(
              child: _buildSummaryItem(
                'Toplam Tutar',
                '₺${totalAmount.toStringAsFixed(2)}',
                Icons.attach_money,
                colors,
              ),
            ),
            SizedBox(width: _getResponsiveSpacing(context)),
            Expanded(
              child: _buildSummaryItem(
                'Fatura Sayısı',
                invoices.length.toString(),
                Icons.receipt_long,
                colors,
              ),
            ),
          ],
        ),
        SizedBox(height: _getResponsiveSpacing(context)),
        Row(
          children: [
            Expanded(
              child: _buildSummaryItem(
                'Toplam Ürün Kalemi',
                totalItems.toString(),
                Icons.list_alt,
                colors,
              ),
            ),
            SizedBox(width: _getResponsiveSpacing(context)),
            Expanded(
              child: _buildSummaryItem(
                'Toplam KDV',
                '₺${totalVat.toStringAsFixed(2)}',
                Icons.request_quote_outlined,
                colors,
              ),
            ),
          ],
        ),
        SizedBox(height: _getResponsiveSpacing(context) * 1.5),

        // Fatura Durum Dağılımı
        if (statusCounts.isNotEmpty) ...[
          const Divider(),
          SizedBox(height: _getResponsiveSpacing(context) * 1.5),
          Text(
            "Fatura Durum Dağılımı",
            style: TextStyle(
              fontSize: _getResponsiveFontSize(context, 16),
              fontWeight: FontWeight.w600,
              color: colors['text'],
            ),
          ),
          SizedBox(height: _getResponsiveSpacing(context)),
          ...statusCounts.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _humanizeStatus(entry.key),
                    style: TextStyle(color: colors['textSecondary']),
                  ),
                  Text(
                    entry.value.toString(),
                    style: TextStyle(
                        color: colors['text'], fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );
          }),
          SizedBox(height: _getResponsiveSpacing(context) * 1.5),
        ],

        ElevatedButton.icon(
          onPressed: _showExportOptions,
          icon: const Icon(Icons.download, size: 18),
          label: const Text('Raporu Dışa Aktar'),
          style: ElevatedButton.styleFrom(
            backgroundColor: colors['primaryBlue'],
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryItem(
      String label, String value, IconData icon, Map<String, dynamic> colors) {
    return Container(
      padding: EdgeInsets.all(_getResponsivePadding(context)),
      decoration: BoxDecoration(
        color: colors['background'],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: (colors['textSecondary'] as Color)
                .withAlpha(26)), // withOpacity yerine withAlpha
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: colors['textSecondary'], size: 18),
              SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: colors['textSecondary'],
                  fontSize: _getResponsiveFontSize(context, 14),
                ),
              ),
            ],
          ),
          SizedBox(height: _getResponsiveSpacing(context) * 0.5),
          Text(
            value,
            style: TextStyle(
              color: colors['text'],
              fontSize: _getResponsiveFontSize(context, 18),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoicesSection(Map<String, dynamic> colors, bool isDarkMode) {
    if (_packageData == null) return const SliverToBoxAdapter();

    final invoices = _packageData!['invoices'] as List<dynamic>? ?? [];

    if (invoices.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          margin: EdgeInsets.all(_getResponsivePadding(context)),
          padding: EdgeInsets.all(_getResponsivePadding(context) * 2),
          decoration: BoxDecoration(
            color: colors['surface'],
            borderRadius: BorderRadius.circular(DashboardConstants.cardRadius),
            boxShadow: DashboardConstants.getCardShadow(isDarkMode),
          ),
          child: Column(
            children: [
              Icon(
                Icons.inbox,
                size: _getResponsiveContainerSize(context, 48),
                color: colors['textSecondary'],
              ),
              SizedBox(height: _getResponsiveSpacing(context)),
              Text(
                'Bu pakette henüz fatura yok',
                style: TextStyle(
                  color: colors['textSecondary'],
                  fontSize: _getResponsiveFontSize(context, 16),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final invoice = invoices[index];
          return _buildInvoiceCard(invoice, colors, isDarkMode);
        },
        childCount: invoices.length,
      ),
    );
  }

  // Yeni Fatura Kartı Tasarımı
  Widget _buildInvoiceCard(Map<String, dynamic> invoice,
      Map<String, dynamic> colors, bool isDarkMode) {
    final invoiceId = invoice['id']?.toString() ?? UniqueKey().toString();
    final isExpanded = _expandedCards.contains(invoiceId);
    final invoiceModel = Invoice.fromJson(invoice);

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: _getResponsivePadding(context),
        vertical: _getResponsiveSpacing(context) * 0.5,
      ),
      decoration: BoxDecoration(
        color: colors['surface'],
        borderRadius: BorderRadius.circular(DashboardConstants.cardRadius),
        boxShadow: DashboardConstants.getCardShadow(isDarkMode),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedCards.remove(invoiceId);
                } else {
                  _expandedCards.add(invoiceId);
                }
              });
            },
            borderRadius: BorderRadius.circular(DashboardConstants.cardRadius),
            child: Padding(
              padding: EdgeInsets.all(_getResponsivePadding(context)),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: (colors['primaryBlue'] as Color)
                          .withAlpha(25), // withOpacity yerine withAlpha
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        invoiceModel.sellerName.isNotEmpty
                            ? invoiceModel.sellerName[0].toUpperCase()
                            : 'B',
                        style: TextStyle(
                          color: colors['primaryBlue'],
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: _getResponsiveSpacing(context)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invoiceModel.sellerName,
                          style: TextStyle(
                            color: colors['text'],
                            fontSize: _getResponsiveFontSize(context, 16),
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          _formatDate(invoiceModel.date),
                          style: TextStyle(
                            color: colors['textSecondary'],
                            fontSize: _getResponsiveFontSize(context, 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: _getResponsiveSpacing(context)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₺${invoiceModel.totalAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: colors['text'],
                          fontSize: _getResponsiveFontSize(context, 16),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: colors['textSecondary'],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: EdgeInsets.fromLTRB(
                  _getResponsivePadding(context),
                  0,
                  _getResponsivePadding(context),
                  _getResponsivePadding(context)),
              child: Column(
                children: [
                  const Divider(height: 1),
                  SizedBox(height: _getResponsiveSpacing(context)),
                  // Fatura resmi
                  if (invoiceModel.thumbnailUrl != null &&
                      invoiceModel.thumbnailUrl!.isNotEmpty)
                    Center(
                      child: GestureDetector(
                        onTap: () => _showFullScreenImage(
                            invoiceModel.thumbnailUrl!, isDarkMode, colors),
                        child: Container(
                          width: double.infinity,
                          height: 150,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: (colors['textSecondary'] as Color)
                                    .withAlpha(
                                        51)), // withOpacity yerine withAlpha
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              invoiceModel.thumbnailUrl!,
                              fit: BoxFit.contain,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const Center(
                                    child: CircularProgressIndicator());
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.image_not_supported_outlined,
                                      color: (colors['textSecondary'] as Color)
                                          .withAlpha(
                                              128), // withOpacity yerine withAlpha
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Resim Yüklenemedi',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: (colors['textSecondary']
                                                as Color)
                                            .withAlpha(
                                                128), // withOpacity yerine withAlpha
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  SizedBox(height: _getResponsiveSpacing(context)),
                  _buildInvoiceDetailRow(
                      'Fatura No', invoiceModel.fileName ?? 'N/A', colors),
                  _buildInvoiceDetailRow(
                      'KDV Tutarı', '₺0.00', colors), // Placeholder
                  _buildInvoiceDetailRow(
                      'Dosya Adı', invoiceModel.fileName ?? 'N/A', colors),
                  if (invoice['processingMs'] != null)
                    _buildInvoiceDetailRow(
                        'İşlem Süresi', '${invoice['processingMs']}ms', colors),
                  SizedBox(height: _getResponsiveSpacing(context) * 1.5),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _copyInvoiceData(invoice),
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Veriyi Kopyala'),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: colors['textSecondary'],
                              side: BorderSide(
                                  color: (colors['textSecondary'] as Color)
                                      .withAlpha(
                                          77))), // withOpacity yerine withAlpha
                        ),
                      ),
                      SizedBox(width: _getResponsiveSpacing(context) * 0.5),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _navigateToInvoiceDetail(invoice),
                          icon: const Icon(Icons.visibility, size: 16),
                          label: const Text('Faturayı Görüntüle'),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: colors['primaryBlue'],
                              side: BorderSide(
                                  color: (colors['primaryBlue'] as Color)
                                      .withAlpha(
                                          77))), // withOpacity yerine withAlpha
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: _getResponsiveSpacing(context) * 0.5),
                  ElevatedButton.icon(
                    onPressed: () => _showInvoiceReportOptions(invoice),
                    icon: const Icon(Icons.assessment, size: 18),
                    label: const Text('Fatura Raporu Al'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors['primaryBlue'],
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInvoiceDetailRow(
      String label, String value, Map<String, dynamic> colors) {
    return Padding(
      padding:
          EdgeInsets.symmetric(vertical: _getResponsiveSpacing(context) * 0.25),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: colors['textSecondary'],
              fontSize: _getResponsiveFontSize(context, 14),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: colors['text'],
              fontSize: _getResponsiveFontSize(context, 14),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  double _calculateTotalAmount(List<dynamic> invoices) {
    return invoices.fold<double>(0.0, (sum, invoice) {
      try {
        final invoiceModel = Invoice.fromJson(invoice);
        return sum + invoiceModel.totalAmount;
      } catch (e) {
        return sum;
      }
    });
  }

  int _calculateTotalItems(List<dynamic> invoices) {
    int totalItems = 0;
    for (var invoiceData in invoices) {
      try {
        final structured = invoiceData['structured'];
        if (structured != null && structured['urun_kalemleri'] is List) {
          totalItems += (structured['urun_kalemleri'] as List).length;
        }
      } catch (e) {
        // Ignore if parsing fails for one invoice
      }
    }
    return totalItems;
  }

  double _calculateTotalVat(List<dynamic> invoices) {
    double totalVat = 0.0;
    for (var invoiceData in invoices) {
      try {
        final structured = invoiceData['structured'];
        if (structured != null && structured['kdv_tutari'] != null) {
          final vatValue =
              structured['kdv_tutari'].toString().replaceAll(',', '.');
          totalVat += double.tryParse(vatValue) ?? 0.0;
        }
      } catch (e) {
        // Ignore
      }
    }
    return totalVat;
  }

  void _showExportOptions() {
    final isDarkMode =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    final colors = DashboardConstants.getColors(isDarkMode);

    showModalBottomSheet(
      context: context,
      backgroundColor: colors['surface'],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(_getResponsiveContainerSize(context, 20))),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(_getResponsivePadding(context) * 1.25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: _getResponsiveContainerSize(context, 40),
              height: _getResponsiveContainerSize(context, 4),
              decoration: BoxDecoration(
                color: (colors['textSecondary'] as Color)
                    .withAlpha(77), // withOpacity yerine withAlpha
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: _getResponsiveSpacing(context) * 1.25),
            Text(
              'Rapor Seçenekleri',
              style: TextStyle(
                color: colors['text'],
                fontSize: _getResponsiveFontSize(context, 18),
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: _getResponsiveSpacing(context) * 1.25),
            ListTile(
              leading: Icon(Icons.copy, color: colors['primaryBlue']),
              title: const Text('JSON Raporu'),
              subtitle: const Text('Verileri JSON formatında indir'),
              onTap: () {
                Navigator.of(context).pop();
                _exportPackageJSON();
              },
            ),
            ListTile(
              leading: Icon(Icons.table_chart, color: colors['primaryBlue']),
              title: const Text('CSV Raporu'),
              subtitle: const Text('Verileri CSV formatında indir'),
              onTap: () {
                Navigator.of(context).pop();
                _exportPackageCSV();
              },
            ),
            ListTile(
              leading: Icon(Icons.assessment, color: colors['primaryBlue']),
              title: const Text('Excel Raporu'),
              subtitle: const Text('Verileri Excel formatında indir'),
              onTap: () {
                Navigator.of(context).pop();
                _exportPackageExcel();
              },
            ),
            SizedBox(height: _getResponsiveSpacing(context)),
          ],
        ),
      ),
    );
  }

  void _showInvoiceReportOptions(Map<String, dynamic> invoice) {
    final isDarkMode =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    final colors = DashboardConstants.getColors(isDarkMode);

    showModalBottomSheet(
      context: context,
      backgroundColor: colors['surface'],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(_getResponsiveContainerSize(context, 20))),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(_getResponsivePadding(context) * 1.25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: _getResponsiveContainerSize(context, 40),
              height: _getResponsiveContainerSize(context, 4),
              decoration: BoxDecoration(
                color: (colors['textSecondary'] as Color)
                    .withAlpha(77), // withOpacity yerine withAlpha
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: _getResponsiveSpacing(context) * 1.25),
            Text(
              'Fatura Raporu',
              style: TextStyle(
                color: colors['text'],
                fontSize: _getResponsiveFontSize(context, 18),
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: _getResponsiveSpacing(context) * 1.25),
            ListTile(
              leading: Icon(Icons.copy, color: colors['primaryBlue']),
              title: const Text('JSON Raporu'),
              subtitle: const Text('Fatura verisini JSON formatında indir'),
              onTap: () {
                Navigator.of(context).pop();
                _exportInvoice(invoice, 'json');
              },
            ),
            ListTile(
              leading: Icon(Icons.table_chart, color: colors['primaryBlue']),
              title: const Text('CSV Raporu'),
              subtitle: const Text('Fatura verisini CSV formatında indir'),
              onTap: () {
                Navigator.of(context).pop();
                _exportInvoice(invoice, 'csv');
              },
            ),
            ListTile(
              leading: Icon(Icons.assessment, color: colors['primaryBlue']),
              title: const Text('Excel Raporu'),
              subtitle: const Text('Fatura verisini Excel formatında indir'),
              onTap: () {
                Navigator.of(context).pop();
                _exportInvoice(invoice, 'excel');
              },
            ),
            SizedBox(height: _getResponsiveSpacing(context)),
          ],
        ),
      ),
    );
  }

  Future<void> _exportInvoice(
      Map<String, dynamic> invoice, String format) async {
    final isDarkMode =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    final colors = DashboardConstants.getColors(isDarkMode);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${format.toUpperCase()} raporu oluşturuluyor...'),
      backgroundColor: colors['accentAmber'],
      duration: const Duration(seconds: 2),
    ));

    try {
      final token = await _storageService.getToken();
      if (token == null) throw Exception('Token bulunamadı');

      final invoiceId = invoice['id'] ?? 'unknown_invoice';

      switch (format) {
        case 'json':
          final jsonContent =
              await ReportService.generateInvoiceJsonReport(token, invoice);
          if (jsonContent != null && jsonContent.isNotEmpty) {
            final fileName = 'fatura_raporu_$invoiceId.json';
            if (!mounted) return;
            await ReportService.saveAndShareReport(
                jsonContent, fileName, context,
                mimeType: 'application/json');
          }
          break;
        case 'csv':
          final csvContent =
              await ReportService.generateInvoiceCSVReport(token, invoice);
          if (csvContent != null && csvContent.isNotEmpty) {
            final fileName = 'fatura_raporu_$invoiceId.csv';
            if (!mounted) return;
            await ReportService.saveAndShareReport(
                csvContent, fileName, context,
                mimeType: 'text/csv');
          }
          break;
        case 'excel':
          final excelData =
              await ReportService.generateInvoiceExcelReport(token, invoice);
          final fileName = 'fatura_raporu_$invoiceId.xlsx';
          if (!mounted) return;
          await ReportService.saveExcelReport(excelData, fileName, context);
          break;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Hata: Rapor oluşturulamadı - ${e.toString()}'),
        backgroundColor: colors['errorRed'],
      ));
    }
  }

  void _copyInvoiceData(Map<String, dynamic> invoice) {
    try {
      final invoiceModel = Invoice.fromJson(invoice);
      final data = {
        'Fatura No': invoiceModel.fileName ?? 'N/A',
        'Satıcı': invoiceModel.sellerName,
        'Tutar': '₺${invoiceModel.totalAmount.toStringAsFixed(2)}',
        'Tarih': _formatDate(invoiceModel.date),
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(data);
      Clipboard.setData(ClipboardData(text: jsonString));

      if (!mounted) return;
      final isDarkMode =
          Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
      final colors = DashboardConstants.getColors(isDarkMode);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Fatura verisi panoya kopyalandı!'),
          backgroundColor: colors['successGreen'],
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final isDarkMode =
          Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
      final colors = DashboardConstants.getColors(isDarkMode);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fatura verisi kopyalanamadı: $e'),
          backgroundColor: colors['errorRed'],
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showFullScreenImage(
      String imageUrl, bool isDarkMode, Map<String, dynamic> colors) {
    showDialog(
      context: context,
      barrierColor:
          (Colors.black).withAlpha(204), // withOpacity yerine withAlpha
      builder: (context) {
        return Dialog(
          backgroundColor: isDarkMode ? Colors.black : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InteractiveViewer(
            panEnabled: true,
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Icon(
                    Icons.broken_image,
                    color: Colors.white54,
                    size: 64,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _navigateToInvoiceDetail(Map<String, dynamic> invoice) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => InvoiceDetailScreen(
          packageId: widget.packageId,
          invoiceId: invoice['id'],
        ),
      ),
    );
  }

  void _showReevaluateConfirmation() {
    final isDarkMode =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    final colors = DashboardConstants.getColors(isDarkMode);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: colors['surface'],
          title: Text(
            'Paketi Tekrar Değerlendir',
            style: TextStyle(
              color: colors['text'],
              fontSize: _getResponsiveFontSize(context, 18),
            ),
          ),
          content: Text(
            'Bu işlem, paketteki tüm faturaları yeniden işleyecek ve mevcut verileri güncelleyecektir. Emin misiniz?',
            style: TextStyle(
              color: colors['textSecondary'],
              fontSize: _getResponsiveFontSize(context, 14),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'İptal',
                style: TextStyle(color: colors['textSecondary']),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors['accentAmber'],
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _reevaluatePackage();
              },
              child: const Text('Onayla ve Değerlendir'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _reevaluatePackage() async {
    try {
      final token = await _storageService.getToken();
      if (token == null) {
        throw Exception('Token bulunamadı');
      }

      await _apiService.reevaluatePackage(token, widget.packageId);

      if (!mounted) return;
      final isDarkMode =
          Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
      final colors = DashboardConstants.getColors(isDarkMode);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Paket başarıyla yeniden değerlendirildi!'),
          backgroundColor: colors['successGreen'],
          duration: const Duration(seconds: 3),
        ),
      );
      _loadAll();
    } catch (e) {
      if (!mounted) return;
      final isDarkMode =
          Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
      final colors = DashboardConstants.getColors(isDarkMode);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Paket yeniden değerlendirilemedi: $e'),
          backgroundColor: colors['errorRed'],
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _exportPackageJSON() async {
    final isDarkMode =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    final colors = DashboardConstants.getColors(isDarkMode);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('JSON raporu oluşturuluyor...'),
      backgroundColor: colors['accentAmber'],
      duration: const Duration(seconds: 2),
    ));

    try {
      final token = await _storageService.getToken();
      if (token == null) throw Exception('Token bulunamadı');

      final jsonContent =
          await ReportService.generatePackageJsonReport(token, _packageData!);
      if (jsonContent != null && jsonContent.isNotEmpty) {
        final fileName = 'paket_raporu_${widget.packageId}.json';
        if (!mounted) return;
        await ReportService.saveAndShareReport(jsonContent, fileName, context,
            mimeType: 'application/json');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Hata: JSON raporu oluşturulamadı - ${e.toString()}'),
        backgroundColor: colors['errorRed'],
      ));
    }
  }

  void _exportPackageCSV() async {
    final isDarkMode =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    final colors = DashboardConstants.getColors(isDarkMode);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('CSV raporu oluşturuluyor...'),
      backgroundColor: colors['accentAmber'],
      duration: const Duration(seconds: 2),
    ));

    try {
      final token = await _storageService.getToken();
      if (token == null) throw Exception('Token bulunamadı');

      final csvContent =
          await ReportService.generatePackageCSVReport(token, _packageData!);
      if (csvContent != null && csvContent.isNotEmpty) {
        final fileName = 'paket_raporu_${widget.packageId}.csv';
        if (!mounted) return;
        await ReportService.saveAndShareReport(csvContent, fileName, context,
            mimeType: 'text/csv');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Hata: CSV raporu oluşturulamadı - ${e.toString()}'),
        backgroundColor: colors['errorRed'],
      ));
    }
  }

  void _exportPackageExcel() async {
    final isDarkMode =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    final colors = DashboardConstants.getColors(isDarkMode);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Excel raporu oluşturuluyor...'),
      backgroundColor: colors['accentAmber'],
      duration: const Duration(seconds: 2),
    ));

    try {
      final token = await _storageService.getToken();
      if (token == null) throw Exception('Token bulunamadı');

      final excelData =
          await ReportService.generatePackageExcelReport(token, _packageData!);
      final fileName = 'paket_raporu_${widget.packageId}.xlsx';
      if (!mounted) return;
      await ReportService.saveExcelReport(excelData, fileName, context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Hata: Excel raporu oluşturulamadı - ${e.toString()}'),
        backgroundColor: colors['errorRed'],
      ));
    }
  }

  void _logout() async {
    try {
      // Token'ı, WebSocket bağlantısını ve dashboard verilerini temizle
      await _storageService.deleteToken();
      WebSocketService().disconnect();

      // Dashboard verilerini temizle
      if (mounted) {
        final dashboardProvider =
            Provider.of<DashboardProvider>(context, listen: false);
        dashboardProvider.clearData();
      }

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginRegisterScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      final isDarkMode =
          Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
      final colors = DashboardConstants.getColors(isDarkMode);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Çıkış yapılamadı: $e'),
          backgroundColor: colors['errorRed'],
        ),
      );
    }
  }

  String _humanizeError(String error) {
    if (error.contains('Token')) {
      return 'Oturum süreniz dolmuş. Lütfen tekrar giriş yapın.';
    } else if (error.contains('Network')) {
      return 'İnternet bağlantınızı kontrol edin.';
    } else if (error.contains('Server')) {
      return 'Sunucu ile bağlantı kurulamadı.';
    } else {
      return 'Beklenmeyen bir hata oluştu.';
    }
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) {
      return 'Bilinmiyor';
    }
    try {
      DateTime date = _parseDate(dateValue);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return 'Geçersiz Tarih';
    }
  }

  DateTime _parseDate(dynamic dateValue) {
    if (dateValue is DateTime) {
      return dateValue;
    }
    if (dateValue is String) {
      return DateTime.parse(dateValue);
    }
    if (dateValue is Map &&
        dateValue.containsKey('_seconds') &&
        dateValue.containsKey('_nanoseconds')) {
      return DateTime.fromMillisecondsSinceEpoch(dateValue['_seconds'] * 1000);
    }
    throw const FormatException('Unsupported date format');
  }

  String _humanizeStatus(String status) {
    switch (status) {
      case 'processed':
        return 'İşlendi';
      case 'approved':
        return 'Onaylandı';
      case 'failed':
        return 'Hatalı';
      case 'pending':
        return 'Beklemede';
      default:
        return 'Diğer';
    }
  }

  // Responsive helper methods
  double _getResponsivePadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) return 16.0;
    if (screenWidth < 1200) return 24.0;
    return 32.0;
  }

  double _getResponsiveSpacing(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) return 12.0;
    if (screenWidth < 1200) return 16.0;
    return 20.0;
  }

  double _getResponsiveFontSize(BuildContext context, double baseSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) return baseSize * 0.9;
    if (screenWidth < 1200) return baseSize;
    return baseSize * 1.1;
  }

  double _getResponsiveContainerSize(BuildContext context, double baseSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 600) return baseSize * 0.8;
    if (screenWidth < 1200) return baseSize;
    return baseSize * 1.2;
  }
}

class _NetworkImageLoader extends StatefulWidget {
  final String url;
  final String sellerName;

  const _NetworkImageLoader({required this.url, required this.sellerName});

  @override
  __NetworkImageLoaderState createState() => __NetworkImageLoaderState();
}

class __NetworkImageLoaderState extends State<_NetworkImageLoader> {
  Future<Uint8List>? _imageFuture;

  @override
  void initState() {
    super.initState();
    _imageFuture = _fetchImage();
  }

  Future<Uint8List> _fetchImage() async {
    try {
      final response = await http.get(Uri.parse(widget.url));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw Exception('Failed to load image: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _imageFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return const Icon(Icons.image_not_supported, color: Colors.grey);
        } else if (snapshot.hasData) {
          return Image.memory(
            snapshot.data!,
            fit: BoxFit.cover,
          );
        } else {
          return Center(
            child: Text(
              widget.sellerName.isNotEmpty
                  ? widget.sellerName.substring(0, 1)
                  : '?',
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          );
        }
      },
    );
  }
}
