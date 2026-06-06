import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class UploadService {
  final _storage = FirebaseStorage.instance;
  final _picker = ImagePicker();

  /// Pick image from gallery or camera.
  Future<File?> pickImage({bool fromCamera = false}) async {
    final source = fromCamera ? ImageSource.camera : ImageSource.gallery;
    final picked = await _picker.pickImage(source: source, imageQuality: 70);
    if (picked == null) return null;
    return File(picked.path);
  }

  /// Upload file to Firebase Storage and return download URL.
  /// Returns null if offline or not authenticated.
  Future<String?> uploadReceipt({
    required File file,
    required String roomId,
    required String folder,
  }) async {
    // Check network availability first
    if (!await _hasNetwork()) return null;

    // Firebase Storage requires a signed-in user
    if (FirebaseAuth.instance.currentUser == null) return null;

    try {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      final ref = _storage.ref('receipts/$roomId/$folder/$fileName');
      final snapshot = await ref.putFile(file);
      if (snapshot.state == TaskState.success) {
        return await ref.getDownloadURL();
      }
      return null;
    } on FirebaseException catch (e, st) {
      debugPrint('UploadReceipt FirebaseException: ${e.code} ${e.message}');
      debugPrint('$st');
      return null;
    } catch (e, st) {
      debugPrint('UploadReceipt failed: $e');
      debugPrint('$st');
      return null;
    }
  }

  Future<bool> _hasNetwork() async {
    try {
      final result = await InternetAddress.lookup(
        'googleapis.com',
      ).timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
