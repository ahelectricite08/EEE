import '../../models/video_model.dart';

String liveCategoryTitle(String category) {
  switch (category) {
    case 'resume':
      return 'Résumés de matchs';
    case 'podcast':
      return 'Émissions et podcasts';
    case 'matchday':
      return 'Jour de match';
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
      return 'PODCAST';
    case 'matchday':
      return 'JOUR DE MATCH';
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
