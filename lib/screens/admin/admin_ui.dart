/// Barrel design Admin — composants stables pour les écrans.
///
/// Alias : [AdminPageHeader], [AdminSection] (dans admin_module_shell),
/// [AdminSegmented] (= [AdminSegmentedControl]), [AdminField], [AdminPrimaryButton].
library;

export 'admin_components.dart' show AdminPrimaryButton, AdminSecondaryButton;
export 'admin_form_widgets.dart' show AdminField;
export 'admin_module_colors.dart';
export 'admin_module_shell.dart';
export 'admin_segmented_control.dart';

import 'admin_segmented_control.dart';

/// Alias — contrôle segmenté (filtres).
typedef AdminSegmented = AdminSegmentedControl;
