# Fatura İşleme API Dokümantasyonu

## 🔐 Kimlik Doğrulama

Tüm API istekleri JWT token gerektirir. Token'ı `Authorization` header'ında gönderin:

```
Authorization: Bearer <your-jwt-token>
```

## 📤 Fatura İşleme Endpoint'leri

### 1. Senkron Fatura İşleme

**POST** `/api/invoices/scan`

Faturayı senkron olarak işler ve sonucu hemen döner.

#### Request
```bash
curl -X POST \
  http://localhost:3000/api/invoices/scan \
  -H 'Authorization: Bearer <token>' \
  -F 'file=@/path/to/invoice.png'
```

#### Response
```json
{
  "message": "Invoice processed and saved successfully.",
  "data": {
    "id": "invoice_id_123",
    "fileUrl": "https://storage.googleapis.com/...",
    "structured": {
      "fatura_tarihi": "2025-01-15",
      "genel_toplam": "125.50",
      "satici_firma_unvani": "ABC Şirketi"
    }
  }
}
```

### 2. Asenkron Fatura İşleme

**POST** `/api/invoices/scan-background`

Faturayı arka planda işler, hemen job ID döner.

#### Request
```bash
curl -X POST \
  http://localhost:3000/api/invoices/scan-background \
  -H 'Authorization: Bearer <token>' \
  -F 'file=@/path/to/invoice.png'
```

#### Response
```json
{
  "message": "Invoice processing started in background.",
  "jobId": "job_1703123456789_abc123",
  "invoiceId": "invoice_id_123",
  "status": "uploading"
}
```

### 3. Fatura Listesi

**GET** `/api/invoices`

Kullanıcının tüm faturalarını listeler.

#### Request
```bash
curl -X GET \
  http://localhost:3000/api/invoices \
  -H 'Authorization: Bearer <token>'
```

#### Response
```json
{
  "invoices": [
    {
      "id": "invoice_id_123",
      "fileName": "fatura.png",
      "status": "processed",
      "uploadedAt": "2025-01-15T10:30:00Z",
      "fileUrl": "https://storage.googleapis.com/...",
      "thumbnailUrl": "https://storage.googleapis.com/...",
      "structured": {
        "fatura_tarihi": "2025-01-15",
        "genel_toplam": "125.50"
      }
    }
  ]
}
```

### 4. JSON Export

**GET** `/api/invoices/export.json`

Tüm faturaları JSON formatında dışa aktarır.

#### Request
```bash
curl -X GET \
  http://localhost:3000/api/invoices/export.json \
  -H 'Authorization: Bearer <token>'
```

#### Response
```json
{
  "userId": "user_123",
  "exportedAt": "2025-01-15T10:30:00Z",
  "invoiceCount": 5,
  "invoices": [...]
}
```

## 📦 Paket İşleme Endpoint'leri

### 1. Paket Oluşturma

**POST** `/api/packages/create`

Yeni bir fatura paketi oluşturur.

#### Request
```bash
curl -X POST \
  http://localhost:3000/api/packages/create \
  -H 'Authorization: Bearer <token>' \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "Ocak 2025 Faturaları",
    "description": "Ocak ayına ait tüm faturalar"
  }'
```

#### Response
```json
{
  "message": "Package created successfully.",
  "package": {
    "id": "package_id_123",
    "name": "Ocak 2025 Faturaları",
    "createdAt": "2025-01-15T10:30:00Z",
    "totalInvoices": 0,
    "processedInvoices": 0,
    "errorCount": 0
  }
}
```

### 2. Paket Listesi

**GET** `/api/packages`

Kullanıcının tüm paketlerini listeler.

#### Request
```bash
curl -X GET \
  http://localhost:3000/api/packages \
  -H 'Authorization: Bearer <token>'
```

#### Response
```json
{
  "packages": [
    {
      "id": "package_id_123",
      "name": "Ocak 2025 Faturaları",
      "createdAt": "2025-01-15T10:30:00Z",
      "totalInvoices": 5,
      "processedInvoices": 3,
      "errorCount": 0
    }
  ]
}
```

### 3. Paket Detayı

**GET** `/api/packages/:packageId`

Belirli bir paketin detaylarını getirir.

#### Request
```bash
curl -X GET \
  http://localhost:3000/api/packages/package_id_123 \
  -H 'Authorization: Bearer <token>'
```

