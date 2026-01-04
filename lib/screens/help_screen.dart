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

  final List<FAQItem> _faqItems = [
    FAQItem(
      question: 'Lorem Ipsum Dolor Sit Amet?',
      answer:
          'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco.',
    ),
    FAQItem(
      question: 'Lorem Ipsum Dolor Sit Amet?',
      answer:
          'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
    ),
    FAQItem(
      question: 'Lorem Ipsum Dolor Sit Amet?',
      answer: 'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    ),
    FAQItem(
      question: 'Lorem Ipsum Dolor Sit Amet?',
      answer:
          'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam.',
    ),
    FAQItem(
      question: 'Lorem Ipsum Dolor Sit Amet?',
      answer:
          'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt.',
    ),
    FAQItem(
      question: 'Lorem Ipsum Dolor Sit Amet?',
      answer:
          'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
                              ? Colors.white
                              : Colors.transparent,
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
                                  ? const Color(0xFFB789DA)
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
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Category Pills
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
        const SizedBox(height: 20),
        // FAQ Items
        ..._faqItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return _buildFAQItem(item, index);
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
                        color:
                            isExpanded ? Colors.white : const Color(0xFFB789DA),
                        fontFamily: 'OpenDyslexic',
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: isExpanded ? Colors.white : const Color(0xFFB789DA),
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
                  height: 1.5,
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
        _buildContactOption(
          icon: Icons.headset_mic,
          title: 'Customer Service',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Opening Customer Service...'),
                backgroundColor: Color(0xFFB789DA),
              ),
            );
          },
        ),
        _buildContactOption(
          icon: Icons.language,
          title: 'Website',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Opening Website...'),
                backgroundColor: Color(0xFFB789DA),
              ),
            );
          },
        ),
        _buildContactOption(
          icon: Icons.message,
          title: 'Whatsapp',
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
          decoration: BoxDecoration(
            color: const Color(0xFFB789DA),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFFB789DA),
            fontFamily: 'OpenDyslexic',
          ),
        ),
        trailing: const Icon(
          Icons.keyboard_arrow_down,
          color: Color(0xFFB789DA),
          size: 24,
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
