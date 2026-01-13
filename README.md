# Portfolio Admin (FastAPI + Static Frontend)

Un mini-CMS léger pour gérer et afficher un portfolio avec édition inline côté front, persistance via API FastAPI et upload de fichiers. Le frontend est un fichier `index.html` autonome qui consomme l’API (JSON) et propose un mode édition après authentification par mot de passe. Le backend expose des endpoints pour récupérer/sauvegarder les données, gérer l’authentification et stocker les fichiers uploadés.

## Vue d’ensemble

- **Frontend** : SPA minimaliste en HTML/CSS/JS (vanilla) avec mode lecture/édition. L’édition se fait via `contenteditable` et les boutons d’action (ajout/suppression).
- **Backend** : FastAPI, stockage JSON file-based (`database.json` + `admin.json` pour le hash du mot de passe), upload statique via `/uploads`.
- **Auth** : login par mot de passe (hashé SHA-256 côté serveur). Retourne un token stocké en mémoire (ensemble `active_tokens`), transmis via header `x-token`.
- **Persistance** : les données sont lues/écrites dans `database.json`. Un seed (`DEFAULT_DATA`) initialise le fichier s’il n’existe pas.
- **Uploads** : fichiers envoyés via `/api/upload`, servis ensuite par `/uploads/<filename>`.

## Stack technique

- **Frontend** : HTML5, CSS (inline), JS vanilla, Font Awesome CDN.
- **Backend** : Python 3, FastAPI, Uvicorn, Pydantic, CORS Middleware.
- **Stockage** : fichiers locaux (`database.json`, `admin.json`, répertoire `uploads/`).

## Fonctionnalités principales

- Affichage du portfolio (profil, à-propos, expériences, diplômes, projets, certifications, compétences, soft skills, langues).
- Mode édition sécurisé (login) avec :
  - Champs `contenteditable`
  - Ajout/suppression d’items (listes : expériences, formations, projets, compétences, certifications, soft skills, langues)
  - Upload photo et CV (PDF) via API, mise à jour des URLs dans les données
- Sauvegarde des modifications vers l’API (`/api/data`).
- Changement de mot de passe admin.
- Déconnexion et invalidation des tokens (en mémoire).

## Structure des données (JSON)

```json
{
  "personal": {
    "name": "string",
    "title": "string",
    "availability": "string",
    "email": "string",
    "phone": "string",
    "location": "string",
    "linkedin": "string",
    "social": "string",
    "summary": "string",
    "photoUrl": "string",
    "cvUrl": "string"
  },
  "softSkills": ["string", "..."],
  "languages": ["string", "..."],
  "education": [{ "degree": "string", "school": "string", "date": "string" }],
  "experience": [{ "role": "string", "company": "string", "date": "string", "tasks": ["string", "..."] }],
  "techSkills": [{ "cat": "string", "tools": "string" }],
  "projects": [{ "name": "string", "desc": "string", "tech": "string", "link": "string" }],
  "certifications": [{ "name": "string", "link": "string" }]
}
```

## Endpoints backend (FastAPI)

- `GET  /api/data` : retourne le JSON complet du portfolio.
- `POST /api/login` : `{ "password": "<plain>" }` → `{ token }` (token UUID ajouté à `active_tokens`).
- `POST /api/logout` : header `x-token` (optionnel) → supprime le token du set.
- `POST /api/change-password` : `{ "old_password", "new_password" }` → met à jour `admin.json`, vide `active_tokens`.
- `POST /api/data` : (auth requis) envoie le JSON complet `PortfolioData` pour sauvegarder dans `database.json`.
- `POST /api/upload` : (auth requis) upload multipart `file` → `{ "url": "/uploads/<filename>" }`.
- Static : `/uploads/<filename>` sert les fichiers uploadés.

## Authentification & sécurité

- Hash SHA-256 stocké dans `admin.json` (par défaut hash de `admin123`).
- Les tokens sont conservés en mémoire (non persistés). Un redémarrage du serveur invalide tout.
- Header attendu : `x-token` pour les routes protégées.
- CORS ouvert (`*`) pour simplifier le développement (à restreindre en production).
- Aucune gestion de rôles, ni de refresh token : solution simple pour usage personnel.

## Frontend : comportement

- `loadDataFromAPI()` : fetch sur `/api/data`, puis `render()`.
- `login()` : prompt mot de passe → `/api/login` → stocke `authToken`, active `isEditMode`, ajoute classe `editing` au `body`.
- `saveDataToAPI()` : POST `/api/data` avec le JSON courant et `x-token`.
- `uploadFileToAPI(file)` : POST `/api/upload` avec `x-token`, renvoie l’URL à intégrer (photo ou CV).
- `changePassword()` : prompts pour ancien/nouveau, appelle `/api/change-password`.
- Boutons flottants : login (crayon), save, change password, logout.
- En mode édition : bordures, boutons add/delete, upload photo/CV, champs éditables.

## Mise en place locale

### Prérequis
- Python 3.9+ recommandé
- `pip` (ou `pipenv`/`poetry`)

### Installation
```bash
pip install fastapi uvicorn pydantic
```

### Lancement du backend
```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```
- Démarre l’API sur `http://localhost:8000`.
- Initialise `database.json` et `admin.json` si absents.
- Sert les uploads sous `http://localhost:8000/uploads/<filename>`.

### Frontend
- Ouvrir `index.html` dans le navigateur.
- Assurez-vous que `API_BASE_URL` dans le script pointe vers le backend (par défaut `http://localhost:8000`).

## Exemples d’appels API (curl)

- Login :
```bash
curl -X POST http://localhost:8000/api/login \
  -H "Content-Type: application/json" \
  -d '{"password": "admin123"}'
```

- Sauvegarder les données :
```bash
curl -X POST http://localhost:8000/api/data \
  -H "Content-Type: application/json" \
  -H "x-token: <token>" \
  -d @database.json
```

- Upload d’un fichier :
```bash
curl -X POST http://localhost:8000/api/upload \
  -H "x-token: <token>" \
  -F "file=@/chemin/vers/fichier.pdf"
```

- Changer le mot de passe :
```bash
curl -X POST http://localhost:8000/api/change-password \
  -H "Content-Type: application/json" \
  -d '{"old_password": "admin123", "new_password": "monNouveauPass"}'
```

## Conseils de prod / durcissement

- Restreindre `allow_origins` à votre domaine.
- Servir le frontend via un serveur statique (NGINX) et reverse proxy vers FastAPI.
- Stocker `uploads/` dans un volume ou un bucket si conteneurisé.
- Ajouter une limite de taille d’upload et filtrer les types MIME.
- Envisager une persistance token (DB) ou des sessions signées si plusieurs instances.
- Surveiller et sauvegarder `database.json` et `admin.json` (backups).
- Mettre un HTTPS (Let’s Encrypt) et désactiver l’auto-indexation des fichiers.

## Dépannage

- **401 Unauthorized** : token manquant ou expiré (redémarrage serveur) → relogin.
- **Fichiers non servis** : vérifier `uploads/` existe et que FastAPI est lancé avec la bonne cwd.
- **CORS** : adapter `allow_origins` si le frontend est sur un autre domaine/port.
- **Ports** : si déjà occupé, changer `PORT` dans l’environnement ou l’argument uvicorn.
- **Cache navigateur** : vider ou hard refresh après des changements frontend.

## Personnalisation rapide

- Modifier les styles dans le `<style>` de `index.html`.
- Adapter les sections rendues dans `render()` (timeline, projets, compétences).
- Changer le seed de `DEFAULT_DATA` dans `main.py` pour un nouvel utilisateur.

---

Bon développement ! 🎉