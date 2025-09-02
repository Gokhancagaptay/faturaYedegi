import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:fatura_yeni/core/services/api_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

// Web için eklenen import
import 'package:fatura_yeni/core/services/web_helpers_stub.dart'
    if (dart.library.html) 'package:fatura_yeni/core/services/web_helpers.dart';

/// Raporlama işlemlerini yöneten servis.
/// Bu servis, tüm raporları (JSON, CSV, Excel) backend'den talep eder
/// ve gelen dosyayı mobil cihaza kaydeder/paylaşır.
class ReportService {
  static final ApiService _apiService = ApiService();

  /// Backend'den bir paket için JSON raporu talep eder.
  static Future<String?> generatePackageJsonReport(
      String token, Map<String, dynamic> packageData) async {
    try {
      final jsonString =
          await _apiService.generatePackageJson(token, packageData);
      if (jsonString != null) {
        return jsonString;
      }
      throw Exception('Backend\'den JSON raporu alınamadı.');
    } catch (e) {
      print('❌ ReportService - JSON raporu oluşturma hatası: $e');
      throw Exception('JSON raporu oluşturulamadı: $e');
    }
  }

  /// Backend'den bir paket için CSV raporu talep eder.
  static Future<String?> generatePackageCSVReport(
      String token, Map<String, dynamic> packageData) async {
    try {
      final csvBytes = await _apiService.generatePackageCsv(token, packageData);
      if (csvBytes != null) {
        return utf8.decode(csvBytes);
      }
      throw Exception('Backend\'den CSV raporu alınamadı.');
    } catch (e) {
      print('❌ ReportService - CSV raporu oluşturma hatası: $e');
      throw Exception('CSV raporu oluşturulamadı: $e');
    }
  }

  /// Backend'den bir paket için Excel raporu talep eder.
  static Future<Uint8List> generatePackageExcelReport(
      String token, Map<String, dynamic> packageData) async {
    try {
      final response =
          await _apiService.generatePackageExcel(token, packageData);
      if (response != null) {
        return response;
      }
      throw Exception('Backend\'den Excel raporu alınamadı.');
    } catch (e) {
      print('❌ ReportService - Backend Excel raporu hatası: $e');
      throw Exception('Excel raporu oluşturulamadı: $e');
    }
  }

  // --- Tekil Fatura Raporları ---

  /// Backend'den tekil bir fatura için JSON raporu talep eder.
  static Future<String?> generateInvoiceJsonReport(
      String token, Map<String, dynamic> invoiceData) async {
    try {
      final jsonString =
          await _apiService.generateInvoiceJson(token, invoiceData);
      if (jsonString != null) {
        return jsonString;
      }
      throw Exception('Backend\'den tekil JSON raporu alınamadı.');
    } catch (e) {
      print('❌ ReportService - Tekil JSON raporu oluşturma hatası: $e');
      throw Exception('Tekil JSON raporu oluşturulamadı: $e');
    }
  }

  /// Backend'den tekil bir fatura için CSV raporu talep eder.
  static Future<String?> generateInvoiceCSVReport(
      String token, Map<String, dynamic> invoiceData) async {
    try {
      final csvBytes = await _apiService.generateInvoiceCsv(token, invoiceData);
      if (csvBytes != null) {
        return utf8.decode(csvBytes);
      }
      throw Exception('Backend\'den tekil CSV raporu alınamadı.');
    } catch (e) {
      print('❌ ReportService - Tekil CSV raporu oluşturma hatası: $e');
      throw Exception('Tekil CSV raporu oluşturulamadı: $e');
    }
  }

  /// Backend'den tekil bir fatura için Excel raporu talep eder.
  static Future<Uint8List> generateInvoiceExcelReport(
      String token, Map<String, dynamic> invoiceData) async {
    try {
      final response =
          await _apiService.generateInvoiceExcel(token, invoiceData);
      if (response != null) {
        return response;
      }
      throw Exception('Backend\'den tekil Excel raporu alınamadı.');
    } catch (e) {
      print('❌ ReportService - Tekil Excel raporu hatası: $e');
      throw Exception('Tekil Excel raporu oluşturulamadı: $e');
    }
  }

  // --- Dosya Kaydetme ve Paylaşma Metodları ---

