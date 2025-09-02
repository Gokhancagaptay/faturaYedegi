const invoiceService = require('../services/invoice.service');
const invoiceRepo = require('../db/invoice.repo');
const userRepo = require('../db/user.repo');
const { getStorage } = require('firebase-admin/storage');
const { defaultQueue } = require('../services/jobQueue');
const { generateThumbnail, uploadThumbnail } = require('../services/image.service');
const WebSocketService = require('../services/websocket.service');

const scanInvoice = async (req, res) => {
    console.log(`📸 scanInvoice called with file: ${req.file?.originalname}`);
    if (!req.file) {
        return res.status(400).json({ message: 'No invoice file uploaded.' });
    }

    try {
        const userId = req.user?.uid || req.user?.id; 
        console.log(`📸 Processing for userId: ${userId}`);
        await userRepo.ensureAppUserExists(userId);

        // 1) İlk kayıt: uploading
        const createdAt = new Date();
        const baseRecord = {
            userId: userId,
            fileName: req.file.originalname,
            uploadedAt: createdAt,
            status: 'uploading',
            internalLogs: [`created: ${createdAt.toISOString()}`],
        };
        const created = await invoiceRepo.saveInvoice(baseRecord);

        let fileUrl = null;
        let thumbnailUrl = null;

        // 2) Dosyayı yükle -> queued
        try {
            const storage = getStorage();
            const bucket = storage.bucket();
            const fileName = `app_users/${userId}/invoices/${created.id}/${req.file.originalname}`;
            const storageFile = bucket.file(fileName);
            await storageFile.save(req.file.buffer, {
                metadata: {
                    contentType: req.file.mimetype,
                    metadata: {
                        originalName: req.file.originalname,
                        uploadedBy: userId,
                        uploadedAt: createdAt.toISOString(),
                        invoiceId: created.id
                    }
                }
            });
            await storageFile.makePublic();
            fileUrl = `https://storage.googleapis.com/${bucket.name}/${fileName}`;

            // Thumbnail üret ve kaydet
            console.log(`📸 Starting thumbnail generation for ${req.file.originalname}`);
            const thumbBuffer = await generateThumbnail(req.file.buffer, { mime: req.file.mimetype });
            const thumbPath = `app_users/${userId}/invoices/${created.id}/thumbnail.jpg`;
            
            // Yeni thumbnail upload fonksiyonunu kullan
            const thumbnailResult = await uploadThumbnail(thumbBuffer, thumbPath, {
                metadata: {
                    originalName: req.file.originalname,
                    uploadedBy: userId,
                    uploadedAt: createdAt.toISOString(),
                    invoiceId: created.id
                }
            });
            
            thumbnailUrl = thumbnailResult.signedUrl;
            console.log(`📸 Thumbnail created: ${thumbnailUrl}`);

            await invoiceRepo.updateInvoice(userId, created.id, {
                status: 'queued',
                fileUrl: fileUrl,
                thumbnailUrl: thumbnailUrl,
                internalLogs: [...(created.internalLogs || []), `fileUploaded: ${new Date().toISOString()}`]
            });

            // WebSocket bildirimi gönder
            WebSocketService.sendInvoiceStatusUpdate(userId, created.id, 'queued');
        } catch (storageError) {
            await invoiceRepo.updateInvoice(userId, created.id, {
                status: 'failed',
                errors: [{ code: 'STORAGE_UPLOAD_FAILED', message: storageError.message }],
                internalLogs: [...(created.internalLogs || []), `uploadError: ${storageError.message}`]
            });
            return res.status(500).json({ message: 'File upload failed.', error: storageError.message, data: { id: created.id } });
        }

        // 3) İşleme başla -> processing (senkron akış)
        const processingStart = Date.now();
        await invoiceRepo.updateInvoice(userId, created.id, {
            status: 'processing',
            internalLogs: [
                ...(created.internalLogs || []),
                `processingStart: ${new Date(processingStart).toISOString()}`
            ]
        });

        // WebSocket bildirimi gönder
        WebSocketService.sendInvoiceStatusUpdate(userId, created.id, 'processing');

        try {
            const processedData = await invoiceService.processWithPython(req.file);
            const processingEnd = Date.now();
            const processingMs = processingEnd - processingStart;

            await invoiceRepo.updateInvoice(userId, created.id, {
                status: 'processed',
                structured: (processedData && (processedData.structured || processedData.yapilandirilmis_veri)) || processedData || {},
                ocrText: processedData?.ocrText,
                lastProcessedAt: new Date(),
                processingMs,
                internalLogs: [
                    `processingEnd: ${new Date(processingEnd).toISOString()}`,
                    `processingMs: ${processingMs}`
                ]
            });

            // WebSocket bildirimi gönder
            WebSocketService.sendInvoiceStatusUpdate(userId, created.id, 'processed');

            return res.status(200).json({ 
                message: 'Invoice processed and saved successfully.', 
                data: { id: created.id, fileUrl }
            });
        } catch (error) {
            await invoiceRepo.updateInvoice(userId, created.id, {
                status: 'failed',
                errors: [{ code: 'PARSER_FAILED', message: error.message }],
                internalLogs: [`parserError: ${error.message}`]
            });
            return res.status(500).json({ message: 'Failed to process invoice.', error: error.message, data: { id: created.id } });
        }

    } catch (error) {
        console.error('Error in scanInvoice controller:', error.message);
        res.status(500).json({ message: 'Failed to process invoice.', error: error.message });
    }
};

