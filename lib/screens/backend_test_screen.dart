// lib/screens/backend_test_screen.dart (IMPROVED VERSION)
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
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _testConnection();
  }

  Future<void> _testConnection() async {
    _addLog('Testing backend connection...', isInfo: true);
    
    final connected = await _mongoService.testConnection();
    
    setState(() {
      _isConnected = connected;
    });
    
    if (connected) {
      _addLog('✅ Backend connected successfully!');
    } else {
      _addLog('❌ Backend connection failed!', isError: true);
      _addLog('Please check your backend URL in mongodb_service.dart', isError: true);
    }
  }

  void _addLog(String message, {bool isError = false, bool isInfo = false}) {
    setState(() {
      final timestamp = DateTime.now().toString().substring(11, 19);
      final icon = isError ? '❌' : (isInfo ? 'ℹ️' : '✅');
      _logs.add('[$timestamp] $icon $message');
    });
    
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
    if (!_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backend not connected! Please check your configuration.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isTesting = true;
      _logs.clear();
    });

    _addLog('Starting comprehensive backend tests...', isInfo: true);
    
    await _testConnection();
    await _testUserSession();
    await _testDocuments();
    await _testTags();
    await _testSettings();
    
    _addLog('All tests completed!', isInfo: true);
    
    setState(() {
      _isTesting = false;
    });
  }

  Future<void> _testUserSession() async {
    _addLog('--- Testing User Sessions ---', isInfo: true);
    
    final userId = _authService.getUserId();
    if (userId == null) {
      _addLog('No user logged in - skipping session tests', isError: true);
      return;
    }

    try {
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
        _addLog('Session created: ${createdSession.id}');
        
        _addLog('Fetching active session...');
        final activeSession = await _mongoService.getActiveSession(userId);
        if (activeSession != null) {
          _addLog('Active session retrieved: ${activeSession.id}');
          
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
    _addLog('--- Testing Documents ---', isInfo: true);
    
    final userId = _authService.getUserId();
    if (userId == null) {
      _addLog('No user logged in - skipping document tests', isError: true);
      return;
    }

    try {
      _addLog('Creating test document...');
      final document = DocumentModel(
        userId: userId,
        name: 'Test_Doc_${DateTime.now().millisecondsSinceEpoch}',
        content: 'This is a test document for backend testing.',
        uploadedDate: DateTime.now(),
        tags: ['test', 'backend'],
        isFavorite: false,
      );
      
      final createdDoc = await _mongoService.createDocument(document);
      if (createdDoc != null && createdDoc.id != null) {
        _addLog('Document created: ${createdDoc.name}');
        
        _addLog('Retrieving document...');
        final retrievedDoc = await _mongoService.getDocument(createdDoc.id!);
        if (retrievedDoc != null) {
          _addLog('Document retrieved: ${retrievedDoc.name}');
          
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
          
          _addLog('Fetching all user documents...');
          final userDocs = await _mongoService.getUserDocuments(userId);
          _addLog('Found ${userDocs.length} documents');
          
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
    _addLog('--- Testing Document Tags ---', isInfo: true);
    
    final userId = _authService.getUserId();
    if (userId == null) {
      _addLog('No user logged in - skipping tag tests', isError: true);
      return;
    }

    try {
      _addLog('Creating test tag...');
      final tag = DocumentTag(
        userId: userId,
        tagName: 'Test_Tag_${DateTime.now().millisecondsSinceEpoch}',
        color: '#FF5733',
        createdAt: DateTime.now(),
      );
      
      final createdTag = await _mongoService.createTag(tag);
      if (createdTag != null && createdTag.id != null) {
        _addLog('Tag created: ${createdTag.tagName}');
        
        _addLog('Fetching user tags...');
        final userTags = await _mongoService.getUserTags(userId);
        _addLog('Found ${userTags.length} tags');
        
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
    _addLog('--- Testing App Settings ---', isInfo: true);
    
    final userId = _authService.getUserId();
    if (userId == null) {
      _addLog('No user logged in - skipping settings tests', isError: true);
      return;
    }

    try {
      _addLog('Updating test settings...');
      final settingsToTest = {
        'test_string': 'Hello Backend',
        'test_number': 42,
        'test_boolean': true,
        'test_double': 3.14,
      };
      
      for (var entry in settingsToTest.entries) {
        final updated = await _mongoService.updateSetting(userId, entry.key, entry.value);
        if (updated) {
          _addLog('Setting updated: ${entry.key} = ${entry.value}');
        } else {
          _addLog('Failed to update: ${entry.key}', isError: true);
        }
      }
      
      _addLog('Retrieving individual settings...');
      for (var key in settingsToTest.keys) {
        final value = await _mongoService.getSetting(userId, key);
        if (value != null) {
          _addLog('Retrieved: $key = $value');
        } else {
          _addLog('Failed to retrieve: $key', isError: true);
        }
      }
      
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
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh connection',
            onPressed: _testConnection,
          ),
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
          // Connection Status
          Container(
            padding: const EdgeInsets.all(16),
            color: _isConnected ? Colors.green.shade50 : Colors.red.shade50,
            child: Row(
              children: [
                Icon(
                  _isConnected ? Icons.check_circle : Icons.error,
                  color: _isConnected ? Colors.green : Colors.red,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isConnected ? 'Backend Connected' : 'Backend Disconnected',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _isConnected ? Colors.green.shade900 : Colors.red.shade900,
                          fontFamily: 'OpenDyslexic',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isConnected 
                            ? 'Ready to run tests' 
                            : 'Check your backend URL configuration',
                        style: TextStyle(
                          fontSize: 12,
                          color: _isConnected ? Colors.green.shade700 : Colors.red.shade700,
                          fontFamily: 'OpenDyslexic',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Test Control Panel
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isTesting || !_isConnected ? null : _runAllTests,
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
                      disabledBackgroundColor: Colors.grey[400],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
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
                Expanded(
                  child: Text(
                    _authService.isLoggedIn
                        ? 'User: ${_authService.getUserEmail() ?? "Unknown"}'
                        : 'Not logged in',
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'OpenDyslexic',
                    ),
                  ),
                ),
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
}