const ExcelJS = require('exceljs');

class ExcelService {
  // Paket Excel raporu oluştur
  static async generatePackageExcel(packageData) {
    try {
      console.log('🔐 ExcelService - Paket Excel raporu oluşturuluyor...');
      if (!packageData || !Array.isArray(packageData.invoices)) {
        console.error('❌ ExcelService - Geçersiz packageData:', packageData);
        throw new Error('Paket verisi veya faturalar eksik/geçersiz.');
      }
      
      const workbook = new ExcelJS.Workbook();
      workbook.creator = 'Fatura Yeni';
      workbook.lastModifiedBy = 'Fatura Yeni';
      workbook.created = new Date();
      workbook.modified = new Date();

      // 1. Paket Bilgileri Sayfası
      const packageSheet = workbook.addWorksheet('Paket Bilgileri');
      this._addPackageInfoSheet(packageSheet, packageData);

      // 2. Fatura Detayları Sayfası
      const invoicesSheet = workbook.addWorksheet('Fatura Detayları');
      this._addInvoicesSheet(invoicesSheet, packageData.invoices || []);

      // 3. Özet Sayfası
      const summarySheet = workbook.addWorksheet('Özet');
      this._addSummarySheet(summarySheet, packageData.invoices || []);

      // 4. Ürün Kalemleri Sayfası
      const productsSheet = workbook.addWorksheet('Ürün Kalemleri');
      this._addProductsSheet(productsSheet, packageData.invoices || []);

      // 5. İşlenmiş Veri (JSON) Sayfası
      const structuredDataSheet = workbook.addWorksheet('İşlenmiş Veri (JSON)');
      this._addStructuredDataSheet(structuredDataSheet, packageData.invoices || []);

      // 6. OCR Metinleri Sayfası
      const ocrSheet = workbook.addWorksheet('OCR Metinleri');
      this._addOCRSheet(ocrSheet, packageData.invoices || []);

      // Stil uygula
      this._applyStyles(workbook);

      console.log('🔐 ExcelService - Excel dosyası oluşturuldu, encode ediliyor...');
      const buffer = await workbook.xlsx.writeBuffer();
      console.log(`🔐 ExcelService - Excel dosyası hazır, boyut: ${buffer.length} bytes`);
      
      return buffer;
    } catch (error) {
      console.error('❌ ExcelService - Excel oluşturma hatası:', error);
      throw new Error(`Excel raporu oluşturulamadı: ${error.message}`);
    }
  }

  // Tekil Fatura Excel raporu oluştur
  static async generateInvoiceExcel(invoiceData) {
    try {
      console.log('🔐 ExcelService - Tekil Fatura Excel raporu oluşturuluyor...');
      if (!invoiceData) {
        throw new Error('Fatura verisi (invoiceData) eksik.');
      }
      
      const workbook = new ExcelJS.Workbook();
      workbook.creator = 'Fatura Yeni';
      workbook.created = new Date();

      // Tek faturayı bir diziye koyarak mevcut yardımcı fonksiyonları yeniden kullan
      const invoices = [invoiceData];

      // 1. Fatura Detayları Sayfası (tek satır)
      const invoicesSheet = workbook.addWorksheet('Fatura Detayları');
      this._addInvoicesSheet(invoicesSheet, invoices);

      // 2. Ürün Kalemleri Sayfası
      const productsSheet = workbook.addWorksheet('Ürün Kalemleri');
      this._addProductsSheet(productsSheet, invoices);

      // 3. İşlenmiş Veri (JSON) Sayfası
      const structuredDataSheet = workbook.addWorksheet('İşlenmiş Veri (JSON)');
      this._addStructuredDataSheet(structuredDataSheet, invoices);

      // 4. OCR Metinleri Sayfası
      const ocrSheet = workbook.addWorksheet('OCR Metinleri');
      this._addOCRSheet(ocrSheet, invoices);

      // Stil uygula
      this._applyStyles(workbook);

      console.log('🔐 ExcelService - Tekil Excel dosyası oluşturuldu, encode ediliyor...');
      const buffer = await workbook.xlsx.writeBuffer();
      console.log(`🔐 ExcelService - Tekil Excel dosyası hazır, boyut: ${buffer.length} bytes`);
      
      return buffer;
    } catch (error) {
      console.error('❌ ExcelService - Tekil Excel oluşturma hatası:', error);
      throw new Error(`Tekil Excel raporu oluşturulamadı: ${error.message}`);
    }
  }

