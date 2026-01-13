# Portfolio CV éditable + API FastAPI

Une application composée d’une **SPA HTML/JS** (édition inline, sans build) et d’une **API FastAPI** pour persister les données, gérer l’auth par token et uploader des fichiers (photo, CV PDF).

- Front : `index.html` autonome, appels REST vers l’API quand disponible, fallback sur données par défaut.
- Back : `main.py` (FastAPI) avec persistance JSON, CORS ouvert (par défaut), tokens en mémoire, statiques `/uploads`.

---

## Sommaire
- [Architecture](#architecture)
- [Prérequis](#prérequis)
- [Installation & Lancement](#installation--lancement)
- [Documentation API](#documentation-api)
- [Fonctionnalités](#fonctionnalités)
- [Schéma des données](#schéma-des-données)
- [Endpoints](#endpoints)
- [Sécurité](#sécurité)
- [Personnalisation](#personnalisation)
- [Notes & limites](#notes--limites)
- [Améliorations possibles](#améliorations-possibles)

---

## Architecture
- **Frontend** : `index.html` (HTML/CSS/JS), édition inline (`contentEditable`), boutons d’ajout/suppression, upload photo/CV.
- **Backend** : `main.py` (FastAPI)
  - Persistance : `database.json`
  - Config admin : `admin.json`
  - Statiques : `/uploads`
  - CORS : `*` (modifiable)
  - Sessions admin : tokens en mémoire

---

## Prérequis
- Python 3.9+
- `pip install fastapi uvicorn python-multipart`

---

## Installation & Lancement
1) Cloner le dépôt et se placer à la racine.
2) Installer les dépendances :
   ```bash
   pip install fastapi uvicorn python-multipart
   ```
3) Lancer l’API (dev) :
   ```bash
   uvicorn main:app --host 0.0.0.0 --port 8000 --reload
   ```
   - Génère `database.json` et `admin.json` si absents.
   - Servez les uploads via `/uploads`.
4) Lancer le front :
   - Ouvrir `index.html` dans le navigateur, ou
   - Servir statiquement pour éviter les blocages `file://` :
     ```bash
     python -m http.server 5500
     # Puis ouvrir http://localhost:5500/index.html
     ```
   - Adapter `API_BASE_URL` dans `index.html` (par défaut `http://localhost:8000`).

---

## Documentation API
- **Swagger UI** : https://light-cv-to-portfolio-api.onrender.com:8000/docs
- **ReDoc** : https://light-cv-to-portfolio-api.onrender.com:8000/redoc

Ces pages se lancent automatiquement dès que l’API tourne avec `uvicorn main:app ...`.

---

## Fonctionnalités
- **Public** : affichage CV/portfolio (profil, à-propos, expériences, formations, compétences tech/soft, langues, projets, certifications).
- **Mode Admin** :
  - Login par mot de passe → récupère un token (`x-token`).
  - Édition inline, ajout/suppression d’éléments.
  - Upload photo/CV (stocke les URLs dans `cvData`).
  - Sauvegarde via `POST /api/data`.
- **Traduction** : widget Google Translate (désactive l’édition si la page est traduite).
- **Responsive** : sidebar + contenu adaptés mobile.

---

## Schéma des données
- Persistance : `database.json`
- Modèle principal `PortfolioData` :
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
- `GET /api/data` — Retourne le JSON complet du CV.

### Auth
- `POST /api/login` — Body `{ "password": "<plain>" }` → `{ "token": "<uuid>" }` (header `x-token` ensuite).
- `POST /api/logout` — Header `x-token`.
- `POST /api/change-password` — Body `{ "old_password": "...", "new_password": "..." }` (invalide tous les tokens).

### Protégés (Header `x-token: <token>`)
- `POST /api/data` — Body `PortfolioData` (écrase `database.json`).
- `POST /api/upload` — FormData `file` → `{ "url": "/uploads/<filename>" }`.

---

## Sécurité
- Mot de passe admin stocké en SHA-256 dans `admin.json` (hash par défaut de `"admin123"`).
- Tokens **en mémoire** (`active_tokens`) : redémarrage = déconnexion.
- Pensez à restreindre CORS en production (`allow_origins`).
- Ajoutez des limites de taille/type sur les uploads côté serveur/reverse-proxy.

---

## Personnalisation
- **API_BASE_URL** : en haut de `index.html`.
- **Styles** : variables CSS dans `:root`, classes `.section`, `.sidebar`, `.project-card`, etc.
- **Données par défaut** : `DEFAULT_DATA` dans `main.py` (utilisé si `database.json` absent).
- **Mot de passe admin** : via `POST /api/change-password` ou en remplaçant le hash dans `admin.json`.
- **Uploads** : dossier `uploads/` créé automatiquement (droits d’écriture requis).

---

## Notes & limites
- Tokens non persistés : un redémarrage invalide les sessions.
- CORS ouvert (`*`) pour le dev : à restreindre en prod.
- Pas de taille limite côté API sur les uploads : ajoutez des garde-fous (Nginx/uvicorn, validation MIME/poids).
- Front sans bundler : préférez un serveur statique plutôt que `file://`.

---

## Améliorations possibles
- Validation front (champs requis, formats email/tél/URL).
- Validation serveur sur les uploads (MIME, poids max).
- Persistance des tokens (Redis) ou JWT.
- Versioning/historique des données.
- Webhook ou email après sauvegarde.
- Tests unitaires (FastAPI) + CI.