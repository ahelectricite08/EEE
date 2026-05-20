import 'package:flutter/material.dart';

import '../../../../widgets/powered_by_partner_encart.dart';

/// Encart partenaire onglet prono — config [app_config/powered_by_partner].
class PronoPoweredByEncart extends StatelessWidget {
  const PronoPoweredByEncart({super.key});

  @override
  Widget build(BuildContext context) {
    return const PoweredByPartnerEncart(slot: PoweredByEncartSlot.prono);
  }
}
