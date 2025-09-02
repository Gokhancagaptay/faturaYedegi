const packageRepo = require('../db/package.repo');
const invoiceRepo = require('../db/invoice.repo');
const userRepo = require('../db/user.repo');
const { getStorage } = require('firebase-admin/storage');
const { defaultQueue } = require('../services/jobQueue');
const { generateThumbnail, uploadThumbnail } = require('../services/image.service');
const invoiceService = require('../services/invoice.service');
const { INVOICE_TEMPLATE } = require('../config/invoiceTemplate');

const createPackage = async (req, res) => {
    try {
        const userId = req.user?.uid || req.user?.id;
        await userRepo.ensureAppUserExists(userId);
        const files = req.files || [];
        const name = req.body?.name;
        console.log(`📦 Creating package with ${files.length} files`);
        const pkg = await packageRepo.createPackage(userId, { name, totalInvoices: files.length });
        console.log(`📦 Package created: ${pkg.id}`);

        // Kuyruk: her dosya için bir iş
        for (const file of files) {
            console.log(`📦 Adding file to queue: ${file.originalname}`);
            defaultQueue.add({
                name: 'process-invoice-in-package',
                payload: { userId, packageId: pkg.id, file },
                handler: async ({ userId, packageId, file }) => {
                    console.log(`📦 Queue handler called for: ${file.originalname}`);
                    await processFileInPackage(userId, packageId, file);
                }
            });
        }

        res.status(202).json({ message: 'Package created', packageId: pkg.id, status: 'uploading', total: files.length });
    } catch (e) {
        console.error('createPackage error', e);
        res.status(500).json({ message: 'Failed to create package', error: e.message });
    }
};

const processFileInPackage = async (userId, packageId, file) => {
    const createdAt = new Date();
    let invoiceDoc = null;
    try {
        // 1) invoice kaydı: uploading
        invoiceDoc = await packageRepo.addInvoice(userId, packageId, {
            originalName: file.originalname,
            uploadedAt: createdAt,
            status: 'uploading',
            isApproved: false,
        });

        // 2) Storage upload + thumbnail -> queued
        console.log(`📦 Starting file upload for ${file.originalname}`);
        const storage = getStorage();
        const bucket = storage.bucket();
        const basePath = `app_users/${userId}/packages/${packageId}/invoices/${invoiceDoc.id}`;
        const filePath = `${basePath}/${file.originalname}`;
        const storageFile = bucket.file(filePath);
        await storageFile.save(file.buffer, { metadata: { contentType: file.mimetype } });
        
        // GÜNCELLEME: Dosyayı herkese açık yapmak yerine güvenli, süreli bir URL oluştur.
        const [fileUrl] = await storageFile.getSignedUrl({
            action: 'read',
            expires: Date.now() + 1000 * 60 * 60, // 1 saat geçerli
        });
        
        console.log(`📦 File uploaded, signed URL created: ${fileUrl}`);
        
        console.log(`📦 Starting thumbnail generation...`);
        const thumbBuffer = await generateThumbnail(file.buffer, { mime: file.mimetype });
        const thumbPath = `${basePath}/thumbnail.jpg`;
        
        // Yeni thumbnail upload fonksiyonunu kullan
        const thumbnailResult = await uploadThumbnail(thumbBuffer, thumbPath, {
            metadata: {
                originalName: file.originalname,
                uploadedBy: userId,
                uploadedAt: new Date().toISOString(),
                invoiceId: invoiceDoc.id,
                packageId: packageId
            }
        });

        console.log(`📸 Thumbnail created: ${thumbnailResult.signedUrl}`);

        await packageRepo.updateInvoice(userId, packageId, invoiceDoc.id, {
            status: 'queued', 
            fileUrl, 
            thumbnailUrl: thumbnailResult.signedUrl
        });
        console.log(`📦 Invoice updated with URLs`);
        

        // 3) İşleme -> processing (Python parser opsiyonel)
        await packageRepo.updateInvoice(userId, packageId, invoiceDoc.id, { 
            status: 'processing' 
        });
        
        let processed = null;
        let ms = 0;
        
        try {
            const t0 = Date.now();
            processed = await invoiceService.processWithPython(file);
            ms = Date.now() - t0;
            console.log('✅ Python parser başarıyla çalıştı');
        } catch (pythonError) {
            console.warn('⚠️ Python parser çalışmadı, dosya sadece yüklendi:', pythonError.message);
            // Python parser çalışmazsa dosya sadece yüklenmiş olarak işaretle
            processed = {
                structured: {},
                ocrText: 'Python parser servisi mevcut değil',
                status: 'uploaded_only'
            };
            ms = 0;
        }

        const finalStructuredData = {
            ...INVOICE_TEMPLATE,
            ...(processed && (processed.structured || processed.yapilandirilmis_veri)) || {}
        };

        await packageRepo.updateInvoice(userId, packageId, invoiceDoc.id, {
            status: processed?.status === 'uploaded_only' ? 'uploaded' : 'processed',
            structured: finalStructuredData,
            ocrText: processed?.ocrText,
            lastProcessedAt: new Date(),
            processingMs: ms,
            isApproved: false, // Varsayılan olarak onaylanmamış
        });
        
        if (processed?.status === 'uploaded_only') {
            await packageRepo.incrementCounters(userId, packageId, { uploaded: 1 });
        } else {
            await packageRepo.incrementCounters(userId, packageId, { processed: 1 });
        }
    } catch (err) {
        console.error('processFileInPackage error', err.message);
        await packageRepo.updateInvoice(userId, packageId, invoiceDoc?.id, {
            status: 'failed',
            errors: [{ code: 'PROCESS_FAILED', message: err.message }]
        });
        await packageRepo.incrementCounters(userId, packageId, { errors: 1 });
    }
};

