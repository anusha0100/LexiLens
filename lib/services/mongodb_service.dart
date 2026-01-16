// lib/services/mongodb_service.dart (UPDATED)
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:lexilens/models/user_session.dart';
import 'package:lexilens/models/word_dictionary.dart';
import 'package:lexilens/models/document_tag.dart';
import 'package:lexilens/models/document_model.dart';

class MongoDBService {
  static final MongoDBService _instance = MongoDBService._internal();
  factory MongoDBService() => _instance;
  MongoDBService._internal();
  
  // ⚠️ IMPORTANT: Update this URL to match your backend server
  // For Android Emulator: use http://10.0.2.2:3000/api
  // For iOS Simulator: use http://localhost:3000/api
  // For Physical Device: use http://YOUR_COMPUTER_IP:3000/api
  
  static const String baseUrl = 'http://10.0.2.2:3000/api'; // Android Emulator
  // static const String baseUrl = 'http://localhost:3000/api'; // iOS Simulator
  // static const String baseUrl = 'http://192.168.1.100:3000/api'; // Physical Device (replace with your IP)
  
  String? _authToken;

  void setAuthToken(String token) {
    _authToken = token;
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_authToken != null) 'Authorization': 'Bearer $_authToken',
  };

  // Test connection
  Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('${baseUrl.replaceAll('/api', '')}/api/health'),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      print('Connection test failed: $e');
      return false;
    }
  }

  // User Session Methods
  Future<UserSession?> createSession(UserSession session) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sessions'),
        headers: _headers,
        body: jsonEncode(session.toJson()),
      );

      if (response.statusCode == 201) {
        return UserSession.fromJson(jsonDecode(response.body));
      }
      print('Create session failed: ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      print('Error creating session: $e');
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
        return UserSession.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      print('Error getting session: $e');
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
      print('Error invalidating session: $e');
      return false;
    }
  }

  // Document Methods
  Future<DocumentModel?> createDocument(DocumentModel doc) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/documents'),
        headers: _headers,
        body: jsonEncode({
          'userId': doc.userId,
          'fileName': doc.name,
          'filePath': doc.filePath,
          'documentText': doc.content,
          'uploadedDate': doc.uploadedDate.toIso8601String(),
          'tags': doc.tags,
          'isFavorite': doc.isFavorite,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return DocumentModel.fromJson(data);
      }
      print('Create document failed: ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      print('Error creating document: $e');
      return null;
    }
  }

  Future<List<DocumentModel>> getUserDocuments(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/documents/user/$userId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => DocumentModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error getting documents: $e');
      return [];
    }
  }

  Future<DocumentModel?> getDocument(String docId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/documents/$docId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return DocumentModel.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      print('Error getting document: $e');
      return null;
    }
  }

  Future<bool> updateDocument(String docId, Map<String, dynamic> updates) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/documents/$docId'),
        headers: _headers,
        body: jsonEncode(updates),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating document: $e');
      return false;
    }
  }

  Future<bool> deleteDocument(String docId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/documents/$docId'),
        headers: _headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting document: $e');
      return false;
    }
  }

  // Document Tag Methods
  Future<DocumentTag?> createTag(DocumentTag tag) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tags'),
        headers: _headers,
        body: jsonEncode({
          'userId': tag.userId,
          'tagName': tag.tagName,
          'color': tag.color,
        }),
      );

      if (response.statusCode == 201) {
        return DocumentTag.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      print('Error creating tag: $e');
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
      print('Error getting user tags: $e');
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
      print('Error deleting tag: $e');
      return false;
    }
  }

  // App Settings Methods
  Future<bool> updateSetting(String userId, String key, dynamic value) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/settings'),
        headers: _headers,
        body: jsonEncode({
          'userId': userId,
          'settingKey': key,
          'value': value,
        }),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      print('Error updating setting: $e');
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
      print('Error getting setting: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> getAllSettings(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/settings/user/$userId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> settings = jsonDecode(response.body);
        Map<String, dynamic> settingsMap = {};
        for (var setting in settings) {
          settingsMap[setting['settingKey']] = setting['value'];
        }
        return settingsMap;
      }
      return {};
    } catch (e) {
      print('Error getting all settings: $e');
      return {};
    }
  }

  // Word Dictionary Methods
  Future<WordDictionary?> getWordInfo(String word) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/dictionary/$word'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return WordDictionary.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      print('Error getting word info: $e');
      return null;
    }
  }

  Future<List<WordDictionary>> searchWords(String query) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/dictionary/search/$query'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => WordDictionary.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error searching words: $e');
      return [];
    }
  }
}