// J'ai changé v1 en v2 pour forcer la mise à jour
const CACHE_NAME = 'portfolio-assami-v2';

const ASSETS_TO_CACHE = [
    './',                // <--- LA LIGNE MANQUANTE (La racine du site)
    './index.html',
    './manifest.json',
    'https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css',
    'https://unpkg.com/vis-network/standalone/umd/vis-network.min.js',
    'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2'
];

// Installation du Service Worker
self.addEventListener('install', (event) => {
    event.waitUntil(
        caches.open(CACHE_NAME).then((cache) => {
            console.log('[Service Worker] Mise en cache des fichiers');
            return cache.addAll(ASSETS_TO_CACHE);
        })
    );
});

// Activation et nettoyage des anciens caches
self.addEventListener('activate', (event) => {
    event.waitUntil(
        caches.keys().then((keyList) => {
            return Promise.all(keyList.map((key) => {
                if (key !== CACHE_NAME) {
                    console.log('[Service Worker] Suppression ancien cache', key);
                    return caches.delete(key);
                }
            }));
        })
    );
    // Force le SW à prendre le contrôle immédiatement
    return self.clients.claim(); 
});

// Interception des requêtes (Stratégie : Cache, puis Réseau)
self.addEventListener('fetch', (event) => {
    // On ne cache pas les appels API Supabase
    if (event.request.url.includes('supabase.co')) {
        return; 
    }

    event.respondWith(
        caches.match(event.request).then((response) => {
            return response || fetch(event.request);
        })
    );
});