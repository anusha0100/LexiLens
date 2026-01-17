// lib/services/mongodb_service.dart (FIXED VERSION)
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:lexilens/models/document_model.dart';
import 'package:lexilens/models/document_tag.dart';
import 'package:lexilens/models/user_session.dart';

class MongoDBService {
  static final MongoDBService _instance = MongoDBService._internal();
  factory MongoDBService() => _instance;
  MongoDBService._internal();
  static const String baseUrl = 'https://lexilens-backend-yyix.onrender.com';
  
  // For local testing:
  // Android Emulator: 'http://10.0.2.2:3000/api'
  // iOS Simulator: 'http://localhost:3000/api'
  // Physical Device: 'http://YOUR_IP_ADDRESS:3000/api'

  String _authToken = '';

  void setAuthToken(String token) {
    _authToken = token;
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_authToken.isNotEmpty) 'Authorization': 'Bearer $_authToken',
  };

  // Error handler helper
  void _handleError(dynamic error, String operation) {
    print('MongoDB Service Error [$operation]: $error');
  }

  // ==================== SESSION OPERATIONS ====================
  
  Future<UserSession?> createSession(UserSession session) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sessions'),
        headers: _headers,
        body: jsonEncode(session.toJson()),
      );

      print('Create Session Response: ${response.statusCode}');
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UserSession.fromJson(data);
      }
      
      print('Create Session Failed: ${response.body}');
      return null;
    } catch (e) {
      _handleError(e, 'createSession');
      return null;
    }
  }

  Future<UserSession?> getActiveSession(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sessions/$userId/active'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UserSession.fromJson(data);
      }
      
      return null;
    } catch (e) {
      _handleError(e, 'getActiveSession');
      return null;
    }
  }

  Future<bool> invalidateSession(String sessionId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/sessions/$sessionId'),
        headers: _headers,
      );

      return response.statusCode == 200;
    } catch (e) {
      _handleError(e, 'invalidateSession');
      return false;
    }
  }

  // ==================== DOCUMENT OPERATIONS ====================
  
  Future<DocumentModel?> createDocument(DocumentModel document) async {
    try {
      print('Creating document: ${document.name}');
      
      final response = await http.post(
        Uri.parse('$baseUrl/documents'),
        headers: _headers,
        body: jsonEncode(document.toJson()),
      );

      print('Create Document Response: ${response.statusCode}');
      print('Response Body: ${response.body}');
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return DocumentModel.fromJson(data);
      }
      
      print('Create Document Failed: ${response.body}');
      return null;
    } catch (e) {
      _handleError(e, 'createDocument');
      return null;
    }
  }

  Future<List<DocumentModel>> getUserDocuments(String userId) async {
    try {
      print('Fetching documents for user: $userId');
      
      final response = await http.get(
        Uri.parse('$baseUrl/documents/user/$userId'),
        headers: _headers,
      );

      print('Get Documents Response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => DocumentModel.fromJson(json)).toList();
      }
      
      return [];
    } catch (e) {
      _handleError(e, 'getUserDocuments');
      return [];
    }
  }

  Future<DocumentModel?> getDocument(String documentId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/documents/$documentId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return DocumentModel.fromJson(data);
      }
      
      return null;
    } catch (e) {
      _handleError(e, 'getDocument');
      return null;
    }
  }

  Future<bool> updateDocument(String documentId, Map<String, dynamic> updates) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/documents/$documentId'),
        headers: _headers,
        body: jsonEncode(updates),
      );

      return response.statusCode == 200;
    } catch (e) {
      _handleError(e, 'updateDocument');
      return false;
    }
  }

  Future<bool> deleteDocument(String documentId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/documents/$documentId'),
        headers: _headers,
      );

      return response.statusCode == 200;
    } catch (e) {
      _handleError(e, 'deleteDocument');
      return false;
    }
  }

  // ==================== TAG OPERATIONS ====================
  
  Future<DocumentTag?> createTag(DocumentTag tag) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tags'),
        headers: _headers,
        body: jsonEncode(tag.toJson()),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return DocumentTag.fromJson(data);
      }
      
      return null;
    } catch (e) {
      _handleError(e, 'createTag');
      return null;
    }
  }

  Future<List<DocumentTag>> getUserTags(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/tags/user/$userId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => DocumentTag.fromJson(json)).toList();
      }
      
      return [];
    } catch (e) {
      _handleError(e, 'getUserTags');
      return [];
    }
  }

  Future<bool> deleteTag(String tagId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/tags/$tagId'),
        headers: _headers,
      );

      return response.statusCode == 200;
    } catch (e) {
      _handleError(e, 'deleteTag');
      return false;
    }
  }

  // ==================== SETTINGS OPERATIONS ====================
  
  Future<bool> updateSetting(String userId, String key, dynamic value) async {
    try {
      print('Updating setting: $key = $value');
      
      final response = await http.post(
        Uri.parse('$baseUrl/settings'),
        headers: _headers,
        body: jsonEncode({
          'userId': userId,
          'settingKey': key,
          'value': value,
        }),
      );

      print('Update Setting Response: ${response.statusCode}');
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      _handleError(e, 'updateSetting');
      return false;
    }
  }

  Future<dynamic> getSetting(String userId, String key) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/settings/$userId/$key'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['value'];
      }
      
      return null;
    } catch (e) {
      _handleError(e, 'getSetting');
      return null;
    }
  }

  Future<Map<String, dynamic>> getAllSettings(String userId) async {
    try {
      print('Fetching all settings for user: $userId');
      
      final response = await http.get(
        Uri.parse('$baseUrl/settings/user/$userId'),
        headers: _headers,
      );

      print('Get Settings Response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final Map<String, dynamic> settings = {};
        
        for (var setting in data) {
          settings[setting['settingKey']] = setting['value'];
        }
        
        return settings;
      }
      
      return {};
    } catch (e) {
      _handleError(e, 'getAllSettings');
      return {};
    }
  }

  // ==================== CONNECTIVITY TEST ====================
  
  Future<bool> testConnection() async {
    try {
      print('Testing connection to: $baseUrl/health');
      
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));

      print('Connection Test Response: ${response.statusCode}');
      print('Response Body: ${response.body}');
      
      return response.statusCode == 200;
    } catch (e) {
      _handleError(e, 'testConnection');
      return false;
    }
  }
}