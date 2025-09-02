const sharp = require('sharp');
const fs = require('fs');
const path = require('path');
const os = require('os');
const { getStorage } = require('firebase-admin/storage');
const { execFile } = require('child_process');

// Buffer -> thumbnail buffer (küçük boyutlu jpg)
// PDF dosyaları için gerçek ilk sayfa görüntüsü oluşturur
async function generateThumbnail(buffer, options = {}) {
    console.log('🖼️ generateThumbnail called with mime:', options.mime);
    const width = options.width ?? 1200; // Detay ekranı için maksimum kalite
    const quality = options.quality ?? 95; // Maksimum kalite
    const mime = options.mime ?? '';

    const isPdf = (typeof mime === 'string' && mime.toLowerCase().includes('pdf'))
        || buffer.slice(0, 4).toString() === '%PDF';

    console.log('🖼️ isPdf:', isPdf, 'mime:', mime, 'buffer size:', buffer.length);

    if (isPdf) {
        console.log('🖼️ Processing PDF for thumbnail generation');
        
        // 1. Yöntem: Poppler ile PDF -> PNG
        try {
            const pdfImageBuffer = await renderPdfWithPoppler(buffer);
            if (pdfImageBuffer && pdfImageBuffer.length > 1000) { // En az 1KB olmalı
                console.log('🖼️ PDF converted to image with poppler, size:', pdfImageBuffer.length);
                const thumbnail = await sharp(pdfImageBuffer)
                    .resize({ width, withoutEnlargement: true })
                    .jpeg({ quality })
                    .toBuffer();
                console.log('🖼️ PDF thumbnail created successfully, size:', thumbnail.length);
                return thumbnail;
            } else {
                console.log('🖼️ Poppler conversion returned null or too small, trying alternative');
            }
        } catch (pdfError) {
            console.error('🖼️ Poppler PDF thumbnail generation failed:', pdfError);
        }
        
        // 2. Yöntem: Alternatif yöntem
        try {
            const pdfImageBuffer = await renderPdfWithAlternative(buffer);
            if (pdfImageBuffer && pdfImageBuffer.length > 1000) {
                console.log('🖼️ PDF converted to image with alternative method, size:', pdfImageBuffer.length);
                const thumbnail = await sharp(pdfImageBuffer)
                    .resize({ width, withoutEnlargement: true })
                    .jpeg({ quality })
                    .toBuffer();
                console.log('🖼️ PDF thumbnail created successfully with alternative method, size:', thumbnail.length);
                return thumbnail;
            } else {
                console.log('🖼️ Alternative conversion returned null or too small');
            }
        } catch (altError) {
            console.error('🖼️ Alternative PDF thumbnail generation failed:', altError);
        }
        
        // 3. Yöntem: Sharp ile doğrudan PDF işleme
        try {
            console.log('🖼️ Trying direct Sharp PDF processing...');
            const thumbnail = await sharp(buffer, { page: 0 })
                .resize({ width, withoutEnlargement: true })
                .jpeg({ quality })
                .toBuffer();
            console.log('🖼️ Direct Sharp PDF processing successful, size:', thumbnail.length);
            return thumbnail;
        } catch (sharpError) {
            console.error('🖼️ Direct Sharp PDF processing failed:', sharpError);
        }
        
        // Son çare: PDF placeholder oluştur
        console.log('🖼️ All PDF processing methods failed, creating fallback placeholder');
        const placeholder = await createPdfPlaceholder(width, quality);
        console.log('🖼️ PDF fallback placeholder created, size:', placeholder.length);
        return placeholder;
    }

    // Normal görüntü dosyaları için
    try {
        return await sharp(buffer)
            .resize({ width, withoutEnlargement: true })
            .jpeg({ quality })
            .toBuffer();
    } catch (err) {
        console.error('🖼️ Image processing failed:', err);
        // Desteklenmeyen formatlar için son çare placeholder
        const placeholder = await createPdfPlaceholder(width, quality);
        return placeholder;
    }
}

