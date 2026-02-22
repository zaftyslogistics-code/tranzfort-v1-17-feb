import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';

/// Task 5.13: Slim animated connectivity indicator.
/// Shows a compact bar that slides down when offline and auto-dismisses
/// "Back online" after 2 seconds.
class ConnectivityBanner extends StatefulWidget {
  final Widget child;

  const ConnectivityBanner({super.key, required this.child});

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner>
    with SingleTickerProviderStateMixin {
  late StreamSubscription<List<ConnectivityResult>> _subscription;
  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;
  bool _isOffline = false;
  bool _showBackOnline = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    ));

    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      final offline = results.contains(ConnectivityResult.none);

      if (!offline && _isOffline) {
        setState(() {
          _isOffline = false;
          _showBackOnline = true;
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _animController.reverse().then((_) {
              if (mounted) setState(() => _showBackOnline = false);
            });
          }
        });
      } else if (offline && !_isOffline) {
        setState(() => _isOffline = true);
        _animController.forward();
      }
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showBanner = _isOffline || _showBackOnline;

    return Column(
      children: [
        if (showBanner)
          SlideTransition(
            position: _slideAnimation,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top > 0 ? 4 : 0,
                bottom: 6,
                left: 16,
                right: 16,
              ),
              color: _isOffline ? AppColors.error : AppColors.success,
              child: SafeArea(
                bottom: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isOffline ? Icons.wifi_off : Icons.wifi,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isOffline ? 'No internet connection' : 'Back online',
                      style: AppTypography.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}
