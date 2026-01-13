# Portfolio CV éditable (HTML/JS)

Ce projet est une page HTML monopage qui sert de portfolio/CV interactif pour **Assami BAGA**. Il fonctionne sans backend : toutes les données sont stockées en mémoire et dans le `localStorage` du navigateur. Un mode admin permet d’éditer le contenu directement dans la page, puis d’exporter le code JSON mis à jour (et le hash du mot de passe) pour le rendre permanent dans le fichier.

## Sommaire
- [Fonctionnalités](#fonctionnalités)
- [Structure et données](#structure-et-données)
- [Mode Admin et authentification](#mode-admin-et-authentification)
- [Sauvegarde et export](#sauvegarde-et-export)
- [Gestion des médias (photo, CV PDF)](#gestion-des-médias-photo-cv-pdf)
- [Traduction Google](#traduction-google)
- [Lancer le projet](#lancer-le-projet)
- [Personnalisation rapide](#personnalisation-rapide)
- [Notes et limites](#notes-et-limites)

## Fonctionnalités
- **CV/Portfolio statique** en HTML/CSS/JS, aucune dépendance backend.
- **Mode Admin** (protégé par mot de passe, hash SHA-256) pour éditer le contenu en place (contenteditable).
- **CRUD front** sur toutes les sections : expériences, formations, compétences techniques, soft skills, langues, projets, certifications.
- **Export des données** : copie dans le presse-papiers du JSON `cvData` et rappel du hash de mot de passe à replacer dans `index.html`.
- **Mémorisation locale** via `localStorage` : photo de profil, CV PDF uploadé, hash de mot de passe si modifié.
- **Bouton de téléchargement du CV** (ou upload en mode édition).
- **Traduction** avec le widget Google Translate.
- **UI mobile-friendly** (mise en page responsive).

## Structure et données
- Tout est dans `index.html`.
- Les données sont contenues dans l’objet `cvData` :
  - `personal` : nom, titre, disponibilité, email, téléphone, localisation, LinkedIn, social, résumé.
  - `softSkills`, `languages` : tableaux simples.
  - `education`, `experience` : listes d’objets (avec tâches pour l’expérience).
  - `techSkills` : catégories + outils.
  - `projects` : nom, description, stack, lien.
  - `certifications` : nom + lien.
- Les boutons d’ajout/suppression n’apparaissent qu’en mode édition (`body.editing`).

## Mode Admin et authentification
- Mot de passe par défaut : hash SHA-256 de `"admin123"` stocké dans `adminHash`.
- Au clic sur le crayon (bouton flottant), un prompt demande le mot de passe. Si le hash correspond à `adminHash`, le mode édition est activé (`isEditMode = true`, classe `editing` sur le `body`).
- **Changement de mot de passe** : bouton clé → prompt → calcule un nouveau hash SHA-256 → sauvegarde dans `localStorage` et en mémoire (`adminHash`).

## Sauvegarde et export
- Bouton disque (save) : copie dans le presse-papiers un script contenant :
  - Le nouveau `cvData` sérialisé (JSON beautifié).
  - Un rappel du hash à mettre à jour dans `adminHash`.
- Pour rendre les changements permanents côté fichier :
  1) Copier le bloc exporté,
  2) Ouvrir `index.html`,
  3) Remplacer la déclaration `let cvData = ...` par le bloc,
  4) Mettre à jour `adminHash` si le mot de passe a changé.

## Gestion des médias (photo, CV PDF)
- **Photo de profil** : input file caché ; l’image est encodée en base64 et stockée dans `localStorage` (`profilePhoto`). Taille max ~3 Mo.
- **CV PDF** : en mode édition, le bouton “Uploader CV” ouvre un input file ; le PDF est stocké en base64 dans `localStorage` (`cvFile`). En mode visiteur, le bouton tente de télécharger ce fichier (ou affiche “Aucun CV” si absent).

## Traduction Google
- Intègre le widget Google Translate (`translate.google.com/translate_a/element.js`) pour proposer une traduction de la page.
- Restriction : l’édition est bloquée si la page est en mode traduction (test sur la classe `translated-ltr`).

## Lancer le projet
1. Cloner/télécharger le fichier `index.html`.
2. Ouvrir `index.html` dans un navigateur moderne (Chrome/Firefox/Edge).
3. (Optionnel) Servir via un petit serveur local pour éviter certains blocages CORS liés à `file://` (ex. `python -m http.server 8000`).

## Personnalisation rapide
- **Texte et données** : éditer en mode Admin puis exporter, ou modifier directement l’objet `cvData` dans `index.html`.
- **Mot de passe** : bouton clé → changer → exporter pour récupérer le nouveau hash → remplacer `adminHash` dans le fichier.
- **Liens projets/certifs** : remplir les champs `link` (actuellement `#` pour certains).
- **Couleurs/Styles** : palette dans `:root` (variables CSS).

## Notes et limites
- **Persistance locale** : les médias et le hash modifié sont stockés dans le `localStorage` du navigateur courant uniquement. Pour les rendre permanents, il faut réintégrer le code exporté dans `index.html`.
- **Sécurité** : le mot de passe est géré côté front (hash en clair dans le code), donc ne pas utiliser un mot de passe sensible. Convient à un usage portfolio/démo.
- **Poids des fichiers** : uploads limités à ~3 Mo pour l’image et le PDF.
- **Traduction** : désactive l’édition pour éviter les incohérences du DOM traduit.

---

Bon travail et bonne personnalisation ! 🎉