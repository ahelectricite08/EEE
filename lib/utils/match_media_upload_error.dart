import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Message FR pour échecs upload médias match (Storage / Firestore).
String matchMediaUploadErrorMessage(Object error) {
  if (FirebaseAuth.instance.currentUser == null) {
    return 'Session expirée — reconnecte-toi sur l’admin (compte admin / CM / statisticien).';
  }

  final code = error is FirebaseException ? error.code : '';
  final raw = error.toString().toLowerCase();
  if (error is StateError) {
    switch (error.message) {
      case 'not_authenticated':
        return 'Non connecté — ouvre l’admin et reconnecte-toi.';
      case 'video_too_large':
      case 'audio_too_large':
        return 'Fichier trop lourd (max 40 Mo vidéo / 15 Mo audio).';
      case 'video_file_missing':
      case 'audio_file_missing':
        return 'Fichier vide ou inaccessible.';
    }
  }
  final unauthorized = code == 'unauthorized'
      || code == 'permission-denied'
      || code == 'storage/unauthorized'
      || raw.contains('unauthorized')
      || raw.contains('permission-denied')
      || raw.contains('permission_denied');

  if (unauthorized) {
    return 'Accès refusé (Storage/Firestore). Vérifie que tu es connecté en admin, '
        'CM ou statisticien, puis déconnecte/reconnecte pour rafraîchir les droits.';
  }
  if (code == 'unauthenticated' || raw.contains('unauthenticated')) {
    return 'Non connecté — ouvre l’admin et reconnecte-toi.';
  }
  return 'Échec envoi : $error';
}

/// MIME + extension à partir du nom de fichier (web/mobile souvent faux ou vide).
({String contentType, String extension}) matchMediaTypeFromName(
  String fileName, {
  required bool isVideo,
}) {
  final name = fileName.toLowerCase().trim();
  if (isVideo) {
    if (name.endsWith('.mov') || name.endsWith('.qt')) {
      return (contentType: 'video/quicktime', extension: 'mov');
    }
    if (name.endsWith('.webm')) {
      return (contentType: 'video/webm', extension: 'webm');
    }
    if (name.endsWith('.m4v')) {
      return (contentType: 'video/mp4', extension: 'm4v');
    }
    return (contentType: 'video/mp4', extension: 'mp4');
  }
  if (name.endsWith('.mp3')) {
    return (contentType: 'audio/mpeg', extension: 'mp3');
  }
  if (name.endsWith('.aac')) {
    return (contentType: 'audio/aac', extension: 'aac');
  }
  if (name.endsWith('.webm') || name.endsWith('.ogg')) {
    return (contentType: 'audio/webm', extension: 'webm');
  }
  if (name.endsWith('.wav')) {
    return (contentType: 'audio/wav', extension: 'wav');
  }
  return (contentType: 'audio/mp4', extension: 'm4a');
}
