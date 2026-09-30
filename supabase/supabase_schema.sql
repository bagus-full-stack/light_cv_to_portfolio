-- ============================================================
-- Schéma Supabase pour le portfolio (version corrigée)
-- À exécuter dans : Supabase > SQL Editor > New query
-- Le script peut être relancé sans erreur et sans écraser le contenu
-- déjà présent dans la table portfolio.
-- ============================================================

-- ------------------------------------------------------------
-- 0. ADMINISTRATEUR
--    Seul(s) le(s) compte(s) listé(s) ici peuvent modifier le site,
--    lire les messages et gérer les fichiers. Sans cela, n'importe
--    quel compte créé via l'inscription Supabase Auth aurait les mêmes
--    droits que toi.
-- ------------------------------------------------------------
create table if not exists public.admin_users (
  user_id uuid primary key references auth.users (id) on delete cascade
);
alter table public.admin_users enable row level security;   -- aucune policy : lisible seulement via is_admin()

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.admin_users where user_id = auth.uid());
$$;
grant execute on function public.is_admin() to authenticated;

-- >>> À MODIFIER : remplace par l'e-mail de ton compte admin Supabase Auth
--     (celui que tu saisis dans la fenêtre « Email Admin » du site).
insert into public.admin_users (user_id)
select id from auth.users where email = 'TON_EMAIL_ADMIN@exemple.com'
on conflict do nothing;

-- Vérification : cette requête doit renvoyer 1. Si elle renvoie 0,
-- l'e-mail ci-dessus ne correspond à aucun compte : corrige-le et relance.
select count(*) as nombre_admins from public.admin_users;

-- ------------------------------------------------------------
-- 1. TABLE portfolio (contenu du CV, édité via le mode admin)
-- ------------------------------------------------------------
create table if not exists public.portfolio (
  id int primary key,
  json_data jsonb not null,
  updated_at timestamptz not null default now()
);
alter table public.portfolio enable row level security;

-- Mise à jour automatique de updated_at
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
drop trigger if exists portfolio_set_updated_at on public.portfolio;
create trigger portfolio_set_updated_at
  before update on public.portfolio
  for each row execute function public.set_updated_at();

drop policy if exists "portfolio_public_read" on public.portfolio;
drop policy if exists "portfolio_admin_write" on public.portfolio;
drop policy if exists "portfolio_admin_update" on public.portfolio;

create policy "portfolio_public_read"
  on public.portfolio for select
  to anon, authenticated
  using (true);

create policy "portfolio_admin_write"
  on public.portfolio for insert
  to authenticated
  with check (public.is_admin());

create policy "portfolio_admin_update"
  on public.portfolio for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- Depuis mai 2026, les nouvelles tables ne sont plus exposées
-- automatiquement à l'API : les droits doivent être accordés explicitement.
grant select on public.portfolio to anon, authenticated;
grant insert, update on public.portfolio to authenticated;

-- ------------------------------------------------------------
-- 2. TABLE messages (formulaire de contact)
-- ------------------------------------------------------------
create table if not exists public.messages (
  id bigint generated always as identity primary key,
  name text not null,
  email text not null,
  message text not null,
  created_at timestamptz not null default now()
);
alter table public.messages enable row level security;

