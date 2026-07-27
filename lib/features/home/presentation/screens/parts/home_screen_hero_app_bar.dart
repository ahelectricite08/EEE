part of '../home_screen.dart';

mixin _HomeScreenHeroAppBarMixin on _HomeScreenController {
  SliverAppBar _buildAppBarWithHero() {
    final session = ref.watch(authSessionProvider).asData?.value;
    final signedIn = session != null;
    final heroEvents = _heroPreviewEvents();

    return SliverAppBar(
      pinned: true,
      expandedHeight: 312,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
      ),
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 0,
      toolbarHeight: 52,
      // â"€â"€ Titre compact visible quand la photo est scrollée â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _IconBtn(
              icon: Icons.public_rounded,
              color: Colors.white,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SocialLinksScreen()),
              ),
            ),
            if (_isLive || _isEmissionLive) ...[
              const SizedBox(width: 10),
              Flexible(
                fit: FlexFit.loose,
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) => FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: _PulsingLiveBadge(pulse: _pulse.value),
                  ),
                ),
              ),
            ],
            const Spacer(),
            if (_userRole != null && _userRole != UserRole.supporter)
              _RolePill(role: _userRole!.displayName),
            const SizedBox(width: 4),
            _IconBtn(
              icon: Icons.search_rounded,
              onTap: () {
                final open = widget.onOpenGlobalSearch;
                if (open != null) {
                  open();
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const GlobalSearchScreen(),
                    ),
                  );
                }
              },
            ),
            const SizedBox(width: 10),
            _IconBtn(
              icon: !signedIn
                  ? Icons.person_outline_rounded
                  : Icons.person_rounded,
              color: signedIn ? const Color(0xFFC8A436) : null,
              onTap: () async {
                if (!signedIn) {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AuthLockScreen()),
                  );
                } else {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(
                        onSwitchMainTab: widget.onSwitchTab,
                      ),
                    ),
                  );
                }
                _loadRole();
              },
            ),
          ],
        ),
      ),
      // â"€â"€ Photo pleine largeur depuis le haut â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
      flexibleSpace: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
        clipBehavior: Clip.antiAlias,
        child: Stack(
        fit: StackFit.expand,
        children: [
          // Photo toujours visible (même quand collapsé)
          _homeBannerUrl != null && _homeBannerUrl!.isNotEmpty
              ? Image.network(
                  _homeBannerUrl!,
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -0.3),
                  errorBuilder: (context, error, stackTrace) => Image.asset(
                    'assets/images/IMG_0842.JPG',
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, -0.3),
                  ),
                )
              : Image.asset(
                  'assets/images/IMG_0842.JPG',
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -0.3),
                ),
          FlexibleSpaceBar(
            collapseMode: CollapseMode.parallax,
            background: GestureDetector(
              onTap: () async {
                if (_isLive && !_matchStreamBroadcast) return;
                final url = _isLive
                    ? _liveUrl
                    : (_isEmissionLive ? _emissionUrl : null);
                if (url != null && url.isNotEmpty) {
                  final clean = YoutubeParser.sanitizeShareUrl(url);
                  await launchUrl(
                    Uri.parse(clean),
                    mode: LaunchMode.externalApplication,
                  );
                } else if (!_isLive && !_isEmissionLive) {
                  _switchMain(1);
                }
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Photo de fond â€" stade du club recevant en live
                  if (_isLive && _liveTeam1.isNotEmpty)
                    StreamBuilder<String?>(
                      stream: _watchHomeStadiumHero(_liveTeam1),
                      builder: (context, snap) {
                        final stadiumUrl = snap.data;
                        if (stadiumUrl != null && stadiumUrl.isNotEmpty) {
                          return Image.network(
                            stadiumUrl,
                            fit: BoxFit.cover,
                            alignment: const Alignment(-1.0, 0.6),
                            errorBuilder: (context, error, stackTrace) => Image.asset(
                              'assets/images/3058CE18-B5A0-4297-91BD-C9F4034C0942.jpg',
                              fit: BoxFit.cover,
                              alignment: const Alignment(-1.0, 0.6),
                            ),
                          );
                        }
                        return Image.asset(
                          'assets/images/3058CE18-B5A0-4297-91BD-C9F4034C0942.jpg',
                          fit: BoxFit.cover,
                          alignment: const Alignment(-1.0, 0.6),
                        );
                      },
                    )
                  else
                    (_homeBannerUrl != null && _homeBannerUrl!.isNotEmpty && !_isEmissionLive)
                        ? Image.network(
                            _homeBannerUrl!,
                            fit: BoxFit.cover,
                            alignment: const Alignment(-1.0, 0.6),
                            errorBuilder: (context, error, stackTrace) => Image.asset(
                              'assets/images/IMG_0842.JPG',
                              fit: BoxFit.cover,
                              alignment: const Alignment(-1.0, 0.6),
                            ),
                          )
                        : Image.asset(
                            _isEmissionLive
                                ? 'assets/images/IMG_0377.JPG'
                                : 'assets/images/IMG_0842.JPG',
                            fit: BoxFit.cover,
                            alignment: const Alignment(-1.0, 0.6),
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: const Color(0xFF111111),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.sports_soccer_rounded,
                                      size: 48,
                                      color: _kRed.withAlpha(80),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'DVCR',
                                      style: GoogleFonts.barlowCondensed(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white38,
                                        letterSpacing: 4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                  // ── Gradient haut (toolbar lisible) ─────────────────────
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.center,
                          colors: [
                            Colors.black.withAlpha(170),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // ── Gradient bas (lisibilité contenu) ───────────────────
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withAlpha(_isLive ? 200 : 180),
                            Colors.black.withAlpha(_isLive ? 80 : 40),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.45, 0.75],
                        ),
                      ),
                    ),
                  ),
                  // ── Filigrane DVCR — watermark discret en permanence ────
                  if (!_isLive && !_isEmissionLive) ...[
                    Positioned(
                      top: -8,
                      right: -24,
                      child: Text(
                        'DVCR',
                        style: GoogleFonts.barlowCondensed(
                          fontSize: 160,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                          color: Colors.white.withAlpha(12),
                          letterSpacing: -4,
                          height: 0.85,
                        ),
                      ),
                    ),
                  ],
                  // ── Contenu dynamique en bas ─────────────────────────────
                  Positioned(
                    bottom: 18,
                    left: 16,
                    right: 16,
                    child: _isLive
                        ? _buildLiveHeroContent(heroEvents)
                        : _isEmissionLive
                        ? _buildEmissionHeroContent()
                        : _buildDefaultHeroContent(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  // ── Contenu hero : état par défaut ──────────────────────────────────────────
}
