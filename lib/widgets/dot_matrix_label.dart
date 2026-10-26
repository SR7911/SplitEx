import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:split_ex/widgets/dot_matrix_glyphs.dart';

class DotMatrixLabel extends StatelessWidget {
  final Color color;
  final String text;
  final double fontSize;
  const DotMatrixLabel({super.key, required this.color, this.text = 'My Expenses', this.fontSize = 14});
  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.textScalerOf(context).scale(fontSize);
    final width = (text.length * 6 - 1).clamp(1, 10000) * height / 7;
    return Semantics(label: text, child: SizedBox(height: height, width: width,
      child: CustomPaint(painter: _Letters(text, color))));
  }
}
class _Letters extends CustomPainter {
  final String text;
  final Color color;
  _Letters(this.text, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    if (text.isEmpty) return;
    final step = math.min(size.width / (text.length * 6 - 1), size.height / 7);
    final paint = Paint()..color = color;
    final chars = text.toUpperCase();
    for (var i = 0; i < chars.length; i++) {
      final glyph = dotMatrixGlyphs[chars[i]] ?? dotMatrixGlyphs['?']!;
      for (var row = 0; row < 7; row++) {
        for (var col = 0; col < 5; col++) {
          if (glyph[row * 5 + col] == '1') {
            canvas.drawCircle(Offset((i * 6 + col + .5) * step, (row + .5) * step), step * .45, paint);
          }
        }
      }
    }
  }
  @override
  bool shouldRepaint(_Letters oldDelegate) => oldDelegate.color != color || oldDelegate.text != text;
}
class DotMatrixProgress extends StatelessWidget {
  final bool circular;
  final double value;
  final Color color, trackColor;
  const DotMatrixProgress({super.key, required this.value, required this.color, required this.trackColor, this.circular = false});
  @override
  Widget build(BuildContext context) => Semantics(label: 'Spending progress', value: '${(value.clamp(0, 1) * 100).round()}%',
    child: SizedBox(height: circular ? 80 : 7, width: circular ? 80 : double.infinity, child: CustomPaint(painter: _Progress(value, color, trackColor, circular))));
}
class _Progress extends CustomPainter {
  final double value;
  final Color color, trackColor;
  final bool circular;
  _Progress(this.value, this.color, this.trackColor, this.circular);
  @override
  void paint(Canvas canvas, Size size) {
    if (circular) {
      final paint = Paint();
      for (var ring = 0; ring < 3; ring++) {
        final radius = math.min(size.width, size.height) * .43 - ring * 4;
        for (var dot = 0; dot < 48; dot++) {
          final angle = dot * math.pi * 2 / 48 - math.pi / 2;
          paint.color = (dot + .5) / 48 <= value.clamp(0, 1) ? color : trackColor;
          canvas.drawCircle(Offset(size.width / 2 + math.cos(angle) * radius, size.height / 2 + math.sin(angle) * radius), 1.2, paint);
        }
      }
      return;
    }
    final columns = (size.width / 4).floor().clamp(1, 1000);
    final step = size.width / columns;
    final paint = Paint();
    for (var col = 0; col < columns; col++) {
      paint.color = (col + .5) / columns <= value.clamp(0, 1) ? color : trackColor;
      for (var row = 0; row < 2; row++) {
        canvas.drawCircle(Offset((col + .5) * step, size.height * (row + 1) / 3), math.min(step * .29, size.height / 6), paint);
      }
    }
  }
  @override
  bool shouldRepaint(_Progress oldDelegate) => oldDelegate.value != value || oldDelegate.color != color || oldDelegate.trackColor != trackColor || oldDelegate.circular != circular;
}
