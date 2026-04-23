import 'dart:math' as math;
import 'dart:ui' show Rect, Size, Offset;

import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

class FaceFrameGeometry {
  final int faceCount;
  final Face? primaryFace;
  final bool isSingleFace;
  final bool isInsideGuide;
  final bool isCentered;
  final bool isLargeEnough;
  final bool isTooLarge;
  final bool hasAcceptableRoll;
  final double yaw;
  final double pitch;
  final double roll;
  final double faceWidthRatio;
  final double faceHeightRatio;

  const FaceFrameGeometry({
    required this.faceCount,
    required this.primaryFace,
    required this.isSingleFace,
    required this.isInsideGuide,
    required this.isCentered,
    required this.isLargeEnough,
    required this.isTooLarge,
    required this.hasAcceptableRoll,
    required this.yaw,
    required this.pitch,
    required this.roll,
    required this.faceWidthRatio,
    required this.faceHeightRatio,
  });

  factory FaceFrameGeometry.empty() {
    return const FaceFrameGeometry(
      faceCount: 0,
      primaryFace: null,
      isSingleFace: false,
      isInsideGuide: false,
      isCentered: false,
      isLargeEnough: false,
      isTooLarge: false,
      hasAcceptableRoll: true,
      yaw: 0,
      pitch: 0,
      roll: 0,
      faceWidthRatio: 0,
      faceHeightRatio: 0,
    );
  }

  bool get isFramedWell {
    return isSingleFace &&
        isInsideGuide &&
        isCentered &&
        isLargeEnough &&
        !isTooLarge &&
        hasAcceptableRoll;
  }

  bool get hasNeutralYaw => yaw.abs() <= FaceQualityService.maxNeutralYawDegrees;

  bool get hasNeutralPitch =>
      pitch.abs() <= FaceQualityService.maxNeutralPitchDegrees;

  bool get isReadyForFinalCapture {
    return isFramedWell && hasNeutralYaw && hasNeutralPitch;
  }

  String get guidance {
    if (faceCount == 0) {
      return 'Arahkan wajah ke dalam frame.';
    }
    if (faceCount > 1) {
      return 'Pastikan hanya satu wajah yang terlihat.';
    }
    if (!isInsideGuide) {
      return 'Pastikan wajah masuk ke area oval.';
    }
    if (isTooLarge) {
      return 'Wajah terlalu dekat. Jauhkan sedikit dari kamera.';
    }
    if (!isLargeEnough) {
      return 'Dekatkan wajah sedikit ke kamera.';
    }
    if (!isCentered) {
      return 'Geser wajah ke area tengah frame.';
    }
    if (!hasAcceptableRoll) {
      return 'Luruskan kepala supaya tidak terlalu miring.';
    }

    return 'Posisi wajah sudah pas.';
  }

  String get finalCaptureGuidance {
    if (!isFramedWell) {
      return guidance;
    }
    if (!hasNeutralYaw) {
      return 'Hadapkan wajah lurus ke depan untuk foto final.';
    }
    if (!hasNeutralPitch) {
      return 'Posisikan dagu sejajar dengan frame oval.';
    }

    return 'Posisi wajah sudah siap diambil.';
  }
}

class FaceCaptureAssessment {
  final bool passes;
  final String message;
  final double blurScore;
  final double brightnessScore;
  final String qualityLabel;

  const FaceCaptureAssessment({
    required this.passes,
    required this.message,
    required this.blurScore,
    required this.brightnessScore,
    required this.qualityLabel,
  });
}

class FaceQualityService {
  static const double maxNeutralYawDegrees = 10;
  static const double maxNeutralPitchDegrees = 12;
  static const double _minFaceWidthRatio = 0.18;
  static const double _minFaceHeightRatio = 0.22;
  static const double _maxFaceWidthRatio = 0.60;
  static const double _maxFaceHeightRatio = 0.72;
  static const double _centerToleranceX = 0.22;
  static const double _centerToleranceY = 0.24;
  static const double _maxRollDegrees = 18;
  static const double _minBlurScore = 180;
  static const double _minBrightness = 70;
  static const double _maxBrightness = 195;

  const FaceQualityService();

