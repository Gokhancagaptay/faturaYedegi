const express = require('express');
const ReportController = require('../controllers/reportController');
const { protect } = require('../middlewares/auth.middleware');
const router = express.Router();

// Middleware'i tüm rapor endpoint'lerine uygula
router.use(protect);

// Test endpoint - rapor sisteminin çalışıp çalışmadığını kontrol et
router.get('/test', ReportController.testReport);

// Paket Excel raporu oluştur ve indir
router.post('/excel', ReportController.generatePackageExcel);

// Paket CSV raporu oluştur ve indir (tüm faturalar)
router.post('/csv', ReportController.generatePackageCSV);

// Paket JSON raporu oluştur ve indir
router.post('/json', ReportController.generatePackageJson);

// Ürün kalemleri CSV raporu oluştur ve indir
router.post('/products-csv', ReportController.generateProductsCSV);

// Özet CSV raporu oluştur ve indir
router.post('/summary-csv', ReportController.generateSummaryCSV);

// Tüm raporları oluştur (Excel olarak)
router.post('/all', ReportController.generateAllReports);

// Single invoice reports
router.post('/invoice/excel', ReportController.generateInvoiceExcel);
router.post('/invoice/csv', ReportController.generateInvoiceCSV);
router.post('/invoice/json', ReportController.generateInvoiceJson);

module.exports = router;
