import 'package:flutter/material.dart';
import 'package:lexilens/screens/success_screen.dart';
import 'package:lexilens/services/auth_service.dart';
import 'package:lexilens/services/mongodb_service.dart';

class PhoneAuthScreen extends StatefulWidget {
  final String email;

  const PhoneAuthScreen({super.key, required this.email});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _phoneController = TextEditingController();
  final _authService = AuthService();
  final _mongoService = MongoDBService();
  final String _countryCode = '+91';
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _savePhoneAndContinue() async {
    if (_phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your phone number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_phoneController.text.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 10-digit phone number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = _authService.getUserId();
      if (userId != null) {
        final fullPhone = '$_countryCode${_phoneController.text.trim()}';
        await _mongoService.updateSetting(userId, 'user_phone', fullPhone);
      }

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SuccessScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving phone number: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _skipForNow() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SuccessScreen()),
    );
  }

  void _addDigit(String digit) {
    if (_phoneController.text.length < 10) {
      setState(() => _phoneController.text += digit);
    }
  }

  void _removeDigit() {
    if (_phoneController.text.isNotEmpty) {
      setState(() => _phoneController.text = _phoneController.text
          .substring(0, _phoneController.text.length - 1));
    }
  }

  String _formatPhoneNumber() {
    final text = _phoneController.text;
    if (text.isEmpty) return '';
    String formatted = '';
    for (int i = 0; i < text.length; i++) {
      if (i == 5) formatted += ' ';
      formatted += text[i];
    }
    return formatted;
  }

  @override
  Widget build(BuildContext context) {
    final bool phoneComplete = _phoneController.text.length >= 10;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFB789DA), Color(0xFFC89EE5)],
                ),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Add Phone Number',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'OpenDyslexic',
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _isLoading ? null : _skipForNow,
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'OpenDyslexic',
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 28),

                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8D5F0),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.phone_android,
                          size: 40, color: Color(0xFFB789DA)),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Enter your phone number',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'OpenDyslexic',
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'This will be saved to your profile',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontFamily: 'OpenDyslexic',
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Phone display
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F0FF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: phoneComplete
                              ? const Color(0xFFB789DA)
                              : Colors.grey[300]!,
                          width: phoneComplete ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFB789DA),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '+91',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'OpenDyslexic',
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _phoneController.text.isEmpty
                                  ? '_____ _____'
                                  : _formatPhoneNumber(),
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 2,
                                fontFamily: 'OpenDyslexic',
                                color: _phoneController.text.isEmpty
                                    ? Colors.grey[400]
                                    : Colors.black87,
                              ),
                            ),
                          ),
                          if (phoneComplete)
                            const Icon(Icons.check_circle,
                                color: Color(0xFFB789DA), size: 22),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Numpad
                    SizedBox(
                      width: 240,
                      child: GridView.count(
                        shrinkWrap: true,
                        crossAxisCount: 3,
                        childAspectRatio: 1.4,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildNumberButton('1'),
                          _buildNumberButton('2'),
                          _buildNumberButton('3'),
                          _buildNumberButton('4'),
                          _buildNumberButton('5'),
                          _buildNumberButton('6'),
                          _buildNumberButton('7'),
                          _buildNumberButton('8'),
                          _buildNumberButton('9'),
                          const SizedBox(),
                          _buildNumberButton('0'),
                          _buildBackspaceButton(),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Continue button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : (phoneComplete ? _savePhoneAndContinue : null),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB789DA),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey[300],
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Text(
                                'Save & Continue',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'OpenDyslexic',
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberButton(String number) {
    return InkWell(
      onTap: _isLoading ? null : () => _addDigit(number),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[300]!),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              fontFamily: 'OpenDyslexic',
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton() {
    return InkWell(
      onTap: _isLoading ? null : _removeDigit,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[300]!),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(
          child: Icon(Icons.backspace_outlined,
              size: 20, color: Color(0xFFB789DA)),
        ),
      ),
    );
  }
}