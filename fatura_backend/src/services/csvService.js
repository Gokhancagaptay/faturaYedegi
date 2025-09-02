const createCsvWriter = require('csv-writer').createObjectCsvWriter;
const path = require('path');
const fs = require('fs');

class CSVService {
  // Paket CSV raporu oluştur
  static async generatePackageCSV(packageData, outputPath = null) {
    try {
      console.log('🔐 CSVService - Paket CSV raporu oluşturuluyor...');
      
      if (!outputPath) {
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
        outputPath = path.join(__dirname, `../../temp/package_${packageData.id}_${timestamp}.csv`);
      }

      // Temp klasörü yoksa oluştur
      const tempDir = path.dirname(outputPath);
      if (!fs.existsSync(tempDir)) {
        fs.mkdirSync(tempDir, { recursive: true });
      }

      // CSV Writer oluştur
      const csvWriter = createCsvWriter({
        path: outputPath,
        header: [
          { id: 'id', title: 'ID' },
          { id: 'dosyaAdi', title: 'Dosya Adı' },
          { id: 'satici', title: 'Satıcı' },
          { id: 'gercekTutar', title: 'Gerçek Tutar' },
          { id: 'gercekKDV', title: 'Gerçek KDV' },
          { id: 'faturaTarihi', title: 'Fatura Tarihi' },
          { id: 'durum', title: 'Durum' },
          { id: 'faturaNo', title: 'Fatura No' },
          { id: 'yuklemeTarihi', title: 'Yükleme Tarihi' },
          { id: 'islemSuresi', title: 'İşlem Süresi' },
          { id: 'aliciUnvan', title: 'Alıcı Unvan' },
          { id: 'aliciVKN', title: 'Alıcı VKN' },
          { id: 'aliciTelefon', title: 'Alıcı Telefon' },
          { id: 'aliciVergiDairesi', title: 'Alıcı Vergi Dairesi' },
          { id: 'ettn', title: 'ETTN' },
          { id: 'malHizmetToplam', title: 'Mal Hizmet Toplam' },
          { id: 'odenecekTutar', title: 'Ödenecek Tutar' },
          { id: 'vergilerDahilToplam', title: 'Vergiler Dahil Toplam' },
          { id: 'toplamIskonto', title: 'Toplam İskonto' }
        ]
      });

      // Veri hazırla
      const records = [];
      const invoices = packageData.invoices || [];

      invoices.forEach(invoice => {
        const structured = invoice.structured || {};
        
        records.push({
          id: invoice.id || 'N/A',
          dosyaAdi: invoice.originalName || 'N/A',
          satici: invoice.sellerName || 'Bilinmeyen Satıcı',
          gercekTutar: this._extractRealAmount(structured),
          gercekKDV: this._extractRealVAT(structured),
          faturaTarihi: this._formatDate(invoice.invoiceDate),
          durum: invoice.isApproved ? 'Onaylandı' : 'Beklemede',
          faturaNo: this._extractInvoiceNumber(structured),
          yuklemeTarihi: this._formatDate(invoice.uploadedAt),
          islemSuresi: invoice.processingMs || 'N/A',
          aliciUnvan: structured.alici_unvan || '',
          aliciVKN: structured.alici_vkn || '',
          aliciTelefon: structured.alici_tel || '',
          aliciVergiDairesi: structured.alici_vergi_dairesi || '',
          ettn: structured.ettn || '',
          malHizmetToplam: structured.mal_hizmet_toplam_tutari || '',
          odenecekTutar: structured.odenecek_tutar || '',
          vergilerDahilToplam: structured.vergiler_dahil_toplam_tutar || '',
          toplamIskonto: structured.toplam_iskonto || ''
        });
      });

      // CSV yaz
      await csvWriter.writeRecords(records);
      
      console.log(`🔐 CSVService - CSV dosyası oluşturuldu: ${outputPath}`);
      return outputPath;
    } catch (error) {
      console.error('❌ CSVService - CSV oluşturma hatası:', error);
      throw new Error(`CSV raporu oluşturulamadı: ${error.message}`);
    }
  }

