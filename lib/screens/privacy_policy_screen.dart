import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFB789DA),
        title: const Text(
          'Privacy Policy',
          style: TextStyle(
            fontFamily: 'OpenDyslexic',
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          _SectionTitle('Last Updated: April 2025'),
          SizedBox(height: 16),
          _BodyText(
            'LexiLens ("we", "our", or "us") is committed to protecting your privacy. '
            'This Privacy Policy explains how we collect, use, and safeguard your '
            'information when you use the LexiLens mobile application. By using the '
            'app, you agree to the collection and use of information in accordance '
            'with this policy.',
          ),
          SizedBox(height: 24),

          _SectionTitle('1. Information We Collect'),
          SizedBox(height: 8),
          _SubTitle('Personal Information'),
          _BodyText(
            'When you create an account, we collect:\n'
            '• Full name\n'
            '• Email address\n'
            '• Phone number (optional)\n'
            '• Profile picture (optional)',
          ),
          SizedBox(height: 12),
          _SubTitle('Usage Data'),
          _BodyText(
            'We automatically collect certain information when you use the app, including:\n'
            '• Device type and operating system\n'
            '• App features accessed and time spent\n'
            '• Scanned document metadata (not the document content itself)\n'
            '• Reading preferences and accessibility settings',
          ),
          SizedBox(height: 12),
          _SubTitle('Camera & Media'),
          _BodyText(
            'LexiLens uses your camera to scan documents and enable the AR reading '
            'overlay feature. Images are processed locally on your device for OCR. '
            'Documents you choose to save are stored securely on our servers tied '
            'to your account.',
          ),
          SizedBox(height: 24),

          _SectionTitle('2. How We Use Your Information'),
          SizedBox(height: 8),
          _BodyText(
            'We use the information we collect to:\n'
            '• Create and manage your LexiLens account\n'
            '• Provide and personalise accessibility features for dyslexia support\n'
            '• Remember your reading preferences (font, size, colour, spacing)\n'
            '• Sync your saved documents across devices\n'
            '• Respond to support requests and feedback\n'
            '• Improve the accuracy and performance of our OCR and text overlay features\n'
            '• Ensure the security of your account',
          ),
          SizedBox(height: 24),

          _SectionTitle('3. Data Storage & Security'),
          SizedBox(height: 8),
          _BodyText(
            'Your data is stored securely using industry-standard encryption. '
            'We use Firebase Authentication for secure sign-in and MongoDB for '
            'storing your settings and documents. Access to your data is restricted '
            'to authorised personnel only.\n\n'
            'While we take reasonable measures to protect your information, no '
            'method of transmission over the internet is 100% secure. We encourage '
            'you to use a strong password and keep your login credentials private.',
          ),
          SizedBox(height: 24),

          _SectionTitle('4. Third-Party Services'),
          SizedBox(height: 8),
          _BodyText(
            'LexiLens uses the following third-party services that may collect '
            'information as described in their own privacy policies:\n'
            '• Firebase (Google) — Authentication and crash reporting\n'
            '• MongoDB Atlas — Secure cloud database storage\n'
            '• Google ML Kit — On-device OCR text recognition\n\n'
            'We do not sell, trade, or rent your personal information to third parties.',
          ),
          SizedBox(height: 24),

          _SectionTitle('5. Children\'s Privacy'),
          SizedBox(height: 8),
          _BodyText(
            'LexiLens is designed to support users of all ages, including children '
            'with dyslexia. We do not knowingly collect personal information from '
            'children under 13 without parental consent. If you believe your child '
            'has provided us with personal information without your consent, please '
            'contact us immediately.',
          ),
          SizedBox(height: 24),

          _SectionTitle('6. Your Rights'),
          SizedBox(height: 8),
          _BodyText(
            'You have the right to:\n'
            '• Access the personal data we hold about you\n'
            '• Request correction of inaccurate information\n'
            '• Request deletion of your account and all associated data\n'
            '• Export your saved documents at any time\n\n'
            'You can delete your account directly from the app by going to '
            'Profile → Edit Profile → Delete Account.',
          ),
          SizedBox(height: 24),

          _SectionTitle('7. Data Retention'),
          SizedBox(height: 8),
          _BodyText(
            'We retain your personal information for as long as your account is '
            'active. If you delete your account, all associated data — including '
            'your profile information, saved documents, and settings — will be '
            'permanently removed from our servers within 30 days.',
          ),
          SizedBox(height: 24),

          _SectionTitle('8. Changes to This Policy'),
          SizedBox(height: 8),
          _BodyText(
            'We may update this Privacy Policy from time to time. We will notify '
            'you of any significant changes by updating the "Last Updated" date at '
            'the top of this page. Continued use of the app after changes are '
            'posted constitutes your acceptance of the updated policy.',
          ),
          SizedBox(height: 24),

          _SectionTitle('9. Contact Us'),
          SizedBox(height: 8),
          _BodyText(
            'If you have any questions or concerns about this Privacy Policy or '
            'how we handle your data, please contact us at:\n\n'
            'Email: privacy@lexilens.app\n'
            'We aim to respond to all enquiries within 5 business days.',
          ),
          SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: Color(0xFFB789DA),
        fontFamily: 'OpenDyslexic',
      ),
    );
  }
}

class _SubTitle extends StatelessWidget {
  final String text;
  const _SubTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
        fontFamily: 'OpenDyslexic',
      ),
    );
  }
}

class _BodyText extends StatelessWidget {
  final String text;
  const _BodyText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        height: 1.7,
        color: Colors.black87,
        fontFamily: 'OpenDyslexic',
      ),
    );
  }
}