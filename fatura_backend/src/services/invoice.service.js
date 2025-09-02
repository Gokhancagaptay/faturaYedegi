const axios = require('axios');
const FormData = require('form-data');

// URL of the Python invoice parser service running in Docker
// Prefer environment variable; fallback to local dev
const PYTHON_PARSER_URL = process.env.PARSER_URL || 'http://localhost:5001/parse_invoice';

const processWithPython = async (file) => {
    try {
        const formData = new FormData();
        // Field name expected by Python server: 'file'
        formData.append('file', file.buffer, { filename: file.originalname });

        console.log(`Forwarding file to Python parser service at ${PYTHON_PARSER_URL} ...`);

        const response = await axios.post(PYTHON_PARSER_URL, formData, {
            headers: {
                ...formData.getHeaders()
            },
            timeout: 60000,
        });

        console.log('Received response from Python parser.');
        
        // Return the JSON data from the Python service
        return response.data;

    } catch (error) {
        const msg = error.response ? JSON.stringify(error.response.data) : error.message;
        console.error('Error communicating with Python parser service:', msg);
        
        // Python parser çalışmazsa basit bir fallback döndür
        console.log('⚠️ Python parser servisi mevcut değil, basit fallback kullanılıyor');
        return {
            structured: {
                fatura_no: 'Parser mevcut değil',
                fatura_tarihi: new Date().toISOString().split('T')[0],
                satici_unvan: 'Parser mevcut değil',
                alici_unvan: 'Parser mevcut değil',
                odenecek_tutar: '0.00',
                mal_hizmet_toplam_tutari: '0.00',
                ettn: 'Parser mevcut değil',
                vergi_no: 'Parser mevcut değil',
                tc_no: 'Parser mevcut değil',
                telefon: 'Parser mevcut değil',
                email: 'Parser mevcut değil'
            },
            ocrText: 'Python parser servisi mevcut değil. Dosya sadece yüklendi.',
            status: 'uploaded_only',
            message: 'Dosya başarıyla yüklendi ancak analiz edilemedi.'
        };
    }
};

module.exports = {
    processWithPython,
};
