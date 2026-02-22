import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/auth_service_provider.dart';

/// Small speaker icon button that reads text aloud via TTS.
/// Toggles between play/stop. Pulses while speaking.
/// [text] — display text shown in tooltip.
/// [spokenText] — what actually gets spoken (falls back to [text] if null).
/// [locale] — 'hi-IN' for Hindi/Hinglish, 'en-IN' for English (default).
class TtsButton extends ConsumerStatefulWidget {
  final String text;
  final String? spokenText;
  final double size;
  final String locale;

  const TtsButton({
    super.key,
    required this.text,
    this.spokenText,
    this.size = 20,
    this.locale = 'en-IN',
  });

  @override
  ConsumerState<TtsButton> createState() => _TtsButtonState();
}

class _TtsButtonState extends ConsumerState<TtsButton> {
  bool _isSpeaking = false;

  String get _effectiveText => widget.spokenText ?? widget.text;

  Future<void> _toggle() async {
    final tts = ref.read(ttsServiceProvider);
    if (_isSpeaking) {
      await tts.stop();
      if (mounted) setState(() => _isSpeaking = false);
    } else {
      await _speak(tts);
    }
  }

  Future<void> _speak(dynamic tts) async {
    setState(() => _isSpeaking = true);
    await tts.speak(_effectiveText, locale: widget.locale);
    // Wait for completion — TTS is async, poll briefly
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted && !tts.isSpeaking) {
      setState(() => _isSpeaking = false);
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

  Future<void> _replay() async {
    final tts = ref.read(ttsServiceProvider);
    await tts.stop();
    if (mounted) await _speak(tts);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: _replay,
      child: IconButton(
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
      ),
    );
  }
}
