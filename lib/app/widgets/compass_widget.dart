import 'dart:math';
import 'package:flutter/material.dart';


class CompassWidget extends StatelessWidget {
  const CompassWidget({
    super.key,
    required this.currentAzimuth,
    required this.routerBearing,
    required this.signalColor,
    this.size = 88,
  });

  final double currentAzimuth, routerBearing;
  final Color  signalColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final arrowAngle = (routerBearing - currentAzimuth + 360) % 360;
    return SizedBox(width: size, height: size,
      child: Stack(alignment: Alignment.center, children: [
        // Rose rotates to stay world-locked
        Transform.rotate(
          angle: -currentAzimuth * pi / 180,
          child: CustomPaint(size: Size(size, size),
              painter: _CompassRosePainter(signalColor)),
        ),
        // Arrow always points toward router bearing
        Transform.rotate(
          angle: arrowAngle * pi / 180,
          child: CustomPaint(size: Size(size * 0.5, size * 0.5),
              painter: _ArrowPainter(signalColor)),
        ),
        // Centre dot
        Container(width: 7, height: 7,
          decoration: BoxDecoration(color: signalColor, shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: signalColor.withOpacity(0.8), blurRadius: 5)])),
      ]),
    );
  }
}

class _CompassRosePainter extends CustomPainter {
  const _CompassRosePainter(this.c);
  final Color c;

  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2, cy = s.height / 2, r = s.shortestSide / 2;
    canvas.drawCircle(Offset(cx, cy), r,
        Paint()..color = c.withOpacity(0.12)
               ..style = PaintingStyle.stroke..strokeWidth = 1.2);
    const labels = ['N', 'E', 'S', 'W'];
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < 16; i++) {
      final a    = i * pi / 8;
      final isC  = i % 4 == 0;
      final tR   = isC ? r * 0.80 : r * 0.88;
      final col  = isC ? (i == 0 ? Colors.redAccent : c.withOpacity(0.7))
                       : c.withOpacity(0.25);
      canvas.drawLine(
        Offset(cx + r * 0.94 * cos(a - pi/2), cy + r * 0.94 * sin(a - pi/2)),
        Offset(cx + tR       * cos(a - pi/2), cy + tR       * sin(a - pi/2)),
        Paint()..color = col..strokeWidth = isC ? 1.8 : 0.8,
      );
      if (isC) {
        tp.text = TextSpan(text: labels[i ~/ 4], style: TextStyle(
          color: col, fontSize: s.shortestSide * 0.10,
          fontWeight: FontWeight.bold, fontFamily: 'monospace',
        ));
        tp.layout();
        tp.paint(canvas, Offset(
          cx + r * 0.60 * cos(a - pi/2) - tp.width  / 2,
          cy + r * 0.60 * sin(a - pi/2) - tp.height / 2,
        ));
      }
    }
  }

  @override bool shouldRepaint(_CompassRosePainter o) => o.c != c;
}

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter(this.c);
  final Color c;

  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2, cy = s.height / 2, h = s.height / 2;
    final path = Path()
      ..moveTo(cx, cy - h)
      ..lineTo(cx + s.width * 0.18, cy + h * 0.5)
      ..lineTo(cx, cy + h * 0.10)
      ..lineTo(cx - s.width * 0.18, cy + h * 0.5)
      ..close();
    canvas.drawPath(path, Paint()
      ..color = c.withOpacity(0.85)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawPath(path, Paint()..color = c);
  }

  @override bool shouldRepaint(_ArrowPainter o) => o.c != c;
}