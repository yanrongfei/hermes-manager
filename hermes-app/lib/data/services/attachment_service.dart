import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import '../models/attachment.dart';

class AttachmentService {
  final ImagePicker _imagePicker = ImagePicker();

  Future<Attachment?> pickImageFromGallery() async {
    try {
      final XFile? file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (file == null) return null;

      final bytes = await file.length();
      return Attachment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: 'image',
        name: path.basename(file.path),
        localPath: file.path,
        mimeType: 'image/${path.extension(file.path).replaceFirst('.', '')}',
        size: bytes,
      );
    } catch (e) {
      return null;
    }
  }

  Future<Attachment?> takePhoto() async {
    try {
      final XFile? file = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (file == null) return null;

      final bytes = await file.length();
      return Attachment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: 'image',
        name: path.basename(file.path),
        localPath: file.path,
        mimeType: 'image/${path.extension(file.path).replaceFirst('.', '')}',
        size: bytes,
      );
    } catch (e) {
      return null;
    }
  }

  Future<Attachment?> pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return null;

      final file = result.files.first;
      final filePath = file.path;
      if (filePath == null) return null;

      final fileEntity = File(filePath);
      final bytes = await fileEntity.length();

      return Attachment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: 'file',
        name: file.name,
        localPath: filePath,
        size: bytes,
      );
    } catch (e) {
      return null;
    }
  }
}