import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fatura_yeni/core/services/api_service.dart';
import 'package:fatura_yeni/core/services/storage_service.dart';
import 'package:provider/provider.dart';
import 'package:fatura_yeni/core/providers/theme_provider.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  ScanScreenState createState() => ScanScreenState();
}

class ScanScreenState extends State<ScanScreen> {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  bool _isLoading = false;

  Future<void> _processFiles(List<PlatformFile> files) async {
    if (files.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final token = await _storageService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found.');
      }

      await _apiService.createPackage(files, token);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paket oluşturuldu ve işleniyor.'),
          backgroundColor: Colors.green,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null && result.files.isNotEmpty) {
        await _processFiles(result.files);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dosya seçme hatası: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final colors = _getColors(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Fatura Tara', style: TextStyle(color: colors['text'])),
        backgroundColor: colors['surface'],
        elevation: 0,
        iconTheme: IconThemeData(color: colors['text']),
      ),
      backgroundColor: colors['background'],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.document_scanner_outlined,
                      size: 100,
                      color: colors['primary'],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Faturalarınızı Yükleyin',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: colors['text'],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'PDF, JPG veya PNG formatındaki faturalarınızı seçerek yükleyebilirsiniz.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: colors['textSecondary'],
                      ),
                    ),
                    const SizedBox(height: 48),
                    ElevatedButton.icon(
                      onPressed: _pickAndUploadFiles,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Dosya Seç'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors['primary'],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Map<String, dynamic> _getColors(BuildContext context) {
    final theme = Theme.of(context);
    return {
      'primary': theme.primaryColor,
      'background': theme.scaffoldBackgroundColor,
      'surface': theme.cardColor,
      'text': theme.textTheme.bodyLarge!.color,
      'textSecondary': theme.textTheme.bodyMedium!.color,
    };
  }
}
