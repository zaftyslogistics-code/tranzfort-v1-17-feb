import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/auth_service_provider.dart';

/// Small speaker icon button that reads text aloud via TTS.
/// Toggles between play/stop. Pulses while speaking.
class TtsButton extends ConsumerStatefulWidget {
  final String text;
  final double size;

  const TtsButton({super.key, required this.text, this.size = 20});

  @override
  ConsumerState<TtsButton> createState() => _TtsButtonState();
}

class _TtsButtonState extends ConsumerState<TtsButton> {
  bool _isSpeaking = false;

  Future<void> _toggle() async {
    final tts = ref.read(ttsServiceProvider);
    if (_isSpeaking) {
      await tts.stop();
      if (mounted) setState(() => _isSpeaking = false);
    } else {
      setState(() => _isSpeaking = true);
      await tts.speak(widget.text);
      // Wait for completion — TTS is async, poll briefly
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted && !tts.isSpeaking) {
        setState(() => _isSpeaking = false);
      }
    }
  }

  @override
  void dispose() {
    // Stop TTS if this widget is removed while speaking
    if (_isSpeaking) {
      ref.read(ttsServiceProvider).stop();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        _isSpeaking ? Icons.stop_circle_outlined : Icons.volume_up_outlined,
        size: widget.size,
        color: _isSpeaking ? AppColors.brandOrange : AppColors.textTertiary,
      ),
      tooltip: _isSpeaking ? 'Stop reading' : 'Read aloud',
      onPressed: _toggle,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(
        minWidth: widget.size + 16,
        minHeight: widget.size + 16,
      ),
    );
  }
}
