// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lexilens/services/mongodb_service.dart';
import 'package:lexilens/models/user_session.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final MongoDBService _mongoService = MongoDBService();
  String? _verificationId;
  String? _pendingEmail;
  String? _pendingPassword;

  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => currentUser != null;
  
  String extractUsername(String email) {
    try {
      final parts = email.split('@');
      if (parts.isNotEmpty) {
        String username = parts[0];
        username = username.replaceAll('.', ' ').replaceAll('_', ' ');
        final words = username.split(' ');
        final capitalizedWords = words.map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        }).toList();
        
        return capitalizedWords.join(' ');
      }
      return 'User';
    } catch (e) {
      return 'User';
    }
  }
  
  String getUserDisplayName() {
    if (currentUser?.email != null) {
      return extractUsername(currentUser!.email!);
    }
    return 'User';
  }

  Future<String> _getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return '${androidInfo.manufacturer} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return '${iosInfo.name} ${iosInfo.model}';
      }
      return 'Unknown Device';
    } catch (e) {
      return 'Unknown Device';
    }
  }

  Future<void> _createSession(String userId, String token) async {
    final deviceInfo = await _getDeviceInfo();
    
    final session = UserSession(
      userId: userId,
      token: token,
      deviceInfo: deviceInfo,
      ipAddress: 'N/A', 
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 30)),
      isActive: true,
    );

    await _mongoService.createSession(session);
    _mongoService.setAuthToken(token);
  }

  Future<void> _saveUserProfile(String userId, String email) async {
    try {
      final username = extractUsername(email);
      await _mongoService.updateSetting(userId, 'user_name', username);
      await _mongoService.updateSetting(userId, 'user_email', email);
      await _mongoService.updateSetting(userId, 'created_at', DateTime.now().toIso8601String());
    } catch (e) {
      print('Error saving user profile: $e');
    }
  }

  // Sign up with email and password
  Future<Map<String, dynamic>> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      _pendingEmail = email;
      _pendingPassword = password;

      return {
        'success': true,
        'message': 'Email stored. Proceed to phone verification.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> verifyPhoneNumber({
    required String phoneNumber,
  }) async {
    try {
      _verificationId = 'fake_verification_${DateTime.now().millisecondsSinceEpoch}';

      return {
        'success': true,
        'verificationId': _verificationId,
        'message': 'Use OTP: 1234',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> verifyOTP({
    required String otp,
    required String verificationId,
  }) async {
    try {
      if (otp != '1234') {
        return {
          'success': false,
          'message': 'Invalid OTP. Please use 1234',
        };
      }

      if (_pendingEmail == null || _pendingPassword == null) {
        return {
          'success': false,
          'message': 'No pending registration found',
        };
      }
      
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _pendingEmail!,
        password: _pendingPassword!,
      );
      final token = await userCredential.user?.getIdToken();
      if (token != null && userCredential.user != null) {
        await _createSession(userCredential.user!.uid, token);
        await _saveUserProfile(userCredential.user!.uid, _pendingEmail!);
      }

      _pendingEmail = null;
      _pendingPassword = null;
      _verificationId = null;

      return {
        'success': true,
        'user': userCredential.user,
        'message': 'Registration successful',
      };
    } on FirebaseAuthException catch (e) {
      String message = 'Registration failed';
      
      switch (e.code) {
        case 'email-already-in-use':
          message = 'This email is already registered';
          break;
        case 'invalid-email':
          message = 'Invalid email address';
          break;
        case 'weak-password':
          message = 'Password is too weak';
          break;
        default:
          message = e.message ?? 'An error occurred';
      }

      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final token = await userCredential.user?.getIdToken();
      
      if (token != null && userCredential.user != null) {
        await _createSession(userCredential.user!.uid, token);
        await _saveUserProfile(userCredential.user!.uid, email);
      }
      
      return {
        'success': true,
        'user': userCredential.user,
        'message': 'Login successful',
      };
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed';
      
      switch (e.code) {
        case 'user-not-found':
          message = 'No user found with this email';
          break;
        case 'wrong-password':
          message = 'Incorrect password';
          break;
        case 'invalid-email':
          message = 'Invalid email address';
          break;
        case 'user-disabled':
          message = 'This account has been disabled';
          break;
        default:
          message = e.message ?? 'An error occurred';
      }

      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  Future<void> logout() async {
    try {
      if (currentUser != null) {
        final session = await _mongoService.getActiveSession(currentUser!.uid);
        if (session != null && session.id != null) {
          await _mongoService.invalidateSession(session.id!);
        }
      }
      await _auth.signOut();
      _pendingEmail = null;
      _pendingPassword = null;
      _verificationId = null;
      _mongoService.setAuthToken('');
    } catch (e) {
      print('Error during logout: $e');
    }
  }

  String? getUserEmail() {
    return currentUser?.email;
  }

  String? getUserId() {
    return currentUser?.uid;
  }

  Future<String> getUsername() async {
    if (currentUser?.email != null) {
      try {
        final userId = currentUser!.uid;
        final savedName = await _mongoService.getSetting(userId, 'user_name');
        if (savedName != null && savedName.toString().isNotEmpty) {
          return savedName.toString();
        }
      } catch (e) {
        print('Error getting saved username: $e');
      }
      return extractUsername(currentUser!.email!);
    }
    return 'User';
  }

  Future<Map<String, dynamic>> resetPassword({
    required String email,
  }) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return {
        'success': true,
        'message': 'Password reset email sent',
      };
    } on FirebaseAuthException catch (e) {
      return {
        'success': false,
        'message': e.message ?? 'Failed to send reset email',
      };
    }
  }

  // Password reset via backend email service
  Future<Map<String, dynamic>> requestPasswordReset({
    required String email,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${MongoDBService.baseUrl}/auth/request-reset'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      
      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Password reset email sent. Please check your inbox.',
        };
      }
      
      return {
        'success': false,
        'message': data['message'] ?? 'Failed to send reset email',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // Re-authenticate user with password
  Future<Map<String, dynamic>> reauthenticateWithPassword({
    required String password,
  }) async {
    try {
      if (currentUser == null || currentUser!.email == null) {
        return {
          'success': false,
          'message': 'No user logged in',
        };
      }

      final credential = EmailAuthProvider.credential(
        email: currentUser!.email!,
        password: password,
      );

      await currentUser!.reauthenticateWithCredential(credential);

      return {
        'success': true,
        'message': 'Re-authentication successful',
      };
    } on FirebaseAuthException catch (e) {
      String message = 'Re-authentication failed';
      
      switch (e.code) {
        case 'wrong-password':
          message = 'Incorrect password';
          break;
        case 'user-mismatch':
          message = 'Credential does not match current user';
          break;
        case 'invalid-credential':
          message = 'Invalid credentials';
          break;
        default:
          message = e.message ?? 'An error occurred';
      }

      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // Delete user account - Complete implementation
  Future<Map<String, dynamic>> deleteAccount({String? password}) async {
    try {
      if (currentUser == null) {
        return {
          'success': false,
          'message': 'No user logged in',
        };
      }
      
      final userId = currentUser!.uid;
      final userEmail = currentUser!.email;

      print('🗑️ Starting account deletion for user: $userId');

      // Step 1: Re-authenticate if password provided
      if (password != null && password.isNotEmpty) {
        print('🔐 Re-authenticating user...');
        final reauthResult = await reauthenticateWithPassword(password: password);
        if (!reauthResult['success']) {
          return reauthResult;
        }
      }

      // Step 2: Get fresh auth token
      final token = await currentUser!.getIdToken(true);
      if (token != null) {
        _mongoService.setAuthToken(token);
      }

      // Step 3: Delete from backend (MongoDB)
      print('🗄️ Deleting backend data...');
      try {
        final response = await http.delete(
          Uri.parse('${MongoDBService.baseUrl}/users/$userId'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw Exception('Backend deletion request timed out');
          },
        );

        print('Backend response status: ${response.statusCode}');
        print('Backend response body: ${response.body}');

        if (response.statusCode != 200) {
          final errorData = jsonDecode(response.body);
          print('❌ Backend deletion failed: ${errorData['message']}');
          
          // Continue with Firebase deletion even if backend fails
          print('⚠️ Continuing with Firebase deletion despite backend error...');
        } else {
          final responseData = jsonDecode(response.body);
          print('✅ Backend data deleted: ${responseData['details']}');
        }
      } catch (e) {
        print('❌ Backend deletion error: $e');
        print('⚠️ Continuing with Firebase deletion...');
      }

      // Step 4: Delete from Firebase
      print('🔥 Deleting Firebase account...');
      try {
        await currentUser!.delete();
        print('✅ Firebase account deleted');
      } on FirebaseAuthException catch (e) {
        if (e.code == 'requires-recent-login') {
          print('⚠️ Requires recent login');
          return {
            'success': false,
            'message': 'For security, please enter your password to continue',
            'requiresReauth': true,
          };
        }
        throw e;
      }

      // Step 5: Logout and clear local data
      print('🧹 Cleaning up local data...');
      await logout();

      print('✅ Account deletion completed successfully');
      
      return {
        'success': true,
        'message': 'Account deleted successfully',
      };
    } on FirebaseAuthException catch (e) {
      print('❌ Firebase error during deletion: ${e.code} - ${e.message}');
      
      if (e.code == 'requires-recent-login') {
        return {
          'success': false,
          'message': 'For security, please enter your password to continue',
          'requiresReauth': true,
        };
      }
      
      return {
        'success': false,
        'message': e.message ?? 'Failed to delete Firebase account',
      };
    } catch (e) {
      print('❌ Unexpected error during deletion: $e');
      return {
        'success': false,
        'message': 'Failed to delete account: ${e.toString()}',
      };
    }
  }

  Future<void> refreshSession() async {
    try {
      if (currentUser != null) {
        final token = await currentUser!.getIdToken(true);
        if (token != null) {
          _mongoService.setAuthToken(token);
        }
      }
    } catch (e) {
      print('Error refreshing session: $e');
    }
  }
}