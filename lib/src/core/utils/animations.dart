import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_spacing.dart';

/// Reusable animation extensions and helpers for TranZfort.
/// Uses flutter_animate for declarative staggered animations.

/// Standard fade+slide entrance for list items with stagger delay.
extension StaggerAnimateList on Widget {
  /// Animate a list item with fadeIn + slideUp, staggered by [index].
  Widget staggerEntrance(int index) {
    return animate(
      delay: AppSpacing.staggerDelay * index,
    )
        .fadeIn(duration: AppSpacing.normal, curve: Curves.easeOut)
        .slideY(
          begin: 0.05,
          end: 0,
          duration: AppSpacing.normal,
          curve: Curves.easeOut,
        );
  }
}

/// Standard page transition for GoRouter (fade + slide).
CustomTransitionPage<void> fadeSlideTransitionPage({
  required Widget child,
  LocalKey? key,
}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: AppSpacing.normal,
    reverseTransitionDuration: AppSpacing.normal,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      );
      return FadeTransition(
        opacity: curvedAnimation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.03, 0),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: child,
        ),
      );
    },
  );
}

/// Count-up animation widget for dashboard stat numbers.
class CountUpText extends StatefulWidget {
  final int value;
  final TextStyle? style;
  final String prefix;
  final Duration duration;

  const CountUpText({
    super.key,
    required this.value,
    this.style,
    this.prefix = '',
    this.duration = const Duration(milliseconds: 500),
  });

  @override
  State<CountUpText> createState() => _CountUpTextState();
}

class _CountUpTextState extends State<CountUpText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = IntTween(begin: 0, end: widget.value).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(CountUpText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = IntTween(
        begin: _animation.value,
        end: widget.value,
      ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      );
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Text(
          '${widget.prefix}${_animation.value}',
          style: widget.style,
        );
      },
    );
  }
}
