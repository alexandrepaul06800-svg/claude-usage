# Claude Usage

App macOS menu bar pour suivre l'usage Claude sans ouvrir `claude.ai`.

## Etat actuel

- SwiftUI + `MenuBarExtra`
- popover detaille et onboarding minimal
- stockage `sessionKey` dans le Keychain
- historique JSON local
- notifications de seuil et reset
- toggle "lancer au demarrage" via `ServiceManagement`

## Ouvrir dans Xcode

1. Ouvre `Package.swift` dans Xcode.
2. Dans les settings du package app, ajoute `ClaudeUsage.entitlements`.
3. Signe l'app si tu veux tester `Launch at Login` et les notifications dans un contexte proche du reel.

## Build CLI

```bash
swift build
```

## Configuration MVP

- `sessionKey`: a coller manuellement depuis les cookies `claude.ai`
- `organization ID`: a saisir manuellement tant que l'app ne le detecte pas automatiquement

## Donnees et confidentialite

- le `sessionKey` est stocke localement dans le Keychain macOS
- l'`organization ID` et les preferences sont stockes localement via `UserDefaults`
- l'historique d'usage est stocke localement en JSON dans `Application Support`
- la derniere reponse brute de l'endpoint d'usage peut etre stockee localement pour le diagnostic et l'export
- aucune cle API, aucun token, et aucune donnee utilisateur reelle ne sont inclus dans ce repository

## Limites connues

- le mapping de l'endpoint `/api/organizations/{org_id}/usage` est defensif mais devra etre ajuste sur une vraie reponse capturee
- `Launch at Login` depend d'une app bundle signee pour un comportement complet hors environnement de dev
- le package est pret a etre ouvert dans Xcode, mais je n'ai pas genere de `.xcodeproj` manuel
