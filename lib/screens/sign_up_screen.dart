import 'package:flutter/material.dart';
import 'package:lexilens/screens/phone_auth_screen.dart';
import 'package:lexilens/screens/log_in_screen.dart';
import 'package:lexilens/services/auth_service.dart';

// FIX: Improved Sign Up screen UI/UX.
// • Matches the redesigned LogInScreen visual language (gradient bg, card form).
// • Cleaner field labels + consistent spacing.
// • Terms checkbox row is more compact and accessible.

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey            = GlobalKey<FormState>();
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService        = AuthService();
  bool  _obscurePassword    = true;
  bool  _agreedToTerms      = false;
  bool  _isLoading          = false;

  static const _kPurple = Color(0xFF7B4FA6);
  static const _kAccent = Color(0xFFB789DA);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signUpWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the terms & conditions'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _authService.signUpWithEmail(
        email:    _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        setState(() => _isLoading = false);

        if (result['success']) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PhoneAuthScreen(email: _emailController.text.trim()),
            ),
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
          onPressed: () => Navigator.pop(context),
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
                'Create Account',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'OpenDyslexic',
                  color: Color(0xFF2D1B4E),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Fill in your details below to get started',
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
                        decoration: _fieldDecoration('Min. 6 characters').copyWith(
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
                          if (v == null || v.isEmpty) return 'Please enter a password';
                          if (v.length < 6)           return 'Password must be at least 6 characters';
                          return null;
                        },
                      ),

                      const SizedBox(height: 20),

                      // Terms checkbox
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: _agreedToTerms,
                              onChanged: _isLoading
                                  ? null
                                  : (v) => setState(() => _agreedToTerms = v ?? false),
                              activeColor: _kPurple,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'I agree to the Terms & Conditions',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                                fontFamily: 'OpenDyslexic',
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Submit
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _signUpWithEmail,
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
                                  'Create Account',
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

              // ── Login link ────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account?  ',
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
                              MaterialPageRoute(builder: (_) => const LogInScreen()),
                            ),
                    child: Text(
                      'Log in',
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