import 'package:flutter/material.dart';

class AppLoader extends StatefulWidget {
  final String? message;
  final double size;
  final Color? color;

  const AppLoader({
    Key? key,
    this.message,
    this.size = 50.0,
    this.color,
  }) : super(key: key);

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: widget.size + 20,
            height: widget.size + 20,
            decoration: BoxDecoration(
              color: const Color(0xFF0D1D20).withOpacity(0.8),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF75E5E2).withOpacity(0.3),
                  spreadRadius: 2,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _animation.value * 2 * 3.14159,
                    child: Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        gradient: const SweepGradient(
                          colors: [
                            Color(0xFF75E5E2),
                            Color(0xFF4A9B98),
                            Color(0xFF75E5E2),
                          ],
                          stops: [0.0, 0.5, 1.0],
                        ),
                        borderRadius: BorderRadius.circular(widget.size / 2),
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D1D20),
                          borderRadius: BorderRadius.circular((widget.size - 8) / 2),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.restaurant,
                            color: Color(0xFF75E5E2),
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          if (widget.message != null) ...[
            const SizedBox(height: 16),
            Text(
              widget.message!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontFamily: 'Raleway',
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class AppLoaderOverlay {
  static OverlayEntry? _overlayEntry;

  static void show(BuildContext context, {String? message}) {
    if (_overlayEntry != null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => Material(
        color: Colors.black.withOpacity(0.7),
        child: AppLoader(message: message),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  static void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}