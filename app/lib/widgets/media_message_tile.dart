import 'package:app/models/message.dart';
import 'package:flutter/material.dart';

class MediaMessageTile extends StatelessWidget {
  const MediaMessageTile({
    required this.type,
    this.title,
    this.localPath,
    this.fileSizeBytes,
    this.duration,
    this.onTap,
    super.key,
  });

  final MessageType type;
  final String? title;
  final String? localPath;
  final int? fileSizeBytes;
  final Duration? duration;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return InkWell(
      key: const Key('media-message-tile'),
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 180, maxWidth: 280),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: switch (type) {
            MessageType.image => _ImageTile(
              title: title ?? 'Image',
              localPath: localPath,
              fileSizeBytes: fileSizeBytes,
              color: color,
            ),
            MessageType.voice => _VoiceTile(
              duration: duration,
              fileSizeBytes: fileSizeBytes,
              color: color,
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

class _VoiceTile extends StatelessWidget {
  const _VoiceTile({
    required this.duration,
    required this.fileSizeBytes,
    required this.color,
  });

  final Duration? duration;
  final int? fileSizeBytes;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.play_arrow, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: List.generate(
                  14,
                  (index) => Expanded(
                    child: Container(
                      height: (index.isEven ? 18 : 28).toDouble(),
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_formatDuration(duration)}  ${_formatBytes(fileSizeBytes)}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ],
    );
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
