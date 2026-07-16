import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../constants/app_constants.dart';
import '../error/error_mapper.dart';
import '../providers/core_providers.dart';

/// Uploads product images to the `product-images` bucket under
/// `<shopId>/<entityId>/<uuid>.<ext>` (the first path segment scopes RLS).
class ImageUploader {
  ImageUploader(this._client);
  final SupabaseClient _client;
  static const _uuid = Uuid();

  Future<String> uploadProductImage({
    required String shopId,
    required String productId,
    required File file,
  }) async {
    try {
      final ext = file.path.split('.').last.toLowerCase();
      final path = '$shopId/$productId/${_uuid.v4()}.$ext';
      await _client.storage.from(AppConstants.bucketProductImages).upload(
            path,
            file,
            fileOptions: const FileOptions(upsert: true),
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
