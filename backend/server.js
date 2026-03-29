const express = require('express');
const cors = require('cors');
const mongoose = require('mongoose');
require('dotenv').config();

const app = express();

app.use(cors());
app.use(express.json());

const MONGODB_URI = process.env.MONGODB_URI;

if (!MONGODB_URI) {
  console.error('FATAL: MONGODB_URI environment variable is not set.');
  console.error('Set it in Render Dashboard → Environment → Add Environment Variable.');
  process.exit(1);
}

mongoose.connect(MONGODB_URI, {
  serverSelectionTimeoutMS: 10000,
  socketTimeoutMS: 45000,
  connectTimeoutMS: 10000,
})
  .then(() => console.log('Connected to MongoDB'))
  .catch(err => {
    console.error('MongoDB connection error:', err.message);
    process.exit(1);
  });

mongoose.connection.on('disconnected', () => {
  console.warn('MongoDB disconnected. Attempting to reconnect...');
});

mongoose.connection.on('reconnected', () => {
  console.log('MongoDB reconnected');
});

// Routes
app.use('/api/auth',       require('./routes/auth'));
app.use('/api/documents',  require('./routes/documents'));
app.use('/api/sessions',   require('./routes/sessions'));
app.use('/api/settings',   require('./routes/settings'));
app.use('/api/tags',       require('./routes/tags'));
app.use('/api/dictionary', require('./routes/dictionary'));
app.use('/api/ocr-cache',  require('./routes/ocrCache'));   // ← added
app.use('/api',            require('./routes/users'));

// Health check
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    message: 'Server is running',
    timestamp: new Date().toISOString(),
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ success: false, message: 'Route not found' });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Server error:', err);
  res.status(500).json({
    success: false,
    message: 'Internal server error',
    error: process.env.NODE_ENV === 'development' ? err.message : undefined,
  });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
});