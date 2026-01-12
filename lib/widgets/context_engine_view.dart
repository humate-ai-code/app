import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_app/theme/app_theme.dart';

class ContextEngineView extends StatefulWidget {
  final List<Offset> connectedDeviceOffsets;

  const ContextEngineView({
    super.key,
    required this.connectedDeviceOffsets,
  });

  @override
  State<ContextEngineView> createState() => _ContextEngineViewState();
}

class _ContextEngineViewState extends State<ContextEngineView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // We expect this widget to be in a Stack filling the screen or a large area
    return Stack(
      alignment: Alignment.center,
      children: [
        // The Optical Fiber Animations
        // We pass the center of *this* widget as the end point (The Engine)
        LayoutBuilder(
          builder: (context, constraints) {
            final center = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
            return CustomPaint(
              size: Size.infinite,
              painter: OpticalFiberPainter(
                animation: _controller,
                startPoints: widget.connectedDeviceOffsets,
                endPoint: center,
              ),
            );
          },
        ),
        
        // Center Node: Context Engine Chip
        Positioned(
          // subtle pulsing glow
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.cyanAccent.withValues(alpha: 0.4 + 0.2 * sin(_controller.value * 2 * pi)),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: child,
              );
            },
            child: _buildNodeIcon(Icons.memory, size: 60, isMain: true),
          ),
        ),
      ],
    );
  }

  Widget _buildNodeIcon(IconData icon, {double size = 40, bool isMain = false}) {
    return Container(
      width: size + 20,
      height: size + 20,
      decoration: BoxDecoration(
        color: AppColors.background,
        shape: BoxShape.circle,
        border: Border.all(
          color: isMain ? AppColors.cyanAccent : AppColors.textSecondary,
          width: 2,
        ),
      ),
      child: Icon(
        icon,
        color: isMain ? AppColors.cyanAccent : AppColors.textSecondary,
        size: size,
      ),
    );
  }
}

class OpticalFiberPainter extends CustomPainter {
  final Animation<double> animation;
  final List<Offset> startPoints;
  final Offset endPoint;

  OpticalFiberPainter({
    required this.animation,
    required this.startPoints,
    required this.endPoint,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    for (final start in startPoints) {
      _drawBundle(canvas, start, endPoint);
    }
  }

  void _drawBundle(Canvas canvas, Offset start, Offset end) {
    final rand = Random(start.hashCode); // Consistent random based on start point
    
    // Determine curve direction based on relative position
    // If start is below end, curve should probably go wider or direct?
    // Let's make a nice organic curve.
    
    for (int i = 0; i < 3; i++) { // Fewer fibers per bundle to reduce clutter
        final path = Path();
        path.moveTo(start.dx, start.dy);
        
        // Control point: mid-point + random offset perpendicular to the line
        final midX = (start.dx + end.dx) / 2;
        
        // Simple randomization for organic feel
        final offsetX = (rand.nextDouble() - 0.5) * 100;
        final offsetY = (rand.nextDouble() - 0.5) * 50;

        final controlPoint1 = Offset(midX + offsetX, start.dy + offsetY);
        final controlPoint2 = Offset(midX - offsetX, end.dy - offsetY);
        
        // Cubic bezier for smoother S-curves
        path.cubicTo(
          controlPoint1.dx, controlPoint1.dy, 
          controlPoint2.dx, controlPoint2.dy, 
          end.dx, end.dy
        );
        
        // Draw the base dim line
        final basePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = AppColors.cyanAccent.withValues(alpha: 0.2);
        canvas.drawPath(path, basePaint);
        
        // Draw the traveling pulse
        final pathMetrics = path.computeMetrics().first;
        final length = pathMetrics.length;
        final offset = (animation.value + (i * 0.3)) % 1.0;
        final pulseStart = length * offset;
        final pulseEnd = (pulseStart + 40).clamp(0.0, length.toDouble());

        if (pulseStart < length) {
            final extract = pathMetrics.extractPath(pulseStart, pulseEnd);
            final pulsePaint = Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2.0
                ..shader = LinearGradient(
                    colors: [
                      AppColors.cyanAccent.withValues(alpha: 0), 
                      AppColors.cyanAccent, 
                      AppColors.purpleAccent
                    ],
                    stops: const [0.0, 0.5, 1.0],
                ).createShader(extract.getBounds());
            
            canvas.drawPath(extract, pulsePaint);
        }
    }
  }

  @override
  bool shouldRepaint(covariant OpticalFiberPainter oldDelegate) => true;
}
