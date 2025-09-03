import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:fatura_yeni/core/services/api_service.dart';
import 'package:fatura_yeni/core/services/storage_service.dart';
import 'package:fatura_yeni/core/services/websocket_service.dart';
import 'package:fatura_yeni/features/packages/screens/package_detail_screen.dart';
import 'package:fatura_yeni/features/auth/screens/login_register_screen.dart';
import 'package:fatura_yeni/features/dashboard/providers/dashboard_provider.dart';
import 'package:fatura_yeni/core/providers/theme_provider.dart';
import 'package:fatura_yeni/core/constants/dashboard_constants.dart';

class PackagesScreen extends StatefulWidget {
  const PackagesScreen({super.key});

  @override
  State<PackagesScreen> createState() => _PackagesScreenState();
}

class _PackagesScreenState extends State<PackagesScreen> {
  final ApiService _api = ApiService();
  final StorageService _storage = StorageService();
  late Future<List<Map<String, dynamic>>> _packagesFuture;

  @override
  void initState() {
    super.initState();
    _packagesFuture = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    try {
      final token = await _storage.getToken();
      print(
          '🔐 Packages - Token kontrol ediliyor: ${token != null ? 'VAR' : 'YOK'}');
      if (token != null) {
        print('🔐 Packages - Token değeri: ${token.substring(0, 10)}...');
      }

      if (token == null) {
        throw Exception('Giriş yapmanız gerekiyor. Lütfen tekrar giriş yapın.');
      }

      final res = await _api.getPackages(token);
      final List<dynamic> list = res['packages'] ?? [];
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      print('❌ Packages - Hata: $e');
      rethrow;
    }
  }

  // Paket durumunu belirle
  String _getPackageStatus(Map<String, dynamic> pkg) {
    final int total = (pkg['totalInvoices'] ?? 0) as int;
    final int processed = (pkg['processedInvoices'] ?? 0) as int;
    final int errors = (pkg['errorCount'] ?? 0) as int;

    if (total == 0) return 'Boş';
    if (processed == total && errors == 0) return 'Tamamlandı';
    if (errors > 0) return 'Hata Var';
    if (processed > 0) return 'İşleniyor';
    return 'Bekliyor';
  }

