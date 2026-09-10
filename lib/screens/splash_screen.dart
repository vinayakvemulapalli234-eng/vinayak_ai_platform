import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final user = AuthService.currentUser;

    if (user == null) {
      // Not logged in — show the normal splash screen with "Get Started".
      setState(() => _checking = false);
      return;
    }

    // Logged in — check how far they got in setup, and route accordingly.
    final profile = await AuthService.getUserProfile();

    if (!mounted) return;

    if (profile == null) {
      setState(() => _checking = false);
      return;
    }

    final role = profile['role'];
    final language = profile['language'];

    if (role != null) {
      context.go('/home');
    } else if (language != null) {
      context.go('/role');
    } else {
      context.go('/language');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: Color(0xFFFBF6EE),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF1E7A4C)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFBF6EE),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/logo.png',
                width: 180,
              ),
              const SizedBox(height: 16),
              const Text(
                'Our Heritage. Our Hands.\nA Brighter Tomorrow',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.brown),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E7A4C),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => context.go('/login'),
                  child: const Text('Get Started', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}