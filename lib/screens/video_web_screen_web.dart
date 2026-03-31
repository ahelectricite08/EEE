import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/video_model.dart';

const _kBg  = Color(0xFF0A0A0A);
const _kRed = Color(0xFFBA203C);

// Sur web : ouvre YouTube dans un nouvel onglet
class VideoWebScreen extends StatelessWidget {
  final VideoModel video;
  const VideoWebScreen({super.key, required this.video});

  @override
  Widget build(BuildContext context) {
    // Lance directement YouTube et ferme l'écran
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await launchUrl(
        Uri.parse('https://www.youtube.com/watch?v=${video.youtubeId}'),
        mode: LaunchMode.externalApplication,
      );
      if (context.mounted) Navigator.pop(context);
    });
    return const Scaffold(
      backgroundColor: _kBg,
      body: Center(child: CircularProgressIndicator(color: _kRed)));
  }
}
