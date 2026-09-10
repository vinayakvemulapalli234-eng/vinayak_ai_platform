import 'package:flutter/material.dart';

enum BackdropStyle { studioWhite, warmGradient, coolGradient, softGray }

class BackdropOption {
  final BackdropStyle style;
  final String label;
  final List<Color> colors;
  const BackdropOption(this.style, this.label, this.colors);
}

const backdropOptions = [
  BackdropOption(BackdropStyle.studioWhite, 'Studio White', [Color(0xFFFFFFFF), Color(0xFFF2F2F2)]),
  BackdropOption(BackdropStyle.warmGradient, 'Warm Wood', [Color(0xFFEFDCC5), Color(0xFFC9A578)]),
  BackdropOption(BackdropStyle.coolGradient, 'Soft Blue', [Color(0xFFE3EEF5), Color(0xFFB9D3E4)]),
  BackdropOption(BackdropStyle.softGray, 'Neutral Gray', [Color(0xFFEDEDED), Color(0xFFCFCFCF)]),
];

class BackdropPicker extends StatelessWidget {
  final BackdropStyle selected;
  final ValueChanged<BackdropStyle> onSelect;
  const BackdropPicker({super.key, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 70,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: backdropOptions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final opt = backdropOptions[i];
          final isSelected = opt.style == selected;
          return GestureDetector(
            onTap: () => onSelect(opt.style),
            child: Column(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: opt.colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? const Color(0xFF1E7A4C) : Colors.black12,
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(opt.label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
              ],
            ),
          );
        },
      ),
    );
  }
}