  // Ürün kalemleri CSV raporu oluştur
  static async generateProductsCSV(packageData, outputPath = null) {
    try {
      console.log('🔐 CSVService - Ürün kalemleri CSV raporu oluşturuluyor...');
      
      if (!outputPath) {
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
        outputPath = path.join(__dirname, `../../temp/products_${packageData.id}_${timestamp}.csv`);
      }

      // Temp klasörü yoksa oluştur
      const tempDir = path.dirname(outputPath);
      if (!fs.existsSync(tempDir)) {
        fs.mkdirSync(tempDir, { recursive: true });
      }

      // CSV Writer oluştur
      const csvWriter = createCsvWriter({
        path: outputPath,
        header: [
          { id: 'faturaId', title: 'Fatura ID' },
          { id: 'dosyaAdi', title: 'Dosya Adı' },
          { id: 'siraNo', title: 'Sıra No' },
          { id: 'malHizmet', title: 'Mal Hizmet' },
          { id: 'miktar', title: 'Miktar' },
          { id: 'birimFiyat', title: 'Birim Fiyat' },
          { id: 'malHizmetTutari', title: 'Mal Hizmet Tutarı' },
          { id: 'kdvOrani', title: 'KDV Oranı' },
          { id: 'kdvTutari', title: 'KDV Tutarı' },
          { id: 'iskontoOrani', title: 'İskonto Oranı' },
          { id: 'iskontoTutari', title: 'İskonto Tutarı' },
          { id: 'digerVergiler', title: 'Diğer Vergiler' }
        ]
      });

      // Veri hazırla
      const records = [];
      const invoices = packageData.invoices || [];

      invoices.forEach(invoice => {
        const structured = invoice.structured || {};
        const urunKalemleri = structured.urun_kalemleri || [];
        
        urunKalemleri.forEach(urun => {
          records.push({
            faturaId: invoice.id || 'N/A',
            dosyaAdi: invoice.originalName || 'N/A',
            siraNo: urun['sıra no'] || '',
            malHizmet: urun['mal hizmet'] || '',
            miktar: urun['miktar'] || '',
            birimFiyat: urun['birim fiyat'] || '',
            malHizmetTutari: urun['mal hizmet tutarı'] || '',
            kdvOrani: urun['kdv oranı'] || '',
            kdvTutari: urun['kdv tutarı'] || '',
            iskontoOrani: urun['i̇skonto oranı'] || '',
            iskontoTutari: urun['i̇skonto tutarı'] || '',
            digerVergiler: urun['diğer vergiler'] || ''
          });
        });
      });

      // CSV yaz
      await csvWriter.writeRecords(records);
      
      console.log(`🔐 CSVService - Ürün kalemleri CSV dosyası oluşturuldu: ${outputPath}`);
      return outputPath;
    } catch (error) {
      console.error('❌ CSVService - Ürün kalemleri CSV oluşturma hatası:', error);
      throw new Error(`Ürün kalemleri CSV raporu oluşturulamadı: ${error.message}`);
    }
  }

  // Özet CSV raporu oluştur
  static async generateSummaryCSV(packageData, outputPath = null) {
    try {
      console.log('🔐 CSVService - Özet CSV raporu oluşturuluyor...');
      
      if (!outputPath) {
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
        outputPath = path.join(__dirname, `../../temp/summary_${packageData.id}_${timestamp}.csv`);
      }

      // Temp klasörü yoksa oluştur
      const tempDir = path.dirname(outputPath);
      if (!fs.existsSync(tempDir)) {
        fs.mkdirSync(tempDir, { recursive: true });
      }

      // CSV Writer oluştur
      const csvWriter = createCsvWriter({
        path: outputPath,
        header: [
          { id: 'alan', title: 'Alan' },
          { id: 'deger', title: 'Değer' }
        ]
      });

      const invoices = packageData.invoices || [];
      const totalAmount = this._calculateRealTotalAmount(invoices);
      const totalVAT = this._calculateRealTotalVAT(invoices);
      const averageAmount = invoices.length > 0 ? totalAmount / invoices.length : 0;
      const totalProducts = this._calculateTotalProductItems(invoices);

      // Veri hazırla
      const records = [
        { alan: 'Paket ID', deger: packageData.id || 'N/A' },
        { alan: 'Paket Adı', deger: packageData.name || 'N/A' },
        { alan: 'Durum', deger: packageData.status || 'N/A' },
        { alan: 'Toplam Fatura', deger: packageData.totalInvoices || 0 },
        { alan: 'İşlenmiş Fatura', deger: packageData.processedInvoices || 0 },
        { alan: 'Onaylanan Fatura', deger: packageData.approvedInvoices || 0 },
        { alan: 'Hata Sayısı', deger: packageData.errorCount || 0 },
        { alan: 'Toplam Tutar (Gerçek)', deger: totalAmount.toFixed(2) },
        { alan: 'Toplam KDV (Gerçek)', deger: totalVAT.toFixed(2) },
        { alan: 'Ortalama Fatura Tutarı', deger: averageAmount.toFixed(2) },
        { alan: 'Toplam Ürün Kalemi', deger: totalProducts }
      ];

      // CSV yaz
      await csvWriter.writeRecords(records);
      
      console.log(`🔐 CSVService - Özet CSV dosyası oluşturuldu: ${outputPath}`);
      return outputPath;
    } catch (error) {
      console.error('❌ CSVService - Özet CSV oluşturma hatası:', error);
      throw new Error(`Özet CSV raporu oluşturulamadı: ${error.message}`);
    }
  }

