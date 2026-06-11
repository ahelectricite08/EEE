import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  Future<void> openLink() async {
    final url = Uri.parse("https://www.helloasso.com/TON-LIEN");

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Accès Premium 🔥",
              style: TextStyle(color: Colors.white, fontSize: 28),
            ),

            const SizedBox(height: 20),

            const Text(
              "Live, Replay, Chat exclusif",
              style: TextStyle(color: Colors.white70),
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: openLink,
              child: const Text("S’abonner"),
            )
          ],
        ),
      ),
    );
  }
}