import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_service.dart';

class LanguageSelectScreen extends StatefulWidget {
  const LanguageSelectScreen({super.key});

  @override
  State<LanguageSelectScreen> createState() => _LanguageSelectScreenState();
}

class _LanguageSelectScreenState extends State<LanguageSelectScreen> {
  bool _isSaving = false;

  Future<void> _selectLanguage(String code) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      await AuthService.saveLanguage(code);
      if (mounted) context.go('/role');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save language: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final languages = [
      {'label': 'हिंदी', 'sub': 'Hindi', 'code': 'hi'},
      {'label': 'తెలుగు', 'sub': 'Telugu', 'code': 'te'},
      {'label': 'தமிழ்', 'sub': 'Tamil', 'code': 'ta'},
      {'label': 'ಕನ್ನಡ', 'sub': 'Kannada', 'code': 'kn'},
      {'label': 'മലയാളം', 'sub': 'Malayalam', 'code': 'ml'},
      {'label': 'বাংলা', 'sub': 'Bengali', 'code': 'bn'},
      {'label': 'ગુજરાતી', 'sub': 'Gujarati', 'code': 'gu'},
      {'label': 'A', 'sub': 'English', 'code': 'en'},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFFBF6EE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFBF6EE),
        elevation: 0,
        leading: const BackButton(color: Colors.black87),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose Your Language',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Select your language / अपनी भाषा चुनें',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _isSaving
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF1E7A4C)),
                    )
                  : GridView.builder(
                      itemCount: languages.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 2.4,
                      ),
                      itemBuilder: (context, index) {
                        final lang = languages[index];
                        return InkWell(
                          onTap: () => _selectLanguage(lang['code']!),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.black12),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(lang['label']!,
                                    style: const TextStyle(
                                        fontSize: 20, fontWeight: FontWeight.bold)),
                                Text(lang['sub']!,
                                    style: const TextStyle(color: Colors.black54)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.volume_up_outlined, color: Colors.black54),
              label: const Text('Listen to all languages',
                  style: TextStyle(color: Colors.black54)),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}