const scanInvoiceBackground = async (req, res) => {
    console.log(`📸 scanInvoiceBackground called with file: ${req.file?.originalname}`);
    if (!req.file) {
        return res.status(400).json({ message: 'No invoice file uploaded.' });
    }

    try {
        const userId = req.user?.uid || req.user?.id;
        console.log(`📸 Background processing for userId: ${userId}`);
        const jobId = `job_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

        // İlk kayıt: uploading + jobId
        const createdAt = new Date();
        const baseRecord = {
            userId: userId,
            fileName: req.file.originalname,
            uploadedAt: createdAt,
            status: 'uploading',
            jobId,
            internalLogs: [`created: ${createdAt.toISOString()}`],
        };
        const created = await invoiceRepo.saveInvoice(baseRecord);

        res.status(202).json({ 
            message: 'Invoice processing started in background.', 
            jobId,
            invoiceId: created.id,
            status: 'uploading'
        });

        // Kuyruk üzerinden arka plan işlemi başlat
        defaultQueue.add({
            name: 'process-invoice',
            payload: { file: req.file, userId, jobId, invoiceId: created.id, initialLogs: baseRecord.internalLogs },
            handler: async ({ file, userId, jobId, invoiceId, initialLogs }) => {
                await processInvoiceInBackground(file, userId, jobId, invoiceId, initialLogs);
            }
        });
    } catch (error) {
        console.error('Error in scanInvoiceBackground controller:', error.message);
        res.status(500).json({ message: 'Failed to start invoice processing.', error: error.message });
    }
};

const processInvoiceInBackground = async (file, userId, jobId, invoiceId, initialLogs = []) => {
    try {
        await userRepo.ensureAppUserExists(userId);

        // Dosya yükle -> queued
        let fileUrl = null;
        try {
            const storage = getStorage();
            const bucket = storage.bucket();
            const fileName = `app_users/${userId}/invoices/${invoiceId}/${file.originalname}`;
            const storageFile = bucket.file(fileName);
            await storageFile.save(file.buffer, {
                metadata: {
                    contentType: file.mimetype,
                    metadata: {
                        originalName: file.originalname,
                        uploadedBy: userId,
                        uploadedAt: new Date().toISOString(),
                        jobId,
                        invoiceId
                    }
                }
            });
            await storageFile.makePublic();
            fileUrl = `https://storage.googleapis.com/${bucket.name}/${fileName}`;

            // Thumbnail üret ve kaydet
            console.log(`📸 Starting thumbnail generation for ${file.originalname}`);
            const thumbBuffer = await generateThumbnail(file.buffer, { mime: file.mimetype });
            const thumbPath = `app_users/${userId}/invoices/${invoiceId}/thumbnail.jpg`;
            
            // Yeni thumbnail upload fonksiyonunu kullan
            const thumbnailResult = await uploadThumbnail(thumbBuffer, thumbPath, {
                metadata: {
                    originalName: file.originalname,
                    uploadedBy: userId,
                    uploadedAt: new Date().toISOString(),
                    jobId,
                    invoiceId
                }
            });
            
            const thumbnailUrl = thumbnailResult.signedUrl;
            console.log(`📸 Thumbnail created: ${thumbnailUrl}`);

            await invoiceRepo.updateInvoice(userId, invoiceId, {
                status: 'queued',
                fileUrl,
                thumbnailUrl,
                internalLogs: [...initialLogs, `fileUploaded: ${new Date().toISOString()}`]
            });
        } catch (storageError) {
            await invoiceRepo.updateInvoice(userId, invoiceId, {
                status: 'failed',
                errors: [{ code: 'STORAGE_UPLOAD_FAILED', message: storageError.message }],
                internalLogs: [...initialLogs, `uploadError: ${storageError.message}`]
            });
            return;
        }

        // İşleme başla -> processing
        const processingStart = Date.now();
        await invoiceRepo.updateInvoice(userId, invoiceId, {
            status: 'processing',
            internalLogs: [...initialLogs, `processingStart: ${new Date(processingStart).toISOString()}`]
        });

        try {
            const processedData = await invoiceService.processWithPython(file);
            const processingEnd = Date.now();
            const processingMs = processingEnd - processingStart;

            await invoiceRepo.updateInvoice(userId, invoiceId, {
                status: 'processed',
                structured: (processedData && (processedData.structured || processedData.yapilandirilmis_veri)) || processedData || {},
                ocrText: processedData?.ocrText,
                lastProcessedAt: new Date(),
                processingMs,
                internalLogs: [`processingEnd: ${new Date(processingEnd).toISOString()}`, `processingMs: ${processingMs}`]
            });
        } catch (error) {
            await invoiceRepo.updateInvoice(userId, invoiceId, {
                status: 'failed',
                errors: [{ code: 'PARSER_FAILED', message: error.message }],
                internalLogs: [`parserError: ${error.message}`]
            });
        }
    } catch (error) {
        console.error(`Background processing fatal for job ${jobId}:`, error.message);
        try {
            await invoiceRepo.updateInvoice(userId, invoiceId, {
                status: 'failed',
                errors: [{ code: 'UNCAUGHT', message: error.message }]
            });
        } catch (_) {}
    }
};

