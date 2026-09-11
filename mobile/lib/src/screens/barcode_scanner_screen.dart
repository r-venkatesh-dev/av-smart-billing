import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../sound_service.dart';

/// Feedback result returned by a continuous barcode scan callback.
class BarcodeScanFeedback {
  final bool success;
  final String title;
  final String? subtitle;

  const BarcodeScanFeedback({
    required this.success,
    required this.title,
    this.subtitle,
  });
}

class BarcodeScannerScreen extends StatefulWidget {
  /// If provided, the camera stays open continuously and calls this handler
  /// on each valid barcode detection without auto-closing.
  final Future<BarcodeScanFeedback> Function(String barcode)? onContinuousScan;

  /// Optional bottom widget, e.g. live cart summary and "Done Billing" button.
  final Widget? bottomSummary;

  /// Custom title for the scanner screen.
  final String title;

  const BarcodeScannerScreen({
    super.key,
    this.onContinuousScan,
    this.bottomSummary,
    this.title = 'Scan barcode',
  });

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _singleScanReturned = false;
  bool _isProcessing = false;
  bool _torchEnabled = false;

  String? _lastScannedCode;
  DateTime? _lastScanTime;
  BarcodeScanFeedback? _activeFeedback;
  Timer? _feedbackTimer;

  bool get isContinuous => widget.onContinuousScan != null;

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(String code) async {
    final rawCode = code.trim();
    if (rawCode.isEmpty) return;

    if (!isContinuous) {
      if (!_singleScanReturned) {
        _singleScanReturned = true;
        await SoundService.beepSuccess();
        if (mounted) Navigator.pop(context, rawCode);
      }
      return;
    }

    final now = DateTime.now();

    // Prevent overlapping async lookups
    if (_isProcessing) return;

    // Cooldown: prevent duplicate scans of the exact same barcode within 1.5 seconds
    if (_lastScannedCode == rawCode &&
        _lastScanTime != null &&
        now.difference(_lastScanTime!).inMilliseconds < 1500) {
      return;
    }

    // Minimum delay between scanning any barcode (600ms)
    if (_lastScanTime != null &&
        now.difference(_lastScanTime!).inMilliseconds < 600) {
      return;
    }

    _isProcessing = true;
    _lastScannedCode = rawCode;
    _lastScanTime = now;

    try {
      final feedback = await widget.onContinuousScan!(rawCode);
      if (mounted) {
        _feedbackTimer?.cancel();
        setState(() {
          _activeFeedback = feedback;
        });
        _feedbackTimer = Timer(const Duration(milliseconds: 2500), () {
          if (mounted) {
            setState(() {
              _activeFeedback = null;
            });
          }
        });
      }
    } catch (_) {
      // In case of unexpected error, beep error and show message
      await SoundService.beepError();
      if (mounted) {
        setState(() {
          _activeFeedback = BarcodeScanFeedback(
            success: false,
            title: 'Scan error',
            subtitle: 'Could not process barcode',
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedback = _activeFeedback;
    final boxBorderColor = feedback == null
        ? Colors.white
        : feedback.success
            ? const Color(0xff057c73)
            : const Color(0xffc53030);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: _torchEnabled ? 'Turn torch off' : 'Turn torch on',
            icon: Icon(
              _torchEnabled ? Icons.flash_on : Icons.flash_off,
              color: _torchEnabled ? Colors.amber : Colors.white70,
            ),
            onPressed: () async {
              try {
                await _controller.toggleTorch();
                setState(() => _torchEnabled = !_torchEnabled);
              } catch (_) {}
            },
          ),
          if (isContinuous)
            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.check, color: Colors.white),
              label: const Text(
                'Done',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final value = capture.barcodes.firstOrNull?.rawValue;
              if (value != null) {
                _handleBarcode(value);
              }
            },
          ),

          // Viewfinder box
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 280,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: boxBorderColor, width: 3.5),
                borderRadius: BorderRadius.circular(16),
                boxShadow: feedback != null
                    ? [
                        BoxShadow(
                          color: (feedback.success
                                  ? const Color(0xff057c73)
                                  : const Color(0xffc53030))
                              .withValues(alpha: 0.35),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
            ),
          ),

          // Real-time feedback banner
          Positioned(
            top: 24,
            left: 20,
            right: 20,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: feedback != null
                  ? Container(
                      key: ValueKey('${feedback.title}_${feedback.success}'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: feedback.success
                            ? const Color(0xff057c73)
                            : const Color(0xffc53030),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black45,
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            feedback.success
                                ? Icons.check_circle_outline
                                : Icons.error_outline,
                            color: Colors.white,
                            size: 26,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  feedback.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (feedback.subtitle != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    feedback.subtitle!,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),

          // Bottom instruction & custom bottom summary
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87, Colors.black],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.bottomSummary != null)
                      widget.bottomSummary!
                    else
                      const Text(
                        'Place product barcode inside the box',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
