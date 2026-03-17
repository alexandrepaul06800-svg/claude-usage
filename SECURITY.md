# Security

## Resume

Ce projet manipule des donnees locales potentiellement sensibles a l'execution, en particulier:

- un `sessionKey` stocke dans le Keychain macOS
- un `organization ID` stocke localement
- un historique d'usage local
- un payload brut d'usage potentiellement exportable depuis l'ecran de diagnostic

Le repository ne doit contenir aucun secret, aucun cookie reel, ni aucun export d'utilisateur.

## Bonnes pratiques

- ne commit jamais de `sessionKey`, cookie, token, ou capture de DevTools
- ne partage pas de payload JSON reel sans l'anonymiser soigneusement
- verifie les captures d'ecran de la vue diagnostics avant publication
- privilegie des fixtures synthetiques dans `Tests/ClaudeUsageTests/Fixtures`

## Signaler un probleme

Si tu identifies une fuite potentielle de donnees, un stockage trop permissif, ou un comportement risquant d'exposer des informations utilisateur, ouvre une issue privee si possible ou contacte le mainteneur avant divulgation publique complete.

## Portee

Ce projet est un client non officiel qui depend de comportements `claude.ai` susceptibles d'evoluer. Les changements de schema, d'authentification, ou de politique d'acces peuvent avoir des impacts securite et confidentialite qui doivent etre reevalues regulierement.
