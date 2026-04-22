import 'package:flutter/material.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFB789DA),
        title: const Text(
          'Terms of Service',
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
            'Please read these Terms of Service ("Terms") carefully before using '
            'the LexiLens mobile application ("the App") operated by LexiLens '
            '("we", "us", or "our"). By creating an account or using the App, '
            'you agree to be bound by these Terms. If you do not agree, '
            'please do not use the App.',
          ),
          SizedBox(height: 24),

          _SectionTitle('1. Eligibility'),
          SizedBox(height: 8),
          _BodyText(
            'LexiLens is available to users of all ages. Users under the age of 13 '
            'must have parental or guardian consent before creating an account. By '
            'using the App, you confirm that you have the legal capacity to enter '
            'into this agreement, or that a parent or guardian has consented on '
            'your behalf.',
          ),
          SizedBox(height: 24),

          _SectionTitle('2. Your Account'),
          SizedBox(height: 8),
          _BodyText(
            'You are responsible for maintaining the confidentiality of your login '
            'credentials and for all activity that occurs under your account. You '
            'agree to:\n'
            '• Provide accurate and complete information when registering\n'
            '• Notify us immediately of any unauthorised use of your account\n'
            '• Not share your account credentials with others\n\n'
            'We reserve the right to suspend or terminate accounts that violate '
            'these Terms.',
          ),
          SizedBox(height: 24),

          _SectionTitle('3. Permitted Use'),
          SizedBox(height: 8),
          _BodyText(
            'LexiLens is a reading-assistance application designed to support '
            'individuals with dyslexia and other reading challenges. You may use '
            'the App to:\n'
            '• Scan and digitise physical documents for personal reading\n'
            '• Apply accessibility features such as dyslexic-friendly fonts, '
            'text resizing, colour overlays, and text-to-speech\n'
            '• Save and manage your personal documents within the App\n'
            '• Use the AR live-reading overlay for real-world text\n\n'
            'You agree not to use the App for any unlawful, harmful, or '
            'unauthorised purpose.',
          ),
          SizedBox(height: 24),

          _SectionTitle('4. Prohibited Activities'),
          SizedBox(height: 8),
          _BodyText(
            'You must not:\n'
            '• Scan, store, or distribute copyrighted material without proper authorisation\n'
            '• Attempt to reverse-engineer, decompile, or tamper with the App\n'
            '• Use the App to collect data about other users\n'
            '• Upload or transmit malicious code or harmful content\n'
            '• Impersonate another person or entity\n'
            '• Use the App in any way that disrupts or damages our services',
          ),
          SizedBox(height: 24),

          _SectionTitle('5. Intellectual Property'),
          SizedBox(height: 8),
          _BodyText(
            'All content within the App — including the LexiLens name, logo, '
            'interface design, code, and features — is the intellectual property '
            'of LexiLens and is protected by applicable copyright, trademark, '
            'and intellectual property laws.\n\n'
            'You retain ownership of any documents you scan or upload. By using '
            'the App, you grant us a limited licence to store and process your '
            'content solely to provide the services described in these Terms.',
          ),
          SizedBox(height: 24),

          _SectionTitle('6. Accessibility Commitment'),
          SizedBox(height: 8),
          _BodyText(
            'LexiLens is built with accessibility at its core. We are committed '
            'to continuously improving the App for users with dyslexia, visual '
            'stress, and other reading-related challenges. We welcome feedback '
            'to help us improve.',
          ),
          SizedBox(height: 24),

          _SectionTitle('7. Disclaimers'),
          SizedBox(height: 8),
          _BodyText(
            'The App is provided on an "as is" and "as available" basis. While '
            'we strive for accuracy in our OCR and text processing features, '
            'we do not guarantee that results will always be error-free. '
            'LexiLens is not a medical device and is not intended to diagnose, '
            'treat, or cure any condition.',
          ),
          SizedBox(height: 24),

          _SectionTitle('8. Limitation of Liability'),
          SizedBox(height: 8),
          _BodyText(
            'To the fullest extent permitted by applicable law, LexiLens shall '
            'not be liable for any indirect, incidental, special, or consequential '
            'damages arising from your use of — or inability to use — the App. '
            'This includes loss of data, loss of profits, or any other damages, '
            'even if we have been advised of the possibility of such damages.',
          ),
          SizedBox(height: 24),

          _SectionTitle('9. Termination'),
          SizedBox(height: 8),
          _BodyText(
            'You may stop using the App and delete your account at any time from '
            'within the App (Profile → Edit Profile → Delete Account). We may '
            'suspend or terminate your access if you breach these Terms. '
            'Upon termination, your right to use the App ceases immediately.',
          ),
          SizedBox(height: 24),

          _SectionTitle('10. Changes to These Terms'),
          SizedBox(height: 8),
          _BodyText(
            'We may revise these Terms at any time. We will notify you of material '
            'changes by updating the "Last Updated" date. Continued use of the App '
            'after changes are posted means you accept the revised Terms.',
          ),
          SizedBox(height: 24),

          _SectionTitle('11. Governing Law'),
          SizedBox(height: 8),
          _BodyText(
            'These Terms shall be governed by and construed in accordance with the '
            'laws of India. Any disputes arising under these Terms shall be subject '
            'to the exclusive jurisdiction of the courts located in India.',
          ),
          SizedBox(height: 24),

          _SectionTitle('12. Contact Us'),
          SizedBox(height: 8),
          _BodyText(
            'If you have any questions about these Terms, please contact us at:\n\n'
            'Email: legal@lexilens.app\n'
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