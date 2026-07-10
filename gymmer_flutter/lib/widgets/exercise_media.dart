/// Preview tiles and a full-screen viewer for exercise thumbnail and media.
/// Resolves app-owned relative paths (and freshly-picked absolute paths) to
/// files on disk; images pinch-zoom, videos play with a tap-to-play/pause
/// overlay and a scrubbable progress bar.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../data/media_storage.dart';
import '../theme/app_theme.dart';

/// Square preview tile for one media [path]. Images show the picture; videos
/// show a play glyph. When [openOnTap] is true (default) tapping opens the
/// full-screen [MediaViewerPage]; otherwise taps fall through to a parent
/// (e.g. a list row that opens an editor).
class ExerciseMediaThumb extends StatelessWidget {
  const ExerciseMediaThumb({
    super.key,
    required this.path,
    required this.isVideo,
    this.size = 44,
    this.openOnTap = true,
  });

  final String path;
  final bool isVideo;
  final double size;
  final bool openOnTap;

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: FutureBuilder<String?>(
        future: resolveExerciseMediaPath(path),
        builder: (context, snapshot) {
          final resolved = snapshot.data;
          if (isVideo || resolved == null) {
            return Icon(
              isVideo ? Icons.play_circle_outline : Icons.image_outlined,
              size: size * 0.5,
            );
          }
          return Image.file(
            File(resolved),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                Icon(Icons.broken_image_outlined, size: size * 0.5),
          );
        },
      ),
    );
    if (!openOnTap) return tile;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MediaViewerPage(path: path, isVideo: isVideo),
        ),
      ),
      child: tile,
    );
  }
}

/// Full-screen viewer: pinch-zoom images, tap-to-play/pause videos.
class MediaViewerPage extends StatefulWidget {
  const MediaViewerPage({super.key, required this.path, required this.isVideo});

  final String path;
  final bool isVideo;

  @override
  State<MediaViewerPage> createState() => _MediaViewerPageState();
}

class _MediaViewerPageState extends State<MediaViewerPage> {
  VideoPlayerController? _controller;
  String? _resolved;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final resolved = await resolveExerciseMediaPath(widget.path);
    if (!mounted) return;
    if (resolved == null) {
      setState(() => _error = 'File not found.');
      return;
    }
    if (!widget.isVideo) {
      setState(() => _resolved = resolved);
      return;
    }
    final controller = VideoPlayerController.file(File(resolved));
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();
    } catch (_) {
      await controller.dispose();
      if (mounted) setState(() => _error = 'Could not play this video.');
      return;
    }
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() {
      _resolved = resolved;
      _controller = controller;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _toggle() {
    final controller = _controller;
    if (controller == null) return;
    controller.value.isPlaying ? controller.pause() : controller.play();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, elevation: 0),
      body: Center(child: _body()),
    );
  }

  Widget _body() {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          _error!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    if (widget.isVideo) {
      final controller = _controller;
      if (controller == null) return const CircularProgressIndicator();
      return GestureDetector(
        onTap: _toggle,
        child: ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            return AspectRatio(
              aspectRatio: value.aspectRatio == 0 ? 16 / 9 : value.aspectRatio,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  VideoPlayer(controller),
                  if (!value.isPlaying)
                    const Icon(
                      Icons.play_arrow,
                      size: 72,
                      color: Colors.white70,
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: VideoProgressIndicator(
                      controller,
                      allowScrubbing: true,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }
    final resolved = _resolved;
    if (resolved == null) return const CircularProgressIndicator();
    return InteractiveViewer(
      maxScale: 5,
      child: Image.file(File(resolved)),
    );
  }
}
