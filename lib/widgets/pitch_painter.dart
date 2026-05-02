import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../providers/live_match_provider.dart';

class PitchPainter extends CustomPainter {
  final PossessionSide possessionSide;
  final double possessionPulse;
  final double passProgress;
  final List<PitchPlayerMarker> homeMarkers;
  final List<PitchPlayerMarker> awayMarkers;
  final PitchPassLine? activePass;
  final LiveMatchEvent? highlightEvent;

  const PitchPainter({
    required this.possessionSide,
    required this.possessionPulse,
    required this.passProgress,
    required this.homeMarkers,
    required this.awayMarkers,
    required this.activePass,
    required this.highlightEvent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawPitch(canvas, size);
    _drawPossessionArrow(canvas, size);
    _drawPlayers(canvas, size);
    _drawPassLine(canvas, size);
    _drawHighlight(canvas, size);
  }

  void _drawPitch(Canvas canvas, Size size) {
    final pitchRect = Offset.zero & size;
    final grassPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1F7A31), Color(0xFF0D5F20)],
      ).createShader(pitchRect);

    canvas.drawRRect(
      RRect.fromRectAndRadius(pitchRect, const Radius.circular(18)),
      grassPaint,
    );

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.88)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.4, size.shortestSide * 0.005);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        pitchRect.deflate(size.shortestSide * 0.015),
        const Radius.circular(12),
      ),
      linePaint,
    );

    final midX = size.width / 2;
    final midY = size.height / 2;
    canvas.drawLine(Offset(midX, 0), Offset(midX, size.height), linePaint);
    canvas.drawCircle(Offset(midX, midY), size.shortestSide * 0.10, linePaint);
    canvas.drawCircle(Offset(midX, midY), 2.2, Paint()..color = Colors.white);

    _drawPenaltyBox(canvas, size, left: true, paint: linePaint);
    _drawPenaltyBox(canvas, size, left: false, paint: linePaint);
  }

  void _drawPenaltyBox(Canvas canvas, Size size,
      {required bool left, required Paint paint}) {
    final double boxWidth = size.width * 0.12;
    final double boxHeight = size.height * 0.56;
    final double boxTop = (size.height - boxHeight) / 2;
    final double boxLeft = left ? 0.0 : size.width - boxWidth;

    canvas.drawRect(Rect.fromLTWH(boxLeft, boxTop, boxWidth, boxHeight), paint);

    final double sixHeight = size.height * 0.40;
    final double sixWidth = size.width * 0.05;
    final double sixLeft = left ? 0.0 : size.width - sixWidth;
    final double sixTop = (size.height - sixHeight) / 2;
    canvas.drawRect(Rect.fromLTWH(sixLeft, sixTop, sixWidth, sixHeight), paint);

    final double spot = left ? size.width * 0.09 : size.width * 0.91;
    canvas.drawCircle(Offset(spot, size.height / 2), 2.4, Paint()..color = Colors.white);
  }

  void _drawPossessionArrow(Canvas canvas, Size size) {
    final activeColor = possessionSide == PossessionSide.home
        ? const Color(0xFF60A5FA)
        : possessionSide == PossessionSide.away
            ? const Color(0xFFF97316)
            : Colors.white;

    final opacity = 0.12 + (possessionPulse * 0.16);
    final arrowWidth = size.width * 0.76;
    final arrowHeight = size.height * 0.14;
    final centerY = size.height * 0.22;
    final startX = size.width * 0.12;
    final endX = startX + arrowWidth;

    final path = Path();
    if (possessionSide == PossessionSide.away) {
      path.moveTo(endX, centerY);
      path.lineTo(startX + arrowHeight, centerY - arrowHeight / 2);
      path.lineTo(startX + arrowHeight, centerY - arrowHeight * 0.26);
      path.lineTo(startX, centerY - arrowHeight * 0.26);
      path.lineTo(startX, centerY + arrowHeight * 0.26);
      path.lineTo(startX + arrowHeight, centerY + arrowHeight * 0.26);
      path.lineTo(startX + arrowHeight, centerY + arrowHeight / 2);
      path.close();
    } else {
      path.moveTo(startX, centerY);
      path.lineTo(endX - arrowHeight, centerY - arrowHeight / 2);
      path.lineTo(endX - arrowHeight, centerY - arrowHeight * 0.26);
      path.lineTo(endX, centerY - arrowHeight * 0.26);
      path.lineTo(endX, centerY + arrowHeight * 0.26);
      path.lineTo(endX - arrowHeight, centerY + arrowHeight * 0.26);
      path.lineTo(endX - arrowHeight, centerY + arrowHeight / 2);
      path.close();
    }

    final arrowPaint = Paint()
      ..shader = LinearGradient(
        colors: [activeColor.withValues(alpha: opacity), Colors.white.withValues(alpha: opacity * 0.45)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, arrowPaint);
  }

  void _drawPlayers(Canvas canvas, Size size) {
    for (final marker in [...homeMarkers, ...awayMarkers]) {
      final center = Offset(marker.position.dx * size.width, marker.position.dy * size.height);
      final double circleRadius = math.max(11.0, size.shortestSide * 0.020);
      final fillPaint = Paint()..color = marker.color.withValues(alpha: 0.94);
      final outlinePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.88)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawCircle(center, circleRadius, fillPaint);
      canvas.drawCircle(center, circleRadius, outlinePaint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: marker.label,
          style: TextStyle(
            color: Colors.white,
              fontSize: circleRadius * 0.78,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();

      textPainter.paint(
        canvas,
        center - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }
  }

  void _drawPassLine(Canvas canvas, Size size) {
    final pass = activePass;
    if (pass == null) return;

    final from = Offset(pass.from.dx * size.width, pass.from.dy * size.height);
    final to = Offset(pass.to.dx * size.width, pass.to.dy * size.height);
    final control = Offset(
      (from.dx + to.dx) / 2,
      ((from.dy + to.dy) / 2) - (size.height * 0.12),
    );

    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(control.dx, control.dy, to.dx, to.dy);

    final linePaint = Paint()
      ..color = pass.color.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(3, size.shortestSide * 0.010)
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, linePaint);

    final metrics = path.computeMetrics().toList(growable: false);
    if (metrics.isEmpty) return;

    final metric = metrics.first;
    final tangent = metric.getTangentForOffset(metric.length * passProgress.clamp(0, 1));
    if (tangent == null) return;

    final ballPaint = Paint()..color = Colors.white;
    final glowPaint = Paint()..color = pass.color.withValues(alpha: 0.22);
    canvas.drawCircle(tangent.position, math.max(8, size.shortestSide * 0.014), glowPaint);
    canvas.drawCircle(tangent.position, math.max(4.5, size.shortestSide * 0.008), ballPaint);
  }

  void _drawHighlight(Canvas canvas, Size size) {
    final event = highlightEvent;
    if (event == null || !event.isGoal) return;

    final glowPaint = Paint()
      ..color = Colors.amber.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.34),
      size.shortestSide * 0.11,
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant PitchPainter oldDelegate) {
    return oldDelegate.possessionSide != possessionSide ||
        oldDelegate.possessionPulse != possessionPulse ||
        oldDelegate.passProgress != passProgress ||
        oldDelegate.activePass?.id != activePass?.id ||
        oldDelegate.highlightEvent?.id != highlightEvent?.id ||
        oldDelegate.homeMarkers != homeMarkers ||
        oldDelegate.awayMarkers != awayMarkers;
  }
}