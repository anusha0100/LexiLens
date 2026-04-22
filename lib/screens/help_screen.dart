import 'package:flutter/material.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'Popular Topic';
  int? _expandedIndex;

  final Map<String, List<FAQItem>> _categoryFAQs = {
    'Popular Topic': [
      FAQItem(
        question: 'How do I scan a document?',
        answer:
            'Tap the camera icon on the home screen or go to the Scanner tab. '
            'Point your camera at the document and tap the shutter button. '
            'LexiLens will automatically detect the text and display it in your '
            'chosen dyslexia-friendly format. Make sure the document is well-lit '
            'and held flat for the best results.',
      ),
      FAQItem(
        question: 'How do I change the reading font?',
        answer:
            'Go to Settings → Reading Preferences. You can switch between '
            'OpenDyslexic (the default dyslexia-friendly font), Noto Sans Devanagari, '
            'and standard system fonts. Changes apply immediately across all your '
            'documents and the reading screen.',
      ),
      FAQItem(
        question: 'What is AR Reading mode?',
        answer:
            'AR (Augmented Reality) Reading mode overlays the recognised text '
            'directly onto your live camera view in real time. This is great for '
            'reading signs, menus, labels, and other text in the real world. '
            'Access it from the home screen by tapping the AR icon.',
      ),
      FAQItem(
        question: 'Are my documents saved automatically?',
        answer:
            'Yes. After you scan a document, it is automatically saved to your '
            'account and synced to the cloud. You can find all your saved documents '
            'in the Documents tab. Documents are tied to your account, so they '
            'are accessible even if you switch devices.',
      ),
      FAQItem(
        question: 'Can I adjust text size and spacing?',
        answer:
            'Absolutely. In Settings → Reading Preferences, you can independently '
            'control font size, letter spacing, word spacing, and line height. '
            'These settings are designed to reduce visual crowding — a common '
            'challenge for readers with dyslexia.',
      ),
      FAQItem(
        question: 'Does LexiLens support text-to-speech?',
        answer:
            'Yes. While reading any document, tap the speaker icon in the toolbar '
            'to have the text read aloud. You can adjust the speech speed and '
            'pause at any time. The reading ruler can also follow along to help '
            'you track your place on the page.',
      ),
    ],
    'General': [
      FAQItem(
        question: 'Is LexiLens free to use?',
        answer:
            'LexiLens offers a free tier that includes core scanning and reading '
            'features. Advanced features may be available through future premium '
            'plans. Check the app for the latest information on available plans.',
      ),
      FAQItem(
        question: 'Which languages does LexiLens support?',
        answer:
            'LexiLens currently supports English and Hindi text recognition. '
            'We are actively working on expanding language support. The app '
            'interface is available in English.',
      ),
      FAQItem(
        question: 'How do I update my profile information?',
        answer:
            'Tap on your profile icon or avatar in the top corner of the home '
            'screen, then select "Edit Profile". You can update your name, '
            'phone number, and profile picture from there.',
      ),
      FAQItem(
        question: 'Can I use LexiLens offline?',
        answer:
            'Some features require an internet connection, including syncing '
            'documents and saving to the cloud. Basic scanning and reading of '
            'already-saved documents may work offline depending on your device.',
      ),
    ],
    'Services': [
      FAQItem(
        question: 'How do I export or share a document?',
        answer:
            'Open the document in the Documents tab, tap the three-dot menu '
            'in the top-right corner, and select "Export". You can share the '
            'extracted text as a plain text file or copy it to your clipboard.',
      ),
      FAQItem(
        question: 'How do I delete a saved document?',
        answer:
            'In the Documents tab, swipe left on the document you want to delete '
            'and tap the delete icon. You can also open the document, tap the '
            'options menu, and choose "Delete". This action cannot be undone.',
      ),
      FAQItem(
        question: 'How do I delete my account?',
        answer:
            'Go to Profile → Edit Profile and scroll to the "Danger Zone" section '
            'at the bottom. Tap "Delete Account" and confirm with your password. '
            'This will permanently remove your account and all associated data '
            'and cannot be undone.',
      ),
      FAQItem(
        question: 'My scan results look wrong — what should I do?',
        answer:
            'OCR accuracy depends on image quality. For best results: ensure '
            'good lighting, hold the camera steady and parallel to the page, '
            'and avoid shadows or glare. For handwritten text, accuracy may '
            'vary. If the result is still incorrect, try re-scanning.',
      ),
    ],
  };

  List<FAQItem> get _currentFAQItems =>
      _categoryFAQs[_selectedCategory] ?? [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header Section
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFB789DA),
                  Color(0xFFC89EE5),
                ],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 24,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Expanded(
                          child: Text(
                            'Help Center',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontFamily: 'OpenDyslexic',
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'How Can We Help You?',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontFamily: 'OpenDyslexic',
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Search Bar
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search...',
                          hintStyle: TextStyle(
                            color: Colors.grey[400],
                            fontFamily: 'OpenDyslexic',
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Colors.grey[400],
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Tab Bar
          Container(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _tabController.animateTo(0),
                      child: Container(
                        height: 45,
                        decoration: BoxDecoration(
                          color: _tabController.index == 0
                              ? const Color(0xFFB789DA)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(
                            color: const Color(0xFFB789DA),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'FAQ',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _tabController.index == 0
                                  ? Colors.white
                                  : const Color(0xFFB789DA),
                              fontFamily: 'OpenDyslexic',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _tabController.animateTo(1),
                      child: Container(
                        height: 45,
                        decoration: BoxDecoration(
                          color: _tabController.index == 1
                              ? const Color(0xFFB789DA)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(
                            color: const Color(0xFFB789DA),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Contact Us',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _tabController.index == 1
                                  ? Colors.white
                                  : const Color(0xFFB789DA),
                              fontFamily: 'OpenDyslexic',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFAQTab(),
                _buildContactUsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQTab() {
    final query = _searchController.text.trim().toLowerCase();

    // Search across all categories when query is active
    final List<FAQItem> displayItems = query.isEmpty
        ? _currentFAQItems
        : _categoryFAQs.values
            .expand((items) => items)
            .where((item) =>
                item.question.toLowerCase().contains(query) ||
                item.answer.toLowerCase().contains(query))
            .toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Category Pills (hidden during search)
        if (query.isEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCategoryPill('Popular Topic'),
                const SizedBox(width: 8),
                _buildCategoryPill('General'),
                const SizedBox(width: 8),
                _buildCategoryPill('Services'),
              ],
            ),
          ),
        if (query.isEmpty) const SizedBox(height: 20),

        // Search result label
        if (query.isNotEmpty) ...[
          Text(
            '${displayItems.length} result${displayItems.length == 1 ? '' : 's'} for "$query"',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontFamily: 'OpenDyslexic',
            ),
          ),
          const SizedBox(height: 16),
        ],

        // FAQ Items
        if (displayItems.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(
              child: Text(
                'No results found.\nTry a different search term.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontFamily: 'OpenDyslexic',
                  height: 1.6,
                ),
              ),
            ),
          )
        else
          ...displayItems.asMap().entries.map((entry) {
            return _buildFAQItem(entry.value, entry.key);
          }).toList(),
      ],
    );
  }

  Widget _buildCategoryPill(String category) {
    final isSelected = _selectedCategory == category;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = category;
          _expandedIndex = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFB789DA) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFB789DA),
            width: 1.5,
          ),
        ),
        child: Text(
          category,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFFB789DA),
            fontFamily: 'OpenDyslexic',
          ),
        ),
      ),
    );
  }

  Widget _buildFAQItem(FAQItem item, int index) {
    final isExpanded = _expandedIndex == index;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isExpanded ? const Color(0xFFB789DA) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFB789DA),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _expandedIndex = isExpanded ? null : index;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.question,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isExpanded
                            ? Colors.white
                            : const Color(0xFFB789DA),
                        fontFamily: 'OpenDyslexic',
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color:
                        isExpanded ? Colors.white : const Color(0xFFB789DA),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                item.answer,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white,
                  height: 1.6,
                  fontFamily: 'OpenDyslexic',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContactUsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Text(
            'Reach out to us through any of the channels below and we\'ll get back to you as soon as possible.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey,
              fontFamily: 'OpenDyslexic',
              height: 1.6,
            ),
          ),
        ),
        _buildContactOption(
          icon: Icons.email_outlined,
          title: 'Email Support',
          subtitle: 'support@lexilens.app',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Opening email client...'),
                backgroundColor: Color(0xFFB789DA),
              ),
            );
          },
        ),
        _buildContactOption(
          icon: Icons.headset_mic,
          title: 'Customer Service',
          subtitle: 'Mon–Fri, 9 AM – 6 PM IST',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Connecting to customer service...'),
                backgroundColor: Color(0xFFB789DA),
              ),
            );
          },
        ),
        _buildContactOption(
          icon: Icons.language,
          title: 'Website',
          subtitle: 'www.lexilens.app',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Opening website...'),
                backgroundColor: Color(0xFFB789DA),
              ),
            );
          },
        ),
        _buildContactOption(
          icon: Icons.message,
          title: 'WhatsApp',
          subtitle: 'Chat with us directly',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Opening WhatsApp...'),
                backgroundColor: Color(0xFFB789DA),
              ),
            );
          },
        ),
        _buildContactOption(
          icon: Icons.facebook,
          title: 'Facebook',
          subtitle: 'facebook.com/lexilens',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Opening Facebook...'),
                backgroundColor: Color(0xFFB789DA),
              ),
            );
          },
        ),
        _buildContactOption(
          icon: Icons.camera_alt,
          title: 'Instagram',
          subtitle: '@lexilens.app',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Opening Instagram...'),
                backgroundColor: Color(0xFFB789DA),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildContactOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 4,
        ),
        leading: Container(
          width: 45,
          height: 45,
          decoration: const BoxDecoration(
            color: Color(0xFFB789DA),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 22,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFFB789DA),
            fontFamily: 'OpenDyslexic',
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
            fontFamily: 'OpenDyslexic',
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: Color(0xFFB789DA),
          size: 16,
        ),
        onTap: onTap,
      ),
    );
  }
}

class FAQItem {
  final String question;
  final String answer;

  FAQItem({
    required this.question,
    required this.answer,
  });
}