-- Limites de taille et format d'e-mail (en phase avec le formulaire du site :
-- le message peut atteindre 2200 caractères avec le préfixe « Entreprise / poste »).
-- NOT VALID : contrôle les nouveaux messages sans bloquer d'éventuels anciens.
alter table public.messages drop constraint if exists messages_name_len;
alter table public.messages drop constraint if exists messages_email_format;
alter table public.messages drop constraint if exists messages_message_len;
alter table public.messages add constraint messages_name_len check (char_length(name) between 1 and 100) not valid;
alter table public.messages add constraint messages_email_format check (char_length(email) <= 150 and email ~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$') not valid;
alter table public.messages add constraint messages_message_len check (char_length(message) between 1 and 2200) not valid;

drop policy if exists "messages_public_insert" on public.messages;
drop policy if exists "messages_admin_read" on public.messages;
drop policy if exists "messages_admin_delete" on public.messages;

create policy "messages_public_insert"
  on public.messages for insert
  to anon, authenticated
  with check (true);

create policy "messages_admin_read"
  on public.messages for select
  to authenticated
  using (public.is_admin());

create policy "messages_admin_delete"
  on public.messages for delete
  to authenticated
  using (public.is_admin());

grant insert on public.messages to anon, authenticated;
grant select, delete on public.messages to authenticated;

-- OPTIONNEL : plafonner le flux de messages (5 par minute au total) pour limiter le spam.
-- Inconvénient : un attaquant peut aussi bloquer temporairement le formulaire.
-- create or replace function public.messages_throttle() returns trigger language plpgsql as $$
-- begin
--   if (select count(*) from public.messages where created_at > now() - interval '1 minute') >= 5 then
--     raise exception 'Trop de messages, réessayez dans une minute.';
--   end if;
--   return new;
-- end; $$;
-- drop trigger if exists messages_throttle on public.messages;
-- create trigger messages_throttle before insert on public.messages
--   for each row execute function public.messages_throttle();

-- ------------------------------------------------------------
-- 3. TABLE site_stats (compteur de visites)
-- ------------------------------------------------------------
create table if not exists public.site_stats (
  id int primary key,
  visits bigint not null default 0
);
alter table public.site_stats enable row level security;

drop policy if exists "site_stats_public_read" on public.site_stats;
create policy "site_stats_public_read"
  on public.site_stats for select
  to anon, authenticated
  using (true);

grant select on public.site_stats to anon, authenticated;

insert into public.site_stats (id, visits) values (1, 0)
  on conflict (id) do nothing;

-- Fonction RPC appelée par le site à chaque nouvelle visite.
-- SECURITY DEFINER : un visiteur anonyme peut incrémenter le compteur
-- sans avoir de droit UPDATE direct sur la table.
create or replace function public.increment_visits()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.site_stats set visits = visits + 1 where id = 1;
end;
$$;
grant execute on function public.increment_visits() to anon, authenticated;

-- ------------------------------------------------------------
-- 4. TABLE visitor_logs (ville/pays, uniquement avec le consentement du visiteur)
-- ------------------------------------------------------------
create table if not exists public.visitor_logs (
  id bigint generated always as identity primary key,
  city text,
  country text,
  created_at timestamptz not null default now()
);
alter table public.visitor_logs enable row level security;

alter table public.visitor_logs drop constraint if exists visitor_logs_len;
alter table public.visitor_logs add constraint visitor_logs_len check (char_length(coalesce(city, '')) <= 100 and char_length(coalesce(country, '')) <= 100) not valid;

drop policy if exists "visitor_logs_public_insert" on public.visitor_logs;
drop policy if exists "visitor_logs_admin_read" on public.visitor_logs;

create policy "visitor_logs_public_insert"
  on public.visitor_logs for insert
  to anon, authenticated
  with check (true);

create policy "visitor_logs_admin_read"
  on public.visitor_logs for select
  to authenticated
  using (public.is_admin());

grant insert on public.visitor_logs to anon, authenticated;
grant select on public.visitor_logs to authenticated;

-- ------------------------------------------------------------
-- 5. STORAGE : bucket 'uploads' (photo de profil, CV PDF)
--    Le bucket est public : les liens directs (photo, CV) fonctionnent
--    sans policy de lecture. On ne donne donc PAS de droit de lecture
--    anonyme sur storage.objects, ce qui empêcherait de lister les fichiers.
-- ------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('uploads', 'uploads', true, 10485760,
        array['application/pdf', 'image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = true,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "uploads_public_read" on storage.objects;
drop policy if exists "uploads_admin_read" on storage.objects;
drop policy if exists "uploads_admin_write" on storage.objects;
drop policy if exists "uploads_admin_update" on storage.objects;
drop policy if exists "uploads_admin_delete" on storage.objects;

-- Lecture réservée à l'admin (nécessaire au remplacement d'un fichier existant).
create policy "uploads_admin_read"
  on storage.objects for select
  to authenticated
  using (bucket_id = 'uploads' and public.is_admin());

create policy "uploads_admin_write"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'uploads' and public.is_admin());

create policy "uploads_admin_update"
  on storage.objects for update
  to authenticated
  using (bucket_id = 'uploads' and public.is_admin())
  with check (bucket_id = 'uploads' and public.is_admin());

create policy "uploads_admin_delete"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'uploads' and public.is_admin());

