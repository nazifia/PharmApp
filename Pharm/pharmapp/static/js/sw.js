const CACHE_NAME = 'pharmapp-v3';
const API_CACHE_NAME = 'pharmapp-api-v3';
const STATIC_CACHE_NAME = 'pharmapp-static-v3';
const OFFLINE_URL = '/offline/';

// Add sync queue
let syncQueue = [];

const URLS_TO_CACHE = [
    // Core routes
    '/',
    '/dashboard/',
    '/store/',
    '/wholesale/',
    '/customer/',
    '/supplier/',
    '/offline/',
    
    // Static assets
    '/static/manifest.json',
    '/static/js/offline.js',
    '/static/js/form-handler.js',
    '/static/js/connection-handler.js',
    '/static/js/offline-storage.js',
    '/static/vendor/jquery/jquery.min.js',
    '/static/vendor/bootstrap/js/bootstrap.bundle.min.js',
    '/static/vendor/jquery-easing/jquery.easing.min.js',
    '/static/js/sb-admin-2.min.js',
    '/static/vendor/chart.js/Chart.min.js',
    '/static/css/sb-admin-2.min.css',
    '/static/vendor/fontawesome-free/css/all.min.css',
];

const API_ENDPOINTS = [
    '/api/data/initial/',
    '/api/inventory/',
    '/api/customers/',
    '/api/suppliers/',
    '/api/wholesale/',
];

// Cache static assets version
const STATIC_ASSETS = [
    '/static/img/icon-192x192.png',
    '/static/img/icon-512x512.png',
];

console.log('Service Worker: File loaded');

async function cacheUrls(cacheName, urls) {
    const cache = await caches.open(cacheName);
    const failedUrls = [];
    
    for (const url of urls) {
        try {
            await cache.add(url);
            console.log(`[ServiceWorker] Cached: ${url}`);
        } catch (error) {
            console.warn(`[ServiceWorker] Failed to cache: ${url}`, error);
            failedUrls.push(url);
        }
    }
    
    return failedUrls;
}

self.addEventListener('install', event => {
    console.log('[ServiceWorker] Install');
    event.waitUntil(
        Promise.all([
            cacheUrls(CACHE_NAME, URLS_TO_CACHE).then(failedUrls => {
                if (failedUrls.length > 0) {
                    console.warn('[ServiceWorker] Some app shell URLs failed to cache:', failedUrls);
                }
            }),
            cacheUrls(API_CACHE_NAME, API_ENDPOINTS).then(failedUrls => {
                if (failedUrls.length > 0) {
                    console.warn('[ServiceWorker] Some API endpoints failed to cache:', failedUrls);
                }
            }),
            cacheUrls(STATIC_CACHE_NAME, STATIC_ASSETS).then(failedUrls => {
                if (failedUrls.length > 0) {
                    console.warn('[ServiceWorker] Some static assets failed to cache:', failedUrls);
                }
            })
        ]).then(() => {
            console.log('[ServiceWorker] Install complete');
            return self.skipWaiting();
        })
    );
});

self.addEventListener('activate', event => {
    console.log('[ServiceWorker] Activate');
    event.waitUntil(
        Promise.all([
            self.clients.claim(),
            caches.keys().then(cacheNames => {
                return Promise.all(
                    cacheNames
                        .filter(cacheName => 
                            (cacheName.startsWith('pharmapp-') && 
                             cacheName !== CACHE_NAME && 
                             cacheName !== API_CACHE_NAME &&
                             cacheName !== STATIC_CACHE_NAME))
                        .map(cacheName => {
                            console.log('[ServiceWorker] Removing old cache', cacheName);
                            return caches.delete(cacheName);
                        })
                );
            })
        ])
    );
});

// Enhanced fetch handler with better offline support
self.addEventListener('fetch', event => {
    const url = new URL(event.request.url);
    
    // For API requests
    if (url.pathname.startsWith('/api/')) {
        event.respondWith(
            fetch(event.request)
                .then(response => {
                    // Cache successful API responses
                    if (response.status === 200) {
                        const responseToCache = response.clone();
                        caches.open(API_CACHE_NAME)
                            .then(cache => cache.put(event.request, responseToCache));
                    }
                    return response;
                })
                .catch(() => {
                    // Return cached response when offline
                    return caches.match(event.request)
                        .then(response => response || new Response(JSON.stringify({error: 'Offline'}), {
                            status: 503,
                            headers: {'Content-Type': 'application/json'}
                        }));
                })
        );
        return;
    }
    
    // For navigation requests
    if (event.request.mode === 'navigate') {
        event.respondWith(
            fetch(event.request)
                .catch(() => {
                    // Return offline page for navigation requests when offline
                    return caches.match(OFFLINE_URL)
                        .then(response => response || caches.match('/'));
                })
        );
        return;
    }
    
    // For other requests (static assets, etc.)
    event.respondWith(
        caches.match(event.request)
            .then(response => {
                // Return cached version if available
                if (response) {
                    return response;
                }
                
                // Otherwise fetch from network
                return fetch(event.request)
                    .then(response => {
                        // Cache successful responses for static assets
                        if (response.status === 200 && (
                            event.request.destination === 'style' ||
                            event.request.destination === 'script' ||
                            event.request.destination === 'image'
                        )) {
                            const responseToCache = response.clone();
                            caches.open(STATIC_CACHE_NAME)
                                .then(cache => cache.put(event.request, responseToCache));
                        }
                        return response;
                    })
                    .catch(() => {
                        // For images, try to return a placeholder
                        if (event.request.destination === 'image') {
                            return new Response('', {
                                status: 404,
                                statusText: 'Not Found'
                            });
                        }
                        return new Response(JSON.stringify({error: 'Offline'}), {
                            status: 503,
                            headers: {'Content-Type': 'application/json'}
                        });
                    });
            })
    );
});