// PDF placeholder oluştur (PDF ikonu ile)
async function createPdfPlaceholder(width, quality) {
    try {
        // PDF ikonu ile placeholder oluştur
        const svgIcon = `
        <svg width="${width}" height="${Math.round(width * 1.33)}" xmlns="http://www.w3.org/2000/svg">
            <rect width="100%" height="100%" fill="#f3f4f6"/>
            <rect x="20%" y="30%" width="60%" height="40%" fill="#dc2626" rx="8"/>
            <text x="50%" y="45%" text-anchor="middle" fill="white" font-family="Arial" font-size="${width * 0.15}">PDF</text>
            <text x="50%" y="60%" text-anchor="middle" fill="white" font-family="Arial" font-size="${width * 0.08}">Dosya</text>
        </svg>
        `;
        
        return await sharp(Buffer.from(svgIcon))
            .jpeg({ quality })
            .toBuffer();
    } catch (error) {
        console.error('🖼️ Placeholder creation failed:', error);
        // En basit placeholder
        return await sharp({
            create: {
                width: width,
                height: Math.round(width * 1.33),
                channels: 3,
                background: '#f3f4f6',
            },
        })
            .jpeg({ quality })
            .toBuffer();
    }
}

// Alternatif PDF işleme yöntemi - pdf2pic kullanarak
async function renderPdfWithAlternative(pdfBuffer) {
    console.log('🖼️ Trying alternative PDF rendering method...');
    
    try {
        // Sharp ile doğrudan PDF işleme (eğer destekleniyorsa)
        const image = await sharp(pdfBuffer, { page: 0 })
            .resize(800, 600, { fit: 'inside', withoutEnlargement: true })
            .png()
            .toBuffer();
        
        console.log('🖼️ Alternative PDF rendering successful, size:', image.length);
        return image;
    } catch (error) {
        console.error('🖼️ Alternative PDF rendering failed:', error);
        return null;
    }
}

