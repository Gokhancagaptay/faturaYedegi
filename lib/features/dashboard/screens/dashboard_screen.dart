// lib/features/dashboard/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert'; // utf8.decode için gerekli
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:fatura_yeni/features/dashboard/models/invoice_model.dart';
import 'package:fatura_yeni/core/services/api_service.dart';
import 'package:fatura_yeni/core/services/storage_service.dart';
import 'package:fatura_yeni/features/scan/screens/scan_screen.dart';
import 'package:fatura_yeni/features/invoices/screens/invoice_detail_screen.dart';
import 'package:file_picker/file_picker.dart';

import 'package:fatura_yeni/core/services/websocket_service.dart';
import 'package:fatura_yeni/core/providers/theme_provider.dart';
import 'package:fatura_yeni/core/constants/dashboard_constants.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<Invoice>> _invoicesFuture;
  Future<List<Invoice>> _allInvoicesFuture = Future.value(const []);
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  final WebSocketService _webSocketService = WebSocketService();
  Future<List<Map<String, dynamic>>> _packagesFuture = Future.value(const []);
  List<Map<String, dynamic>> _packages = const [];
  String? _selectedPackageId;

  // Filtre durumu
  String?
      _statusFilter; // 'approved', 'processed', 'pending', 'failed', null (tümü)
  String? _packageFilter; // Paket ID'si veya null (tümü)

  // Loading durumu
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _packagesFuture = _loadPackages();
    _invoicesFuture = _loadInvoices();
    _allInvoicesFuture = _loadAllInvoices();
    _initializeWebSocket();
  }

  @override
  void dispose() {
    _webSocketService.disconnect();
    super.dispose();
  }

  // Tema renklerini al (dynamic theme)
  Color get _primaryBlue => context.watch<ThemeProvider>().isDarkMode
      ? DashboardConstants.darkPrimaryBlue
      : DashboardConstants.lightPrimaryBlue;

  Color get _backgroundColor => context.watch<ThemeProvider>().isDarkMode
      ? DashboardConstants.darkBackground
      : DashboardConstants.lightBackground;

  Color get _surfaceColor => context.watch<ThemeProvider>().isDarkMode
      ? DashboardConstants.darkSurface
      : DashboardConstants.lightSurface;

  Color get _textColor => context.watch<ThemeProvider>().isDarkMode
      ? DashboardConstants.darkText
      : DashboardConstants.lightText;

  Color get _textColorSecondary => context.watch<ThemeProvider>().isDarkMode
      ? DashboardConstants.darkTextSecondary
      : DashboardConstants.lightTextSecondary;

  Color get _cardBackground => context.watch<ThemeProvider>().isDarkMode
      ? DashboardConstants.darkSurface
      : DashboardConstants.lightSurface;

  Color get _accentAmber => context.watch<ThemeProvider>().isDarkMode
      ? DashboardConstants.darkAccentAmber
      : DashboardConstants.lightAccentAmber;

  Color get _successGreen => context.watch<ThemeProvider>().isDarkMode
      ? DashboardConstants.darkSuccessGreen
      : DashboardConstants.lightSuccessGreen;

  Color get _errorRed => context.watch<ThemeProvider>().isDarkMode
      ? DashboardConstants.darkErrorRed
      : DashboardConstants.lightErrorRed;

  Color get _white => context.watch<ThemeProvider>().isDarkMode
      ? DashboardConstants.darkWhite
      : DashboardConstants.lightWhite;

  // WebSocket bağlantısını başlat
  Future<void> _initializeWebSocket() async {
    try {
      final token = await _storageService.getToken();
      if (token == null) return;

      // Backend'den kullanıcı ID'sini al
      try {
        final response = await _apiService.getUserProfile(token);
        if (response['success'] == true) {
          final user = response['user'];
          final userId = user['uid'];

          // WebSocket bağlantısını kur
          await _webSocketService.connect(token, userId);

          // WebSocket mesajlarını dinle - sadece bir kez
          _webSocketService.messageStream.listen(
            (message) {
              if (mounted) {
                _handleWebSocketMessage(message);
              }
            },
            onError: (error) {
              // WebSocket dinleme hatası
            },
          );

          // Tüm faturaları dinle - sadece bir kez
          _webSocketService.listenToAllInvoices();
        }
      } catch (profileError) {
        // Kullanıcı profili alınamadı
      }
    } catch (e) {
      // WebSocket başlatma hatası
    }
  }

  // WebSocket mesajlarını işle
  void _handleWebSocketMessage(Map<String, dynamic> message) {
    if (!mounted) return; // Widget dispose edilmişse işleme

    switch (message['type']) {
      case 'invoice_status_update':
        // Fatura durumu güncellendi, sadece bildirim göster
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fatura durumu güncellendi'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        break;
      case 'package_status_update':
        // Paket durumu güncellendi, sadece bildirim göster
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Paket durumu güncellendi'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        break;
      case 'processing_progress':
        // İşlem ilerlemesi göster
        _showProcessingProgress(message['progress'] as int);
        break;
    }
  }

  // İşlem ilerlemesi göster
  void _showProcessingProgress(int progress) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const CircularProgressIndicator(strokeWidth: 2),
              const SizedBox(width: 16),
              Text('İşleniyor: %$progress'),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String _decodeFileName(String? fileName) {
    if (fileName == null) return 'Fatura';
    try {
      // UTF-8 decode for Turkish characters
      return utf8.decode(fileName.codeUnits);
    } catch (e) {
      return fileName;
    }
  }

  // Kullanıcı adını backend'den al
  Future<String> _getUserNameAsync() async {
    try {
      final token = await _storageService.getToken();
      if (token == null) {
        return 'Kullanıcı';
      }

      // Backend'den kullanıcı profilini al
      final response = await _apiService.getUserProfile(token);

      if (response['success'] == true) {
        final user = response['user'];

        // Öncelik sırası: Firestore name > displayName > email
        final name = user['name'] ?? user['displayName'];

        if (name != null && name.isNotEmpty) {
          return name;
        }

        // Email'den kullanıcı adını çıkar
        final email = user['email'];
        if (email != null && email.isNotEmpty) {
          final username = email.split('@')[0];
          final formattedName =
              username[0].toUpperCase() + username.substring(1).toLowerCase();
          return formattedName;
        }
      }
    } catch (e) {
      // Kullanıcı adı alınamadı
    }

    return 'Kullanıcı';
  }

  // İşlenen fatura sayısını hesapla - API üzerinden
  Future<int> _getProcessedInvoiceCount() async {
    try {
      final token = await _storageService.getToken();
      if (token == null) {
        return 0;
      }

      // API'den işlenen fatura sayısını al
      final response = await _apiService.getInvoiceStats(token);

      if (response['success'] == true) {
        final stats = response['stats'] ?? {};
        final processedCount = stats['processed'] ?? 0;
        final approvedCount = stats['approved'] ?? 0;
        final total = processedCount + approvedCount;
        return total;
      }
    } catch (e) {
      // İşlenen fatura sayısı alınamadı
    }

    // API hatası durumunda fallback olarak 0 döndür
    return 0;
  }

  // kaldırıldı: kullanılmayan export dialog metodu

  Future<void> _refreshInvoices() async {
    if (_isLoading) return; // Zaten yükleniyorsa bekle

    setState(() {
      _isLoading = true;
    });

    try {
      // Sadece gerekli verileri yenile
      final newInvoices = await _loadInvoices();
      final newAllInvoices = await _loadAllInvoices();

      if (mounted) {
        setState(() {
          _invoicesFuture = Future.value(newInvoices);
          _allInvoicesFuture = Future.value(newAllInvoices);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      // Fatura yenileme hatası
    }
  }

  Future<List<Invoice>> _loadInvoices() async {
    try {
      final token = await _storageService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found.');
      }

      if (_selectedPackageId != null && _selectedPackageId!.isNotEmpty) {
        // Seçili paket için faturaları çek
        final response = await _apiService.getPackageInvoices(
          token,
          _selectedPackageId!,
        );
        final List<dynamic> data = response['invoices'] ?? [];
        return data.map((json) => Invoice.fromJson(json)).toList();
      } else {
        // Seçili paket yoksa tüm paketlerdeki faturaları çek
        return await _loadAllInvoices();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Faturalar yüklenemedi: $e')));
      }
      return [];
    }
  }

  Future<List<Invoice>> _loadAllInvoices() async {
    try {
      final token = await _storageService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found.');
      }

      // Önce tüm paketleri al
      final packagesResponse = await _apiService.getPackages(token);
      final List<dynamic> packagesList = packagesResponse['packages'] ?? [];

      // Her paket için faturaları çek ve birleştir
      List<Invoice> allInvoices = [];

      for (final package in packagesList) {
        try {
          final packageId = package['id'].toString();
          final packageInvoicesResponse = await _apiService.getPackageInvoices(
            token,
            packageId,
          );
          final List<dynamic> packageInvoices =
              packageInvoicesResponse['invoices'] ?? [];

          // Her faturaya packageId ekle
          final packageInvoicesList = packageInvoices.map((json) {
            final invoiceData = Map<String, dynamic>.from(json);
            invoiceData['packageId'] = packageId; // Package ID'yi ekle
            final invoice = Invoice.fromJson(invoiceData);
            return invoice;
          }).toList();

          allInvoices.addAll(packageInvoicesList);
        } catch (packageError) {
          continue; // Bir paket hata verirse diğerlerine devam et
        }
      }

      return allInvoices;
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _loadPackages() async {
    try {
      final token = await _storageService.getToken();
      if (token == null) throw Exception('Authentication token not found.');
      final res = await _apiService.getPackages(token);
      final List<dynamic> list = res['packages'] ?? [];
      final items = list.cast<Map<String, dynamic>>();

      // Varsayılan paket seçimi kaldırıldı - tüm paketlerdeki faturalar gösterilecek
      _packages = items;
      return items;
    } catch (e) {
      _packages = const [];
      return [];
    }
  }

  void _showUploadOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'Dosya Yükleme Seçenekleri',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _textColor,
                  ),
                ),
                const SizedBox(height: 20),
                _buildUploadOption(
                  icon: Icons.photo_library,
                  title: 'Galeriden Fotoğraf Seç (Paket)',
                  subtitle: 'Tek veya çoklu seçim paket olur',
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _pickMultipleFiles();
                  },
                ),
                _buildUploadOption(
                  icon: Icons.attach_file,
                  title: 'Belge Seç (Paket)',
                  subtitle: 'PDF, JPG, PNG — tek/çoklu',
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _pickMultipleFiles();
                  },
                ),
                _buildUploadOption(
                  icon: Icons.camera_alt,
                  title: 'Kamera ile Çek (Paket)',
                  subtitle: 'Tek fotoğraf paket olur',
                  onTap: () async {
                    Navigator.of(context).pop();
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const ScanScreen(),
                      ),
                    );
                    _refreshInvoices();
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickMultipleFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        allowMultiple: true,
      );
      final List<PlatformFile>? files = result?.files;

      if (files != null && files.isNotEmpty) {
        // Yükleme işlemini başlat ve kullanıcıyı bilgilendir
        _showUploadSnackbar('Fatura paketi oluşturuluyor...', false);

        try {
          final token = await _storageService.getToken();
          if (token == null) {
            _showUploadSnackbar(
                'Oturum hatası. Lütfen tekrar giriş yapın.', true);
            return;
          }

          final response = await _apiService.createPackage(files, token);

          if (response['success'] == true) {
            // WebSocket'ten gelecek durumu bekleyerek anlık güncelleme sağla
            _showUploadSnackbar(
                'Paket başarıyla oluşturuldu ve işleniyor.', false,
                isSuccess: true);
            await _loadAllInvoices(); // Listeyi yenile
          } else {
            final errorMessage =
                response['message'] as String? ?? 'Bilinmeyen bir hata oluştu.';
            _showUploadSnackbar(errorMessage, true);
          }
        } catch (e) {
          _showUploadSnackbar('Dosya yükleme hatası: $e', true);
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Yükleme başarısız: $e')));
    }
  }

  // Yükleme durumunu göstermek için Snackbar
  void _showUploadSnackbar(String message, bool isError,
      {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Colors.redAccent
            : isSuccess
                ? Colors.green
                : Theme.of(context).primaryColor,
        duration: Duration(seconds: isError ? 5 : 3),
      ),
    );
  }

  Widget _buildUploadOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _primaryBlue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: _primaryBlue),
      ),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w600, color: _textColor),
      ),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[600])),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1200;
    final isTablet = screenWidth > 768 && screenWidth <= 1200;

    return Scaffold(
      backgroundColor: _backgroundColor,
      // AppBar ve üst bilgi barı kaldırıldı - maksimum ekran alanı
      body: SafeArea(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _packagesFuture,
          builder: (context, pkgSnapshot) {
            final packages = pkgSnapshot.data ?? _packages;
            return FutureBuilder<List<Invoice>>(
              future: _invoicesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    pkgSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _buildErrorState();
                }

                final invoices = snapshot.data ?? [];

                // Eğer faturalar henüz yüklenmemişse loading göster
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Eğer hiç fatura yoksa boş durum göster
                if (invoices.isEmpty) {
                  return _buildEmptyState();
                }

                final now = DateTime.now();
                final monthlyTotal = invoices
                    .where(
                      (i) =>
                          i.date.year == now.year &&
                          i.date.month == now.month &&
                          (i.status == 'approved' ||
                              (i.status == 'processed' &&
                                  i.isApproved == true)),
                    ) // Sadece onaylanmış faturalar
                    .fold<double>(0.0, (sum, item) => sum + item.totalAmount);

                return FutureBuilder<List<Invoice>>(
                  future: _allInvoicesFuture,
                  builder: (context, allSnap) {
                    final allInvoices = allSnap.data ?? invoices;

                    // Web için farklı layout
                    if (isWeb && (isDesktop || isTablet)) {
                      return _buildWebDashboardContent(
                        context,
                        monthlyTotal,
                        invoices,
                        packages: packages,
                        allInvoices: allInvoices,
                      );
                    }

                    return _buildDashboardContent(
                      context,
                      monthlyTotal,
                      invoices,
                      packages: packages,
                      allInvoices: allInvoices,
                    );
                  },
                );
              },
            );
          },
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton(
        backgroundColor: _primaryBlue,
        onPressed: _showUploadOptions,
        child: Icon(Icons.add, color: _white),
      ),
      // bottomNavigationBar kaldırıldı: ana seviye navigasyon MainScreen'de yönetiliyor
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Faturalar yüklenirken hata oluştu',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _refreshInvoices,
            child: const Text('Tekrar Dene'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return CustomScrollView(
      slivers: [
        _buildHeader(context, 0.0, []),
        SliverFillRemaining(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: DashboardConstants.getResponsiveContainerSize(
                    context,
                    120,
                  ),
                  height: DashboardConstants.getResponsiveContainerSize(
                    context,
                    120,
                  ),
                  decoration: BoxDecoration(
                    color: _primaryBlue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.receipt_long,
                    size: 60,
                    color: _primaryBlue.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Henüz fatura yok',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _textColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'İlk faturanızı yükleyerek başlayın',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const ScanScreen(),
                        ),
                      );
                      _refreshInvoices();
                    },
                    icon: const Icon(Icons.camera_alt),
                    label: const Text(
                      'İlk Faturanızı Yükleyin',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryBlue,
                      foregroundColor: _white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Web için dashboard layout
  Widget _buildWebDashboardContent(
    BuildContext context,
    double monthlyTotal,
    List<Invoice> invoices, {
    List<Map<String, dynamic>> packages = const [],
    List<Invoice> allInvoices = const [],
  }) {
    // Filtrelenmiş faturaları al
    final filteredInvoices = _getFilteredInvoices(allInvoices);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sol panel - İstatistikler ve paketler
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWebHeader(context, monthlyTotal, invoices),
                const SizedBox(height: 32),
                if (packages.isNotEmpty) ...[
                  _buildWebPackagesSection(packages),
                  const SizedBox(height: 32),
                ],
                _buildWebQuickStats(context, invoices, allInvoices),
              ],
            ),
          ),
        ),
        // Sağ panel - Fatura listesi
        Expanded(
          flex: 3,
          child: Container(
            decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Text(
                        _statusFilter == null && _packageFilter == null
                            ? 'Son Faturalar'
                            : 'Filtrelenmiş Faturalar',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _textColor,
                        ),
                      ),
                      const Spacer(),
                      if (_statusFilter != null || _packageFilter != null)
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _statusFilter = null;
                              _packageFilter = null;
                            });
                          },
                          icon: const Icon(Icons.clear),
                          label: const Text('Filtreyi Temizle'),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: _buildWebRecentReceipts(context, filteredInvoices),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardContent(
    BuildContext context,
    double monthlyTotal,
    List<Invoice> invoices, {
    List<Map<String, dynamic>> packages = const [],
    List<Invoice> allInvoices = const [],
  }) {
    // Filtrelenmiş faturaları al
    final filteredInvoices = _getFilteredInvoices(allInvoices);

    return CustomScrollView(
      slivers: [
        _buildHeader(context, monthlyTotal, invoices),
        if (packages.isNotEmpty)
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Text(
                    'Paketler',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _textColor,
                    ),
                  ),
                ),
                _buildPackagesSwitcher(packages),
              ],
            ),
          ),
        // Filtre başlığını göster
        if (_statusFilter != null)
          SliverToBoxAdapter(child: _buildFilterHeader()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildQuickStats(context, invoices, allInvoices),
                const SizedBox(height: 24),
                _buildSectionTitle(
                  context,
                  _statusFilter == null && _packageFilter == null
                      ? 'Son Faturalar'
                      : 'Filtrelenmiş Faturalar',
                  trailingAction:
                      (_statusFilter != null || _packageFilter != null)
                          ? () {
                              setState(() {
                                _statusFilter = null;
                                _packageFilter = null;
                              });
                            }
                          : null,
                ),
                const SizedBox(height: 10),
                _buildRecentReceipts(context, filteredInvoices),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Web header
  Widget _buildWebHeader(
    BuildContext context,
    double monthlyTotal,
    List<Invoice> invoices,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Logo ve başlık
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _primaryBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.receipt_long, color: _white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fatura Scanner',
                    style: TextStyle(
                      color: _textColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Web Versiyonu',
                    style: TextStyle(
                      color: _textColorSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            // Theme toggle butonu
            IconButton(
              tooltip: 'Tema Değiştir',
              onPressed: () {
                context.read<ThemeProvider>().toggleTheme();
              },
              icon: Icon(
                context.watch<ThemeProvider>().isDarkMode
                    ? Icons.light_mode
                    : Icons.dark_mode,
                color: _primaryBlue,
                size: 24,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Harcama kartı
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _primaryBlue,
                _primaryBlue.withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _primaryBlue.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FutureBuilder<String>(
                          future: _getUserNameAsync(),
                          builder: (context, snapshot) {
                            final userName = snapshot.data ?? 'Kullanıcı';
                            return Text(
                              'Hoş geldiniz, $userName!',
                              style: TextStyle(
                                color: _white.withOpacity(0.9),
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          },
                        ),
                        Text(
                          'Bu ayki harcamalarınızı takip edin',
                          style: TextStyle(
                            color: _white.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Bu Ayki Toplam İşlenen Faturanız',
                style: TextStyle(
                  color: _white.withOpacity(0.8),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              FutureBuilder<int>(
                future: _getMonthlyInvoiceCount(),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  return Row(
                    children: [
                      Text(
                        '₺${monthlyTotal.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: _white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$count Fatura',
                          style: TextStyle(
                            color: _white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context,
    double monthlyTotal,
    List<Invoice> invoices,
  ) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          DashboardConstants.getResponsivePadding(context),
          DashboardConstants.getResponsivePadding(context),
          DashboardConstants.getResponsivePadding(context),
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo ve başlık
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _primaryBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.receipt_long, color: _white, size: 24),
                ),
                const SizedBox(width: 16),
                Text(
                  'Fatura Scanner',
                  style: TextStyle(
                    color: _textColor,
                    fontSize: DashboardConstants.getResponsiveFontSize(
                      context,
                      24,
                    ),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // Theme toggle butonu
                IconButton(
                  tooltip: 'Tema Değiştir',
                  onPressed: () {
                    context.read<ThemeProvider>().toggleTheme();
                  },
                  icon: Icon(
                    context.watch<ThemeProvider>().isDarkMode
                        ? Icons.light_mode
                        : Icons.dark_mode,
                    color: _primaryBlue,
                    size: 24,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Harcama kartı
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [
                    _primaryBlue,
                    context.watch<ThemeProvider>().isDarkMode
                        ? _primaryBlue.withOpacity(
                            0.6,
                          ) // Dark mode'da daha koyu
                        : _primaryBlue.withOpacity(0.8), // Light mode'da normal
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _primaryBlue.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.person_outline,
                          color: _white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FutureBuilder<String>(
                              future: _getUserNameAsync(),
                              builder: (context, snapshot) {
                                final userName = snapshot.data ?? 'Kullanıcı';
                                return Text(
                                  'Hoş geldiniz, $userName!',
                                  style: TextStyle(
                                    color: _white.withOpacity(0.9),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                );
                              },
                            ),
                            Text(
                              'Bu ayki harcamalarınızı takip edin',
                              style: TextStyle(
                                color: _white.withOpacity(0.7),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Bu Ayki Toplam İşlenen Faturanız',
                    style: TextStyle(
                      color: _white.withOpacity(0.8),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<int>(
                    future: _getProcessedInvoiceCount(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Text(
                          '...',
                          style: TextStyle(
                            color: _white,
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.5,
                          ),
                        );
                      }
                      return Text(
                        '${snapshot.data ?? 0} Fatura',
                        style: TextStyle(
                          color: _white,
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.5,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(
    BuildContext context,
    String title, {
    VoidCallback? trailingAction,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: _textColor,
          ),
        ),
        if (trailingAction != null)
          InkWell(
            onTap: trailingAction,
            child: Text(
              'Tümünü Gör >',
              style: TextStyle(
                color: _primaryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  // kaldırıldı: kullanılmayan hatırlatma itemi

  Widget _buildRecentReceipts(BuildContext context, List<Invoice> invoices) {
    if (invoices.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Text(
            'Fatura bulunamadı',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ),
      );
    }

    final sorted = List<Invoice>.from(invoices)
      ..sort((a, b) => b.date.compareTo(a.date));
    final recentInvoices = sorted.take(10).toList();

    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: recentInvoices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final invoice = recentInvoices[index];
        return _buildReceiptListCard(context, invoice);
      },
    );
  }

  // Web paketler bölümü
  Widget _buildWebPackagesSection(List<Map<String, dynamic>> packages) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Paketler',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 16),
          _buildPackagesSwitcher(packages),
        ],
      ),
    );
  }

  // Web istatistikler
  Widget _buildWebQuickStats(
    BuildContext context,
    List<Invoice> invoices,
    List<Invoice> allInvoices,
  ) {
    final approvedInvoices =
        allInvoices.where((i) => i.isApproved == true).length;
    final processedInvoices =
        allInvoices.where((i) => i.status == 'processed').length;
    final pendingInvoices =
        allInvoices.where((i) => i.status == 'pending').length;
    final failedInvoices =
        allInvoices.where((i) => i.status == 'failed').length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hızlı İstatistikler',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildWebStatCard(
                  icon: Icons.check_circle,
                  title: 'Onaylanan',
                  value: approvedInvoices.toString(),
                  color: _successGreen,
                  onTap: () {
                    setState(() {
                      if (_statusFilter == 'approved') {
                        _statusFilter = null;
                      } else {
                        _statusFilter = 'approved';
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildWebStatCard(
                  icon: Icons.check_circle_outline,
                  title: 'İşlenen',
                  value: processedInvoices.toString(),
                  color: _accentAmber,
                  onTap: () {
                    setState(() {
                      if (_statusFilter == 'processed') {
                        _statusFilter = null;
                      } else {
                        _statusFilter = 'processed';
                      }
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildWebStatCard(
                  icon: Icons.schedule,
                  title: 'Beklemede',
                  value: pendingInvoices.toString(),
                  color: _primaryBlue,
                  onTap: () {
                    setState(() {
                      if (_statusFilter == 'pending') {
                        _statusFilter = null;
                      } else {
                        _statusFilter = 'pending';
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildWebStatCard(
                  icon: Icons.error_outline,
                  title: 'Hatalı',
                  value: failedInvoices.toString(),
                  color: _errorRed,
                  onTap: () {
                    setState(() {
                      if (_statusFilter == 'failed') {
                        _statusFilter = null;
                      } else {
                        _statusFilter = 'failed';
                      }
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Web istatistik kartı
  Widget _buildWebStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: color.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Web fatura listesi
  Widget _buildWebRecentReceipts(
    BuildContext context,
    List<Invoice> invoices,
  ) {
    if (invoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz fatura bulunmuyor',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Fatura yüklemek için + butonuna tıklayın',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: invoices.length,
      itemBuilder: (context, index) {
        final invoice = invoices[index];
        return _buildWebInvoiceCard(invoice);
      },
    );
  }

  // Web fatura kartı
  Widget _buildWebInvoiceCard(Invoice invoice) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Fatura ikonu
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _getStatusColor(invoice.status ?? '').withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getStatusIcon(invoice.status ?? ''),
              color: _getStatusColor(invoice.status ?? ''),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          // Fatura bilgileri
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invoice.fileName ?? 'Fatura',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '₺${invoice.totalAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _primaryBlue,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: _textColorSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('dd/MM/yyyy').format(invoice.date),
                      style: TextStyle(
                        fontSize: 12,
                        color: _textColorSecondary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(invoice.status ?? '')
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getStatusText(invoice.status ?? ''),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: _getStatusColor(invoice.status ?? ''),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Aksiyon butonları
          Column(
            children: [
              IconButton(
                onPressed: () {
                  // TODO: Fatura detayına git
                },
                icon: Icon(
                  Icons.visibility,
                  color: _primaryBlue,
                ),
                tooltip: 'Görüntüle',
              ),
              if ((invoice.status ?? '') == 'processed')
                IconButton(
                  onPressed: () {
                    // TODO: Onayla/Reddet
                  },
                  icon: Icon(
                    invoice.isApproved == true
                        ? Icons.check_circle
                        : Icons.pending,
                    color: invoice.isApproved == true
                        ? _successGreen
                        : _accentAmber,
                  ),
                  tooltip: invoice.isApproved == true
                      ? 'Onaylandı'
                      : 'Onay Bekliyor',
                ),
            ],
          ),
        ],
      ),
    );
  }

  // Aylık fatura sayısını getir
  Future<int> _getMonthlyInvoiceCount() async {
    try {
      final allInvoices = await _allInvoicesFuture;
      final now = DateTime.now();
      return allInvoices
          .where((i) =>
              i.date.year == now.year &&
              i.date.month == now.month &&
              (i.status == 'approved' ||
                  (i.status == 'processed' && i.isApproved == true)))
          .length;
    } catch (e) {
      return 0;
    }
  }

  Widget _buildPackagesSwitcher(List<Map<String, dynamic>> packages) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemBuilder: (context, index) {
            if (index == 0) {
              // İlk seçenek: Tümü
              final selected = _packageFilter == null;
              return ChoiceChip(
                selected: selected,
                label: const Text('Tümü'),
                onSelected: (_) {
                  setState(() {
                    _packageFilter = null;
                    _selectedPackageId = null;
                  });
                },
              );
            } else {
              // Diğer paketler - isimleri kısalt
              final pkg = packages[index - 1];
              final id = (pkg['id']).toString();
              final fullName = (pkg['name'] ?? 'Paket').toString();
              final shortName = _getSmartPackageName(fullName);
              final selected = id == _packageFilter;
              return ChoiceChip(
                selected: selected,
                label: Text(shortName),
                onSelected: (_) {
                  setState(() {
                    _packageFilter = id;
                    _selectedPackageId = id;
                  });
                },
              );
            }
          },
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemCount: packages.length + 1, // +1 for "Tümü" option
        ),
      ),
    );
  }

  // Akıllı paket ismi oluştur
  String _getSmartPackageName(String fullName) {
    if (fullName.length <= 20) return fullName;

    // ISO 8601 tarih formatı: 2025-08-30T06:25:33.514Z
    if (fullName.contains('T') && fullName.contains('-')) {
      try {
        final parts = fullName.split('T');
        if (parts.length == 2) {
          final datePart = parts[0];
          final timePart = parts[1];

          if (datePart.contains('-')) {
            final dateParts = datePart.split('-');
            if (dateParts.length >= 3) {
              final day = dateParts[2];
              final month = dateParts[1];

              // Saat kısmını al (06:25:33.514Z -> 06:25)
              String timeDisplay = '';
              if (timePart.contains(':')) {
                final timeParts = timePart.split(':');
                if (timeParts.length >= 2) {
                  final hour = timeParts[0];
                  final minute = timeParts[1];
                  timeDisplay = ' $hour:$minute';
                }
              }

              return '$day/$month$timeDisplay'; // 30/08 06:25
            }
          }
        }
      } catch (e) {
        // Paket ismi parse hatası
      }
    }

    // Diğer formatlar için basit kısaltma
    if (fullName.length <= 25) return fullName;
    return '${fullName.substring(0, 22)}...';
  }

  // kaldırıldı: kullanılmayan yükleme kartı

  Widget _buildReceiptListCard(BuildContext context, Invoice invoice) {
    final formatCurrency = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');

    // Fatura durumuna göre renk ve icon belirle
    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (invoice.status == 'approved' ||
        (invoice.status == 'processed' && invoice.isApproved == true)) {
      statusColor = _successGreen;
      statusIcon = Icons.check_circle;
      statusText = 'Onaylandı';
    } else if (invoice.status == 'processed') {
      statusColor = _accentAmber;
      statusIcon = Icons.check_circle_outline;
      statusText = 'İşlendi';
    } else if (invoice.status == 'processing') {
      statusColor = _accentAmber;
      statusIcon = Icons.hourglass_bottom;
      statusText = 'İşleniyor';
    } else if (invoice.status == 'uploading' || invoice.status == 'queued') {
      statusColor = Colors.grey;
      statusIcon = Icons.upload;
      statusText = 'Yükleniyor';
    } else if (invoice.status == 'failed') {
      statusColor = _errorRed;
      statusIcon = Icons.error;
      statusText = 'Hata';
    } else {
      statusColor = Colors.grey;
      statusIcon = Icons.help;
      statusText = 'Bilinmiyor';
    }

    return InkWell(
      onTap: () {
        // Fatura detayına yönlendir - packageId ile birlikte
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => InvoiceDetailScreen(
              invoiceId: invoice.id,
              packageId: invoice.packageId ??
                  _selectedPackageId, // Önce fatura kendi packageId'sini kullan, yoksa seçili paketi
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardBackground,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _cardBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: invoice.thumbnailUrl != null &&
                      invoice.thumbnailUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        invoice.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: BoxDecoration(
                              color: _cardBackground,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: _buildFileTypeIcon(invoice.fileName),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            decoration: BoxDecoration(
                              color: _cardBackground,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes !=
                                        null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                                strokeWidth: 2,
                                color: _primaryBlue,
                              ),
                            ),
                          );
                        },
                        // Görsel yükleme hatalarını daha iyi handle et
                        cacheWidth: 88, // 44 * 2 for high DPI
                        cacheHeight: 88,
                        filterQuality: FilterQuality.medium,
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: _cardBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _buildFileTypeIcon(invoice.fileName),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invoice.sellerName.isNotEmpty
                        ? invoice.sellerName
                        : _decodeFileName(invoice.fileName),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: _textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('d MMMM yyyy', 'tr_TR').format(invoice.date),
                    style: TextStyle(color: _textColorSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatCurrency.format(invoice.totalAmount),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      Icon(statusIcon, color: _white, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(color: _white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileTypeIcon(String? fileName) {
    if (fileName == null) {
      return Icon(Icons.description, color: _textColorSecondary);
    }

    final extension = fileName.split('.').last.toLowerCase();
    IconData iconData;
    Color iconColor;

    switch (extension) {
      case 'pdf':
        iconData = Icons.picture_as_pdf;
        iconColor = _errorRed;
        break;
      case 'doc':
      case 'docx':
        iconData = Icons.description;
        iconColor = _primaryBlue;
        break;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
        iconData = Icons.image;
        iconColor = _successGreen;
        break;
      default:
        iconData = Icons.description;
        iconColor = _textColorSecondary;
    }

    return Icon(iconData, color: iconColor);
  }

  // Durum rengini getir
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return _successGreen;
      case 'processed':
        return _accentAmber;
      case 'pending':
        return _primaryBlue;
      case 'failed':
        return _errorRed;
      default:
        return Colors.grey;
    }
  }

  // Durum ikonunu getir
  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Icons.check_circle;
      case 'processed':
        return Icons.pending;
      case 'pending':
        return Icons.schedule;
      case 'failed':
        return Icons.error;
      default:
        return Icons.receipt;
    }
  }

  // Durum metnini getir
  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return 'Onaylandı';
      case 'processed':
        return 'İşlendi';
      case 'pending':
        return 'Bekliyor';
      case 'failed':
        return 'Hatalı';
      default:
        return 'Bilinmiyor';
    }
  }

  // Yeni: Filtrelenmiş faturaları döndür
  List<Invoice> _getFilteredInvoices(List<Invoice> allInvoices) {
    List<Invoice> filteredInvoices = allInvoices;

    // 1. Durum filtresi uygula
    if (_statusFilter != null) {
      switch (_statusFilter) {
        case 'approved':
          // Onaylananlar: Kullanıcı onaylamış faturalar
          filteredInvoices = filteredInvoices
              .where(
                (i) =>
                    i.status == 'approved' ||
                    (i.status == 'processed' && i.isApproved == true),
              )
              .toList();
          break;

        case 'processed':
          // İşlenen: Sistem işlemiş, onay bekleyen faturalar
          filteredInvoices = filteredInvoices
              .where((i) => i.status == 'processed' && i.isApproved != true)
              .toList();
          break;

        case 'pending':
          // Beklemede: Sistem tarafından işlenmeyi bekleyen faturalar
          filteredInvoices = filteredInvoices
              .where(
                (i) =>
                    i.status == 'processing' ||
                    i.status == 'uploading' ||
                    i.status == 'queued',
              )
              .toList();
          break;

        case 'failed':
          // Hatalı: Sistem tarafından işlenememiş faturalar
          filteredInvoices =
              filteredInvoices.where((i) => i.status == 'failed').toList();
          break;
      }
    }

    // 2. Paket filtresi uygula
    if (_packageFilter != null) {
      filteredInvoices =
          filteredInvoices.where((i) => i.packageId == _packageFilter).toList();
    }

    return filteredInvoices;
  }

  // Yeni: Filtre başlığını göster
  Widget _buildFilterHeader() {
    if (_statusFilter == null && _packageFilter == null) {
      return const SizedBox.shrink();
    }

    String filterTitle = '';
    Color filterColor = _primaryBlue;
    IconData filterIcon = Icons.filter_list;
    List<String> activeFilters = [];

    // Durum filtresi varsa ekle
    if (_statusFilter != null) {
      switch (_statusFilter) {
        case 'approved':
          activeFilters.add('Onaylanan');
          filterColor = _successGreen;
          filterIcon = Icons.check_circle;
          break;
        case 'processed':
          activeFilters.add('İşlenen');
          filterColor = _accentAmber;
          filterIcon = Icons.check_circle_outline;
          break;
        case 'pending':
          activeFilters.add('Bekleyen');
          filterColor = _accentAmber;
          filterIcon = Icons.hourglass_bottom;
          break;
        case 'failed':
          activeFilters.add('Hatalı');
          filterColor = _errorRed;
          filterIcon = Icons.error_outline;
          break;
      }
    }

    // Paket filtresi varsa ekle
    if (_packageFilter != null) {
      final package = _packages.firstWhere(
        (p) => p['id'].toString() == _packageFilter,
        orElse: () => {'name': 'Bilinmeyen Paket'},
      );
      final fullName = package['name'] ?? 'Paket';
      final shortName = _getSmartPackageName(fullName.toString());
      activeFilters.add(shortName);
    }

    // Filtre başlığını oluştur
    if (activeFilters.length == 1) {
      filterTitle = '${activeFilters.first} Faturalar';
    } else if (activeFilters.length == 2) {
      filterTitle = '${activeFilters.first} - ${activeFilters.last} Faturalar';
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: filterColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: filterColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(filterIcon, color: filterColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              filterTitle,
              style: TextStyle(
                color: filterColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _statusFilter = null;
                _packageFilter = null;
              });
            },
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Filtreyi Temizle'),
            style: TextButton.styleFrom(
              foregroundColor: filterColor,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(
    BuildContext context,
    List<Invoice> invoices,
    List<Invoice> allInvoices,
  ) {
    // Filtrelenmiş faturaları hesapla
    List<Invoice> filteredInvoices = allInvoices;

    // Paket filtresi varsa uygula
    if (_packageFilter != null) {
      filteredInvoices =
          filteredInvoices.where((i) => i.packageId == _packageFilter).toList();
    }

    // Onaylananlar: Kullanıcı onaylamış faturalar
    final approvedInvoices = filteredInvoices
        .where(
          (i) => (i.status == 'approved' ||
              (i.status == 'processed' && i.isApproved == true)),
        )
        .length;

    // İşlenen: Sistem işlemiş, onay bekleyen faturalar
    final processedInvoices = filteredInvoices
        .where((i) => i.status == 'processed' && i.isApproved != true)
        .length;

    // Beklemede: Sistem tarafından işlenmeyi bekleyen faturalar
    final pendingInvoices = filteredInvoices
        .where(
          (i) =>
              i.status == 'processing' ||
              i.status == 'uploading' ||
              i.status == 'queued',
        )
        .length;

    // Hatalı: Sistem tarafından işlenememiş faturalar
    final failedInvoices =
        filteredInvoices.where((i) => i.status == 'failed').length;

    Widget statCard({
      required IconData icon,
      required String title,
      required String value,
      required String filterType,
      required VoidCallback onTap,
    }) {
      final isSelected = _statusFilter == filterType;

      // Paket ismi gösterme - sadece durum ismi göster
      String displayTitle = title;

      return InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? _primaryBlue.withOpacity(0.1) : _cardBackground,
            borderRadius: BorderRadius.circular(12),
            border:
                isSelected ? Border.all(color: _primaryBlue, width: 2) : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: isSelected ? _primaryBlue : _primaryBlue),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? _primaryBlue : _textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                displayTitle,
                style: TextStyle(
                  color: isSelected ? _primaryBlue : const Color(0xFF6B7280),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // İlk satır - Onaylanan ve İşlenen
        Row(
          children: [
            Expanded(
              child: statCard(
                icon: Icons.check_circle,
                title: 'Onaylanan',
                value: approvedInvoices.toString(),
                filterType: 'approved',
                onTap: () {
                  setState(() {
                    if (_statusFilter == 'approved') {
                      _statusFilter = null; // Tekrar tıkla = filtreyi kaldır
                    } else {
                      _statusFilter = 'approved';
                    }
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: statCard(
                icon: Icons.check_circle_outline,
                title: 'İşlenen',
                value: processedInvoices.toString(),
                filterType: 'processed',
                onTap: () {
                  setState(() {
                    if (_statusFilter == 'processed') {
                      _statusFilter = null;
                    } else {
                      _statusFilter = 'processed';
                    }
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // İkinci satır - Beklemede ve Hatalı
        Row(
          children: [
            Expanded(
              child: statCard(
                icon: Icons.hourglass_bottom,
                title: 'Beklemede',
                value: pendingInvoices.toString(),
                filterType: 'pending',
                onTap: () {
                  setState(() {
                    if (_statusFilter == 'pending') {
                      _statusFilter = null;
                    } else {
                      _statusFilter = 'pending';
                    }
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: statCard(
                icon: Icons.error_outline,
                title: 'Hatalı',
                value: failedInvoices.toString(),
                filterType: 'failed',
                onTap: () {
                  setState(() {
                    if (_statusFilter == 'failed') {
                      _statusFilter = null;
                    } else {
                      _statusFilter = 'failed';
                    }
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
