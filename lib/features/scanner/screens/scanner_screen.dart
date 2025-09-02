// lib/features/scanner/screens/scanner_screen.dart

import 'dart:io';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fatura_yeni/constants/app_constants.dart';
import 'package:fatura_yeni/providers/file_provider.dart';
import 'package:fatura_yeni/core/services/api_service.dart';
import 'package:fatura_yeni/core/services/storage_service.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  bool _isLoading = false;
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();

  Future<void> _scanDocument() async {
    try {
      // cunning_document_scanner paketini kullanarak tarayıcıyı aç
      List<String> pictures = await CunningDocumentScanner.getPictures() ?? [];

      if (pictures.isNotEmpty) {
        // Taranan ilk dosyayı al (genellikle tek sayfa taranır)
        final path = pictures.first;
        final file = File(path);

        // Dosya bilgilerini al
        final fileName = file.path.split('/').last;
        final bytes = await file.readAsBytes();

        // PlatformFile'a dönüştür
        PlatformFile platformFile = PlatformFile(
          name: fileName,
          bytes: bytes,
          size: bytes.length,
          path: path,
        );

        // Dosyayı provider'a ekle
        ref.read(fileProvider.notifier).addFile(platformFile);

        // Backend'e gönder ve paket oluştur
        await _processScannedFile(platformFile);
      } else {
        // Kullanıcı taramayı iptal ederse ana ekrana dön
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      // Hata yönetimi
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Belge taranırken bir hata oluştu: $e')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _processScannedFile(PlatformFile file) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final token = await _storageService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found.');
      }

      // Taranan dosyayı backend'e gönder ve paket oluştur
      final response = await _apiService.createPackage([file], token);

      if (mounted) {
        if (response['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Belge başarıyla taranıp işlendi.'),
              backgroundColor: Colors.green,
            ),
          );
          // Başarılı olunca ana ekrana dön
          Navigator.of(context).pop(true);
        } else {
          throw Exception(
            response['message'] ?? 'Belge işlenirken bir hata oluştu.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Ekran açılır açılmaz tarayıcıyı başlat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scanDocument();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Belge Tara'),
      ),
      body: Center(
        child: _isLoading
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Belge taranıyor ve işleniyor...'),
                ],
              )
            : const Text('Tarayıcı başlatılıyor...'),
      ),
    );
  }
}
