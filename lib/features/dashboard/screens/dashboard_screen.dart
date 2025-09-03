// lib/features/dashboard/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert'; // utf8.decode için gerekli
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:fatura_yeni/features/dashboard/models/invoice_model.dart';
import 'package:fatura_yeni/features/dashboard/providers/dashboard_provider.dart';
import 'package:fatura_yeni/core/services/api_service.dart';
import 'package:fatura_yeni/core/services/storage_service.dart';
import 'package:fatura_yeni/core/services/websocket_service.dart';
import 'package:fatura_yeni/features/scan/screens/scan_screen.dart';
import 'package:fatura_yeni/features/invoices/screens/invoice_detail_screen.dart';
import 'package:fatura_yeni/features/auth/screens/login_register_screen.dart';
import 'package:file_picker/file_picker.dart';

import 'package:fatura_yeni/core/providers/theme_provider.dart';
import 'package:fatura_yeni/core/constants/dashboard_constants.dart';
import 'package:fatura_yeni/features/upload/screens/upload_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // UI state for filters will remain in the widget
  String? _statusFilter;
  String? _packageFilter;
  String? _selectedPackageId;

  // Services needed for actions
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    // Dashboard'a geldiğinde veri yükleme işlemini başlat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<DashboardProvider>(context, listen: false);
      if (provider.status == DashboardStatus.initial) {
        print('🔄 Dashboard initState - Veri yükleme başlatılıyor');
        provider.loadData();
      }
    });
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

  // WebSocket bağlantısını başlatma ve veri yükleme işlemleri Provider'a taşındı.
  // initState ve dispose içindeki eski kodlar kaldırıldı.

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

  // İşlenen fatura sayısını hesapla - Artık Provider'dan gelen veri üzerinden
  int _getProcessedInvoiceCount(List<Invoice> allInvoices) {
    return allInvoices
        .where((i) =>
            i.status == 'processed' ||
            (i.status == 'approved' && i.isApproved == true))
        .length;
  }

  // Aylık fatura sayısını getir
  int _getMonthlyInvoiceCount(List<Invoice> allInvoices) {
    try {
      final now = DateTime.now();
      return allInvoices
          .where((i) => i.date.year == now.year && i.date.month == now.month)
          .length;
    } catch (e) {
      return 0;
    }
  }

  // _loadInvoices, _loadAllInvoices, _loadPackages Provider'a taşındı.

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
                  subtitle: 'Sadece fotoğraflar — tek/çoklu',
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _pickPhotos();
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
                    final result = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const ScanScreen(),
                      ),
                    );
                    // Veriyi yenilemek için provider'ı tetikle
                    if (!mounted || result == null) return;
                    await Provider.of<DashboardProvider>(context, listen: false)
                        .loadData(silent: true);
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

  // Sadece fotoğrafları seç
  Future<void> _pickPhotos() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image, // Sadece resimler
        allowMultiple: true,
      );
      final List<PlatformFile>? files = result?.files;

      if (files != null && files.isNotEmpty) {
        // Yükleme işlemini başlat ve kullanıcıyı bilgilendir
        if (!mounted) return;
        _showUploadSnackbar('Fotoğraf paketi oluşturuluyor...', false);

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
                'Fotoğraf paketi başarıyla oluşturuldu ve işleniyor.', false,
                isSuccess: true);
            // Veriyi yenilemek için provider'ı tetikle
            if (!mounted) return;
            await Provider.of<DashboardProvider>(context, listen: false)
                .loadData(silent: true);
          } else {
            final errorMessage =
                response['message'] as String? ?? 'Bilinmeyen bir hata oluştu.';
            _showUploadSnackbar(errorMessage, true);
          }
        } catch (e) {
          _showUploadSnackbar('Fotoğraf yükleme hatası: $e', true);
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Fotoğraf seçimi başarısız: $e')));
    }
  }

  // Tüm dosya türlerini seç (PDF, JPG, PNG)
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
        if (!mounted) return;
        _showUploadSnackbar('Belge paketi oluşturuluyor...', false);

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
                'Belge paketi başarıyla oluşturuldu ve işleniyor.', false,
                isSuccess: true);
            // Veriyi yenilemek için provider'ı tetikle
            if (!mounted) return;
            await Provider.of<DashboardProvider>(context, listen: false)
                .loadData(silent: true);
          } else {
            final errorMessage =
                response['message'] as String? ?? 'Bilinmeyen bir hata oluştu.';
            _showUploadSnackbar(errorMessage, true);
          }
        } catch (e) {
          _showUploadSnackbar('Belge yükleme hatası: $e', true);
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Belge seçimi başarısız: $e')));
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
        backgroundColor: isSuccess
            ? Colors.green
            : isError
                ? Colors.redAccent
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
          color: _primaryBlue.withAlpha((255 * 0.1).round()),
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

    return Scaffold(
      backgroundColor: _backgroundColor,
      // AppBar ve üst bilgi barı kaldırıldı - maksimum ekran alanı
      body: SafeArea(
        child: Consumer<DashboardProvider>(
          builder: (context, provider, child) {
            // Veri durumuna göre UI'ı oluştur
            switch (provider.status) {
              case DashboardStatus.loading:
                return const Center(child: CircularProgressIndicator());
              case DashboardStatus.error:
                return _buildErrorState(provider.errorMessage);
              case DashboardStatus.loaded:
              case DashboardStatus.initial: // Also handles initial loaded state
                final invoices = provider.invoices;
                final packages = provider.packages;

                print(
                    '📊 Dashboard UI - Paketler: ${packages.length}, Faturalar: ${invoices.length}');

                if (invoices.isEmpty) {
                  print('📊 Dashboard UI - Empty state gösteriliyor');
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
                    )
                    .fold<double>(0.0, (sum, item) => sum + item.totalAmount);

                final allInvoices = provider.invoices;

                // Web için farklı layout
                if (isWeb) {
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
            }
          },
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: kIsWeb
          ? FloatingActionButton.extended(
              backgroundColor: _primaryBlue,
              onPressed: () => _handleFabClick(context),
              tooltip: 'Yeni Paket Yükle',
              icon: Icon(Icons.upload_file, color: _white),
              label: Text('Dosya Yükle', style: TextStyle(color: _white)),
            )
          : FloatingActionButton(
              backgroundColor: _primaryBlue,
              onPressed: () => _handleFabClick(context),
              tooltip: 'Fatura Ekle',
              child: Icon(Icons.add, color: _white),
            ),
      // bottomNavigationBar kaldırıldı: ana seviye navigasyon MainScreen'de yönetiliyor
    );
  }

  void _handleFabClick(BuildContext context) async {
    if (kIsWeb) {
      // Web'de UploadScreen'e git - yönlendirme yok, sadece aç
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const UploadScreen()),
      );
    } else {
      // Mobilde ScanScreen'e git
      _showUploadOptions();
    }
  }

  Widget _buildErrorState([String? message]) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: _errorRed.withAlpha((255 * 0.1).round()),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 60,
                color: _errorRed,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Veriler yüklenirken hata oluştu',
              style: TextStyle(
                color: _textColor,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Lütfen internet bağlantınızı kontrol edin ve tekrar deneyin.',
              style: TextStyle(
                color: _textColorSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _errorRed.withAlpha((255 * 0.1).round()),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _errorRed,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Provider.of<DashboardProvider>(context, listen: false)
                        .loadData();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tekrar Dene'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryBlue,
                    foregroundColor: _white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    _logout();
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Çıkış Yap'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _textColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
                    color: _primaryBlue.withAlpha((255 * 0.1).round()),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.receipt_long,
                    size: 60,
                    color: _primaryBlue.withAlpha((255 * 0.6).round()),
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
                      // Veriyi yenilemek için provider'ı tetikle
                      if (!mounted) return;
                      await Provider.of<DashboardProvider>(context,
                              listen: false)
                          .loadData(silent: true);
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
                _primaryBlue.withAlpha((255 * 0.8).round()),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _primaryBlue.withAlpha((255 * 0.3).round()),
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
                                color: _white.withAlpha((255 * 0.9).round()),
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          },
                        ),
                        Text(
                          'Bu ayki harcamalarınızı takip edin',
                          style: TextStyle(
                            color: _white.withAlpha((255 * 0.7).round()),
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
                'Bu Ayki Toplam Fatura',
                style: TextStyle(
                  color: _white.withAlpha((255 * 0.8).round()),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '₺${monthlyTotal.toStringAsFixed(2)}',
                style: TextStyle(
                  color: _white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_getMonthlyInvoiceCount(invoices)} Fatura',
                style: TextStyle(
                  color: _white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
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
                        ? _primaryBlue.withAlpha(
                            (255 * 0.6).round()) // Dark mode'da daha koyu
                        : _primaryBlue.withAlpha(
                            (255 * 0.8).round()), // Light mode'da normal
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _primaryBlue.withAlpha((255 * 0.3).round()),
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
                          color: _white.withAlpha((255 * 0.2).round()),
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
                                    color:
                                        _white.withAlpha((255 * 0.9).round()),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                );
                              },
                            ),
                            Text(
                              'Bu ayki harcamalarınızı takip edin',
                              style: TextStyle(
                                color: _white.withAlpha((255 * 0.7).round()),
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
                      color: _white.withAlpha((255 * 0.8).round()),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_getProcessedInvoiceCount(invoices)} Fatura',
                    style: TextStyle(
                      color: _white,
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                    ),
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
          color: Theme.of(context).dividerColor.withAlpha((255 * 0.2).round()),
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
          color: Theme.of(context).dividerColor.withAlpha((255 * 0.2).round()),
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
          color: color.withAlpha((255 * 0.1).round()),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withAlpha((255 * 0.3).round()),
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
                color: color.withAlpha((255 * 0.8).round()),
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
          color: Theme.of(context).dividerColor.withAlpha((255 * 0.2).round()),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((255 * 0.05).round()),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Fatura ikonu
          SizedBox(
            width: 48,
            height: 48,
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
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              strokeWidth: 2,
                              color: _primaryBlue,
                            ),
                          ),
                        );
                      },
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
                            .withAlpha((255 * 0.1).round()),
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
                onPressed: () async {
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => InvoiceDetailScreen(
                        invoiceId: invoice.id,
                        packageId: invoice.packageId ?? _selectedPackageId,
                      ),
                    ),
                  );
                  // Eğer onaylama işlemi yapıldıysa (pop(true)), listeyi yenile
                  if (result == true) {
                    Provider.of<DashboardProvider>(context, listen: false)
                        .loadData();
                  }
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
      onTap: () async {
        // Fatura detayına yönlendir - packageId ile birlikte
        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => InvoiceDetailScreen(
              invoiceId: invoice.id,
              packageId: invoice.packageId ??
                  _selectedPackageId, // Önce fatura kendi packageId'sini kullan, yoksa seçili paketi
            ),
          ),
        );
        // Eğer onaylama işlemi yapıldıysa (pop(true)), listeyi yenile
        if (result == true) {
          Provider.of<DashboardProvider>(context, listen: false).loadData();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardBackground,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((255 * 0.05).round()),
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
    List<Invoice> filteredInvoices = List.from(allInvoices);

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
      final package = Provider.of<DashboardProvider>(context, listen: false)
          .packages
          .firstWhere(
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
        color: filterColor.withAlpha((255 * 0.1).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: filterColor.withAlpha((255 * 0.3).round())),
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
            color: isSelected
                ? _primaryBlue.withAlpha((255 * 0.1).round())
                : _cardBackground,
            borderRadius: BorderRadius.circular(12),
            border:
                isSelected ? Border.all(color: _primaryBlue, width: 2) : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((255 * 0.05).round()),
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

  // Logout metodu
  void _logout() async {
    try {
      final storageService = StorageService();

      // Token'ı, WebSocket bağlantısını ve dashboard verilerini temizle
      await storageService.deleteToken();
      WebSocketService().disconnect();

      // Dashboard verilerini temizle
      if (mounted) {
        final dashboardProvider =
            Provider.of<DashboardProvider>(context, listen: false);
        dashboardProvider.clearData();
      }

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginRegisterScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      // Hata durumunda da giriş ekranına yönlendir
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginRegisterScreen()),
          (route) => false,
        );
      }
    }
  }
}