#### Response
```json
{
  "package": {
    "id": "package_id_123",
    "name": "Ocak 2025 Faturaları",
    "createdAt": "2025-01-15T10:30:00Z",
    "totalInvoices": 5,
    "processedInvoices": 3,
    "errorCount": 0,
    "lastProcessedAt": "2025-01-15T10:35:00Z"
  }
}
```

### 4. Paket Faturaları

**GET** `/api/packages/:packageId/invoices`

Paketteki faturaları listeler.

#### Request
```bash
curl -X GET \
  http://localhost:3000/api/packages/package_id_123/invoices \
  -H 'Authorization: Bearer <token>'
```

#### Response
```json
{
  "invoices": [
    {
      "id": "invoice_id_123",
      "originalName": "fatura1.png",
      "status": "processed",
      "uploadedAt": "2025-01-15T10:30:00Z",
      "fileUrl": "https://storage.googleapis.com/...",
      "structured": {...}
    }
  ]
}
```

### 5. Paket JSON Export

**GET** `/api/packages/:packageId/export.json`

Paketi JSON formatında dışa aktarır.

#### Request
```bash
curl -X GET \
  http://localhost:3000/api/packages/package_id_123/export.json \
  -H 'Authorization: Bearer <token>'
```

#### Response
```json
{
  "packageId": "package_id_123",
  "name": "Ocak 2025 Faturaları",
  "createdAt": "2025-01-15T10:30:00Z",
  "totalInvoices": 5,
  "processedInvoices": 3,
  "errorCount": 0,
  "invoices": [...]
}
```

## 🚨 Hata Kodları

### HTTP Status Kodları

| Kod | Açıklama |
|-----|----------|
| 200 | Başarılı |
| 201 | Oluşturuldu |
| 202 | Kabul edildi (Background processing) |
| 400 | Geçersiz istek |
| 401 | Kimlik doğrulama gerekli |
| 403 | Yetkisiz erişim |
| 404 | Bulunamadı |
| 500 | Sunucu hatası |

### Hata Response Formatı

```json
{
  "message": "Hata açıklaması",
  "error": "Detaylı hata mesajı",
  "data": {
    "id": "invoice_id_123"
  }
}
```

## 📊 Response Formatları

### Fatura Objesi

```json
{
  "id": "string",
  "userId": "string",
  "fileName": "string",
  "status": "uploading|queued|processing|processed|failed",
  "uploadedAt": "timestamp",
  "lastProcessedAt": "timestamp",
  "fileUrl": "string",
  "thumbnailUrl": "string",
  "processingMs": "number",
  "structured": {
    "fatura_tarihi": "string",
    "genel_toplam": "string",
    "satici_firma_unvani": "string"
  },
  "errors": [
    {
      "code": "string",
      "message": "string"
    }
  ],
  "internalLogs": ["string"]
}
```

### Paket Objesi

```json
{
  "id": "string",
  "userId": "string",
  "name": "string",
  "description": "string",
  "createdAt": "timestamp",
  "totalInvoices": "number",
  "processedInvoices": "number",
  "errorCount": "number",
  "lastProcessedAt": "timestamp"
}
```

## 🔧 Test Örnekleri

### Python ile Test

```python
import requests

# Token al
auth_response = requests.post('http://localhost:3000/api/auth/login', json={
    'phone': '+905551234567',
    'password': 'password123'
})
token = auth_response.json()['token']

# Fatura yükle
with open('fatura.png', 'rb') as f:
    files = {'file': f}
    headers = {'Authorization': f'Bearer {token}'}
    response = requests.post('http://localhost:3000/api/invoices/scan', 
                           files=files, headers=headers)
    print(response.json())
```

### JavaScript ile Test

```javascript
const FormData = require('form-data');
const fs = require('fs');

// Token al
const authResponse = await fetch('http://localhost:3000/api/auth/login', {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({
        phone: '+905551234567',
        password: 'password123'
    })
});
const {token} = await authResponse.json();

// Fatura yükle
const form = new FormData();
form.append('file', fs.createReadStream('fatura.png'));

const response = await fetch('http://localhost:3000/api/invoices/scan', {
    method: 'POST',
    headers: {
        'Authorization': `Bearer ${token}`,
        ...form.getHeaders()
    },
    body: form
});

console.log(await response.json());
```

## 📈 Rate Limiting

- **Upload**: 10 istek/dakika
- **List**: 100 istek/dakika
- **Export**: 5 istek/dakika

## 🔒 Güvenlik

- Tüm endpoint'ler JWT token gerektirir
- Dosya boyutu limiti: 10MB
- Desteklenen formatlar: PNG, JPG, PDF
- CORS: Sadece güvenilir domain'ler