  // Paket bilgileri sayfası
  static _addPackageInfoSheet(sheet, packageData) {
    console.log('📝 ExcelService - Paket Bilgileri sayfası oluşturuluyor...');
    // Başlık
    sheet.getCell('A1').value = 'PAKET BİLGİLERİ';
    sheet.getCell('A1').font = { bold: true, size: 16 };
    sheet.getCell('A1').fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFE0E0E0' } };
    sheet.mergeCells('A1:B1');

    // Veri
    const data = [
      ['ID', packageData.id || 'N/A'],
      ['Ad', packageData.name || 'N/A'],
      ['Durum', packageData.status || 'N/A'],
      ['Toplam Fatura', packageData.totalInvoices || 0],
      ['İşlenmiş Fatura', packageData.processedInvoices || 0],
      ['Onaylanan Fatura', packageData.approvedInvoices || 0],
      ['Hata Sayısı', packageData.errorCount || 0],
      ['Oluşturulma Tarihi', this._formatDate(packageData.createdAt)],
      ['Son Güncelleme', this._formatDate(packageData.lastUpdatedAt)],
      ['Son Yeniden Değerlendirme', this._formatDate(packageData.lastReevaluationAt)],
    ];

    data.forEach((row, index) => {
      const rowNum = index + 3;
      sheet.getCell(`A${rowNum}`).value = row[0];
      sheet.getCell(`B${rowNum}`).value = row[1];
      
      // Başlık hücreleri
      sheet.getCell(`A${rowNum}`).font = { bold: true };
      sheet.getCell(`A${rowNum}`).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFF0F0F0' } };
    });

    // Sütun genişlikleri
    sheet.getColumn('A').width = 20;
    sheet.getColumn('B').width = 30;
  }

  // Fatura detayları sayfası
  static _addInvoicesSheet(sheet, invoices) {
    console.log(`📝 ExcelService - Fatura Detayları sayfası oluşturuluyor (${invoices.length} fatura)...`);
    // Başlık
    sheet.getCell('A1').value = 'FATURA DETAYLARI';
    sheet.getCell('A1').font = { bold: true, size: 16 };
    sheet.getCell('A1').fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFE0E0E0' } };
    sheet.mergeCells('A1:X1');

    // Sütun başlıkları
    const headers = [
      'Fatura ID', 'Dosya Adı', 'Onay Durumu', 'İşlem Durumu', 'Fatura No', 'Fatura Tarihi', 'Sipariş Tarihi',
      'Yükleme Tarihi', 'Son İşlem Tarihi', 'Son Yeniden Değerlendirme', 'İşlem Süresi (ms)', 
      'Alıcı Unvan', 'Alıcı VKN', 'Alıcı Telefon', 'Alıcı Vergi Dairesi', 
      'ETTN', 'Mal Hizmet Toplam', 'Toplam İskonto', 'Ödenecek Tutar', 'Vergiler Dahil Toplam',
      'Dosya URL', 'Thumbnail URL'
    ];

    headers.forEach((header, index) => {
      const col = String.fromCharCode(65 + index); // A, B, C...
      sheet.getCell(`${col}2`).value = header;
      sheet.getCell(`${col}2`).font = { bold: true };
      sheet.getCell(`${col}2`).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFD0D0D0' } };
      sheet.getCell(`${col}2`).alignment = { horizontal: 'center', vertical: 'middle' };
    });

    // Filtre ve Dondurma
    sheet.autoFilter = `A2:${String.fromCharCode(65 + headers.length - 1)}2`;
    sheet.views = [
      {state: 'frozen', ySplit: 2, activeCell: 'A3'}
    ];

    // Veri satırları
    invoices.forEach((invoice, index) => {
      const rowNum = index + 3;
      const structured = invoice.structured || {};
      
      const rowData = [
        invoice.id || 'N/A',
        invoice.originalName || 'N/A',
        invoice.isApproved ? 'Onaylandı' : 'Beklemede',
        invoice.status || 'N/A',
        this._extractInvoiceNumber(structured),
        this._extractInvoiceDate(structured),
        structured.siparis_tarihi || 'N/A',
        this._formatDate(invoice.uploadedAt),
        this._formatDate(invoice.lastProcessedAt),
        this._formatDate(invoice.lastReevaluationAt),
        invoice.processingMs || 'N/A',
        structured.alici_unvan || '',
        structured.alici_vkn || '',
        structured.alici_tel || '',
        structured.alici_vergi_dairesi || '',
        structured.ettn || '',
        structured.mal_hizmet_toplam_tutari || '',
        structured.toplam_iskonto || '',
        structured.odenecek_tutar || '',
        structured.vergiler_dahil_toplam_tutar || '',
        invoice.fileUrl || '',
        invoice.thumbnailUrl || ''
      ];

      rowData.forEach((value, colIndex) => {
        const col = String.fromCharCode(65 + colIndex);
        sheet.getCell(`${col}${rowNum}`).value = value;
        
        // Sayısal formatlar
        const numericColumns = [16, 17, 18, 19]; // mal_hizmet_toplam_tutari ve sonrası
        if(numericColumns.includes(colIndex)) {
            sheet.getCell(`${col}${rowNum}`).numFmt = '#,##0.00';
        }
      });
      console.log(`  - Fatura ${index + 1} işlendi: ${invoice.id}`);
    });

    // Sütun genişlikleri
    headers.forEach((_, index) => {
      const col = String.fromCharCode(65 + index);
      sheet.getColumn(col).width = 15;
    });
  }

