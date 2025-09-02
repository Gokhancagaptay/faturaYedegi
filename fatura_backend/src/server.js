require('dotenv').config();
const express = require('express');
const cors = require('cors');
const initializeFirebase = require('./config/firebaseAdmin');
const WebSocketService = require('./services/websocket.service');

const authRoutes = require('./routes/auth.routes');
const invoiceRoutes = require('./routes/invoice.routes');
const packageRoutes = require('./routes/package.routes');
const userRoutes = require('./routes/user.routes'); // Yeni eklenen
const reportRoutes = require('./routes/reportRoutes');

// Initialize Firebase
try {
  initializeFirebase();
  console.log('Firebase Admin SDK initialized successfully.');
} catch (error) {
  console.error('Firebase Admin SDK initialization failed:', error);
  process.exit(1); // Exit if Firebase fails to initialize
}

const app = express();

// Middlewares
app.use(cors());
app.use(express.json({ limit: '250mb' }));
app.use(express.urlencoded({ extended: true, limit: '250mb' }));


// Routes
app.get('/', (req, res) => {
  res.send('Fatura Yeni Backend is running!');
});

app.use('/api/auth', authRoutes);
app.use('/api/invoice', invoiceRoutes);
app.use('/api/packages', packageRoutes);
app.use('/api/user', userRoutes); // Yeni eklenen
app.use('/api/reports', reportRoutes);


// Global Error Handler
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).send({ error: 'Something went wrong!' });
});


const PORT = process.env.PORT || 3000;
const server = app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});

// WebSocket sunucusunu başlat
WebSocketService.initialize(server);
