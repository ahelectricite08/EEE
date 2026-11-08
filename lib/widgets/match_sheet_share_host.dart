import 'package:flutter/material.dart';

/// Ancien hôte auto-popup feuille de match — plus de présentation.
/// Reste dans le bootstrap (shrink) pour ne pas casser le câblage.
class MatchSheetShareHost extends StatelessWidget {
  const MatchSheetShareHost({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
