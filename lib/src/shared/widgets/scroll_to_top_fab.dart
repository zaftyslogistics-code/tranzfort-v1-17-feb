import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// A floating action button that appears when the user scrolls down
/// past [showAfterOffset] pixels. Tapping it scrolls back to the top.
class ScrollToTopFab extends StatefulWidget {
  final ScrollController scrollController;
  final double showAfterOffset;

  const ScrollToTopFab({
    super.key,
    required this.scrollController,
    this.showAfterOffset = 500,
  });

  @override
  State<ScrollToTopFab> createState() => _ScrollToTopFabState();
}

class _ScrollToTopFabState extends State<ScrollToTopFab> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    final show = widget.scrollController.offset > widget.showAfterOffset;
    if (show != _visible) {
      setState(() => _visible = show);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: AnimatedOpacity(
        opacity: _visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: FloatingActionButton.small(
          heroTag: 'scrollToTop',
          backgroundColor: AppColors.brandTeal,
          onPressed: () {
            widget.scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
            );
          },
          child: const Icon(Icons.keyboard_arrow_up, color: Colors.white),
        ),
      ),
    );
  }
}