  /// Gelen metin tabanlı veriyi (JSON, CSV) bir dosyaya kaydeder ve paylaşım/indirme menüsünü açar.
  static Future<void> saveAndShareReport(
      String data, String fileName, BuildContext context,
      {String mimeType = 'text/plain'}) async {
    try {
      print('🔐 ReportService - saveAndShareReport BAŞLADI');
      print('🔐 ReportService - Dosya adı: $fileName');
      print('🔐 ReportService - MIME type: $mimeType');
      print('🔐 ReportService - Platform: ${kIsWeb ? 'Web' : 'Mobile'}');

      if (kIsWeb) {
        // Web platformu için indirme mantığı
        final bytes = utf8.encode(data);
        downloadFile(fileName, bytes, mimeType);
        print(
            '🔐 ReportService - Web için dosya indirme tetiklendi: $fileName');
        return;
      }

      final status = await requestStoragePermission(context);
      if (!status.isGranted) {
        print('❌ İzin reddedildi, dosya kaydedilemedi');
        return;
      }

      final directory = await _getDownloadPath();
      if (directory == null) {
        print('❌ İndirme dizini bulunamadı.');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Dosyayı kaydetmek için uygun bir dizin bulunamadı.')),
          );
        }
        return;
      }

      final file = File('${directory.path}/$fileName');
      await file.writeAsString(data);
      print('🔐 ReportService - Dosya kaydedildi: ${file.path}');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rapor kaydedildi: ${file.path}'),
            action: SnackBarAction(
              label: 'Dosyayı Aç',
              onPressed: () {
                OpenFile.open(file.path);
              },
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ ReportService - Dosya kaydetme/paylaşma hatası: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dosya kaydedilemedi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Gelen byte verisini (Excel) bir dosyaya kaydeder ve paylaşım/indirme menüsünü açar.
  static Future<void> saveExcelReport(
      Uint8List excelData, String fileName, BuildContext context) async {
    try {
      if (kIsWeb) {
        // Web platformu için Excel indirme mantığı
        downloadFile(fileName, excelData,
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        print(
            '🔐 ReportService - Web için Excel indirme tetiklendi: $fileName');
        return;
      }

      final status = await requestStoragePermission(context);
      if (!status.isGranted) {
        print('❌ İzin reddedildi, dosya kaydedilemedi');
        return;
      }

      final directory = await _getDownloadPath();
      if (directory == null) {
        print('❌ İndirme dizini bulunamadı.');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Dosyayı kaydetmek için uygun bir dizin bulunamadı.')),
          );
        }
        return;
      }

      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(excelData);
      print('🔐 ReportService - Excel dosyası kaydedildi: ${file.path}');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Excel raporu kaydedildi: ${file.path}'),
            action: SnackBarAction(
              label: 'Dosyayı Aç',
              onPressed: () {
                OpenFile.open(file.path);
              },
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ ReportService - Excel kaydetme hatası: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Excel dosyası kaydedilemedi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Mobil cihazda depolama izni ister.
  static Future<PermissionStatus> requestStoragePermission(
      BuildContext context) async {
    try {
      if (kIsWeb) {
        return PermissionStatus.granted;
      }

      Permission permission;
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        if (androidInfo.version.sdkInt >= 33) {
          // Android 13+
          permission = Permission.photos; // Veya .videos, .audio
        } else {
          permission = Permission.storage;
        }
      } else {
        return PermissionStatus.granted; // Diğer platformlar için
      }

      final status = await permission.status;
      if (status.isGranted) {
        return PermissionStatus.granted;
      }

      final newStatus = await permission.request();
      if (newStatus.isGranted) {
        return PermissionStatus.granted;
      }

      if (newStatus.isPermanentlyDenied) {
        if (context.mounted) {
          await _showPermissionDialog(context);
        }
      }

      return newStatus;
    } catch (e) {
      print('🔐 ReportService - requestStoragePermission hatası: $e');
      return PermissionStatus.denied;
    }
  }

  /// İndirme yapılacak dizini platforma göre belirler.
  static Future<Directory?> _getDownloadPath() async {
    if (Platform.isAndroid) {
      // Android'de genel 'Download' klasörünü dener
      final downloadDir = Directory('/storage/emulated/0/Download');
      if (await downloadDir.exists()) {
        return downloadDir;
      }
    }
    // Genel çözüm (uygulamaya özel dizin)
    return getApplicationDocumentsDirectory();
  }

  /// Kalıcı olarak reddedilen izinler için kullanıcıyı ayarlara yönlendiren diyalog.
  static Future<void> _showPermissionDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('İzin Gerekli'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                    'Raporları kaydetmek için depolama izni vermeniz gerekiyor.'),
                Text('Lütfen uygulama ayarlarından bu izni etkinleştirin.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('İptal'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Ayarları Aç'),
              onPressed: () {
                openAppSettings();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
