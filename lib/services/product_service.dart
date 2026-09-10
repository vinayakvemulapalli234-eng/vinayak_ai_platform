import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ProductService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploads the product image and saves the full product listing to Firestore.
  /// Returns the new product's document ID.
  static Future<String> saveProduct({
    required Uint8List imageBytes,
    required String title,
    required String description,
    required String materials,
    required String category,
    required List<String> tags,
    required String price,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('You must be logged in to save a product.');
    }

    // 1. Upload image to Firebase Storage.
    final fileName = 'products/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.png';
    final ref = _storage.ref().child(fileName);
    await ref.putData(imageBytes);
    final imageUrl = await ref.getDownloadURL();

    // 2. Save the product document to Firestore.
    final docRef = await _firestore.collection('products').add({
      'artisanId': user.uid,
      'title': title,
      'description': description,
      'materials': materials,
      'category': category,
      'tags': tags,
      'price': price,
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  /// Fetches all products listed by the current artisan.
  static Future<List<Map<String, dynamic>>> getMyProducts() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final snapshot = await _firestore
        .collection('products')
        .where('artisanId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }
}