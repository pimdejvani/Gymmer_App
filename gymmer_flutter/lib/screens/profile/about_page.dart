/// About + required anatomy license credits.
library;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';

const _appVersion = '0.1.0';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About GYMMER')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('GYMMER', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                const Text(
                  'Version $_appVersion',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                const SelectableText('GYMMER is free and non-commercial.'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Anatomy imagery credits',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 10),
                SelectableText(
                  'Upper/lower limb + skeleton sources: AnatomyTOOL / '
                  'University of Groningen — CC BY-SA 4.0.\n\n'
                  'Contains or derives from Open3DModel assets by AnatomyTOOL '
                  'and participating anatomy departments, licensed under '
                  'CC BY-SA. See https://anatomytool.org/open3dmodel.',
                ),
                SizedBox(height: 12),
                SelectableText(
                  'Thorax and abdomen — a few important muscles — '
                  'CC BY-NC-SA 4.0.\n'
                  'Source: Sketchfab\n'
                  'URL: https://sketchfab.com/3d-models/'
                  'thorax-and-abdomen-a-few-important-muscles-'
                  'a6831716a15540d1889efb57305572f8',
                ),
                SizedBox(height: 12),
                SelectableText(
                  'The generated anatomy images are derivatives of these '
                  'sources and inherit the terms.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SurfaceCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Open-source licenses'),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: AppColors.textTertiary,
                ),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'GYMMER',
                  applicationVersion: _appVersion,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
