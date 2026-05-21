import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin_form_widgets.dart';
import '../../admin_palette.dart';

/// Annonce affichée sur l’écran Live TV quand il n’y a pas de direct.
class TvNextLiveSection extends StatefulWidget {
  const TvNextLiveSection({super.key});

  @override
  State<TvNextLiveSection> createState() => _TvNextLiveSectionState();
}

class _TvNextLiveSectionState extends State<TvNextLiveSection> {
  static final _tvRef =
      FirebaseFirestore.instance.collection('tv').doc('config');

  final _imageUrlCtrl = TextEditingController();
  final _dayCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  final _team1Ctrl = TextEditingController();
  final _team2Ctrl = TextEditingController();
  bool _enabled = true;
  bool _loading = true;
  bool _saving = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _imageUrlCtrl.dispose();
    _dayCtrl.dispose();
    _dateCtrl.dispose();
    _timeCtrl.dispose();
    _team1Ctrl.dispose();
    _team2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _status = null;
    });
    try {
      final snap = await _tvRef.get();
      final data = snap.data() ?? {};
      _enabled = data['nextLiveEnabled'] != false;
      _imageUrlCtrl.text = (data['nextLiveImageUrl'] ?? '').toString().trim();
      _dayCtrl.text = (data['nextLiveDay'] ?? '').toString().trim();
      _dateCtrl.text = (data['nextLiveDate'] ?? '').toString().trim();
      _timeCtrl.text = (data['nextLiveTime'] ?? '').toString().trim();
      _team1Ctrl.text = (data['nextLiveTeam1'] ?? '').toString().trim();
      _team2Ctrl.text = (data['nextLiveTeam2'] ?? '').toString().trim();
    } catch (e) {
      _status = 'Erreur lecture : $e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _status = null;
    });
    try {
      await _tvRef.set(
        {
          'nextLiveEnabled': _enabled,
          'nextLiveImageUrl': _imageUrlCtrl.text.trim(),
          'nextLiveDay': _dayCtrl.text.trim(),
          'nextLiveDate': _dateCtrl.text.trim(),
          'nextLiveTime': _timeCtrl.text.trim(),
          'nextLiveTeam1': _team1Ctrl.text.trim(),
          'nextLiveTeam2': _team2Ctrl.text.trim(),
          'nextLiveUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      if (mounted) {
        setState(() => _status = 'Prochain live enregistré pour l’écran TV.');
      }
    } catch (e) {
      if (mounted) setState(() => _status = 'Erreur : $e');
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: CircularProgressIndicator(color: adminGold, strokeWidth: 2),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PROCHAIN LIVE (ÉCRAN TV HORS DIRECT)',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: adminGold,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Photo de fond + jour, date, heure et affiche (équipe vs équipe). '
          'Visible quand il n’y a pas de direct sur l’app Android TV.',
          style: GoogleFonts.inter(fontSize: 11, color: adminGrey, height: 1.35),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: adminCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: adminBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _enabled,
                onChanged: _saving ? null : (v) => setState(() => _enabled = v),
                title: Text(
                  'Afficher l’annonce sur la TV',
                  style: GoogleFonts.inter(fontSize: 13, color: adminTextPrimary),
                ),
                activeThumbColor: adminGold,
              ),
              AdminField(
                ctrl: _imageUrlCtrl,
                label: 'URL photo de fond (HTTPS)',
                hint: 'Vide = bannière DVCR par défaut sur la TV',
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: AdminField(
                      ctrl: _dayCtrl,
                      label: 'Jour',
                      hint: 'ex. Samedi',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AdminField(
                      ctrl: _dateCtrl,
                      label: 'Date',
                      hint: 'ex. 23 mai 2026',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AdminField(
                      ctrl: _timeCtrl,
                      label: 'Heure',
                      hint: 'ex. 18h00 (obligatoire pour le compte à rebours TV)',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: AdminField(
                      ctrl: _team1Ctrl,
                      label: 'Équipe 1',
                      hint: 'ex. CSSA',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AdminField(
                      ctrl: _team2Ctrl,
                      label: 'Équipe 2',
                      hint: 'ex. FC Metz',
                    ),
                  ),
                ],
              ),
              if (_status != null) ...[
                const SizedBox(height: 10),
                Text(
                  _status!,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: _status!.startsWith('Erreur') ? adminRed : adminGreenAccent,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: adminGold,
                  foregroundColor: Colors.black,
                ),
                child: Text(
                  _saving ? 'Enregistrement…' : 'Enregistrer le prochain live',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
