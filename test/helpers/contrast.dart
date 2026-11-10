import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Relación de contraste WCAG entre dos colores opacos (1 a 21).
double contrastRatio(Color a, Color b) {
  double luminance(Color c) {
    double channel(double v) =>
        v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
  }

  final la = luminance(a);
  final lb = luminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

/// Mezcla [fg] (con su transparencia) sobre [bg].
Color blendOver(Color fg, Color bg) => Color.alphaBlend(fg, bg);

class LowContrastText {
  final String text;
  final Color foreground;
  final Color background;
  final double ratio;

  const LowContrastText(this.text, this.foreground, this.background, this.ratio);

  @override
  String toString() =>
      '"$text" ${_hex(foreground)} sobre ${_hex(background)} '
      '(${ratio.toStringAsFixed(2)}:1)';

  static String _hex(Color c) =>
      '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
}

/// Busca los `Text` visibles cuyo color casi no se distingue de su fondo.
///
/// El fondo es el del ancestro con color sólido más cercano (Container,
/// DecoratedBox, Material, Card, Scaffold…). Si el primer ancestro con fondo
/// es un degradado, el texto se omite (no hay un color único que comparar).
List<LowContrastText> lowContrastTexts(
  WidgetTester tester, {
  double minRatio = 3.0,
}) {
  final problems = <LowContrastText>[];

  for (final element in find.byType(Text).evaluate()) {
    final widget = element.widget as Text;
    final label = widget.data ?? widget.textSpan?.toPlainText() ?? '';
    if (label.trim().isEmpty) continue;

    final style = DefaultTextStyle.of(element).style.merge(widget.style);
    final color = style.color;
    if (color == null || color.a == 0) continue;

    Color? background;
    var unknown = false;
    element.visitAncestorElements((ancestor) {
      final w = ancestor.widget;
      Color? found;
      if (w is Container) {
        final d = w.decoration;
        if (d is BoxDecoration) {
          if (d.gradient != null) {
            unknown = true;
            return false;
          }
          found = d.color;
        }
        found ??= w.color;
      } else if (w is DecoratedBox) {
        final d = w.decoration;
        if (d is BoxDecoration) {
          if (d.gradient != null) {
            unknown = true;
            return false;
          }
          found = d.color;
        }
      } else if (w is ColoredBox) {
        found = w.color;
      } else if (w is Material && w.color != null) {
        found = w.color;
      } else if (w is Card) {
        found = w.color ?? Theme.of(ancestor).cardTheme.color;
      } else if (w is Scaffold) {
        found = w.backgroundColor ?? Theme.of(ancestor).scaffoldBackgroundColor;
      }
      if (found != null && found.a > 0.5) {
        background = found;
        return false;
      }
      return true;
    });
    if (unknown) continue;

    final bg = background ?? Theme.of(element).scaffoldBackgroundColor;
    final fg = blendOver(color, bg);
    final ratio = contrastRatio(fg, bg);
    if (ratio < minRatio) {
      problems.add(LowContrastText(label, fg, bg, ratio));
    }
  }
  return problems;
}
