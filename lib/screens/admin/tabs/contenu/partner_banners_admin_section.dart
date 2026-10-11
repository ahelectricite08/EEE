import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../services/partner_banners_service.dart';
import '../../../../utils/pick_image_bytes.dart';
import '../../../../widgets/dvcr_network_image.dart';
import '../../admin_form_widgets.dart';
import '../../admin_palette.dart';
import '../settings/settings_card.dart';

/// Admin — encarts partenaires (`app_config/partner_banners`), upload Storage.
class PartnerBannersAdminSection extends StatefulWidget {
  const PartnerBannersAdminSection({super.key});

  @override
  State<PartnerBannersAdminSection> createState() =>
      _PartnerBannersAdminSectionState();
}

class _PartnerBannersAdminSectionState
    extends State<PartnerBannersAdminSection> {
  StreamSubscription<PartnerBannerCatalog>? _sub;
  PartnerBannerCatalog _catalog = PartnerBannerCatalog.empty;
  bool _loading = true;
  bool _uploading = false;
  String _uploadSlot = 'home';
  String? _busyId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sub = PartnerBannersService.instance.watchCatalog().listen((c) {
      if (!mounted) return;
      setState(() {
        _catalog = c;
        _loading = false;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  String _errorLabel(Object e) {
    if (e is StateError) {
      return switch (e.message) {
        'banner_too_large' => 'Fichier trop lourd (800 Ko max).',
        'banner_format' => 'Format refusé — PNG, JPG ou WebP.',
        'banner_empty' => 'Fichier vide — réessaie.',
        'not_authenticated' => 'Connecte-toi pour uploader.',
        _ => 'Erreur : $e',
      };
    }
    return 'Erreur : $e';
  }

  Future<void> _upload() async {
    if (_uploading) return;
    late final PickedImageBytes picked;
    try {
      final result = await pickImageBytes(
        allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
      );
      if (result == null) return;
      picked = result;
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _errorLabel(e));
      return;
    }

    if (picked.bytes.length > PartnerBanner.maxFileBytes) {
      setState(() => _error = 'Fichier trop lourd (800 Ko max).');
      return;
    }

    final size = await PartnerBannersService.probeImageSize(picked.bytes);
    if (!mounted) return;
    if (size != null &&
        PartnerBanner.isWildlyOffRatio(
          size.width.toDouble(),
          size.height.toDouble(),
        )) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: adminCard,
          title: Text(
            'Ratio loin de 3:1',
            style: GoogleFonts.barlowCondensed(
              fontWeight: FontWeight.w900,
              color: adminTextPrimary,
            ),
          ),
          content: Text(
            'Fichier ${size.width}×${size.height} px. '
            'La spec c’est 1200×400 (3:1). L’app cadrera au centre dans '
            'un cadre 3:1 — le layout ne cassera pas, mais le visuel '
            'peut être coupé. Continuer ?',
            style: GoogleFonts.inter(fontSize: 13, color: adminGrey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Annuler',
                style: GoogleFonts.inter(color: adminGrey),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'Importer quand même',
                style: GoogleFonts.inter(
                  color: adminGold,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      await PartnerBannersService.instance.uploadBanner(
        bytes: picked.bytes,
        extension: picked.extension,
        slot: _uploadSlot,
        originalName: picked.name,
        pixelWidth: size?.width,
        pixelHeight: size?.height,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _errorLabel(e));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _delete(PartnerBanner banner) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: adminCard,
        title: Text(
          'Supprimer cet encart ?',
          style: GoogleFonts.barlowCondensed(
            fontWeight: FontWeight.w900,
            color: adminTextPrimary,
          ),
        ),
        content: Text(
          'Il disparaît de ${PartnerBanner.slotLabel(banner.slot)}. '
          'Si plus aucun encart n’est actif sur cet emplacement, '
          'l’ancienne URL Wix (Soutenez) peut réapparaître.',
          style: GoogleFonts.inter(fontSize: 13, color: adminGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: GoogleFonts.inter(color: adminGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Supprimer',
              style: GoogleFonts.inter(
                color: adminRed,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busyId = banner.id);
    try {
      await PartnerBannersService.instance.deleteBanner(banner);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _errorLabel(e));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: 'ENCARTS PARTENAIRES',
      icon: Icons.view_agenda_rounded,
      color: adminGold,
      child: _loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(
                  color: adminGold,
                  strokeWidth: 2,
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    PartnerBanner.specCopy,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: adminTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tu uploades le fichier ici — plus besoin de Wix pour '
                    'les dimensions. L’app affiche toujours un cadre 3:1 '
                    '(letterbox / recadrage centre), le layout ne saute pas. '
                    'Un encart actif par emplacement (le plus petit « ordre »). '
                    'Lien optionnel au tap. PNG / JPG / WebP.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: adminGrey,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Storage · ${PartnerBanner.storageFolder}/  ·  '
                    'Firestore · app_config/${PartnerBanner.firestoreDocId}',
                    style: GoogleFonts.inter(fontSize: 10, color: adminGrey),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Emplacement à l’import',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: adminGrey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final slot in PartnerBanner.slots)
                        ChoiceChip(
                          label: Text(
                            PartnerBanner.slotLabel(slot),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          selected: _uploadSlot == slot,
                          selectedColor: adminGold,
                          onSelected: (v) {
                            if (v) setState(() => _uploadSlot = slot);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _uploading ? null : _upload,
                      style: FilledButton.styleFrom(
                        backgroundColor: adminGold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: _uploading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Icon(Icons.upload_rounded, size: 18),
                      label: Text(
                        _uploading
                            ? 'IMPORT…'
                            : 'IMPORTER UN BANDEAU '
                                '(${PartnerBanner.slotLabel(_uploadSlot)})',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: GoogleFonts.inter(fontSize: 12, color: adminRed),
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (_catalog.isEmpty)
                    Text(
                      'Aucun encart pour l’instant — importe le premier '
                      '(${PartnerBanner.specCopy}). Tant que le catalogue '
                      'est vide, l’app peut encore afficher une URL Wix '
                      'saisie dans HelloAsso → Soutenez.',
                      style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
                    )
                  else
                    ...PartnerBanner.slots.map((slot) {
                      final list = _catalog.forSlot(slot);
                      if (list.isEmpty) return const SizedBox.shrink();
                      return _SlotGroup(
                        slot: slot,
                        banners: list,
                        busyId: _busyId,
                        onDelete: _delete,
                        onError: (e) => setState(() => _error = _errorLabel(e)),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

class _SlotGroup extends StatelessWidget {
  final String slot;
  final List<PartnerBanner> banners;
  final String? busyId;
  final Future<void> Function(PartnerBanner) onDelete;
  final void Function(Object e) onError;

  const _SlotGroup({
    required this.slot,
    required this.banners,
    required this.busyId,
    required this.onDelete,
    required this.onError,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            PartnerBanner.slotLabel(slot).toUpperCase(),
            style: GoogleFonts.barlowCondensed(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: adminTextPrimary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          for (final b in banners)
            _BannerCard(
              banner: b,
              busy: busyId == b.id,
              onDelete: () => onDelete(b),
              onError: onError,
            ),
        ],
      ),
    );
  }
}

class _BannerCard extends StatefulWidget {
  final PartnerBanner banner;
  final bool busy;
  final VoidCallback onDelete;
  final void Function(Object e) onError;

  const _BannerCard({
    required this.banner,
    required this.busy,
    required this.onDelete,
    required this.onError,
  });

  @override
  State<_BannerCard> createState() => _BannerCardState();
}

class _BannerCardState extends State<_BannerCard> {
  late final TextEditingController _link;
  late final TextEditingController _sort;
  late String _slot;
  late bool _active;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _link = TextEditingController(text: widget.banner.linkUrl);
    _sort = TextEditingController(text: '${widget.banner.sort}');
    _slot = widget.banner.slot;
    _active = widget.banner.active;
  }

  @override
  void didUpdateWidget(covariant _BannerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banner.id != widget.banner.id) {
      _link.text = widget.banner.linkUrl;
      _sort.text = '${widget.banner.sort}';
      _slot = widget.banner.slot;
      _active = widget.banner.active;
    }
  }

  @override
  void dispose() {
    _link.dispose();
    _sort.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await PartnerBannersService.instance.updateBanner(
        widget.banner.copyWith(
          linkUrl: _link.text.trim(),
          slot: _slot,
          sort: int.tryParse(_sort.text.trim()) ?? widget.banner.sort,
          active: _active,
        ),
      );
    } catch (e) {
      widget.onError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? get _ratioHint {
    final w = widget.banner.pixelWidthStored;
    final h = widget.banner.pixelHeightStored;
    if (w <= 0 || h <= 0) return null;
    if (!PartnerBanner.isWildlyOffRatio(w.toDouble(), h.toDouble())) {
      return '$w×$h px';
    }
    return '$w×$h px — loin de 1200×400 (3:1), recadré au centre';
  }

  @override
  Widget build(BuildContext context) {
    final off = _ratioHint != null &&
        widget.banner.pixelWidthStored > 0 &&
        PartnerBanner.isWildlyOffRatio(
          widget.banner.pixelWidthStored.toDouble(),
          widget.banner.pixelHeightStored.toDouble(),
        );
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: adminSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: adminBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: PartnerBanner.aspectRatio,
            child: DecoratedBox(
              decoration: const BoxDecoration(color: Color(0xFFEDE7D9)),
              child: DvcrNetworkImage(
                widget.banner.imageUrl,
                fit: BoxFit.contain,
                alignment: Alignment.center,
                width: double.infinity,
                cacheWidth: dvcrImageCacheWidth(context, 400),
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: adminGrey,
                  ),
                ),
              ),
            ),
          ),
          if (_ratioHint != null) ...[
            const SizedBox(height: 6),
            Text(
              _ratioHint!,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: off ? adminRed : adminGrey,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Switch(
                value: _active,
                activeThumbColor: adminGold,
                onChanged: widget.busy
                    ? null
                    : (v) {
                        setState(() => _active = v);
                        _save();
                      },
              ),
              Text(
                _active ? 'Actif' : 'Masqué',
                style: GoogleFonts.inter(fontSize: 12, color: adminGrey),
              ),
              const Spacer(),
              DropdownButton<String>(
                value: PartnerBanner.slots.contains(_slot) ? _slot : 'home',
                underline: const SizedBox.shrink(),
                style: GoogleFonts.inter(fontSize: 12, color: adminTextPrimary),
                items: [
                  for (final s in PartnerBanner.slots)
                    DropdownMenuItem(
                      value: s,
                      child: Text(PartnerBanner.slotLabel(s)),
                    ),
                ],
                onChanged: widget.busy
                    ? null
                    : (v) {
                        if (v == null) return;
                        setState(() => _slot = v);
                        _save();
                      },
              ),
            ],
          ),
          AdminField(
            ctrl: _link,
            label: 'Lien au tap (optionnel)',
            hint: 'https://…  vide = lien Soutenez / HelloAsso',
          ),
          const SizedBox(height: 8),
          AdminField(
            ctrl: _sort,
            label: 'Ordre (plus petit = affiché)',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.busy || _saving ? null : _save,
                  child: Text(
                    _saving ? '…' : 'Enregistrer lien / ordre',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: widget.busy ? null : widget.onDelete,
                child: Text(
                  'Suppr.',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: adminRed,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