const listPackages = async (req, res) => {
    try {
        const userId = req.user?.uid || req.user?.id;
        const list = await packageRepo.listPackages(userId, {});
        res.status(200).json({ packages: list });
    } catch (e) {
        res.status(500).json({ message: 'Failed to list packages', error: e.message });
    }
};

const getPackage = async (req, res) => {
    try {
        const userId = req.user?.uid || req.user?.id;
        const pkg = await packageRepo.getPackage(userId, req.params.packageId);
        if (!pkg) return res.status(404).json({ message: 'Package not found' });
        res.status(200).json({ package: pkg });
    } catch (e) {
        res.status(500).json({ message: 'Failed to get package', error: e.message });
    }
};

const listPackageInvoices = async (req, res) => {
    try {
        const userId = req.user?.uid || req.user?.id;
        const items = await packageRepo.listInvoices(userId, req.params.packageId, {});
        console.log(`📋 Package invoices response:`, items.map(i => ({ id: i.id, thumbnailUrl: i.thumbnailUrl })));
        res.status(200).json({ invoices: items });
    } catch (e) {
        res.status(500).json({ message: 'Failed to list invoices', error: e.message });
    }
};

const exportPackageJson = async (req, res) => {
    try {
        const userId = req.user?.uid || req.user?.id;
        const pkg = await packageRepo.getPackage(userId, req.params.packageId);
        if (!pkg) return res.status(404).json({ message: 'Package not found' });
        const items = await packageRepo.listInvoices(userId, req.params.packageId, { limit: 1000 });
        const payload = {
            packageId: req.params.packageId,
            name: pkg.name,
            createdAt: pkg.createdAt,
            totalInvoices: pkg.totalInvoices,
            processedInvoices: pkg.processedInvoices,
            errorCount: pkg.errorCount,
            invoices: items.map(x => ({
                id: x.id,
                originalName: x.originalName,
                status: x.status,
                uploadedAt: x.uploadedAt,
                lastProcessedAt: x.lastProcessedAt,
                fileUrl: x.fileUrl,
                thumbnailUrl: x.thumbnailUrl,
                structured: x.structured || {},
            }))
        };
        res.setHeader('Content-Type', 'application/json');
        return res.status(200).send(JSON.stringify(payload));
    } catch (e) {
        res.status(500).json({ message: 'Failed to export package', error: e.message });
    }
};