  // Tekil Fatura CSV raporu oluştur
  static async generateInvoiceCSV(invoiceData, outputPath = null) {
    try {
      console.log('🔐 CSVService - Tekil Fatura CSV raporu oluşturuluyor...');
      
      if (!outputPath) {
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
        outputPath = path.join(__dirname, `../../temp/invoice_${invoiceData.id}_${timestamp}.csv`);
      }

      const tempDir = path.dirname(outputPath);
      if (!fs.existsSync(tempDir)) {
        fs.mkdirSync(tempDir, { recursive: true });
      }

      const csvWriter = createCsvWriter({
        path: outputPath,
        header: [
          { id: 'alan', title: 'Alan' },
          { id: 'deger', title: 'Değer' }
        ]
      });

      const structured = invoiceData.structured || {};
      const urunKalemleri = structured.urun_kalemleri || [];
      
      const records = [
        { alan: 'ID', deger: invoiceData.id || 'N/A' },
        { alan: 'Dosya Adı', deger: invoiceData.originalName || 'N/A' },
        { alan: 'Durum', deger: invoiceData.isApproved ? 'Onaylandı' : 'Beklemede' },
        { alan: 'Fatura No', deger: this._extractInvoiceNumber(structured) },
        { alan: 'Yükleme Tarihi', deger: this._formatDate(invoiceData.uploadedAt) },
        { alan: 'Son İşlem Tarihi', deger: this._formatDate(invoiceData.lastProcessedAt) },
        { alan: 'İşlem Süresi (ms)', deger: invoiceData.processingMs || 'N/A' },
        { alan: 'Alıcı Unvan', deger: structured.alici_unvan || '' },
        { alan: 'Alıcı VKN', deger: structured.alici_vkn || '' },
        { alan: 'Alıcı Telefon', deger: structured.alici_tel || '' },
        { alan: 'Alıcı Vergi Dairesi', deger: structured.alici_vergi_dairesi || '' },
        { alan: 'ETTN', deger: structured.ettn || '' },
        { alan: 'Mal Hizmet Toplam', deger: structured.mal_hizmet_toplam_tutari || '' },
        { alan: 'Toplam İskonto', deger: structured.toplam_iskonto || '' },
        { alan: 'Ödenecek Tutar', deger: structured.odenecek_tutar || '' },
        { alan: 'Vergiler Dahil Toplam', deger: structured.vergiler_dahil_toplam_tutar || '' },
        { alan: 'Toplam KDV (Hesaplanan)', deger: this._extractRealVAT(structured).toFixed(2) }
      ];

      records.push({alan: '---', deger: '---'});
      records.push({alan: 'ÜRÜN KALEMLERİ', deger: `(${urunKalemleri.length} adet)`});
      
      urunKalemleri.forEach((urun, index) => {
          records.push({ alan: `Ürün ${index + 1} - Sıra No`, deger: urun['sıra no'] || ''});
          records.push({ alan: `Ürün ${index + 1} - Mal/Hizmet`, deger: (urun['mal hizmet'] || '').replace(/\n/g, ' ')});
          records.push({ alan: `Ürün ${index + 1} - Miktar`, deger: urun['miktar'] || ''});
          records.push({ alan: `Ürün ${index + 1} - Birim Fiyat`, deger: urun['birim fiyat'] || ''});
          records.push({ alan: `Ürün ${index + 1} - Tutar`, deger: urun['mal hizmet tutarı'] || ''});
          records.push({ alan: `Ürün ${index + 1} - KDV Oranı`, deger: urun['kdv oranı'] || ''});
          records.push({ alan: `Ürün ${index + 1} - KDV Tutarı`, deger: urun['kdv tutarı'] || ''});
      });

      await csvWriter.writeRecords(records);
      
      console.log(`🔐 CSVService - CSV dosyası oluşturuldu: ${outputPath}`);
      return outputPath;
    } catch (error) {
      console.error('❌ CSVService - Tekil Fatura CSV oluşturma hatası:', error);
      throw new Error(`Tekil CSV raporu oluşturulamadı: ${error.message}`);
    }
  }

