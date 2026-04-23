import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/qr_decoder_service.dart';
import '../theme/app_theme.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    autoStart: false,
    facing: kIsWeb ? CameraFacing.front : CameraFacing.back,
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final ImagePicker _imagePicker = ImagePicker();
  final QrDecoderService _qrDecoderService = const QrDecoderService();

  bool _hasHandledDetection = false;
  bool _isTorchOn = false;
  bool _isStartingCamera = true;
  bool _isProcessingResult = false;
  String? _cameraErrorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScanner();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startScanner() async {
    try {
      await _controller.start();
      if (!mounted) {
        return;
      }
      setState(() {
        _isStartingCamera = false;
        _cameraErrorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isStartingCamera = false;
        _cameraErrorMessage = error.toString();
      });
    }
  }

  Future<void> _handleDetection(BarcodeCapture capture) async {
    if (_hasHandledDetection || _isProcessingResult) {
      return;
    }

    String? rawValue;
    for (final barcode in capture.barcodes) {
      final candidate = barcode.rawValue?.trim();
      if (candidate != null && candidate.isNotEmpty) {
        rawValue = candidate;
        break;
      }
    }

    if (rawValue == null) {
      return;
    }

    _hasHandledDetection = true;
    if (mounted) {
      setState(() {
        _isProcessingResult = true;
      });
    }

    try {
      await _controller.stop();
    } catch (_) {}

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(rawValue);
  }

  Future<void> _openGallery() async {
    try {
      final file = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (!mounted || file == null) {
        return;
      }

      setState(() {
        _isProcessingResult = true;
      });

      final rawValue = await _qrDecoderService.decodeFile(file);
      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(rawValue);
    } on QrDecoderException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isProcessingResult = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isProcessingResult = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal membuka galeri atau membaca QR dari gambar.'),
        ),
      );
    }
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
      if (!mounted) {
        return;
      }

      setState(() {
        _isTorchOn = !_isTorchOn;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: MobileScanner(
              controller: _controller,
              onDetect: _handleDetection,
              errorBuilder: (context, error) {
                return Container(
                  color: Colors.black,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.videocam_off_rounded,
                        color: Colors.white,
                        size: 54,
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Kamera belum bisa dibuka.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        error.errorDetails?.message ??
                            'Coba izinkan kamera atau gunakan galeri.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                );
              },
              overlayBuilder: (context, constraints) {
                final width = constraints.maxWidth * 0.72;
                final frameSize = width.clamp(220.0, 320.0).toDouble();

                return Stack(
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.16),
                                Colors.black.withValues(alpha: 0.44),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        width: frameSize,
                        height: frameSize,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.92),
                            width: 2.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.20),
                              blurRadius: 28,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
	                        child: Stack(
	                          children: [
	                            _ScannerBeam(size: frameSize),
	                          ],
	                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (_isStartingCamera)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66000000),
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            ),
          if (_cameraErrorMessage != null)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.78),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.videocam_off_rounded,
                      color: Colors.white,
                      size: 56,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Kamera belum berhasil dimulai.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _cameraErrorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _isStartingCamera = true;
                          _cameraErrorMessage = null;
                        });
                        _startScanner();
                      },
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      Material(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          borderRadius: BorderRadius.circular(18),
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Scan QR GymMaster',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      _buildActionButton(
                        icon: Icons.photo_library_outlined,
                        onTap: _openGallery,
                      ),
                      const Spacer(),
                      _buildActionButton(
                        icon: _isTorchOn
                            ? Icons.flashlight_on_rounded
                            : Icons.flashlight_off_rounded,
                        onTap: _toggleTorch,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_isProcessingResult)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.34),
                  alignment: Alignment.center,
                  child: Container(
                    width: 220,
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.74),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 34,
                          height: 34,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.primary,
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Memproses QR...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Tunggu sebentar, hasil scan sedang disiapkan.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13.5,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

class _ScannerBeam extends StatefulWidget {
  final double size;

  const _ScannerBeam({required this.size});

  @override
  State<_ScannerBeam> createState() => _ScannerBeamState();
}

class _ScannerBeamState extends State<_ScannerBeam>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final travel = (widget.size - 26).clamp(0.0, double.infinity);

        return Positioned(
          left: 18,
          right: 18,
          top: 12 + (_animation.value * travel),
          child: child!,
        );
      },
      child: Container(
        height: 3,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: const LinearGradient(
            colors: [Color(0x0000FFF0), Color(0xFF62FFF0), Color(0x0000FFF0)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF62FFF0).withValues(alpha: 0.85),
              blurRadius: 18,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}
