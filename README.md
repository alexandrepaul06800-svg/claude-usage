# Claude Usage

App macOS de menu bar pour suivre l'usage Claude sans garder `claude.ai` ouvert.

## Apercu

- app SwiftUI basee sur `MenuBarExtra`
- saisie d'un `sessionKey` stocke localement dans le Keychain macOS
- auto-detection defensive de l'`organization ID`
- historique local en JSON
- fenetre de diagnostic et export des donnees locales
- notifications de seuil, reset, et erreur de synchronisation
- option "lancer au demarrage" via `ServiceManagement`

## Pour qui

Ce projet est surtout adapte si tu es:

- sur macOS
- a l'aise avec Xcode et Swift Package Manager
- ok avec une installation manuelle
- conscient que l'outil est non officiel et peut casser si `claude.ai` change

## Statut

Le projet est utilisable, mais reste un outil communautaire non officiel.

Il depend actuellement d'un `sessionKey` navigateur et d'endpoints `claude.ai` non documentes. Le comportement peut donc changer sans preavis si Anthropic modifie ses routes, sa structure de reponse, ou ses conditions d'utilisation.

## Demarrage rapide

### Ouvrir dans Xcode

1. Ouvre `Package.swift` dans Xcode.
2. Dans les settings du package app, ajoute `ClaudeUsage.entitlements`.
3. Signe l'app si tu veux tester `Launch at Login` et les notifications dans un contexte proche du reel.

### Build CLI

```bash
swift build
swift test
```

## Installation

Il n'y a pas encore de build signe ou d'installateur "1 clic".

Installation actuelle:

1. clone le repo
2. ouvre `Package.swift` dans Xcode
3. ajoute `ClaudeUsage.entitlements` au package app
4. build et lance l'app depuis Xcode
5. colle ton `sessionKey` dans les reglages de l'app

## Utilisation

1. ouvre `claude.ai` dans ton navigateur
2. recupere la valeur du cookie `sessionKey`
3. ouvre Claude Usage
4. colle le `sessionKey` dans l'onglet de connexion
5. laisse l'`organization ID` vide si l'auto-detection fonctionne, sinon renseigne-le manuellement

## Configuration

- `sessionKey`: a coller manuellement depuis les cookies `claude.ai`
- `organization ID`: laisse vide pour l'auto-detection, ou renseigne-le manuellement en secours

## Donnees et confidentialite

L'app ne contient aucune cle API, aucun token, ni aucune donnee utilisateur reelle dans ce repository.

En execution locale:

- le `sessionKey` est stocke localement dans le Keychain macOS
- l'`organization ID` et les preferences sont stockes localement via `UserDefaults`
- l'historique d'usage est stocke localement en JSON dans `Application Support`
- la derniere reponse brute de l'endpoint d'usage peut etre stockee localement pour le diagnostic et l'export

Consulte aussi `SECURITY.md` avant de partager des logs, captures d'ecran, ou exports.

## Open Source

- licence: `MIT`
- contributions: voir `CONTRIBUTING.md`
- signalement responsable: voir `SECURITY.md`
- code de conduite: voir `CODE_OF_CONDUCT.md`

## Feuille de route

Ameliorations utiles pour le projet:

- release macOS plus simple a installer
- captures d'ecran et demo dans le README
- detection plus robuste de l'`organization ID`
- reduction du stockage du payload brut de diagnostic
- meilleure tolerance aux changements de schema cote `claude.ai`

## Limites connues

- le mapping de l'endpoint `/api/organizations/{org_id}/usage` est defensif et devra etre ajuste sur de vraies reponses si le schema evolue
- `Launch at Login` depend d'une app bundle signee pour un comportement complet hors environnement de dev
- le package est pret a etre ouvert dans Xcode, mais aucun `.xcodeproj` manuel n'est fourni
- le projet n'utilise pas l'API officielle Anthropic

## Support

- pour un bug: ouvre une issue GitHub avec les etapes de reproduction
- pour une idee: ouvre une issue de feature request
- pour un sujet sensible: passe par `SECURITY.md`
