import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'face_quality_service.dart';

enum LivenessStep { blink, turnLeft, turnRight }

enum TurnSide { positiveYaw, negativeYaw }

class LivenessProgress {
  final LivenessStep currentStep;
  final int completedSteps;
  final bool isCompleted;
  final String title;
  final String detail;

  const LivenessProgress({
    required this.currentStep,
    required this.completedSteps,
    required this.isCompleted,
    required this.title,
    required this.detail,
  });
}

class LivenessStepController {
  final Duration holdDuration;
  final Duration blinkResetDuration;
  static const List<LivenessStep> _steps = [
    LivenessStep.blink,
    LivenessStep.turnLeft,
    LivenessStep.turnRight,
  ];

  int _currentIndex = 0;
  DateTime? _conditionStartedAt;
  DateTime? _blinkDetectedAt;

  LivenessStepController({
    this.holdDuration = const Duration(milliseconds: 650),
    this.blinkResetDuration = const Duration(milliseconds: 900),
  });

  void reset() {
    _currentIndex = 0;
    _conditionStartedAt = null;
    _blinkDetectedAt = null;
  }

  bool get isCompleted => _currentIndex >= _steps.length;

  LivenessProgress get initialProgress {
    return const LivenessProgress(
      currentStep: LivenessStep.blink,
      completedSteps: 0,
      isCompleted: false,
      title: 'Kedip sekali',
      detail: 'Kedipkan mata untuk mulai verifikasi.',
    );
  }

  LivenessProgress evaluate({
    required FaceFrameGeometry geometry,
    Face? face,
    DateTime? now,
  }) {
    if (_currentIndex >= _steps.length) {
      return const LivenessProgress(
        currentStep: LivenessStep.turnRight,
        completedSteps: 3,
        isCompleted: true,
        title: 'Foto siap diambil',
        detail: 'Bagus, tahan sebentar. Aku ambil foto final sekarang.',
      );
    }

    final timestamp = now ?? DateTime.now();
    final step = _steps[_currentIndex];

    if (!geometry.isFramedWell || face == null) {
      _conditionStartedAt = null;
      return LivenessProgress(
        currentStep: step,
        completedSteps: _currentIndex,
        isCompleted: false,
        title: _titleFor(step),
        detail: geometry.guidance,
      );
    }

    final satisfied = _isStepSatisfied(step, face);
    if (!satisfied) {
      _conditionStartedAt = null;
      return LivenessProgress(
        currentStep: step,
        completedSteps: _currentIndex,
        isCompleted: false,
        title: _titleFor(step),
        detail: _detailFor(step),
      );
    }

    _conditionStartedAt ??= timestamp;
    final heldLongEnough =
        timestamp.difference(_conditionStartedAt!) >= holdDuration;
    if (!heldLongEnough) {
      return LivenessProgress(
        currentStep: step,
        completedSteps: _currentIndex,
        isCompleted: false,
        title: _titleFor(step),
        detail: 'Pertahankan pose ini sebentar...',
      );
    }

    _currentIndex++;
    _conditionStartedAt = null;

    if (_currentIndex >= _steps.length) {
      return const LivenessProgress(
        currentStep: LivenessStep.turnRight,
        completedSteps: 3,
        isCompleted: true,
        title: 'Foto siap diambil',
        detail: 'Bagus, tahan sebentar. Aku ambil foto final sekarang.',
      );
    }

    final nextStep = _steps[_currentIndex];
    return LivenessProgress(
      currentStep: nextStep,
      completedSteps: _currentIndex,
      isCompleted: false,
      title: _titleFor(nextStep),
      detail: _detailFor(nextStep),
    );
  }

  bool _isStepSatisfied(LivenessStep step, Face face) {
    final yaw = (face.headEulerAngleY ?? 0).toDouble();
    final leftEye = face.leftEyeOpenProbability;
    final rightEye = face.rightEyeOpenProbability;

    switch (step) {
      case LivenessStep.blink:
        if (leftEye == null || rightEye == null) {
          return false;
        }
        final eyesClosed = leftEye < 0.25 && rightEye < 0.25;
        if (eyesClosed) {
          _blinkDetectedAt ??= DateTime.now();
          return true;
        }
        if (_blinkDetectedAt != null &&
            DateTime.now().difference(_blinkDetectedAt!) <=
                blinkResetDuration) {
          return true;
        }
        _blinkDetectedAt = null;
        return false;
      case LivenessStep.turnLeft:
        return yaw <= -18;
      case LivenessStep.turnRight:
        return yaw >= 18;
    }
  }

  String _titleFor(LivenessStep step) {
    switch (step) {
      case LivenessStep.blink:
        return 'Kedip sekali';
      case LivenessStep.turnLeft:
        return 'Putar ke kiri';
      case LivenessStep.turnRight:
        return 'Putar ke kanan';
    }
  }

  String _detailFor(LivenessStep step) {
    switch (step) {
      case LivenessStep.blink:
        return 'Kedipkan mata sekali untuk memulai.';
      case LivenessStep.turnLeft:
        return 'Palingkan wajah ke kiri sampai jelas.';
      case LivenessStep.turnRight:
        return 'Bagus, sekarang palingkan ke kanan.';
    }
  }
}
