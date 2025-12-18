import 'package:flutter/material.dart';

class DrippingContainer extends StatelessWidget {
  final Color color;
  final Color accent;
  final Color shadowColor;
  final Widget? child;
  final double height;
  final double width;

  const DrippingContainer({
    super.key,
    required this.color,
    required this.accent,
    required this.shadowColor,
    this.child,
    this.height = 220,
    this.width = 200,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DrippingSquarePainter(
        color: color,
        accent: accent,
        shadowColor: shadowColor,
      ),
      child: SizedBox(
        width: width,
        height: height,
        child: child == null
            ? null
            : Padding(padding: const EdgeInsets.all(16.0), child: child),
      ),
    );
  }
}

class _DrippingSquarePainter extends CustomPainter {
  final Color color;
  final Color accent;
  final Color shadowColor;

  _DrippingSquarePainter({
    required this.color,
    required this.accent,
    required this.shadowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double bodyHeight = size.height * 0.60;
    final double dripHeight = size.height * 0.40; // longer drips
    final double radius = 20.0;

    final Paint paint = Paint()
      ..shader = LinearGradient(
        colors: [color, color.withOpacity(0.9)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final Path path = Path();

    // Top rounded rectangle
    path.moveTo(radius, 0);
    path.arcToPoint(
      Offset(0, radius),
      radius: Radius.circular(radius),
      clockwise: false,
    );
    path.lineTo(0, bodyHeight);

    // === Drips === (slimmer + longer)
    path.quadraticBezierTo(
      size.width * 0.05,
      bodyHeight + dripHeight * 0.9,
      size.width * 0.10,
      bodyHeight,
    );
    path.quadraticBezierTo(
      size.width * 0.20,
      bodyHeight + dripHeight * 1.2,
      size.width * 0.24,
      bodyHeight,
    );
    path.quadraticBezierTo(
      size.width * 0.33,
      bodyHeight + dripHeight * 0.8,
      size.width * 0.38,
      bodyHeight,
    );
    path.quadraticBezierTo(
      size.width * 0.45,
      bodyHeight + dripHeight * 1.4,
      size.width * 0.50,
      bodyHeight,
    );
    path.quadraticBezierTo(
      size.width * 0.60,
      bodyHeight + dripHeight * 0.9,
      size.width * 0.66,
      bodyHeight,
    );
    path.quadraticBezierTo(
      size.width * 0.73,
      bodyHeight + dripHeight * 1.3,
      size.width * 0.78,
      bodyHeight,
    );
    path.quadraticBezierTo(
      size.width * 0.87,
      bodyHeight + dripHeight * 1.0,
      size.width,
      bodyHeight,
    );

    // Right side & top
    path.lineTo(size.width, radius);
    path.arcToPoint(
      Offset(size.width - radius, 0),
      radius: Radius.circular(radius),
      clockwise: false,
    );
    path.close();

    // Shadow & fill
    canvas.drawShadow(path, shadowColor, 6, true);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
