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
    loadData();
  }

  Future<void> loadData({bool silent = false}) async {
    if (!silent) {
      _status = DashboardStatus.loading;
      notifyListeners();
    }

    try {
      final token = await _storageService.getToken();
      if (token == null) throw Exception('Authentication token not found.');

      final results = await Future.wait([
        _loadAllInvoices(token),
        _loadPackages(token),
      ]);

      _invoices = results[0] as List<Invoice>;
      _packages = results[1] as List<Map<String, dynamic>>;

      _status = DashboardStatus.loaded;
      _initializeWebSocket(token);
    } catch (e) {
      _status = DashboardStatus.error;
      _errorMessage = e.toString();
    }

    if (!_isDisposed) {
      notifyListeners();
    }
  }

  Future<List<Invoice>> _loadAllInvoices(String token) async {
    final packagesResponse = await _apiService.getPackages(token);
    final List<dynamic> packagesList = packagesResponse['packages'] ?? [];
    List<Invoice> allInvoices = [];
    for (final package in packagesList) {
      try {
        final packageId = package['id'].toString();
        final packageInvoicesResponse =
            await _apiService.getPackageInvoices(token, packageId);
        final List<dynamic> packageInvoices =
            packageInvoicesResponse['invoices'] ?? [];
        final packageInvoicesList = packageInvoices.map((json) {
          final invoiceData = Map<String, dynamic>.from(json);
          invoiceData['packageId'] = packageId;
          return Invoice.fromJson(invoiceData);
        }).toList();
        allInvoices.addAll(packageInvoicesList);
      } catch (e) {
        continue;
      }
    }
    allInvoices.sort((a, b) => b.date.compareTo(a.date));
    return allInvoices;
  }

  Future<List<Map<String, dynamic>>> _loadPackages(String token) async {
    final res = await _apiService.getPackages(token);
    final List<dynamic> list = res['packages'] ?? [];
    return list.cast<Map<String, dynamic>>();
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
    if (message['type'] == 'invoice_update' ||
        message['type'] == 'package_update' ||
        message['type'] == 'invoice_status_update') {
      loadData(silent: true);
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _webSocketService.disconnect();
    super.dispose();
  }
}
