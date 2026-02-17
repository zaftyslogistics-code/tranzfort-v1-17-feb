import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';

class GradientButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double? width;
  final double height;

  const GradientButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.width,
    this.height = AppSpacing.buttonHeight,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _isPressed = false;

  bool get _isEnabled => widget.onPressed != null && !widget.isLoading;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: _isEnabled,
      label: widget.isLoading ? '${widget.text}, loading' : widget.text,
      child: GestureDetector(
      onTapDown: _isEnabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: _isEnabled
          ? (_) {
              setState(() => _isPressed = false);
              HapticFeedback.mediumImpact();
              widget.onPressed?.call();
            }
          : null,
      onTapCancel:
          _isEnabled ? () => setState(() => _isPressed = false) : null,
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: AppSpacing.fast,
        child: Container(
          width: widget.width ?? double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: _isEnabled ? AppColors.tranzfortGradient : null,
            color: _isEnabled ? null : Colors.grey.shade400,
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
            boxShadow: _isEnabled
                ? [
                    BoxShadow(
                      color: AppColors.brandTeal.withValues(alpha: 0.30),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    widget.text,
                    style: AppTypography.buttonLarge.copyWith(
                      color: _isEnabled
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.50),
                    ),
                  ),
          ),
        ),
      ),
      ),
    );
  }
}
