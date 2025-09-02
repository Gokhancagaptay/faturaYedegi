const WebSocket = require('ws');
const jwt = require('jsonwebtoken');
require('dotenv').config(); // .env dosyasını yükle

class WebSocketService {
    constructor() {
        this.wss = null;
        this.clients = new Map(); // userId -> WebSocket bağlantıları
        this.authenticatedClients = new Map(); // token -> { userId, ws }
    }

    // WebSocket sunucusunu başlat
    initialize(server) {
        this.wss = new WebSocket.Server({ 
            server,
            path: '/ws'
        });

        this.wss.on('connection', (ws, req) => {
            this.handleConnection(ws, req);
        });

        console.log('🔌 WebSocket sunucusu başlatıldı');
    }

    // Yeni bağlantıyı işle
    handleConnection(ws, req) {
        console.log('🔌 Yeni WebSocket bağlantısı');

        // URL'den token ve userId'yi al
        const url = new URL(req.url, 'http://localhost');
        const token = url.searchParams.get('token');
        const userId = url.searchParams.get('userId');

        if (!token || !userId) {
            console.log('❌ WebSocket: Token veya userId eksik');
            ws.close(1008, 'Token veya userId eksik');
            return;
        }

        // Token'ı doğrula
        try {
            const decoded = jwt.verify(token, process.env.JWT_SECRET);
            if (decoded.uid !== userId) {
                console.log('❌ WebSocket: Token userId uyuşmazlığı');
                ws.close(1008, 'Token userId uyuşmazlığı');
                return;
            }

            // Bağlantıyı kaydet
            this.authenticatedClients.set(token, { userId, ws });
            
            // Kullanıcının bağlantılarını kaydet
            if (!this.clients.has(userId)) {
                this.clients.set(userId, new Set());
            }
            this.clients.get(userId).add(ws);

            console.log(`✅ WebSocket: Kullanıcı ${userId} bağlandı`);

            // Bağlantı mesajını gönder
            this.sendToClient(ws, {
                type: 'connected',
                userId: userId,
                timestamp: new Date().toISOString()
            });

        } catch (error) {
            console.log('❌ WebSocket: Token doğrulama hatası', error.message);
            ws.close(1008, 'Token doğrulama hatası');
            return;
        }

        // Mesaj dinle
        ws.on('message', (message) => {
            this.handleMessage(ws, message, userId);
        });

        // Bağlantı kapanma
        ws.on('close', () => {
            this.handleDisconnection(ws, userId, token);
        });

        // Hata durumu
        ws.on('error', (error) => {
            console.log('❌ WebSocket hatası:', error.message);
            this.handleDisconnection(ws, userId, token);
        });
    }

    // Gelen mesajı işle
    handleMessage(ws, message, userId) {
        try {
            const data = JSON.parse(message);
            console.log(`📨 WebSocket mesajı (${userId}):`, data.type);

            switch (data.type) {
                case 'listen_invoice':
                    this.handleListenInvoice(ws, data.invoiceId, userId);
                    break;
                case 'listen_package':
                    this.handleListenPackage(ws, data.packageId, userId);
                    break;
                case 'listen_all_invoices':
                    this.handleListenAllInvoices(ws, userId);
                    break;
                default:
                    console.log('❌ Bilinmeyen WebSocket mesaj tipi:', data.type);
            }
        } catch (error) {
            console.log('❌ WebSocket mesaj işleme hatası:', error.message);
        }
    }

    // Fatura dinleme
    handleListenInvoice(ws, invoiceId, userId) {
        console.log(`👂 Kullanıcı ${userId} fatura ${invoiceId} dinliyor`);
        // Burada fatura durumu değişikliklerini dinleyebiliriz
    }

    // Paket dinleme
    handleListenPackage(ws, packageId, userId) {
        console.log(`👂 Kullanıcı ${userId} paket ${packageId} dinliyor`);
        // Burada paket durumu değişikliklerini dinleyebiliriz
    }

    // Tüm faturaları dinleme
    handleListenAllInvoices(ws, userId) {
        console.log(`👂 Kullanıcı ${userId} tüm faturaları dinliyor`);
        // Burada tüm fatura durumu değişikliklerini dinleyebiliriz
    }

    // Bağlantı kapanma
    handleDisconnection(ws, userId, token) {
        console.log(`🔌 WebSocket: Kullanıcı ${userId} bağlantısı kapandı`);

        // Kullanıcının bağlantılarını temizle
        if (this.clients.has(userId)) {
            this.clients.get(userId).delete(ws);
            if (this.clients.get(userId).size === 0) {
                this.clients.delete(userId);
            }
        }

        // Authenticated clients'tan kaldır
        this.authenticatedClients.delete(token);
    }

    // Belirli bir client'a mesaj gönder
    sendToClient(ws, message) {
        if (ws.readyState === WebSocket.OPEN) {
            try {
                ws.send(JSON.stringify(message));
            } catch (error) {
                console.log('❌ WebSocket mesaj gönderme hatası:', error.message);
            }
        }
    }

    // Belirli bir kullanıcıya mesaj gönder
    sendToUser(userId, message) {
        if (this.clients.has(userId)) {
            const userConnections = this.clients.get(userId);
            userConnections.forEach(ws => {
                this.sendToClient(ws, message);
            });
        }
    }

    // Tüm kullanıcılara mesaj gönder
    broadcast(message) {
        this.wss.clients.forEach(client => {
            if (client.readyState === WebSocket.OPEN) {
                this.sendToClient(client, message);
            }
        });
    }

    // Fatura durumu güncellemesi gönder
    sendInvoiceStatusUpdate(userId, invoiceId, status, packageId = null) {
        const message = {
            type: 'invoice_status_update',
            invoiceId: invoiceId,
            status: status,
            packageId: packageId,
            timestamp: new Date().toISOString()
        };

        this.sendToUser(userId, message);
        console.log(`📊 Fatura durumu güncellendi: ${invoiceId} -> ${status}`);
    }

    // Paket durumu güncellemesi gönder
    sendPackageStatusUpdate(userId, packageId, status) {
        const message = {
            type: 'package_status_update',
            packageId: packageId,
            status: status,
            timestamp: new Date().toISOString()
        };

        this.sendToUser(userId, message);
        console.log(`📦 Paket durumu güncellendi: ${packageId} -> ${status}`);
    }

    // İşlem ilerlemesi gönder
    sendProcessingProgress(userId, progress, packageId = null) {
        const message = {
            type: 'processing_progress',
            progress: progress,
            packageId: packageId,
            timestamp: new Date().toISOString()
        };

        this.sendToUser(userId, message);
        console.log(`⚙️ İşlem ilerlemesi: %${progress}`);
    }

    // Sunucuyu kapat
    close() {
        if (this.wss) {
            this.wss.close();
            console.log('🔌 WebSocket sunucusu kapatıldı');
        }
    }
}

module.exports = new WebSocketService();
