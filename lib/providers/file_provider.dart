import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Bu provider, seçilen/taranan dosyaların listesini yönetir.
final fileProvider =
    StateNotifierProvider<FileNotifier, List<PlatformFile>>((ref) {
  return FileNotifier();
});

class FileNotifier extends StateNotifier<List<PlatformFile>> {
  FileNotifier() : super([]);

  // Listeye yeni bir dosya ekler
  void addFile(PlatformFile file) {
    state = [...state, file];
  }

  // Belirtilen indeksteki dosyayı listeden kaldırır
  void removeFile(int index) {
    state = [
      for (int i = 0; i < state.length; i++)
        if (i != index) state[i],
    ];
  }

  // Tüm dosya listesini temizler
  void clearFiles() {
    state = [];
  }
}
