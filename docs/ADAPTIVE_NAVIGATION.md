# FlowIt - Navigation Adaptative

## 🎯 Vue d'ensemble

FlowIt utilise une architecture de navigation adaptative qui s'ajuste automatiquement selon la taille de l'écran, offrant une expérience optimale sur desktop et mobile.

## 📱 Comportement par Plateforme

### Desktop (≥ 800px)
- **Sidebar fixe** : Navigation permanente à gauche (280px de largeur)
- **Contenu principal** : Zone de contenu principale à droite
- **Profile utilisateur** : Affiché en bas de la sidebar
- **Pas de drawer** : Navigation toujours visible

### Mobile (< 800px)
- **Drawer coulissant** : Navigation accessible via le menu hamburger
- **AppBar** : Titre de la section actuelle avec bouton menu
- **Plein écran** : Le contenu occupe tout l'écran
- **Fermeture auto** : Le drawer se ferme après sélection

## 🏗️ Architecture Technique

### Structure des Fichiers
```
lib/
├── presentation/
│   ├── widgets/
│   │   └── adaptive_app_layout.dart    # Layout principal adaptatif
│   └── screens/
│       ├── home/
│       │   └── home_screen.dart        # Écran "My Tasks"
│       ├── projects/
│       │   └── projects_screen.dart    # Écran "Projects"
│       └── settings/
│           └── settings_screen.dart    # Écran "Settings"
└── app.dart                           # Configuration du routeur
```

### Composants Principaux

#### 1. `AdaptiveAppLayout`
Widget principal qui gère le layout adaptatif :
- Détecte la taille d'écran (breakpoint: 800px)
- Affiche soit le layout desktop soit mobile
- Gère la navigation entre les destinations

#### 2. `AppDestination` enum
Définit les destinations disponibles :
- `myTasks` : Page d'accueil avec les tâches
- `projects` : Gestion des portefeuilles projet
- `settings` : Paramètres de l'application

#### 3. Shell Navigation avec go_router
Utilise `ShellRoute` pour maintenir le layout lors de la navigation :
```dart
ShellRoute(
  builder: (context, state, child) => AdaptiveAppLayout(...),
  routes: [
    GoRoute(path: '/', builder: (context, state) => HomeScreen()),
    GoRoute(path: '/settings', builder: (context, state) => SettingsScreen()),
  ],
)
```

## 🎨 Design System

### Sidebar Components

#### Header Section
- **Logo FlowIt** : Icône dashboard avec nom de l'app
- **Tagline** : "Project Management"
- **Hauteur** : 80px (desktop) / 100px (mobile)

#### Navigation Section
- **Titre** : "Navigation"
- **Items** : My Tasks, Settings
- **États** : Normal, Selected, Hover
- **Icônes** : Material Rounded

#### User Profile (Desktop seulement)
- **Avatar** : Première lettre du nom d'utilisateur
- **Nom** : Nom d'utilisateur du compte CalDAV
- **Serveur** : URL du serveur (tronquée)
- **Action** : Clic pour aller aux Settings

### Couleurs et Styles
- **Selected item** : Primary color avec background primaryContainer (alpha: 0.3)
- **Border radius** : 12px pour les éléments interactifs
- **Espacement** : Padding de 8px horizontal pour les items

## 🔄 Navigation Flow

### Flux Utilisateur Desktop
1. **Sidebar permanente** affichée à gauche
2. **Clic sur destination** → Changement du contenu principal
3. **Sélection visuelle** de l'item actif
4. **Profil utilisateur** accessible en bas

### Flux Utilisateur Mobile  
1. **AppBar** avec titre de la section et menu hamburger
2. **Clic menu** → Ouverture du drawer
3. **Sélection destination** → Fermeture drawer + navigation
4. **Contenu plein écran** affiché

## 📋 Routes Configurées

| Route | Destination | Écran | Description |
|-------|-------------|-------|-------------|
| `/` | MyTasks | HomeScreen | Tâches groupées par Today/Soon/Unregistered |

| `/settings` | Settings | SettingsScreen | Configuration de l'app |
| `/connect` | - | ConnectionScreen | Connexion CalDAV (hors shell) |
| `/project/:uid` | - | ProjectDetailScreen | Détail d'un projet (hors shell) |
| `/task/:uid` | - | TaskDetailScreen | Détail d'une tâche (hors shell) |

## 🛠️ Personnalisation

### Modifier le Breakpoint
```dart
static const double _desktopBreakpoint = 800.0; // Dans AdaptiveAppLayout
```

### Ajouter une Destination
1. **Ajouter à l'enum** `AppDestination`
2. **Implémenter les propriétés** (label, icon, route)
3. **Ajouter la route** dans `app.dart`
4. **Créer l'écran** correspondant

### Personnaliser la Sidebar
- **Largeur** : Modifier `width: 280` dans `SizedBox`
- **Header** : Personnaliser `_buildSidebarHeader()`
- **Sections** : Ajouter/modifier dans `_buildSidebar()`

## 🚀 Avantages

### UX Excellence
- **Cohérence** : Interface unifiée sur toutes les tailles d'écran
- **Performance** : Navigation fluide sans reconstruction complète
- **Accessibilité** : Navigation claire et prévisible

### DX (Developer Experience)
- **Maintenance** : Un seul layout pour toutes les plateformes
- **Extensibilité** : Facile d'ajouter de nouvelles destinations
- **Testabilité** : Logique centralisée et modulaire

### Material Design 3
- **Guidelines** : Respect des recommandations Material Design
- **Adaptive** : Utilise les breakpoints standard
- **Modern** : Icônes rounded et couleurs M3

## 🔄 Prochaines Étapes

1. **Liste des projets** : Afficher les vrais portefeuilles dans la sidebar
2. **FAB contextuels** : Boutons d'action flottants adaptés à chaque écran
3. **Breadcrumbs** : Navigation hiérarchique pour les écrans de détail
4. **Gestion d'état** : Mémoriser la sélection de navigation
5. **Animations** : Transitions fluides entre les destinations

---
*Documentation générée le : 2024-12-19*
*Version : FlowIt App v1.0.0* 