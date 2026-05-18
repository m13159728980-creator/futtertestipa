import 'dart:convert';
import 'dart:io';

import 'package:app/core/config/app_config.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as image;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class MediaValidationException implements Exception {
  const MediaValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PreparedImage {
  const PreparedImage({
    required this.file,
    required this.width,
    required this.height,
  });

  final File file;
  final int width;
  final int height;
}

class MediaService {
  MediaService({
    Directory? rootDirectory,
    http.Client? client,
    String baseUrl = AppConfig.apiBaseUrl,
  }) : _rootDirectory = rootDirectory,
       _client = client ?? http.Client(),
       _baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), '');

  static const int maxImageWidth = 1080;
  static const int maxFileBytes = 50 * 1024 * 1024;
  static const Duration maxVoiceDuration = Duration(seconds: 60);

  final Directory? _rootDirectory;
  final http.Client _client;
  final String _baseUrl;

  Future<Directory> mediaDirectory() => _childDirectory('media');

  Future<Directory> cacheDirectory() => _childDirectory('cache');

  Future<Directory> thumbnailDirectory() => _childDirectory('thumbnails');

  Future<PreparedImage> prepareImage(File source) async {
    await validateFile(source);
    final decoded = image.decodeImage(await source.readAsBytes());
    if (decoded == null) {
      throw const MediaValidationException('Unsupported image format');
    }

    final target = _targetSize(decoded.width, decoded.height);
    final resized = target.width == decoded.width
        ? decoded
        : image.copyResize(
            decoded,
            width: target.width,
            height: target.height,
            interpolation: image.Interpolation.average,
          );
    final cache = await cacheDirectory();
    final filename = await hashedMediaFilename(source, extension: '.jpg');
    final output = File(p.join(cache.path, filename));
    await output.writeAsBytes(image.encodeJpg(resized, quality: 82));

    return PreparedImage(
      file: output,
      width: target.width,
      height: target.height,
    );
  }

  Future<void> validateFile(File file) async {
    final length = await file.length();
    if (length > maxFileBytes) {
      throw const MediaValidationException('File exceeds 50 MB limit');
    }
  }

  void validateVoiceDuration(Duration duration) {
    if (duration > maxVoiceDuration) {
      throw const MediaValidationException('Voice exceeds 60 second limit');
    }
  }

  Future<String> hashedMediaFilename(File file, {String? extension}) async {
    final digest = sha256.convert(await file.readAsBytes()).toString();
    final ext = (extension ?? p.extension(file.path)).toLowerCase();
    return '$digest$ext';
  }

  Future<String> upload(File file, {String? token}) async {
    await validateFile(file);
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/media/upload'),
    );
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final response = await http.Response.fromStream(
      await _client.send(request),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MediaValidationException('Upload failed: ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      final file = decoded['file'];
      if (file is Map<String, dynamic>) {
        final directPath = file['path'] ?? file['url'] ?? file['downloadUrl'];
        if (directPath is String && directPath.isNotEmpty) {
          return directPath;
        }
        final id = file['id'];
        if (id is String && id.isNotEmpty) {
          return '/media/$id';
        }
        final storagePath = file['storagePath'];
        if (storagePath is String && storagePath.isNotEmpty) {
          return storagePath;
        }
      }
      final directPath =
          decoded['path'] ?? decoded['url'] ?? decoded['downloadUrl'];
      if (directPath is String && directPath.isNotEmpty) {
        return directPath;
      }
    }
    throw const MediaValidationException('Upload response missing media path');
  }

  Future<List<int>> download(String path, {String? token}) async {
    final uri = path.startsWith('http')
        ? Uri.parse(path)
        : Uri.parse('$_baseUrl$path');
    final response = await _client.get(
      uri,
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MediaValidationException('Download failed: ${response.statusCode}');
    }
    return response.bodyBytes;
  }

  Future<File> downloadToMediaFile(
    String path, {
    String? filename,
    String? token,
  }) async {
    final bytes = await download(path, token: token);
    final media = await mediaDirectory();
    final digest = sha256.convert(utf8.encode(path)).toString();
    final extension =
        _safeExtension(filename) ?? _safeExtension(path) ?? '.bin';
    final output = File(p.join(media.path, '$digest$extension'));
    await output.writeAsBytes(bytes);
    return output;
  }

  Future<void> clearCache() async {
    for (final directory in [
      await cacheDirectory(),
      await thumbnailDirectory(),
    ]) {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
      await directory.create(recursive: true);
    }
  }

  ({int width, int height}) _targetSize(int width, int height) {
    if (width <= maxImageWidth) {
      return (width: width, height: height);
    }
    final ratio = maxImageWidth / width;
    return (width: maxImageWidth, height: (height * ratio).round());
  }

  Future<Directory> _childDirectory(String name) async {
    final root = await _root();
    final directory = Directory(p.join(root.path, name));
    return directory.create(recursive: true);
  }

  Future<Directory> _root() async {
    if (_rootDirectory != null) {
      await _rootDirectory.create(recursive: true);
      return _rootDirectory;
    }
    return getApplicationDocumentsDirectory();
  }

  String? _safeExtension(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final extension = p.extension(Uri.decodeComponent(value.split('?').first));
    if (extension.isEmpty || extension.length > 16) {
      return null;
    }
    final normalized = extension.toLowerCase();
    return RegExp(r'^\.[a-z0-9]+$').hasMatch(normalized) ? normalized : null;
  }
}
