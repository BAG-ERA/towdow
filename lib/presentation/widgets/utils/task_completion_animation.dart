// Reusable task completion animation widget
// Shows an animated checkmark overlay to indicate task completion
// Can be used anywhere in the app when marking tasks as complete

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A reusable widget that displays an animated checkmark to indicate task completion.
/// 
/// This widget shows a circular background with an animated checkmark that scales in
/// and fades out. It's designed to provide visual feedback when a task is completed.
/// 
/// Usage:
/// ```dart
/// await TaskCompletionAnimation.show(context);
/// // Task completion logic continues after animation
/// ```
class TaskCompletionAnimation extends StatefulWidget {
  /// The duration of the animation
  final Duration duration;
  
  /// The size of the completion circle
  final double size;
  
  /// The color of the checkmark and circle
  final Color? color;

  const TaskCompletionAnimation({
    super.key,
    this.duration = const Duration(milliseconds: 600),
    this.size = 120.0,
    this.color,
  });

  @override
  State<TaskCompletionAnimation> createState() => _TaskCompletionAnimationState();

  /// Shows the completion animation as an overlay
  /// 
  /// Returns a Future that completes when the animation finishes
  static Future<void> show(
    BuildContext context, {
    Duration duration = const Duration(milliseconds: 600),
    double size = 120.0,
    Color? color,
  }) async {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    
    final completer = Completer<void>();
    
    overlayEntry = OverlayEntry(
      builder: (context) => TaskCompletionAnimation(
        duration: duration,
        size: size,
        color: color,
        key: ValueKey('completion_${DateTime.now().millisecondsSinceEpoch}'),
      ),
    );
    
    overlay.insert(overlayEntry);
    
    // Wait for animation to complete, then remove overlay
    Future.delayed(duration, () {
      overlayEntry.remove();
      completer.complete();
    });
    
    return completer.future;
  }
}

class _TaskCompletionAnimationState extends State<TaskCompletionAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _checkmarkAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    // Circle scales up quickly
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.4, curve: Curves.elasticOut),
    ));

    // Everything fades out at the end
    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
    ));

    // Checkmark draws in after circle appears
    _checkmarkAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.6, curve: Curves.easeOut),
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.color ?? theme.colorScheme.primary;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Material(
          type: MaterialType.transparency,
          child: Container(
            color: Colors.black.withOpacity(0.3 * _fadeAnimation.value),
            child: Center(
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Opacity(
                  opacity: _fadeAnimation.value,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: CustomPaint(
                      painter: _CheckmarkPainter(
                        progress: _checkmarkAnimation.value,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  final double progress;
  final Color color;

  _CheckmarkPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    
    // Define checkmark coordinates as percentages of size
    final startX = size.width * 0.25;
    final startY = size.height * 0.50;
    final midX = size.width * 0.42;
    final midY = size.height * 0.65;
    final endX = size.width * 0.75;
    final endY = size.height * 0.35;

    // Calculate total path length for animation
    final firstSegmentLength = math.sqrt(
      math.pow(midX - startX, 2) + math.pow(midY - startY, 2),
    );
    final secondSegmentLength = math.sqrt(
      math.pow(endX - midX, 2) + math.pow(endY - midY, 2),
    );
    final totalLength = firstSegmentLength + secondSegmentLength;

    final currentLength = totalLength * progress;

    path.moveTo(startX, startY);

    if (currentLength <= firstSegmentLength) {
      // Drawing first segment
      final t = currentLength / firstSegmentLength;
      final x = startX + (midX - startX) * t;
      final y = startY + (midY - startY) * t;
      path.lineTo(x, y);
    } else {
      // First segment complete, drawing second segment
      path.lineTo(midX, midY);
      final remainingLength = currentLength - firstSegmentLength;
      final t = remainingLength / secondSegmentLength;
      final x = midX + (endX - midX) * t;
      final y = midY + (endY - midY) * t;
      path.lineTo(x, y);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CheckmarkPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

