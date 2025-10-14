import 'package:flutter/material.dart';
import 'dart:math';

// -------------------------------------------------------------------
// --- Brand Colors (Aapki file se liya gaya) ---
// -------------------------------------------------------------------
const Color kPrimaryColor = Color(0xFF75E5E2); // Light Cyan
const Color kSecondaryColor = Color(0xFF41938F); // Teal Green
const Color kTertiaryColor = Color(0xFF0D1D20); // Very Dark Teal
const Color kInputBgColor = Color(0xFF282828); // Dark Grey/Black

// -------------------------------------------------------------------
// --- 1. Overlay Management Functions (No Change) ---
// -------------------------------------------------------------------

OverlayEntry? _loaderOverlay;

void showLoader(BuildContext context) {
  if (_loaderOverlay == null) {
    _loaderOverlay = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Container(
            color: kTertiaryColor.withOpacity(0.9), // Slightly more opaque
          ),
          const CustomLoader(),
        ],
      ),
    );
    Overlay.of(context).insert(_loaderOverlay!);
  }
}

void hideLoader() {
  _loaderOverlay?.remove();
  _loaderOverlay = null;
}

// -------------------------------------------------------------------
// --- 2. Devaj Tec Themed Custom Loader Widget (Devaj Nexus) ---
// -------------------------------------------------------------------

class CustomLoader extends StatefulWidget {
  final double size;
  final Duration duration;

  const CustomLoader({
    super.key,
    this.size = 100.0, // Thoda bada size for more detail
    this.duration = const Duration(seconds: 3), // Thodi lambi duration for smoother animation
  });

  @override
  _CustomLoaderState createState() => _CustomLoaderState();
}