  // Özet sayfası
  static _addSummarySheet(sheet, invoices) {
    console.log('📝 ExcelService - Özet sayfası oluşturuluyor...');
    // Başlık
    sheet.getCell('A1').value = 'ÖZET BİLGİLER';
    sheet.getCell('A1').font = { bold: true, size: 16 };
    sheet.getCell('A1').fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFE0E0E0' } };
    sheet.mergeCells('A1:B1');

    const totalAmount = this._calculateRealTotalAmount(invoices);
    const totalVAT = this._calculateRealTotalVAT(invoices);
    const averageAmount = invoices.length > 0 ? totalAmount / invoices.length : 0;
    const totalProducts = this._calculateTotalProductItems(invoices);

    const data = [
      ['Toplam Tutar (Gerçek)', totalAmount],
      ['Toplam KDV (Gerçek)', totalVAT],
      ['Ortalama Fatura Tutarı', averageAmount],
      ['Fatura Sayısı', invoices.length],
      ['Toplam Ürün Kalemi', totalProducts]
    ];

    data.forEach((row, index) => {
      const rowNum = index + 3;
      sheet.getCell(`A${rowNum}`).value = row[0];
      sheet.getCell(`B${rowNum}`).value = row[1];
      
      sheet.getCell(`A${rowNum}`).font = { bold: true };
      sheet.getCell(`A${rowNum}`).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFF0F0F0' } };
      
      // Sayısal değerler için format
      if (rowNum <= 5) { // İlk 3 satır sayısal
        sheet.getCell(`B${rowNum}`).numFmt = '#,##0.00';
      }
    });

    sheet.getColumn('A').width = 25;
    sheet.getColumn('B').width = 20;
  }

  // Ürün kalemleri sayfası
  static _addProductsSheet(sheet, invoices) {
    console.log('📝 ExcelService - Ürün Kalemleri sayfası oluşturuluyor...');
    // Başlık
    sheet.getCell('A1').value = 'ÜRÜN KALEMLERİ DETAYI';
    sheet.getCell('A1').font = { bold: true, size: 16 };
    sheet.getCell('A1').fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFE0E0E0' } };
    sheet.mergeCells('A1:L1');

    // Sütun başlıkları
    const headers = [
      'Fatura ID', 'Dosya Adı', 'Sıra No', 'Mal Hizmet', 'Miktar',
      'Birim Fiyat', 'Mal Hizmet Tutarı', 'KDV Oranı', 'KDV Tutarı',
      'İskonto Oranı', 'İskonto Tutarı', 'Diğer Vergiler'
    ];

    headers.forEach((header, index) => {
      const col = String.fromCharCode(65 + index);
      sheet.getCell(`${col}2`).value = header;
      sheet.getCell(`${col}2`).font = { bold: true };
      sheet.getCell(`${col}2`).fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFD0D0D0' } };
      sheet.getCell(`${col}2`).alignment = { horizontal: 'center', vertical: 'middle' };
    });

    // Filtre ve Dondurma
    sheet.autoFilter = `A2:${String.fromCharCode(65 + headers.length - 1)}2`;
    sheet.views = [
      {state: 'frozen', ySplit: 2, activeCell: 'A3'}
    ];

    // Veri satırları
    let currentRow = 3;
    invoices.forEach((invoice) => {
      const structured = invoice.structured || {};
      const urunKalemleri = structured.urun_kalemleri || [];
      
      urunKalemleri.forEach((urun) => {
        const rowData = [
          invoice.id || 'N/A',
          invoice.originalName || 'N/A',
          urun['sıra no'] || '',
          urun['mal hizmet'] || '',
          urun['miktar'] || '',
          urun['birim fiyat'] || '',
          urun['mal hizmet tutarı'] || '',
          urun['kdv oranı'] || '',
          urun['kdv tutarı'] || '',
          urun['i̇skonto oranı'] || '',
          urun['i̇skonto tutarı'] || '',
          urun['diğer vergiler'] || ''
        ];

        rowData.forEach((value, colIndex) => {
          const col = String.fromCharCode(65 + colIndex);
          sheet.getCell(`${col}${currentRow}`).value = value;
        });

        currentRow++;
      });
    });

    // Sütun genişlikleri
    headers.forEach((_, index) => {
      const col = String.fromCharCode(65 + index);
      sheet.getColumn(col).width = 15;
    });
  }

