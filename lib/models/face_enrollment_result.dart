import 'dart:typed_data';

class FaceEnrollmentResult {
  final String imagePath;
  final Uint8List imageBytes;
  final double blurScore;
  final double brightnessScore;
  final DateTime capturedAt;
  final String qualityLabel;
  final String qualityMessage;

  const FaceEnrollmentResult({
    required this.imagePath,
    required this.imageBytes,
    required this.blurScore,
    required this.brightnessScore,
    required this.capturedAt,
    required this.qualityLabel,
    required this.qualityMessage,
  });
}
