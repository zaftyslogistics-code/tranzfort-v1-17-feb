import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/dialogs.dart';
import '../../services/ai_model_manager.dart';
import '../../services/llm_service.dart';
import '../../services/ai_tts_service.dart';
import '../../services/ai_stt_service.dart';
import '../../providers/bot_provider.dart';

/// Settings screen for managing on-device AI models.
///
/// Shows per-model cards with download/delete/toggle controls.
/// Total storage used at the bottom with "Delete All" option.
class AiSettingsScreen extends ConsumerStatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  ConsumerState<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends ConsumerState<AiSettingsScreen> {
  late final AiModelManager _mgr;
  int _totalStorageBytes = 0;

  @override
  void initState() {
    super.initState();
    _mgr = ref.read(aiModelManagerProvider);
    _mgr.addListener(_onManagerChanged);
    _refreshStorage();
  }

  @override
  void dispose() {
    _mgr.removeListener(_onManagerChanged);
    super.dispose();
  }

  void _onManagerChanged() {
    if (mounted) {
      setState(() {});
      _refreshStorage();
    }
  }

  Future<void> _refreshStorage() async {
    final bytes = await _mgr.totalStorageUsed;
    if (mounted) setState(() => _totalStorageBytes = bytes);
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final llmInfo = _mgr.getLlmInfo();
    final ttsInfo = _mgr.getTtsInfo();
    final sttInfo = _mgr.getSttInfo();

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(title: const Text('AI & Voice')),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF4ECDC4)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'On-Device AI',
                          style: AppTypography.bodyMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Download AI models for offline bot, voice, and transcription. '
                          'All processing happens on your phone.',
                          style: AppTypography.caption.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // LLM Section
            Text('Chat AI', style: AppTypography.h3Subsection),
            const SizedBox(height: 12),
            _buildModelCard(llmInfo),

            const SizedBox(height: 24),

            // TTS Section
            Text('AI Voice', style: AppTypography.h3Subsection),
            const SizedBox(height: 12),
            _buildModelCard(ttsInfo),

            const SizedBox(height: 24),

            // STT Section
            Text('Voice Input', style: AppTypography.h3Subsection),
            const SizedBox(height: 12),
            _buildModelCard(sttInfo),

            const SizedBox(height: 24),

            // Diagnostics Panel
            _buildDiagnosticsPanel(),

            const SizedBox(height: 24),

