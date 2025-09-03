import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

class WebSocketService {
  WebSocketChannel? _channel;
  StreamController<Map<String, dynamic>>? _messageController;
  Timer? _reconnectTimer;
  bool _isConnected = false;
  String? _token;
  String? _userId;

  // Singleton pattern
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  // Stream getter
  Stream<Map<String, dynamic>> get messageStream {
    _messageController ??= StreamController<Map<String, dynamic>>.broadcast();
    return _messageController!.stream;
  }

  // Bağlantı durumu
  bool get isConnected => _isConnected;

  // WebSocket bağlantısını başlat
  Future<void> connect(String token, String userId) async {
    if (_isConnected) return;

    _token = token;
    _userId = userId;

    try {
      // WebSocket URL'i (Docker container için)
      final wsUrl = 'ws://10.0.2.2:3000/ws?token=$token&userId=$userId';

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _isConnected = true;

      print('🔌 WebSocket bağlantısı kuruldu');

      // Mesajları dinle
      _channel!.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onError: (error) {
          print('❌ WebSocket hatası: $error');
          _isConnected = false;
          _scheduleReconnect();
        },
        onDone: () {
          print('🔌 WebSocket bağlantısı kapandı');
          _isConnected = false;
          _scheduleReconnect();
        },
      );

      // Bağlantı mesajı gönder
      _sendMessage({
        'type': 'connect',
        'userId': userId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ WebSocket bağlantı hatası: $e');
      _isConnected = false;
      _scheduleReconnect();
    }
  }

  // Mesaj gönder
  void _sendMessage(Map<String, dynamic> message) {
    if (_channel != null && _isConnected) {
      try {
        _channel!.sink.add(jsonEncode(message));
      } catch (e) {
        print('❌ WebSocket mesaj gönderme hatası: $e');
      }
    }
  }

  // Gelen mesajları işle
  void _handleMessage(dynamic message) {
    try {
      if (message is String) {
        final data = jsonDecode(message) as Map<String, dynamic>;
        _messageController?.add(data);

        // Mesaj tipine göre işle
        switch (data['type']) {
          case 'invoice_status_update':
            print(
                '📊 Fatura durumu güncellendi: ${data['invoiceId']} -> ${data['status']}');
            break;
          case 'package_status_update':
            print(
                '📦 Paket durumu güncellendi: ${data['packageId']} -> ${data['status']}');
            break;
          case 'processing_progress':
            print('⚙️ İşlem ilerlemesi: ${data['progress']}%');
            break;
          default:
            print('📨 WebSocket mesajı: $data');
        }
      }
    } catch (e) {
      print('❌ WebSocket mesaj işleme hatası: $e');
    }
  }

  // Yeniden bağlanma zamanlaması
  void _scheduleReconnect() {
    if (_reconnectTimer != null) return;

    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      _reconnectTimer = null;
      if (_token != null && _userId != null) {
        print('🔄 WebSocket yeniden bağlanmaya çalışılıyor...');
        connect(_token!, _userId!);
      }
    });
  }

  // Belirli bir fatura için durum güncellemelerini dinle
  void listenToInvoice(String invoiceId) {
    _sendMessage({
      'type': 'listen_invoice',
      'invoiceId': invoiceId,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // Belirli bir paket için durum güncellemelerini dinle
  void listenToPackage(String packageId) {
    _sendMessage({
      'type': 'listen_package',
      'packageId': packageId,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // Tüm faturaları dinle
  void listenToAllInvoices() {
    _sendMessage({
      'type': 'listen_all_invoices',
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // Bağlantıyı kapat
  void disconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    if (_channel != null) {
      _channel!.sink.close(status.goingAway);
      _channel = null;
    }

    _isConnected = false;
    print('🔌 WebSocket bağlantısı kapatıldı');
  }

  // Servisi temizle
  void dispose() {
    disconnect();
    _messageController?.close();
    _messageController = null;
  }
}
