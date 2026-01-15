// lib/services/mongodb_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:lexilens/models/user_session.dart';
import 'package:lexilens/models/word_dictionary.dart';
import 'package:lexilens/models/document_tag.dart';
import 'package:lexilens/models/app_setting.dart';
import 'package:lexilens/models/document_model.dart';

class MongoDBService {
  static final MongoDBService _instance = MongoDBService._internal();
  factory MongoDBService() => _instance;
  MongoDBService._internal();
  static const String baseUrl = 'BACKEND_API_URL';
  String? _authToken;

  void setAuthToken(String token) {
    _authToken = token;
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_authToken != null) 'Authorization': 'Bearer $_authToken',
  };

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
        Uri.parse('$baseUrl/dictionary/search?q=$query'),
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

  // Document Tag Methods
  Future<DocumentTag?> createTag(DocumentTag tag) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tags'),
        headers: _headers,
        body: jsonEncode(tag.toJson()),
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
  Future<AppSetting?> getSetting(String key) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/settings/$key'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return AppSetting.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      print('Error getting setting: $e');
      return null;
    }
  }

  Future<bool> updateSetting(String key, dynamic value) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/settings/$key'),
        headers: _headers,
        body: jsonEncode({'setting_value': value}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating setting: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> getAllSettings() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/settings'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      }
      return {};
    } catch (e) {
      print('Error getting all settings: $e');
      return {};
    }
  }

  // Document Methods
  Future<DocumentModel?> createDocument(DocumentModel doc) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/documents'),
        headers: _headers,
        body: jsonEncode(doc.toJson()),
      );

      if (response.statusCode == 201) {
        return DocumentModel.fromJson(jsonDecode(response.body));
      }
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

  Future<List<DocumentModel>> searchDocuments(String userId, String query) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/documents/search?user_id=$userId&q=$query'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => DocumentModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error searching documents: $e');
      return [];
    }
  }

  Future<List<DocumentModel>> getDocumentsByTag(String userId, String tagName) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/documents/tag?user_id=$userId&tag=$tagName'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => DocumentModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error getting documents by tag: $e');
      return [];
    }
  }

  Future<List<DocumentModel>> getFavoriteDocuments(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/documents/favorites/$userId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => DocumentModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error getting favorite documents: $e');
      return [];
    }
  }
}