            // Storage summary
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                boxShadow: AppColors.cardShadow,
              ),
              child: Row(
                children: [
                  Icon(Icons.storage, color: AppColors.textTertiary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total AI Storage',
                            style: AppTypography.bodySmall
                                .copyWith(fontWeight: FontWeight.w600)),
                        Text(
                          _formatBytes(_totalStorageBytes),
                          style: AppTypography.caption
                              .copyWith(color: AppColors.textTertiary),
                        ),
                      ],
                    ),
                  ),
                  if (_totalStorageBytes > 0)
                    TextButton(
                      onPressed: _confirmDeleteAll,
                      child: Text(
                        'Delete All',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // DIAGNOSTICS PANEL
  // ===========================================================================

  Widget _buildDiagnosticsPanel() {
    final llmMetrics = LlmService().lastMetrics;
    final ttsMetrics = AiTtsService().lastMetrics;
    final sttMetrics = AiSttService().lastMetrics;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        boxShadow: AppColors.cardShadow,
        border: Border.all(color: AppColors.brandTeal.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.speed, color: AppColors.brandTeal, size: 20),
              const SizedBox(width: 8),
              Text(
                'Performance Diagnostics',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Test AI models and view timing metrics',
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 16),

          // LLM Test
          _buildDiagnosticsRow(
            label: 'LLM (TinyLlama)',
            icon: Icons.auto_awesome,
            metrics: llmMetrics?.toString() ?? 'Not tested yet',
            onTest: _testLlm,
            isAvailable: _mgr.isReady(AiModelType.llm) && _mgr.useAiLlm,
          ),
          const Divider(height: 24),

          // TTS Test
          _buildDiagnosticsRow(
            label: 'TTS (Kokoro - Female hi+en)',
            icon: Icons.record_voice_over,
            metrics: ttsMetrics?.toString() ?? 'Not tested yet',
            onTest: _testTts,
            isAvailable: _mgr.isReady(AiModelType.tts) && _mgr.useAiTts,
          ),
          const Divider(height: 24),

          // STT Test
          _buildDiagnosticsRow(
            label: 'STT (Whisper)',
            icon: Icons.mic,
            metrics: sttMetrics?.toString() ?? 'Not tested yet',
            onTest: _testStt,
            isAvailable: _mgr.isReady(AiModelType.stt) && _mgr.useAiStt,
            isRecording: _isRecordingStt,
          ),

          const SizedBox(height: 16),

          // Refresh button
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh Metrics'),
            ),
          ),
        ],
      ),
    );
  }

  bool _isRecordingStt = false;

  Widget _buildDiagnosticsRow({
    required String label,
    required IconData icon,
    required String metrics,
    required VoidCallback onTest,
    required bool isAvailable,
    bool isRecording = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (isAvailable)
              FilledButton.tonalIcon(
                onPressed: onTest,
                icon: Icon(
                  isRecording ? Icons.stop : Icons.play_arrow,
                  size: 16,
                ),
                label: Text(isRecording ? 'Stop' : 'Test'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(80, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  textStyle: AppTypography.caption,
                ),
              )
            else
              Text(
                'Model not ready',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.scaffoldBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            metrics,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // DIAGNOSTIC TEST METHODS
  // ===========================================================================

  Future<void> _testLlm() async {
    AppDialogs.showSuccessSnackBar(context, 'Testing LLM...');

    final llm = LlmService();
    
    // Check model file first
    final mgr = ref.read(aiModelManagerProvider);
    final modelPath = await mgr.getModelPath(AiModelType.llm);
    if (!mounted) return;
    if (modelPath == null) {
      AppDialogs.showErrorSnackBar(context, 'LLM: Model not downloaded');
      return;
    }
    final file = File(modelPath);
    if (!file.existsSync()) {
      AppDialogs.showErrorSnackBar(context, 'LLM: Model file missing');
      return;
    }
    final size = file.lengthSync();
    if (size < 100 * 1024 * 1024) {
      AppDialogs.showErrorSnackBar(context, 'LLM: Model file too small (${(size/1024/1024).toStringAsFixed(0)} MB)');
      return;
    }

    final ok = await llm.load();
    if (!mounted) return;
    if (!ok) {
      AppDialogs.showErrorSnackBar(context, 'LLM: Failed to load model (check logs)');
      return;
    }

    // Run a simple test prompt
    final testText = await llm.generateResponse(
      userMessage: 'Say "Hello from TranZfort" in 5 words or less.',
      userRole: 'supplier',
      language: 'en',
    );

    if (mounted) {
      setState(() {}); // Refresh metrics display
      AppDialogs.showSuccessSnackBar(
        context,
        'LLM Test: "${testText.substring(0, testText.length.clamp(0, 40))}..."',
      );
    }
  }

  Future<void> _testTts() async {
    AppDialogs.showSuccessSnackBar(context, 'Testing TTS...');

    final tts = AiTtsService();
    final ok = await tts.initialize();
    if (!ok) {
      // Try to get more details about why it failed
      final mgr = ref.read(aiModelManagerProvider);
      final modelPath = await mgr.getModelPath(AiModelType.tts);
      if (!mounted) return;
      String errorDetail = '';
      if (modelPath == null) {
        errorDetail = 'Model not downloaded';
      } else {
        final file = File(modelPath);
        if (!file.existsSync()) {
          errorDetail = 'Model file missing at $modelPath';
        } else {
          final size = file.lengthSync();
          errorDetail = 'File exists (${(size / 1024 / 1024).toStringAsFixed(1)} MB) but init failed';
        }
      }
      AppDialogs.showErrorSnackBar(context, 'TTS failed: $errorDetail');
      return;
    }

    await tts.speak(
      'Hello from TranZfort voice testing.',
      'en',
    );

    if (mounted) {
      setState(() {}); // Refresh metrics display
    }
  }

  Future<void> _testStt() async {
    final stt = AiSttService();

    if (_isRecordingStt) {
      // Stop and transcribe
      final text = await stt.stopAndTranscribe(language: 'en');
      _isRecordingStt = false;

      if (mounted) {
        setState(() {}); // Refresh metrics display
        if (text != null) {
          AppDialogs.showSuccessSnackBar(context, 'STT: "$text"');
        } else {
          AppDialogs.showErrorSnackBar(context, 'STT failed or empty');
        }
      }
    } else {
      // Start recording
      final ok = await stt.initialize();
      if (!mounted) return;
      if (!ok) {
        AppDialogs.showErrorSnackBar(context, 'STT failed to initialize');
        return;
      }

      final started = await stt.startRecording();
      if (!mounted) return;
      if (started) {
        _isRecordingStt = true;
        setState(() {});
        AppDialogs.showSuccessSnackBar(context, 'Recording... Tap Stop when done');
      } else {
        AppDialogs.showErrorSnackBar(context, 'Failed to start recording');
      }
    }
  }

  // ===========================================================================
  // MODEL CARDS
  // ===========================================================================

  Widget _buildModelCard(AiModelInfo info) {
    final isDownloading = info.status == AiModelStatus.downloading;
    final isReady = info.status == AiModelStatus.ready;
    final isError = info.status == AiModelStatus.error;

    final isEnabled = _getToggleValue(info.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        boxShadow: AppColors.cardShadow,
        border: isReady
            ? Border.all(color: AppColors.brandTeal.withValues(alpha: 0.3))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _iconForType(info.type),
                color: isReady ? AppColors.brandTeal : AppColors.textTertiary,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(info.label,
                        style: AppTypography.bodyMedium
                            .copyWith(fontWeight: FontWeight.w600)),
                    Text(info.description,
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textTertiary)),
                  ],
                ),
              ),
              // Status chip
              _buildStatusChip(info),
            ],
          ),

          // Progress bar when downloading
          if (isDownloading) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: info.downloadProgress,
                backgroundColor: AppColors.brandTeal.withValues(alpha: 0.15),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.brandTeal),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(info.downloadProgress * 100).toStringAsFixed(0)}% — ${info.estimatedSize}',
              style: AppTypography.caption
                  .copyWith(color: AppColors.textTertiary),
            ),
          ],

          // Error message
          if (isError && _mgr.getErrorMessage(info.type) != null) ...[
            const SizedBox(height: 8),
            Text(
              _mgr.getErrorMessage(info.type)!,
              style: AppTypography.caption.copyWith(color: AppColors.error),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // Action row
          const SizedBox(height: 12),
          Row(
            children: [
              if (!isReady && !isDownloading)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      if (info.type == AiModelType.llm) {
                        _mgr.downloadLlm();
                      } else if (info.type == AiModelType.tts) {
                        _mgr.downloadTts();
                      } else if (info.type == AiModelType.stt) {
                        _mgr.downloadStt();
                      }
                    },
                    icon: const Icon(Icons.download, size: 18),
                    label: Text('Download ${info.estimatedSize}'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brandTeal,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      textStyle: AppTypography.bodySmall,
                    ),
                  ),
                ),
              if (isError) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: TextButton(
                    onPressed: () {
                      if (info.type == AiModelType.llm) {
                        _mgr.downloadLlm();
                      } else if (info.type == AiModelType.tts) {
                        _mgr.downloadTts();
                      } else if (info.type == AiModelType.stt) {
                        _mgr.downloadStt();
                      }
                    },
                    child: const Text('Retry'),
                  ),
                ),
              ],
              if (isReady) ...[
                // Toggle switch
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        isEnabled ? 'Enabled' : 'Disabled',
                        style: AppTypography.bodySmall.copyWith(
                          color: isEnabled
                              ? AppColors.brandTeal
                              : AppColors.textTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Switch(
                        value: isEnabled,
                        onChanged: (v) => _setToggle(info.type, v),
                        activeTrackColor: AppColors.brandTeal,
                      ),
                    ],
                  ),
                ),
                // Delete button
                IconButton(
                  onPressed: () => _confirmDelete(info),
                  icon: Icon(Icons.delete_outline,
                      color: AppColors.error, size: 20),
                  tooltip: 'Delete model',
                ),
              ],
              if (isDownloading)
                Expanded(
                  child: Center(
                    child: Text(
                      'Downloading...',
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.brandTeal),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(AiModelInfo info) {
    Color bg;
    Color fg;
    String label;

    switch (info.status) {
      case AiModelStatus.ready:
        bg = AppColors.brandTeal.withValues(alpha: 0.1);
        fg = AppColors.brandTeal;
        label = 'Ready';
        break;
      case AiModelStatus.downloading:
        bg = AppColors.brandOrange.withValues(alpha: 0.1);
        fg = AppColors.brandOrange;
        label = 'Downloading';
        break;
      case AiModelStatus.error:
        bg = AppColors.error.withValues(alpha: 0.1);
        fg = AppColors.error;
        label = 'Error';
        break;
      case AiModelStatus.notDownloaded:
        bg = AppColors.textTertiary.withValues(alpha: 0.1);
        fg = AppColors.textTertiary;
        label = 'Not Downloaded';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: AppTypography.caption
              .copyWith(color: fg, fontWeight: FontWeight.w600, fontSize: 10)),
    );
  }

  IconData _iconForType(AiModelType type) {
    switch (type) {
      case AiModelType.llm:
        return Icons.auto_awesome;
      case AiModelType.tts:
        return Icons.record_voice_over;
      case AiModelType.stt:
        return Icons.mic;
    }
  }

  bool _getToggleValue(AiModelType type) {
    switch (type) {
      case AiModelType.llm:
        return _mgr.useAiLlm;
      case AiModelType.tts:
        return _mgr.useAiTts;
      case AiModelType.stt:
        return _mgr.useAiStt;
    }
  }

  void _setToggle(AiModelType type, bool value) {
    switch (type) {
      case AiModelType.llm:
        _mgr.setUseAiLlm(value);
        break;
      case AiModelType.tts:
        _mgr.setUseAiTts(value);
        break;
      case AiModelType.stt:
        _mgr.setUseAiStt(value);
        break;
    }
  }

  Future<void> _confirmDelete(AiModelInfo info) async {
    final confirmed = await AppDialogs.confirm(
      context,
      title: 'Delete ${info.label}?',
      description:
          'This will free up ${info.estimatedSize} of storage. You can re-download anytime.',
      confirmText: 'Delete',
      isDestructive: true,
    );
    if (confirmed) {
      if (info.type == AiModelType.llm) {
        await _mgr.deleteLlm();
      } else if (info.type == AiModelType.tts) {
        await _mgr.deleteTts();
      } else if (info.type == AiModelType.stt) {
        await _mgr.deleteStt();
      }
      if (mounted) {
        AppDialogs.showSuccessSnackBar(context, '${info.label} deleted');
      }
    }
  }

  Future<void> _confirmDeleteAll() async {
    final confirmed = await AppDialogs.confirm(
      context,
      title: 'Delete All AI Models?',
      description:
          'This will free up ${_formatBytes(_totalStorageBytes)}. Bot will use basic mode.',
      confirmText: 'Delete All',
      isDestructive: true,
    );
    if (confirmed) {
      await _mgr.deleteAll();
      if (mounted) {
        AppDialogs.showSuccessSnackBar(context, 'All AI models deleted');
      }
    }
  }
}
