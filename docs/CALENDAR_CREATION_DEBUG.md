# Guide de débogage - Création de calendrier CalDAV

## Problème : La création de nouveaux calendriers échoue

### Corrections apportées

1. **Format XML MKCALENDAR corrigé**
   - Ajout des sections CDATA pour échapper les caractères spéciaux
   - Ajout de la déclaration `resourcetype` avec `collection` et `calendar`
   - Respect strict du RFC 4791 Section 5.3.1

2. **En-têtes HTTP améliorés**
   - Ajout de `Content-Type: application/xml; charset=utf-8` pour MKCALENDAR
   - Normalisation des chemins de calendrier (ajout du `/` final)

3. **Gestion d'erreur améliorée**
   - Support des codes de statut 200, 201, 204 pour le succès
   - Gestion spécifique des erreurs 403 (permission) et 409 (conflit)
   - Logging détaillé pour le debugging

4. **Validation des chemins**
   - Normalisation automatique des chemins de calendrier
   - Validation de la structure des URL

### Structure XML MKCALENDAR corrigée

```xml
<?xml version="1.0" encoding="utf-8"?>
<C:mkcalendar xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
  <D:set>
    <D:prop>
      <D:displayname><![CDATA[FlowIt Tasks]]></D:displayname>
      <D:resourcetype>
        <D:collection/>
        <C:calendar/>
      </D:resourcetype>
      <C:supported-calendar-component-set>
        <C:comp name="VTODO"/>
        <C:comp name="VEVENT"/>
      </C:supported-calendar-component-set>
      <C:calendar-description><![CDATA[Created by FlowIt]]></C:calendar-description>
    </D:prop>
  </D:set>
</C:mkcalendar>
```

### Diagnostic des problèmes

#### 1. Vérifier les logs

Les logs FlowIt montrent maintenant :
- L'URL exacte de la requête MKCALENDAR
- Le corps XML complet envoyé
- Le code de statut de la réponse
- Le corps de la réponse du serveur

```
[DEBUG] CalDAVService: Creating calendar FlowIt Tasks at /calendar/home/user/flowit-tasks/
[DEBUG] CalDAVService: Sending MKCALENDAR request to: /calendar/home/user/flowit-tasks/
[DEBUG] CalDAVService: MKCALENDAR body: [XML content]
[DEBUG] CalDAVService: MKCALENDAR response status: 201
[INFO] CalDAVService: Calendar created successfully with status 201
```

#### 2. Codes d'erreur courants

| Code | Signification | Solution |
|------|---------------|----------|
| 201  | ✅ Créé avec succès | Normal |
| 204  | ✅ Créé sans contenu | Normal |
| 403  | ❌ Permission refusée | Vérifier les droits utilisateur |
| 409  | ❌ Calendrier existe déjà | Choisir un autre nom |
| 422  | ❌ XML invalide | Vérifier le format XML |
| 500  | ❌ Erreur serveur | Vérifier la configuration serveur |

#### 3. Tests de validation

Exécuter les tests unitaires :
```bash
flutter test test/calendar_creation_test.dart
```

Test d'intégration avec serveur réel :
```bash
flutter test test/calendar_creation_integration_test.dart --plain-name="XML generation"
```

#### 4. Vérifications manuelles

1. **Connectivité**
   - Le serveur CalDAV est-il accessible ?
   - L'authentification fonctionne-t-elle ?

2. **Permissions**
   - L'utilisateur a-t-il le droit de créer des calendriers ?
   - Le dossier de destination existe-t-il ?

3. **Format des données**
   - Le nom du calendrier contient-il des caractères spéciaux ?
   - L'URL du calendrier est-elle valide ?

### Test avec serveur Radicale

Pour tester localement avec Radicale :

```bash
# Installation
pip install radicale

# Configuration minimale (~/.config/radicale/config)
[auth]
type = htpasswd
htpasswd_filename = /path/to/users
htpasswd_encryption = plain

[storage]
filesystem_folder = /path/to/collections

# Création d'utilisateur
htpasswd -c /path/to/users testuser

# Démarrage
radicale --host 0.0.0.0 --port 5232
```

### Serveurs CalDAV testés

| Serveur | Version | Status | Notes |
|---------|---------|--------|-------|
| Radicale | 3.x | ✅ | Support complet MKCALENDAR |
| Nextcloud | 25+ | ✅ | Support VTODO |
| SOGo | 5.x | ✅ | CalDAV complet |
| Baikal | 0.9+ | ✅ | Compatible |

### Problèmes connus

1. **Certains serveurs exigent des permissions spéciales** pour créer des calendriers
2. **Certains serveurs** ne supportent pas tous les composants (VTODO vs VEVENT)
3. **Les chemins de calendrier** peuvent varier selon la configuration du serveur

### Contact et support

En cas de problème persistant :
1. Activer les logs de débogage détaillés
2. Vérifier la compatibilité du serveur CalDAV
3. Tester avec Radicale en local
4. Consulter les logs du serveur CalDAV 