class _CustomLoaderState extends State<CustomLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _outerRotationAnimation;
  late Animation<double> _innerGridAnimation; // For inner grid/hexagons
  late Animation<double> _monogramPulseAnimation; // For DVT text

  // Custom Color Cycle using your theme colors
  final List<Color> themeColorCycle = [
    kPrimaryColor, // Light Cyan
    kSecondaryColor, // Teal Green
    kPrimaryColor.withOpacity(0.7), // Lighter shade
    kSecondaryColor.withOpacity(0.7), // Medium shade
  ];

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(); // Keep repeating

    // Outer Ring Rotation: Continuous linear rotation
    _outerRotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );

    // Inner Grid/Hexagon Animation: Expands and contracts (like a breathing effect)
    _innerGridAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 0.5), // Expand
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 0.5), // Contract
    ]).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Monogram Pulse: Subtle scale up/down, slightly out of sync with ring
    _monogramPulseAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.1), weight: 0.5),
      TweenSequenceItem(tween: Tween<double>(begin: 1.1, end: 1.0), weight: 0.5),
    ]).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.2, 0.8, curve: Curves.easeInOut)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Helper function to calculate the dynamic color based on controller value
  Color _calculateDynamicColor(double value) {
    int currentIndex = (value * themeColorCycle.length).floor() % themeColorCycle.length;
    int nextIndex = (currentIndex + 1) % themeColorCycle.length;
    double t = (value * themeColorCycle.length) - currentIndex;
    return Color.lerp(themeColorCycle[currentIndex], themeColorCycle[nextIndex], t)!;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final containerSize = widget.size * 1.5;
          final dynamicRingColor = _calculateDynamicColor(_controller.value);

          return SizedBox(
            width: containerSize,
            height: containerSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 1. Outer Orbiting Ring (Dynamic Color)
                RotationTransition(
                  turns: _outerRotationAnimation,
                  child: CustomPaint(
                    size: Size(containerSize, containerSize),
                    painter: RingPainter(
                      color: dynamicRingColor,
                      sweepAngle: 90 + (180 * _controller.value), // More dynamic sweep
                      trackColor: kInputBgColor.withOpacity(0.7),
                      strokeWidth: 6.0,
                    ),
                  ),
                ),

                // 2. Inner Expanding Grid/Hexagons (New, Techy Effect)
                FadeTransition(
                  opacity: _innerGridAnimation, // Fade in/out with expand/contract
                  child: Transform.scale(
                    scale: 0.5 + (_innerGridAnimation.value * 0.5), // Scale from 0.5 to 1.0
                    child: CustomPaint(
                      size: Size(widget.size * 0.8, widget.size * 0.8), // Slightly smaller than container
                      painter: HexagonGridPainter(
                        baseColor: kSecondaryColor, // Teal Green for inner elements
                        animationValue: _innerGridAnimation.value,
                        gridDensity: 3, // Number of hexagons in a row/column
                      ),
                    ),
                  ),
                ),

                // 3. Devaj Monogram Core with Refined Pulse
                ScaleTransition(
                  scale: _monogramPulseAnimation, // Subtle scale animation
                  child: Text(
                    'DVT', // Your chosen short form
                    style: TextStyle(
                      fontSize: widget.size * 0.45, // Slightly larger
                      fontWeight: FontWeight.w900,
                      color: kPrimaryColor, // Light Cyan
                      fontFamily: 'Raleway',
                      shadows: [
                        BoxShadow(
                          color: kPrimaryColor.withOpacity(0.6), // Brighter glow
                          blurRadius: 15, // More blur for ethereal look
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// -------------------------------------------------------------------
// --- 3. Custom Painter for the Rotating Ring (Updated StrokeWidth) ---
// -------------------------------------------------------------------

class RingPainter extends CustomPainter {
  final Color color;
  final double sweepAngle;
  final Color trackColor;
  final double strokeWidth;

  RingPainter({
    required this.color,
    required this.sweepAngle,
    required this.trackColor,
    this.strokeWidth = 5.0, // Customizable stroke width
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - strokeWidth / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius, trackPaint); // Draw dark track

    final arcPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2, // Start from top
      sweepAngle * (pi / 180),
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant RingPainter oldDelegate) {
    return oldDelegate.sweepAngle != sweepAngle ||
           oldDelegate.color != color ||
           oldDelegate.trackColor != trackColor ||
           oldDelegate.strokeWidth != strokeWidth;
  }
}

// -------------------------------------------------------------------
// --- 4. NEW: Custom Painter for Inner Hexagon Grid Effect ---
// -------------------------------------------------------------------

class HexagonGridPainter extends CustomPainter {
  final Color baseColor;
  final double animationValue; // 0.0 to 1.0 for expansion
  final int gridDensity; // How many hexagons in a row/column

  HexagonGridPainter({
    required this.baseColor,
    required this.animationValue,
    this.gridDensity = 3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    final effectiveRadius = maxRadius * animationValue; // Max radius of the expanding pattern

    final paint = Paint()
      ..color = baseColor.withOpacity(0.3 + (animationValue * 0.4)) // Fade in/out
      ..strokeWidth = 1.5 // Thin lines for a delicate look
      ..style = PaintingStyle.stroke;

    // Draw concentric hexagons / squares to form a grid-like pattern
    // Iterate from center outwards, scaling based on animationValue
    for (int i = 0; i <= gridDensity; i++) {
      final currentScale = i / gridDensity; // 0.0 to 1.0 for each "layer"
      
      // Hexagon vertices calculation (more complex, but techy)
      final innerHexRadius = effectiveRadius * currentScale;
      if (innerHexRadius < 1) continue; // Avoid drawing tiny shapes

      Path hexagonPath = Path();
      for (int j = 0; j < 6; j++) {
        final angle = (pi / 3) * j; // 60 degrees apart
        final x = center.dx + innerHexRadius * cos(angle);
        final y = center.dy + innerHexRadius * sin(angle);
        if (j == 0) {
          hexagonPath.moveTo(x, y);
        } else {
          hexagonPath.lineTo(x, y);
        }
      }
      hexagonPath.close();
      canvas.drawPath(hexagonPath, paint);

      // Add cross-lines to connect vertices, making it more like a grid
      if (i > 0) {
        for (int j = 0; j < 3; j++) { // Draw 3 main "spokes"
          final angle = (pi / 3) * j;
          final x1 = center.dx + innerHexRadius * cos(angle);
          final y1 = center.dy + innerHexRadius * sin(angle);
          final x2 = center.dx + innerHexRadius * cos(angle + pi); // Opposite side
          final y2 = center.dy + innerHexRadius * sin(angle + pi);
          canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant HexagonGridPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
           oldDelegate.baseColor != baseColor ||
           oldDelegate.gridDensity != gridDensity;
  }
}