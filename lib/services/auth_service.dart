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
      await _mongoService.updateSetting(
          userId, 'created_at', DateTime.now().toIso8601String());
    } catch (e) {
      print('Error saving user profile: $e');
    }
  }

  Future<void> _seedDefaultPreferences(String userId) async {
    try {
      final response = await http
          .post(
            Uri.parse(
                '${MongoDBService.baseUrl}/settings/seed-defaults/$userId'),
            headers: {
              'Content-Type': 'application/json',
              if (_mongoService.authToken.isNotEmpty)
                'Authorization': 'Bearer ${_mongoService.authToken}',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        print('✅ Default preferences seeded for $userId');
      } else {
        print(
            '⚠️ seed-defaults returned ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('⚠️ Could not seed default preferences: $e');
    }
  }

  // ── Sign up: creates the Firebase account immediately so the user exists
  // before reaching PhoneAuthScreen. Profile data is seeded straight away.
  Future<Map<String, dynamic>> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final token = await userCredential.user?.getIdToken();
      if (token != null && userCredential.user != null) {
        final uid = userCredential.user!.uid;
        await _createSession(uid, token);
        await _saveUserProfile(uid, email);
        await _seedDefaultPreferences(uid);
      }

      return {
        'success': true,
        'user': userCredential.user,
        'message': 'Account created. Please add your phone number.',
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
          message = 'Password must be at least 6 characters';
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
        // Refresh profile data on every login so email is always up-to-date.
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
        final session =
            await _mongoService.getActiveSession(currentUser!.uid);
        if (session != null && session.id != null) {
          await _mongoService.invalidateSession(session.id!);
        }
      }
      await _auth.signOut();
      _mongoService.setAuthToken('');
    } catch (e) {
      print('Error during logout: $e');
    }
  }

  String? getUserEmail() => currentUser?.email;
  String? getUserId() => currentUser?.uid;

  Future<String> getUsername() async {
    if (currentUser?.email != null) {
      try {
        final userId = currentUser!.uid;
        final savedName =
            await _mongoService.getSetting(userId, 'user_name');
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

  Future<Map<String, dynamic>> reauthenticateWithPassword({
    required String password,
  }) async {
    try {
      if (currentUser == null || currentUser!.email == null) {
        return {'success': false, 'message': 'No user logged in'};
      }

      final credential = EmailAuthProvider.credential(
        email: currentUser!.email!,
        password: password,
      );

      await currentUser!.reauthenticateWithCredential(credential);

      return {'success': true, 'message': 'Re-authentication successful'};
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

      return {'success': false, 'message': message};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteAccount({String? password}) async {
    try {
      if (currentUser == null) {
        return {'success': false, 'message': 'No user logged in'};
      }

      final userId = currentUser!.uid;

      if (password != null && password.isNotEmpty) {
        final reauthResult =
            await reauthenticateWithPassword(password: password);
        if (!reauthResult['success']) return reauthResult;
      }

      final token = await currentUser!.getIdToken(true);
      if (token != null) {
        _mongoService.setAuthToken(token);
      }

      try {
        final response = await http
            .delete(
              Uri.parse('${MongoDBService.baseUrl}/users/$userId'),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                if (token != null) 'Authorization': 'Bearer $token',
              },
            )
            .timeout(const Duration(seconds: 30));

        if (response.statusCode != 200) {
          print(
              '⚠️ Continuing with Firebase deletion despite backend error...');
        }
      } catch (e) {
        print('⚠️ Backend deletion error: $e — continuing with Firebase...');
      }

      try {
        await currentUser!.delete();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'requires-recent-login') {
          return {
            'success': false,
            'message': 'For security, please enter your password to continue',
            'requiresReauth': true,
          };
        }
        rethrow;
      }

      await logout();

      return {'success': true, 'message': 'Account deleted successfully'};
    } on FirebaseAuthException catch (e) {
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