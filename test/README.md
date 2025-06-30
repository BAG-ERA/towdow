# Tests Unitaires FlowIt CalDAV

## 📋 Vue d'ensemble

Ce dossier contient les tests unitaires et d'intégration pour vérifier le comportement de la découverte CalDAV selon le RFC 4791.

## 🧪 Tests Disponibles

### 1. `caldav_discovery_integration_test.dart`
Tests d'intégration qui vérifient la logique de découverte CalDAV sans dépendances externes :

- **Parsing XML** : Validation du parsing des réponses PROPFIND
  - `current-user-principal`
  - `calendar-home-set` 
  - Listes de calendriers avec filtrage des status 200 OK
- **Construction d'URLs** : Gestion des chemins absolus vs relatifs
- **Conformité RFC 4791** : Séquence de découverte en 3 étapes
- **Gestion d'erreurs** : Réponses malformées, codes d'erreur HTTP
- **Filtrage de calendriers** : Identification des calendriers supportant VTODO

### 2. `services/caldav_service_test.dart` (Préparé)
Tests unitaires mocqués pour CalDAVService :
- Découverte complète RFC 4791 avec serveur mocké
- Test de connexion basique  
- Gestion des erreurs réseau
- Différents types de serveurs (Nextcloud, Radicale)

### 3. `widgets/calendar_selection_screen_test.dart` (Préparé)
Tests de widgets pour l'interface de sélection de calendriers :
- État de chargement
- Affichage des calendriers découverts
- Option de création de nouveau calendrier
- Sélection/désélection des calendriers

## 🏃 Lancer les Tests

```bash
# Tous les tests
flutter test

# Test spécifique
flutter test test/caldav_discovery_integration_test.dart

# Tests avec verbose
flutter test --verbose

# Tests de performance  
flutter test --platform chrome
```

## ✅ Scénarios Testés

### RFC 4791 Compliance
- [x] Séquence PROPFIND en 3 étapes
- [x] Parsing des réponses XML multi-status
- [x] Filtrage des réponses 200 OK uniquement
- [x] Gestion des chemins absolus/relatifs

### Serveurs Supportés
- [x] Nextcloud (séquence standard)
- [x] Radicale (calendar-home-set direct)
- [x] Serveurs avec principal inexistant
- [x] Réponses malformées

### Interface Utilisateur  
- [x] État de chargement pendant découverte
- [x] Affichage des calendriers trouvés
- [x] Option "Créer nouveau calendrier"
- [x] Sélection multiple de calendriers

### Gestion d'Erreurs
- [x] Timeouts réseau
- [x] Codes d'erreur HTTP (401, 403, 404, 500)
- [x] XML malformé
- [x] Principales manquantes

## 🎯 Métriques de Couverture

Les tests couvrent :
- **Logique métier** : Parsing XML, construction URLs, séquence RFC
- **Interface utilisateur** : États de chargement, sélection, navigation
- **Robustesse** : Cas d'erreur, serveurs non-conformes
- **Performance** : Pas de boucles infinies, timeouts appropriés

## 🔧 Mock Strategy

Les tests utilisent une approche hybride :
- **Tests logiques purs** : Pas de mocks, test des algorithmes directement
- **Tests service** : Mocks HTTP pour simuler différents serveurs
- **Tests UI** : Widgets tests avec données prédéfinies

Cette approche garantit :
- **Rapidité** des tests (pas de réseau réel)
- **Reproductibilité** (pas de dépendance externe)
- **Couverture complète** (tous les cas edge testés)

## 📊 Validation Contre Production

Ces tests valident le comportement observé en production contre :
- Serveur Radicale (utilisé dans l'exemple réel)
- Réponses XML exactes du serveur
- Séquence de découverte RFC 4791 complète

Quand la découverte fonctionne en production, ces tests devraient tous passer ! ✅ 