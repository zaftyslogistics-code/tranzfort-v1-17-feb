import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../core/constants/app_colors.dart';

class ConnectivityBanner extends StatefulWidget {
  final Widget child;

  const ConnectivityBanner({super.key, required this.child});

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  late StreamSubscription<List<ConnectivityResult>> _subscription;
  bool _isOffline = false;
  bool _showBackOnline = false;

  @override
  void initState() {
    super.initState();
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      final offline = results.contains(ConnectivityResult.none);

      if (!offline && _isOffline) {
        // Was offline, now back online
        setState(() {
          _isOffline = false;
          _showBackOnline = true;
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _showBackOnline = false);
        });
      } else if (offline) {
        setState(() => _isOffline = true);
      }
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_isOffline)
          MaterialBanner(
            content: const Text(
              'No internet connection',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
            backgroundColor: AppColors.error,
            leading: const Icon(Icons.wifi_off, color: Colors.white),
            actions: [const SizedBox.shrink()],
          ),
        if (_showBackOnline)
          MaterialBanner(
            content: const Text(
              'Back online',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
            backgroundColor: AppColors.success,
            leading: const Icon(Icons.wifi, color: Colors.white),
            actions: [const SizedBox.shrink()],
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}
