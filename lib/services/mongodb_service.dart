import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:lexilens/models/document_model.dart';
import 'package:lexilens/models/document_tag.dart';
import 'package:lexilens/models/user_session.dart';

class MongoDBService {
  static final MongoDBService _instance = MongoDBService._internal();
  factory MongoDBService() => _instance;
  MongoDBService._internal();

  static const String baseUrl = 'https://lexilens-backend-yyix.onrender.com/api';
  String _authToken = '';

  void setAuthToken(String token) {
    _authToken = token;
  }

  Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (_authToken.isNotEmpty) 'Authorization': 'Bearer $_authToken',
  };

  Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Connection test failed: $e');
      return false;
    }
  }

  Future<DocumentModel?> createDocument(DocumentModel document) async {
    try {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📤 CREATING DOCUMENT');
      print('Name: ${document.name}');
      print('Content Length: ${document.content.length}');
      print('First 200 chars: ${document.content.substring(0, document.content.length > 200 ? 200 : document.content.length)}');
      
      final payload = {
        'userId': document.userId,
        'fileName': document.name,
        'documentText': document.content,
        'filePath': document.filePath ?? '',
        'uploadedDate': document.uploadedDate.toIso8601String(),
        'tags': document.tags,
        'isFavorite': document.isFavorite,
      };
      
      print('Payload: ${jsonEncode(payload)}');
      
      final response = await http.post(
        Uri.parse('$baseUrl/documents'),
        headers: headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 20));

      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return DocumentModel.fromJson(data);
      }
      
      return null;
    } catch (e) {
      print('Create Document Error: $e');
      return null;
    }
  }

  Future<List<DocumentModel>> getUserDocuments(String userId) async {
    try {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('FETCHING DOCUMENTS FOR USER: $userId');
      
      final response = await http.get(
        Uri.parse('$baseUrl/documents/user/$userId'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      print('Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        print('Found ${data.length} documents');
        
        final documents = data.map((json) {
          print('Document: ${json['fileName']}');
          print('Content Length: ${json['documentText']?.toString().length ?? 0}');
          return DocumentModel.fromJson(json);
        }).toList();
        
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        return documents;
      }
      
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      return [];
    } catch (e) {
      print('Get Documents Error: $e');
      return [];
    }
  }

  Future<DocumentModel?> getDocument(String documentId) async {
    try {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📖 FETCHING SINGLE DOCUMENT: $documentId');
      
      final response = await http.get(
        Uri.parse('$baseUrl/documents/$documentId'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      print('Response Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Document: ${data['fileName']}');
        print('Content Length: ${data['documentText']?.toString().length ?? 0}');
        print('First 200 chars: ${data['documentText']?.toString().substring(0, (data['documentText']?.toString().length ?? 0) > 200 ? 200 : (data['documentText']?.toString().length ?? 0))}');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        
        return DocumentModel.fromJson(data);
      }
      
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      return null;
    } catch (e) {
      print('Get Document Error: $e');
      return null;
    }
  }

  Future<bool> updateDocument(String documentId, Map<String, dynamic> updates) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/documents/$documentId'),
        headers: headers,
        body: jsonEncode(updates),
      ).timeout(const Duration(seconds: 15));
      return response.statusCode == 200;
    } catch (e) {
      print('Update Document Error: $e');
      return false;
    }
  }

  Future<bool> deleteDocument(String documentId) async {
    try {
      print('Deleting document: $documentId');
      final response = await http.delete(
        Uri.parse('$baseUrl/documents/$documentId'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      
      print('Delete Response: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('Delete Document Error: $e');
      return false;
    }
  }

  Future<UserSession?> createSession(UserSession session) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sessions'),
        headers: headers,
        body: jsonEncode(session.toJson()),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UserSession.fromJson(data);
      }
      return null;
    } catch (e) {
      print('Create Session Error: $e');
      return null;
    }
  }

  Future<UserSession?> getActiveSession(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sessions/$userId/active'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UserSession.fromJson(data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> invalidateSession(String sessionId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/sessions/$sessionId'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // TAG OPERATIONS
  Future<DocumentTag?> createTag(DocumentTag tag) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tags'),
        headers: headers,
        body: jsonEncode(tag.toJson()),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return DocumentTag.fromJson(data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<DocumentTag>> getUserTags(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/tags/user/$userId'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => DocumentTag.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> deleteTag(String tagId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/tags/$tagId'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // SETTINGS OPERATIONS
  Future<bool> updateSetting(String userId, String key, dynamic value) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/settings'),
        headers: headers,
        body: jsonEncode({
          'userId': userId,
          'settingKey': key,
          'value': value,
        }),
      ).timeout(const Duration(seconds: 15));
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<dynamic> getSetting(String userId, String key) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/settings/$userId/$key'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['value'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> getAllSettings(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/settings/user/$userId'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

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
      return {};
    }
  }
}

