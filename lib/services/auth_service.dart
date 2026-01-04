import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _verificationId;
  String? _pendingEmail;
  String? _pendingPassword;

  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  // Sign up with email and password (Step 1)
  Future<Map<String, dynamic>> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      // Store credentials for later use after phone verification
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

  // Simulate phone verification (Step 2)
  Future<Map<String, dynamic>> verifyPhoneNumber({
    required String phoneNumber,
  }) async {
    try {
      // Generate a fake verification ID
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

  // Verify OTP and complete registration (Step 3)
  Future<Map<String, dynamic>> verifyOTP({
    required String otp,
    required String verificationId,
  }) async {
    try {
      // Check if OTP is correct
      if (otp != '1234') {
        return {
          'success': false,
          'message': 'Invalid OTP. Please use 1234',
        };
      }

      // Check if we have pending credentials
      if (_pendingEmail == null || _pendingPassword == null) {
        return {
          'success': false,
          'message': 'No pending registration found',
        };
      }

      // Create user account with email and password
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _pendingEmail!,
        password: _pendingPassword!,
      );

      // Clear pending credentials
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

  // Login with email and password
  Future<Map<String, dynamic>> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

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

  // Logout
  Future<void> logout() async {
    await _auth.signOut();
    _pendingEmail = null;
    _pendingPassword = null;
    _verificationId = null;
  }

  // Get user email
  String? getUserEmail() {
    return currentUser?.email;
  }

  // Reset password
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
}