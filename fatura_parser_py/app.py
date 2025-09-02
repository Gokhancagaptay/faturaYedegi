import os
import sys
import time
from flask import Flask, request, jsonify
from werkzeug.utils import secure_filename

# Yalnızca vendor analiz motorunu kullan
VENDOR_DIR = os.path.join(os.path.dirname(__file__), 'vendor', 'fatura_tanima_uygulamasi')
if os.path.isdir(VENDOR_DIR) and VENDOR_DIR not in sys.path:
    sys.path.append(VENDOR_DIR)

class _VendorAdapter:
    def __init__(self):
        self._engine = None
        self._callable = None

        # 1) Sınıf tabanlı motor dene
        for mod_name, cls_name in [
            ('fatura_analiz_motoru', 'FaturaAnalizMotoru'),
            ('main', 'FaturaAnalizMotoru'),
            ('app', 'FaturaAnalizMotoru'),
        ]:
            try:
                mod = __import__(mod_name, fromlist=[cls_name])
                engine_cls = getattr(mod, cls_name)
                # Config yolu opsiyonel
                cfg = os.path.join(VENDOR_DIR, 'config', 'config.json')
                try:
                    self._engine = engine_cls(config_path=cfg) if os.path.isfile(cfg) else engine_cls()
                except TypeError:
                    self._engine = engine_cls()
                # Olası metod isimleri
                for m in ['analiz_et', 'analyze', 'analyze_file', 'fatura_analiz_et']:
                    if callable(getattr(self._engine, m, None)):
                        self._callable = getattr(self._engine, m)
                        return
            except Exception:
                continue

        # 2) Fonksiyon tabanlı API dene (main.py içindeki analiz fonksiyonları)
        try:
            mod = __import__('main', fromlist=['analiz_et', 'analyze', 'analyze_file'])
            for fname in ['analiz_et', 'analyze', 'analyze_file', 'run_analysis']:
                fn = getattr(mod, fname, None)
                if callable(fn):
                    self._engine = mod
                    self._callable = fn
                    return
        except Exception:
            pass

        raise ImportError('Vendor analiz motoru bulunamadı veya başlatılamadı.')

    def analyze(self, filepath):
        # Metod imzaları farklı olabilir; gorsellestir argümanını best-effort geçiriyoruz
        try:
            return self._callable(filepath, gorsellestir=False)
        except TypeError:
            return self._callable(filepath)

# Flask uygulamasını başlat
app = Flask(__name__)

# Yüklenen dosyaların kaydedileceği klasör
UPLOAD_FOLDER = 'fatura_uploads'
if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)

app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16 MB dosya boyutu limiti

# İzin verilen dosya uzantıları
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'pdf'}

# Ayrıntılı analiz logları için env bayrağı
VERBOSE = os.getenv('ANALYSIS_VERBOSE', 'false').lower() == 'true'

def allowed_file(filename):
    """Dosya uzantısının izin verilenler arasında olup olmadığını kontrol eder."""
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

# Analiz motorunu başlat (yalnızca vendor)
analiz_sistemi = None
try:
    analiz_sistemi = _VendorAdapter()
    print("✅ Vendor Fatura Analiz Motoru yüklendi (adapter).")
except Exception as e:
    analiz_sistemi = None
    print(f"❌ Vendor Fatura Analiz Motoru başlatılamadı: {e}")

@app.route('/health', methods=['GET'])
def health_check():
    """Servisin ayakta olup olmadığını kontrol etmek için basit bir endpoint."""
    if analiz_sistemi:
        return jsonify({"status": "OK", "message": "Fatura tanima servisi calisiyor."}), 200
    else:
        return jsonify({"status": "ERROR", "message": "Fatura tanima servisi baslatilamadi."}), 500

@app.route('/parse_invoice', methods=['POST'])
def parse_invoice():
    """
    POST isteği ile gönderilen bir fatura dosyasını (resim veya PDF) işler
    ve yapılandırılmış JSON verisini döndürür.
    """
    if analiz_sistemi is None:
        return jsonify({"hata": "Analiz sistemi mevcut değil. Lütfen sunucu loglarını kontrol edin."}), 500

    # Dosya istekle birlikte gönderildi mi?
    if 'file' not in request.files:
        return jsonify({"hata": "İstek içinde 'file' adında bir dosya bulunamadı."}), 400
    
    file = request.files['file']

    # Kullanıcı bir dosya seçti mi?
    if file.filename == '':
        return jsonify({"hata": "Dosya seçilmedi."}), 400

    # Dosya geçerli ve izin verilen bir uzantıya sahip mi?
    if file and allowed_file(file.filename):
        filename = secure_filename(file.filename)
        filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
        
        try:
            # Dosyayı sunucuya kaydet
            file.save(filepath)
            
            # Faturayı analiz et (vendor ya da legacy API'si)
            # Vendor adapter üzerinden analiz
            t0 = time.time()
            result = analiz_sistemi.analyze(filepath)
            dt = (time.time() - t0) * 1000.0
            if VERBOSE:
                try:
                    # Vendor çıktısı: 'structured' | 'yapilandirilmis_veri'
                    struct = {}
                    if isinstance(result, dict):
                        struct = result.get('structured') or result.get('yapilandirilmis_veri') or result
                    keys = list(struct.keys()) if isinstance(struct, dict) else []
                    urun_count = len(struct.get('urun_kalemleri', [])) if isinstance(struct, dict) and isinstance(struct.get('urun_kalemleri', []), list) else 0
                    print(f"🧾 Analiz özeti | dosya={filename} | süre={dt:.0f} ms | alan_sayısı={len(keys)} | urun_kalemi={urun_count}")
                    # Eski tarz alan kontrol çıktısı
                    expected = [
                        'fatura_no','fatura_tarihi','satici_unvan','alici_unvan','odenecek_tutar',
                        'mal_hizmet_toplam_tutari','ettn','vergi_no','tc_no','telefon','email'
                    ]
                    for fld in expected:
                        ok = isinstance(struct, dict) and (struct.get(fld) not in (None, '', []))
                        print(("✅ " if ok else "❌ ") + f"{fld} " + ("bulundu" if ok else "bulunamadı"))
                except Exception as _:
                    pass
            
            # Analiz sonrası yüklenen dosyayı temizle
            try:
                os.remove(filepath)
            except Exception:
                pass

            # Sadece yapılandırılmış veriyi ve gerekirse hata mesajını döndür
            if isinstance(result, dict) and "hata" in result:
                return jsonify({"hata": result["hata"]}), 500
            
            if isinstance(result, dict) and "structured" in result:
                return jsonify(result.get("structured", {})), 200
            
            # Son çare: dikeyi doğrudan döndür
            return jsonify(result if isinstance(result, dict) else {"structured": result}), 200

        except Exception as e:
            # Hata durumunda geçici dosyayı sil
            if os.path.exists(filepath):
                try:
                    os.remove(filepath)
                except Exception:
                    pass
            print(f"HATA: /parse_invoice endpoint'inde bir hata oluştu: {e}")
            return jsonify({"hata": f"Sunucuda bir hata oluştu: {str(e)}"}), 500
    else:
        return jsonify({"hata": "İzin verilmeyen dosya türü. Sadece png, jpg, jpeg, pdf kabul edilir."}), 400

if __name__ == '__main__':
    # Bu blok sadece 'python app.py' ile doğrudan çalıştırıldığında devreye girer.
    # Docker (gunicorn) ile çalıştırıldığında kullanılmaz.
    # Debug modunda ve 0.0.0.0 (her yerden erişilebilir) olarak çalıştır.
    app.run(host='0.0.0.0', port=5001, debug=True)
