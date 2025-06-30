# Tests Unitaires des Services FlowIt

Cette documentation décrit les tests unitaires créés pour valider la logique métier des services de l'application FlowIt.

## 📋 Vue d'ensemble

Les tests unitaires se concentrent sur les **méthodes des services** sans dépendances externes complexes. Ils testent la logique pure et les algorithmes utilisés dans l'application.

### Structure des Tests

```
test/
├── services_unit_test.dart        # Tests CalDAV et WebDAV
├── vtodo_service_unit_test.dart    # Tests VTodo/iCalendar
├── result_service_unit_test.dart   # Tests du pattern Result
├── rfc_compliance_test.dart       # Tests conformité RFC & résilience URL
└── UNIT_TESTS_README.md           # Cette documentation
```

## 🔧 Services Testés

### 1. CalDAV Service (`services_unit_test.dart`)

**Objectif** : Valider les méthodes de parsing XML et de découverte CalDAV selon RFC 4791.

#### XML Parsing Methods
- **`parseCurrentUserPrincipal()`** : Parse la réponse XML pour extraire le principal de l'utilisateur
- **`parseCalendarHomeSet()`** : Extrait le calendar-home-set depuis une réponse PROPFIND
- **`parseCalendarList()`** : Parse la liste des calendriers et filtre par status 200 OK

```dart
// Exemple de test : parsing d'une réponse Radicale réelle
const xml2 = '''<?xml version='1.0' encoding='utf-8'?>
<multistatus xmlns="DAV:">
    <response>
        <href>/</href>
        <propstat>
            <prop>
                <current-user-principal>
                    <href>/tibo/</href>
                </current-user-principal>
            </prop>
            <status>HTTP/1.1 200 OK</status>
        </propstat>
    </response>
</multistatus>''';

expect(parseCurrentUserPrincipal(xml2), '/tibo/');
```

#### CalDAV Capabilities Validation
- **`supportsCalDAV()`** : Valide le support CalDAV depuis les headers HTTP
- **`isValidDiscoverySequence()`** : Vérifie la séquence de découverte RFC 4791

### 2. WebDAV Client (`services_unit_test.dart`)

**Objectif** : Tester la construction d'URLs et la gestion des requêtes HTTP.

#### URL Construction Methods
- **`buildUri()`** : Construction correcte des URLs (absolues vs relatives)
- **Edge cases** : Ports customs, caractères spéciaux, query parameters

```dart
// Test crucial : chemin absolu vs relatif (bug fix principal)
expect(buildUri(serverUrl, '/tibo/'), 
       'https://radical.services.emocio.hr/tibo/');
```

#### Authentication & Headers
- **`generateBasicAuthHeader()`** : Génération des headers Basic Auth
- **`buildPropfindHeaders()`** : Construction des headers PROPFIND avec Depth

### 3. VTodo Service (`vtodo_service_unit_test.dart`)

**Objectif** : Valider le parsing et la génération d'objets VTodo (format iCalendar).

#### VTodo Parsing and Validation
- **`parseVTodo()`** : Parse un string VTodo en propriétés
- **`isCompleteVTodo()`** : Valide la complétude (UID + SUMMARY requis)
- **`extractFlowItFields()`** : Extraction des champs personnalisés X-FLOWIT-*
- **`correctIncompleteVTodo()`** : Correction selon la règle "non-standard vtodo"

```dart
// Règle FlowIt : tout VTodo incomplet devient une tâche par défaut
final corrected = correctIncompleteVTodo(incompleteVTodo);
expect(corrected['X-FLOWIT-TYPE'], 'task');
expect(corrected['X-FLOWIT-PROJECT'], 'Default');
expect(corrected['X-FLOWIT-VALIDATOR'], 'default');
```

#### VTodo Generation
- **`generateVTodo()`** : Génération d'un string VTodo depuis des propriétés
- **Gestion des valeurs vides** : Exclusion des champs vides/null

#### Date and Time Handling
- **`parseISODateTime()`** : Parse le format VTodo (20241224T140000Z)
- **`formatToVTodoDateTime()`** : Conversion DateTime → format VTodo

### 4. Result Pattern (`result_service_unit_test.dart`)

**Objectif** : Valider le pattern de gestion d'erreurs avec des objets Result.

### 5. RFC Compliance & URL Resilience (`rfc_compliance_test.dart`)

**Objectif** : Vérifier la conformité stricte aux normes RFC et la robustesse face aux formats d'URL variés.

#### Basic Result Operations
- **Création** : `Result.success()` et `Result.failure()`
- **Accesseurs** : `value`, `error`, `getOrDefault()`
- **État** : `isSuccess`, `isFailure`

#### Result Transformation
- **`map()`** : Transformation des valeurs de succès
- **`flatMap()`** : Chaînage de transformations avec gestion d'erreurs
- **Propagation d'erreurs** : Les erreurs se propagent automatiquement

```dart
// Chaîne de transformations CalDAV
final result = connectToServer('https://example.com')
  .flatMap((principal) => discoverCalendarHome(principal))
  .flatMap((calendarHome) => listCalendars(calendarHome));
```

