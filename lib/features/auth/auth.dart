/// Public Auth feature API.
///
/// Other features / legacy screens should import this barrel (or the screens
/// re-exports under `lib/screens/`) — **not** `features/auth/data/**`.
library;

export 'domain/entities/auth_session.dart';
export 'domain/entities/auth_user.dart';
export 'domain/repositories/auth_repository.dart';
export 'presentation/auth_providers.dart';
export 'presentation/screens/login_screen.dart';
export 'presentation/screens/register_screen.dart';
