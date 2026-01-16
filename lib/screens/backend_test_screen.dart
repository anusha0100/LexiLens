// lib/screens/backend_test_screen.dart
// lib/screens/backend_test_screen.dart
import 'package:flutter/material.dart';
import 'package:lexilens/services/mongodb_service.dart';
import 'package:lexilens/services/auth_service.dart';
import 'package:lexilens/models/document_model.dart';
import 'package:lexilens/models/document_tag.dart';
import 'package:lexilens/models/user_session.dart';


class BackendTestScreen extends StatefulWidget {
  const BackendTestScreen({super.key});

  @override
  State<BackendTestScreen> createState() => _BackendTestScreenState();
}

class _BackendTestScreenState extends State<BackendTestScreen> {
  final _mongoService = MongoDBService();
  final _authService = AuthService();
  final _logController = ScrollController();
  final List<String> _logs = [];
  bool _isTesting = false;

  void _addLog(String message, {bool isError = false}) {
    setState(() {
      final timestamp = DateTime.now().toString().substring(11, 19);
      _logs.add('[$timestamp] ${isError ? '❌' : '✅'} $message');
    });
    
    // Auto scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_logController.hasClients) {
        _logController.animateTo(
          _logController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _runAllTests() async {
    setState(() {
      _isTesting = true;
      _logs.clear();
    });

    _addLog('Starting backend tests...');
    
    await _testUserSession();
    await _testDocuments();
    await _testTags();
    await _testSettings();
    
    _addLog('All tests completed!');
    
    setState(() {
      _isTesting = false;
    });
  }

  Future<void> _testUserSession() async {
    _addLog('--- Testing User Sessions ---');
    
    final userId = _authService.getUserId();
    if (userId == null) {
      _addLog('No user logged in - skipping session tests', isError: true);
      return;
    }

    try {
      // Test: Create Session
      _addLog('Creating new session...');
      final session = UserSession(
        userId: userId,
        token: 'test_token_${DateTime.now().millisecondsSinceEpoch}',
        deviceInfo: 'Test Device',
        ipAddress: '127.0.0.1',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 30)),
        isActive: true,
      );
      
      final createdSession = await _mongoService.createSession(session);
      if (createdSession != null) {
        _addLog('Session created successfully: ${createdSession.id}');
        
        // Test: Get Active Session
        _addLog('Fetching active session...');
        final activeSession = await _mongoService.getActiveSession(userId);
        if (activeSession != null) {
          _addLog('Active session retrieved: ${activeSession.id}');
          
          // Test: Invalidate Session
          if (activeSession.id != null) {
            _addLog('Invalidating session...');
            final invalidated = await _mongoService.invalidateSession(activeSession.id!);
            if (invalidated) {
              _addLog('Session invalidated successfully');
            } else {
              _addLog('Failed to invalidate session', isError: true);
            }
          }
        } else {
          _addLog('Failed to retrieve active session', isError: true);
        }
      } else {
        _addLog('Failed to create session', isError: true);
      }
    } catch (e) {
      _addLog('Session test error: $e', isError: true);
    }
  }

  Future<void> _testDocuments() async {
    _addLog('--- Testing Documents ---');
    
    final userId = _authService.getUserId();
    if (userId == null) {
      _addLog('No user logged in - skipping document tests', isError: true);
      return;
    }

    try {
      // Test: Create Document
      _addLog('Creating test document...');
      final document = DocumentModel(
        userId: userId,
        name: 'Test Document ${DateTime.now().millisecondsSinceEpoch}',
        content: 'This is a test document created for backend testing.',
        uploadedDate: DateTime.now(),
        tags: ['test', 'backend'],
        isFavorite: false,
      );
      
      final createdDoc = await _mongoService.createDocument(document);
      if (createdDoc != null && createdDoc.id != null) {
        _addLog('Document created: ${createdDoc.name}');
        
        // Test: Get Document
        _addLog('Retrieving document...');
        final retrievedDoc = await _mongoService.getDocument(createdDoc.id!);
        if (retrievedDoc != null) {
          _addLog('Document retrieved: ${retrievedDoc.name}');
          
          // Test: Update Document
          _addLog('Updating document...');
          final updated = await _mongoService.updateDocument(
            createdDoc.id!,
            {'isFavorite': true},
          );
          if (updated) {
            _addLog('Document updated to favorite');
          } else {
            _addLog('Failed to update document', isError: true);
          }
          
          // Test: Get User Documents
          _addLog('Fetching all user documents...');
          final userDocs = await _mongoService.getUserDocuments(userId);
          _addLog('Found ${userDocs.length} documents');
          
          // Test: Delete Document
          _addLog('Deleting test document...');
          final deleted = await _mongoService.deleteDocument(createdDoc.id!);
          if (deleted) {
            _addLog('Document deleted successfully');
          } else {
            _addLog('Failed to delete document', isError: true);
          }
        } else {
          _addLog('Failed to retrieve document', isError: true);
        }
      } else {
        _addLog('Failed to create document', isError: true);
      }
    } catch (e) {
      _addLog('Document test error: $e', isError: true);
    }
  }

