import 'dart:io';

import 'package:app/core/config/app_config.dart';
import 'package:app/core/services/media_service.dart';
import 'package:app/models/message.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MediaOpenResult {
  const MediaOpenResult({required this.success, this.message});

  final bool success;
  final String? message;
}

abstract class MediaOpenController {
  Future<MediaOpenResult> open({
    String? localPath,
    String? remoteUrl,
    String? title,
    required bool isVideo,
  });
}

class NativeMediaOpenController implements MediaOpenController {
  NativeMediaOpenController({
    MediaService? mediaService,
    MethodChannel channel = const MethodChannel('app/media_open'),
  }) : _mediaService = mediaService ?? MediaService(),
       _channel = channel;

  final MediaService _mediaService;
  final MethodChannel _channel;

  @override
  Future<MediaOpenResult> open({
    String? localPath,
    String? remoteUrl,
    String? title,
    required bool isVideo,
  }) async {
    final local = localPath;
    File? source;
    if (local != null && local.isNotEmpty) {
      final file = File(local);
      if (await file.exists()) {
        source = file;
      }
    }

    final remote = remoteUrl;
    if (source == null && remote != null && remote.isNotEmpty) {
      source = await _mediaService.downloadToMediaFile(remote, filename: title);
    }

    if (source == null) {
      return const MediaOpenResult(success: false, message: '文件不可用');
    }

    final opened =
        await _channel.invokeMethod<bool>('open', {'path': source.path}) ??
        false;
    return MediaOpenResult(success: opened, message: opened ? null : '无法打开文件');
  }
}

abstract class VoicePlaybackController {
  Future<bool> play({String? localPath, String? remoteUrl});

  void dispose();
}

class NativeVoicePlaybackController implements VoicePlaybackController {
  NativeVoicePlaybackController({
    String baseUrl = AppConfig.apiBaseUrl,
    MethodChannel channel = const MethodChannel('app/voice_playback'),
  }) : _baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), ''),
       _channel = channel;

  final String _baseUrl;
  final MethodChannel _channel;

  @override
  Future<bool> play({String? localPath, String? remoteUrl}) async {
    final source = await _source(localPath: localPath, remoteUrl: remoteUrl);
    if (source == null) {
      return false;
    }

    return await _channel.invokeMethod<bool>('play', {'source': source}) ??
        true;
  }

  Future<String?> _source({String? localPath, String? remoteUrl}) async {
    final path = localPath;
    if (path != null && path.isNotEmpty && await File(path).exists()) {
      return path;
    }
    final url = remoteUrl;
    if (url == null || url.isEmpty) {
      return null;
    }
    return _absoluteUrl(url);
  }

  String _absoluteUrl(String url) {
    return _resolveAbsoluteUrl(url, baseUrl: _baseUrl);
  }

  @override
  void dispose() {
    _channel.invokeMethod<void>('stop');
  }
}

class MediaMessageTile extends StatefulWidget {
  const MediaMessageTile({
    required this.type,
    this.isVideo = false,
    this.title,
    this.localPath,
    this.remoteUrl,
    this.fileSizeBytes,
    this.duration,
    this.onTap,
    this.voicePlaybackController,
    this.mediaOpenController,
    super.key,
  });

  final MessageType type;
  final bool isVideo;
  final String? title;
  final String? localPath;
  final String? remoteUrl;
  final int? fileSizeBytes;
  final Duration? duration;
  final VoidCallback? onTap;
  final VoicePlaybackController? voicePlaybackController;
  final MediaOpenController? mediaOpenController;

  static const embeddedTextColor = Color(0xFF10201B);
  static const embeddedSecondaryTextColor = Color(0x990F1F1A);

  @override
  State<MediaMessageTile> createState() => _MediaMessageTileState();
}

class _MediaMessageTileState extends State<MediaMessageTile> {
  late final MediaOpenController _mediaOpenController =
      widget.mediaOpenController ?? NativeMediaOpenController();
  bool _opening = false;

