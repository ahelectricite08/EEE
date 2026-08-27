import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../models/match_partner_logos.dart';
import '../../../../models/souvenir_branding.dart';
import '../../../../services/match_partner_logos_service.dart';
import '../../../../widgets/match_souvenir_partner_logo_admin_panel.dart';
import '../../../../widgets/square_partner_logo_admin_slot.dart';
import '../../admin_palette.dart';

/// Admin — logos partenaires des cartes match (`Photos & réseaux`).
class MatchPartnerLogosAdminSection extends StatefulWidget {
  const MatchPartnerLogosAdminSection({super.key});

  @override
  State<MatchPartnerLogosAdminSection> createState() =>
      _MatchPartnerLogosAdminSectionState();
}

class _MatchPartnerLogosAdminSectionState
    extends State<MatchPartnerLogosAdminSection> {
  StreamSubscription<MatchPartnerLogos>? _sub;
  MatchPartnerLogos _logos = MatchPartnerLogos.defaults;
  bool _loading = true;
  bool _ratingBusy = false;
  bool _motmBusy = false;
  String? _ratingError;
  String? _motmError;

  @override
  void initState() {
    super.initState();
    _sub = MatchPartnerLogosService.instance.watch().listen((v) {
      if (!mounted) return;
      setState(() {
        _logos = v;
        _loading = false;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _run({
    required MatchPartnerLogoSlot slot,
    required Future<void> Function() action,
  }) async {
    setState(() {
      if (slot == MatchPartnerLogoSlot.matchRating) {
        _ratingBusy = true;
        _ratingError = null;
      } else {
        _motmBusy = true;
        _motmError = null;
      }
    });
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (slot == MatchPartnerLogoSlot.matchRating) {
          _ratingError = '$e';
        } else {
          _motmError = '$e';
        }
      });
    }
    if (!mounted) return;
    setState(() {
      if (slot == MatchPartnerLogoSlot.matchRating) {
        _ratingBusy = false;
      } else {
        _motmBusy = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PARTENAIRES MATCH',
          style: GoogleFonts.barlowCondensed(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: adminGold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Logos note du match et homme du match : le fichier garde ses '
          'proportions (pas de crop carré). Le souvenir reste en cadre carré. '
          'Au lancement du vote, le logo homme du match est repris '
          'automatiquement (surcharge possible).',
          style: GoogleFonts.inter(
            fontSize: 11,
            color: adminGrey,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'app_config/${MatchPartnerLogos.firestoreDocId} · '
          'app_config/${SouvenirBranding.firestoreDocId}',
          style: GoogleFonts.inter(fontSize: 10, color: adminGrey),
        ),
        const SizedBox(height: 14),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(
                color: adminGold,
                strokeWidth: 2,
              ),
            ),
          )
        else ...[
          SquarePartnerLogoAdminSlot(
            title: 'LOGO NOTE DU MATCH',
            hint:
                'Carte accueil après le match. PNG / JPG / WebP — large, '
                'haut ou carré : l’aperçu suit le ratio du fichier '
                '(max 88×220 ici, 56×112 sur la carte). Max ~2 Mo.',
            logoUrl: _logos.matchRatingLogoUrl,
            revisionMillis: _logos.revisionMillis,
            busy: _ratingBusy,
            error: _ratingError,
            lockSquare: false,
            onUpload: (picked) => _run(
              slot: MatchPartnerLogoSlot.matchRating,
              action: () async {
                if (picked.bytes.length >
                    MatchPartnerLogosService.maxFileBytes) {
                  throw StateError('Fichier trop lourd (max 2 Mo).');
                }
                await MatchPartnerLogosService.instance.uploadLogo(
                  slot: MatchPartnerLogoSlot.matchRating,
                  bytes: picked.bytes,
                  extension: picked.extension,
                );
              },
            ),
            onSaveUrl: (url) => _run(
              slot: MatchPartnerLogoSlot.matchRating,
              action: () => MatchPartnerLogosService.instance.setLogoUrl(
                slot: MatchPartnerLogoSlot.matchRating,
                url: url,
              ),
            ),
            onRemove: () => _run(
              slot: MatchPartnerLogoSlot.matchRating,
              action: () => MatchPartnerLogosService.instance.clearLogo(
                slot: MatchPartnerLogoSlot.matchRating,
                deleteStorageFile: true,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SquarePartnerLogoAdminSlot(
            title: 'LOGO HOMME DU MATCH',
            hint:
                'Logo par défaut du vote. Ratio réel du fichier (max 88×220 '
                'ici, 56×112 sur la carte). Le champ du vote reste une '
                'surcharge ponctuelle.',
            logoUrl: _logos.motmLogoUrl,
            revisionMillis: _logos.revisionMillis,
            busy: _motmBusy,
            error: _motmError,
            lockSquare: false,
            onUpload: (picked) => _run(
              slot: MatchPartnerLogoSlot.motm,
              action: () async {
                if (picked.bytes.length >
                    MatchPartnerLogosService.maxFileBytes) {
                  throw StateError('Fichier trop lourd (max 2 Mo).');
                }
                await MatchPartnerLogosService.instance.uploadLogo(
                  slot: MatchPartnerLogoSlot.motm,
                  bytes: picked.bytes,
                  extension: picked.extension,
                );
              },
            ),
            onSaveUrl: (url) => _run(
              slot: MatchPartnerLogoSlot.motm,
              action: () => MatchPartnerLogosService.instance.setLogoUrl(
                slot: MatchPartnerLogoSlot.motm,
                url: url,
              ),
            ),
            onRemove: () => _run(
              slot: MatchPartnerLogoSlot.motm,
              action: () => MatchPartnerLogosService.instance.clearLogo(
                slot: MatchPartnerLogoSlot.motm,
                deleteStorageFile: true,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        const MatchSouvenirPartnerLogoAdminPanel(),
      ],
    );
  }
}
