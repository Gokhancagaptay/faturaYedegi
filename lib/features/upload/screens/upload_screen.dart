import 'package:fatura_yeni/core/services/api_service.dart';
import 'package:fatura_yeni/core/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_dropzone/flutter_dropzone.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  late DropzoneViewController controller;
  bool _isHovering = false;
  final List<PlatformFile> _files = [];
  bool _isUploading = false;
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dosya Yükle ve Paket Oluştur'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDropzone(),
            const SizedBox(height: 24),
            _buildSelectedFilesList(),
            const SizedBox(height: 24),
            _buildUploadButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildDropzone() {
    final colorScheme = Theme.of(context).colorScheme;
    final dropzoneColor =
        _isHovering ? colorScheme.primary : Colors.grey.shade400;

    return GestureDetector(
      onTap: _pickFiles,
      child: Container(
        // Using a standard container instead of DottedBorder for now
        decoration: BoxDecoration(
          border: Border.all(
            color: dropzoneColor,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          height: 200,
          decoration: BoxDecoration(
            color: _isHovering
                ? colorScheme.primary.withAlpha(25)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              DropzoneView(
                operation: DragOperation.copy,
                cursor: CursorType.grab,
                onCreated: (ctrl) => controller = ctrl,
                onHover: () => setState(() => _isHovering = true),
                onLeave: () => setState(() => _isHovering = false),
                onDropFiles: _handleDroppedFiles, // Use the new typed callback
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 64,
                      color: dropzoneColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Dosyaları buraya sürükleyin veya seçmek için tıklayın',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: dropzoneColor, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Desteklenen formatlar: PDF, JPG, PNG',
                      style:
                          TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedFilesList() {
    if (_files.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Seçilen Dosyalar (${_files.length})',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _files.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final file = _files[index];
            return Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.insert_drive_file_outlined),
                title: Text(file.name, overflow: TextOverflow.ellipsis),
                subtitle: Text('${(file.size / 1024).toStringAsFixed(2)} KB'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _files.removeAt(index);
                    });
                  },
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildUploadButton() {
    return Container(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        icon: _isUploading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : const Icon(Icons.analytics_outlined, size: 24),
        label: Text(
          _isUploading
              ? 'Paket Oluşturuluyor...'
              : 'Analiz Et ve Paket Oluştur',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        onPressed: _files.isEmpty || _isUploading ? null : _createPackage,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              _isUploading ? Colors.grey[400] : Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          elevation: _isUploading ? 0 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      allowMultiple: true,
      withData: true,
    );
    if (result != null) {
      setState(() {
        _files.addAll(result.files);
      });
    }
  }

  Future<void> _handleDroppedFiles(List<dynamic>? files) async {
    if (files == null || files.isEmpty) return;

    final List<PlatformFile> acceptedFiles = [];
    int unsupportedFiles = 0;

    for (final file in files) {
      try {
        final mime = await controller.getFileMIME(file);
        if (['application/pdf', 'image/jpeg', 'image/png'].contains(mime)) {
          final bytes = await controller.getFileData(file);
          final name = await controller.getFilename(file);
          final size = await controller.getFileSize(file);

          acceptedFiles.add(PlatformFile(
            name: name,
            bytes: bytes,
            size: size,
          ));
        } else {
          unsupportedFiles++;
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Dosya okunurken bir hata oluştu: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    setState(() {
      _files.addAll(acceptedFiles);
      _isHovering = false;
    });

    if (unsupportedFiles > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '$unsupportedFiles adet dosya desteklenmeyen formatta olduğu için eklenmedi.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _createPackage() async {
    if (!mounted) return;

    setState(() {
      _isUploading = true;
    });

    try {
      // İlk feedback: Token kontrolü
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paket oluşturuluyor...'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 1),
          ),
        );
      }

      // Token kontrolü
      final token = await _storageService.getToken();
      if (token == null) {
        throw Exception('Oturum hatası. Lütfen tekrar giriş yapın.');
      }

      // API çağrısı
      final response = await _apiService.createPackage(_files, token);

      if (mounted) {
        if (response['success'] == true) {
          // Başarı mesajını göster
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(response['message'] ??
                        'Paket başarıyla oluşturuldu ve işleniyor.'),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );

          // Paket oluşturuldu, aynı ekranda kal
          // Dosya listesini temizle
          setState(() {
            _files.clear();
          });
        } else {
          throw Exception(response['message'] ?? 'Bilinmeyen bir hata oluştu.');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Paket oluşturulamadı: $e'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Tekrar Dene',
              textColor: Colors.white,
              onPressed: () {
                if (!_isUploading) {
                  _createPackage();
                }
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }
}
