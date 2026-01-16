// server.js (UPDATED)
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
require('dotenv').config();

const app = express();

// Enhanced CORS configuration
app.use(cors({
  origin: '*', // Allow all origins in development
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true
}));

// Middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Request logging middleware
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
  next();
});

// MongoDB Connection
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/lexilens';

mongoose.connect(MONGODB_URI, {
  useNewUrlParser: true,
  useUnifiedTopology: true,
})
  .then(() => {
    console.log('✅ MongoDB connected successfully');
    console.log(`📍 Database: ${mongoose.connection.name}`);
  })
  .catch(err => {
    console.error('❌ MongoDB connection error:', err);
    process.exit(1);
  });

// Routes
app.use('/api/sessions', require('./routes/sessions'));
app.use('/api/documents', require('./routes/documents'));
app.use('/api/tags', require('./routes/tags'));
app.use('/api/settings', require('./routes/settings'));
app.use('/api/dictionary', require('./routes/dictionary'));

// Health check
app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'Server running successfully',
    timestamp: new Date().toISOString(),
    database: mongoose.connection.readyState === 1 ? 'connected' : 'disconnected'
  });
});

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    message: 'LexiLens Backend API',
    version: '1.0.0',
    endpoints: {
      health: '/api/health',
      sessions: '/api/sessions',
      documents: '/api/documents',
      tags: '/api/tags',
      settings: '/api/settings',
      dictionary: '/api/dictionary'
    }
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ 
    error: 'Endpoint not found',
    path: req.path,
    method: req.method
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('❌ Error:', err);
  res.status(500).json({ 
    error: 'Internal server error',
    message: process.env.NODE_ENV === 'development' ? err.message : 'Something went wrong'
  });
});

const PORT = process.env.PORT || 3000;

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Server running on http://localhost:${PORT}`);
  console.log(`📱 For Android Emulator: http://10.0.2.2:${PORT}`);
  console.log(`📱 For iOS Simulator: http://localhost:${PORT}`);
  console.log(`📱 For Physical Device: http://YOUR_IP:${PORT}`);
  console.log('');
  console.log('Available endpoints:');
  console.log(`  - Health Check: http://localhost:${PORT}/api/health`);
  console.log(`  - Sessions: http://localhost:${PORT}/api/sessions`);
  console.log(`  - Documents: http://localhost:${PORT}/api/documents`);
  console.log(`  - Tags: http://localhost:${PORT}/api/tags`);
  console.log(`  - Settings: http://localhost:${PORT}/api/settings`);
  console.log(`  - Dictionary: http://localhost:${PORT}/api/dictionary`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM signal received: closing HTTP server');
  mongoose.connection.close(() => {
    console.log('MongoDB connection closed');
    process.exit(0);
  });
});