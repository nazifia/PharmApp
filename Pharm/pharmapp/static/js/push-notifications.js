/**
 * Push Notifications Handler for PharmApp
 */

class PushNotificationManager {
    constructor() {
        this.isSupported = 'serviceWorker' in navigator && 'PushManager' in window;
    }

    /**
     * Initialize push notifications
     */
    async init() {
        if (!this.isSupported) {
            console.log('Push notifications not supported');
            return;
        }

        try {
            // Register service worker
            const registration = await navigator.serviceWorker.ready;
            
            // Check existing subscription
            const subscription = await registration.pushManager.getSubscription();
            if (subscription) {
                console.log('User is already subscribed to push notifications');
                await this.sendSubscriptionToServer(subscription);
                return subscription;
            }
            
            console.log('User is not subscribed to push notifications');
        } catch (error) {
            console.error('Error during push notification initialization:', error);
        }
    }

    /**
     * Subscribe user to push notifications
     */
    async subscribeUser() {
        if (!this.isSupported) {
            throw new Error('Push notifications not supported');
        }

        try {
            const registration = await navigator.serviceWorker.ready;
            
            const subscription = await registration.pushManager.subscribe({
                userVisibleOnly: true,
                applicationServerKey: this.urlBase64ToUint8Array(this.getVapidPublicKey())
            });
            
            // Send subscription to server
            await this.sendSubscriptionToServer(subscription);
            
            console.log('User is subscribed to push notifications');
            return subscription;
        } catch (error) {
            console.error('Failed to subscribe user:', error);
            throw error;
        }
    }

    /**
     * Unsubscribe user from push notifications
     */
    async unsubscribeUser() {
        if (!this.isSupported) {
            return;
        }

        try {
            const registration = await navigator.serviceWorker.ready;
            const subscription = await registration.pushManager.getSubscription();
            
            if (subscription) {
                await subscription.unsubscribe();
                await this.removeSubscriptionFromServer(subscription);
                console.log('User is unsubscribed from push notifications');
            }
        } catch (error) {
            console.error('Failed to unsubscribe user:', error);
        }
    }

    /**
     * Send subscription to server
     */
    async sendSubscriptionToServer(subscription) {
        try {
            const response = await fetch('/api/save-subscription/', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'X-CSRFToken': this.getCSRFToken()
                },
                body: JSON.stringify({
                    subscription: subscription
                })
            });
            
            if (!response.ok) {
                throw new Error('Failed to save subscription');
            }
            
            console.log('Subscription sent to server');
        } catch (error) {
            console.error('Error sending subscription to server:', error);
        }
    }

    /**
     * Remove subscription from server
     */
    async removeSubscriptionFromServer(subscription) {
        try {
            const response = await fetch('/api/remove-subscription/', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'X-CSRFToken': this.getCSRFToken()
                },
                body: JSON.stringify({
                    subscription: subscription
                })
            });
            
            if (!response.ok) {
                throw new Error('Failed to remove subscription');
            }
            
            console.log('Subscription removed from server');
        } catch (error) {
            console.error('Error removing subscription from server:', error);
        }
    }

    /**
     * Convert VAPID public key from base64 to Uint8Array
     */
    urlBase64ToUint8Array(base64String) {
        const padding = '='.repeat((4 - base64String.length % 4) % 4);
        const base64 = (base64String + padding)
            .replace(/\-/g, '+')
            .replace(/_/g, '/');
        
        const rawData = window.atob(base64);
        const outputArray = new Uint8Array(rawData.length);
        
        for (let i = 0; i < rawData.length; ++i) {
            outputArray[i] = rawData.charCodeAt(i);
        }
        return outputArray;
    }

    /**
     * Get VAPID public key (replace with your actual key)
     */
    getVapidPublicKey() {
        // This should be replaced with your actual VAPID public key
        // You can generate one using libraries like web-push
        return 'YOUR_VAPID_PUBLIC_KEY_HERE';
    }

    /**
     * Get CSRF token for Django
     */
    getCSRFToken() {
        const csrfToken = document.querySelector('[name=csrfmiddlewaretoken]');
        return csrfToken ? csrfToken.value : '';
    }

    /**
     * Request notification permission
     */
    async requestPermission() {
        if (!('Notification' in window)) {
            console.log('This browser does not support notifications.');
            return;
        }
        
        if (Notification.permission === 'granted') {
            console.log('Permission already granted');
            return;
        }
        
        const permission = await Notification.requestPermission();
        if (permission === 'granted') {
            console.log('Notification permission granted');
            await this.subscribeUser();
        } else {
            console.log('Notification permission denied');
        }
    }
}

// Initialize push notification manager
const pushNotificationManager = new PushNotificationManager();

// Initialize when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    pushNotificationManager.init();
});

// Export for use in other modules
window.PushNotificationManager = PushNotificationManager;
window.pushNotificationManager = pushNotificationManager;