  // Durum rengini belirle
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Tamamlandı':
        return DashboardConstants.lightSuccessGreen;
      case 'İşleniyor':
        return DashboardConstants.lightAccentAmber;
      case 'Hata Var':
        return DashboardConstants.lightErrorRed;
      case 'Bekliyor':
        return DashboardConstants.lightPrimaryBlue;
      default:
        return Colors.grey;
    }
  }

  // Durum ikonunu belirle
  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Tamamlandı':
        return Icons.check_circle;
      case 'İşleniyor':
        return Icons.hourglass_bottom;
      case 'Hata Var':
        return Icons.error_outline;
      case 'Bekliyor':
        return Icons.schedule;
      default:
        return Icons.help_outline;
    }
  }

  // Paket ismini formatla
  String _formatPackageName(String rawName) {
    if (rawName.contains('T') && rawName.contains('-')) {
      try {
        final parts = rawName.split('T');
        if (parts.length == 2) {
          final datePart = parts[0];
          final timePart = parts[1];

          if (datePart.contains('-')) {
            final dateParts = datePart.split('-');
            if (dateParts.length >= 3) {
              final year = dateParts[0];
              final month = dateParts[1];
              final day = dateParts[2];

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

              return '$day $month $year$timeDisplay Paketi';
            }
          }
        }
      } catch (e) {
        // Parse hatası durumunda orijinal ismi kullan
      }
    }

    // Diğer formatlar için basit kısaltma
    if (rawName.length <= 30) return rawName;
    return '${rawName.substring(0, 27)}...';
  }

  // Progress bar rengini belirle
  Color _getProgressColor(String status) {
    switch (status) {
      case 'Tamamlandı':
        return DashboardConstants.lightSuccessGreen;
      case 'İşleniyor':
        return DashboardConstants.lightAccentAmber;
      case 'Hata Var':
        return DashboardConstants.lightErrorRed;
      default:
        return DashboardConstants.lightPrimaryBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.watch<ThemeProvider>().isDarkMode;
    final colors = DashboardConstants.getColors(isDarkMode);

    return Scaffold(
      backgroundColor: colors['background'] as Color,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(context, colors),

            // Paket Listesi
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _packagesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: colors['primaryBlue'] as Color,
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return _buildErrorState(context, colors);
                  }

                  final packages = snapshot.data ?? [];
                  if (packages.isEmpty) {
                    return _buildEmptyState(context, colors);
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      final future = _load();
                      setState(() {
                        _packagesFuture = future;
                      });
                      await future;
                    },
                    child: ListView.separated(
                      padding: EdgeInsets.all(
                          DashboardConstants.getResponsivePadding(context)),
                      itemCount: packages.length,
                      separatorBuilder: (_, __) => SizedBox(
                          height:
                              DashboardConstants.getResponsiveSpacing(context)),
                      itemBuilder: (context, index) {
                        final pkg = packages[index];
                        return _buildPackageCard(context, pkg, colors);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Header
  Widget _buildHeader(BuildContext context, Map<String, dynamic> colors) {
    return Container(
      padding: EdgeInsets.all(DashboardConstants.getResponsivePadding(context)),
      decoration: BoxDecoration(
        color: colors['surface'] as Color,
        boxShadow: DashboardConstants.getHeaderShadow(colors['isDark'] as bool),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors['primaryBlue'] as Color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.inventory_2,
              color: colors['white'] as Color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Paketler',
            style: TextStyle(
              color: colors['text'] as Color,
              fontSize: DashboardConstants.getResponsiveFontSize(context, 24),
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          // Theme toggle
          IconButton(
            tooltip: 'Tema Değiştir',
            onPressed: () {
              context.read<ThemeProvider>().toggleTheme();
            },
            icon: Icon(
              context.watch<ThemeProvider>().isDarkMode
                  ? Icons.light_mode
                  : Icons.dark_mode,
              color: colors['primaryBlue'] as Color,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  // Paket Kartı
  Widget _buildPackageCard(BuildContext context, Map<String, dynamic> pkg,
      Map<String, dynamic> colors) {
    final name = (pkg['name'] ?? 'Paket').toString();
    final total = (pkg['totalInvoices'] ?? 0) as int;
    final processed = (pkg['processedInvoices'] ?? 0) as int;
    final errors = (pkg['errorCount'] ?? 0) as int;
    final status = _getPackageStatus(pkg);
    final progress = total > 0 ? (processed / total).clamp(0.0, 1.0) : 0.0;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PackageDetailScreen(
              packageId: (pkg['id']).toString(),
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(DashboardConstants.cardRadius),
      child: Container(
        padding:
            EdgeInsets.all(DashboardConstants.getResponsivePadding(context)),
        decoration: BoxDecoration(
          color: colors['surface'] as Color,
          borderRadius: BorderRadius.circular(DashboardConstants.cardRadius),
          boxShadow: DashboardConstants.getCardShadow(colors['isDark'] as bool),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst satır - Başlık ve Durum
            Row(
              children: [
                // Sol ikon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: (colors['primaryBlue'] as Color).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.inventory_2,
                    color: colors['primaryBlue'] as Color,
                    size: 24,
                  ),
                ),

                const SizedBox(width: 16),

                // Başlık
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatPackageName(name),
                        style: TextStyle(
                          color: colors['text'] as Color,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Durum: $processed / $total Fatura İşlendi',
                        style: TextStyle(
                          color: colors['textSecondary'] as Color,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                // Durum etiketi
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getStatusColor(status).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getStatusIcon(status),
                        color: _getStatusColor(status),
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        status,
                        style: TextStyle(
                          color: _getStatusColor(status),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Sağ ok
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: colors['textSecondary'] as Color,
                  size: 20,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Progress bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'İlerleme',
                      style: TextStyle(
                        color: colors['textSecondary'] as Color,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: TextStyle(
                        color: _getProgressColor(status),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: colors['background'] as Color,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(_getProgressColor(status)),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),

            // Alt bilgi
            if (errors > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: DashboardConstants.lightErrorRed,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$errors fatura işlenirken hata oluştu',
                    style: TextStyle(
                      color: DashboardConstants.lightErrorRed,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Hata durumu
  Widget _buildErrorState(BuildContext context, Map<String, dynamic> colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: colors['textSecondary'] as Color,
          ),
          const SizedBox(height: 16),
          Text(
            'Paketler yüklenemedi',
            style: TextStyle(
              color: colors['text'] as Color,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Lütfen internet bağlantınızı kontrol edin',
            style: TextStyle(
              color: colors['textSecondary'] as Color,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _packagesFuture = _load();
                  });
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Tekrar Dene'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors['primaryBlue'] as Color,
                  foregroundColor: colors['white'] as Color,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(DashboardConstants.buttonRadius),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => _logout(context),
                icon: const Icon(Icons.logout),
                label: const Text('Giriş Yap'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors['accentAmber'] as Color,
                  foregroundColor: colors['white'] as Color,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(DashboardConstants.buttonRadius),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _logout(BuildContext context) async {
    try {
      // Token'ı, WebSocket bağlantısını ve dashboard verilerini temizle
      await _storage.deleteToken();
      WebSocketService().disconnect();

      // Dashboard verilerini temizle
      if (mounted) {
        final dashboardProvider =
            Provider.of<DashboardProvider>(context, listen: false);
        dashboardProvider.clearData();
      }

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const LoginRegisterScreen(),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      // Hata durumunda da giriş ekranına yönlendir
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const LoginRegisterScreen(),
          ),
          (route) => false,
        );
      }
    }
  }

  // Boş durum
  Widget _buildEmptyState(BuildContext context, Map<String, dynamic> colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: DashboardConstants.getResponsiveContainerSize(context, 120),
            height: DashboardConstants.getResponsiveContainerSize(context, 120),
            decoration: BoxDecoration(
              color: (colors['primaryBlue'] as Color).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inventory_2,
              size: 60,
              color: (colors['primaryBlue'] as Color).withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Henüz paket yok',
            style: TextStyle(
              fontSize: DashboardConstants.getResponsiveFontSize(context, 24),
              fontWeight: FontWeight.bold,
              color: colors['text'] as Color,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'İlk faturanızı yükleyerek paket oluşturun',
            style: TextStyle(
              fontSize: 16,
              color: colors['textSecondary'] as Color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
