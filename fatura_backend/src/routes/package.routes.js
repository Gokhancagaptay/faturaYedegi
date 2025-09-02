const express = require('express');
const router = express.Router();
const multer = require('multer');
const { protect } = require('../middlewares/auth.middleware');
const controller = require('../controllers/package.controller');

const upload = multer({ storage: multer.memoryStorage() });

router.post(
  '/',
  protect,
  upload.array('files', 1000),
  controller.createPackage
);
router.get('/', protect, controller.listPackages);
router.get('/:packageId', protect, controller.getPackage);
router.get('/:packageId/invoices', protect, controller.listPackageInvoices);
router.get('/:packageId/export.json', protect, controller.exportPackageJson);
router.post('/:packageId/reevaluate', protect, controller.reevaluatePackage);

// Fatura detay, güncelleme, onaylama ve reddetme endpoint'leri
router.get('/:packageId/invoices/:invoiceId', protect, controller.getInvoiceDetail);
router.put('/:packageId/invoices/:invoiceId', protect, controller.updateInvoiceData);
router.post('/:packageId/invoices/:invoiceId/approve', protect, controller.approveInvoice);
router.post('/:packageId/invoices/:invoiceId/reject', protect, controller.rejectInvoice);

// Sadece yapılandırılmış veriyi güncellemek için yeni endpoint
router.put('/:packageId/invoices/:invoiceId/structured', protect, controller.updateStructuredData);


module.exports = router;