  FaceFrameGeometry inspectFrame({
    required List<Face> faces,
    required Size imageSize,
    required Size screenSize,
    required Size guideSize,
  }) {
    if (faces.isEmpty) {
      return FaceFrameGeometry.empty();
    }

    final sortedFaces = [...faces]
      ..sort((a, b) {
        final aArea = a.boundingBox.width * a.boundingBox.height;
        final bArea = b.boundingBox.width * b.boundingBox.height;
        return bArea.compareTo(aArea);
      });

    final primaryFace = sortedFaces.first;
    final faceBounds = primaryFace.boundingBox;

    // scale factor for BoxFit.cover
    final scaleX = screenSize.width / imageSize.width;
    final scaleY = screenSize.height / imageSize.height;
    final scale = math.max(scaleX, scaleY);

    // image center
    final centerX = imageSize.width / 2;
    final centerY = imageSize.height / 2;

    // circle bounds in image coordinates
    final guideRect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: guideSize.width / scale,
      height: guideSize.height / scale,
    );

    final faceWidthRatio = faceBounds.width / guideRect.width;
    final faceHeightRatio = faceBounds.height / guideRect.height;

    final normalizedCenterX =
        (faceBounds.center.dx - guideRect.left) / guideRect.width;
    final normalizedCenterY =
        (faceBounds.center.dy - guideRect.top) / guideRect.height;
    final centerDeltaX = ((normalizedCenterX - 0.5).abs() * 2);
    final centerDeltaY = ((normalizedCenterY - 0.5).abs() * 2);
    final isInsideGuide =
        (centerDeltaX * centerDeltaX) + (centerDeltaY * centerDeltaY) <= 0.92;

    final roll = (primaryFace.headEulerAngleZ ?? 0).toDouble();
    final yaw = (primaryFace.headEulerAngleY ?? 0).toDouble();
    final pitch = (primaryFace.headEulerAngleX ?? 0).toDouble();

    final isCentered =
        (normalizedCenterX - 0.5).abs() <= _centerToleranceX &&
        (normalizedCenterY - 0.5).abs() <= _centerToleranceY;
    final isTooLarge =
        faceWidthRatio > _maxFaceWidthRatio ||
        faceHeightRatio > _maxFaceHeightRatio;
    final isLargeEnough =
        faceWidthRatio >= _minFaceWidthRatio &&
        faceHeightRatio >= _minFaceHeightRatio;
    final hasAcceptableRoll = roll.abs() <= _maxRollDegrees;