  Future<void> _handleTap() async {
    widget.onTap?.call();
    if (widget.type == MessageType.image) {
      await _showImageViewer();
      return;
    }
    if (_opening) {
      return;
    }
    setState(() => _opening = true);
    try {
      final result = await _mediaOpenController.open(
        localPath: widget.localPath,
        remoteUrl: widget.remoteUrl,
        title: widget.title,
        isVideo: widget.isVideo,
      );
      if (!result.success && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result.message ?? '无法打开文件')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('无法打开文件')));
      }
    } finally {
      if (mounted) {
        setState(() => _opening = false);
      }
    }
  }

  Future<void> _showImageViewer() {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (context) {
        return Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  key: const Key('media-image-viewer'),
                  minScale: 0.7,
                  maxScale: 4,
                  child: Center(
                    child: _ImagePreview(
                      localPath: widget.localPath,
                      remoteUrl: widget.remoteUrl,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                right: 8,
                child: IconButton.filled(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final isVoice = widget.type == MessageType.voice;
    return InkWell(
      key: const Key('media-message-tile'),
      borderRadius: BorderRadius.circular(8),
      onTap: isVoice ? null : _handleTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: isVoice ? 132 : 180,
          maxWidth: isVoice ? 220 : 280,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isVoice ? 6 : 8,
            vertical: isVoice ? 4 : 8,
          ),
          child: switch (widget.type) {
            MessageType.image => _ImageTile(
              title: widget.title ?? 'Image',
              localPath: widget.localPath,
              remoteUrl: widget.remoteUrl,
              fileSizeBytes: widget.fileSizeBytes,
              color: color,
            ),
            MessageType.voice => _VoiceTile(
              localPath: widget.localPath,
              remoteUrl: widget.remoteUrl,
              duration: widget.duration,
              color: color,
              playbackController: widget.voicePlaybackController,
              onTap: widget.onTap,
            ),
            MessageType.file => _FileTile(
              title: widget.title ?? 'File',
              fileSizeBytes: widget.fileSizeBytes,
              color: color,
              isVideo: widget.isVideo,
              opening: _opening,
            ),
            _ => _FileTile(
              title: widget.title ?? 'Media',
              fileSizeBytes: widget.fileSizeBytes,
              color: color,
              isVideo: widget.isVideo,
              opening: _opening,
            ),
          },
        ),
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({
    required this.title,
    required this.localPath,
    required this.remoteUrl,
    required this.fileSizeBytes,
    required this.color,
  });

  final String title;
  final String? localPath;
  final String? remoteUrl;
  final int? fileSizeBytes;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _ImagePreview(
                key: const Key('media-image-preview'),
                localPath: localPath,
                remoteUrl: remoteUrl,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _TitleAndSize(title: title, fileSizeBytes: fileSizeBytes),
      ],
    );
  }
}

class _VoiceTile extends StatefulWidget {
  const _VoiceTile({
    required this.localPath,
    required this.remoteUrl,
    required this.duration,
    required this.color,
    required this.playbackController,
    required this.onTap,
  });

  final String? localPath;
  final String? remoteUrl;
  final Duration? duration;
  final Color color;
  final VoicePlaybackController? playbackController;
  final VoidCallback? onTap;

  @override
  State<_VoiceTile> createState() => _VoiceTileState();
}

class _VoiceTileState extends State<_VoiceTile> {
  late final VoicePlaybackController _playbackController =
      widget.playbackController ?? NativeVoicePlaybackController();
  late final bool _ownsController = widget.playbackController == null;
  bool _playing = false;

  @override
  void dispose() {
    if (_ownsController) {
      _playbackController.dispose();
    }
    super.dispose();
  }

  Future<void> _play() async {
    widget.onTap?.call();
    if (mounted) {
      setState(() => _playing = true);
    }
    try {
      final started = await _playbackController.play(
        localPath: widget.localPath,
        remoteUrl: widget.remoteUrl,
      );
      if (!started && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('语音文件不可用')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('语音播放失败')));
      }
    } finally {
      if (mounted) {
        setState(() => _playing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: widget.color,
          shape: const CircleBorder(),
          child: InkWell(
            key: const Key('voice-message-play-button'),
            customBorder: const CircleBorder(),
            onTap: _play,
            child: SizedBox.square(
              dimension: 30,
              child: Icon(
                _playing ? Icons.stop : Icons.play_arrow,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 20,
                child: CustomPaint(
                  painter: _VoiceWavePainter(color: widget.color),
                  child: const SizedBox.expand(),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _formatDuration(widget.duration),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  height: 1,
                  color: MediaMessageTile.embeddedSecondaryTextColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VoiceWavePainter extends CustomPainter {
  const _VoiceWavePainter({required this.color});

  final Color color;

  static const _bars = [7, 12, 18, 10, 20, 15, 8, 19, 12, 17, 9, 14];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.45)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    final gap = size.width / (_bars.length - 1);
    for (var index = 0; index < _bars.length; index += 1) {
      final height = _bars[index].toDouble().clamp(6, size.height);
      final x = index * gap;
      final centerY = size.height / 2;
      canvas.drawLine(
        Offset(x, centerY - height / 2),
        Offset(x, centerY + height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VoiceWavePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({
    required this.title,
    required this.fileSizeBytes,
    required this.color,
    required this.isVideo,
    required this.opening,
  });

  final String title;
  final int? fileSizeBytes;
  final Color color;
  final bool isVideo;
  final bool opening;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isVideo ? Icons.videocam_outlined : Icons.insert_drive_file,
          color: color,
          size: 36,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _TitleAndSize(title: title, fileSizeBytes: fileSizeBytes),
        ),
        if (opening) ...[
          const SizedBox(width: 8),
          SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: color),
          ),
        ],
      ],
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({
    required this.localPath,
    required this.remoteUrl,
    required this.fit,
    super.key,
  });

  final String? localPath;
  final String? remoteUrl;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final local = localPath;
    if (local != null && local.isNotEmpty && File(local).existsSync()) {
      return Image.file(
        File(local),
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: _errorBuilder,
      );
    }

    final remote = remoteUrl;
    if (remote != null && remote.isNotEmpty) {
      return Image.network(
        _resolveAbsoluteUrl(remote),
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (context, child, progress) {
          if (progress == null) {
            return child;
          }
          return const Center(
            child: SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: _errorBuilder,
      );
    }

    return _imageFallback(context);
  }

  Widget _errorBuilder(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) {
    return _imageFallback(context);
  }

  Widget _imageFallback(BuildContext context) {
    return Icon(
      Icons.image_not_supported_outlined,
      size: 44,
      color: Theme.of(context).colorScheme.primary,
    );
  }
}

class _TitleAndSize extends StatelessWidget {
  const _TitleAndSize({required this.title, required this.fileSizeBytes});

  final String title;
  final int? fileSizeBytes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: MediaMessageTile.embeddedTextColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _formatBytes(fileSizeBytes),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: MediaMessageTile.embeddedSecondaryTextColor,
          ),
        ),
      ],
    );
  }
}

String _formatDuration(Duration? duration) {
  if (duration == null) {
    return '--:--';
  }
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

String _formatBytes(int? bytes) {
  if (bytes == null) {
    return 'Unknown size';
  }
  if (bytes < 1024) {
    return '$bytes B';
  }
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String _resolveAbsoluteUrl(
  String url, {
  String baseUrl = AppConfig.apiBaseUrl,
}) {
  if (url.startsWith('http://') || url.startsWith('https://')) {
    return url;
  }
  final normalizedBaseUrl = baseUrl.replaceFirst(RegExp(r'/$'), '');
  final normalizedPath = url.startsWith('/') ? url : '/$url';
  return '$normalizedBaseUrl$normalizedPath';
}
