import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Compresses images before upload to keep Supabase storage usage low.
/// Decodes, downsizes to fit within [maxDimension], and re-encodes as JPEG.
/// Falls back to the original bytes if anything goes wrong or if the result
/// wouldn't be smaller.
class ImageCompressor {
  const ImageCompressor._();

  static Uint8List compress(
    Uint8List input, {
    int maxDimension = 1200,
    int quality = 70,
  }) {
    try {
      final decoded = img.decodeImage(input);
      if (decoded == null) return input;

      var image = decoded;
      final longest =
          decoded.width > decoded.height ? decoded.width : decoded.height;
      if (longest > maxDimension) {
        image = decoded.width >= decoded.height
            ? img.copyResize(decoded, width: maxDimension)
            : img.copyResize(decoded, height: maxDimension);
      }

      final jpg = img.encodeJpg(image, quality: quality);
      return jpg.length < input.length ? jpg : input;
    } catch (_) {
      return input;
    }
  }
}
