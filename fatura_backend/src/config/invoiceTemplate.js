const INVOICE_TEMPLATE = {
  // Akıllı Özet Kartı
  odenecek_tutar: '',
  satici_unvani: '',
  fatura_tarihi: null,

  // Veri Ayıklama Yardımcısı
  alici_unvan: '',
  fatura_numarasi: '',
  alici_vkn: '',
  alici_unvan_raw_text: '',

  // Diğer potansiyel alanlar
  siparis_no: '',
  ettn: '',
  satici_vergi_dairesi: '',
  vergi_no: '',
  tc_no: '',
  alici_ad_soyad: '',
  alici_tckn: '',
  alici_adres: '',
  telefon: '',
  email: '',
  iban: '',
  fatura_tipi: '',
  
  // Finansal Özet
  mal_hizmet_toplam_tutari: '',
  ara_toplam: '',
  toplam_kdv: '',
  genel_toplam: '',

  // Ürün Kalemleri
  urun_kalemleri: [],
};

module.exports = {
  INVOICE_TEMPLATE,
};
