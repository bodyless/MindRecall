import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// 「回念笔记」应用图标：浅蓝底 + 白纸 + 深蓝装订线/回念弧。
abstract final class AppIconPainter {
  /// 背景：浅蓝。
  static const lightBlue = Color(0xFF7EB6D9);

  /// 点缀：深蓝。
  static const deepBlue = Color(0xFF1E3A5F);

  /// 纸张：白。
  static const paperWhite = Color(0xFFFFFFFF);

  /// 正文横线（浅灰蓝，不抢主色）。
  static const lineBlue = Color(0xFFC5D9EC);

  static void paint(
    Canvas canvas,
    Size size, {
    bool withBackground = true,
  }) {
    final s = size.shortestSide;
    final rect = Offset.zero & Size(s, s);

    if (withBackground) {
      final bgRRect = RRect.fromRectAndRadius(
        rect,
        Radius.circular(s * 0.22),
      );
      canvas.drawRRect(bgRRect, Paint()..color = lightBlue);
    }

    final cardRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.16, s * 0.14, s * 0.68, s * 0.72),
      Radius.circular(s * 0.06),
    );
    canvas.drawRRect(cardRect, Paint()..color = paperWhite);

    final bindX = s * 0.3;
    canvas.drawLine(
      Offset(bindX, s * 0.22),
      Offset(bindX, s * 0.78),
      Paint()
        ..color = deepBlue
        ..strokeWidth = s * 0.016
        ..strokeCap = StrokeCap.round,
    );

    final linePaint = Paint()
      ..color = lineBlue
      ..strokeWidth = s * 0.014
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 2; i++) {
      final y = s * (0.38 + i * 0.12);
      canvas.drawLine(
        Offset(s * 0.38, y),
        Offset(s * 0.72, y),
        linePaint,
      );
    }

    final arcCenter = Offset(s * 0.7, s * 0.7);
    final arcRadius = s * 0.13;
    final stroke = s * 0.032;
    final arcPaint = Paint()
      ..color = deepBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    const start = -math.pi * 0.2;
    const sweep = math.pi * 1.3;
    canvas.drawArc(
      Rect.fromCircle(center: arcCenter, radius: arcRadius),
      start,
      sweep,
      false,
      arcPaint,
    );

    final tipAngle = start + sweep;
    final tip = Offset(
      arcCenter.dx + arcRadius * math.cos(tipAngle),
      arcCenter.dy + arcRadius * math.sin(tipAngle),
    );
    final tangent = tipAngle + math.pi / 2;
    final arrowLen = s * 0.042;
    final arrowPath = Path()
      ..moveTo(
        tip.dx + arrowLen * math.cos(tangent + 0.9),
        tip.dy + arrowLen * math.sin(tangent + 0.9),
      )
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(
        tip.dx + arrowLen * math.cos(tangent - 0.9),
        tip.dy + arrowLen * math.sin(tangent - 0.9),
      );
    canvas.drawPath(
      arrowPath,
      Paint()
        ..color = deepBlue
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.drawCircle(
      arcCenter,
      s * 0.018,
      Paint()..color = paperWhite,
    );
  }

  static Future<ui.Image> renderImage({
    int pixelSize = 1024,
    bool withBackground = true,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    paint(
      canvas,
      Size.square(pixelSize.toDouble()),
      withBackground: withBackground,
    );
    final picture = recorder.endRecording();
    return picture.toImage(pixelSize, pixelSize);
  }

  static Future<List<int>> renderPngBytes({
    int pixelSize = 1024,
    bool withBackground = true,
  }) async {
    final image = await renderImage(
      pixelSize: pixelSize,
      withBackground: withBackground,
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Failed to encode app icon PNG');
    }
    return byteData.buffer.asUint8List();
  }
}

/// 预览用 Widget。
class AppIconPreview extends StatelessWidget {
  const AppIconPreview({super.key, this.size = 192});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: const _AppIconPreviewPainter(),
    );
  }
}

class _AppIconPreviewPainter extends CustomPainter {
  const _AppIconPreviewPainter();

  @override
  void paint(Canvas canvas, Size size) {
    AppIconPainter.paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
