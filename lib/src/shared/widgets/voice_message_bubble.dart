import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/constants/app_colors.dart';

class VoiceMessageBubble extends StatefulWidget {
  final String voiceUrl;
  final int durationSeconds;
  final bool isMine;

  const VoiceMessageBubble({
    super.key,
    required this.voiceUrl,
    required this.durationSeconds,
    required this.isMine,
  });

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  final _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      final dur = await _player.setUrl(widget.voiceUrl);
      if (dur != null && mounted) {
        setState(() => _duration = dur);
      }
    } catch (_) {
      // URL may be invalid or expired
    }

    _player.positionStream.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });

    _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state.playing);
        if (state.processingState == ProcessingState.completed) {
          _player.seek(Duration.zero);
          _player.pause();
        }
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final totalDur = _duration.inSeconds > 0
        ? _duration
        : Duration(seconds: widget.durationSeconds);
    final progress = totalDur.inMilliseconds > 0
        ? (_position.inMilliseconds / totalDur.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isMine
            ? Colors.white.withValues(alpha: 0.15)
            : AppColors.brandTealLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              if (_isPlaying) {
                _player.pause();
              } else {
                _player.play();
              }
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: widget.isMine
                    ? Colors.white.withValues(alpha: 0.25)
                    : AppColors.brandTeal,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: widget.isMine ? Colors.white : Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 120,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: widget.isMine
                          ? Colors.white.withValues(alpha: 0.2)
                          : AppColors.borderDefault,
                      valueColor: AlwaysStoppedAnimation(
                        widget.isMine
                            ? Colors.white
                            : AppColors.brandTeal,
                      ),
                      minHeight: 3,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isPlaying
                      ? _formatDuration(_position)
                      : _formatDuration(totalDur),
                  style: TextStyle(
                    fontSize: 11,
                    color: widget.isMine
                        ? Colors.white.withValues(alpha: 0.7)
                        : AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
