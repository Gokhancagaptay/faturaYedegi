import 'package:flutter/material.dart';
import 'package:fatura_yeni/features/dashboard/models/invoice_model.dart';
import 'package:fatura_yeni/core/services/api_service.dart';
import 'package:fatura_yeni/core/services/storage_service.dart';
import 'package:fatura_yeni/core/services/websocket_service.dart';

enum DashboardStatus { initial, loading, loaded, error }

class DashboardProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  final WebSocketService _webSocketService = WebSocketService();

  List<Invoice> _invoices = [];
  List<Map<String, dynamic>> _packages = [];
  DashboardStatus _status = DashboardStatus.initial;
  String? _errorMessage;

  List<Invoice> get invoices => _invoices;
  List<Map<String, dynamic>> get packages => _packages;
  DashboardStatus get status => _status;
  String? get errorMessage => _errorMessage;

  bool _isDisposed = false;

  DashboardProvider() {
    // loadData() çağrısı kaldırıldı - initState'te çağrılacak
  }

  Future<void> loadData({bool silent = false}) async {
    if (!silent) {
      _status = DashboardStatus.loading;
      notifyListeners();
    }

    try {
      final token = await _storageService.getToken();
      if (token == null) {
        throw Exception('Oturum hatası. Lütfen tekrar giriş yapın.');
      }

      // Veri yükleme işlemlerini sırayla yap (paralel değil)
      print('🔄 Dashboard verileri yükleniyor...');
      _packages = await _loadPackages(token);
      _invoices = await _loadAllInvoices(token);

      print(
          '✅ Dashboard verileri yüklendi: ${_packages.length} paket, ${_invoices.length} fatura');
      _status = DashboardStatus.loaded;
      _errorMessage = null; // Hata mesajını temizle

      // WebSocket'i arka planda başlat (hata olsa bile dashboard çalışsın)
      _initializeWebSocket(token).catchError((e) {
        print('WebSocket başlatma hatası: $e');
      });
    } catch (e) {
      // Silent mode'da hata durumunda status'u değiştirme
      if (!silent) {
        _status = DashboardStatus.error;
        _errorMessage = e.toString();
      }
      print('Dashboard veri yükleme hatası: $e');
    }

    if (!_isDisposed) {
      notifyListeners();
    }
  }

  Future<List<Invoice>> _loadAllInvoices(String token) async {
    try {
      final packagesResponse = await _apiService.getPackages(token);
      final List<dynamic> packagesList = packagesResponse['packages'] ?? [];
      print('📦 Paket listesi alındı: ${packagesList.length} paket');
      List<Invoice> allInvoices = [];

      for (final package in packagesList) {
        try {
          final packageId = package['id']?.toString();
          if (packageId == null || packageId.isEmpty) continue;

          print('📄 Paket faturaları yükleniyor: $packageId');
          final packageInvoicesResponse =
              await _apiService.getPackageInvoices(token, packageId);
          final List<dynamic> packageInvoices =
              packageInvoicesResponse['invoices'] ?? [];
          print('📄 Paket $packageId: ${packageInvoices.length} fatura');

          for (final json in packageInvoices) {
            try {
              final invoiceData = Map<String, dynamic>.from(json);
              invoiceData['packageId'] = packageId;

              // Debug: Fatura tipini ve structured verisini kontrol et
              final fileName =
                  invoiceData['originalName'] as String? ?? 'Bilinmeyen';
              final hasStructured = invoiceData['structured'] != null;
              final fileUrl = invoiceData['fileUrl'] as String? ?? '';
              final isPdf = fileName.toLowerCase().endsWith('.pdf');

              print(
                  '📄 Fatura: $fileName | PDF: $isPdf | Structured: $hasStructured | URL: ${fileUrl.isNotEmpty ? "VAR" : "YOK"}');

              final invoice = Invoice.fromJson(invoiceData);
              allInvoices.add(invoice);
            } catch (e) {
              print('Fatura parse hatası: $e');
              continue;
            }
          }
        } catch (e) {
          print('Paket faturaları yükleme hatası: $e');
          continue;
        }
      }

      allInvoices.sort((a, b) => b.date.compareTo(a.date));
      print('📊 Toplam fatura sayısı: ${allInvoices.length}');
      return allInvoices;
    } catch (e) {
      print('Tüm faturaları yükleme hatası: $e');
      return []; // Boş liste döndür, dashboard çöksün
    }
  }

  Future<List<Map<String, dynamic>>> _loadPackages(String token) async {
    try {
      final res = await _apiService.getPackages(token);
      final List<dynamic> list = res['packages'] ?? [];
      print('📦 Paketler yüklendi: ${list.length} paket');
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Paketler yükleme hatası: $e');
      return []; // Boş liste döndür, dashboard çöksün
    }
  }

  Future<void> _initializeWebSocket(String token) async {
    try {
      final response = await _apiService.getUserProfile(token);
      if (response['success'] == true) {
        final user = response['user'];
        final userId = user['uid'];
        await _webSocketService.connect(token, userId);
        _webSocketService.messageStream.listen((message) {
          _handleWebSocketMessage(message);
        });
        _webSocketService.listenToAllInvoices();
      }
    } catch (e) {
      // WebSocket initialization failed
    }
  }

  void _handleWebSocketMessage(Map<String, dynamic> message) {
    print('📨 WebSocket mesajı alındı: ${message['type']}');

    if (message['type'] == 'invoice_update' ||
        message['type'] == 'package_update' ||
        message['type'] == 'invoice_status_update' ||
        message['type'] == 'package_status_update') {
      print('🔄 Dashboard verileri yenileniyor...');
      loadData(silent: true);
    }
  }

  // Verileri temizle (kullanıcı değişikliği için)
  void clearData() {
    _invoices.clear();
    _packages.clear();
    _status = DashboardStatus.initial;
    _errorMessage = null;
    _webSocketService.disconnect();
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _webSocketService.disconnect();
    super.dispose();
  }
}
