const ExcelService = require('../services/excelService');
const CSVService = require('../services/csvService');
const path = require('path');
const fs = require('fs');

class ReportController {
  // Paket Excel raporu oluştur ve indir
  static async generatePackageExcel(req, res) {
    try {
      console.log('🔐 ReportController - Paket Excel raporu isteği alındı');
      console.log('Gelen istek body:', JSON.stringify(req.body, null, 2));
      
      const { packageData } = req.body;
      
      if (!packageData || typeof packageData !== 'object' || !packageData.invoices) {
        console.error('❌ Geçersiz veya eksik paket verisi:', packageData);
        return res.status(400).json({
          success: false,
          message: 'Paket verisi (packageData) ve faturalar (invoices) gerekli'
        });
      }

      // Excel oluştur
      const excelBuffer = await ExcelService.generatePackageExcel(packageData);
      
      // Dosya adı oluştur
      const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
      const fileName = `paket_${packageData.id}_${timestamp}.xlsx`;
      
      // Response headers
      res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      res.setHeader('Content-Disposition', `attachment; filename="${fileName}"`);
      res.setHeader('Content-Length', excelBuffer.length);
      
      console.log(`🔐 ReportController - Excel raporu gönderiliyor: ${fileName} (${excelBuffer.length} bytes)`);
      
      // Buffer'ı gönder
      res.send(excelBuffer);
      
    } catch (error) {
      console.error('❌ ReportController - Excel raporu hatası:', error);
      res.status(500).json({
        success: false,
        message: `Excel raporu oluşturulamadı: ${error.message}`
      });
    }
  }

  // Paket CSV raporu oluştur ve indir (Komple)
  static async generatePackageCSV(req, res) {
    try {
      console.log('🔐 ReportController - Paket CSV raporu isteği alındı');
      console.log('Gelen istek body:', JSON.stringify(req.body, null, 2));
      const { packageData } = req.body;
      if (!packageData || typeof packageData !== 'object' || !packageData.invoices) {
        console.error('❌ Geçersiz veya eksik paket verisi:', packageData);
        return res.status(400).json({
          success: false,
          message: 'Paket verisi (packageData) ve faturalar (invoices) gerekli'
        });
      }

      // CSV'yi geçici bir dosyaya oluştur
      const csvPath = await CSVService.generatePackageCSV(packageData);
      
      const fileName = `paket_raporu_${packageData.id || 'rapor'}.csv`;
      
      res.setHeader('Content-Type', 'text/csv; charset=utf-8');
      res.setHeader('Content-Disposition', `attachment; filename="${fileName}"`);
      
      console.log(`🔐 ReportController - CSV raporu gönderiliyor: ${fileName}`);
      
      const fileStream = fs.createReadStream(csvPath);
      fileStream.pipe(res);
      
      fileStream.on('end', () => {
        try {
          fs.unlinkSync(csvPath);
          console.log(`🔐 ReportController - Geçici CSV dosyası silindi: ${csvPath}`);
        } catch (e) {
          console.error('❌ Geçici CSV dosyası silinemedi:', e);
        }
      });
      
    } catch (error) {
      console.error('❌ ReportController - CSV raporu hatası:', error);
      res.status(500).json({
        success: false,
        message: `CSV raporu oluşturulamadı: ${error.message}`
      });
    }
  }

  // Paket JSON raporu oluştur ve indir
  static async generatePackageJson(req, res) {
    try {
      console.log('🔐 ReportController - Paket JSON raporu isteği alındı');
      console.log('Gelen istek body:', JSON.stringify(req.body, null, 2));
      const { packageData } = req.body;
      if (!packageData) {
        return res.status(400).json({
          success: false,
          message: 'Paket verisi gerekli'
        });
      }

      // Gelen veriyi formatlayarak geri gönder
      const reportJson = JSON.stringify(packageData, null, 2);
      
      const fileName = `paket_raporu_${packageData.id || 'rapor'}.json`;

      res.setHeader('Content-Type', 'application/json; charset=utf-8');
      res.setHeader('Content-Disposition', `attachment; filename="${fileName}"`);
      
      console.log(`🔐 ReportController - JSON raporu gönderiliyor: ${fileName}`);
      
      res.send(reportJson);

    } catch (error) {
      console.error('❌ ReportController - JSON raporu hatası:', error);
      res.status(500).json({
        success: false,
        message: `JSON raporu oluşturulamadı: ${error.message}`
      });
    }
  }