const getInvoices = async (req, res) => {
    try {
        const userId = req.user?.uid || req.user?.id;
        const invoices = await invoiceRepo.getInvoicesByUserId(userId);
        console.log(`📋 All invoices response:`, invoices.map(i => ({ id: i.id, thumbnailUrl: i.thumbnailUrl })));
        res.status(200).json({ invoices });
    } catch (error) {
        console.error('Error in getInvoices controller:', error.message);
        res.status(500).json({ message: 'Failed to retrieve invoices.', error: error.message });
    }
};

// Geçici: Paket mimarisi gelene kadar kullanıcı bazında tüm faturaları tek JSON olarak döndür
const exportInvoicesJson = async (req, res) => {
    try {
        const userId = req.user?.uid || req.user?.id;
        const invoices = await invoiceRepo.getInvoicesByUserId(userId);

        const payload = {
            userId,
            exportedAt: new Date().toISOString(),
            invoiceCount: invoices.length,
            invoices: invoices.map(inv => ({
                id: inv.id,
                originalName: inv.fileName,
                status: inv.status,
                uploadedAt: inv.uploadedAt,
                lastProcessedAt: inv.lastProcessedAt,
                processingMs: inv.processingMs,
                fileUrl: inv.fileUrl,
                thumbnailUrl: inv.thumbnailUrl,
                structured: inv.structured || {},
            }))
        };

        // Not: Büyük veri setlerinde streaming/export dosyası oluşturma tercih edilmeli (V2)
        res.setHeader('Content-Type', 'application/json');
        return res.status(200).send(JSON.stringify(payload));
    } catch (error) {
        console.error('Error in exportInvoicesJson controller:', error.message);
        res.status(500).json({ message: 'Failed to export invoices.', error: error.message });
    }
};