  // İşlenmiş veri (JSON) sayfası
  static _addStructuredDataSheet(sheet, invoices) {
    console.log('📝 ExcelService - İşlenmiş Veri (JSON) sayfası oluşturuluyor...');
    // Başlık
    sheet.getCell('A1').value = 'İŞLENMİŞ VERİ (JSON)';
    sheet.getCell('A1').font = { bold: true, size: 16 };
    sheet.getCell('A1').fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFE0E0E0' } };
    sheet.mergeCells('A1:C1');

    // Sütun başlıkları
    sheet.getCell('A2').value = 'Fatura ID';
    sheet.getCell('B2').value = 'Dosya Adı';
    sheet.getCell('C2').value = 'İşlenmiş Veri (JSON)';
    sheet.getCell('A2').font = { bold: true };
    sheet.getCell('B2').font = { bold: true };
    sheet.getCell('C2').font = { bold: true };
    sheet.getCell('A2').fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFD0D0D0' } };
    sheet.getCell('B2').fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFD0D0D0' } };
    sheet.getCell('C2').fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFD0D0D0' } };

    // Veri satırları
    invoices.forEach((invoice, index) => {
      const rowNum = index + 3;
      sheet.getCell(`A${rowNum}`).value = invoice.id || 'N/A';
      sheet.getCell(`B${rowNum}`).value = invoice.originalName || 'N/A';
      const structuredData = invoice.structured ? JSON.stringify(invoice.structured, null, 2) : '{}';
      sheet.getCell(`C${rowNum}`).value = structuredData;
      
      // JSON metni için wrap text
      sheet.getCell(`C${rowNum}`).alignment = { wrapText: true, vertical: 'top' };
    });

    sheet.getColumn('A').width = 30;
    sheet.getColumn('B').width = 40;
    sheet.getColumn('C').width = 100;
  }

  // OCR metinleri sayfası
  static _addOCRSheet(sheet, invoices) {
    console.log('📝 ExcelService - OCR Metinleri sayfası oluşturuluyor...');
    // Başlık
    sheet.getCell('A1').value = 'OCR METİNLERİ';
    sheet.getCell('A1').font = { bold: true, size: 16 };
    sheet.getCell('A1').fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFE0E0E0' } };
    sheet.mergeCells('A1:B1');

    // Sütun başlıkları
    sheet.getCell('A2').value = 'Fatura ID';
    sheet.getCell('B2').value = 'OCR Metni';
    sheet.getCell('A2').font = { bold: true };
    sheet.getCell('B2').font = { bold: true };
    sheet.getCell('A2').fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFD0D0D0' } };
    sheet.getCell('B2').fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFD0D0D0' } };

    // Veri satırları
    invoices.forEach((invoice, index) => {
      const rowNum = index + 3;
      sheet.getCell(`A${rowNum}`).value = invoice.id || 'N/A';
      sheet.getCell(`B${rowNum}`).value = invoice.ocrText || '';
      
      // OCR metni için wrap text
      sheet.getCell(`B${rowNum}`).alignment = { wrapText: true, vertical: 'top' };
    });

    sheet.getColumn('A').width = 30;
    sheet.getColumn('B').width = 100;
  }

  // Stil uygula
  static _applyStyles(workbook) {
    workbook.worksheets.forEach(sheet => {
      // Tüm hücreler için border ve font
      sheet.eachRow({ includeEmpty: true }, (row) => {
        row.eachCell({ includeEmpty: true }, (cell) => {
          cell.border = {
            top: { style: 'thin', color: { argb: 'FFCCCCCC' } },
            left: { style: 'thin', color: { argb: 'FFCCCCCC' } },
            bottom: { style: 'thin', color: { argb: 'FFCCCCCC' } },
            right: { style: 'thin', color: { argb: 'FFCCCCCC' } }
          };
          cell.font = { name: 'Arial', size: 10 };
        });
      });
    });
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

  static _extractInvoiceDate(structured) {
    try {
      if (!structured || !structured.alici_unvan) {
        return 'N/A';
      }
      const unvan = structured.alici_unvan;
      if (typeof unvan !== 'string') return 'N/A';
      
      let match = unvan.match(/Fatura Tarihi: (\d{2}-\d{2}-\d{4})/);
      if (match && match[1]) {
        return match[1];
      }
      
      match = unvan.match(/Düzenleme Tarihi: (\d{2}-\d{2}-\d{4})/);
      if (match && match[1]) {
        return match[1];
      }

      return 'N/A';
    } catch (e) {
      console.error('❌ Fatura tarihi çıkarılamadı:', structured, e);
      return 'N/A';
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

module.exports = ExcelService;
