import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/admin/admin_form_widgets.dart';
import '../screens/admin/admin_module_colors.dart';
import '../screens/admin/admin_palette.dart';
import '../utils/pick_image_bytes.dart';
import '../utils/remote_image_url.dart';
import 'square_partner_logo.dart';

/// Upload + URL + aperçu logo partenaire match.
class SquarePartnerLogoAdminSlot extends StatefulWidget {
  final String title;
  final String hint;
  final String logoUrl;
  final int revisionMillis;
  final bool busy;
  final String? error;
  final Future<void> Function(PickedImageBytes picked) onUpload;
  final Future<void> Function(String url) onSaveUrl;
  final Future<void> Function() onRemove;
  final bool framed;
  /// `true` (souvenir) : aperçu carré croppé. `false` : ratio réel du fichier.
  final bool lockSquare;

  const SquarePartnerLogoAdminSlot({
    super.key,
    required this.title,
    required this.hint,
    required this.logoUrl,
    required this.revisionMillis,
    required this.busy,
    this.error,
    required this.onUpload,
    required this.onSaveUrl,
    required this.onRemove,
    this.framed = true,
    this.lockSquare = true,
  });

  @override
  State<SquarePartnerLogoAdminSlot> createState() =>
      _SquarePartnerLogoAdminSlotState();
}

class _SquarePartnerLogoAdminSlotState
    extends State<SquarePartnerLogoAdminSlot> {
  late final TextEditingController _urlCtrl;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(text: widget.logoUrl);
  }

  @override
  void didUpdateWidget(covariant SquarePartnerLogoAdminSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.logoUrl != widget.logoUrl &&
        _urlCtrl.text.trim() != widget.logoUrl.trim()) {
      _urlCtrl.text = widget.logoUrl;
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final picked = await pickImageBytes(
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
    );
    if (picked == null) return;
    await widget.onUpload(picked);
  }

  Future<void> _saveUrl() async {
    final url = _urlCtrl.text.trim();
    final warn = remoteImageAdminWarning(url);
    if (warn != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(warn), backgroundColor: adminRed),
      );
      return;
    }
    await widget.onSaveUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final accent = AdminModuleColors.contenu;
    final hasLogo = widget.logoUrl.trim().isNotEmpty;

    final body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.title.trim().isNotEmpty) ...[
            Text(
              widget.title,
              style: GoogleFonts.barlowCondensed(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: adminTextPrimary,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            widget.hint,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: adminGrey,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          SquarePartnerLogo(
            url: widget.logoUrl,
            revisionMillis: widget.revisionMillis,
            size: 88,
            lockSquare: widget.lockSquare,
            maxWidth: widget.lockSquare ? null : 220,
            maxHeight: 88,
            showEmptyPlaceholder: true,
            background: const Color(0xFFF5F2E9),
            borderColor: adminBorder,
          ),
          const SizedBox(height: 12),
          AdminField(
            ctrl: _urlCtrl,
            label: 'URL du logo',
            hint: 'https://… ou uploade un fichier',
          ),
          if (widget.error != null) ...[
            const SizedBox(height: 8),
            Text(
              widget.error!,
              style: GoogleFonts.inter(fontSize: 11, color: adminRed),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: widget.busy ? null : _pick,
                  icon: widget.busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.upload_rounded, size: 16),
                  label: Text(
                    hasLogo ? 'Changer le logo' : 'Uploader le logo',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: accent.withAlpha(80),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: widget.busy ? null : _saveUrl,
                style: OutlinedButton.styleFrom(
                  foregroundColor: adminTextPrimary,
                  side: const BorderSide(color: adminBorder),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'URL',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (hasLogo) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: widget.busy ? null : widget.onRemove,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: adminGrey,
                    side: const BorderSide(color: adminBorder),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Retirer',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      );

    if (!widget.framed) return body;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: adminCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: adminBorder),
      ),
      child: body,
    );
  }
}