-- ------------------------------------------------------------
-- 6. SEED : contenu actuel du portfolio (généré depuis index.html, version 7)
--    ON CONFLICT DO NOTHING : relancer le script n'écrase jamais
--    le contenu modifié en mode admin.
-- ------------------------------------------------------------
insert into public.portfolio (id, json_data) values (1, $seed${"contentVersion":7,"personal":{"name":"Assami BAGA","title":"Ingénieur Full Stack & IA","availability":"Disponible immédiatement","email":"bagaassami09@gmail.com","phone":"07 53 49 67 71","location":"Île-de-France","linkedin":"assami-baga","social":"bagus-full-stack","summary":"Ingénieur diplômé Bac+5 en Ingénierie Logicielle et Intelligence Artificielle (EILCO, 2026), disponible immédiatement en CDI. J'ai 3 ans d'expérience en entreprise chez Orange et CDC Informatique, sur des applications web (Angular, Spring Boot, React) et des systèmes critiques de traitement de flux (200+ flux/jour en production). Je pars toujours du besoin métier pour livrer une solution pragmatique, maintenable et adoptée par les équipes. Je m'appuie sur l'IA (LLM, RAG, vision par ordinateur, IA générative, NLP) là où elle apporte une vraie valeur : traduction et synthèse vocale pour 7 langues du Burkina Faso, analyse nutritionnelle par photo, génération d'images optimisée. Formé à la conformité (RGPD, ISO 27001, LCB-FT), rigoureux et curieux, j'aime expliquer clairement et partager ce que j'apprends."},"softSkills":["Orienté besoin métier","Esprit d'analyse et de synthèse","Rigueur et fiabilité en production","Collaboration transverse","Pédagogie et partage de connaissances","Autonomie et proactivité","Résolution de problèmes complexes","Pragmatisme orienté résultat","Curiosité technique"],"languages":["Français","Anglais"],"education":[{"degree":"Diplôme d'ingénieur en Ingénierie Logicielle et Intelligence Artificielle","school":"École d'Ingénieur du Littoral Côte d'Opale (EILCO), Calais, France","date":"Sept 2023 - Sept 2026"},{"degree":"Licence en Ingénierie des Systèmes d'Information","school":"École Supérieure d'Informatique (ESI), Burkina Faso","date":"Oct 2019 - Fév 2023"}],"experience":[{"role":"Ingénieur Data & Systèmes d'Information","company":"CDC Informatique, Bagneux","date":"Sept 2024 - Sept 2026","tasks":["Conçu en Python et déployé PYMQCOPY (MQ Series, Bash, Control-M), programme critique de routage de messages vers le cloud et les micro-services : 200+ flux/jour, avec suivi des incidents et correction en production.","Modélisé et documenté un Référentiel des Services Flux (80+ services) avec 3 équipes IT, base de l'analyse d'impact des évolutions du SI.","Diagnostiqué avec des équipes pluridisciplinaires des problèmes techniques complexes, identifié les causes et proposé des corrections."]},{"role":"Bénévole - Mentorat et Accompagnement","company":"AFEV, Calais","date":"Sept 2023 - Sept 2024","tasks":["Accompagnement régulier de jeunes en difficulté scolaire : pédagogie et partage de connaissances.","Création de lien dans les quartiers populaires, renforçant ma communication et mon adaptabilité."]},{"role":"Ingénieur Full Stack","company":"Orange, Ouagadougou","date":"Sept 2022 - Sept 2023","tasks":["PNP+ (Angular, Spring Boot, PostgreSQL) : traduit les besoins des équipes métier en spécifications, puis développé l'outil qui automatise la conception des offres commerciales, soit -60% de temps de production d'une proposition.","Refonte des portails MySpace (parcours d'éligibilité fibre) et BourseFondation (gestion des bourses) en API REST et micro-services, avec traitement sécurisé des données : +30% de sessions."]},{"role":"Software Engineer","company":"WAKATLAB, Ouagadougou","date":"Sept 2021 - Oct 2021","tasks":["Conception et réalisation collaborative de projets IoT.","Développement logiciel et intégration matérielle."]}],"techSkills":[{"cat":"Langages","tools":"Python, Java, TypeScript, JavaScript, SQL, Bash, C, PHP, Kotlin"},{"cat":"IA Générative & LLM","tools":"OpenAI API, LangChain, RAG, Embeddings, Prompt engineering, Hugging Face, Stable Diffusion, Fine-tuning LoRA, LCM-LoRA, ControlNet, n8n"},{"cat":"IA & Machine Learning","tools":"PyTorch, TensorFlow, Keras, Scikit-learn, Vision par ordinateur, YOLO, OpenCV, DeepFace, NLP, Deep Learning (CNN/RNN/GAN/VAE), ONNX, TFLite"},{"cat":"Back-end & API","tools":"Spring Boot, FastAPI, Node.js, NestJS, ExpressJS, Laravel, REST, GraphQL, WebSocket, Swagger, Postman, JWT, Keycloak"},{"cat":"Front-end & Mobile","tools":"Angular, React, Next.js, Flutter, Android, Tailwind, Bootstrap, SASS, HTML/CSS, PWA"},{"cat":"Bases de données & Data","tools":"PostgreSQL, MySQL, SQL Server, Oracle Database, MongoDB, Redis, Supabase, Firebase, DBeaver, Pandas, NumPy, Power BI, dbt, Excel, Modélisation Merise"},{"cat":"Intégration & Exploitation SI","tools":"MQ Series, Control-M, Messagerie asynchrone, Linux, Analyse d'impact, Documentation technique"},{"cat":"DevOps & Méthodes","tools":"Docker, Git, GitHub Actions CI/CD, Kubernetes, Ansible, Scrum, UML"},{"cat":"Sécurité & Conformité","tools":"RGPD, ISO 27001, HDS, LCB-FT, Classification des données, Protection des données"},{"cat":"Mathématiques & Statistiques","tools":"Algèbre linéaire, Théorie des graphes, Calcul différentiel, Statistiques, R, Matlab"}],"projects":[{"name":"PYMQCOPY – Routage de messages vers le cloud","meta":"CDC Informatique · 2024–2026","tech":"Python, MQ Series, Bash, ControlM, DBeaver","context":"Modernisation des échanges de messages MQ vers le cloud et les micro-services.","role":"Conception et développement du programme de routage.","result":"Programme critique en production, 200+ flux/jour acheminés, contribuant à la fiabilité de l'architecture SI.","link":"#","desc":"Contexte : Modernisation des échanges de messages MQ vers le cloud et les micro-services. Rôle : Conception et développement du programme de routage. Résultat : Programme critique en production, 200+ flux/jour acheminés, contribuant à la fiabilité de l'architecture SI."},{"name":"Référentiel des Services Flux – Cartographie applicative","meta":"CDC Informatique · 2024–2026","tech":"Python, PHP, Git, MQ Series, Bash, ControlM, DBeaver","context":"Manque de visibilité centralisée sur les services d'échange de flux et leurs dépendances.","role":"Modélisation et documentation du référentiel, en coordination avec 3 équipes IT.","result":"Référentiel de 80+ services, base de l'analyse d'impact des évolutions du SI.","link":"#","desc":"Contexte : Manque de visibilité centralisée sur les services d'échange de flux et leurs dépendances. Rôle : Modélisation et documentation du référentiel, en coordination avec 3 équipes IT. Résultat : Référentiel de 80+ services, base de l'analyse d'impact des évolutions du SI."},{"name":"PNP+ – Automatisation des offres commerciales","meta":"Orange · 2022–2023","tech":"Angular, Spring Boot, PostgreSQL","context":"Conception manuelle et chronophage des offres et propositions commerciales.","role":"Développement full stack de l'outil, en lien avec les besoins des équipes métier.","result":"Outil d'automatisation livré, soit -60% de temps de production d'une proposition.","link":"#","desc":"Contexte : Conception manuelle et chronophage des offres et propositions commerciales. Rôle : Développement full stack de l'outil, en lien avec les besoins des équipes métier. Résultat : Outil d'automatisation livré, soit -60% de temps de production d'une proposition."},{"name":"MySpace – Refonte du portail client","meta":"Orange · 2022–2023","tech":"Angular, Spring Boot, Laravel, PostgreSQL","context":"Portail client avec parcours interactif d'éligibilité fibre et espace de gestion centralisée des abonnements.","role":"Refonte en API REST et micro-services, avec traitement sécurisé des données.","result":"Portail refondu, +30% de sessions.","link":"https://mafibre.orange.bf/eligibilite","desc":"Contexte : Portail client avec parcours interactif d'éligibilité fibre et espace de gestion centralisée des abonnements. Rôle : Refonte en API REST et micro-services, avec traitement sécurisé des données. Résultat : Portail refondu, +30% de sessions."},{"name":"Bourse Fondation – Gestion centralisée des bourses","meta":"Orange · 2022–2023","tech":"Angular, Spring Boot, Laravel, PostgreSQL","context":"Traitement des dossiers de bourses dispersé et peu sécurisé.","role":"Refonte en API REST et micro-services, avec traitement sécurisé des dossiers.","result":"Application refondue, flux d'informations centralisés et optimisés.","link":"https://www.orange.bf/fr/rse/fondation-bourse.html","desc":"Contexte : Traitement des dossiers de bourses dispersé et peu sécurisé. Rôle : Refonte en API REST et micro-services, avec traitement sécurisé des dossiers. Résultat : Application refondue, flux d'informations centralisés et optimisés."},{"name":"Faso Connect – Traduction et synthèse vocale","meta":"Projet personnel · 2026","tech":"FastAPI, Meta NLLB-200, MMS-TTS, Redis, Docker, PostgreSQL","context":"Besoin d'outils linguistiques pour les langues du Burkina Faso.","role":"Architecture, développement et déploiement conteneurisé.","result":"API couvrant 7 langues (mooré, dioula, fulfulde, etc.), pipeline de fine-tuning, cache Redis et historisation des requêtes.","link":"https://github.com/bagus-full-stack/faso_connect_api","desc":"Contexte : Besoin d'outils linguistiques pour les langues du Burkina Faso. Rôle : Architecture, développement et déploiement conteneurisé. Résultat : API couvrant 7 langues (mooré, dioula, fulfulde, etc.), pipeline de fine-tuning, cache Redis et historisation des requêtes."},{"name":"AI Health Chef – Analyse nutritionnelle par IA","meta":"Projet personnel · 2025","tech":"Flutter, Riverpod, GoRouter, Supabase, OpenAI Vision","context":"Estimation des apports nutritionnels à partir de photos de repas.","role":"Conception et développement de l'application mobile et de l'intégration LLM.","result":"Classification de 300+ aliments, estimation en <2 s, dashboard temps réel (calories, macronutriments) et coach conversationnel.","link":"https://github.com/bagus-full-stack/ai-heath-chef","desc":"Contexte : Estimation des apports nutritionnels à partir de photos de repas. Rôle : Conception et développement de l'application mobile et de l'intégration LLM. Résultat : Classification de 300+ aliments, estimation en <2 s, dashboard temps réel (calories, macronutriments) et coach conversationnel."},{"name":"Spare – Suivi budgétaire FinTech","meta":"Projet personnel · 2024","tech":"React, Node.js, Firebase","context":"Suivi de budget à partir de données bancaires réelles.","role":"Conception et développement full stack.","result":"Synchronisation bancaire par API, authentification JWT, actualisation des transactions en temps réel.","link":"https://github.com/bagus-full-stack/spare/tree/dev","desc":"Contexte : Suivi de budget à partir de données bancaires réelles. Rôle : Conception et développement full stack. Résultat : Synchronisation bancaire par API, authentification JWT, actualisation des transactions en temps réel."},{"name":"SympsonIMG – Génération d'images par IA","meta":"Projet personnel","tech":"Next.js, FastAPI, PyTorch, HuggingFace Diffusers, Stable Diffusion, LoRA, LCM-LoRA, ControlNet, Inpainting","context":"Besoin d'une génération d'images rapide et personnalisable, sans temps d'inférence prohibitif.","role":"Conception full stack et du pipeline d'IA générative, y compris l'entraînement d'un modèle LoRA personnalisé.","result":"Application Text-to-Image, Inpainting et ControlNet, génération en ~1 s grâce à LCM-LoRA.","link":"#","desc":"Contexte : Besoin d'une génération d'images rapide et personnalisable, sans temps d'inférence prohibitif. Rôle : Conception full stack et du pipeline d'IA générative, y compris l'entraînement d'un modèle LoRA personnalisé. Résultat : Application Text-to-Image, Inpainting et ControlNet, génération en ~1 s grâce à LCM-LoRA."},{"name":"RealTime Detection – Surveillance vidéo intelligente","meta":"Projet personnel","tech":"Python, YOLOv11, DeepFace, OpenCV, NumPy, PyQt6","context":"Besoin de surveillance vidéo avec traçabilité des événements détectés.","role":"Développement de bout en bout (détection, tracking, reconnaissance faciale, interface).","result":"Application autonome avec preuves visuelles horodatées, historique CSV et galerie de gestion des visages. Interface réactive (threading) et limitation des logs redondants (cooldown).","link":"#","desc":"Contexte : Besoin de surveillance vidéo avec traçabilité des événements détectés. Rôle : Développement de bout en bout (détection, tracking, reconnaissance faciale, interface). Résultat : Application autonome avec preuves visuelles horodatées, historique CSV et galerie de gestion des visages. Interface réactive (threading) et limitation des logs redondants (cooldown)."},{"name":"Bagus Checker AI – Jeu de dames avec moteur d'IA","meta":"Projet personnel","tech":"Angular, NestJS, Socket.IO, Tailwind, Minimax, Alpha-Beta Pruning, MCTS","context":"Jeu de dames proposant des adversaires IA de niveaux variés et une analyse de parties.","role":"Conception full stack et du moteur d'IA multi-niveaux.","result":"Modes local, multijoueur temps réel et IA (Minimax, Alpha-Beta, MCTS), évaluation heuristique, bibliothèque d'ouvertures et analyse post-partie avec recommandations stratégiques.","link":"https://github.com/bagus-full-stack/bagus-checkers","desc":"Contexte : Jeu de dames proposant des adversaires IA de niveaux variés et une analyse de parties. Rôle : Conception full stack et du moteur d'IA multi-niveaux. Résultat : Modes local, multijoueur temps réel et IA (Minimax, Alpha-Beta, MCTS), évaluation heuristique, bibliothèque d'ouvertures et analyse post-partie avec recommandations stratégiques."},{"name":"MathViz – Visualisation mathématique","meta":"Projet personnel","tech":"Next.js, Plotly.js, Tailwind, Math.js","context":"Besoin d'outils visuels pour comprendre des fonctions en 2D, 3D et N dimensions.","role":"Conception et développement de la plateforme.","result":"Visualisations avec projection, animation et colorimétrie, plus outils de calcul de dérivées, d'intégrales et de points critiques.","link":"https://github.com/bagus-full-stack/mathVisualisation","desc":"Contexte : Besoin d'outils visuels pour comprendre des fonctions en 2D, 3D et N dimensions. Rôle : Conception et développement de la plateforme. Résultat : Visualisations avec projection, animation et colorimétrie, plus outils de calcul de dérivées, d'intégrales et de points critiques."},{"name":"FoundAgain – Géolocalisation d'objets perdus","meta":"Projet personnel","tech":"Angular, Tailwind, Firebase","context":"Initiative solidaire pour retrouver des objets perdus.","role":"Développement front-end et intégration des services cloud Firebase.","result":"Application déployée, synchronisation des données utilisateurs en temps réel.","link":"https://found-again-4a0e0.web.app/","desc":"Contexte : Initiative solidaire pour retrouver des objets perdus. Rôle : Développement front-end et intégration des services cloud Firebase. Résultat : Application déployée, synchronisation des données utilisateurs en temps réel."},{"name":"Bagus Portfolio – Portfolio avec CMS sur-mesure","meta":"Projet personnel","tech":"HTML, CSS, JavaScript, Supabase, CI/CD, PWA","context":"Besoin d'un portfolio éditable sans redéploiement.","role":"Conception et développement complets.","result":"Portfolio avec CMS intégré (édition sécurisée par authentification, stockage de médias), chatbot IA à reconnaissance vocale, thèmes animés (Canvas) et terminal interactif caché.","link":"https://github.com/bagus-full-stack/light_cv_to_portfolio","desc":"Contexte : Besoin d'un portfolio éditable sans redéploiement. Rôle : Conception et développement complets. Résultat : Portfolio avec CMS intégré (édition sécurisée par authentification, stockage de médias), chatbot IA à reconnaissance vocale, thèmes animés (Canvas) et terminal interactif caché."},{"name":"Blue Attendance – Présence par détection Bluetooth","meta":"Projet académique","tech":"Java, XML, FastAPI, Android Studio","context":"Saisie manuelle des présences lente et sujette aux erreurs.","role":"Conception et développement de l'application Android et de l'API REST.","result":"Prise de présence automatisée par Bluetooth, synchronisation sécurisée des données.","link":"#","desc":"Contexte : Saisie manuelle des présences lente et sujette aux erreurs. Rôle : Conception et développement de l'application Android et de l'API REST. Résultat : Prise de présence automatisée par Bluetooth, synchronisation sécurisée des données."},{"name":"Projet IoT – Dashboard de capteurs connectés","meta":"Projet académique","tech":"React, Node.js, PostgreSQL","context":"Besoin de suivre en temps réel les données de capteurs connectés.","role":"Développement full stack, de l'ingestion à la visualisation.","result":"Dashboard temps réel avec traitement des données de capteurs.","link":"#","desc":"Contexte : Besoin de suivre en temps réel les données de capteurs connectés. Rôle : Développement full stack, de l'ingestion à la visualisation. Résultat : Dashboard temps réel avec traitement des données de capteurs."},{"name":"Technology Transfer – Plateforme de mise en relation","meta":"Projet académique","tech":"HTML, CSS, Bootstrap, MySQL","context":"Faciliter la mise en relation autour du transfert de technologies.","role":"Développement de la plateforme et conception du schéma relationnel.","result":"Plateforme web fonctionnelle adossée à une base de données modélisée.","link":"#","desc":"Contexte : Faciliter la mise en relation autour du transfert de technologies. Rôle : Développement de la plateforme et conception du schéma relationnel. Résultat : Plateforme web fonctionnelle adossée à une base de données modélisée."},{"name":"Todo List – Application sécurisée avec back-office","meta":"Projet académique","tech":"PHP, Laravel, Voyager","context":"Application de gestion de tâches nécessitant des accès sécurisés.","role":"Développement full stack.","result":"Authentification complète avec vérification par email et panel d'administration back-office.","link":"#","desc":"Contexte : Application de gestion de tâches nécessitant des accès sécurisés. Rôle : Développement full stack. Résultat : Authentification complète avec vérification par email et panel d'administration back-office."},{"name":"Checkers Game – Jeu de dames en ligne de commande","meta":"Projet académique","tech":"C, Linux","context":"Projet d'algorithmique en environnement Unix.","role":"Conception de la logique métier et implémentation du jeu.","result":"Jeu de dames interactif en ligne de commande.","link":"https://github.com/bagus-full-stack/jeu_dames_C","desc":"Contexte : Projet d'algorithmique en environnement Unix. Rôle : Conception de la logique métier et implémentation du jeu. Résultat : Jeu de dames interactif en ligne de commande."},{"name":"ESI Website – Site institutionnel","meta":"Projet académique","tech":"HTML, CSS, Bootstrap","context":"Site vitrine institutionnel de l'école.","role":"Intégration front-end.","result":"Site responsive, compatible multi-écrans, navigation intuitive.","link":"#","desc":"Contexte : Site vitrine institutionnel de l'école. Rôle : Intégration front-end. Résultat : Site responsive, compatible multi-écrans, navigation intuitive."},{"name":"UI Calculator & Keyboard – Interface accessible","meta":"Projet académique","tech":"HTML, CSS, SCSS","context":"Exercice d'interface centré sur l'accessibilité et la modularité du style.","role":"Intégration et design de l'interface.","result":"Clavier virtuel et calculatrice interactifs, design pixel-perfect, styles modulaires.","link":"#","desc":"Contexte : Exercice d'interface centré sur l'accessibilité et la modularité du style. Rôle : Intégration et design de l'interface. Résultat : Clavier virtuel et calculatrice interactifs, design pixel-perfect, styles modulaires."}],"certifications":[{"name":"Supervised Machine Learning: Regression and Classification (Coursera / DeepLearning.AI)","link":"./images/supervised_machine_learning_certificate.jpg"},{"name":"Python Data Structures","link":"./images/python_data_structures_certificate.jpg"},{"name":"SQL","link":"./images/sql_certificate.jpg"},{"name":"Java","link":"./images/java_certificate.jpg"},{"name":"JavaScript","link":"./images/javascript_certificate.jpg"},{"name":"Conformité et sécurité (RGPD, ISO 27001 / HDS, LCB-FT) – CDC Informatique","link":"#"},{"name":"C","link":"./images/c_certificate.jpg"},{"name":"HTML","link":"./images/html_certificate.jpg"},{"name":"CSS","link":"./images/css_certificate.jpg"},{"name":"PHP","link":"./images/php_certificate.jpg"},{"name":"Python for Beginner","link":"./images/python_for_beginner_certificate.jpg"},{"name":"Coding marketers","link":"./images/coding_marketers_certificate.jpg"},{"name":"Responsive Web Design","link":"./images/responsive_web_design_certificate.jpg"},{"name":"Intro référentiel HDS & ISO 27001","link":"#"},{"name":"Sensibilisation PUPA","link":"#"},{"name":"Fondamentaux de la LCB-FT","link":"#"},{"name":"RGPD - Protection données","link":"#"},{"name":"Classification et protection données","link":"#"},{"name":"Déontologie code","link":"#"},{"name":"Evacuation et sécurité incendie","link":"#"}]}$seed$::jsonb)
on conflict (id) do nothing;
