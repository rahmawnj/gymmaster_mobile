import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:zxing2/qrcode.dart';

class QrDecoderException implements Exception {
  final String message;

  const QrDecoderException(this.message);

  @override
  String toString() => message;
}

class QrDecoderService {
  const QrDecoderService();

  Future<String> decodeFile(XFile file) async {
    final bytes = await file.readAsBytes();
    return decodeBytes(bytes);
  }

  String decodeBytes(Uint8List bytes) {
    final decodedImage = img.decodeImage(bytes);
    if (decodedImage == null) {
      throw const QrDecoderException(
        'Format gambar tidak didukung. Coba pilih file gambar lain.',
      );
    }

    final bakedImage = img.bakeOrientation(decodedImage);
    final candidates = <img.Image>[
      bakedImage,
      img.copyRotate(bakedImage, angle: 90),
      img.copyRotate(bakedImage, angle: 180),
      img.copyRotate(bakedImage, angle: -90),
    ];

    for (final candidate in candidates) {
      final result = _tryDecode(candidate);
      if (result != null && result.isNotEmpty) {
        return result;
      }
    }

    throw const QrDecoderException(
      'QR tidak ditemukan pada gambar yang dipilih.',
    );
  }

  String? _tryDecode(img.Image sourceImage) {
    try {
      final converted = sourceImage.convert(numChannels: 4);
      final pixels = converted
          .getBytes(order: img.ChannelOrder.abgr)
          .buffer
          .asInt32List();
      final source = RGBLuminanceSource(
        converted.width,
        converted.height,
        pixels,
      );
      final bitmap = BinaryBitmap(HybridBinarizer(source));
      final result = QRCodeReader().decode(bitmap);
      return result.text.trim();
    } catch (_) {
      return null;
    }
  }
}
