# Contributing

Merci de t'interesser au projet.

## Avant de proposer un changement

- ouvre une issue si le changement est important ou si le comportement attendu n'est pas clair
- decris l'impact utilisateur, surtout si le changement touche le parsing des endpoints `claude.ai`
- evite de proposer des modifications qui introduisent des secrets, des credentials de test reels, ou des exports de donnees utilisateur

## Regles de contribution

- garde le projet sans secret embarque
- n'ajoute pas de payloads reels captures depuis un compte utilisateur
- privilegie des fixtures synthetiques pour les tests
- documente les changements visibles dans `README.md` si l'installation, la configuration, ou les limites changent
- ajoute ou mets a jour des tests quand tu modifies le parsing ou la persistence

## Workflow local

```bash
swift build
swift test
```

## Pull requests

- explique le probleme resolu
- decris les risques de regression
- liste les tests executes
- signale explicitement toute hypothese sur les endpoints ou schemas de reponse
