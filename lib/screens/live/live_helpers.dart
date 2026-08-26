import 'package:flutter/material.dart';

import '../../models/video_model.dart';

int tvImageCacheWidth(BuildContext context, double logicalPx) {
  final logical = logicalPx.isFinite && logicalPx > 0 ? logicalPx : 176;
  return (logical * MediaQuery.devicePixelRatioOf(context))
      .round()
      .clamp(160, 1440);
}

/// Thumb YouTube 16:9 croppée en carte 9:16 (`BoxFit.cover`) :
/// [cacheWidth] doit suivre la *hauteur* affichée, pas la largeur ~120 px.
int tvShortsImageCacheWidth(BuildContext context, double logicalWidth) {
  final logical = logicalWidth.isFinite && logicalWidth > 0 ? logicalWidth : 124;
  final dpr = MediaQuery.devicePixelRatioOf(context);
  final needed = logical * (16 / 9) * (16 / 9) * dpr;
  return needed.round().clamp(480, 1280);
}

String liveCategoryTitle(String category) {
  switch (category) {
    case 'resume':
      return 'Résumés de matchs';
    case 'podcast':
      return 'Émissions et podcasts';
    case 'matchday':
      return 'Jour de match';
    case 'shorts':
      return 'En 60 secondes';
    case 'all':
    default:
      return 'Dernières vidéos';
  }
}

String liveCategoryPill(String category) {
  switch (category) {
    case 'resume':
      return 'RÉSUMÉ';
    case 'podcast':
      return 'ÉMISSION';
    case 'matchday':
      return 'JOUR DE MATCH';
    case 'shorts':
      return 'SHORT';
    case 'all':
    default:
      return 'DVCR TV';
  }
}

String liveDateLabel(DateTime date) {
  final now = DateTime.now();
  final diff = now.difference(date);
  if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
  if (diff.inDays == 1) return 'Hier';
  if (diff.inDays < 7) return 'Il y a ${diff.inDays} jours';
  const months = [
    'jan',
    'fév',
    'mar',
    'avr',
    'mai',
    'juin',
    'juil',
    'aoû',
    'sep',
    'oct',
    'nov',
    'déc',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String liveVideoMeta(VideoModel video) {
  final duration = video.duration.trim();
  final date = liveDateLabel(video.date);
  if (duration.isEmpty) return date;
  return '$duration · $date';
}
