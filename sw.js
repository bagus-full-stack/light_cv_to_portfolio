const CACHE_NAME = 'portfolio-assami-v1';
const ASSETS_TO_CACHE = [
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
                    return caches.delete(key);
                }
            }));
        })
    );
});

// Interception des requêtes (Stratégie : Cache, puis Réseau)
self.addEventListener('fetch', (event) => {
    // On ne cache pas les appels API Supabase pour avoir toujours les données fraîches
    if (event.request.url.includes('supabase.co')) {
        return; 
    }

    event.respondWith(
        caches.match(event.request).then((response) => {
            return response || fetch(event.request);
        })
    );
});