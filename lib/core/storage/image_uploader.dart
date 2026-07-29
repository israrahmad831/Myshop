import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../constants/app_constants.dart';
import '../error/error_mapper.dart';
import '../providers/core_providers.dart';

/// Uploads product images to the `product-images` bucket under
/// `<shopId>/<entityId>/<uuid>.<ext>` (the first path segment scopes RLS).
///
/// Uses raw bytes (`uploadBinary`) rather than a `dart:io` File so it works on
/// web as well as mobile/desktop.
class ImageUploader {
  ImageUploader(this._client);
  final SupabaseClient _client;
  static const _uuid = Uuid();

  static String _contentType(String ext) => switch (ext.toLowerCase()) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        'heic' => 'image/heic',
        _ => 'image/jpeg',
      };

  /// Upload a shop-level image (e.g. receipt header, logo). Stored under
  /// `<shopId>/<kind>/<uuid>.<ext>` so the first path segment scopes RLS.
  Future<String> uploadShopImage({
    required String shopId,
    required String kind, // 'header' | 'logo'
    required Uint8List bytes,
    String fileExt = 'jpg',
  }) async {
    return _upload('$shopId/$kind', bytes, fileExt);
  }

  Future<String> uploadProductImage({
    required String shopId,
    required String productId,
    required Uint8List bytes,
    String fileExt = 'jpg',
  }) async {
    return _upload('$shopId/$productId', bytes, fileExt);
  }

  Future<String> uploadCustomerImage({
    required String shopId,
    required String customerId,
    required Uint8List bytes,
    String fileExt = 'jpg',
  }) async {
    return _upload('$shopId/customer-$customerId', bytes, fileExt);
  }

  Future<String> _upload(String folder, Uint8List bytes, String fileExt) async {
    try {
      final ext = fileExt.isEmpty ? 'jpg' : fileExt.toLowerCase();
      final path = '$folder/${_uuid.v4()}.$ext';
      await _client.storage.from(AppConstants.bucketProductImages).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: _contentType(ext),
            ),
          );
      return _client.storage
          .from(AppConstants.bucketProductImages)
          .getPublicUrl(path);
    } catch (e) {
      throw mapError(e);
    }
  }
}

final imageUploaderProvider = Provider<ImageUploader>((ref) {
  return ImageUploader(ref.watch(supabaseProvider));
});