  Future<void> _testTags() async {
    _addLog('--- Testing Document Tags ---');
    
    final userId = _authService.getUserId();
    if (userId == null) {
      _addLog('No user logged in - skipping tag tests', isError: true);
      return;
    }

    try {
      // Test: Create Tag
      _addLog('Creating test tag...');
      final tag = DocumentTag(
        userId: userId,
        tagName: 'Test Tag ${DateTime.now().millisecondsSinceEpoch}',
        color: '#FF5733',
        createdAt: DateTime.now(),
      );
      
      final createdTag = await _mongoService.createTag(tag);
      if (createdTag != null && createdTag.id != null) {
        _addLog('Tag created: ${createdTag.tagName}');
        
        // Test: Get User Tags
        _addLog('Fetching user tags...');
        final userTags = await _mongoService.getUserTags(userId);
        _addLog('Found ${userTags.length} tags');
        
        // Test: Delete Tag
        _addLog('Deleting test tag...');
        final deleted = await _mongoService.deleteTag(createdTag.id!);
        if (deleted) {
          _addLog('Tag deleted successfully');
        } else {
          _addLog('Failed to delete tag', isError: true);
        }
      } else {
        _addLog('Failed to create tag', isError: true);
      }
    } catch (e) {
      _addLog('Tag test error: $e', isError: true);
    }
  }

  Future<void> _testSettings() async {
    _addLog('--- Testing App Settings ---');
    
    final userId = _authService.getUserId();
    if (userId == null) {
      _addLog('No user logged in - skipping settings tests', isError: true);
      return;
    }

    try {
      // Test: Update Settings
      _addLog('Updating test settings...');
      final settingsToTest = {
        'test_string': 'Hello World',
        'test_number': 42,
        'test_boolean': true,
        'test_double': 3.14,
      };
      
      for (var entry in settingsToTest.entries) {
        final updated = await _mongoService.updateSetting(userId, entry.key, entry.value);
        if (updated) {
          _addLog('Setting updated: ${entry.key} = ${entry.value}');
        } else {
          _addLog('Failed to update setting: ${entry.key}', isError: true);
        }
      }
      
      // Test: Get Individual Settings
      _addLog('Retrieving individual settings...');
      for (var key in settingsToTest.keys) {
        final value = await _mongoService.getSetting(userId, key);
        if (value != null) {
          _addLog('Retrieved setting: $key = $value');
        } else {
          _addLog('Failed to retrieve setting: $key', isError: true);
        }
      }
      
      // Test: Get All Settings
      _addLog('Retrieving all settings...');
      final allSettings = await _mongoService.getAllSettings(userId);
      _addLog('Found ${allSettings.length} total settings');
      
    } catch (e) {
      _addLog('Settings test error: $e', isError: true);
    }
  }

  @override
  void dispose() {
    _logController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFB789DA),
        title: const Text(
          'Backend Testing',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'OpenDyslexic',
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.white),
            tooltip: 'Clear logs',
            onPressed: () {
              setState(() {
                _logs.clear();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Test Control Panel
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  onPressed: _isTesting ? null : _runAllTests,
                  icon: _isTesting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.play_arrow),
                  label: Text(
                    _isTesting ? 'Running Tests...' : 'Run All Tests',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'OpenDyslexic',
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB789DA),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTestButton(
                        'Sessions',
                        Icons.vpn_key,
                        () => _testUserSession(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTestButton(
                        'Documents',
                        Icons.description,
                        () => _testDocuments(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildTestButton(
                        'Tags',
                        Icons.label,
                        () => _testTags(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTestButton(
                        'Settings',
                        Icons.settings,
                        () => _testSettings(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Log Display
          Expanded(
            child: Container(
              color: Colors.black,
              padding: const EdgeInsets.all(16),
              child: _logs.isEmpty
                  ? Center(
                      child: Text(
                        'No tests run yet.\nPress "Run All Tests" to begin.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                          fontFamily: 'OpenDyslexic',
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _logController,
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            _logs[index],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontFamily: 'Courier New',
                              height: 1.5,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          // Status Bar
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey[200],
            child: Row(
              children: [
                Icon(
                  _authService.isLoggedIn ? Icons.check_circle : Icons.error,
                  color: _authService.isLoggedIn ? Colors.green : Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  _authService.isLoggedIn
                      ? 'User: ${_authService.getUserEmail() ?? "Unknown"}'
                      : 'Not logged in',
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'OpenDyslexic',
                  ),
                ),
                const Spacer(),
                Text(
                  '${_logs.length} logs',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontFamily: 'OpenDyslexic',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestButton(String label, IconData icon, VoidCallback onPressed) {
    return OutlinedButton.icon(
      onPressed: _isTesting ? null : onPressed,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontFamily: 'OpenDyslexic',
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFB789DA),
        side: const BorderSide(color: Color(0xFFB789DA)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}