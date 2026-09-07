-- ============================================================
-- Schéma de migration Supabase pour myOnlineCV
-- À exécuter dans : Nouveau projet Supabase > SQL Editor > New query
-- ============================================================

-- ------------------------------------------------------------
-- 1. TABLE portfolio (contenu du CV, édité via le mode admin)
-- ------------------------------------------------------------
create table if not exists public.portfolio (
  id int primary key,
  json_data jsonb not null,
  updated_at timestamptz not null default now()
);

alter table public.portfolio enable row level security;

create policy "portfolio_public_read"
  on public.portfolio for select
  to anon, authenticated
  using (true);

create policy "portfolio_admin_write"
  on public.portfolio for insert
  to authenticated
  with check (true);

create policy "portfolio_admin_update"
  on public.portfolio for update
  to authenticated
  using (true)
  with check (true);

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

create policy "messages_public_insert"
  on public.messages for insert
  to anon, authenticated
  with check (true);

create policy "messages_admin_read"
  on public.messages for select
  to authenticated
  using (true);

create policy "messages_admin_delete"
  on public.messages for delete
  to authenticated
  using (true);

-- ------------------------------------------------------------
-- 3. TABLE site_stats (compteur de visites)
-- ------------------------------------------------------------
create table if not exists public.site_stats (
  id int primary key,
  visits bigint not null default 0
);

alter table public.site_stats enable row level security;

create policy "site_stats_public_read"
  on public.site_stats for select
  to anon, authenticated
  using (true);

insert into public.site_stats (id, visits) values (1, 0)
  on conflict (id) do nothing;

-- Fonction RPC appelée par le site à chaque nouvelle visite.
-- SECURITY DEFINER : permet à un visiteur anonyme d'incrémenter le
-- compteur sans lui donner un accès UPDATE direct sur la table.
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
-- 4. TABLE visitor_logs (ville/pays des visiteurs, via ipapi.co)
-- ------------------------------------------------------------
create table if not exists public.visitor_logs (
  id bigint generated always as identity primary key,
  city text,
  country text,
  created_at timestamptz not null default now()
);

alter table public.visitor_logs enable row level security;

create policy "visitor_logs_public_insert"
  on public.visitor_logs for insert
  to anon, authenticated
  with check (true);

create policy "visitor_logs_admin_read"
  on public.visitor_logs for select
  to authenticated
  using (true);

-- ------------------------------------------------------------
-- 5. STORAGE : bucket 'uploads' (photo de profil, CV PDF)
-- ------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('uploads', 'uploads', true)
on conflict (id) do nothing;

create policy "uploads_public_read"
  on storage.objects for select
  to anon, authenticated
  using (bucket_id = 'uploads');

create policy "uploads_admin_write"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'uploads');

create policy "uploads_admin_update"
  on storage.objects for update
  to authenticated
  using (bucket_id = 'uploads');

create policy "uploads_admin_delete"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'uploads');