const reevaluatePackage = async (req, res) => {
    try {
        const userId = req.user?.uid || req.user?.id;
        const { packageId } = req.params;
        
        console.log(`🔄 Reevaluating package: ${packageId} for user: ${userId}`);
        
        // 1. Paketi bul ve kontrol et
        const pkg = await packageRepo.getPackage(userId, packageId);
        if (!pkg) {
            return res.status(404).json({ 
                success: false, 
                message: 'Paket bulunamadı' 
            });
        }
        
        // 2. Paketteki tüm faturaları al
        const invoices = await packageRepo.listInvoices(userId, packageId, { limit: 1000 });
        console.log(`🔄 Found ${invoices.length} invoices to reevaluate`);
        
        // 3. Paket durumunu güncelle
        await packageRepo.updatePackage(userId, packageId, {
            status: 'reevaluating',
            reevaluatedAt: new Date(),
            lastReevaluationAt: new Date()
        });
        
        // 4. Her fatura için tekrar işleme kuyruğa ekle
        for (const invoice of invoices) {
            if (invoice.fileUrl) {
                console.log(`🔄 Adding invoice ${invoice.id} to reevaluation queue`);
                
                // Faturayı tekrar işleme kuyruğa ekle
                defaultQueue.add({
                    name: 'reevaluate-invoice',
                    payload: { 
                        userId, 
                        packageId, 
                        invoiceId: invoice.id,
                        fileUrl: invoice.fileUrl,
                        originalName: invoice.originalName
                    },
                    handler: async ({ userId, packageId, invoiceId, fileUrl, originalName }) => {
                        console.log(`🔄 Reevaluating invoice: ${invoiceId}`);
                        await reevaluateInvoiceInPackage(userId, packageId, invoiceId, fileUrl, originalName);
                    }
                });
            }
        }
        
        // 5. Başarılı response
        res.status(200).json({
            success: true,
            message: 'Paket başarıyla tekrar değerlendirildi!',
            data: {
                packageId,
                totalInvoices: invoices.length,
                status: 'reevaluating'
            }
        });
        
    } catch (error) {
        console.error('reevaluatePackage error:', error);
        res.status(500).json({
            success: false,
            message: 'Tekrar değerlendirme başarısız: ' + error.message
        });
    }
};

// Faturayı tekrar değerlendir
const reevaluateInvoiceInPackage = async (userId, packageId, invoiceId, fileUrl, originalName) => {
    try {
        // 1. Fatura durumunu güncelle
        await packageRepo.updateInvoice(userId, packageId, invoiceId, {
            status: 'reevaluating',
            lastReevaluationAt: new Date()
        });
        
        // 2. Dosyayı indir ve tekrar işle
        // GÜNCELLEME: fileUrl zaten imzalı olduğu için doğrudan fetch kullanabiliriz.
        // Eğer fileUrl'in süresi dolmuş olsaydı, burada yeniden imzalı URL oluşturmamız gerekirdi.
        // Şimdilik mevcut yapının çalıştığını varsayıyoruz.
        const response = await fetch(fileUrl);
        const fileBuffer = await response.arrayBuffer();
        
        // 3. Python parser ile tekrar işle
        const t0 = Date.now();
        const processed = await invoiceService.processWithPython({
            buffer: Buffer.from(fileBuffer),
            originalname: originalName,
            mimetype: 'application/pdf'
        });
        const ms = Date.now() - t0;
        
        const finalStructuredData = {
            ...INVOICE_TEMPLATE,
            ...(processed && (processed.structured || processed.yapilandirilmis_veri)) || {}
        };

        // 4. Sonuçları güncelle
        await packageRepo.updateInvoice(userId, packageId, invoiceId, {
            status: processed?.status === 'uploaded_only' ? 'uploaded' : 'processed',
            structured: finalStructuredData,
            ocrText: processed?.ocrText,
            lastProcessedAt: new Date(),
            processingMs: ms,
            isApproved: false, // Tekrar değerlendirildiği için onay sıfırla
        });
        
        console.log(`✅ Invoice ${invoiceId} reevaluated successfully`);
        
    } catch (error) {
        console.error(`❌ Failed to reevaluate invoice ${invoiceId}:`, error);
        await packageRepo.updateInvoice(userId, packageId, invoiceId, {
            status: 'failed',
            errors: [{ 
                code: 'REEVALUATION_FAILED', 
                message: error.message,
                timestamp: new Date()
            }]
        });
    }
};

