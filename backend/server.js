// server.js
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
require('dotenv').config();

const app = express();

// Middleware
app.use(cors());
app.use(express.json());

// MongoDB Connection
mongoose.connect(process.env.MONGODB_URI)
  .then(() => console.log('✅ MongoDB connected successfully'))
  .catch(err => console.error('❌ MongoDB connection error:', err));

// Routes
app.use('/api/sessions', require('./routes/sessions'));
app.use('/api/documents', require('./routes/documents'));
app.use('/api/tags', require('./routes/tags'));
app.use('/api/settings', require('./routes/settings'));
app.use('/api/dictionary', require('./routes/dictionary'));

// Health check
app.get('/api/health', (req, res) => {
  res.json({ status: 'Server running successfully' });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🚀 Server running on http://localhost:${PORT}`);
});
