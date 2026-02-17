import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
// Extension extraction done manually to avoid extra dependency

class StorageService {
  final SupabaseClient _supabase;

  StorageService(this._supabase);

  static const Set<String> _privateBuckets = {
    verificationDocsBucket,
    truckImagesBucket,
    voiceMessagesBucket,
  };

  Future<String> uploadFile({
    required String bucket,
    required String filePath,
    required File file,
  }) async {
    await _supabase.storage.from(bucket).upload(
          filePath,
          file,
          fileOptions: const FileOptions(upsert: true),
        );

    if (_privateBuckets.contains(bucket)) {
      return await _supabase.storage.from(bucket).createSignedUrl(filePath, 3600);
    }
    return _supabase.storage.from(bucket).getPublicUrl(filePath);
  }

  Future<String> getSignedUrl({
    required String bucket,
    required String filePath,
    int expiresIn = 3600,
  }) async {
    return await _supabase.storage.from(bucket).createSignedUrl(
          filePath,
          expiresIn,
        );
  }

  Future<String> uploadImage({
    required String bucket,
    required String userId,
    required XFile imageFile,
    String? subfolder,
  }) async {
    final ext = imageFile.path.split('.').last;
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final storagePath = subfolder != null
        ? '$userId/$subfolder/$fileName'
        : '$userId/$fileName';

    final file = File(imageFile.path);

    return await uploadFile(
      bucket: bucket,
      filePath: storagePath,
      file: file,
    );
  }

  static const String verificationDocsBucket = 'verification-docs';
  static const String truckImagesBucket = 'truck-images';
  static const String avatarsBucket = 'avatars';
  static const String voiceMessagesBucket = 'voice-messages';
}
