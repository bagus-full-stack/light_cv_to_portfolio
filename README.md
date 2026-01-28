# 🚀 Portfolio Intelligent & Dynamique - Assami Baga

![Status](https://img.shields.io/badge/Status-En_Production-success?style=flat-square)
![Stack](https://img.shields.io/badge/Tech-JS%20%7C%20Supabase%20%7C%20OpenAI-blue?style=flat-square)
![License](https://img.shields.io/badge/License-MIT-lightgrey?style=flat-square)

Bienvenue sur le code source de mon portfolio professionnel. Ce projet va au-delà d'une simple vitrine web : c'est une **Single Page Application (SPA)** complète, administrable en temps réel et dotée d'un assistant IA.

🌐 **Voir le site en live : [https://bagus-full-stack.me/](https://bagus-full-stack.me/)**

---

## 📑 Sommaire
- [Fonctionnalités Principales](#-fonctionnalités-principales)
- [Architecture Technique](#-architecture-technique)
- [Intelligence Artificielle](#-intelligence-artificielle)
- [Installation & Configuration](#-installation--configuration)
- [Structure de la Base de Données](#-structure-de-la-base-de-données)

---

## 🌟 Fonctionnalités Principales

### 🎨 Expérience Utilisateur (Frontend)
* **Thèmes Dynamiques :** Bascule instantanée entre les modes **Clair**, **Sombre** et **Hacker** (style terminal Matrix avec effets néon).
* **Internationalisation :** Traduction automatique via l'API Google Translate.
* **Mode Impression :** Feuille de style CSS `@media print` optimisée pour générer un CV PDF propre directement depuis le navigateur.
* **Notifications Toasts :** Feedback utilisateur non-intrusif pour les actions (sauvegarde, erreurs).

### 🛠️ Administration (CMS Custom)
* **Authentification Sécurisée :** Login admin via Supabase Auth.
* **Édition In-Situ :** Une fois connecté, tous les textes deviennent éditables au clic (`contenteditable`).
* **Gestion de Données :** Ajout/Suppression dynamique de projets, compétences et expériences sans toucher au code.
* **Upload Cloud :** Gestion des images de profil et des fichiers PDF via Supabase Storage.

### 📊 Data & Analytics
* **Compteur de Vues :** Incrémentation en temps réel stockée en base de données (RPC Function).
* **Système de Contact :** Les messages du formulaire sont enregistrés en base et consultables depuis l'interface admin.

---

## 🏗 Architecture Technique

Le projet repose sur une architecture **JAMstack** moderne :

| Composant | Technologie | Description |
| :--- | :--- | :--- |
| **Frontend** | HTML5, CSS3, Vanilla JS | Pas de framework lourd, performance native maximale. |
| **Database** | PostgreSQL (Supabase) | Stockage relationnel et JSONB pour la flexibilité du contenu. |
| **Backend** | Supabase Edge Functions | Serverless functions (Deno) pour la logique IA. |
| **Auth** | Supabase Auth | Gestion sécurisée des sessions et JWT. |
| **Hosting** | GitHub Pages | Hébergement du frontend. |
| **CI/CD** | GitHub Actions | Déploiement automatique des fonctions backend. |

---

## 🧠 Intelligence Artificielle

Le site intègre un **Chatbot Contextuel** capable de répondre aux questions des recruteurs à ma place.

* **Modèle :** GPT-4o-mini (via OpenAI API).
* **Mécanisme :** À chaque question, le backend reçoit le CV complet au format JSON.
* **Prompt Engineering :** Un "System Prompt" instruit l'IA pour agir comme un assistant professionnel, utilisant uniquement les données de mon parcours pour répondre.

**Fichier concerné :** `supabase/functions/chat-resume/index.ts`

---

## 💻 Installation & Configuration

Pour cloner et lancer ce projet localement :

### 1. Cloner le repo
```bash
git clone [https://github.com/bagus-full-stack/light_cv_to_portfolio](https://github.com/bagus-full-stack/light_cv_to_portfolio)
cd ton-repo


