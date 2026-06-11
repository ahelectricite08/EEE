import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../home/home_palette.dart';

/// Lecteur PDF in-app (URL Firebase Storage).
class BenevolePdfScreen extends StatefulWidget {
  final String title;
  final String fileUrl;

  const BenevolePdfScreen({
    super.key,
    required this.title,
    required this.fileUrl,
  });

  @override
  State<BenevolePdfScreen> createState() => _BenevolePdfScreenState();
}

class _BenevolePdfScreenState extends State<BenevolePdfScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final uri = Uri.parse(widget.fileUrl);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: homeBg,
      appBar: AppBar(
        backgroundColor: homeBg,
        foregroundColor: homeText,
        elevation: 0,
        title: Text(
          widget.title,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(
                color: homeGreen,
                strokeWidth: 2,
              ),
            ),
        ],
      ),
    );
  }
}
