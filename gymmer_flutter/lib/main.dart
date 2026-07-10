import 'package:flutter/material.dart';

import 'data/workout_store.dart';
import 'screens/workout_home_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const GymmerApp());
}

class GymmerApp extends StatelessWidget {
  const GymmerApp({super.key, this.store});

  final WorkoutStore? store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GYMMER',
      debugShowCheckedModeBanner: false,
      theme: buildGymmerTheme(),
      home: GymmerHome(store: store),
    );
  }
}
