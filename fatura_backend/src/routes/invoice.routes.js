const express = require('express');
const router = express.Router();
const multer = require('multer');
const invoiceController = require('../controllers/invoice.controller');
const { protect } = require('../middlewares/auth.middleware');

// Configure multer for file uploads. We'll use memory storage to handle the file
// as a buffer before sending it to the Python service.
const upload = multer({ storage: multer.memoryStorage() });

// @route   POST api/invoice/scan
// @desc    Upload an invoice for scanning (synchronous)
// @access  Private
router.post('/scan', protect, upload.single('invoice'), invoiceController.scanInvoice);

// @route   POST api/invoice/scan-background
// @desc    Upload an invoice for scanning (asynchronous/background)
// @access  Private
router.post('/scan-background', protect, upload.single('invoice'), invoiceController.scanInvoiceBackground);

// @route   GET api/invoice/
// @desc    Get all invoices for the logged-in user
// @access  Private
router.get('/', protect, invoiceController.getInvoices);

// @route   GET api/invoice/stats
// @desc    Get invoice statistics for the logged-in user
// @access  Private
router.get('/stats', protect, invoiceController.getInvoiceStats);

// @route   GET api/invoice/:invoiceId
// @desc    Get invoice detail by ID
// @access  Private
router.get('/:invoiceId', protect, invoiceController.getInvoiceDetail);

// @route   PUT api/invoice/:invoiceId
// @desc    Update invoice data and approval status
// @access  Private
router.put('/:invoiceId', protect, invoiceController.updateInvoiceData);

// Export JSON (geçici, paket mimarisi gelene kadar kullanıcı seviyesinde)
router.get('/export.json', protect, invoiceController.exportInvoicesJson);

module.exports = router;