// poppler-utils (pdftoppm) ile PDF -> PNG
async function renderPdfWithPoppler(pdfBuffer) {
    console.log('🖼️ Starting PDF to PNG conversion with poppler...');
    
    const tempDir = os.tmpdir();
    const timestamp = Date.now();
    const tempPdf = path.join(tempDir, `thumb_${timestamp}.pdf`);
    const outPrefix = path.join(tempDir, `thumb_${timestamp}`);
    const outPng = `${outPrefix}-1.png`;

    console.log('🖼️ Temp files:', { tempPdf, outPng });

    try {
        // PDF buffer'ını geçici dosyaya yaz
        fs.writeFileSync(tempPdf, pdfBuffer);
        console.log('🖼️ PDF file written to temp location, size:', pdfBuffer.length);

        // pdftoppm ile PDF'i PNG'e çevir - daha detaylı hata yakalama
        await new Promise((resolve, reject) => {
            console.log('🖼️ Running pdftoppm command with args:', ['-singlefile', '-png', '-r', '200', tempPdf, outPrefix]);
            
            const child = execFile('pdftoppm', ['-singlefile', '-png', '-r', '200', tempPdf, outPrefix], (err, stdout, stderr) => {
                if (err) {
                    console.error('🖼️ pdftoppm error:', err);
                    console.error('🖼️ pdftoppm stderr:', stderr);
                    console.error('🖼️ pdftoppm stdout:', stdout);
                    return reject(err);
                }
                console.log('🖼️ pdftoppm stdout:', stdout);
                console.log('🖼️ pdftoppm stderr:', stderr);
                resolve();
            });

            // Timeout ekle (10 saniye)
            setTimeout(() => {
                child.kill();
                reject(new Error('pdftoppm timeout'));
            }, 10000);
        });

        // -singlefile parametresi ile dosya adı farklı olabilir, kontrol et
        const possiblePngFiles = [
            outPng, // test-1.png
            `${outPrefix}.png`, // test.png
            `${outPrefix}-1.png`, // test-1.png (alternatif)
        ];
        
        let pngFile = null;
        for (const file of possiblePngFiles) {
            if (fs.existsSync(file)) {
                pngFile = file;
                console.log('🖼️ Found PNG file:', pngFile);
                break;
            }
        }

        // Oluşturulan PNG dosyasını oku
        if (pngFile) {
            const img = fs.readFileSync(pngFile);
            console.log('🖼️ PNG file read successfully, size:', img.length);
            
            // Geçici dosyaları temizle
            try { 
                fs.unlinkSync(tempPdf); 
                console.log('🖼️ Temp PDF file cleaned up');
            } catch (cleanupError) {
                console.warn('🖼️ PDF cleanup warning:', cleanupError.message);
            }
            try { 
                fs.unlinkSync(pngFile); 
                console.log('🖼️ Temp PNG file cleaned up');
            } catch (cleanupError) {
                console.warn('🖼️ PNG cleanup warning:', cleanupError.message);
            }
            
            return img;
        } else {
            console.error('🖼️ PNG file not found. Checked files:', possiblePngFiles);
            // Dosya listesini kontrol et
            try {
                const files = fs.readdirSync(tempDir);
                console.log('🖼️ Temp directory contents:', files.filter(f => f.includes(`thumb_${timestamp}`)));
            } catch (listError) {
                console.error('🖼️ Could not list temp directory:', listError.message);
            }
            throw new Error('PNG file not created');
        }
    } catch (error) {
        console.error('🖼️ PDF to PNG conversion failed:', error);
        
        // Geçici dosyaları temizle (hata durumunda da)
        try { 
            if (fs.existsSync(tempPdf)) {
                fs.unlinkSync(tempPdf); 
                console.log('🖼️ Temp PDF file cleaned up after error');
            }
        } catch (cleanupError) {
            console.warn('🖼️ PDF cleanup error:', cleanupError.message);
        }
        try { 
            if (fs.existsSync(outPng)) {
                fs.unlinkSync(outPng); 
                console.log('🖼️ Temp PNG file cleaned up after error');
            }
        } catch (cleanupError) {
            console.warn('🖼️ PNG cleanup error:', cleanupError.message);
        }
        
        return null;
    }
}

// Firebase Storage'da dosya yükleme ve signed URL oluşturma
async function uploadFileToStorage(buffer, filePath, contentType, options = {}) {
    try {
        console.log('🖼️ Starting file upload to Firebase Storage:', filePath);
        
        const storage = getStorage();
        const bucket = storage.bucket();
        const file = bucket.file(filePath);
        
        // Dosyayı yükle
        await file.save(buffer, { 
            metadata: { 
                contentType: contentType,
                cacheControl: 'public, max-age=31536000', // 1 yıl cache
                ...options.metadata
            } 
        });
        console.log('🖼️ File saved to Firebase Storage');
        
        // Public erişim için makePublic() çağır
        await file.makePublic();
        console.log('🖼️ File made public');
        
        // Signed URL oluştur (7 gün geçerli)
        const [signedUrl] = await file.getSignedUrl({
            action: 'read',
            expires: Date.now() + 7 * 24 * 60 * 60 * 1000, // 7 gün
        });
        console.log('🖼️ Signed URL created');
        
        console.log(`🖼️ File uploaded successfully: ${filePath}`);
        console.log(`🖼️ Signed URL created: ${signedUrl}`);
        
        return {
            publicUrl: `https://storage.googleapis.com/${bucket.name}/${filePath}`,
            signedUrl: signedUrl
        };
    } catch (error) {
        console.error('🖼️ File upload failed:', error);
        throw error;
    }
}

// Thumbnail yükleme ve URL döndürme
async function uploadThumbnail(thumbnailBuffer, filePath, options = {}) {
    console.log('🖼️ Uploading thumbnail:', filePath, 'size:', thumbnailBuffer.length);
    return await uploadFileToStorage(
        thumbnailBuffer, 
        filePath, 
        'image/jpeg',
        {
            metadata: {
                thumbnail: 'true',
                ...options.metadata
            }
        }
    );
}

