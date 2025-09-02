// lib/core/services/api_service.dart
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:io' show SocketException;

class ApiService {
  // Backend URL seçimi: Platform'a göre otomatik
  static String get _baseUrl {
    if (kIsWeb) {
      // Web için: Aynı domain'de çalışıyor
      return "http://localhost:3000";
    }

    if (Platform.isAndroid) {
      // Android emülatör için
      if (Platform.environment.containsKey('ANDROID_EMULATOR')) {
        return "http://10.0.2.2:3000";
      }
      // Fiziksel cihaz için: LAN IP kullan
      return "http://192.168.4.73:3000";
    }

    if (Platform.isIOS) {
      // iOS simülatör için
      return "http://localhost:3000";
    }

    // Varsayılan
    return "http://localhost:3000";
  }

  // API bağlantısını test et
  static Future<bool> testConnection() async {
    try {
      final resp = await http.get(
        Uri.parse("$_baseUrl/health"),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      return resp.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Hata mesajlarını kullanıcı dostu hale getir
  static String _humanizeError(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('connection timed out') ||
        errorStr.contains('connection refused') ||
        errorStr.contains('failed to connect')) {
      return 'Sunucuya bağlanılamıyor. Lütfen internet bağlantınızı kontrol edin.';
    }

    if (errorStr.contains('401') || errorStr.contains('unauthorized')) {
      return 'Oturum süreniz dolmuş. Lütfen tekrar giriş yapın.';
    }

    if (errorStr.contains('403') || errorStr.contains('forbidden')) {
      return 'Bu işlem için yetkiniz bulunmuyor.';
    }

    if (errorStr.contains('404') || errorStr.contains('not found')) {
      return 'İstenen kaynak bulunamadı.';
    }

    if (errorStr.contains('500') ||
        errorStr.contains('internal server error')) {
      return 'Sunucu hatası. Lütfen daha sonra tekrar deneyin.';
    }

    return 'Beklenmeyen bir hata oluştu: $error';
  }

  // Signed URL'leri handle etmek için yardımcı fonksiyon
  static String? getSignedUrl(String? url) {
    if (url == null || url.isEmpty) return null;

    // Eğer URL zaten signed URL ise (token parametresi varsa) direkt döndür
    if (url.contains('token=')) {
      return url;
    }

    // Eğer public URL ise ve erişim sorunu varsa, backend'den signed URL iste
    // Bu durumda backend'de bir endpoint oluşturmak gerekebilir
    return url;
  }

  // OTP ile kayıt/giriş
  Future<Map<String, dynamic>> registerWithOtp({
    required String phoneNumber,
  }) async {
    try {
      final resp = await http
          .post(
            Uri.parse("$_baseUrl/api/auth/register"),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              "phoneNumber": phoneNumber,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (resp.statusCode != 200) {
        throw Exception(_humanizeError(resp.body));
      }
      return jsonDecode(resp.body);
    } catch (e) {
      throw Exception(_humanizeError(e));
    }
  }

  // OTP doğrulama
  Future<Map<String, dynamic>> verifyOtp({
    required String phoneNumber,
    required String otp,
  }) async {
    try {
      final resp = await http
          .post(
            Uri.parse("$_baseUrl/api/auth/verify-otp"),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              "phoneNumber": phoneNumber,
              "otp": otp,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (resp.statusCode != 200) {
        throw Exception(_humanizeError(resp.body));
      }
      return jsonDecode(resp.body);
    } catch (e) {
      throw Exception(_humanizeError(e));
    }
  }

  // Fatura yükleme ve işleme (senkron)
  Future<Map<String, dynamic>> uploadAndParseInvoice(
      String token, String filePath,
      {String? fileUrl}) async {
    try {
      final uri = Uri.parse("$_baseUrl/api/invoice/scan");
      var request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token';

      request.files.add(await http.MultipartFile.fromPath(
        'invoice', // Backend'deki multer field adı
        filePath,
      ));

      if (fileUrl != null) {
        request.fields['fileUrl'] = fileUrl;
      }

      final response =
          await request.send().timeout(const Duration(seconds: 60));
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode != 200) {
        throw Exception(_humanizeError(
            'Failed to upload invoice: ${response.reasonPhrase}'));
      }
      return jsonDecode(responseBody);
    } catch (e) {
      throw Exception(_humanizeError(e));
    }
  }

  // Fatura yükleme ve işleme (asenkron/arka plan)
  Future<Map<String, dynamic>> uploadAndParseInvoiceBackground(
      String token, String filePath) async {
    try {
      final uri = Uri.parse("$_baseUrl/api/invoice/scan-background");
      var request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token';

      request.files.add(await http.MultipartFile.fromPath(
        'invoice',
        filePath,
      ));

      final response =
          await request.send().timeout(const Duration(seconds: 30));
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode != 202) {
        throw Exception(_humanizeError(
            'Failed to start background processing: ${response.reasonPhrase}'));
      }
      return jsonDecode(responseBody);
    } catch (e) {
      throw Exception(_humanizeError(e));
    }
  }

  // Kullanıcının faturalarını getir
  Future<Map<String, dynamic>> getInvoices(String token) async {
    try {
      final resp = await http.get(
        Uri.parse("$_baseUrl/api/invoice"),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 30));

      if (resp.statusCode != 200) {
        throw Exception(_humanizeError(resp.body));
      }
      return jsonDecode(resp.body);
    } catch (e) {
      throw Exception(_humanizeError(e));
    }
  }

  // Firebase ID token ile login -> backend JWT alır
  Future<Map<String, dynamic>> loginWithFirebaseToken({
    required String firebaseIdToken,
    String? phoneNumber,
  }) async {
    try {
      final resp = await http
          .post(
            Uri.parse("$_baseUrl/api/auth/login-firebase"),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'firebaseIdToken': firebaseIdToken,
              if (phoneNumber != null) 'phoneNumber': phoneNumber,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (resp.statusCode != 200) {
        throw Exception(_humanizeError(resp.body));
      }
      return jsonDecode(resp.body);
    } catch (e) {
      throw Exception(_humanizeError(e));
    }
  }

  // NEW: Password-based register
  Future<Map<String, dynamic>> registerWithPassword({
    String? name,
    String? email,
    String? phoneNumber,
    required String password,
  }) async {
    try {
      final resp = await http
          .post(
            Uri.parse("$_baseUrl/api/auth/register-password"),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              "name": name,
              "email": email,
              "phoneNumber": phoneNumber,
              "password": password,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception(_humanizeError(resp.body));
      }
      return jsonDecode(resp.body);
    } catch (e) {
      throw Exception(_humanizeError(e));
    }
  }

  // NEW: Password-based login (identifier: email or phone)
  Future<Map<String, dynamic>> loginWithPassword({
    required String identifier,
    required String password,
  }) async {
    try {
      final resp = await http
          .post(
            Uri.parse("$_baseUrl/api/auth/login-password"),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              "identifier": identifier,
              "password": password,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (resp.statusCode != 200) {
        throw Exception(_humanizeError(resp.body));
      }
      return jsonDecode(resp.body);
    } catch (e) {
      throw Exception(_humanizeError(e));
    }
  }

  Future<Map<String, dynamic>> exportInvoicesJson(String token) async {
    try {
      final uri = Uri.parse("$_baseUrl/api/invoice/export.json");
      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception(_humanizeError(
            'Failed to export invoices: ${response.reasonPhrase}'));
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception(_humanizeError(e));
    }
  }

  // Paketler - liste
  Future<Map<String, dynamic>> getPackages(String token) async {
    try {
      final uri = Uri.parse("$_baseUrl/api/packages");
      final resp = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 30));

      if (resp.statusCode != 200) {
        throw Exception(
            _humanizeError('Failed to load packages: ${resp.reasonPhrase}'));
      }
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception(_humanizeError(e));
    }
  }

  // Paket detayı
  Future<Map<String, dynamic>> getPackageDetail(
      String token, String packageId) async {
    try {
      final uri = Uri.parse("$_baseUrl/api/packages/$packageId");
      final resp = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 30));

      if (resp.statusCode != 200) {
        throw Exception(
            _humanizeError('Failed to load package: ${resp.reasonPhrase}'));
      }

      final responseData = jsonDecode(resp.body) as Map<String, dynamic>;

      return responseData;
    } catch (e) {
      throw Exception(_humanizeError(e));
    }
  }

  // Paket içindeki faturalar
  Future<Map<String, dynamic>> getPackageInvoices(
      String token, String packageId) async {
    try {
      final uri = Uri.parse("$_baseUrl/api/packages/$packageId/invoices");
      final resp = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 30));

      if (resp.statusCode != 200) {
        throw Exception(_humanizeError(
            'Failed to load package invoices: ${resp.reasonPhrase}'));
      }
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception(_humanizeError(e));
    }
  }

  // Paket oluştur (çoklu dosya)
  Future<Map<String, dynamic>> createPackage(
      List<PlatformFile> files, String token) async {
    final url = Uri.parse('$_baseUrl/api/packages');
    final request = http.MultipartRequest('POST', url);

    request.headers['Authorization'] = 'Bearer $token';

    for (var file in files) {
      if (kIsWeb) {
        // Web platformu için (byte'lar var)
        request.files.add(
          http.MultipartFile.fromBytes(
            'files',
            file.bytes!,
            filename: file.name,
          ),
        );
      } else {
        // Mobil platformlar için (dosya yolu var)
        request.files.add(
          await http.MultipartFile.fromPath(
            'files',
            file.path!,
            filename: file.name,
          ),
        );
      }
    }

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 202) {
        // 202 Accepted durumunda, işlem başarıyla kuyruğa alındı demektir.
        // Body boş olabilir, bu yüzden varsayılan bir başarı mesajı döndürelim.
        if (response.body.isEmpty) {
          return {
            'success': true,
            'message': 'Package creation accepted and is in progress.',
            'package': {'id': null} // ID henüz bilinmiyor olabilir
          };
        }
      }
      return _handleResponse(response);
    } on SocketException {
      throw Exception('İnternet bağlantısı yok veya sunucuya ulaşılamıyor.');
    } catch (e) {
      throw Exception('Paket oluşturulamadı: $e');
    }
  }

  // Yanıtı işle
  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300 ||
        response.statusCode == 202) {
      try {
        final decoded = json.decode(response.body);
        return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
      } catch (e) {
        // JSON parse hatası durumunda ham body'i bir anahtar altında döndür
        return {
          'success': false,
          'message': 'Invalid response format',
          'body': response.body
        };
      }
    } else {
      String errorMessage;
      try {
        final errorBody = json.decode(response.body);
        errorMessage =
            errorBody['message'] ?? 'Bilinmeyen bir sunucu hatası oluştu.';
      } catch (e) {
        errorMessage = response.body.isNotEmpty
            ? response.body
            : 'Sunucudan yanıt alınamadı.';
      }
      throw Exception('Hata: ${response.statusCode} - $errorMessage');
    }
  }

  // Paket yeniden değerlendir
  Future<Map<String, dynamic>> reevaluatePackage(
      String token, String packageId) async {
    try {
      final uri = Uri.parse("$_baseUrl/api/packages/$packageId/reevaluate");
      final resp = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (resp.statusCode != 200) {
        throw Exception(_humanizeError(
            'Failed to reevaluate package: ${resp.reasonPhrase}'));
      }
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception(_humanizeError(e));
    }
  }

  // YENİ EKLENEN FATURA FONKSİYONLARI

  Future<Map<String, dynamic>?> getInvoiceDetail(
      String token, String packageId, String invoiceId) async {
    try {
      final uri =
          Uri.parse("$_baseUrl/api/packages/$packageId/invoices/$invoiceId");
      final resp = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 30));

      if (resp.statusCode == 200 && resp.body.isNotEmpty) {
        return jsonDecode(resp.body);
      } else {
        // Hata durumunda veya boş yanıtta null döndür
        return null;
      }
    } catch (e) {
      throw Exception(_humanizeError(e));
    }
  }

  // YENİ: Faturanın yapılandırılmış verisini güncelle
  Future<bool> updateInvoiceStructuredData({
    required String token,
    required String packageId,
    required String invoiceId,
    required Map<String, dynamic> updatedData,
  }) async {
    try {
      final uri = Uri.parse(
          "$_baseUrl/api/packages/$packageId/invoices/$invoiceId/structured");
      final resp = await http
          .put(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(updatedData),
          )
          .timeout(const Duration(seconds: 30));

      return resp.statusCode == 200;
    } catch (e) {
      // Hata durumunda false döndür ve hatayı logla (veya _humanizeError ile işle)
      print('updateInvoiceStructuredData Error: ${e.toString()}');
      return false;
    }
  }

  Future<Map<String, dynamic>> updateInvoiceData(String token, String packageId,
      String invoiceId, Map<String, dynamic> data) async {
    try {
      final uri =
          Uri.parse("$_baseUrl/api/packages/$packageId/invoices/$invoiceId");
      final resp = await http
          .put(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 30));

      if (resp.statusCode != 200) {
        throw Exception(
            _humanizeError('Failed to update invoice: ${resp.reasonPhrase}'));
      }
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception(_humanizeError(e));
    }
  }

  Future<Map<String, dynamic>> approveInvoice(
      String token, String packageId, String invoiceId) async {
    try {
      final uri = Uri.parse(
          "$_baseUrl/api/packages/$packageId/invoices/$invoiceId/approve");
      final resp = await http.post(uri, headers: {
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 30));

      if (resp.statusCode != 200) {
        throw Exception(
            _humanizeError('Failed to approve invoice: ${resp.reasonPhrase}'));
      }
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception(_humanizeError(e));
    }
  }

  Future<Map<String, dynamic>> rejectInvoice(
      String token, String packageId, String invoiceId) async {
    try {
      final uri = Uri.parse(
          "$_baseUrl/api/packages/$packageId/invoices/$invoiceId/reject");
      final resp = await http.post(uri, headers: {
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 30));

      if (resp.statusCode != 200) {
        throw Exception(
            _humanizeError('Failed to reject invoice: ${resp.reasonPhrase}'));
      }
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception(_humanizeError(e));
    }
  }

  // Fatura güncelle
  Future<Map<String, dynamic>> updateInvoice(String token, String invoiceId,
      {bool? isApproved, String? notes}) async {
    try {
      final uri = Uri.parse("$_baseUrl/api/invoice/$invoiceId");
      final body = <String, dynamic>{};

      if (isApproved != null) {
        body['isApproved'] = isApproved;
      }

      if (notes != null) {
        body['notes'] = notes;
      }

      final resp = await http
          .put(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (resp.statusCode != 200) {
        throw Exception(
            _humanizeError('Failed to update invoice: ${resp.reasonPhrase}'));
      }
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception(_humanizeError(e));
    }
  }

  // Fatura istatistiklerini getir
  Future<Map<String, dynamic>> getInvoiceStats(String token) async {
    try {
      final uri = Uri.parse("$_baseUrl/api/invoice/stats");
      final resp = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 30));

      if (resp.statusCode != 200) {
        throw Exception(_humanizeError(
            'Failed to get invoice stats: ${resp.reasonPhrase}'));
      }
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception(_humanizeError(e));
    }
  }

  // Kullanıcı profilini getir
  Future<Map<String, dynamic>> getUserProfile(String token) async {
    try {
      final uri = Uri.parse("$_baseUrl/api/user/profile");
      final resp = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (resp.statusCode != 200) {
        throw Exception(
            _humanizeError('Failed to get user profile: ${resp.reasonPhrase}'));
      }
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception(_humanizeError(e));
    }
  }

  // Kullanıcı profilini güncelle
  Future<Map<String, dynamic>> updateUserProfile(
      String token, Map<String, dynamic> profileData) async {
    try {
      final uri = Uri.parse("$_baseUrl/api/user/profile");
      final resp = await http
          .put(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(profileData),
          )
          .timeout(const Duration(seconds: 30));

      if (resp.statusCode != 200) {
        throw Exception(_humanizeError(
            'Failed to update user profile: ${resp.reasonPhrase}'));
      }
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception(_humanizeError(e));
    }
  }

  // Paket Excel raporu oluştur (Backend'den)
  Future<Uint8List?> generatePackageExcel(
      String token, Map<String, dynamic> packageData) async {
    try {
      final uri = Uri.parse("$_baseUrl/api/reports/excel");
      final resp = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'packageData': packageData,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (resp.statusCode == 200) {
        return resp.bodyBytes;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  // Paket CSV raporu oluştur (Backend'den)
  Future<Uint8List?> generatePackageCsv(
      String token, Map<String, dynamic> packageData) async {
    try {
      final uri = Uri.parse("$_baseUrl/api/reports/csv");
      final resp = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'packageData': packageData,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (resp.statusCode == 200) {
        return resp.bodyBytes;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  // Paket JSON raporu oluştur (Backend'den)
  Future<String?> generatePackageJson(
      String token, Map<String, dynamic> packageData) async {
    try {
      final uri = Uri.parse("$_baseUrl/api/reports/json");
      final resp = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'packageData': packageData,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (resp.statusCode == 200) {
        return resp.body;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  // Tekil Fatura Excel raporu oluştur
  Future<Uint8List?> generateInvoiceExcel(
      String token, Map<String, dynamic> invoiceData) async {
    try {
      final uri = Uri.parse("$_baseUrl/api/reports/invoice/excel");
      final resp = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'invoiceData': invoiceData}),
          )
          .timeout(const Duration(seconds: 60));

      if (resp.statusCode == 200) {
        return resp.bodyBytes;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  // Tekil Fatura CSV raporu oluştur
  Future<Uint8List?> generateInvoiceCsv(
      String token, Map<String, dynamic> invoiceData) async {
    try {
      final uri = Uri.parse("$_baseUrl/api/reports/invoice/csv");
      final resp = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'invoiceData': invoiceData}),
          )
          .timeout(const Duration(seconds: 60));

      if (resp.statusCode == 200) {
        return resp.bodyBytes;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  // Tekil Fatura JSON raporu oluştur
  Future<String?> generateInvoiceJson(
      String token, Map<String, dynamic> invoiceData) async {
    try {
      final uri = Uri.parse("$_baseUrl/api/reports/invoice/json");
      final resp = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'invoiceData': invoiceData}),
          )
          .timeout(const Duration(seconds: 60));

      if (resp.statusCode == 200) {
        return resp.body;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
}
