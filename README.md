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

## Limites connues

- le mapping de l'endpoint `/api/organizations/{org_id}/usage` est defensif et devra etre ajuste sur de vraies reponses si le schema evolue
- `Launch at Login` depend d'une app bundle signee pour un comportement complet hors environnement de dev
- le package est pret a etre ouvert dans Xcode, mais aucun `.xcodeproj` manuel n'est fourni
- le projet n'utilise pas l'API officielle Anthropic
