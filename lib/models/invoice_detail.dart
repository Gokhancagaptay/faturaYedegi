import 'dart:convert';

class InvoiceDetail {
  final String originalName;
  final String fileUrl;
  final String thumbnailUrl;
  final StructuredInvoice structured;

  InvoiceDetail({
    required this.originalName,
    required this.fileUrl,
    required this.thumbnailUrl,
    required this.structured,
  });

  factory InvoiceDetail.fromJson(Map<String, dynamic> json) {
    return InvoiceDetail(
      originalName: json['originalName'] ?? 'N/A',
      fileUrl: json['fileUrl'] ?? '',
      thumbnailUrl: json['thumbnailUrl'] ?? '',
      structured: StructuredInvoice.fromJson(json['structured'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'originalName': originalName,
        'fileUrl': fileUrl,
        'thumbnailUrl': thumbnailUrl,
        'structured': structured.toJson(),
      };
}

class StructuredInvoice {
  String? odenecekTutar;
  String? saticiUnvani;
  String? faturaTarihi;
  String? faturaNumarasi;
  final String aliciUnvan; // Ham veri için
  final List<UrunKalemi> urunKalemleri;
  final Map<String, dynamic> otherFields; // Diğer tüm alanlar için
  bool isApproved = false;
  String? status;
  String? rawText;

  StructuredInvoice(
      {this.odenecekTutar,
      this.saticiUnvani,
      this.faturaTarihi,
      this.faturaNumarasi,
      required this.aliciUnvan,
      required this.urunKalemleri,
      required this.otherFields,
      this.isApproved = false,
      this.status,
      this.rawText});

  bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) {
      if (value.toLowerCase() == 'true') return true;
      if (value.toLowerCase() == 'false') return false;
    }
    // Varsayılan olarak veya tanınmayan bir tip için false döndür
    return false;
  }

  factory StructuredInvoice.fromJson(Map<String, dynamic> json) {
    bool localIsApproved = false;
    if (json['is_approved'] is bool) {
      localIsApproved = json['is_approved'];
    } else if (json['is_approved'] is String) {
      localIsApproved = json['is_approved'].toLowerCase() == 'true';
    }

    final Map<String, dynamic> structuredData = Map.from(json);

    // Bilinen ve özel olarak işlenen alanları ayıkla
    final odenecekTutar = structuredData.remove('odenecek_tutar')?.toString();
    final saticiUnvani = structuredData.remove('satici_unvani')?.toString();
    final faturaTarihi = structuredData.remove('fatura_tarihi')?.toString();
    final faturaNumarasi = structuredData.remove('fatura_numarasi')?.toString();
    final aliciUnvan =
        structuredData.remove('alici_unvan')?.toString() ?? 'N/A';
    final urunKalemleriList =
        (structuredData.remove('urun_kalemleri') as List? ?? [])
            .map((i) => UrunKalemi.fromJson(i))
            .toList();

    // Geriye kalanlar otherFields'a atanır
    final otherFieldsMap = structuredData;

    return StructuredInvoice(
      odenecekTutar: odenecekTutar,
      saticiUnvani: saticiUnvani,
      faturaTarihi: faturaTarihi,
      faturaNumarasi: faturaNumarasi,
      aliciUnvan: aliciUnvan,
      urunKalemleri: urunKalemleriList,
      otherFields: otherFieldsMap,
      isApproved: localIsApproved,
      status: json['status'],
      rawText: json['raw_text'],
    );
  }

  Map<String, dynamic> toJson() => {
        'odenecek_tutar': odenecekTutar,
        'satici_unvani': saticiUnvani,
        'fatura_tarihi': faturaTarihi,
        'fatura_numarasi': faturaNumarasi,
        'alici_unvan': aliciUnvan,
        'urun_kalemleri': urunKalemleri.map((i) => i.toJson()).toList(),
        'isApproved': isApproved,
        'status': status,
        'raw_text': rawText,
        ...otherFields,
      };
}

class UrunKalemi {
  String malHizmet;
  Map<String, dynamic> fields;
  String? siraNo;

  UrunKalemi({required this.malHizmet, required this.fields, this.siraNo});

  factory UrunKalemi.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> otherFields = Map.from(json);
    final String malHizmet = otherFields.remove('mal_hizmet')?.toString() ?? '';
    final String? siraNo = otherFields.remove('sıra no')?.toString();
    return UrunKalemi(
        malHizmet: malHizmet, fields: otherFields, siraNo: siraNo);
  }

  Map<String, dynamic> toJson() => {
        'mal_hizmet': malHizmet,
        'sıra no': siraNo,
        ...fields,
      };

  String get displayName {
    if (malHizmet.isNotEmpty && malHizmet != 'N/A') {
      return malHizmet;
    }
    if (siraNo != null && siraNo!.isNotEmpty) {
      return '$siraNo. Kalem';
    }
    return 'İsimsiz Kalem'; // Fallback
  }
}
