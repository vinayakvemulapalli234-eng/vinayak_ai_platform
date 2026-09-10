import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Converts a phone number into a fake email Firebase can use internally.
  static String _fakeEmail(String phone) => '$phone@kalaai.app';

  // Pads the 4-digit PIN so it meets Firebase's 6-character password minimum.
  static String _fakePassword(String pin) => '$pin-kala';

  /// Registers a new user with phone + PIN, and creates their Firestore profile.
  /// Throws FirebaseAuthException on failure.
  static Future<User?> register(String phone, String pin) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: _fakeEmail(phone),
      password: _fakePassword(pin),
    );

    final user = credential.user;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).set({
        'phone': phone,
        'role': null,
        'language': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    return user;
  }

  /// Logs in an existing user with phone + PIN. Throws FirebaseAuthException on failure.
  static Future<User?> login(String phone, String pin) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: _fakeEmail(phone),
      password: _fakePassword(pin),
    );
    return credential.user;
  }

  static Future<void> logout() async {
    await _auth.signOut();
  }

  static User? get currentUser => _auth.currentUser;

  /// Fetches the current user's Firestore profile document, or null if not logged in.
  static Future<Map<String, dynamic>?> getUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    return doc.data();
  }

  /// Saves the user's selected language code (e.g. 'hi', 'te', 'en') to Firestore.
  static Future<void> saveLanguage(String languageCode) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).update({
      'language': languageCode,
    });
  }

  /// Saves the user's selected role ('artisan' or 'buyer') to Firestore.
  static Future<void> saveRole(String role) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).update({
      'role': role,
    });
  }
}