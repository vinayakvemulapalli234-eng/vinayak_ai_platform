import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'backdrop_picker.dart';

class ProductComposite extends StatelessWidget {
  final Uint8List cutoutPngBytes; // transparent PNG from remove.bg
  final BackdropStyle backdropStyle;

  const ProductComposite({
    super.key,
    required this.cutoutPngBytes,
    required this.backdropStyle,
  });

  @override
  Widget build(BuildContext context) {
    final opt = backdropOptions.firstWhere((o) => o.style == backdropStyle);

    return Container(
      height: 280,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: opt.colors,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Soft shadow ellipse under the product
          Positioned(
            bottom: 30,
            child: Container(
              width: 160,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.18),
                borderRadius: BorderRadius.circular(100),
              ),
              // Simple blur-look via a shadow-only box; for a true blur wrap in ImageFiltered
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Image.memory(cutoutPngBytes, fit: BoxFit.contain),
          ),
        ],
      ),
    );
  }
}