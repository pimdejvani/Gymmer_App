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

  Future<void> _pickThumbnail() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    setState(() => thumbnailPath = file.path);
  }

  Future<void> _pickMedia(ExerciseMediaType type) async {
    final file = type == ExerciseMediaType.video
        ? await _picker.pickVideo(source: ImageSource.gallery)
        : await _picker.pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    setState(() => media.add(ExerciseMedia(path: file.path, type: type)));
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
                      child: Text(
                        thumbnailPath == null
                            ? 'No thumbnail selected.'
                            : 'Tap image to view',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textSecondary),
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
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => unawaited(_pickThumbnail()),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(
                    thumbnailPath == null ? 'Choose Image' : 'Change Image',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Media',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () =>
                          unawaited(_pickMedia(ExerciseMediaType.image)),
                      icon: const Icon(Icons.image),
                      label: const Text('Add Image'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          unawaited(_pickMedia(ExerciseMediaType.video)),
                      icon: const Icon(Icons.videocam),
                      label: const Text('Add Video'),
                    ),
                  ],
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
                        media[i].path.split(RegExp(r'[\\/]')).last,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        media[i].type == ExerciseMediaType.video
                            ? 'Video · tap to play'
                            : 'Image · tap to view',
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
