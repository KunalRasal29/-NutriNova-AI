import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

Future<XFile?> recoverInterruptedPhoto(ImagePicker picker) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
  final response = await picker.retrieveLostData();
  if (response.exception != null) throw response.exception!;
  final files = response.files;
  return files != null && files.isNotEmpty ? files.first : response.file;
}

String photoPickerErrorMessage(Object error, ImageSource source) {
  if (error is PlatformException) {
    switch (error.code) {
      case 'camera_access_denied':
      case 'camera_access_denied_without_prompt':
      case 'camera_access_restricted':
        return 'Camera access is unavailable. Allow Camera for NutriNova AI in '
            'device Settings, then try again. You can also use Gallery.';
      case 'photo_access_denied':
      case 'photo_access_denied_without_prompt':
      case 'photo_access_restricted':
        return 'Photo access is unavailable. Allow Photos for NutriNova AI in '
            'device Settings, then choose a photo again.';
      case 'already_active':
        return 'A photo picker is already open. Finish or cancel it first.';
    }
  }
  return source == ImageSource.camera
      ? 'Camera could not open. Try again or choose a photo from Gallery.'
      : 'Could not open this photo. Choose another image or try again.';
}