// Background sync for form submissions
self.addEventListener('sync', event => {
    console.log('[Service Worker] Sync event:', event.tag);
    if (event.tag === 'sync-pending-actions') {
        event.waitUntil(syncPendingActions());
    }
});

// Function to sync pending actions
async function syncPendingActions() {
    console.log('[Service Worker] Syncing pending actions');
    
    try {
        const db = await openIndexedDB();
        const transaction = db.transaction(['syncQueue'], 'readonly');
        const store = transaction.objectStore('syncQueue');
        const request = store.getAll();
        
        const actions = await new Promise((resolve, reject) => {
            request.onsuccess = () => resolve(request.result);
            request.onerror = () => reject(request.error);
        });
        
        console.log('[Service Worker] Actions to sync:', actions);
        
        for (const action of actions) {
            try {
                const response = await fetch(action.action, {
                    method: action.method,
                    headers: {
                        'Content-Type': 'application/json',
                        'X-CSRFToken': getCSRFTokenFromCookie()
                    },
                    body: JSON.stringify(action.data)
                });
                
                if (response.ok) {
                    // Remove successfully synced action
                    await removeFromSyncQueue(action.id);
                    console.log('[Service Worker] Successfully synced action:', action.id);
                } else {
                    console.warn('[Service Worker] Failed to sync action:', action.id, response.status);
                    // Increment retry count
                    await updateSyncQueueItem(action.id, { 
                        retries: (action.retries || 0) + 1 
                    });
                }
            } catch (error) {
                console.error('[Service Worker] Sync failed for action:', action.id, error);
                // Increment retry count
                await updateSyncQueueItem(action.id, { 
                    retries: (action.retries || 0) + 1 
                });
            }
        }
        
        // Notify clients that sync is complete
        const clients = await self.clients.matchAll();
        clients.forEach(client => {
            client.postMessage({
                type: 'SYNC_COMPLETE',
                message: 'Background sync completed'
            });
        });
        
    } catch (error) {
        console.error('[Service Worker] Error during sync:', error);
    }
}

// Helper function to open IndexedDB
function openIndexedDB() {
    return new Promise((resolve, reject) => {
        const request = indexedDB.open('PharmAppDB', 4);
        request.onsuccess = () => resolve(request.result);
        request.onerror = () => reject(request.error);
    });
}

// Helper function to remove item from sync queue
function removeFromSyncQueue(id) {
    return openIndexedDB().then(db => {
        return new Promise((resolve, reject) => {
            const transaction = db.transaction(['syncQueue'], 'readwrite');
            const store = transaction.objectStore('syncQueue');
            const request = store.delete(id);
            request.onsuccess = () => resolve();
            request.onerror = () => reject(request.error);
        });
    });
}

// Helper function to update item in sync queue
function updateSyncQueueItem(id, updates) {
    return openIndexedDB().then(db => {
        return new Promise((resolve, reject) => {
            const transaction = db.transaction(['syncQueue'], 'readwrite');
            const store = transaction.objectStore('syncQueue');
            
            const getRequest = store.get(id);
            getRequest.onsuccess = () => {
                const item = getRequest.result;
                if (item) {
                    Object.assign(item, updates);
                    const putRequest = store.put(item);
                    putRequest.onsuccess = () => resolve();
                    putRequest.onerror = () => reject(putRequest.error);
                } else {
                    reject(new Error('Item not found'));
                }
            };
            getRequest.onerror = () => reject(getRequest.error);
        });
    });
}

// Helper function to get CSRF token from cookies
function getCSRFTokenFromCookie() {
    const name = 'csrftoken';
    let cookieValue = null;
    if (document.cookie && document.cookie !== '') {
        const cookies = document.cookie.split(';');
        for (let i = 0; i < cookies.length; i++) {
            const cookie = cookies[i].trim();
            if (cookie.substring(0, name.length + 1) === (name + '=')) {
                cookieValue = decodeURIComponent(cookie.substring(name.length + 1));
                break;
            }
        }
    }
    return cookieValue;
}

// Push notifications
self.addEventListener('push', event => {
    console.log('[Service Worker] Push received');
    
    let data = {};
    if (event.data) {
        data = event.data.json();
    }
    
    const title = data.title || 'PharmApp Notification';
    const options = {
        body: data.body || 'You have a new notification',
        icon: '/static/img/icon-192x192.png',
        badge: '/static/img/icon-192x192.png',
        tag: data.tag || 'pharmapp-notification',
        data: data.data || {},
        actions: data.actions || []
    };

    event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('notificationclick', event => {
    console.log('[Service Worker] Notification click received');
    
    event.notification.close();
    
    const url = event.notification.data.url || '/';
    event.waitUntil(
        self.clients.matchAll({type: 'window'})
            .then(clientList => {
                for (const client of clientList) {
                    if (client.url === url && 'focus' in client) {
                        return client.focus();
                    }
                }
                if (self.clients.openWindow) {
                    return self.clients.openWindow(url);
                }
            })
    );
});

// Handle push subscription
self.addEventListener('pushsubscriptionchange', event => {
    console.log('[Service Worker] Push subscription change');
    event.waitUntil(
        self.registration.pushManager.subscribe(event.oldSubscription.options)
            .then(subscription => {
                // Send the new subscription to your server
                return fetch('/api/save-subscription/', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        subscription: subscription
                    })
                });
            })
    );
});

// Placeholder functions - implement based on your offline storage mechanism
async function getPendingActions() {
    // Return array of pending actions
    return [];
}

async function removePendingAction(id) {
    // Remove action from storage
}