import 'package:flutter/material.dart';
import 'package:lexilens/screens/success_screen.dart';
import 'package:lexilens/services/auth_service.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;

  const OTPVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
  });

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final List<String> _otpDigits = ['', '', '', ''];
  final _authService = AuthService();
  int _currentIndex = 0;
  bool _isLoading = false;

  Future<void> _verifyOTP() async {
    String otp = _otpDigits.join();
    
    if (otp.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter complete OTP'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _authService.verifyOTP(
        otp: otp,
        verificationId: widget.verificationId,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Registration successful!'),
              backgroundColor: Color(0xFFB789DA),
            ),
          );

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const SuccessScreen()),
            (route) => false,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: Colors.red,
            ),
          );
          
          // Reset OTP fields on error
          setState(() {
            _otpDigits.fillRange(0, 4, '');
            _currentIndex = 0;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _resendOTP() async {
    if (_isLoading) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('OTP resent! Use: 1234'),
        backgroundColor: Color(0xFFB789DA),
        duration: Duration(seconds: 3),
      ),
    );

    // Reset OTP fields
    setState(() {
      _otpDigits.fillRange(0, 4, '');
      _currentIndex = 0;
    });
  }

  void _addDigit(String digit) {
    if (_currentIndex < 4 && !_isLoading) {
      setState(() {
        _otpDigits[_currentIndex] = digit;
        _currentIndex++;
      });
      if (_currentIndex == 4) {
        _verifyOTP();
      }
    }
  }

  void _removeDigit() {
    if (_currentIndex > 0 && !_isLoading) {
      setState(() {
        _currentIndex--;
        _otpDigits[_currentIndex] = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.close, 
            color: Colors.black,
          ),
          onPressed: _isLoading ? null : () => Navigator.pop(context),
        ),
        title: const Text(
          'Verify Phone',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'OpenDyslexic',
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 40),
              Text(
                'Code is sent to ${widget.phoneNumber}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontFamily: 'OpenDyslexic',
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Default OTP: 1234',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: const Color(0xFFB789DA),
                  fontWeight: FontWeight.bold,
                  fontFamily: 'OpenDyslexic',
                ),
              ),
              const SizedBox(height: 40),
              // OTP Input boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  4,
                  (index) => Container(
                    width: 60,
                    height: 60,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _currentIndex == index
                            ? const Color(0xFFB789DA)
                            : Colors.grey[300]!,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: _isLoading && index == 3
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Color(0xFFB789DA),
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              _otpDigits[index],
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'OpenDyslexic',
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Resend OTP
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Didn't receive code? ",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontFamily: 'OpenDyslexic',
                    ),
                  ),
                  GestureDetector(
                    onTap: _isLoading ? null : _resendOTP,
                    child: Text(
                      'Request again',
                      style: TextStyle(
                        fontSize: 12,
                        color: _isLoading
                            ? Colors.grey
                            : const Color(0xFFB789DA),
                        fontWeight: FontWeight.bold,
                        fontFamily: 'OpenDyslexic',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              // Verify Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : (_otpDigits.join().length == 4 ? _verifyOTP : null),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB789DA),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Verify and Create Account',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'OpenDyslexic',
                          ),
                        ),
                ),
              ),
              const Spacer(),
              // Number pad 
              SizedBox(
                width: 280,
                child: GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 3,
                  childAspectRatio: 1.4,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumberButton(String number) {
    return InkWell(
      onTap: _isLoading ? null : () => _addDigit(number),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: Colors.grey[300]!,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              fontFamily: 'OpenDyslexic',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton() {
    return InkWell(
      onTap: _isLoading ? null : _removeDigit,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: Colors.grey[300]!,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Icon(
            Icons.backspace_outlined,
            size: 22,
            color: Color(0xFFB789DA),
          ),
        ),
      ),
    );
  }
}