    return FaceFrameGeometry(
      faceCount: faces.length,
      primaryFace: primaryFace,
      isSingleFace: faces.length == 1,
      isInsideGuide: isInsideGuide,
      isCentered: isCentered,
      isLargeEnough: isLargeEnough,
      isTooLarge: isTooLarge,
      hasAcceptableRoll: hasAcceptableRoll,
      yaw: yaw,
      pitch: pitch,
      roll: roll,
      faceWidthRatio: faceWidthRatio,
      faceHeightRatio: faceHeightRatio,
    );
  }

  Future<FaceCaptureAssessment> assessCapturedPhoto({
    required String imagePath,
    required FaceDetector detector,
  }) async {
    final faces = await detector.processImage(InputImage.fromFilePath(imagePath));
    if (faces.isEmpty) {
      return const FaceCaptureAssessment(
        passes: false,
        message: 'Wajah tidak terdeteksi di foto final. Coba ulangi sekali lagi.',
        blurScore: 0,
        brightnessScore: 0,
        qualityLabel: 'Belum valid',
      );
    }
    if (faces.length > 1) {
      return const FaceCaptureAssessment(
        passes: false,
        message: 'Foto final memuat lebih dari satu wajah. Coba ambil ulang.',
        blurScore: 0,
        brightnessScore: 0,
        qualityLabel: 'Belum valid',
      );
    }

    final bytes = await XFile(imagePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return const FaceCaptureAssessment(
        passes: false,
        message: 'Foto final tidak bisa dibaca. Coba ulang lagi.',
        blurScore: 0,
        brightnessScore: 0,
        qualityLabel: 'Belum valid',
      );
    }

    final faceBounds = faces.single.boundingBox;
    final cropRect = _expandedCrop(
      bounds: faceBounds,
      imageWidth: decoded.width,
      imageHeight: decoded.height,
    );

    final cropped = img.copyCrop(
      decoded,
      x: cropRect.left.toInt(),
      y: cropRect.top.toInt(),
      width: cropRect.width.toInt(),
      height: cropRect.height.toInt(),
    );
    final grayscale = img.grayscale(
      img.copyResize(
        cropped,
        width: math.min(cropped.width, 220),
      ),
    );

    final blurScore = _calculateBlurScore(grayscale);
    final brightnessScore = _calculateBrightnessScore(grayscale);

    if (blurScore < _minBlurScore) {
      return FaceCaptureAssessment(
        passes: false,
        message: 'Foto masih agak blur. Tahan HP sebentar lalu coba lagi.',
        blurScore: blurScore,
        brightnessScore: brightnessScore,
        qualityLabel: 'Kurang tajam',
      );
    }
    if (brightnessScore < _minBrightness) {
      return FaceCaptureAssessment(
        passes: false,
        message: 'Foto terlalu gelap. Coba cari cahaya yang lebih terang.',
        blurScore: blurScore,
        brightnessScore: brightnessScore,
        qualityLabel: 'Terlalu gelap',
      );
    }
    if (brightnessScore > _maxBrightness) {
      return FaceCaptureAssessment(
        passes: false,
        message: 'Foto terlalu terang. Kurangi cahaya langsung ke wajah.',
        blurScore: blurScore,
        brightnessScore: brightnessScore,
        qualityLabel: 'Terlalu terang',
      );
    }

    final qualityLabel = blurScore >= 260 && brightnessScore >= 90 && brightnessScore <= 170
        ? 'Bagus'
        : 'Layak dipakai';

    return FaceCaptureAssessment(
      passes: true,
      message: 'Foto final sudah cukup tajam dan terang.',
      blurScore: blurScore,
      brightnessScore: brightnessScore,
      qualityLabel: qualityLabel,
    );
  }

  Rect _expandedCrop({
    required Rect bounds,
    required int imageWidth,
    required int imageHeight,
  }) {
    final horizontalPadding = bounds.width * 0.35;
    final topPadding = bounds.height * 0.42;
    final bottomPadding = bounds.height * 0.28;

    final left = _clampDouble(bounds.left - horizontalPadding, 0, imageWidth - 1);
    final top = _clampDouble(bounds.top - topPadding, 0, imageHeight - 1);
    final right = _clampDouble(
      bounds.right + horizontalPadding,
      left + 1,
      imageWidth.toDouble(),
    );
    final bottom = _clampDouble(
      bounds.bottom + bottomPadding,
      top + 1,
      imageHeight.toDouble(),
    );

    return Rect.fromLTRB(left, top, right, bottom);
  }

  double _calculateBlurScore(img.Image image) {
    if (image.width < 3 || image.height < 3) {
      return 0;
    }

    var total = 0.0;
    var totalSquared = 0.0;
    var count = 0;

    for (var y = 1; y < image.height - 1; y++) {
      for (var x = 1; x < image.width - 1; x++) {
        final center = image.getPixel(x, y).r.toDouble();
        final left = image.getPixel(x - 1, y).r.toDouble();
        final right = image.getPixel(x + 1, y).r.toDouble();
        final top = image.getPixel(x, y - 1).r.toDouble();
        final bottom = image.getPixel(x, y + 1).r.toDouble();

        final laplacian = (4 * center) - left - right - top - bottom;
        total += laplacian;
        totalSquared += laplacian * laplacian;
        count++;
      }
    }

    if (count == 0) {
      return 0;
    }

    final mean = total / count;
    return (totalSquared / count) - (mean * mean);
  }

  double _calculateBrightnessScore(img.Image image) {
    if (image.width == 0 || image.height == 0) {
      return 0;
    }

    var total = 0.0;
    var count = 0;
    for (final pixel in image) {
      total += pixel.r.toDouble();
      count++;
    }

    if (count == 0) {
      return 0;
    }

    return total / count;
  }

  double _clampDouble(double value, double min, double max) {
    if (value < min) {
      return min;
    }
    if (value > max) {
      return max;
    }
    return value;
  }
}
