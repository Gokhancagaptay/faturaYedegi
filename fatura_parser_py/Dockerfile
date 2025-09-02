# 1. Temel imaj olarak Python 3.9'u kullan
FROM python:3.9-slim

# 2. Çalışma dizinini ayarla
WORKDIR /app
# Logların anında docker'a düşmesi için buffer'ı kapat
ENV PYTHONUNBUFFERED=1
# Ayrıntılı analiz loglarını açmak için bayrak (gerekirse docker-compose ile override edilebilir)
ENV ANALYSIS_VERBOSE=true

# 3. Gerekli sistem kütüphanelerini kur (OpenCV ve Tesseract için)
# non-interactive: Kurulum sırasında soru sormasını engeller
RUN apt-get update && apt-get install -y --no-install-recommends \
    tesseract-ocr \
    tesseract-ocr-tur \
    libgl1 \
    libglib2.0-0 \
    curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 4. Bağımlılık dosyasını kopyala
COPY requirements.txt .

# 5. Python kütüphanelerini kur
RUN pip install --no-cache-dir -r requirements.txt

# 6. Proje dosyalarının geri kalanını kopyala
COPY . .

# 7. Flask uygulamasının çalışacağı portu belirt
EXPOSE 5001

# 8. Uygulamayı başlatma komutu
CMD ["gunicorn", "--bind", "0.0.0.0:5001", "--workers", "4", "--access-logfile", "-", "--error-logfile", "-", "--capture-output", "--log-level", "info", "app:app"]
