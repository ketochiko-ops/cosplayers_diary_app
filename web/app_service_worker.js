'use strict';

const CACHE_NAME = 'cosplayers-diary-pwa-v2';
const APP_SHELL = [
  './',
  'index.html',
  'flutter_bootstrap.js',
  'project_storage.js',
  'flutter.js',
  'main.dart.js',
  'manifest.json',
  'favicon.png',
  'icons/Icon-180.png',
  'icons/Icon-192.png',
  'icons/Icon-512.png',
  'icons/Icon-maskable-192.png',
  'icons/Icon-maskable-512.png',
  'assets/AssetManifest.bin',
  'assets/AssetManifest.bin.json',
  'assets/FontManifest.json',
  'assets/fonts/MaterialIcons-Regular.otf',
  'assets/packages/cupertino_icons/assets/CupertinoIcons.ttf',
  'assets/shaders/ink_sparkle.frag',
  'assets/shaders/stretch_effect.frag',
  'canvaskit/canvaskit.js',
  'canvaskit/canvaskit.wasm',
  'canvaskit/chromium/canvaskit.js',
  'canvaskit/chromium/canvaskit.wasm',
  'canvaskit/skwasm.js',
  'canvaskit/skwasm.wasm',
  'canvaskit/skwasm_heavy.js',
  'canvaskit/skwasm_heavy.wasm',
  'canvaskit/wimp.js',
  'canvaskit/wimp.wasm',
];

self.addEventListener('install', function (event) {
  const urls = APP_SHELL.map(function (path) {
    return new URL(path, self.registration.scope).toString();
  });
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(function (cache) {
        return cache.addAll(urls);
      })
      .then(function () {
        return self.skipWaiting();
      }),
  );
});

self.addEventListener('activate', function (event) {
  event.waitUntil(
    caches.keys()
      .then(function (names) {
        return Promise.all(
          names
            .filter(function (name) {
              return name.startsWith('cosplayers-diary-pwa-') &&
                  name !== CACHE_NAME;
            })
            .map(function (name) {
              return caches.delete(name);
            }),
        );
      })
      .then(function () {
        return self.clients.claim();
      }),
  );
});

self.addEventListener('fetch', function (event) {
  const request = event.request;
  if (request.method !== 'GET') return;

  const requestUrl = new URL(request.url);
  if (requestUrl.origin !== self.location.origin) return;

  event.respondWith(
    fetch(request)
      .then(function (response) {
        if (!response.ok) return response;
        const copy = response.clone();
        return caches.open(CACHE_NAME)
          .then(function (cache) {
            return cache.put(request, copy).catch(function () {
              // Range responses and browser-managed requests may not be cacheable.
            });
          })
          .then(function () {
            return response;
          });
      })
      .catch(function () {
        return caches.match(request).then(function (cached) {
          if (cached) return cached;
          if (request.mode === 'navigate') {
            return caches.match(
              new URL('index.html', self.registration.scope).toString(),
            );
          }
          throw new Error('オフラインで利用できないリソースです。');
        });
      }),
  );
});
