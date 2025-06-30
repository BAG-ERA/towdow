# Guide - Création de portefeuilles projet avec noms personnalisés

## Fonctionnalité

FlowIt permet maintenant de créer des portefeuilles projet avec des noms personnalisés lors de la configuration initiale ou lors de l'ajout de nouveaux portefeuilles.

## Comment utiliser

### 1. Création du premier portefeuille projet
Lors de la première connexion à un serveur CalDAV :
1. Connectez-vous à votre serveur CalDAV
2. Si aucun portefeuille compatible n'existe, FlowIt affiche l'option "Create Your First Project Portfolio"
3. Cliquez sur **"Create Portfolio"**
4. Une boîte de dialogue s'ouvre avec :
   - **Nom du portefeuille** : Par défaut "FlowIt Portfolio" (modifiable)
   - **Description** : Par défaut "Project portfolio created by FlowIt" (optionnelle)

### 2. Ajout d'un nouveau portefeuille projet
Si des portefeuilles existent déjà :
1. Dans l'écran de sélection des portefeuilles projet
2. Cliquez sur **"Create"** dans la section "Create New Project Portfolio"
3. Même dialogue de saisie que ci-dessus

## Règles de validation

### Nom du portefeuille projet
- **Obligatoire** : Le nom ne peut pas être vide
- **Nettoyage automatique** : 
  - Conversion en minuscules
  - Suppression des caractères spéciaux (!@#$%^&*(), etc.)
  - Remplacement des espaces par des tirets
  - Suppression des tirets multiples consécutifs
  - Suppression des tirets en début/fin

### Description
- **Optionnelle** : Peut être laissée vide
- **Aucune restriction** : Tous caractères acceptés

## Exemples de transformation des noms

| Nom saisi | Nom technique généré |
|-----------|---------------------|
| `FlowIt Tasks` | `flowit-tasks` |
| `Mon Calendrier 2024` | `mon-calendrier-2024` |
| `Projets & Tâches!` | `projets-tches` |
| `   Espaces   ` | `espaces` |
| `Calendrier---Test` | `calendriertest` |
| `🎯 Objectifs` | `objectifs` |

## Cas particuliers

### Noms avec caractères Unicode
- **Caractères latins étendus** : Les accents sont supprimés
  - `français` → `franais`
  - `español` → `espaol`

- **Caractères non-latins** : Supprimés avec fallback
  - `Календарь` → `flowit-tasks` (fallback)
  - `日本語` → `flowit-tasks` (fallback)

### Noms invalides
Si le nom saisi ne contient que des caractères spéciaux :
- **Nom technique** : `flowit-tasks` (fallback automatique)
- **Nom affiché** : Nom original saisi par l'utilisateur

## Chemin du calendrier

Le chemin technique est construit ainsi :
```
{calendar-home-set}/{nom-technique}/
```

**Exemple** :
- Serveur : `https://caldav.example.com`
- Calendar Home : `/calendars/user/`
- Nom technique : `mes-taches`
- **Chemin final** : `/calendars/user/mes-taches/`

## Bonnes pratiques

### ✅ Recommandé
- Utiliser des noms courts et descriptifs
- Éviter les caractères spéciaux dans le nom
- Utiliser la description pour plus de détails

### ❌ À éviter
- Noms très longs (>50 caractères)
- Uniquement des caractères spéciaux
- Noms en double (vérifiez les calendriers existants)

## Exemples d'usage

### Usage personnel
- **Nom** : `Mes Tâches`
- **Description** : `Calendrier personnel pour mes tâches quotidiennes`

### Usage professionnel
- **Nom** : `Projet Alpha`
- **Description** : `Tâches et jalons du projet Alpha - Q1 2024`

### Usage familial
- **Nom** : `Famille Martin`
- **Description** : `Planning familial et tâches ménagères`

## Dépannage

### Le calendrier n'apparaît pas
1. Vérifiez que la création s'est bien terminée (message de succès)
2. Actualisez la liste des calendriers
3. Vérifiez les permissions sur le serveur CalDAV

### Erreur de création
- **403 Forbidden** : Pas de permission de créer des calendriers
- **409 Conflict** : Un calendrier avec ce nom existe déjà
- **422 Unprocessable** : Format XML incorrect (bug à signaler)

### Support technique
En cas de problème, consultez les logs de l'application ou le guide de débogage dans `CALENDAR_CREATION_DEBUG.md`. 