// Fatura detayını getir (packageId verilirse paket altından okur)
const getInvoiceDetail = async (req, res) => {
    try {
        const userId = req.user?.uid || req.user?.id;
        const { invoiceId } = req.params;
        const { packageId } = req.query;

        let invoice = null;
        if (packageId) {
            const admin = require('firebase-admin');
            const db = admin.firestore();
            const doc = await db
                .collection('app_users').doc(userId)
                .collection('packages').doc(packageId)
                .collection('invoices').doc(invoiceId)
                .get();
            if (doc.exists) {
                invoice = { id: doc.id, userId, packageId, ...doc.data() };
            }
        } else {
            invoice = await invoiceRepo.getInvoiceById(userId, invoiceId);
        }

        if (!invoice) {
            return res.status(404).json({ message: 'Invoice not found.' });
        }

        res.status(200).json({ invoice });
    } catch (error) {
        console.error('Error in getInvoiceDetail controller:', error.message);
        res.status(500).json({ message: 'Failed to retrieve invoice detail.', error: error.message });
    }
};

// Fatura verilerini güncelle (packageId verilirse paket altını günceller)
const updateInvoiceData = async (req, res) => {
    try {
        const userId = req.user?.uid || req.user?.id;
        const { invoiceId } = req.params;
        const { structured, isApproved } = req.body;
        const { packageId } = req.query;
        
        const updateData = {
            lastUpdatedAt: new Date(),
            internalLogs: [`manualUpdate: ${new Date().toISOString()}`]
        };
        
        if (structured) {
            updateData.structured = structured;
            updateData.isManuallyEdited = true;
        }
        
        if (isApproved !== undefined) {
            updateData.isApproved = isApproved;
            updateData.approvedAt = isApproved ? new Date() : null;
            updateData.approvedBy = isApproved ? userId : null;
            
            // Status'u da güncelle
            if (isApproved) {
                updateData.status = 'approved';
            } else {
                updateData.status = 'processed'; // Onay kaldırıldığında processed'e geri dön
            }
        }

        let updatedInvoice = null;
        if (packageId) {
            const admin = require('firebase-admin');
            const db = admin.firestore();
            await db
                .collection('app_users').doc(userId)
                .collection('packages').doc(packageId)
                .collection('invoices').doc(invoiceId)
                .update(updateData);
            
            // Package counter'larını güncelle
            if (isApproved !== undefined) {
                const packageRepo = require('../db/package.repo');
                await packageRepo.incrementCounters(userId, packageId, { 
                    approved: isApproved ? 1 : -1 
                });
            }
            
            updatedInvoice = { id: invoiceId, userId, packageId, ...updateData };
        } else {
            updatedInvoice = await invoiceRepo.updateInvoice(userId, invoiceId, updateData);
        }

        res.status(200).json({ 
            message: 'Invoice updated successfully.',
            invoice: updatedInvoice
        });
    } catch (error) {
        console.error('Error in updateInvoiceData controller:', error.message);
        res.status(500).json({ message: 'Failed to update invoice.', error: error.message });
    }
};

// Fatura istatistiklerini getir
const getInvoiceStats = async (req, res) => {
    try {
        const userId = req.user?.uid || req.user?.id;
        
        // Tüm paketlerdeki faturaları say
        const admin = require('firebase-admin');
        const db = admin.firestore();
        
        const packagesSnapshot = await db
            .collection('app_users').doc(userId)
            .collection('packages')
            .get();
        
        let totalProcessed = 0;
        let totalApproved = 0;
        let totalPending = 0;
        let totalFailed = 0;
        
        for (const packageDoc of packagesSnapshot.docs) {
            const invoicesSnapshot = await packageDoc.ref
                .collection('invoices')
                .get();
            
            invoicesSnapshot.docs.forEach(doc => {
                const invoice = doc.data();
                if (invoice.status === 'processed' && !invoice.isApproved) {
                    totalProcessed++;
                } else if (invoice.status === 'approved' || (invoice.status === 'processed' && invoice.isApproved)) {
                    totalApproved++;
                } else if (['processing', 'uploading', 'queued'].includes(invoice.status)) {
                    totalPending++;
                } else if (invoice.status === 'failed') {
                    totalFailed++;
                }
            });
        }
        
        res.status(200).json({
            success: true,
            stats: {
                processed: totalProcessed,
                approved: totalApproved,
                pending: totalPending,
                failed: totalFailed
            }
        });
    } catch (error) {
        console.error('Error in getInvoiceStats controller:', error.message);
        res.status(500).json({ 
            success: false,
            message: 'Failed to get invoice stats.', 
            error: error.message 
        });
    }
};

module.exports = {
    scanInvoice,
    scanInvoiceBackground,
    getInvoices,
    exportInvoicesJson,
    getInvoiceDetail,
    updateInvoiceData,
    getInvoiceStats,
};
