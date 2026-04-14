importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBE2vVdvoezTp5HGagF8NQn8lBmwKokd-c',
  authDomain: 'football-fantasy-app-498ac.firebaseapp.com',
  projectId: 'football-fantasy-app-498ac',
  storageBucket: 'football-fantasy-app-498ac.firebasestorage.app',
  messagingSenderId: '811534522991',
  appId: '1:811534522991:web:036ba04a73249f8fe68b9a',
  measurementId: 'G-MWM47G84JM',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const title = payload.notification?.title || 'Football Fantasy Manager';
  const options = {
    body: payload.notification?.body || 'You have a new update.',
    icon: '/icons/Icon-192.png',
  };

  self.registration.showNotification(title, options);
});
