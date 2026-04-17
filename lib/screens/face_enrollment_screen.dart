import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../models/face_enrollment_result.dart';
import '../services/camera_permission_service.dart';
import '../services/face_quality_service.dart';
import '../services/liveness_step_controller.dart';
import '../theme/app_theme.dart';

class FaceEnrollmentScreen extends StatefulWidget {
  const FaceEnrollmentScreen({super.key});

  @override
  State<FaceEnrollmentScreen> createState() => _FaceEnrollmentScreenState();
}

class _FaceEnrollmentScreenState extends State<FaceEnrollmentScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  static const int _captureCountdownStart = 3;
  static const double _cameraCircleSize = 280;
  final _permissionService = const CameraPermissionService();
  final _qualityService = const FaceQualityService();
  final _screenBrightness = ScreenBrightness();
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableClassification: true,
      enableLandmarks: true,
      minFaceSize: 0.08,
    ),
  );

  CameraController? _cameraController;
  FaceFrameGeometry _geometry = FaceFrameGeometry.empty();
  final LivenessStepController _livenessController = LivenessStepController();
  late LivenessProgress _progress;
  FaceEnrollmentResult? _result;

  bool _isInitializing = true;
  bool _isProcessingFrame = false;
  bool _isCapturing = false;
  bool _isBrightnessBoosted = false;
  bool _isSettingBrightness = false;
  double? _defaultBrightness;
  String? _errorMessage;
  bool _showSettingsAction = false;
  DateTime? _lastProcessedAt;
  Timer? _countdownTimer;
  late final AnimationController _countdownRingController;
  int? _countdownValue;
  String _countdownMessage = 'Tahan posisi, foto akan diambil otomatis.';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _countdownRingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _captureCountdownStart),
    );
    _progress = _livenessController.initialProgress;
    unawaited(_initializeCameraFlow());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelCountdown(shouldRebuild: false);
    unawaited(_restoreBrightness());
    unawaited(_stopCamera());
    _faceDetector.close();
    _countdownRingController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_result != null) {
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _cancelCountdown();
      unawaited(_stopCamera());
      return;
    }

    if (state == AppLifecycleState.resumed && mounted) {
      unawaited(_initializeCameraFlow(restart: true));
    }
  }

  Future<void> _initializeCameraFlow({bool restart = false}) async {
    if (kIsWeb) {
      setState(() {
        _isInitializing = false;
        _errorMessage =
            'Face enrollment ini baru disiapkan untuk Android dan iOS.';
      });
      return;
    }

    if (restart) {
      await _stopCamera();
    }

    setState(() {
      _isInitializing = true;
      _errorMessage = null;
      _showSettingsAction = false;
    });

    final permissionResult = await _permissionService.ensureCameraPermission();
    if (!mounted) {
      return;
    }

    switch (permissionResult) {
      case CameraPermissionResult.granted:
        break;
      case CameraPermissionResult.unsupported:
        setState(() {
          _isInitializing = false;
          _errorMessage =
              'Face enrollment ini baru disiapkan untuk Android dan iOS.';
        });
        return;
      case CameraPermissionResult.denied:
        setState(() {
          _isInitializing = false;
          _errorMessage = 'Akses kamera belum diizinkan.';
        });
        return;
      case CameraPermissionResult.permanentlyDenied:
        setState(() {
          _isInitializing = false;
          _errorMessage = 'Akses kamera diblokir dari sistem.';
          _showSettingsAction = true;
        });
        return;
    }

    try {
      final cameras = await availableCameras();
      if (!mounted) {
        return;
      }

      CameraDescription? frontCamera;
      for (final camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.front) {
          frontCamera = camera;
          break;
        }
      }

      if (frontCamera == null) {
        setState(() {
          _isInitializing = false;
          _errorMessage = 'Kamera depan tidak ditemukan di perangkat ini.';
        });
        return;
      }

      final controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.iOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.nv21,
      );

      await controller.initialize();
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      if (!mounted) {
        await controller.dispose();
        return;
      }

      _cameraController = controller;
      _livenessController.reset();
      _progress = _livenessController.initialProgress;
      _geometry = FaceFrameGeometry.empty();
      _result = null;

      await _startImageStream();

      if (!mounted) {
        return;
      }

      setState(() {
        _isInitializing = false;
      });
    } on CameraException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isInitializing = false;
        _errorMessage = error.description ?? 'Kamera gagal diinisialisasi.';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isInitializing = false;
        _errorMessage = 'Gagal menyiapkan kamera depan untuk verifikasi wajah.';
      });
    }
  }

  Future<void> _startImageStream() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    if (controller.value.isStreamingImages) {
      return;
    }

    await controller.startImageStream((image) {
      final now = DateTime.now();
      if (_isCapturing || _isProcessingFrame) {
        return;
      }
      if (_lastProcessedAt != null &&
          now.difference(_lastProcessedAt!) <
              const Duration(milliseconds: 220)) {
        return;
      }

      _lastProcessedAt = now;
      unawaited(_processCameraImage(image));
    });
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessingFrame || _isCapturing) {
      return;
    }

    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) {
      return;
    }

    _isProcessingFrame = true;
    try {
      final faces = await _faceDetector.processImage(inputImage);
      if (!mounted) {
        return;
      }

      final screenSize = MediaQuery.of(context).size;
      final geometry = _qualityService.inspectFrame(
        faces: faces,
        imageSize: Size(image.width.toDouble(), image.height.toDouble()),
        screenSize: screenSize,
        circleSize: _cameraCircleSize,
      );

      final progress = _livenessController.evaluate(
        geometry: geometry,
        face: faces.isNotEmpty ? geometry.primaryFace : null,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _geometry = geometry;
        _progress = progress;
        _errorMessage = null;
      });

      unawaited(_syncBrightnessForGeometry(geometry));
      _handleAutoCaptureState(geometry, progress);
    } finally {
      _isProcessingFrame = false;
    }
  }

  void _handleAutoCaptureState(FaceFrameGeometry geometry, LivenessProgress progress) {
    if (_isCapturing) {
      return;
    }

    if (!geometry.isFramedWell) {
      _cancelCountdown();
      return;
    }

    if (_countdownValue != null) {
      return;
    }

    if (progress.isCompleted) {
      _startCountdown();
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _countdownValue = _captureCountdownStart;
      _countdownMessage = 'Tahan posisi, foto akan diambil otomatis.';
    });
    _countdownRingController
      ..stop()
      ..reset()
      ..forward();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final current = _countdownValue;
      if (current == null) {
        timer.cancel();
        return;
      }

      if (current <= 1) {
        timer.cancel();
        setState(() {
          _countdownValue = null;
        });
        unawaited(_captureFinalPhoto());
        return;
      }

      setState(() {
        _countdownValue = current - 1;
      });
    });
  }

  void _cancelCountdown({bool shouldRebuild = true}) {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _countdownRingController
      ..stop()
      ..reset();
    if (_countdownValue != null && mounted && shouldRebuild) {
      setState(() {
        _countdownValue = null;
      });
    } else {
      _countdownValue = null;
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final controller = _cameraController;
    if (controller == null) {
      return null;
    }

    InputImageRotation? rotation;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      rotation = InputImageRotationValue.fromRawValue(
        controller.description.sensorOrientation,
      );
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      final orientations = {
        DeviceOrientation.portraitUp: 0,
        DeviceOrientation.landscapeLeft: 90,
        DeviceOrientation.portraitDown: 180,
        DeviceOrientation.landscapeRight: 270,
      };

      var rotationCompensation =
          orientations[controller.value.deviceOrientation];
      if (rotationCompensation == null) {
        return null;
      }

      if (controller.description.lensDirection == CameraLensDirection.front) {
        rotationCompensation =
            (controller.description.sensorOrientation + rotationCompensation) %
            360;
      } else {
        rotationCompensation =
            (controller.description.sensorOrientation -
                rotationCompensation +
                360) %
            360;
      }

      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (rotation == null || format == null) {
      return null;
    }

    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final isiOS = defaultTargetPlatform == TargetPlatform.iOS;
    if ((isAndroid && format != InputImageFormat.nv21) ||
        (isiOS && format != InputImageFormat.bgra8888)) {
      return null;
    }
    if (image.planes.length != 1) {
      return null;
    }

    return InputImage.fromBytes(
      bytes: image.planes.first.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  Future<void> _captureFinalPhoto() async {
    final controller = _cameraController;
    if (_isCapturing || controller == null || !controller.value.isInitialized) {
      return;
    }

    _isCapturing = true;
    _cancelCountdown();
    setState(() {});

    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }

      final photo = await controller.takePicture();
      final assessment = await _qualityService.assessCapturedPhoto(
        imagePath: photo.path,
        detector: _faceDetector,
      );
      final photoBytes = await photo.readAsBytes();

      if (!mounted) {
        return;
      }

      if (!assessment.passes) {
        setState(() {
          _livenessController.reset();
          _progress = _livenessController.initialProgress;
          _geometry = FaceFrameGeometry.empty();
          _errorMessage = assessment.message;
        });
        await _startImageStream();
        return;
      }

      setState(() {
        _errorMessage = null;
        _result = FaceEnrollmentResult(
          imagePath: photo.path,
          imageBytes: photoBytes,
          blurScore: assessment.blurScore,
          brightnessScore: assessment.brightnessScore,
          capturedAt: DateTime.now(),
          qualityLabel: assessment.qualityLabel,
          qualityMessage: assessment.message,
        );
      });
      unawaited(_restoreBrightness());
    } on CameraException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.description ?? 'Gagal mengambil foto final.';
      });
      await _startImageStream();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Foto final belum berhasil diambil. Coba lagi ya.';
      });
      await _startImageStream();
    } finally {
      _isCapturing = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _stopCamera() async {
    final controller = _cameraController;
    _cameraController = null;
    if (controller == null) {
      return;
    }

    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
    } catch (_) {
      // Ignore stream shutdown issues and still dispose the controller.
    }

    await controller.dispose();
  }

  Future<void> _syncBrightnessForGeometry(FaceFrameGeometry geometry) async {
    if (kIsWeb) {
      return;
    }

    final shouldBoost = geometry.faceCount > 0;
    if (shouldBoost == _isBrightnessBoosted || _isSettingBrightness) {
      return;
    }

    _isSettingBrightness = true;
    try {
      _defaultBrightness ??= await _screenBrightness.current;
      if (shouldBoost) {
        await _screenBrightness.setScreenBrightness(1.0);
        _isBrightnessBoosted = true;
      } else {
        await _restoreBrightness();
      }
    } catch (_) {
      // Ignore brightness errors on unsupported devices.
    } finally {
      _isSettingBrightness = false;
    }
  }

  Future<void> _restoreBrightness() async {
    if (kIsWeb) {
      return;
    }

    if (!_isBrightnessBoosted && _defaultBrightness == null) {
      return;
    }

    try {
      if (_defaultBrightness != null) {
        final value = _defaultBrightness!.clamp(0.0, 1.0);
        await _screenBrightness.setScreenBrightness(value);
      } else {
        await _screenBrightness.resetScreenBrightness();
      }
    } catch (_) {
      // Ignore brightness errors on unsupported devices.
    } finally {
      _isBrightnessBoosted = false;
    }
  }

  Future<void> _retakePhoto() async {
    setState(() {
      _result = null;
      _errorMessage = null;
      _geometry = FaceFrameGeometry.empty();
      _livenessController.reset();
      _progress = _livenessController.initialProgress;
    });
    _cancelCountdown();

    await _initializeCameraFlow(restart: true);
  }

  Future<void> _openSettings() async {
    await _permissionService.openSettings();
  }

  @override
  Widget build(BuildContext context) {
    if (_result != null) {
      return _buildPreviewScaffold(context, _result!);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _errorMessage != null && _cameraController == null
            ? _buildErrorState()
            : Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(child: _buildCameraBody()),
                  Positioned.fill(child: _buildGuideFrame()),
                  if (_countdownValue != null)
                    Positioned.fill(child: _buildCountdownOverlay()),
                  Positioned(
                    top: 12,
                    left: 16,
                    right: 16,
                    child: _buildTopBar(),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: _buildBottomPanel(),
                  ),
                  if (_isCapturing)
                    Container(
                      color: Colors.black.withValues(alpha: 0.55),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildCameraBody() {
    final controller = _cameraController;
    if (_isInitializing ||
        controller == null ||
        !controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    final size = MediaQuery.of(context).size;
    var scale = size.aspectRatio * controller.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;

    return Transform.scale(
      scale: scale,
      child: Center(
        child: CameraPreview(controller),
      ),
    );
  }

  Widget _buildGuideFrame() {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _HolePunchPainter(circleSize: _cameraCircleSize),
          ),
          Center(
            child: SizedBox(
              width: _cameraCircleSize + 18,
              height: _cameraCircleSize + 18,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(
                      _cameraCircleSize + 12,
                      _cameraCircleSize + 12,
                    ),
                    painter: _ProgressRingPainter(
                      progress: _progress.completedSteps / 3,
                    ),
                  ),
                  if (_countdownValue != null)
                    AnimatedBuilder(
                      animation: _countdownRingController,
                      builder: (context, child) {
                        final progress = 1 - _countdownRingController.value;
                        return CustomPaint(
                          size: const Size(
                            _cameraCircleSize + 12,
                            _cameraCircleSize + 12,
                          ),
                          painter: _CountdownRingPainter(progress: progress),
                        );
                      },
                    ),
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _geometry.isFramedWell
                        ? const Color(0xFF7EF2BC)
                        : Colors.white.withValues(alpha: 0.88),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.24),
                      blurRadius: 30,
                      spreadRadius: 6,
                    ),
                  ],
                ),
                width: _cameraCircleSize + 6,
                height: _cameraCircleSize + 6,
              ),
            ],
          ),
        ),
      ),
    ],
  ),
);
  }

  Widget _buildCountdownOverlay() {
    return IgnorePointer(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 94,
              height: 94,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.58),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.82),
                  width: 2,
                ),
              ),
              child: Text(
                '$_countdownValue',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.58),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _countdownMessage,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        _buildIconButton(
          icon: Icons.arrow_back_rounded,
          onTap: () => Navigator.of(context).maybePop(),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Text(
            'On-device only',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _progress.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${(_progress.completedSteps / 3 * 100).toInt()}%',
                style: const TextStyle(
                  color: Color(0xFF25B26B),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ??
                (_countdownValue != null
                    ? 'Pose sudah cocok. Tahan dulu sampai countdown selesai.'
                    : _progress.detail),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatusChip('Deteksi', _geometry.faceCount == 1),
              _buildStatusChip('Pose', _geometry.isFramedWell),
              _buildStatusChip(
                'Timer',
                _countdownValue != null || _isCapturing,
              ),
              _buildStatusChip('Analisis', _result != null),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Wajah: ${(100 * _geometry.faceWidthRatio).round()}% lebar frame • Roll ${_geometry.roll.toStringAsFixed(1)}° • Timer: ${_countdownValue ?? '-'}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String title, bool isDone) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDone
            ? const Color(0xFF25B26B)
            : Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        title,
        style: TextStyle(
          color: isDone ? Colors.black : Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.black.withValues(alpha: 0.42),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF151515),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.videocam_off_outlined,
                color: Colors.white,
                size: 52,
              ),
              const SizedBox(height: 16),
              const Text(
                'Kamera belum siap',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _errorMessage ?? 'Ada kendala saat menyiapkan kamera.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.74),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _initializeCameraFlow(),
                  child: const Text('Coba lagi'),
                ),
              ),
              if (_showSettingsAction) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _openSettings,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.30),
                      ),
                    ),
                    child: const Text('Buka pengaturan'),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white.withValues(alpha: 0.74),
                  ),
                  child: const Text('Kembali'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewScaffold(
    BuildContext context,
    FaceEnrollmentResult result,
  ) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F1EE),
      appBar: AppBar(
        title: const Text(
          'Foto final',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: Image.memory(
                  result.imageBytes,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.black12,
                      alignment: Alignment.center,
                      child: const Text('Foto final tidak bisa ditampilkan.'),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ringkasan kualitas',
                    style: TextStyle(
                      color: AppTheme.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildMetricRow(
                    label: 'Status foto',
                    value: result.qualityLabel,
                  ),
                  const SizedBox(height: 10),
                  _buildMetricRow(
                    label: 'Blur score',
                    value: result.blurScore.toStringAsFixed(0),
                  ),
                  const SizedBox(height: 10),
                  _buildMetricRow(
                    label: 'Brightness',
                    value: result.brightnessScore.toStringAsFixed(0),
                  ),
                  const SizedBox(height: 10),
                  _buildMetricRow(
                    label: 'Waktu capture',
                    value:
                        '${result.capturedAt.hour.toString().padLeft(2, '0')}:${result.capturedAt.minute.toString().padLeft(2, '0')}',
                  ),
                  const SizedBox(height: 14),
                  Text(
                    result.qualityMessage,
                    style: TextStyle(
                      color: AppTheme.ink.withValues(alpha: 0.72),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(result),
                child: const Text('Pakai foto ini'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _retakePhoto,
                child: const Text('Ambil ulang'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow({required String label, required String value}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: AppTheme.ink.withValues(alpha: 0.72),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _CountdownRingPainter extends CustomPainter {
  final double progress;

  const _CountdownRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - 3;
    final basePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    final progressPaint = Paint()
      ..color = AppTheme.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, basePaint);

    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    if (sweep > 0.0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweep,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CountdownRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _HolePunchPainter extends CustomPainter {
  final double circleSize;

  const _HolePunchPainter({required this.circleSize});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2),
        radius: circleSize / 2,
      ));
    path.fillType = PathFillType.evenOdd;
    canvas.drawPath(
      path,
      Paint()..color = Colors.black.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(covariant _HolePunchPainter oldDelegate) {
    return oldDelegate.circleSize != circleSize;
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double progress;

  const _ProgressRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - 3;
    final progressPaint = Paint()
      ..color = const Color(0xFF25B26B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    if (sweep > 0.0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweep,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
