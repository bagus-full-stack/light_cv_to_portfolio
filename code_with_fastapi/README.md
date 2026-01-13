# Portfolio CV éditable + API (FastAPI + HTML)

Ce projet propose :
- Une **SPA HTML/JS** de portfolio/CV entièrement éditable côté client (pas de build tooling).
- Une **API FastAPI** pour persister les données, gérer l’authentification par token et uploader les fichiers (photo, CV PDF).

La page reste fonctionnelle même si l’API est hors ligne (fallback sur les données par défaut intégrées au front). Quand l’API est active, on peut modifier le contenu en mode admin et sauvegarder côté serveur.

---

## Sommaire
- [Architecture](#architecture)
- [Fonctionnalités côté front](#fonctionnalités-côté-front)
- [Fonctionnalités côté API](#fonctionnalités-côté-api)
- [Données et schéma](#données-et-schéma)
- [Endpoints](#endpoints)
- [Sécurité & Authentification](#sécurité--authentification)
- [Mise en route](#mise-en-route)
- [Flux d’édition complet](#flux-dédition-complet)
- [Personnalisation](#personnalisation)
- [Notes & limites](#notes--limites)
- [Améliorations possibles](#améliorations-possibles)

---

## Architecture
- **Frontend** : `index.html` autonome (HTML/CSS/JS) avec édition inline (`contentEditable`). Appels REST vers l’API quand disponible.
- **Backend** : `main.py` (FastAPI)
  - Persistance JSON (`database.json`), config admin (`admin.json`), et uploads statiques (`/uploads`).
  - CORS ouvert (`*`) par défaut.
  - Tokens en mémoire pour les sessions admin.

---

## Fonctionnalités côté front
- **Affichage CV/portfolio** : sections profil, à-propos, expériences, formations, compétences (tech/soft), langues, projets, certifications.
- **Mode Admin** :
  - Login par mot de passe → récupère un **token** REST.
  - Active l’édition inline, boutons d’ajout/suppression, upload photo/CV.
  - Sauvegarde via `POST /api/data`.
- **CRUD front** : ajout/suppression d’éléments (expériences, formations, compétences, projets, certifications, soft skills, langues).
- **Uploads** : photo + CV PDF, envoyés à `POST /api/upload` (URL retournée stockée dans `cvData`).
- **Traduction** : widget Google Translate (désactive l’édition si la page est traduite).
- **Responsive** : grille sidebar + contenu, adaptée mobile.

---

## Fonctionnalités côté API
- **Lecture** : `GET /api/data` charge le CV (fallback créé depuis `DEFAULT_DATA` si `database.json` absent).
- **Écriture** : `POST /api/data` sauvegarde le CV (protégé par token).
- **Auth** :
  - `POST /api/login` (mot de passe hashé côté serveur, hash stocké dans `admin.json`).
  - `POST /api/logout` (invalide le token en mémoire).
  - `POST /api/change-password` (re-hash + invalide les tokens existants).
- **Uploads** : `POST /api/upload` (protégé par token) sauvegarde dans `uploads/` et renvoie l’URL publique `/uploads/<filename>`.
- **Static** : `/uploads/**` sert les fichiers.

---

## Données et schéma
- Fichier de persistance : `database.json`.
- Modèle principal (côté API) : `PortfolioData`
  - `personal`: `{ name, title, availability, email, phone, location, linkedin, social?, summary, photoUrl?, cvUrl? }`
  - `softSkills`: `string[]`
  - `languages`: `string[]`
  - `education`: `{ degree, school, date }[]`
  - `experience`: `{ role, company, date, tasks: string[] }[]`
  - `techSkills`: `{ cat, tools }[]`
  - `projects`: `{ name, desc, tech, link }[]`
  - `certifications`: `{ name, link }[]`

---

## Endpoints

### Public
- `GET /api/data`  
  Retourne le JSON complet du CV.

### Auth
- `POST /api/login`  
  Body: `{ "password": "<plain>" }`  
  Retour: `{ "token": "<uuid>" }` (à passer dans `x-token`).
- `POST /api/logout`  
  Header: `x-token`.
- `POST /api/change-password`  
  Body: `{ "old_password": "...", "new_password": "..." }`  
  Invalide tous les tokens.

### Protégés (Header `x-token: <token>`)
- `POST /api/data`  
  Body: `PortfolioData` (écrase `database.json`).
- `POST /api/upload`  
  FormData: `file` (UploadFile) → Retour `{ "url": "/uploads/<filename>" }`.

---

## Sécurité & Authentification
- Hash SHA-256 du mot de passe stocké dans `admin.json` (initial: hash de `"admin123"`).
- Les tokens sont **en mémoire** (liste `active_tokens`). Un redémarrage invalide les sessions.
- Changements de mot de passe → purge des tokens.

---

## Mise en route

### Prérequis
- Python 3.9+
- `pip install fastapi uvicorn python-multipart`

### Lancer l’API
```bash
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```
- Génère `database.json` et `admin.json` si absents.
- Servez les uploads via `/uploads`.

### Lancer le front
- Ouvrir `index.html` dans un navigateur.  
- Pour éviter certains blocages CORS en `file://`, servez-le via un petit serveur statique (ex. `python -m http.server 5500`), puis ouvrez `http://localhost:5500/index.html`.
- Ajuster `API_BASE_URL` dans `index.html` (par défaut `http://localhost:8000`).

---

## Flux d’édition complet
1. Ouvrir la page, cliquer sur le crayon (Login Admin).
2. Saisir le mot de passe admin (`admin123` par défaut).
3. La page passe en mode édition (bordures, boutons +/trash, upload).
4. Modifier le contenu inline, ajouter/supprimer des entrées.
5. (Optionnel) Uploader photo/CV → envoie vers `POST /api/upload`, stocke l’URL dans `cvData.personal.photoUrl/cvUrl`.
6. Cliquer sur Sauvegarder → `POST /api/data` persiste dans `database.json`.
7. Se déconnecter (bouton rouge) pour quitter l’édition.

---

## Personnalisation
- **API_BASE_URL** : éditer en haut de `index.html`.
- **Style** : variables CSS dans `:root` (couleurs), classes `.section`, `.sidebar`, `.project-card`, etc.
- **Données par défaut** : `DEFAULT_DATA` dans `main.py` (utilisé si `database.json` manquant).
- **Mot de passe admin** : `admin.json` contient le hash. Changer via `POST /api/change-password` ou en remplaçant le hash manuellement.
- **Uploads** : répertoire `uploads/` (cr��é automatiquement). Assurez-vous que l’app FastAPI a les droits d’écriture.

---

## Notes & limites
- Tokens non persistés : un redémarrage API déconnecte les admins.
- CORS ouvert (`*`) pour faciliter les tests, à restreindre en production.
- Pas de taille limite côté serveur sur les uploads (penser à ajouter des garde-fous Nginx/uvicorn ou validation).
- Front sans bundler : tout est dans `index.html`; privilégier un serveur statique plutôt que `file://` pour un comportement réseau fiable.

---

## Améliorations possibles
- Ajouter de la validation côté front (champs obligatoires, formats email/tél, URLs).
- Gérer des tailles/types de fichiers côté API (mime/type, max size).
- Ajouter un stockage persistant pour les tokens (Redis) ou passer à des JWT.
- Mettre en place un mécanisme de versioning des données (snapshots) et d’historique.
- Intégrer un envoi de mail ou webhook après sauvegarde.
- Ajouter des tests (unitaires FastAPI) et un workflow CI.