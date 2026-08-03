part of '../home_screen.dart';

mixin _HomeScreenHeroLiveMixin on _HomeScreenController {
  Widget _buildLiveHeroContent(List<Map<String, dynamic>> heroEvents) {
    if (_liveTeam1.isEmpty || _liveTeam2.isEmpty) return const SizedBox.shrink();

    final leftEvents = heroEvents.where((e) => e['isHomeSide'] == true).toList();
    final rightEvents = heroEvents.where((e) => e['isHomeSide'] != true).toList();

    final String minuteLabel;
    if (_isFulltime) {
      minuteLabel = 'FIN';
    } else if (_isExtraFulltime) {
      minuteLabel = 'FIN PROLONG.';
    } else if (_isHalftime) {
      minuteLabel = 'MI-TEMPS';
    } else if (_isExtraHalftime) {
      minuteLabel = 'MT PROLONG.';
    } else if (_isExtraTimePlaying) {
      minuteLabel = 'PROLONG.';
    } else if (_chronoRunning) {
      minuteLabel = _chronoDisplay;
    } else if (_liveMinute > 0) {
      minuteLabel = "$_liveMinute'";
    } else {
      minuteLabel = 'DIRECT';
    }

    Widget logoWidget(String? url) {
      return Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(55), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: (url != null && url.isNotEmpty)
            ? Padding(
                padding: const EdgeInsets.all(5),
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.sports_soccer_rounded, size: 22, color: Color(0xFF0A4438)),
                ),
              )
            : const Icon(Icons.sports_soccer_rounded, size: 22, color: Color(0xFF0A4438)),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── [STATS] [minute/statut] [COMPO] – centré ─────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bouton STATS (conditionnel)
            if (_liveStatsEnabled) ...[
              GestureDetector(
                onTap: () => _showLiveStats(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _kGreen.withAlpha(180),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withAlpha(35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bar_chart_rounded, size: 12, color: Colors.white.withAlpha(220)),
                      const SizedBox(width: 5),
                      Text('STATS', style: GoogleFonts.barlowCondensed(
                        fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5,
                      )),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            // Minute / statut (toujours affiché au centre)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(22),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withAlpha(50)),
              ),
              child: Text(
                minuteLabel,
                style: GoogleFonts.barlowCondensed(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            // Bouton COMPO (uniquement si toggle admin activé)
            if (_liveLineupOnCard) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _openCompoCard(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(22),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withAlpha(50)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.groups_rounded, size: 12, color: Colors.white.withAlpha(220)),
                    const SizedBox(width: 5),
                    Text(
                      'COMPO',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ], // end if _liveLineupOnCard
          ],
        ),
        const SizedBox(height: 10),
        // ── Logos + Score ────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  logoWidget(_liveLogo1),
                  const SizedBox(height: 5),
                  Text(
                    _liveTeam1.toUpperCase(),
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withAlpha(200),
                      height: 1.1,
                    ),
                  ),
                  _HeroSideCards(yellow: _yellowHome, red: _redHome, alignEnd: false),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '$_scoreHome – $_scoreAway',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 46,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -1.0,
                  height: 1.0,
                ),
              ),
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  logoWidget(_liveLogo2),
                  const SizedBox(height: 5),
                  Text(
                    _liveTeam2.toUpperCase(),
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withAlpha(200),
                      height: 1.1,
                    ),
                  ),
                  _HeroSideCards(yellow: _yellowAway, red: _redAway, alignEnd: false),
                ],
              ),
            ),
          ],
        ),
        // ── Événements ──────────────────────────────────────────────────
        if (heroEvents.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(height: 1, color: Colors.white.withAlpha(20)),
          const SizedBox(height: 5),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _HeroLiveEventsColumn(events: leftEvents, homeSide: true)),
                if (leftEvents.isNotEmpty && rightEvents.isNotEmpty)
                  Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    color: Colors.white.withAlpha(20),
                  ),
                Expanded(child: _HeroLiveEventsColumn(events: rightEvents, homeSide: false)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        // ── CTA ──────────────────────────────────────────────────────────
        Center(
          child: _matchStreamBroadcast
              ? GestureDetector(
                  onTap: () async {
                    final url = _liveUrl;
                    if (url != null && url.isNotEmpty) {
                      final clean = YoutubeParser.sanitizeShareUrl(url);
                      await launchUrl(Uri.parse(clean), mode: LaunchMode.externalApplication);
                    }
                  },
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 160),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      color: _kGold,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(color: _kGold.withAlpha(60), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 14),
                        const SizedBox(width: 5),
                        Text(
                          'REGARDER EN DIRECT',
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _radioLive
                  ? ListenableBuilder(
                      listenable: LiveRadioService.instance,
                      builder: (context, _) {
                        final radio = LiveRadioService.instance;
                        final listening = radio.isListening;
                        final connecting = radio.isConnecting;
                        return GestureDetector(
                          onTap: connecting
                              ? null
                              : () async {
                                  try {
                                    if (listening) {
                                      await radio.stop();
                                    } else {
                                      await radio.startListening();
                                    }
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    final msg = e
                                        .toString()
                                        .replaceFirst(RegExp(r'^[^:]+:\s*'), '');
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          msg.isEmpty
                                              ? 'Impossible de rejoindre la radio'
                                              : msg,
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        backgroundColor: _kRed,
                                      ),
                                    );
                                  }
                                },
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 160),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: listening ? Colors.white.withAlpha(22) : _kGold,
                              borderRadius: BorderRadius.circular(999),
                              border: listening
                                  ? Border.all(color: Colors.white.withAlpha(55))
                                  : null,
                              boxShadow: listening
                                  ? null
                                  : [
                                      BoxShadow(
                                        color: _kGold.withAlpha(60),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  connecting
                                      ? Icons.hourglass_top_rounded
                                      : listening
                                          ? Icons.stop_rounded
                                          : Icons.headphones_rounded,
                                  color: listening || connecting
                                      ? Colors.white
                                      : Colors.black,
                                  size: 14,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  connecting
                                      ? 'CONNEXION…'
                                      : listening
                                          ? 'EN DIRECT — AUDIO'
                                          : 'ÉCOUTER EN AUDIO',
                                  style: GoogleFonts.barlowCondensed(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: listening || connecting
                                        ? Colors.white
                                        : Colors.black,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(22),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white.withAlpha(55)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sports_soccer_rounded, size: 13, color: Colors.white.withAlpha(200)),
                          const SizedBox(width: 7),
                          Text(
                            'MATCH EN DIRECT · PAS DE VIDÉO',
                            style: GoogleFonts.barlowCondensed(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }

  // ── Filtres catégories – angulaires style sport ─────────────────────────────
}
