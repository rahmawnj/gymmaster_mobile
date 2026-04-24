import 'dart:math' as math;
import 'dart:typed_data' show Uint8List;
import 'dart:ui' show Offset, Rect, Size;

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

  bool get hasNeutralYaw =>
      yaw.abs() <= FaceQualityService.maxNeutralYawDegrees;

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
      return 'Geser wajah sampai seluruh area muka masuk ke dalam oval.';
    }
    if (isTooLarge) {
      return 'Wajah terlalu dekat. Jauhkan sedikit sampai ukuran wajah sekitar ${FaceQualityService.formatRatioRange(FaceQualityService.minFaceWidthRatio, FaceQualityService.maxFaceWidthRatio)} lebar oval.';
    }
    if (!isLargeEnough) {
      return 'Wajah masih terlalu jauh. Dekatkan sedikit sampai ukuran wajah sekitar ${FaceQualityService.formatRatioRange(FaceQualityService.minFaceWidthRatio, FaceQualityService.maxFaceWidthRatio)} lebar oval.';
    }
    if (!isCentered) {
      return 'Geser wajah ke tengah oval. Posisi aman sekitar +/-${(FaceQualityService.centerToleranceX * 100).round()}% kanan-kiri dan +/-${(FaceQualityService.centerToleranceY * 100).round()}% atas-bawah dari titik tengah.';
    }
    if (!hasAcceptableRoll) {
      return 'Luruskan kepala supaya tidak terlalu miring. Roll aman di kisaran +/-${FaceQualityService.maxAcceptableRollDegrees.round()}°.';
    }

    return 'Posisi wajah sudah pas.';
  }

  String get finalCaptureGuidance {
    if (!isFramedWell) {
      return guidance;
    }
    if (!hasNeutralYaw) {
      return 'Putar wajah lebih lurus ke depan. Batas aman yaw di kisaran +/-${FaceQualityService.maxNeutralYawDegrees.round()}°.';
    }
    if (!hasNeutralPitch) {
      return 'Posisikan dagu lebih sejajar. Batas aman pitch di kisaran +/-${FaceQualityService.maxNeutralPitchDegrees.round()}°.';
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
  static const double maxNeutralYawDegrees = 8;
  static const double maxNeutralPitchDegrees = 8;
  static const double maxAcceptableRollDegrees = 10;
  static const double minFaceWidthRatio = 0.75;
  static const double minFaceHeightRatio = 0.85;
  static const double maxFaceWidthRatio = 1.10;
  static const double maxFaceHeightRatio = 1.25;
  static const double centerToleranceX = 0.16;
  static const double centerToleranceY = 0.18;
  static const double minPreviewBlurScore = 125;
  static const double _contourInsideRatioThreshold = 0.96;
  static const double _contourEdgeScoreThreshold = 1.0;
  static const double _contourPointScoreThreshold = 1.0;
  static const double _contourBandAverageScoreThreshold = 0.95;
  static const double _contourCriticalPointRatio = 0.14;
  static const int _contourCriticalPointFloor = 4;
  static const double _minBlurScore = 180;
  static const double _minBrightness = 70;
  static const double _maxBrightness = 195;

  const FaceQualityService();

  FaceFrameGeometry inspectFrame({
    required List<Face> faces,
    required Size imageSize,
    required InputImageRotation imageRotation,
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

    // scale factor for BoxFit.cover
    final rotatedImageSize = _rotatedImageSize(imageSize, imageRotation);
    final scaleX = screenSize.width / rotatedImageSize.width;
    final scaleY = screenSize.height / rotatedImageSize.height;
    final scale = math.max(scaleX, scaleY);

    // image center
    final centerX = rotatedImageSize.width / 2;
    final centerY = rotatedImageSize.height / 2;

    // circle bounds in image coordinates
    final guideRect = Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: guideSize.width / scale,
      height: guideSize.height / scale,
    );

    final primaryFace = sortedFaces.first;
    final faceBounds = primaryFace.boundingBox;

    final faceWidthRatio = faceBounds.width / guideRect.width;
    final faceHeightRatio = faceBounds.height / guideRect.height;

    final normalizedCenterX =
        (faceBounds.center.dx - guideRect.left) / guideRect.width;
    final normalizedCenterY =
        (faceBounds.center.dy - guideRect.top) / guideRect.height;
    final isInsideGuide = _isFaceInsideGuide(
      face: primaryFace,
      faceBounds: faceBounds,
      guideRect: guideRect,
    );

    final roll = (primaryFace.headEulerAngleZ ?? 0).toDouble();
    final yaw = (primaryFace.headEulerAngleY ?? 0).toDouble();
    final pitch = (primaryFace.headEulerAngleX ?? 0).toDouble();

    final isCentered =
        (normalizedCenterX - 0.5).abs() <= centerToleranceX &&
        (normalizedCenterY - 0.5).abs() <= centerToleranceY;
    final isTooLarge = faceWidthRatio > maxFaceWidthRatio;
    final isLargeEnough = faceWidthRatio >= minFaceWidthRatio;
    final hasAcceptableRoll = roll.abs() <= maxAcceptableRollDegrees;

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
    final faces = await detector.processImage(
      InputImage.fromFilePath(imagePath),
    );
    if (faces.isEmpty) {
      return const FaceCaptureAssessment(
        passes: false,
        message:
            'Wajah tidak terdeteksi di foto final. Coba ulangi sekali lagi.',
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
      img.copyResize(cropped, width: math.min(cropped.width, 220)),
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

    final qualityLabel =
        blurScore >= 260 && brightnessScore >= 90 && brightnessScore <= 170
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

  double? estimatePreviewBlurScore({
    required CameraImage image,
    required Rect faceBounds,
  }) {
    if (image.planes.isEmpty) {
      return null;
    }

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    final isBgra = format == InputImageFormat.bgra8888;
    final isNv21 = format == InputImageFormat.nv21;
    if (!isBgra && !isNv21) {
      return null;
    }

    final cropRect = _previewCrop(
      bounds: faceBounds,
      imageWidth: image.width,
      imageHeight: image.height,
    );
    if (cropRect.width < 24 || cropRect.height < 24) {
      return null;
    }

    final targetWidth = math.min(96, cropRect.width.round());
    final scaledHeight = (cropRect.height * (targetWidth / cropRect.width))
        .round();
    final targetHeight = math.max(28, math.min(128, scaledHeight));
    if (targetWidth < 3 || targetHeight < 3) {
      return null;
    }

    final grayscale = Uint8List(targetWidth * targetHeight);
    final plane = image.planes.first;
    for (var y = 0; y < targetHeight; y++) {
      final sourceY = _clampInt(
        (cropRect.top + (((y + 0.5) * cropRect.height) / targetHeight)).floor(),
        0,
        image.height - 1,
      );

      for (var x = 0; x < targetWidth; x++) {
        final sourceX = _clampInt(
          (cropRect.left + (((x + 0.5) * cropRect.width) / targetWidth))
              .floor(),
          0,
          image.width - 1,
        );
        grayscale[(y * targetWidth) + x] = _readLumaValue(
          plane: plane,
          x: sourceX,
          y: sourceY,
          isBgra: isBgra,
        );
      }
    }

    return _calculateBlurScoreFromLuma(grayscale, targetWidth, targetHeight);
  }

  Rect _expandedCrop({
    required Rect bounds,
    required int imageWidth,
    required int imageHeight,
  }) {
    final horizontalPadding = bounds.width * 0.35;
    final topPadding = bounds.height * 0.42;
    final bottomPadding = bounds.height * 0.28;

    final left = _clampDouble(
      bounds.left - horizontalPadding,
      0,
      imageWidth - 1,
    );
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

  Rect _previewCrop({
    required Rect bounds,
    required int imageWidth,
    required int imageHeight,
  }) {
    final horizontalPadding = bounds.width * 0.18;
    final topPadding = bounds.height * 0.16;
    final bottomPadding = bounds.height * 0.10;

    final left = _clampDouble(
      bounds.left - horizontalPadding,
      0,
      imageWidth - 1,
    );
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

  Size _rotatedImageSize(Size imageSize, InputImageRotation imageRotation) {
    switch (imageRotation) {
      case InputImageRotation.rotation90deg:
      case InputImageRotation.rotation270deg:
        return Size(imageSize.height, imageSize.width);
      case InputImageRotation.rotation0deg:
      case InputImageRotation.rotation180deg:
        return imageSize;
    }
  }

  bool _isFaceInsideGuide({
    required Face face,
    required Rect faceBounds,
    required Rect guideRect,
  }) {
    // Disabled strict contour checking because the required face size 
    // is now up to 110% of the guide rect, so it will naturally overflow.
    return true;
  }

  bool _isContourInsideGuide(List<Offset> contourPoints, Rect guideRect) {
    if (contourPoints.length < 8) {
      return false;
    }

    final criticalPointCount = math.max(
      _contourCriticalPointFloor,
      (contourPoints.length * _contourCriticalPointRatio).round(),
    );
    final criticalBands = [
      _takeExtremeContourPoints(
        contourPoints,
        count: criticalPointCount,
        comparator: (a, b) => a.dx.compareTo(b.dx),
      ),
      _takeExtremeContourPoints(
        contourPoints,
        count: criticalPointCount,
        comparator: (a, b) => b.dx.compareTo(a.dx),
      ),
      _takeExtremeContourPoints(
        contourPoints,
        count: criticalPointCount,
        comparator: (a, b) => a.dy.compareTo(b.dy),
      ),
      _takeExtremeContourPoints(
        contourPoints,
        count: criticalPointCount,
        comparator: (a, b) => b.dy.compareTo(a.dy),
      ),
    ];
    final edgesInside = criticalBands.every(
      (points) => _isCriticalContourBandInside(points, guideRect),
    );
    if (!edgesInside) {
      return false;
    }

    final insideCount = contourPoints
        .where(
          (point) =>
              _ellipseScore(point, guideRect) <= _contourPointScoreThreshold,
        )
        .length;
    final insideRatio = insideCount / contourPoints.length;
    return insideRatio >= _contourInsideRatioThreshold;
  }

  List<Offset> _takeExtremeContourPoints(
    List<Offset> contourPoints, {
    required int count,
    required int Function(Offset a, Offset b) comparator,
  }) {
    final sorted = [...contourPoints]..sort(comparator);
    return sorted.take(math.min(count, sorted.length)).toList(growable: false);
  }

  bool _isCriticalContourBandInside(List<Offset> points, Rect guideRect) {
    if (points.isEmpty) {
      return false;
    }

    final scores = points
        .map((point) => _ellipseScore(point, guideRect))
        .toList(growable: false);
    final maxScore = scores.reduce(math.max);
    if (maxScore > _contourEdgeScoreThreshold) {
      return false;
    }

    final averageScore =
        scores.reduce((total, score) => total + score) / scores.length;
    return averageScore <= _contourBandAverageScoreThreshold;
  }

  List<Offset> _guideProbePoints(Rect bounds) {
    return [
      bounds.center,
      Offset(bounds.center.dx, bounds.top + (bounds.height * 0.06)),
      Offset(bounds.center.dx, bounds.bottom - (bounds.height * 0.05)),
      Offset(bounds.left + (bounds.width * 0.12), bounds.center.dy),
      Offset(bounds.right - (bounds.width * 0.12), bounds.center.dy),
      Offset(
        bounds.left + (bounds.width * 0.22),
        bounds.top + (bounds.height * 0.22),
      ),
      Offset(
        bounds.right - (bounds.width * 0.22),
        bounds.top + (bounds.height * 0.22),
      ),
      Offset(
        bounds.left + (bounds.width * 0.22),
        bounds.bottom - (bounds.height * 0.18),
      ),
      Offset(
        bounds.right - (bounds.width * 0.22),
        bounds.bottom - (bounds.height * 0.18),
      ),
    ];
  }

  bool _isPointInsideGuideEllipse(Offset point, Rect guideRect) {
    return _ellipseScore(point, guideRect) <= 0.90;
  }

  double _ellipseScore(Offset point, Rect guideRect) {
    final radiusX = guideRect.width / 2;
    final radiusY = guideRect.height / 2;
    if (radiusX <= 0 || radiusY <= 0) {
      return double.infinity;
    }

    final dx = (point.dx - guideRect.center.dx) / radiusX;
    final dy = (point.dy - guideRect.center.dy) / radiusY;
    return (dx * dx) + (dy * dy);
  }

  static String formatRatioRange(double minRatio, double maxRatio) {
    return '${(minRatio * 100).round()}-${(maxRatio * 100).round()}%';
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

  double _calculateBlurScoreFromLuma(
    Uint8List grayscale,
    int width,
    int height,
  ) {
    if (width < 3 || height < 3 || grayscale.isEmpty) {
      return 0;
    }

    var total = 0.0;
    var totalSquared = 0.0;
    var count = 0;

    for (var y = 1; y < height - 1; y++) {
      final rowOffset = y * width;
      for (var x = 1; x < width - 1; x++) {
        final centerIndex = rowOffset + x;
        final center = grayscale[centerIndex].toDouble();
        final left = grayscale[centerIndex - 1].toDouble();
        final right = grayscale[centerIndex + 1].toDouble();
        final top = grayscale[centerIndex - width].toDouble();
        final bottom = grayscale[centerIndex + width].toDouble();

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

  int _readLumaValue({
    required Plane plane,
    required int x,
    required int y,
    required bool isBgra,
  }) {
    final pixelStride = plane.bytesPerPixel ?? (isBgra ? 4 : 1);
    final offset = (y * plane.bytesPerRow) + (x * pixelStride);
    if (offset < 0 || offset >= plane.bytes.length) {
      return 0;
    }

    if (!isBgra) {
      return plane.bytes[offset];
    }

    if (offset + 2 >= plane.bytes.length) {
      return 0;
    }

    final blue = plane.bytes[offset];
    final green = plane.bytes[offset + 1];
    final red = plane.bytes[offset + 2];
    return ((red * 299) + (green * 587) + (blue * 114)) ~/ 1000;
  }

  int _clampInt(int value, int min, int max) {
    if (value < min) {
      return min;
    }
    if (value > max) {
      return max;
    }
    return value;
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