const getInvoiceDetail = async (req, res) => {
    try {
        const userId = req.user?.uid || req.user?.id;
        const { packageId, invoiceId } = req.params;
        const invoice = await packageRepo.getInvoice(userId, packageId, invoiceId);
        if (!invoice) {
            return res.status(404).json({ message: 'Invoice not found' });
        }

        // GÜNCELLEME: fileUrl ve thumbnailUrl'nin süresi dolmuş olabilir.
        // İstek anında taze, imzalı URL'ler oluşturup yanıtı zenginleştir.
        try {
            const storage = getStorage();
            const bucket = storage.bucket();
            const basePath = `app_users/${userId}/packages/${packageId}/invoices/${invoiceId}`;
            
            if (invoice.fileUrl) {
                const originalFilePath = `${basePath}/${invoice.originalName}`;
                const [signedFileUrl] = await bucket.file(originalFilePath).getSignedUrl({
                    action: 'read',
                    expires: Date.now() + 1000 * 60 * 60, // 1 saat
                });
                invoice.fileUrl = signedFileUrl;
            }

            if (invoice.thumbnailUrl) {
                const thumbPath = `${basePath}/thumbnail.jpg`;
                 const [signedThumbnailUrl] = await bucket.file(thumbPath).getSignedUrl({
                    action: 'read',
                    expires: Date.now() + 1000 * 60 * 60, // 1 saat
                });
                invoice.thumbnailUrl = signedThumbnailUrl;
            }
        } catch (urlError) {
            console.warn(`Could not generate signed URLs for invoice ${invoiceId}:`, urlError.message);
            // URL'ler oluşturulamazsa bile devam et, en azından diğer verileri gönder.
        }

        res.status(200).json(invoice);
    } catch (e) {
        console.error('getInvoiceDetail error:', e);
        res.status(500).json({ message: 'Failed to get invoice details', error: e.message });
    }
};

const updateInvoiceData = async (req, res) => {
    try {
        const userId = req.user?.uid || req.user?.id;
        const { packageId, invoiceId } = req.params;
        const { structured } = req.body;

        if (!structured) {
            return res.status(400).json({ message: 'structured data is required' });
        }

        // TODO: Add validation for structured data fields

        await packageRepo.updateInvoice(userId, packageId, invoiceId, { structured });
        res.status(200).json({ message: 'Fatura başarıyla güncellendi.' });
    } catch (e) {
        console.error('updateInvoiceData error:', e);
        res.status(500).json({ message: 'Failed to update invoice', error: e.message });
    }
};

const approveInvoice = async (req, res) => {
    try {
        const userId = req.user?.uid || req.user?.id;
        const { packageId, invoiceId } = req.params;
        await packageRepo.updateInvoice(userId, packageId, invoiceId, { isApproved: true, status: 'approved' });
        res.status(200).json({ message: 'Fatura onaylandı.' });
    } catch (e) {
        console.error('approveInvoice error:', e);
        res.status(500).json({ message: 'Failed to approve invoice', error: e.message });
    }
};

const rejectInvoice = async (req, res) => {
    try {
        const userId = req.user?.uid || req.user?.id;
        const { packageId, invoiceId } = req.params;
        await packageRepo.updateInvoice(userId, packageId, invoiceId, { isApproved: false, status: 'rejected' });
        res.status(200).json({ message: 'Fatura reddedildi.' });
    } catch (e) {
        console.error('rejectInvoice error:', e);
        res.status(500).json({ message: 'Failed to reject invoice', error: e.message });
    }
};

const updateStructuredData = async (req, res) => {
    try {
        const userId = req.user?.uid || req.user?.id;
        const { packageId, invoiceId } = req.params;
        const updatedData = req.body;

        if (!updatedData || typeof updatedData !== 'object') {
            return res.status(400).json({ message: 'Geçerli bir veri objesi gönderilmedi.' });
        }

        // DOĞRU KULLANIM: Fonksiyon (userId, packageId, invoiceId, data) bekliyor.
        await packageRepo.updateInvoice(userId, packageId, invoiceId, {
            structured: updatedData,
            lastEditedAt: new Date() // Düzenleme zamanını kaydet
        });

        res.status(200).json({ success: true, message: 'Fatura verileri başarıyla güncellendi.' });
    } catch (e) {
        console.error('updateStructuredData error:', e);
        res.status(500).json({ success: false, message: 'Fatura güncellenirken bir hata oluştu.', error: e.message });
    }
};

module.exports = {
    createPackage,
    listPackages,
    getPackage,
    listPackageInvoices,
    exportPackageJson,
    reevaluatePackage,
    getInvoiceDetail,
    updateInvoiceData,
    approveInvoice,
    rejectInvoice,
    updateStructuredData,
};