-- ------------------------------------------------------------
-- 6. SEED : contenu du CV (repris du fallback DEFAULT_DATA
--    codé en dur dans index.html, seule copie encore disponible
--    puisque l'ancien projet Supabase a été supprimé)
-- ------------------------------------------------------------
insert into public.portfolio (id, json_data) values (1, $${"personal":{"name":"Assami BAGA","title":"Full Stack & IA Engineer","availability":"Disponible dès Septembre 2026","email":"bagaassami09@gmail.com","phone":"07 53 49 67 71","location":"Ile de france","linkedin":"assami-baga","social":"bagus-full-stack","summary":"Étudiant en dernière année d'école d'ingénieur (Bac+5) spécialisé en Ingénierie Logicielle et IA, passionné par l'innovation technologique et la mobilité de demain. Orienté résultats et doté d'un fort esprit d'analyse, je conçois des solutions IA et logicielles industrialisées. Proactif et habitué aux environnements exigeants, je suis à la recherche active d'un contrat à durée indéterminée (CDI). afin de développer des solutions Data/IA impactantes, collaborer avec des équipes multiculturelles et accélérer mon expertise technique dès septembre 2026."},"softSkills":["Polyvalence","Efficacité","Créativité","Adaptabilité","Collaboration","Autonomie","Curiosité","Proactivité","Résolution de problèmes","Orienté résultat","Volonté d'apprendre"],"languages":["Français","Anglais"],"education":[{"degree":"Diplôme d'ingénieur en Ingénierie Logicielle et Intelligence Artificielle","school":"École d'Ingénieur du Littoral Côte d'Opale (EILCO), Calais, France","date":"Depuis septembre 2023"},{"degree":"PUPA, LCB-FT, HDS, ISO 27001, Déontologie","school":"CDC Informatique, Bagneux","date":"Jan 2025 - Déc 2025"},{"degree":"RGPD, Protection des données, Sécurité incendie, HDS, ISO 27001","school":"CDC Informatique, Bagneux","date":"Jan 2024 - Déc 2024"},{"degree":"Technologie IP, SQL, Linux, Scripting Shell","school":"Essitech, Ouagadougou","date":"Juin 2023"},{"degree":"Langages C, Linux, Arduino, Électronique, Hacking","school":"Struct IOT & Assoc Linux, Bobo-Dioulasso","date":"Jan 2020 - Juil 2021"},{"degree":"Licence en Ingénierie des Systèmes d'Information","school":"Ecole Superieure d'Informatique (ESI), Burkina Faso","date":"Oct 2019 - Fév 2023"}],"experience":[{"role":"Full Stack Engineer","company":"CDC Informatique, Bagneux","date":"Depuis septembre 2024","tasks":["Conception et développement de PYMQCOPY, un programme critique optimisant le routage et la copie des messages MQ vers de multiples destinations, assurant la fluidité des flux de données","Modélisation et réalisation d'un Référentiel des Services Flux (en cours), contribuant à la fiabilité et à lacartographie de l'architecture logicielle","Collaboration quotidienne avec des équipes IT pluridisciplinaires pour diagnostiquer et apporter de nouvelles solutions à des problématiques techniques compexes"]},{"role":"Bénévole - Mentorat et Accompagnement","company":"AFEV Calais","date":"Sept 2023 - Sept 2024","tasks":["Accompagnement des jeunes en difficulté scolaire","Création de lien dans les quartiers populaires","Renforcement l'ouverture d'esprit, la communication et l'adaptabilité"]},{"role":"Full Stack Engineer","company":"Orange & Smile, Ouagadougou","date":"Sept 2022 - Sept 2023","tasks":["Développement de \"PNP+\", un système intelligent automatisant la conception des offres et promotions, intégrant des algorithmes d'analyse pour cibler les besoins métier.","Participation active au développement full-stack de la plateforme MySpace et de BourseFondation","Apport de solutions logicielles innovantes pour soutenir la stratégie digitale de l'entreprise"]},{"role":"Software Engineer","company":"WAKATLAB, Ouagadougou","date":"Sept 2021 - Oct 2021","tasks":["Conception et réalisation collaborative de projets IoT","Développement logiciel et intégration matérielle"]}],"techSkills":[{"cat":"Dev Multiplateforme","tools":"HTML, CSS, JS, TS, SASS, Bootstrap, Tailwind, WordPress, Flutter, Flutter Flow, Java, Pygame, JavaFX, Angular, React, Kotlin, Docker, Tkinter, MQ Series"},{"cat":"API RESTFUL","tools":"NodeJS, ExpressJS, NestJS, Spring, FastAPI, Laravel, Keycloak, JWT, Postman, Git, Bitbucket, Swagger"},{"cat":"Conception & Modeling","tools":"UML, Merise, Scrum, Power AMC, Adobe XD, Figma, JSON, XML, Classic Ladder, LabVIEW"},{"cat":"Mathématiques & Statistiques","tools":"Algèbre linéaire, Théorie des graphes, Calcul différentiel, Analyse statistiques, R, Matlab"},{"cat":"Administration de Base de Données","tools":"MySQL, MariaDB, PostgreSQL, Oracle Database, SQL Server, DBeaver, MongoDB, Supabase, Firebase"},{"cat":"Langages de Programmation","tools":"C, Java, Javascript, TypeScript, Python, R, PHP, Kotlin, Bash, Arduino, VHDL"},{"cat":"Machine Learning & Deep Learning","tools":"TensorFlow, Scikit-learn, PyTorch, Keras, YOLO, Modèles Génératifs (CNN, RNN, GAN, VAE), Fidle, N8N, Pandas, NumPy, Seaborn, Matplotlib, Power BI, JupyterNotebook"}],"projects":[{"name":"Blue Attendance","desc":"Application mobile Android automatisant la prise de présence par détection Bluetooth, couplée à une API REST pour la synchronisation sécurisée des données.","tech":"Java, Xml, FastAPI, Android Studio","link":"#"},{"name":"PNP+","desc":"Système intelligent automatisant la conception des offres et promotions, intégrant des algorithmes d'analyse pour cibler les besoins métier.","tech":"Angular, Spring boot, SQL","link":"#"},{"name":"Myspace","desc":"Portail client full-stack intégrant un parcours interactif de test d'éligibilité à la fibre optique et un espace de gestion centralisée des abonnements télécoms.","tech":"Angular, Spring boot, Laravel, PostgreSQL","link":"https://mafibre.orange.bf/eligibilite"},{"name":"Bourse Fondation","desc":"Application web dédié à la gestion centralisée des bourses, assurant le traitement sécurisé des dossiers et l'optimisation des flux d'informations.","tech":"Angular, Spring boot, Laravel, PostgreSQL","link":"https://www.orange.bf/fr/rse/fondation-bourse.html"},{"name":"UI Calculator & Keyboard","desc":"Création d'une interface interactive de clavier virtuel et de calculatrice, avec un focus sur l'accessibilité, le design pixel-perfect et la modularité du style.","tech":"HTML, CSS, SCSS","link":"#"},{"name":"Projet IOT","desc":"Dashboard full-stack permettant la visualisation en temps réel et le traitement de données issues de capteurs connectés.","tech":"React, Node.js, PostgreSQL","link":"#"},{"name":"ESI Website","desc":"Intégration front-end du site vitrine institutionnel de l'école (ESI), garantissant une navigation intuitive et une compatibilité multi-écrans.","tech":"HTML, CSS, Bootstrap","link":"#"},{"name":"Checkers Game","desc":"Implémentation de l'algorithmique et de la logique métier pour un jeu de dames interactif en ligne de commande sous environnement Unix.","tech":"C, Linux","link":"https://github.com/bagus-full-stack/jeu_dames_C"},{"name":"Todo List","desc":"Application web sécurisée intégrant un système complet d'authentification (vérification par email) et un panel d'administration back-office.","tech":"PHP, Laravel, Voyager","link":"#"},{"name":"Technology Transfer","desc":"Plateforme web facilitant la mise en relation pour le transfert de technologies, incluant la conception du schéma relationnel de la base de données.","tech":"HTML, CSS, Bootstrap, MySql","link":"#"},{"name":"Spare","desc":"Application FinTech de suivi budgétaire intégrant la synchronisation bancaire via API et l'actualisation des transactions en temps réel.","tech":"React, Node.js, Firebase","link":"https://github.com/bagus-full-stack/spare/tree/dev"},{"name":"FoundAgain","desc":"Application solidaire pour la géolocalisation d'objets perdus. Développement Front-end et intégration de services Cloud (Firebase) pour la synchronisation des données utilisateurs en temps réel.","tech":"Angular, Tailwind, Firebase","link":"https://found-again-4a0e0.web.app/"},{"name":"PYMQCOPY","desc":"Programme critique optimisant le routage et la copie des messages MQ vers de multiples destinations, assurant la fluidité des flux de données.","tech":"Python, MQ Series, Bash, ControlM, DBeaver","link":"#"},{"name":"Référentiel","desc":"Modélisation et réalisation d'un Référentiel des Services Flux (en cours), contribuant à la fiabilité et à lacartographie de l'architecture logicielle.","tech":"Python, PHP, Git, MQ Series, Bash, ControlM, DBeaver","link":"#"},{"name":"Bagus Portfolio","desc":"Portfolio web dynamique intégrant son propre système de gestion de contenu (CMS) sur-mesure. Grâce à l'intégration de Supabase, l'interface permet une édition directe du contenu sécurisée par authentification, ainsi que le stockage de fichiers multimédias. Le projet se distingue par des fonctionnalités interactives avancées, notamment un chatbot IA équipé d'une reconnaissance vocale, des animations Canvas pour la gestion des thèmes, et un terminal caché interactif de type \"Easter egg.\"","tech":"HTML, CSS, JavaScript, Supabase, CI/CD, PWA","link":"https://github.com/bagus-full-stack/light_cv_to_portfolio"},{"name":"AI Health Chef","desc":"Application mobile qui aide les utilisateurs à suivre leur alimentation grâce à l'analyse IA de repas à partir de photos. L'application intègre une authentification sécurisée, un dashboard nutritionnel en temps réel (calories et macronutriments), un coach conversationnel IA, ainsi qu'un backend Supabase (base de données, auth et Edge Functions).","tech":"Flutter, Riverpod, GoRouter, Supabase, Image Picker","link":"https://github.com/bagus-full-stack/ai-heath-chef"},{"name":"Bagus Checker AI","desc":"Jeu de dames complet proposant des modes local, multijoueur temps réel et IA. Conception d'un moteur d'intelligence artificielle multi-niveaux s'appuyant sur les algorithmes Minimax, Alpha-Beta Pruning et Monte Carlo Tree Search (MCTS). L'application se distingue par ses outils d'analyse poussés, incluant une évaluation heuristique complexe, une bibliothèque d'ouvertures et un module d'analyse post-partie générant des recommandations stratégiques.","tech":"Angular, NestJS, Socket.IO, Tailwind, Minimax & Alpha-Beta Pruning, MCTS","link":"https://github.com/bagus-full-stack/bagus-checkers"},{"name":"RealTime Detection","desc":"Application autonome de surveillance vidéo en temps réel qui combine détection d'objets (YOLOv11), tracking, et reconnaissance/analyses faciales (DeepFace). L'outil capture automatiquement des preuves visuelles horodatées, écrit un historique structuré (CSV), et offre une galerie pour la gestion manuelle des visages (renommer / supprimer). L'interface, réalisée en PyQt6, permet de basculer entre modèles, régler la qualité vidéo, activer/désactiver le tracking et la reconnaissance, et effectuer des captures manuelles. Le projet inclut des optimisations pour maintenir l'interface réactive (threading) et un mécanisme de cooldown pour limiter les écritures redondantes dans les logs.","tech":"Python, YOLO, DeepFace, OpenCV, NumPy, PyQt6","link":"#"},{"name":"SympsonIMG","desc":"Application Full-Stack (Next.js, FastAPI) de génération d'images par IA. Conception et intégration d'un pipeline d'IA générative basé sur les modèles de diffusion (PyTorch, HuggingFace, Stable Diffusion v1.5), incluant l'entraînement d'un modèle LoRA personnalisé. Implémentation de fonctionnalités avancées de manipulation d'images (Text-to-Image, Inpainting, ControlNet) et optimisation drastique des temps d'inférence (génération en ~1s) grâce à la technologie LCM-LoRA.","tech":"Next.js, FastAPI, PyTorch, HuggingFace Diffusers, Stable Diffusion, LoRA, LCM-LoRA, ControlNet Canny, Inpainting","link":"#"},{"name":"MathViz","desc":"Plateforme web immersive, moderne dédiée à la visualisation mathématique en 2D, 3D et N dimensions grâce à des techniques avancées de projection, d'animation et de colorimétrie. En plus d'intégrer des outils d'analyse performants pour le calcul de dérivées, d'intégrales et l'étude de points critiques.","tech":"Next.js, Plotly.js, Tailwind, Math.js","link":"https://github.com/bagus-full-stack/mathVisualisation"}],"certifications":[{"name":"C","link":"./images/c_certificate.jpg"},{"name":"HTML","link":"./images/html_certificate.jpg"},{"name":"CSS","link":"./images/css_certificate.jpg"},{"name":"Javascript","link":"./images/javascript_certificate.jpg"},{"name":"Java","link":"./images/java_certificate.jpg"},{"name":"PHP","link":"./images/php_certificate.jpg"},{"name":"SQL","link":"./images/sql_certificate.jpg"},{"name":"Python for Beginner","link":"./images/python_for_beginner_certificate.jpg"},{"name":"Python Data Structures","link":"./images/python_data_structures_certificate.jpg"},{"name":"Coding marketers","link":"./images/coding_marketers_certificate.jpg"},{"name":"Responsive Web Design","link":"./images/responsive_web_design_certificate.jpg"},{"name":"Intro référentiel HDS & ISO 27001","link":"#"},{"name":"Sensibilisation PUPA","link":"#"},{"name":"Fondamentaux de la LCB-FT","link":"#"},{"name":"RGPD - Protection données","link":"#"},{"name":"Classification et protection données","link":"#"},{"name":"Déontologie code","link":"#"},{"name":"Evacuation et sécurité incendie","link":"#"},{"name":"Supervised Machine Learning: Regression and Classification","link":"./images/supervised_machine_learning_certificate.jpg"}]}$$::jsonb)
on conflict (id) do update set json_data = excluded.json_data;