  // Yardımcı metodlar
  static _extractRealAmount(structured) {
    try {
      if (!structured) return 0;
      if (structured.odenecek_tutar) {
        const value = structured.odenecek_tutar;
        if (typeof value === 'string') {
          return parseFloat(value.replace(' TL', '').replace(',', '.')) || 0;
        }
        return parseFloat(value) || 0;
      }
      
      if (structured.mal_hizmet_toplam_tutari) {
        const value = structured.mal_hizmet_toplam_tutari;
        if (typeof value === 'string') {
          return parseFloat(value.replace(' TL', '').replace(',', '.')) || 0;
        }
        return parseFloat(value) || 0;
      }
      
      return 0;
    } catch (e) {
      console.error('❌ Gerçek tutar çıkarılamadı:', structured, e);
      return 0;
    }
  }

  static _extractRealVAT(structured) {
    try {
      if (!structured || !structured.urun_kalemleri || !Array.isArray(structured.urun_kalemleri)) {
        return 0;
      }
      
      let totalVAT = 0;
      structured.urun_kalemleri.forEach(urun => {
        if (urun && urun['kdv tutarı']) {
          const kdvValue = urun['kdv tutarı'];
          if (typeof kdvValue === 'string') {
            const kdvAmount = parseFloat(kdvValue.replace(' TL', '').replace(',', '.')) || 0;
            totalVAT += kdvAmount;
          } else if (typeof kdvValue === 'number') {
            totalVAT += kdvValue;
          }
        }
      });
      return totalVAT;
    } catch (e) {
      console.error('❌ Gerçek KDV çıkarılamadı:', structured, e);
      return 0;
    }
  }

  static _extractInvoiceNumber(structured) {
    try {
      if (!structured || !structured.alici_unvan) {
        return 'N/A';
      }
      const unvan = structured.alici_unvan;
      if (typeof unvan !== 'string') return 'N/A';
      const match = unvan.match(/Fatura No: ([^\s]+)/);
      if (match && match[1]) {
        return match[1];
      }
      return 'N/A';
    } catch (e) {
      console.error('❌ Fatura numarası çıkarılamadı:', structured, e);
      return 'N/A';
    }
  }

  static _calculateRealTotalAmount(invoices) {
    return invoices.reduce((sum, invoice) => {
      const structured = invoice.structured || {};
      return sum + this._extractRealAmount(structured);
    }, 0);
  }

  static _calculateRealTotalVAT(invoices) {
    return invoices.reduce((sum, invoice) => {
      const structured = invoice.structured || {};
      return sum + this._extractRealVAT(structured);
    }, 0);
  }

  static _calculateTotalProductItems(invoices) {
    return invoices.reduce((sum, invoice) => {
      const structured = invoice.structured || {};
      const urunKalemleri = structured.urun_kalemleri || [];
      return sum + urunKalemleri.length;
    }, 0);
  }

  static _formatDate(timestamp) {
    if (!timestamp) return 'N/A';
    
    try {
      let date;
      if (timestamp._seconds) {
        date = new Date(timestamp._seconds * 1000);
      } else if (typeof timestamp === 'string' || typeof timestamp === 'number') {
        date = new Date(timestamp);
      } else {
        return 'N/A';
      }
      
      if (isNaN(date.getTime())) {
        return 'N/A';
      }

      return date.toLocaleDateString('tr-TR', {
        year: 'numeric',
        month: '2-digit',
        day: '2-digit'
      });
    } catch (e) {
      console.error('❌ Tarih formatlanamadı:', timestamp, e);
      return 'N/A';
    }
  }
}

module.exports = CSVService;
