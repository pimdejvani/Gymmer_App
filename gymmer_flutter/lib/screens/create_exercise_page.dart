/// Create / Edit Exercise form: name, primary + secondary muscles, equipment,
/// live anatomy preview, thumbnail and media paths.
/// Pops the built Exercise; media files are copied into app-owned storage
/// on save (data/media_storage.dart).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/media_storage.dart';
import '../models.dart';
import '../theme/app_theme.dart';
import '../widgets/exercise_anatomy_panel.dart';
import '../widgets/exercise_media.dart';
import '../widgets/body_muscle_painter.dart';
import '../widgets/shared_widgets.dart';

class CreateExercisePage extends StatefulWidget {
  const CreateExercisePage({super.key, this.exercise});

  final Exercise? exercise;

  @override
  State<CreateExercisePage> createState() => _CreateExercisePageState();
}

class _CreateExercisePageState extends State<CreateExercisePage> {
  late final nameController = TextEditingController(
    text: widget.exercise?.name ?? '',
  );
  final _picker = ImagePicker();
  late String primaryMuscle = widget.exercise?.muscle ?? muscleMapNames.first;
  late final selectedSecondary = {...?widget.exercise?.secondaryMuscles};
  late String equipment = widget.exercise?.equipment ?? 'Dumbbell';
  late String? thumbnailPath = widget.exercise?.thumbnailPath;
  late final media = <ExerciseMedia>[...?widget.exercise?.media];
  bool saving = false;

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  static const _maxMedia = 5;
  static const _maxVideoDuration = Duration(minutes: 1);

  Future<void> _pickThumbnail() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    setState(() => thumbnailPath = file.path);
  }

  /// One picker for both images and videos. Caps the collection at [_maxMedia]
  /// and drops any video longer than [_maxVideoDuration].
  Future<void> _addMedia() async {
    final remaining = _maxMedia - media.length;
    if (remaining <= 0) {
      _showMessage('You can add up to $_maxMedia media items.');
      return;
    }
    final files = await _picker.pickMultipleMedia(limit: remaining);
    if (files.isEmpty || !mounted) return;

    final accepted = <ExerciseMedia>[];
    var skippedLong = 0;
    for (final file in files) {
      if (media.length + accepted.length >= _maxMedia) break;
      final isVideo =
          (file.mimeType?.startsWith('video/') ?? false) ||
          looksLikeVideo(file.path);
      if (isVideo) {
        final duration = await probeVideoDuration(file.path);
        if (duration != null && duration > _maxVideoDuration) {
          skippedLong++;
          continue;
        }
      }
      accepted.add(
        ExerciseMedia(
          path: file.path,
          type: isVideo ? ExerciseMediaType.video : ExerciseMediaType.image,
        ),
      );
    }
    if (!mounted) return;
    if (accepted.isNotEmpty) setState(() => media.addAll(accepted));
    if (skippedLong > 0) {
      _showMessage(
        skippedLong == 1
            ? 'Skipped 1 video longer than 1 minute.'
            : 'Skipped $skippedLong videos longer than 1 minute.',
      );
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> save() async {
    final name = nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter exercise name.')));
      return;
    }
    setState(() => saving = true);
    final storedThumbnail = thumbnailPath == null
        ? null
        : await copyExerciseMediaIntoAppStorage(
            thumbnailPath!,
            exerciseName: name,
            kind: 'thumbnail',
          );
    final storedMedia = <ExerciseMedia>[];
    for (final item in media) {
      storedMedia.add(
        ExerciseMedia(
          path: await copyExerciseMediaIntoAppStorage(
            item.path,
            exerciseName: name,
            kind: item.type.name,
          ),
          type: item.type,
        ),
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop(
      Exercise(
        name,
        primaryMuscle,
        equipment,
        selectedSecondary.toList(),
        storedThumbnail,
        List.unmodifiable(storedMedia),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = Exercise(
      nameController.text.trim().isEmpty
          ? 'New Exercise'
          : nameController.text.trim(),
      primaryMuscle,
      equipment,
      selectedSecondary.toList(),
      thumbnailPath,
      media,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.exercise == null ? 'Create Exercise' : 'Edit Exercise',
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => unawaited(save()),
            child: Text(saving ? 'Saving' : 'Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Exercise Name'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: primaryMuscle,
            decoration: const InputDecoration(labelText: 'Primary Muscle'),
            items: [
              for (final muscle in muscleMapNames)
                DropdownMenuItem(value: muscle, child: Text(muscle)),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                primaryMuscle = value;
                selectedSecondary.remove(value);
              });
            },
          ),
          const SizedBox(height: 14),
          Text(
            'Secondary Muscles',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final muscle in muscleMapNames.where(
                (item) => item != primaryMuscle,
              ))
                FilterChip(
                  label: Text(muscle),
                  selected: selectedSecondary.contains(muscle),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        selectedSecondary.add(muscle);
                      } else {
                        selectedSecondary.remove(muscle);
                      }
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: equipment,
            decoration: const InputDecoration(labelText: 'Equipment'),
            items: const [
              DropdownMenuItem(value: 'Bodyweight', child: Text('Bodyweight')),
              DropdownMenuItem(value: 'Dumbbell', child: Text('Dumbbell')),
              DropdownMenuItem(value: 'Cable', child: Text('Cable')),
              DropdownMenuItem(
                value: 'Smith Machine',
                child: Text('Smith Machine'),
              ),
              DropdownMenuItem(value: 'Machine', child: Text('Machine')),
              DropdownMenuItem(value: 'Barbell', child: Text('Barbell')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => equipment = value);
            },
          ),
          const SizedBox(height: 16),
          ExerciseAnatomyPanel(exercise: preview),
          const SizedBox(height: 16),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Thumbnail',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (thumbnailPath != null)
                      ExerciseMediaThumb(
                        key: ValueKey(thumbnailPath),
                        path: thumbnailPath!,
                        isVideo: false,
                      )
                    else
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceHigh,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.image_outlined, size: 20),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => unawaited(_pickThumbnail()),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(
                          thumbnailPath == null ? 'Choose Image' : 'Change Image',
                        ),
                      ),
                    ),
                    if (thumbnailPath != null)
                      IconButton(
                        tooltip: 'Remove thumbnail',
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => thumbnailPath = null),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Media',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    Text(
                      '${media.length}/$_maxMedia',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Up to $_maxMedia items · videos max 1 minute.',
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: media.length >= _maxMedia
                      ? null
                      : () => unawaited(_addMedia()),
                  icon: const Icon(Icons.perm_media_outlined),
                  label: const Text('Add Photos or Videos'),
                ),
                const SizedBox(height: 8),
                if (media.isEmpty)
                  const Text(
                    'No exercise images or videos selected.',
                    style: TextStyle(color: AppColors.textSecondary),
                  )
                else
                  for (var i = 0; i < media.length; i++)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ExerciseMediaThumb(
                        key: ValueKey(media[i].path),
                        path: media[i].path,
                        isVideo: media[i].type == ExerciseMediaType.video,
                        openOnTap: false,
                      ),
                      title: Text(
                        media[i].type == ExerciseMediaType.video
                            ? 'Video'
                            : 'Image',
                      ),
                      subtitle: Text(
                        media[i].type == ExerciseMediaType.video
                            ? 'Tap to play'
                            : 'Tap to view',
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MediaViewerPage(
                            path: media[i].path,
                            isVideo:
                                media[i].type == ExerciseMediaType.video,
                          ),
                        ),
                      ),
                      trailing: IconButton(
                        tooltip: 'Remove',
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => media.removeAt(i)),
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
