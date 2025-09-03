// lib/features/dashboard/models/invoice_model.dart

class Invoice {
  final String id;
  final String sellerName;
  final DateTime date;
  final double totalAmount;
  final String? status;
  final String? fileName;
  final String? fileUrl;
  final String? thumbnailUrl;
  final DateTime? uploadedAt;
  final DateTime? lastProcessedAt;
  final bool? isApproved;
  final DateTime? approvedAt;
  final String? approvedBy;
  final String? packageId; // Paket ID'si eklendi

  Invoice({
    required this.id,
    required this.sellerName,
    required this.date,
    required this.totalAmount,
    this.status,
    this.fileName,
    this.fileUrl,
    this.thumbnailUrl,
    this.uploadedAt,
    this.lastProcessedAt,
    this.isApproved,
    this.approvedAt,
    this.approvedBy,
    this.packageId,
  });

  // JSON'dan Invoice nesnesine dönüştürme
  factory Invoice.fromJson(Map<String, dynamic> json) {
    final structuredData = json['structured'] as Map<String, dynamic>? ?? {};
    final fileName = json['originalName'] as String? ?? '';
    final isPdf = fileName.toLowerCase().endsWith('.pdf');

    return Invoice(
      id: json['id'] as String? ?? '',
      sellerName: _extractSellerName(structuredData, fileName, isPdf),
      date: _extractInvoiceDate(structuredData, json, fileName, isPdf),
      totalAmount: _extractTotalAmount(structuredData, fileName, isPdf),
      status: json['status'] as String?,
      fileName: fileName,
      fileUrl: json['fileUrl'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      uploadedAt: _parseDate(json['uploadedAt']),
      lastProcessedAt: _parseDate(json['lastProcessedAt']),
      isApproved: json['isApproved'] as bool?,
      approvedAt: _parseDate(json['approvedAt']),
      approvedBy: json['approvedBy'] as String?,
      packageId: json['packageId'] as String?,
    );
  }

  // --- Yardımcı Metodlar ---

  static String _extractSellerName(
      Map<String, dynamic> structuredData, String fileName, bool isPdf) {
    // Birden fazla olası anahtarı kontrol et
    final keys = ['satici_unvan', 'satici_ad_soyad', 'alici_unvan'];
    String rawName = '';

    for (var key in keys) {
      if (structuredData.containsKey(key) && structuredData[key] is String) {
        rawName = structuredData[key];
        break;
      }
    }

    // Eğer structured data yoksa veya boşsa, dosya adından çıkarmaya çalış
    if (rawName.isEmpty && isPdf) {
      // PDF dosya adından satıcı adını çıkarmaya çalış
      final parts = fileName.split('-');
      if (parts.length > 1) {
        rawName = parts[1].trim();
      }
    }

    if (rawName.isEmpty) {
      return isPdf ? 'PDF Fatura' : 'Bilinmeyen Satıcı';
    }

    final cleanName = rawName.split('Fatura Tipi:').first.trim();
    if (cleanName.isEmpty) {
      return isPdf ? 'PDF Fatura' : 'Bilinmeyen Satıcı';
    }
    return cleanName;
  }

  static double _extractTotalAmount(
      Map<String, dynamic> structuredData, String fileName, bool isPdf) {
    // Birden fazla olası anahtarı kontrol et
    final keys = ['odenecek_tutar', 'toplam_tutar', 'genel_toplam'];
    String amountString = '0.0';

    for (var key in keys) {
      if (structuredData.containsKey(key) && structuredData[key] is String) {
        amountString = structuredData[key];
        break;
      }
    }

    // Eğer structured data yoksa ve PDF ise, 0.0 döndür (henüz işlenmemiş)
    if (amountString == '0.0' && isPdf && structuredData.isEmpty) {
      return 0.0;
    }

    try {
      // Para birimi simgelerini ve binlik ayırıcıları temizle
      return double.parse(amountString
          .replaceAll('TL', '')
          .replaceAll('₺', '')
          .trim()
          .replaceAll('.', '')
          .replaceAll(',', '.'));
    } catch (e) {
      return 0.0;
    }
  }

  static DateTime _extractInvoiceDate(Map<String, dynamic> structuredData,
      Map<String, dynamic> invoice, String fileName, bool isPdf) {
    // Structured datadan almayı dene
    final dateKeys = ['fatura_tarihi', 'duzenlenme_tarihi'];
    for (var key in dateKeys) {
      if (structuredData.containsKey(key) && structuredData[key] is String) {
        final dateStr = structuredData[key];
        // "DD.MM.YYYY" veya "DD-MM-YYYY" formatlarını dene
        try {
          final parts = dateStr.replaceAll('.', '-').split('-');
          if (parts.length == 3) {
            final parsedDate =
                DateTime.tryParse('${parts[2]}-${parts[1]}-${parts[0]}');
            if (parsedDate != null) return parsedDate;
          }
        } catch (_) {}
      }
    }

    // Eğer structured data yoksa ve PDF ise, dosya adından tarih çıkarmaya çalış
    if (isPdf && structuredData.isEmpty) {
      final match = RegExp(r'(\d{2}[-.]\d{2}[-.]\d{4})').firstMatch(fileName);
      if (match != null && match.groupCount > 0) {
        final dateStr = match.group(1)!;
        try {
          final parts = dateStr.replaceAll('.', '-').split('-');
          if (parts.length == 3) {
            final parsedDate =
                DateTime.tryParse('${parts[2]}-${parts[1]}-${parts[0]}');
            if (parsedDate != null) return parsedDate;
          }
        } catch (_) {}
      }
    }

    // Başka bir yerden almayı dene (regex)
    final textDataSource = structuredData['alici_unvan'] as String? ?? '';
    final match =
        RegExp(r'(\d{2}[-.]\d{2}[-.]\d{4})').firstMatch(textDataSource);
    if (match != null && match.groupCount > 0) {
      final dateStr = match.group(1)!;
      try {
        final parts = dateStr.replaceAll('.', '-').split('-');
        if (parts.length == 3) {
          final parsedDate =
              DateTime.tryParse('${parts[2]}-${parts[1]}-${parts[0]}');
          if (parsedDate != null) return parsedDate;
        }
      } catch (_) {}
    }
    // Son çare olarak yükleme tarihini kullan
    return _parseDate(invoice['uploadedAt']) ?? DateTime.now();
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    try {
      if (v is String) return DateTime.tryParse(v);
      if (v is Map && v['_seconds'] != null) {
        // Firestore Timestamp formatı
        final seconds = (v['_seconds'] as num).toInt();
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      }
      if (v is Map && v['seconds'] != null) {
        // Firestore Timestamp (eski format)
        final seconds = (v['seconds'] as num).toInt();
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      }
    } catch (_) {}
    return null;
  }
}
