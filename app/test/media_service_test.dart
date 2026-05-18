import 'dart:io';

import 'package:app/core/services/media_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as image;
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('media_service_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('caps compressed image target width at 1080 pixels', () async {
    final source = File(p.join(tempDir.path, 'wide.jpg'));
    await source.writeAsBytes(
      image.encodeJpg(image.Image(width: 2400, height: 1200)),
    );
    final service = MediaService(rootDirectory: tempDir);

    final result = await service.prepareImage(source);

    expect(result.width, 1080);
    expect(result.height, 540);
    expect(result.file.path, contains('${p.separator}cache${p.separator}'));
  });

  test('rejects files larger than 50 MB', () async {
    final file = File(p.join(tempDir.path, 'large.bin'));
    await file.writeAsBytes(List<int>.filled(50 * 1024 * 1024 + 1, 1));
    final service = MediaService(rootDirectory: tempDir);

    await expectLater(
      service.validateFile(file),
      throwsA(isA<MediaValidationException>()),
    );
  });

  test('rejects voice messages longer than 60 seconds', () async {
    final service = MediaService(rootDirectory: tempDir);

    expect(
      () => service.validateVoiceDuration(const Duration(seconds: 61)),
      throwsA(isA<MediaValidationException>()),
    );
  });

  test('generates stable hashed media filenames with extensions', () async {
    final file = File(p.join(tempDir.path, 'photo.JPG'));
    await file.writeAsString('same bytes');
    final service = MediaService(rootDirectory: tempDir);

    final first = await service.hashedMediaFilename(file);
    final second = await service.hashedMediaFilename(file);

    expect(first, second);
    expect(first, endsWith('.jpg'));
    expect(first, hasLength(68));
  });

  test(
    'cache cleanup removes cache and thumbnails but keeps chat database',
    () async {
      final cacheFile = File(p.join(tempDir.path, 'cache', 'cached.jpg'))
        ..createSync(recursive: true);
      final thumbnailFile = File(
        p.join(tempDir.path, 'thumbnails', 'thumb.jpg'),
      )..createSync(recursive: true);
      final dbFile = File(p.join(tempDir.path, 'databases', 'chat.db'))
        ..createSync(recursive: true);
      final mediaFile = File(p.join(tempDir.path, 'media', 'photo.jpg'))
        ..createSync(recursive: true);
      final service = MediaService(rootDirectory: tempDir);

      await service.clearCache();

      expect(await cacheFile.exists(), isFalse);
      expect(await thumbnailFile.exists(), isFalse);
      expect(await dbFile.exists(), isTrue);
      expect(await mediaFile.exists(), isTrue);
    },
  );

  test(
    'upload posts to media upload endpoint and reads backend file path',
    () async {
      final requests = <http.Request>[];
      final service = MediaService(
        rootDirectory: tempDir,
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          requests.add(request);
          if (request.method == 'GET') {
            return http.Response.bytes([1, 2, 3], 200);
          }
          return http.Response(
            '{"file":{"id":"m1","ownerId":1,"originalName":"photo.jpg","mimeType":"image/jpeg","sizeBytes":1,"storagePath":"/server/storage/media/m1.jpg","sha256":"hash"}}',
            201,
          );
        }),
      );
      final file = File(p.join(tempDir.path, 'photo.jpg'))
        ..writeAsBytesSync([9]);

      final uploadPath = await service.upload(file, token: 'token');
      final downloaded = await service.download(
        '/media/photo.jpg',
        token: 'token',
      );

      expect(uploadPath, '/media/m1');
      expect(downloaded, [1, 2, 3]);
      expect(requests.map((request) => request.method), ['POST', 'GET']);
      expect(
        requests.first.url,
        Uri.parse('https://example.test/media/upload'),
      );
      expect(requests.first.headers['Authorization'], 'Bearer token');
    },
  );

  test(
    'downloads remote media into the media directory with extension',
    () async {
      final requests = <http.Request>[];
      final service = MediaService(
        rootDirectory: tempDir,
        baseUrl: 'https://example.test/api',
        client: MockClient((request) async {
          requests.add(request);
          return http.Response.bytes([7, 8, 9], 200);
        }),
      );

      final file = await service.downloadToMediaFile(
        '/media/video-1',
        filename: 'clip.mp4',
        token: 'token',
      );

      expect(await file.exists(), isTrue);
      expect(await file.readAsBytes(), [7, 8, 9]);
      expect(file.path, contains('${p.separator}media${p.separator}'));
      expect(file.path, endsWith('.mp4'));
      expect(requests.single.method, 'GET');
      expect(
        requests.single.url,
        Uri.parse('https://example.test/api/media/video-1'),
      );
      expect(requests.single.headers['Authorization'], 'Bearer token');
    },
  );
}
