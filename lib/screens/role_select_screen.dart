import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_service.dart';

class RoleSelectScreen extends StatefulWidget {
  const RoleSelectScreen({super.key});

  @override
  State<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends State<RoleSelectScreen> {
  bool _isSaving = false;

  Future<void> _selectRole(String role) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      await AuthService.saveRole(role);
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save role: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Who are you?')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _isSaving
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E7A4C)))
            : Column(
                children: [
                  const Text('Tap on your role / अपनी भूमिका चुनें', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 20),
                  _RoleCard(
                    icon: Icons.person,
                    title: 'Artisan',
                    subtitle: 'I make handicrafts',
                    color: const Color(0xFFE8F5E9),
                    onTap: () => _selectRole('artisan'),
                  ),
                  const SizedBox(height: 16),
                  _RoleCard(
                    icon: Icons.shopping_bag,
                    title: 'Customer',
                    subtitle: 'I want to buy',
                    color: const Color(0xFFE3F2FD),
                    onTap: () => _selectRole('buyer'),
                  ),
                ],
              ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            CircleAvatar(radius: 28, backgroundColor: Colors.white, child: Icon(icon, size: 28)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(subtitle, style: TextStyle(color: Colors.grey.shade700)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}