# 🚀 Hızlı Başlangıç - Render.com Deployment

## ⚡ 5 Dakikada Deployment

### 1. GitHub'a Yükle
```bash
git add .
git commit -m "Ready for deployment"
git push
```

### 2. Render.com'da İki Servis Oluştur

#### Python Parser Servisi
- **Type:** Web Service
- **Environment:** Python 3
- **Root Directory:** `fatura_parser_py`
- **Build Command:** `pip install -r requirements.txt`
- **Start Command:** `gunicorn --bind 0.0.0.0:$PORT --workers 2 --timeout 120 app:app`
- **Plan:** Free

#### Node.js Backend Servisi
- **Type:** Web Service  
- **Environment:** Node
- **Root Directory:** `fatura_backend`
- **Build Command:** `npm install`
- **Start Command:** `npm start`
- **Plan:** Free

### 3. Environment Variables Ekle

**Backend için:**
- `PORT`: `3000`
- `PARSER_URL`: `https://fatura-parser.onrender.com/parse_invoice`
- `FIREBASE_PROJECT_ID`: (Firebase Console'dan)
- `FIREBASE_PRIVATE_KEY`: (Firebase Console'dan)
- `FIREBASE_CLIENT_EMAIL`: (Firebase Console'dan)

**Parser için:**
- `PORT`: `5001`
- `PYTHONUNBUFFERED`: `1`

### 4. Flutter Uygulamasını Güncelle

`.env` dosyasını oluştur:
```env
API_BASE_URL=https://fatura-backend.onrender.com
WS_BASE_URL=wss://fatura-backend.onrender.com
```

### 5. Test Et

Backend: `https://fatura-backend.onrender.com/health`
Parser: `https://fatura-parser.onrender.com/health`

## 📚 Detaylı Rehber

Tam detaylı rehber için `DEPLOYMENT.md` dosyasına bakın.

