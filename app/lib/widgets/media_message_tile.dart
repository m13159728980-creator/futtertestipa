import 'dart:io';

import 'package:app/core/config/app_config.dart';
import 'package:app/models/message.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    final normalizedPath = url.startsWith('/') ? url : '/$url';
    return '$_baseUrl$normalizedPath';
  }

  @override
  void dispose() {
    _channel.invokeMethod<void>('stop');
  }
}

class MediaMessageTile extends StatelessWidget {
  const MediaMessageTile({
    required this.type,
    this.title,
    this.localPath,
    this.remoteUrl,
    this.fileSizeBytes,
    this.duration,
    this.onTap,
    this.voicePlaybackController,
    super.key,
  });

  final MessageType type;
  final String? title;
  final String? localPath;
  final String? remoteUrl;
  final int? fileSizeBytes;
  final Duration? duration;
  final VoidCallback? onTap;
  final VoicePlaybackController? voicePlaybackController;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final isVoice = type == MessageType.voice;
    return InkWell(
      key: const Key('media-message-tile'),
      borderRadius: BorderRadius.circular(8),
      onTap: isVoice ? null : onTap,
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
          child: switch (type) {
            MessageType.image => _ImageTile(
              title: title ?? 'Image',
              localPath: localPath,
              fileSizeBytes: fileSizeBytes,
              color: color,
            ),
            MessageType.voice => _VoiceTile(
              localPath: localPath,
              remoteUrl: remoteUrl,
              duration: duration,
              color: color,
              playbackController: voicePlaybackController,
              onTap: onTap,
            ),
            MessageType.file => _FileTile(
              title: title ?? 'File',
              fileSizeBytes: fileSizeBytes,
              color: color,
            ),
            _ => _FileTile(
              title: title ?? 'Media',
              fileSizeBytes: fileSizeBytes,
              color: color,
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
    required this.fileSizeBytes,
    required this.color,
  });

  final String title;
  final String? localPath;
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
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.image, size: 44),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('语音文件不可用')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('语音播放失败')),
        );
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
                  color: Colors.black54,
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

  static const _bars = [
    7,
    12,
    18,
    10,
    20,
    15,
    8,
    19,
    12,
    17,
    9,
    14,
  ];

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
  });

  final String title;
  final int? fileSizeBytes;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.insert_drive_file, color: color, size: 36),
        const SizedBox(width: 10),
        Expanded(
          child: _TitleAndSize(title: title, fileSizeBytes: fileSizeBytes),
        ),
      ],
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
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 2),
        Text(
          _formatBytes(fileSizeBytes),
          style: Theme.of(context).textTheme.labelSmall,
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