  // Ürün kalemleri CSV raporu oluştur ve indir
  static async generateProductsCSV(req, res) {
    try {
      console.log('🔐 ReportController - Ürün kalemleri CSV raporu isteği alındı');
      
      const { packageData } = req.body;
      
      if (!packageData) {
        return res.status(400).json({
          success: false,
          message: 'Paket verisi gerekli'
        });
      }

      // CSV oluştur
      const csvPath = await CSVService.generateProductsCSV(packageData);
      
      // Dosya adı oluştur
      const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
      const fileName = `urun_kalemleri_${packageData.id}_${timestamp}.csv`;
      
      // Response headers
      res.setHeader('Content-Type', 'text/csv');
      res.setHeader('Content-Disposition', `attachment; filename="${fileName}"`);
      
      console.log(`🔐 ReportController - Ürün kalemleri CSV raporu gönderiliyor: ${fileName}`);
      
      // Dosyayı stream olarak gönder
      const fileStream = fs.createReadStream(csvPath);
      fileStream.pipe(res);
      
      // Stream tamamlandığında temp dosyayı sil
      fileStream.on('end', () => {
        try {
          fs.unlinkSync(csvPath);
          console.log(`🔐 ReportController - Temp ürün kalemleri CSV dosyası silindi: ${csvPath}`);
        } catch (e) {
          console.error('❌ Temp ürün kalemleri CSV dosyası silinemedi:', e);
        }
      });
      
    } catch (error) {
      console.error('❌ ReportController - Ürün kalemleri CSV raporu hatası:', error);
      res.status(500).json({
        success: false,
        message: `Ürün kalemleri CSV raporu oluşturulamadı: ${error.message}`
      });
    }
  }

  // Özet CSV raporu oluştur ve indir
  static async generateSummaryCSV(req, res) {
    try {
      console.log('🔐 ReportController - Özet CSV raporu isteği alındı');
      
      const { packageData } = req.body;
      
      if (!packageData) {
        return res.status(400).json({
          success: false,
          message: 'Paket verisi gerekli'
        });
      }

      // CSV oluştur
      const csvPath = await CSVService.generateSummaryCSV(packageData);
      
      // Dosya adı oluştur
      const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
      const fileName = `ozet_${packageData.id}_${timestamp}.csv`;
      
      // Response headers
      res.setHeader('Content-Type', 'text/csv');
      res.setHeader('Content-Disposition', `attachment; filename="${fileName}"`);
      
      console.log(`🔐 ReportController - Özet CSV raporu gönderiliyor: ${fileName}`);
      
      // Dosyayı stream olarak gönder
      const fileStream = fs.createReadStream(csvPath);
      fileStream.pipe(res);
      
      // Stream tamamlandığında temp dosyayı sil
      fileStream.on('end', () => {
        try {
          fs.unlinkSync(csvPath);
          console.log(`🔐 ReportController - Temp özet CSV dosyası silindi: ${csvPath}`);
        } catch (e) {
          console.error('❌ Temp özet CSV dosyası silinemedi:', e);
        }
      });
      
    } catch (error) {
      console.error('❌ ReportController - Özet CSV raporu hatası:', error);
      res.status(500).json({
        success: false,
        message: `Özet CSV raporu oluşturulamadı: ${error.message}`
      });
    }
  }

  // Tüm raporları oluştur (ZIP olarak)
  static async generateAllReports(req, res) {
    try {
      console.log('🔐 ReportController - Tüm raporlar isteği alındı');
      
      const { packageData } = req.body;
      
      if (!packageData) {
        return res.status(400).json({
          success: false,
          message: 'Paket verisi gerekli'
        });
      }

      // Tüm raporları oluştur
      const [excelBuffer, csvPath, productsCsvPath, summaryCsvPath] = await Promise.all([
        ExcelService.generatePackageExcel(packageData),
        CSVService.generatePackageCSV(packageData),
        CSVService.generateProductsCSV(packageData),
        CSVService.generateSummaryCSV(packageData)
      ]);

      // ZIP oluştur (basit olarak Excel'i gönder)
      const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
      const fileName = `tum_raporlar_${packageData.id}_${timestamp}.xlsx`;
      
      // Response headers
      res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      res.setHeader('Content-Disposition', `attachment; filename="${fileName}"`);
      res.setHeader('Content-Length', excelBuffer.length);
      
      console.log(`🔐 ReportController - Tüm raporlar Excel olarak gönderiliyor: ${fileName}`);
      
      // Excel'i gönder (en kapsamlı rapor)
      res.send(excelBuffer);
      
      // Temp CSV dosyalarını temizle
      setTimeout(() => {
        try {
          [csvPath, productsCsvPath, summaryCsvPath].forEach(filePath => {
            if (fs.existsSync(filePath)) {
              fs.unlinkSync(filePath);
              console.log(`🔐 ReportController - Temp CSV dosyası silindi: ${filePath}`);
            }
          });
        } catch (e) {
          console.error('❌ Temp CSV dosyaları silinemedi:', e);
        }
      }, 5000); // 5 saniye sonra sil
      
    } catch (error) {
      console.error('❌ ReportController - Tüm raporlar hatası:', error);
      res.status(500).json({
        success: false,
        message: `Raporlar oluşturulamadı: ${error.message}`
      });
    }
  }

