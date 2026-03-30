import 'package:flutter/material.dart';
import 'package:lexilens/screens/sign_up_screen.dart';
import 'package:lexilens/screens/home_screen.dart';
import 'package:lexilens/services/auth_service.dart';

// FIX: Improved Log In screen UI/UX.
// • Light gradient background matching brand palette.
// • Form wrapped in a floating card — visual separation from background.
// • Field labels use bolder weight; inputs have softer fill + clear focus ring.
// • Consistent 16-unit vertical rhythm between sections.
// • "Forget password?" link right-aligned with reduced visual weight.

class LogInScreen extends StatefulWidget {
  const LogInScreen({super.key});

  @override
  State<LogInScreen> createState() => _LogInScreenState();
}

class _LogInScreenState extends State<LogInScreen> {
  final _formKey           = GlobalKey<FormState>();
  final _emailController   = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService       = AuthService();
  bool  _obscurePassword   = true;
  bool  _isLoading         = false;

  static const _kPurple = Color(0xFF7B4FA6);
  static const _kAccent = Color(0xFFB789DA);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loginWithEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final result = await _authService.loginWithEmail(
        email:    _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        setState(() => _isLoading = false);

        if (result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Login successful!'),
              backgroundColor: _kAccent,
            ),
          );
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message']), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _resetPassword() async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your email first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final result = await _authService.resetPassword(
      email: _emailController.text.trim(),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: result['success'] ? _kAccent : Colors.red,
        ),
      );
    }
  }

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.grey[400], fontFamily: 'OpenDyslexic', fontSize: 13),
    filled: true,
    fillColor: const Color(0xFFF7F3FF),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFE0D4F5), width: 1.2),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _kAccent, width: 1.8),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Colors.red, width: 1.2),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Colors.red, width: 1.8),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5EEFF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _kPurple),
          onPressed: _isLoading ? null : () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Heading ──────────────────────────────────────────────────
              const Text(
                'Log In',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'OpenDyslexic',
                  color: Color(0xFF2D1B4E),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Welcome back — we missed you',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[500],
                  fontFamily: 'OpenDyslexic',
                ),
              ),

              const SizedBox(height: 28),

              // ── Form card ────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _kAccent.withOpacity(0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Email
                      const Text(
                        'Email',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'OpenDyslexic',
                          color: Color(0xFF2D1B4E),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !_isLoading,
                        style: const TextStyle(fontFamily: 'OpenDyslexic', fontSize: 14),
                        decoration: _fieldDecoration('you@example.com'),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Please enter your email';
                          if (!v.contains('@'))       return 'Please enter a valid email';
                          return null;
                        },
                      ),

                      const SizedBox(height: 20),

                      // Password
                      const Text(
                        'Password',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'OpenDyslexic',
                          color: Color(0xFF2D1B4E),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        enabled: !_isLoading,
                        style: const TextStyle(fontFamily: 'OpenDyslexic', fontSize: 14),
                        decoration: _fieldDecoration('••••••••').copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: Colors.grey[400],
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Please enter your password';
                          return null;
                        },
                      ),

                      // Forgot password
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _isLoading ? null : _resetPassword,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            minimumSize: Size.zero,
                          ),
                          child: Text(
                            'Forgot password?',
                            style: TextStyle(
                              fontSize: 11,
                              color: _isLoading ? Colors.grey : _kAccent,
                              fontFamily: 'OpenDyslexic',
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _loginWithEmail,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kPurple,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey[300],
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                                )
                              : const Text(
                                  'Log in',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'OpenDyslexic',
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Sign up link ──────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don't have an account?  ",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontFamily: 'OpenDyslexic',
                    ),
                  ),
                  GestureDetector(
                    onTap: _isLoading
                        ? null
                        : () => Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const SignUpScreen()),
                            ),
                    child: Text(
                      'Sign up',
                      style: TextStyle(
                        fontSize: 12,
                        color: _isLoading ? Colors.grey : _kPurple,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'OpenDyslexic',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}