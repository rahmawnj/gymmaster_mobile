import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../models/face_enrollment_result.dart';
import '../services/camera_permission_service.dart';
import '../services/face_quality_service.dart';
import '../theme/app_theme.dart';

class FaceEnrollmentScreen extends StatefulWidget {
  const FaceEnrollmentScreen({super.key});

  @override
  State<FaceEnrollmentScreen> createState() => _FaceEnrollmentScreenState();
}

class _FaceEnrollmentScreenState extends State<FaceEnrollmentScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  static const int _captureCountdownStart = 3;
  static const int _readinessStepCount = 5;
  static const double _cameraGuideWidth = 270;
  static const double _cameraGuideHeight = 340;
  static const int _requiredStableFrames = 3;
  final _permissionService = const CameraPermissionService();
  final _qualityService = const FaceQualityService();
  final _screenBrightness = ScreenBrightness();
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableClassification: true,
      enableContours: true,
      enableLandmarks: true,
      minFaceSize: 0.08,
    ),
  );

  CameraController? _cameraController;
  FaceFrameGeometry _geometry = FaceFrameGeometry.empty();
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
  Offset? _lastStableFaceCenter;
  double? _lastStableFaceWidthRatio;
  double? _lastStableFaceHeightRatio;
  Size? _latestFrameImageSize;
  InputImageRotation? _latestFrameRotation;
  double? _previewBlurScore;
  int _stableFrameCount = 0;
  bool _hasBlinked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _countdownRingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _captureCountdownStart),
    );
    unawaited(_initializeCameraFlow());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelCountdown(shouldRebuild: false);
    unawaited(_restoreBrightness());
    unawaited(_stopCamera(detachPreview: false));
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
      _geometry = FaceFrameGeometry.empty();
      _resetStabilityState();
      _result = null;

      await _startImageStream();

      if (!mounted) {
        return;
      }

      unawaited(_boostBrightness());

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
        imageRotation: _latestFrameRotation ?? InputImageRotation.rotation0deg,
        screenSize: screenSize,
        guideSize: const Size(_cameraGuideWidth, _cameraGuideHeight),
      );
      _updateStabilityState(geometry);
      final previewBlurScore = _estimatePreviewBlurScore(image, geometry);

      if (!mounted) {
        return;
      }

      setState(() {
        _geometry = geometry;
        _latestFrameImageSize = Size(
          image.width.toDouble(),
          image.height.toDouble(),
        );
        _previewBlurScore = previewBlurScore;
        _errorMessage = null;
      });

      unawaited(_boostBrightness());
      _handleAutoCaptureState(geometry);
    } finally {
      _isProcessingFrame = false;
    }
  }

  void _updateStabilityState(FaceFrameGeometry geometry) {
    final face = geometry.primaryFace;
    if (face == null || !geometry.isReadyForFinalCapture) {
      _resetStabilityState();
      return;
    }

    final faceCenter = face.boundingBox.center;
    final widthRatio = geometry.faceWidthRatio;
    final heightRatio = geometry.faceHeightRatio;

    if (_lastStableFaceCenter == null ||
        _lastStableFaceWidthRatio == null ||
        _lastStableFaceHeightRatio == null) {
      _lastStableFaceCenter = faceCenter;
      _lastStableFaceWidthRatio = widthRatio;
      _lastStableFaceHeightRatio = heightRatio;
      _stableFrameCount = 1;
      return;
    }

    final movement = (faceCenter - _lastStableFaceCenter!).distance;
    final widthDelta = (widthRatio - _lastStableFaceWidthRatio!).abs();
    final heightDelta = (heightRatio - _lastStableFaceHeightRatio!).abs();
    final isStableNow =
        movement <= 18 && widthDelta <= 0.035 && heightDelta <= 0.04;

    _lastStableFaceCenter = faceCenter;
    _lastStableFaceWidthRatio = widthRatio;
    _lastStableFaceHeightRatio = heightRatio;

    if (isStableNow) {
      final nextStableCount = _stableFrameCount + 1;
      _stableFrameCount = nextStableCount > _requiredStableFrames
          ? _requiredStableFrames
          : nextStableCount;
    } else {
      _stableFrameCount = 1;
    }
  }

  void _resetStabilityState() {
    _lastStableFaceCenter = null;
    _lastStableFaceWidthRatio = null;
    _lastStableFaceHeightRatio = null;
    _previewBlurScore = null;
    _stableFrameCount = 0;
  }

  bool get _isFaceStable => _stableFrameCount >= _requiredStableFrames;

  bool get _isFaceInsideOval =>
      _geometry.isSingleFace && _geometry.isInsideGuide;

  bool get _isPreviewSharpEnough =>
      _previewBlurScore == null ||
      _previewBlurScore! >= FaceQualityService.minPreviewBlurScore;

  bool get _isReadyForCountdown =>
      _geometry.isReadyForFinalCapture &&
      _isFaceStable &&
      _isPreviewSharpEnough;

  int get _completedChecklistCount {
    if (!_isFaceInsideOval) {
      return 0;
    }

    var count = 1;
    if (_geometry.isFramedWell) {
      count = 2;
    }
    if (_geometry.isReadyForFinalCapture) {
      count = 3;
    }
    if (_isFaceStable) {
      count = 4;
    }
    if (_isFaceStable &&
        _geometry.isReadyForFinalCapture &&
        _isPreviewSharpEnough) {
      count = 5;
    }
    return count;
  }

  double get _readinessProgress =>
      _completedChecklistCount / _readinessStepCount;

  String _formatDegreeRange(double limit) {
    final rounded = limit.round();
    return '-$rounded° s/d $rounded°';
  }

  Color get _guideFrameColor {
    if (_countdownValue != null || _isCapturing) {
      return const Color(0xFF7EF2BC);
    }
    if (_isReadyForCountdown) {
      return const Color(0xFF7EF2BC);
    }
    if (_geometry.faceCount == 0) {
      return Colors.white.withValues(alpha: 0.88);
    }
    if (_geometry.faceCount > 1) {
      return const Color(0xFFFF8A65);
    }
    if (!_isFaceInsideOval) {
      return Colors.white.withValues(alpha: 0.88);
    }
    if (!_geometry.isFramedWell) {
      return const Color(0xFFFF8A65);
    }
    if (_previewBlurScore != null && !_isPreviewSharpEnough) {
      return const Color(0xFFFFC857);
    }

    return const Color(0xFFFF8A65);
  }



  void _handleAutoCaptureState(FaceFrameGeometry geometry) {
    if (_isCapturing) {
      return;
    }

    if (!geometry.isReadyForFinalCapture ||
        !_isFaceStable ||
        !_isPreviewSharpEnough) {
      _cancelCountdown();
      _hasBlinked = false;
      return;
    }

    if (!_hasBlinked) {
      final face = geometry.primaryFace;
      if (face != null) {
        final leftEyeOpen = face.leftEyeOpenProbability ?? 1.0;
        final rightEyeOpen = face.rightEyeOpenProbability ?? 1.0;
        // Require both eyes to be closed/squinted (< 0.25) simultaneously to count as a blink
        if (leftEyeOpen < 0.25 && rightEyeOpen < 0.25) {
          _hasBlinked = true;
          // Trigger rebuild to update UI immediately
          if (mounted) setState(() {});
        }
      }
      return; // Wait until they blink
    }

    if (_countdownValue != null) {
      return;
    }

    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownRingController
      ..stop()
      ..reset()
      ..forward();
      
    setState(() {
      _countdownValue = _captureCountdownStart;
      _countdownMessage = 'Wajah sudah pas. Tahan posisi...';
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_countdownValue != null && _countdownValue! > 1) {
        setState(() {
          _countdownValue = _countdownValue! - 1;
        });
      } else {
        timer.cancel();
        setState(() {
          _countdownValue = null;
          _countdownMessage = 'Mengambil foto...';
        });
        unawaited(_captureFinalPhoto());
      }
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

  double? _estimatePreviewBlurScore(
    CameraImage image,
    FaceFrameGeometry geometry,
  ) {
    final face = geometry.primaryFace;
    if (face == null || !geometry.isReadyForFinalCapture) {
      return null;
    }

    return _qualityService.estimatePreviewBlurScore(
      image: image,
      faceBounds: face.boundingBox,
    );
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
    _latestFrameRotation = rotation;

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
          _geometry = FaceFrameGeometry.empty();
          _resetStabilityState();
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

  Future<void> _stopCamera({bool detachPreview = true}) async {
    final controller = _cameraController;
    if (detachPreview && mounted && controller != null) {
      setState(() {
        _cameraController = null;
      });
      await Future<void>.delayed(Duration.zero);
    } else {
      _cameraController = null;
    }
    _resetStabilityState();
    _latestFrameImageSize = null;
    _latestFrameRotation = null;
    _lastProcessedAt = null;
    _isProcessingFrame = false;
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

  Future<void> _boostBrightness() async {
    if (kIsWeb) {
      return;
    }

    if (_isBrightnessBoosted || _isSettingBrightness) {
      return;
    }

    _isSettingBrightness = true;
    try {
      _defaultBrightness ??= await _screenBrightness.application;
      await _screenBrightness.setApplicationScreenBrightness(1.0);
      _isBrightnessBoosted = true;
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
        await _screenBrightness.setApplicationScreenBrightness(value);
      } else {
        await _screenBrightness.resetApplicationScreenBrightness();
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
      _resetStabilityState();
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
                  Positioned.fill(child: _buildFaceContourOverlay()),
                  if (_countdownValue != null || (!_hasBlinked && _isReadyForCountdown))
                    Positioned.fill(child: _buildCenterOverlay()),
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
      child: Center(child: CameraPreview(controller)),
    );
  }

  Widget _buildFaceContourOverlay() {
    final controller = _cameraController;
    final face = _geometry.primaryFace;
    final imageSize = _latestFrameImageSize;
    final imageRotation = _latestFrameRotation;
    if (_isInitializing ||
        controller == null ||
        !controller.value.isInitialized ||
        face == null ||
        imageSize == null ||
        imageRotation == null) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: CustomPaint(
        painter: _FaceContourOverlayPainter(
          face: face,
          imageSize: imageSize,
          imageRotation: imageRotation,
          mirrorHorizontally:
              controller.description.lensDirection == CameraLensDirection.front,
          accentColor: _guideFrameColor,
        ),
      ),
    );
  }

  Widget _buildGuideFrame() {
    const guideSize = Size(_cameraGuideWidth, _cameraGuideHeight);

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _HolePunchPainter(guideSize: guideSize)),
          Center(
            child: SizedBox(
              width: guideSize.width + 28,
              height: guideSize.height + 42,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: guideSize.width + 24,
                    height: guideSize.height + 24,
                    child: CustomPaint(
                      painter: _GuideProgressPainter(
                        progress: _readinessProgress,
                        color: _guideFrameColor,
                      ),
                    ),
                  ),
                  if (_countdownValue != null)
                    SizedBox(
                      width: guideSize.width + 24,
                      height: guideSize.height + 24,
                      child: AnimatedBuilder(
                        animation: _countdownRingController,
                        builder: (context, child) {
                          final progress = 1 - _countdownRingController.value;
                          return CustomPaint(
                            painter: _GuideProgressPainter(
                              progress: progress,
                              color: AppTheme.primary,
                              strokeWidth: 6,
                            ),
                          );
                        },
                      ),
                    ),
                  SizedBox(
                    width: guideSize.width + 8,
                    height: guideSize.height + 8,
                    child: CustomPaint(
                      painter: _GuideOutlinePainter(
                        color: _guideFrameColor,
                        isLocked:
                            _countdownValue != null || _isReadyForCountdown,
                      ),
                    ),
                  ),
                  Positioned(top: 0, child: _buildGuideLabel()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideLabel() {
    final ready = _countdownValue != null || _isReadyForCountdown;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: ready
            ? const Color(0xFF173828).withValues(alpha: 0.92)
            : Colors.black.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: ready
              ? const Color(0xFF7EF2BC).withValues(alpha: 0.65)
              : Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: Text(
        ready
            ? 'Range aman, auto capture'
            : 'Pastikan wajah masuk penuh ke oval',
        style: TextStyle(
          color: ready ? const Color(0xFF7EF2BC) : Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
        ),
      ),
    );
  }

  Widget _buildCenterOverlay() {
    final showTimer = _countdownValue != null;
    final message = showTimer
        ? _countdownMessage
        : 'Wajah terkunci.\nSekarang KEDIPKAN KEDUA MATA ANDA\nuntuk membuktikan Anda bukan layar HP.';

    return IgnorePointer(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showTimer)
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
            if (showTimer) const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: showTimer
                    ? Colors.black.withValues(alpha: 0.58)
                    : const Color(0xFFE53935).withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  if (!showTimer)
                    BoxShadow(
                      color: const Color(0xFFE53935).withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                ],
              ),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.98),
                  fontWeight: FontWeight.w800,
                  fontSize: showTimer ? 14 : 16,
                  height: 1.4,
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
      child: _buildStatusPanel(),
    );
  }

  Widget _buildStatusPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Status wajah live',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.92),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildStatusCard(
                icon: Icons.compress_rounded,
                title: 'Jarak',
                subtitle: 'Dekat / Jauh',
                valueText: '${(_geometry.faceWidthRatio * 100).round()}%',
                isAligned: _geometry.isLargeEnough && !_geometry.isTooLarge,
                alignedLabel: 'Aman',
                warningLabel: _geometry.isTooLarge ? 'Mundur sedikit' : 'Terlalu jauh',
                safeRange: FaceQualityService.formatRatioRange(
                  FaceQualityService.minFaceWidthRatio,
                  FaceQualityService.maxFaceWidthRatio,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatusCard(
                icon: Icons.swap_horiz_rounded,
                title: 'Yaw',
                subtitle: 'Kiri / Kanan',
                valueText: '${_geometry.yaw.toStringAsFixed(1)}°',
                isAligned: _geometry.hasNeutralYaw,
                alignedLabel: 'Aman',
                warningLabel: 'Tengok lurus',
                safeRange: _formatDegreeRange(
                  FaceQualityService.maxNeutralYawDegrees,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatusCard(
                icon: Icons.swap_vert_rounded,
                title: 'Pitch',
                subtitle: 'Naik / Turun',
                valueText: '${_geometry.pitch.toStringAsFixed(1)}°',
                isAligned: _geometry.hasNeutralPitch,
                alignedLabel: 'Aman',
                warningLabel: 'Dagu sejajar',
                safeRange: _formatDegreeRange(
                  FaceQualityService.maxNeutralPitchDegrees,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatusCard(
                icon: Icons.screen_rotation_alt_rounded,
                title: 'Roll',
                subtitle: 'Miring',
                valueText: '${_geometry.roll.toStringAsFixed(1)}°',
                isAligned: _geometry.hasAcceptableRoll,
                alignedLabel: 'Aman',
                warningLabel: 'Terlalu miring',
                safeRange: _formatDegreeRange(
                  FaceQualityService.maxAcceptableRollDegrees,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String valueText,
    required bool isAligned,
    required String alignedLabel,
    required String warningLabel,
    required String safeRange,
  }) {
    final accentColor = isAligned
        ? const Color(0xFF25B26B)
        : const Color(0xFFFFB14A);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accentColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            valueText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            isAligned ? alignedLabel : warningLabel,
            style: TextStyle(
              color: accentColor,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            safeRange,
            style: TextStyle(
              color: accentColor.withValues(alpha: 0.92),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 9.5,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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

class _HolePunchPainter extends CustomPainter {
  final Size guideSize;

  const _HolePunchPainter({required this.guideSize});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(
        Rect.fromCenter(
          center: Offset(size.width / 2, size.height / 2),
          width: guideSize.width,
          height: guideSize.height,
        ),
      );
    path.fillType = PathFillType.evenOdd;
    canvas.drawPath(
      path,
      Paint()..color = Colors.black.withValues(alpha: 0.80),
    );
  }

  @override
  bool shouldRepaint(covariant _HolePunchPainter oldDelegate) {
    return oldDelegate.guideSize != guideSize;
  }
}

class _GuideProgressPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color color;

  const _GuideProgressPainter({
    required this.progress,
    required this.color,
    this.strokeWidth = 5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    if (sweep > 0.0) {
      canvas.drawArc(
        Rect.fromLTWH(
          strokeWidth,
          strokeWidth,
          size.width - (strokeWidth * 2),
          size.height - (strokeWidth * 2),
        ),
        -math.pi / 2,
        sweep,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GuideProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.color != color;
  }
}

class _GuideOutlinePainter extends CustomPainter {
  final Color color;
  final bool isLocked;

  const _GuideOutlinePainter({required this.color, required this.isLocked});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(4, 4, size.width - 8, size.height - 8);
    final glowPaint = Paint()
      ..color = color.withValues(alpha: isLocked ? 0.26 : 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isLocked ? 8 : 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = isLocked ? 3.6 : 3;
    final innerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawOval(rect, glowPaint);
    canvas.drawOval(rect, borderPaint);
    canvas.drawOval(rect.deflate(10), innerPaint);

    final markerPaint = Paint()
      ..color = color.withValues(alpha: 0.84)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final markerWidth = size.width * 0.14;
    final markerHeight = size.height * 0.10;

    canvas.drawArc(
      Rect.fromLTWH(12, 18, markerWidth, markerHeight),
      math.pi,
      math.pi / 2,
      false,
      markerPaint,
    );
    canvas.drawArc(
      Rect.fromLTWH(
        size.width - markerWidth - 12,
        18,
        markerWidth,
        markerHeight,
      ),
      -math.pi / 2,
      math.pi / 2,
      false,
      markerPaint,
    );
    canvas.drawArc(
      Rect.fromLTWH(
        12,
        size.height - markerHeight - 18,
        markerWidth,
        markerHeight,
      ),
      math.pi / 2,
      math.pi / 2,
      false,
      markerPaint,
    );
    canvas.drawArc(
      Rect.fromLTWH(
        size.width - markerWidth - 12,
        size.height - markerHeight - 18,
        markerWidth,
        markerHeight,
      ),
      0,
      math.pi / 2,
      false,
      markerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GuideOutlinePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isLocked != isLocked;
  }
}

class _FaceContourOverlayPainter extends CustomPainter {
  final Face face;
  final Size imageSize;
  final InputImageRotation imageRotation;
  final bool mirrorHorizontally;
  final Color accentColor;

  const _FaceContourOverlayPainter({
    required this.face,
    required this.imageSize,
    required this.imageRotation,
    required this.mirrorHorizontally,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (imageSize.width <= 0 || imageSize.height <= 0) {
      return;
    }

    final boxPaint = Paint()
      ..color = const Color(0xFFFF4B4B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    final linePaint = Paint()
      ..color = accentColor.withValues(alpha: 0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final pointPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.86)
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4;

    canvas.drawRect(_mapImageRectToCanvas(face.boundingBox, size), boxPaint);

    for (final contour in face.contours.values) {
      final points = contour?.points;
      if (points == null || points.isEmpty) {
        continue;
      }

      final canvasPoints = points
          .map(
            (point) => _mapImagePointToCanvas(
              point.x.toDouble(),
              point.y.toDouble(),
              size,
            ),
          )
          .toList(growable: false);
      if (canvasPoints.length < 2) {
        continue;
      }

      final path = Path()..moveTo(canvasPoints.first.dx, canvasPoints.first.dy);
      for (var i = 1; i < canvasPoints.length; i++) {
        path.lineTo(canvasPoints[i].dx, canvasPoints[i].dy);
      }
      if (contour!.type == FaceContourType.face ||
          contour.type == FaceContourType.leftEye ||
          contour.type == FaceContourType.rightEye ||
          contour.type == FaceContourType.upperLipTop ||
          contour.type == FaceContourType.lowerLipBottom) {
        path.close();
      }

      canvas.drawPath(path, linePaint);
      canvas.drawPoints(PointMode.points, canvasPoints, pointPaint);
    }
  }

  Rect _mapImageRectToCanvas(Rect rect, Size canvasSize) {
    final mappedPoints = [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ].map((point) => _mapImagePointToCanvas(point.dx, point.dy, canvasSize));
    final minX = mappedPoints.map((point) => point.dx).reduce(math.min);
    final maxX = mappedPoints.map((point) => point.dx).reduce(math.max);
    final minY = mappedPoints.map((point) => point.dy).reduce(math.min);
    final maxY = mappedPoints.map((point) => point.dy).reduce(math.max);
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  Offset _mapImagePointToCanvas(double x, double y, Size canvasSize) {
    final rotatedImageSize = _rotatedImageSize();
    final scale = math.max(
      canvasSize.width / rotatedImageSize.width,
      canvasSize.height / rotatedImageSize.height,
    );
    final drawnWidth = rotatedImageSize.width * scale;
    final drawnHeight = rotatedImageSize.height * scale;
    final dx = (canvasSize.width - drawnWidth) / 2;
    final dy = (canvasSize.height - drawnHeight) / 2;
    final mappedX = mirrorHorizontally
        ? dx + drawnWidth - (x * scale)
        : dx + (x * scale);
    final mappedY = dy + (y * scale);
    return Offset(mappedX, mappedY);
  }

  Size _rotatedImageSize() {
    switch (imageRotation) {
      case InputImageRotation.rotation90deg:
      case InputImageRotation.rotation270deg:
        return Size(imageSize.height, imageSize.width);
      case InputImageRotation.rotation0deg:
      case InputImageRotation.rotation180deg:
        return imageSize;
    }
  }

  @override
  bool shouldRepaint(covariant _FaceContourOverlayPainter oldDelegate) {
    return oldDelegate.face != face ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.imageRotation != imageRotation ||
        oldDelegate.mirrorHorizontally != mirrorHorizontally ||
        oldDelegate.accentColor != accentColor;
  }
}