  // Tekil Fatura JSON raporu oluştur ve indir
  static async generateInvoiceJson(req, res) {
    try {
      console.log('🔐 ReportController - Tekil Fatura JSON raporu isteği alındı');
      const { invoiceData } = req.body;
      if (!invoiceData) {
        return res.status(400).json({ success: false, message: 'Fatura verisi (invoiceData) gerekli' });
      }

      const reportJson = JSON.stringify(invoiceData, null, 2);
      const fileName = `fatura_raporu_${invoiceData.id || 'rapor'}.json`;

      res.setHeader('Content-Type', 'application/json; charset=utf-8');
      res.setHeader('Content-Disposition', `attachment; filename="${fileName}"`);
      
      console.log(`🔐 ReportController - JSON raporu gönderiliyor: ${fileName}`);
      res.send(reportJson);

    } catch (error) {
      console.error('❌ ReportController - Tekil JSON raporu hatası:', error);
      res.status(500).json({ success: false, message: `JSON raporu oluşturulamadı: ${error.message}` });
    }
  }

  // Tekil Fatura CSV raporu oluştur ve indir
  static async generateInvoiceCSV(req, res) {
    try {
      console.log('🔐 ReportController - Tekil Fatura CSV raporu isteği alındı');
      const { invoiceData } = req.body;
       if (!invoiceData || typeof invoiceData !== 'object') {
        return res.status(400).json({ success: false, message: 'Geçerli fatura verisi (invoiceData) gerekli' });
      }

      const csvPath = await CSVService.generateInvoiceCSV(invoiceData);
      const fileName = `fatura_raporu_${invoiceData.id || 'rapor'}.csv`;
      
      res.setHeader('Content-Type', 'text/csv; charset=utf-8');
      res.setHeader('Content-Disposition', `attachment; filename="${fileName}"`);
      
      console.log(`🔐 ReportController - CSV raporu gönderiliyor: ${fileName}`);
      
      const fileStream = fs.createReadStream(csvPath);
      fileStream.pipe(res);
      
      fileStream.on('end', () => {
        try {
          fs.unlinkSync(csvPath);
          console.log(`🔐 ReportController - Geçici CSV dosyası silindi: ${csvPath}`);
        } catch (e) {
          console.error('❌ Geçici CSV dosyası silinemedi:', e);
        }
      });
      
    } catch (error) {
      console.error('❌ ReportController - Tekil CSV raporu hatası:', error);
      res.status(500).json({ success: false, message: `CSV raporu oluşturulamadı: ${error.message}` });
    }
  }

  // Tekil Fatura Excel raporu oluştur ve indir
  static async generateInvoiceExcel(req, res) {
    try {
      console.log('🔐 ReportController - Tekil Fatura Excel raporu isteği alındı');
      const { invoiceData } = req.body;
      
      if (!invoiceData || typeof invoiceData !== 'object') {
        return res.status(400).json({ success: false, message: 'Geçerli fatura verisi (invoiceData) gerekli' });
      }

      const excelBuffer = await ExcelService.generateInvoiceExcel(invoiceData);
      
      const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
      const fileName = `fatura_${invoiceData.id}_${timestamp}.xlsx`;
      
      res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      res.setHeader('Content-Disposition', `attachment; filename="${fileName}"`);
      res.setHeader('Content-Length', excelBuffer.length);
      
      console.log(`🔐 ReportController - Excel raporu gönderiliyor: ${fileName} (${excelBuffer.length} bytes)`);
      res.send(excelBuffer);
      
    } catch (error) {
      console.error('❌ ReportController - Tekil Excel raporu hatası:', error);
      res.status(500).json({ success: false, message: `Excel raporu oluşturulamadı: ${error.message}` });
    }
  }

  // Test endpoint
  static async testReport(req, res) {
    try {
      console.log('🔐 ReportController - Test raporu isteği alındı');
      
      // Test verisi
      const testPackageData = {
        id: 'test-123',
        name: 'Test Paketi',
        status: 'completed',
        totalInvoices: 2,
        processedInvoices: 2,
        approvedInvoices: 1,
        errorCount: 0,
        invoices: [
          {
            id: 'inv-1',
            originalName: 'test1.pdf',
            sellerName: 'Test Satıcı',
            isApproved: true,
            processingMs: 1500,
            structured: {
              odenecek_tutar: '100.50',
              urun_kalemleri: [
                {
                  'sıra no': '1',
                  'mal hizmet': 'Test Ürün',
                  'miktar': '1 Adet',
                  'birim fiyat': '100.50 TL',
                  'mal hizmet tutarı': '100.50 TL',
                  'kdv oranı': '%18',
                  'kdv tutarı': '18.09 TL'
                }
              ]
            }
          }
        ]
      };

      // Excel oluştur
      const excelBuffer = await ExcelService.generatePackageExcel(testPackageData);
      
      // Response headers
      res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      res.setHeader('Content-Disposition', 'attachment; filename="test_rapor.xlsx"');
      res.setHeader('Content-Length', excelBuffer.length);
      
      console.log(`🔐 ReportController - Test Excel raporu gönderiliyor (${excelBuffer.length} bytes)`);
      
      // Buffer'ı gönder
      res.send(excelBuffer);
      
    } catch (error) {
      console.error('❌ ReportController - Test raporu hatası:', error);
      res.status(500).json({
        success: false,
        message: `Test raporu oluşturulamadı: ${error.message}`
      });
    }
  }
}

module.exports = ReportController;
