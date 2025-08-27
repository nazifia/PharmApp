/**
 * Background Sync Implementation for Form Submissions
 */

class BackgroundSyncManager {
    constructor() {
        this.syncQueue = 'syncQueue';
        this.maxRetries = 3;
    }

    /**
     * Add a form submission to the sync queue
     */
    async addToSyncQueue(formAction, formData, method = 'POST') {
        try {
            const syncItem = {
                id: Date.now() + Math.random(),
                action: formAction,
                data: formData,
                method: method,
                timestamp: new Date().toISOString(),
                retries: 0
            };

            await OfflineStorage.addToSyncQueue(syncItem);
            console.log('Added to sync queue:', syncItem);
            
            // Register background sync if available
            if ('serviceWorker' in navigator && 'SyncManager' in window) {
                const registration = await navigator.serviceWorker.ready;
                await registration.sync.register('sync-pending-actions');
                console.log('Background sync registered');
            }
            
            return syncItem.id;
        } catch (error) {
            console.error('Failed to add to sync queue:', error);
            throw error;
        }
    }

    /**
     * Process the sync queue when online
     */
    async processSyncQueue() {
        try {
            const db = await OfflineStorage.init();
            const items = await OfflineStorage.getAllFromStore('syncQueue');
            
            for (const item of items) {
                try {
                    // Skip items that have reached max retries
                    if (item.retries >= this.maxRetries) {
                        console.warn('Max retries reached for item:', item.id);
                        await this.removeFromSyncQueue(item.id);
                        continue;
                    }
                    
                    const response = await fetch(item.action, {
                        method: item.method,
                        headers: {
                            'Content-Type': 'application/json',
                            'X-CSRFToken': this.getCSRFToken()
                        },
                        body: JSON.stringify(item.data)
                    });
                    
                    if (response.ok) {
                        // Successfully synced, remove from queue
                        await this.removeFromSyncQueue(item.id);
                        console.log('Successfully synced item:', item.id);
                    } else {
                        // Increment retry count and update item
                        await this.updateSyncQueueItem(item.id, { 
                            retries: item.retries + 1 
                        });
                        console.warn('Failed to sync item, retry count:', item.retries + 1);
                    }
                } catch (error) {
                    // Network error, increment retry count
                    await this.updateSyncQueueItem(item.id, { 
                        retries: item.retries + 1 
                    });
                    console.error('Sync failed for item:', item.id, error);
                }
            }
        } catch (error) {
            console.error('Error processing sync queue:', error);
        }
    }

    /**
     * Remove an item from the sync queue
     */
    async removeFromSyncQueue(id) {
        const db = await OfflineStorage.init();
        return new Promise((resolve, reject) => {
            const transaction = db.transaction(['syncQueue'], 'readwrite');
            const store = transaction.objectStore('syncQueue');
            
            const request = store.delete(id);
            request.onsuccess = () => resolve();
            request.onerror = () => reject(request.error);
        });
    }

    /**
     * Update an item in the sync queue
     */
    async updateSyncQueueItem(id, updates) {
        const db = await OfflineStorage.init();
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
    }

    /**
     * Get CSRF token for Django forms
     */
    getCSRFToken() {
        const csrfToken = document.querySelector('[name=csrfmiddlewaretoken]');
        return csrfToken ? csrfToken.value : '';
    }

    /**
     * Initialize the background sync manager
     */
    init() {
        // Process queue when coming online
        window.addEventListener('online', () => {
            console.log('Online detected, processing sync queue');
            this.processSyncQueue();
        });

        // Process queue periodically
        setInterval(() => {
            if (navigator.onLine) {
                this.processSyncQueue();
            }
        }, 30000); // Every 30 seconds

        // Process queue on page load
        document.addEventListener('DOMContentLoaded', () => {
            if (navigator.onLine) {
                this.processSyncQueue();
            }
        });
    }
}

// Initialize the background sync manager
const backgroundSyncManager = new BackgroundSyncManager();
backgroundSyncManager.init();

// Export for use in other modules
window.BackgroundSyncManager = BackgroundSyncManager;
window.backgroundSyncManager = backgroundSyncManager;