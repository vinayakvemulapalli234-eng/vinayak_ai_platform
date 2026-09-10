import '../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isLoginMode = true;
  String phone = '';
  String pin = '';
  String confirmPin = '';
  bool _isSubmitting = false;

  bool _enteringConfirm = false;

  final TextEditingController _phoneController = TextEditingController();

  void _onKeyTap(String digit) {
    setState(() {
      if (isLoginMode) {
        if (pin.length < 4) pin += digit;
      } else {
        if (!_enteringConfirm) {
          if (pin.length < 4) pin += digit;
          if (pin.length == 4) _enteringConfirm = true;
        } else {
          if (confirmPin.length < 4) confirmPin += digit;
        }
      }
    });
  }

  void _onDelete() {
    setState(() {
      if (isLoginMode) {
        if (pin.isNotEmpty) pin = pin.substring(0, pin.length - 1);
      } else {
        if (_enteringConfirm && confirmPin.isNotEmpty) {
          confirmPin = confirmPin.substring(0, confirmPin.length - 1);
        } else if (_enteringConfirm && confirmPin.isEmpty) {
          _enteringConfirm = false;
        } else if (pin.isNotEmpty) {
          pin = pin.substring(0, pin.length - 1);
        }
      }
    });
  }

  void _onClear() {
    setState(() {
      pin = '';
      confirmPin = '';
      _enteringConfirm = false;
    });
  }

  void _switchMode(bool loginMode) {
    setState(() {
      isLoginMode = loginMode;
      pin = '';
      confirmPin = '';
      _enteringConfirm = false;
    });
  }

  Widget _buildPinRow(String value, {bool active = true}) {
    return Row(
      children: List.generate(4, (i) {
        final filled = i < value.length;
        return Container(
          width: 44,
          height: 44,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: filled
                ? const Color(0xFF1E7A4C)
                : (active ? Colors.grey.shade200 : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(10),
            border: active ? Border.all(color: const Color(0xFF1E7A4C), width: 1.2) : null,
          ),
          alignment: Alignment.center,
          child: filled
              ? Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                )
              : null,
        );
      }),
    );
  }

  Widget _buildKey(String label, {VoidCallback? onTap}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }

  String _friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This phone number is already registered. Try logging in.';
      case 'user-not-found':
      case 'invalid-credential':
      case 'wrong-password':
        return 'Phone number or PIN is incorrect.';
      case 'weak-password':
        return 'PIN is too weak.';
      default:
        return 'Error: ${e.code} — ${e.message}';    }
  }

  Future<void> _handleSubmit() async {
    if (phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid 10-digit phone number')),
      );
      return;
    }

    if (isLoginMode) {
      if (pin.length < 4) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter your 4-digit PIN')),
        );
        return;
      }
      setState(() => _isSubmitting = true);
      try {
        await AuthService.login(phone, pin);
        if (mounted) context.go('/language');
      } on FirebaseAuthException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_friendlyError(e))),
          );
        }
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    } else {
      if (pin.length < 4 || confirmPin.length < 4) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter and confirm your 4-digit PIN')),
        );
        return;
      }
      if (pin != confirmPin) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PINs do not match')),
        );
        setState(() {
          confirmPin = '';
          _enteringConfirm = true;
        });
        return;
      }
      setState(() => _isSubmitting = true);
      try {
        await AuthService.register(phone, pin);
        if (mounted) context.go('/language');
      } on FirebaseAuthException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_friendlyError(e))),
          );
        }
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.pop(),
                ),
                const SizedBox(height: 8),
                Text(
                  isLoginMode ? 'Welcome Back' : 'Create Account',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  isLoginMode
                      ? 'Enter your registered phone & 4-digit PIN'
                      : 'Set up your phone number & 4-digit PIN',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _switchMode(true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isLoginMode ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: isLoginMode
                                  ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4)]
                                  : [],
                            ),
                            alignment: Alignment.center,
                            child: Text('Login',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: isLoginMode ? Colors.black : Colors.grey)),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _switchMode(false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: !isLoginMode ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: !isLoginMode
                                  ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4)]
                                  : [],
                            ),
                            alignment: Alignment.center,
                            child: Text('Register',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: !isLoginMode ? Colors.black : Colors.grey)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Mobile Number', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  onChanged: (val) => setState(() => phone = val),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.phone_outlined),
                    hintText: '9876543210',
                    counterText: '',
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (isLoginMode) ...[
                  const Text('4-Digit PIN', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  _buildPinRow(pin),
                ],
                if (!isLoginMode) ...[
                  GestureDetector(
                    onTap: () => setState(() => _enteringConfirm = false),
                    child: Text('Set 4-Digit PIN',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: !_enteringConfirm ? const Color(0xFF1E7A4C) : Colors.black)),
                  ),
                  const SizedBox(height: 12),
                  _buildPinRow(pin, active: !_enteringConfirm),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () {
                      if (pin.length == 4) setState(() => _enteringConfirm = true);
                    },
                    child: Text('Confirm PIN',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _enteringConfirm ? const Color(0xFF1E7A4C) : Colors.black)),
                  ),
                  const SizedBox(height: 12),
                  _buildPinRow(confirmPin, active: _enteringConfirm),
                ],
                const SizedBox(height: 20),
                Row(children: [
                  _buildKey('1', onTap: () => _onKeyTap('1')),
                  _buildKey('2', onTap: () => _onKeyTap('2')),
                  _buildKey('3', onTap: () => _onKeyTap('3')),
                ]),
                Row(children: [
                  _buildKey('4', onTap: () => _onKeyTap('4')),
                  _buildKey('5', onTap: () => _onKeyTap('5')),
                  _buildKey('6', onTap: () => _onKeyTap('6')),
                ]),
                Row(children: [
                  _buildKey('7', onTap: () => _onKeyTap('7')),
                  _buildKey('8', onTap: () => _onKeyTap('8')),
                  _buildKey('9', onTap: () => _onKeyTap('9')),
                ]),
                Row(children: [
                  _buildKey('Delete', onTap: _onDelete),
                  _buildKey('0', onTap: () => _onKeyTap('0')),
                  _buildKey('Clear', onTap: _onClear),
                ]),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E7A4C),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _isSubmitting ? null : _handleSubmit,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(
                            isLoginMode ? 'Login →' : 'Register →',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}