// Detay ekranı için yüksek kaliteli thumbnail oluştur
async function generateDetailThumbnail(buffer, options = {}) {
    console.log('🖼️ generateDetailThumbnail called with mime:', options.mime);
    const width = options.width ?? 800; // detay ekranı için daha büyük
    const quality = options.quality ?? 85; // daha yüksek kalite
    const mime = options.mime ?? '';

    const isPdf = (typeof mime === 'string' && mime.toLowerCase().includes('pdf'))
        || buffer.slice(0, 4).toString() === '%PDF';

    console.log('🖼️ isPdf:', isPdf, 'mime:', mime, 'buffer size:', buffer.length);

    if (isPdf) {
        console.log('🖼️ Processing PDF for detail thumbnail generation');
        
        // 1. Yöntem: Poppler ile PDF -> PNG
        try {
            const pdfImageBuffer = await renderPdfWithPoppler(buffer);
            if (pdfImageBuffer && pdfImageBuffer.length > 1000) { // En az 1KB olmalı
                console.log('🖼️ PDF converted to image with poppler, size:', pdfImageBuffer.length);
                const thumbnail = await sharp(pdfImageBuffer)
                    .resize({ width, withoutEnlargement: true })
                    .jpeg({ quality })
                    .toBuffer();
                console.log('🖼️ PDF detail thumbnail created successfully, size:', thumbnail.length);
                return thumbnail;
            } else {
                console.log('🖼️ Poppler conversion returned null or too small, trying alternative');
            }
        } catch (pdfError) {
            console.error('🖼️ Poppler PDF detail thumbnail generation failed:', pdfError);
        }
        
        // 2. Yöntem: Alternatif yöntem
        try {
            const pdfImageBuffer = await renderPdfWithAlternative(buffer);
            if (pdfImageBuffer && pdfImageBuffer.length > 1000) {
                console.log('🖼️ PDF converted to image with alternative method, size:', pdfImageBuffer.length);
                const thumbnail = await sharp(pdfImageBuffer)
                    .resize({ width, withoutEnlargement: true })
                    .jpeg({ quality })
                    .toBuffer();
                console.log('🖼️ PDF detail thumbnail created successfully with alternative method, size:', thumbnail.length);
                return thumbnail;
            } else {
                console.log('🖼️ Alternative conversion returned null or too small');
            }
        } catch (altError) {
            console.error('🖼️ Alternative PDF detail thumbnail generation failed:', altError);
        }
        
        // 3. Yöntem: Sharp ile doğrudan PDF işleme
        try {
            console.log('🖼️ Trying direct Sharp PDF processing for detail...');
            const thumbnail = await sharp(buffer, { page: 0 })
                .resize({ width, withoutEnlargement: true })
                .jpeg({ quality })
                .toBuffer();
            console.log('🖼️ Direct Sharp PDF processing successful for detail, size:', thumbnail.length);
            return thumbnail;
        } catch (sharpError) {
            console.error('🖼️ Direct Sharp PDF processing failed for detail:', sharpError);
        }
        
        // Son çare: PDF placeholder oluştur
        console.log('🖼️ All PDF processing methods failed for detail, creating fallback placeholder');
        const placeholder = await createPdfPlaceholder(width, quality);
        console.log('🖼️ PDF detail fallback placeholder created, size:', placeholder.length);
        return placeholder;
    }

    // Normal görüntü dosyaları için
    try {
        return await sharp(buffer)
            .resize({ width, withoutEnlargement: true })
            .jpeg({ quality })
            .toBuffer();
    } catch (err) {
        console.error('🖼️ Image processing failed for detail:', err);
        // Desteklenmeyen formatlar için son çare placeholder
        const placeholder = await createPdfPlaceholder(width, quality);
        return placeholder;
    }
}

module.exports = {
    generateThumbnail,
    generateDetailThumbnail,
    uploadFileToStorage,
    uploadThumbnail,
};
