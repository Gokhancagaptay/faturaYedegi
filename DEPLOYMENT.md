# 🚀 Ücretsiz Deployment Rehberi - Render.com

Bu dokümantasyon, Fatura Yeni uygulamanızı Render.com üzerinde ücretsiz olarak deploy etmek için adım adım talimatlar içerir.

## 📋 Ön Gereksinimler

1. **GitHub Hesabı**: Kodunuzun GitHub'da olması gerekiyor
2. **Render.com Hesabı**: [render.com](https://render.com) üzerinde ücretsiz hesap oluşturun
3. **Firebase Projesi**: Firebase Admin SDK için gerekli bilgiler

## 🎯 Deployment Adımları

### 1. GitHub'a Kod Yükleme

Eğer kodunuz henüz GitHub'da değilse:

```bash
# Git repository oluştur
git init
git add .
git commit -m "Initial commit - Ready for deployment"

# GitHub'da yeni repository oluşturun, sonra:
git remote add origin https://github.com/kullaniciadi/fatura-yeni.git
git push -u origin main
```

### 2. Render.com'da Servisleri Oluşturma

#### A. Python OCR Parser Servisi

1. [Render.com Dashboard](https://dashboard.render.com)'a giriş yapın
2. **"New +"** butonuna tıklayın
3. **"Web Service"** seçin
4. GitHub repository'nizi bağlayın
5. Aşağıdaki ayarları yapın:

   **Name:** `fatura-parser`
   
   **Environment:** `Python 3`
   
   **Region:** Size en yakın bölgeyi seçin
   
   **Branch:** `main` (veya `master`)
   
   **Root Directory:** `fatura_parser_py` (veya boş bırakın, aşağıdaki komutlarda tam yol kullanın)
   
   **Build Command:**
   ```bash
   cd fatura_parser_py && pip install -r requirements.txt
   ```
   (Eğer Root Directory ayarlıysa sadece: `pip install -r requirements.txt`)
   
   **Start Command:**
   ```bash
   cd fatura_parser_py && gunicorn --bind 0.0.0.0:$PORT --workers 2 --timeout 120 app:app
   ```
   (Eğer Root Directory ayarlıysa sadece: `gunicorn --bind 0.0.0.0:$PORT --workers 2 --timeout 120 app:app`)
   
   **Plan:** `Free` (ücretsiz plan)

6. **"Advanced"** bölümüne gidin ve **Environment Variables** ekleyin:
   - `PORT`: `5001` (Render otomatik atar, ama belirtmekte fayda var)
   - `PYTHONUNBUFFERED`: `1`
   - `ANALYSIS_VERBOSE`: `false`

7. **"Create Web Service"** butonuna tıklayın

8. Deploy işlemi tamamlandığında, servisinizin URL'ini not edin (örn: `https://fatura-parser.onrender.com`)

#### B. Node.js Backend Servisi

1. Yine **"New +"** → **"Web Service"** seçin
2. Aynı GitHub repository'yi seçin
3. Aşağıdaki ayarları yapın:

   **Name:** `fatura-backend`
   
   **Environment:** `Node`
   
   **Region:** Parser ile aynı bölgeyi seçin
   
   **Branch:** `main` (veya `master`)
   
   **Root Directory:** `fatura_backend`
   
   **Build Command:**
   ```bash
   npm install
   ```
   
   **Start Command:**
   ```bash
   npm start
   ```
   
   **Plan:** `Free` (ücretsiz plan)

4. **"Advanced"** → **Environment Variables** ekleyin:
   - `PORT`: `3000`
   - `NODE_ENV`: `production`
   - `PARSER_URL`: `https://fatura-parser.onrender.com/parse_invoice` (Parser servisinin URL'i)
   
   **🔒 GÜVENLİK - ZORUNLU:**
   - `JWT_SECRET`: Güçlü bir rastgele string (en az 32 karakter). Oluşturmak için: `openssl rand -base64 32`
   - `ALLOWED_ORIGINS`: Flutter web uygulamanızın URL'leri (virgülle ayrılmış). Örn: `https://your-app.web.app,https://your-domain.com`
   
   **Firebase Admin SDK için gerekli değişkenler:**
   - `FIREBASE_PROJECT_ID`: Firebase projenizin ID'si
   - `FIREBASE_PRIVATE_KEY`: Firebase Admin SDK private key (tırnak işaretleri olmadan, `\n` karakterleri korunarak)
   - `FIREBASE_CLIENT_EMAIL`: Firebase Admin SDK client email

5. **"Create Web Service"** butonuna tıklayın

6. Deploy işlemi tamamlandığında, backend URL'ini not edin (örn: `https://fatura-backend.onrender.com`)

### 3. Firebase Admin SDK Bilgilerini Alma

1. [Firebase Console](https://console.firebase.google.com)'a gidin
2. Projenizi seçin
3. **Settings (⚙️)** → **Project Settings** → **Service Accounts** sekmesine gidin
4. **"Generate New Private Key"** butonuna tıklayın
5. İndirilen JSON dosyasını açın ve şu bilgileri alın:
   - `project_id` → `FIREBASE_PROJECT_ID`
   - `private_key` → `FIREBASE_PRIVATE_KEY` (tüm key'i kopyalayın, `\n` karakterleri dahil)
   - `client_email` → `FIREBASE_CLIENT_EMAIL`

### 4. Flutter Uygulamasını Güncelleme

1. Proje kök dizininde `.env` dosyası oluşturun (veya mevcut `.env` dosyasını düzenleyin):

```env
# Production Backend URL
API_BASE_URL=https://fatura-backend.onrender.com

# Production WebSocket URL (ws:// yerine wss:// kullanın)
WS_BASE_URL=wss://fatura-backend.onrender.com
```

2. `.env` dosyasını `.gitignore`'a ekleyin (eğer ekli değilse):

```gitignore
.env
```

3. `.env.example` dosyasını güncelleyin (örnek olarak):

```env
API_BASE_URL=https://your-backend-service.onrender.com
WS_BASE_URL=wss://your-backend-service.onrender.com
```

4. Flutter bağımlılıklarını yükleyin:

```bash
flutter pub get
```

### 5. Backend Health Check Endpoint Ekleme

Backend servisinize health check endpoint'i ekleyin (eğer yoksa):

`fatura_backend/src/server.js` dosyasına ekleyin:

```javascript
// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'OK', message: 'Backend is running' });
});
```

### 6. CORS Ayarlarını Kontrol Etme

Backend'inizde CORS ayarlarının production URL'lerini kabul ettiğinden emin olun:

`fatura_backend/src/server.js`:

```javascript
const corsOptions = {
  origin: [
    'http://localhost:3000',
    'https://your-flutter-web-app.web.app', // Flutter web app URL'iniz
    // Render.com URL'lerinizi ekleyin
  ],
  credentials: true,
};
app.use(cors(corsOptions));
```

## ⚠️ Önemli Notlar

### Render.com Free Plan Limitleri

1. **Sleep Mode**: 15 dakika kullanılmadığında servisler uyku moduna geçer
2. **Cold Start**: İlk istek 30-60 saniye sürebilir (uyku modundan uyanma)
3. **Build Time**: Her deploy'da build işlemi yapılır
4. **Bandwidth**: Aylık 100GB limit

### WebSocket Bağlantıları

Render.com free plan'da WebSocket desteği vardır, ancak:
- URL'ler `ws://` yerine `wss://` (secure WebSocket) kullanmalıdır
- Render.com otomatik olarak SSL sertifikası sağlar

### Environment Variables

- Hassas bilgileri (Firebase keys, API keys) asla kod içine yazmayın
- Render.com dashboard'dan environment variables ekleyin
- `.env` dosyasını `.gitignore`'a eklediğinizden emin olun

## 🔧 Sorun Giderme

### Backend'e Bağlanamıyorum

1. Render.com dashboard'da servislerin **"Live"** durumda olduğundan emin olun
2. Health check endpoint'ini test edin: `https://your-backend.onrender.com/health`
3. Logları kontrol edin: Render.com dashboard → Service → Logs

### Parser Servisi Çalışmıyor

1. Python servisinin loglarını kontrol edin
2. `requirements.txt` dosyasındaki tüm bağımlılıkların doğru olduğundan emin olun
3. Health check: `https://fatura-parser.onrender.com/health`

### Flutter Uygulaması Bağlanamıyor

1. `.env` dosyasındaki URL'lerin doğru olduğundan emin olun
2. `flutter clean` ve `flutter pub get` komutlarını çalıştırın
3. Uygulamayı yeniden build edin

## 📱 Mobil Uygulama Build

Deploy edilmiş backend'i kullanmak için:

1. `.env` dosyasını production URL'lerle güncelleyin
2. Android build:
   ```bash
   flutter build apk --release
   ```
3. iOS build:
   ```bash
   flutter build ios --release
   ```

## 🎉 Başarılı Deployment Sonrası

Artık uygulamanız:
- ✅ Her IP'den erişilebilir
- ✅ Her telefonda çalışabilir
- ✅ Ücretsiz hosting kullanıyor
- ✅ SSL sertifikası otomatik (HTTPS)

## 📞 Destek

Sorun yaşarsanız:
1. Render.com dokümantasyonu: [docs.render.com](https://docs.render.com)
2. Render.com community: [community.render.com](https://community.render.com)

