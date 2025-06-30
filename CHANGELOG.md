# Changelog FlowIt App

## [Unreleased] - 2024-12-19

### Added
- **Adaptive Navigation**: Architecture de navigation responsive et moderne
  - Desktop: Sidebar fixe à gauche (280px) avec contenu principal à droite
  - Mobile: Drawer coulissant avec navigation en plein écran
  - Breakpoint automatique à 800px pour basculer entre les modes
  - Header FlowIt avec logo, nom et tagline "Project Management"
  - Section navigation: My Tasks, Projects, Settings avec icônes Material Rounded
  - Section "Project Portfolios" avec bouton création et liste des portefeuilles
  - Profil utilisateur en bas (desktop) avec avatar, nom, serveur
  - Intégration go_router avec ShellRoute pour maintenir le layout
  - États de sélection visuels avec couleurs Material Design 3
- **Custom Project Portfolio Names**: L'utilisateur peut maintenant choisir le nom de son nouveau portefeuille projet
  - Dialogue de saisie avec nom et description personnalisables
  - Validation et nettoyage automatique des noms (caractères spéciaux, espaces)
  - Génération sécurisée des chemins de portefeuille
  - Valeurs par défaut intelligentes ("FlowIt Portfolio")
  - Support des caractères Unicode avec fallback approprié

### Fixed
- **Project Portfolio Creation**: Correction du problème de création de nouveaux portefeuilles projet CalDAV
  - Format XML MKCALENDAR corrigé selon RFC 4791
  - Ajout des en-têtes HTTP appropriés (`Content-Type: application/xml`)
  - Sections CDATA pour échapper les caractères spéciaux
  - Gestion améliorée des codes d'erreur (403, 409, etc.)
  - Normalisation automatique des chemins de portefeuille
  - Logging détaillé pour le debugging

### Updated
- **Dependencies**: Mise à jour vers les versions récentes
  - `flutter_riverpod`: ^2.4.9 → ^2.5.3
  - `go_router`: ^12.1.3 → ^14.6.2
  - `table_calendar`: ^3.0.9 → ^3.1.2
  - `flutter_markdown`: ^0.7.6+2 → ^0.7.3+2
  - `window_manager`: ^0.3.8 → ^0.4.2
  - `equatable`: ^2.0.5 → ^2.0.7
  - `freezed_annotation`: ^2.4.1 → ^2.4.4
  - `flutter_secure_storage`: ^9.0.0 → ^9.2.2
  - `logger`: ^2.0.2+1 → ^2.4.0
  - `rive`: ^0.13.7 → ^0.13.12
  - `path_provider`: ^2.1.2 → ^2.1.4
  - `shared_preferences`: ^2.5.3 → ^2.3.2
  - `xml`: ^6.3.0 → ^6.5.0
  - `http`: ^1.4.0 → ^1.2.2
  - `flutter_lints`: ^2.0.0 → ^5.0.0
  - `build_runner`: ^2.4.8 → ^2.4.12
  - `freezed`: ^2.4.6 → ^2.5.7
  - `json_serializable`: ^6.7.1 → ^6.8.0
  - `test`: ^1.25.2 → ^1.25.8

### Removed
- **Dependencies**: Suppression des paquets inutilisés
  - `cupertino_icons`: Remplacé par Material Icons rounded
  - `provider`: Remplacé par Riverpod
  - `remind_caldav_client`: Non utilisé dans la nouvelle architecture
  - `mocktail`: Doublons avec mockito

### Changed
- **UI Terminology**: Changement de terminologie dans l'interface utilisateur
  - "Calendar" → "Project Portfolio" dans tous les textes d'interface
  - "Create Calendar" → "Create Portfolio"
  - "FlowIt Tasks" → "FlowIt Portfolio" (nom par défaut)
  - "Task calendar created by FlowIt" → "Project portfolio created by FlowIt"
  - Icône calendrier → icône portefeuille (work_rounded) dans les dialogues
- **Icons**: Remplacement de toutes les icônes par leurs équivalents Material Rounded
  - `Icons.add` → `Icons.add_rounded`
  - `Icons.sync` → `Icons.sync_rounded`
  - `Icons.calendar_today` → `Icons.calendar_today_rounded`
  - `Icons.error` → `Icons.error_rounded`
  - `Icons.check_circle` → `Icons.check_circle_rounded`
  - `Icons.arrow_forward_ios` → `Icons.arrow_forward_ios_rounded`
  - `Icons.cloud` → `Icons.cloud_rounded`
  - `Icons.settings` → `Icons.settings_rounded`
  - Et tous les autres icônes dans la nouvelle architecture

### Technical
- **SDK**: Mise à jour de la version minimale Dart SDK vers 3.3.0
- **Architecture**: Toutes les modifications concernent uniquement la nouvelle architecture (`/lib/`)
- **Legacy Code**: Le dossier `/lib.old/` reste inchangé (code de référence)
- **Build**: Compilation Windows testée et validée
- **Tests**: 50 tests unitaires passent avec succès

### Files Modified
- `pubspec.yaml`: Mise à jour des dépendances
- `lib/app.dart`: Navigation adaptative avec ShellRoute + Icônes Material Rounded
- `lib/presentation/widgets/adaptive_app_layout.dart`: **NOUVEAU** - Layout adaptatif principal
- `lib/presentation/screens/projects/projects_screen.dart`: **NOUVEAU** - Écran des portefeuilles projet
- `lib/presentation/screens/home/home_screen.dart`: Adaptation au layout + Icônes Material Rounded
- `lib/presentation/screens/settings/settings_screen.dart`: Adaptation au layout + Icônes Material Rounded
- `lib/presentation/screens/task_detail/task_detail_screen.dart`: Icônes Material Rounded
- `lib/presentation/screens/project_detail/project_detail_screen.dart`: Icônes Material Rounded
- `lib/presentation/screens/connection/connection_screen.dart`: Icônes Material Rounded
- `lib/presentation/screens/connection/widgets/calendar_selection_screen.dart`: Icônes Material Rounded + Terminologie portfolios
- `lib/presentation/screens/connection/widgets/custom_caldav_dialog.dart`: Icônes Material Rounded

### Benefits
- **Performance**: Dépendances plus récentes avec optimisations
- **Security**: Versions récentes avec correctifs de sécurité
- **UI Consistency**: Icônes Material Rounded pour un design moderne et cohérent
- **Maintenance**: Suppression des dépendances inutilisées
- **Future-proof**: Compatibilité avec les versions récentes de Flutter 