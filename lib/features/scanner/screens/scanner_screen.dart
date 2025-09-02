// lib/features/scanner/screens/scanner_screen.dart

import 'dart:io';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fatura_yeni/constants/app_constants.dart';
import 'package:fatura_yeni/providers/file_provider.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  bool _isLoading = false;

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

        // Başarılı tarama sonrası ana ekrana dön
        if (mounted) {
          Navigator.of(context).pop(true);
        }
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