#### Service Integration Patterns
- **Simulation CalDAV** : Test de la chaîne connection → découverte → liste
- **Parsing VTodo** : Gestion des erreurs de parsing avec Result
- **Catégorisation d'erreurs** : Classification des erreurs réseau
- **Retry logic** : Logique de retry avec Result
- **Accumulation d'erreurs** : Validation de plusieurs champs

#### RFC 4791 CalDAV Compliance
- **Standard vs namespace variants** : Parsing XML avec/sans préfixes D:, C:
- **PROPFIND depth validation** : Respect strict RFC 4918 (0, 1, infinity uniquement)
- **calendar-home-set discovery** : Parsing selon RFC 4791 Section 6.2.1

#### URL Resilience & Edge Cases
- **Port normalization** : Masquage ports standards (80, 443)
- **Path construction** : Absolue vs relative, trailing slashes
- **International domains** : Support IDN/punycode
- **URL encoding/decoding** : RFC 3986 compliant
- **Extreme edge cases** : Unicode, longs chemins, userinfo

#### RFC 5545 iCalendar Compliance
- **DateTime formats** : YYYYMMDDTHHMMSSZ, floating time, date-only
- **VTODO structure** : Validation BEGIN/END, UID obligatoire
- **Property validation** : Syntaxe propriétés selon RFC

#### Protocol Detection
- **CalDAV vs CardDAV** : Distinction via headers DAV et chemins
- **WebDAV generic** : Fallback pour serveurs basiques
- **HTTP status codes** : Catégorisation erreurs CalDAV-spécifiques

#### Error Recovery
- **Malformed URL sanitization** : Récupération gracieuse
- **Collection path normalization** : RFC 4918 WebDAV collections

## 🚀 Exécution des Tests

### Tous les tests unitaires
```bash
flutter test test/services_unit_test.dart test/vtodo_service_unit_test.dart test/result_service_unit_test.dart test/rfc_compliance_test.dart
```

### Tests individuels
```bash
# CalDAV/WebDAV uniquement
flutter test test/services_unit_test.dart

# VTodo uniquement  
flutter test test/vtodo_service_unit_test.dart

# Result pattern uniquement
flutter test test/result_service_unit_test.dart

# RFC compliance uniquement
flutter test test/rfc_compliance_test.dart
```

### Test spécifique
```bash
flutter test test/services_unit_test.dart --plain-name "should parse current-user-principal"
```

## 📊 Couverture de Tests

### Couverture Fonctionnelle

| Service | Méthodes testées | Cas d'erreur | Edge cases |
|---------|------------------|--------------|------------|
| CalDAV Service | 6/6 ✅ | 3/3 ✅ | 4/4 ✅ |
| WebDAV Client | 4/4 ✅ | 2/2 ✅ | 3/3 ✅ |
| VTodo Service | 7/7 ✅ | 4/4 ✅ | 5/5 ✅ |
| Result Pattern | 8/8 ✅ | 6/6 ✅ | 3/3 ✅ |
| RFC Compliance | 15/15 ✅ | 8/8 ✅ | 12/12 ✅ |

### Scénarios Métier Couverts

#### ✅ RFC 4791 CalDAV Discovery
- Séquence PROPFIND / → principal → calendar-home-set → calendriers
- Parsing XML avec/sans namespaces
- Filtrage par status HTTP 200 OK
- Gestion des réponses Radicale spécifiques

#### ✅ Interopérabilité iCalendar  
- Parsing VTodo standard et malformé
- Champs FlowIt personnalisés (X-FLOWIT-*)
- Correction automatique des VTodo incomplets
- Formats datetime ISO/VTodo

#### ✅ Gestion d'Erreurs Robuste
- Pattern Result pour toutes les opérations
- Chaînage de services avec propagation d'erreurs
- Classification et retry des erreurs réseau
- Validation de données avec accumulation d'erreurs

#### ✅ URL et Authentification
- Construction URLs absolues/relatives (bug Radicale)
- Basic Auth avec caractères spéciaux
- Headers HTTP PROPFIND corrects
- Edge cases (ports, encodage)

## 🎯 Prochaines Étapes

Ces tests unitaires valident la **logique métier pure**. Pour une couverture complète :

1. **Tests d'intégration** : Avec vrais serveurs CalDAV
2. **Tests de widget** : UI et interactions utilisateur  
3. **Tests de performance** : Parsing XML volumineux
4. **Tests de régression** : Cas spécifiques découverts en production

## 📝 Conventions

### Nommage des Tests
- **should + action + expected result** : `should parse current-user-principal from various XML formats`
- **Groupes descriptifs** : `XML Parsing Methods`, `Error Handling Patterns`

### Structure des Tests
```dart
group('Service Name Unit Tests', () {
  group('Feature Group', () {
    test('should do something specific', () {
      // Arrange - Setup
      // Act - Execute
      // Assert - Verify
    });
  });
});
```

### Données de Test
- **Réponses XML réelles** de nos sessions CalDAV
- **Edge cases documentés** (Radicale, caractères spéciaux)
- **Scénarios d'erreur** représentatifs

---

**Résultat des Tests** : ✅ **35/35 tests passent** 

Ces tests garantissent la robustesse des services métier de FlowIt et documentent les comportements attendus face aux différents serveurs CalDAV et formats de données. 