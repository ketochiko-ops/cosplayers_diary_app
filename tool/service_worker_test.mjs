import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const source = fs.readFileSync('web/app_service_worker.js', 'utf8');
function environment(scope) {
  const prefix = `cosplayers-diary-pwa:${scope}:`;
  const listeners = {};
  const stored = new Map();
  const prefetched = [];
  const caches = {
    keys: async () => [...stored.keys()],
    delete: async (key) => stored.delete(key),
    open: async (key) => {
      if (!stored.has(key)) stored.set(key, new Map());
      const cache = stored.get(key);
      return {
        addAll: async (urls) => { prefetched.push(...urls); },
        match: async (request) => cache.get(request.url ?? request),
        put: async (request, response) => cache.set(request.url ?? request, response),
      };
    },
  };
  const self = {
    registration: { scope }, location: { origin: new URL(scope).origin },
    addEventListener: (name, listener) => { listeners[name] = listener; },
    skipWaiting: async () => {}, clients: { claim: async () => {} },
  };
  vm.runInNewContext(source, {
    self, caches, URL,
    fetch: async () => { throw new Error('offline'); },
  });
  async function lifecycle(name) {
    let pending;
    listeners[name]({ waitUntil: (promise) => { pending = promise; } });
    await pending;
  }
  return { prefix, stored, prefetched, listeners, lifecycle };
}

test('Pages precache resolves every resource inside the repository path', async () => {
  const scope = 'https://user.github.io/cosplayers_diary_app/';
  const env = environment(scope);
  await env.lifecycle('install');
  assert.ok(env.prefetched.length >= 31);
  assert.ok(env.prefetched.every(url => url.startsWith(scope)));
  assert.ok(env.prefetched.includes(`${scope}calendar_sync.js`));
});

test('activation keeps sibling projects and replaces only this scope cache', async () => {
  const env = environment('https://user.github.io/cosplayers_diary_app/');
  const sibling = 'cosplayers-diary-pwa:https://user.github.io/another/:v4';
  env.stored.set(`${env.prefix}v4`, new Map());
  env.stored.set(sibling, new Map());
  env.stored.set('cosplayers-diary-pwa-v4', new Map());
  await env.lifecycle('install');
  await env.lifecycle('activate');
  assert.equal(env.stored.has(`${env.prefix}v4`), false);
  assert.equal(env.stored.has(`${env.prefix}v6`), true);
  assert.equal(env.stored.has(sibling), true);
  assert.equal(env.stored.has('cosplayers-diary-pwa-v4'), true);
});

test('root production migrates its legacy cache without deleting Pages caches', async () => {
  const env = environment('https://app.example/');
  const sibling = 'cosplayers-diary-pwa:https://app.example/another/:v4';
  env.stored.set('cosplayers-diary-pwa-v4', new Map());
  env.stored.set(sibling, new Map());
  await env.lifecycle('install');
  await env.lifecycle('activate');
  assert.equal(env.stored.has('cosplayers-diary-pwa-v4'), false);
  assert.equal(env.stored.has(sibling), true);
});

test('offline navigation uses this scope index instead of a sibling cache', async () => {
  const scope = 'https://user.github.io/cosplayers_diary_app/';
  const env = environment(scope);
  await env.lifecycle('install');
  env.stored.get(`${env.prefix}v6`).set(`${scope}index.html`, 'own app');
  env.stored.set('sibling', new Map([[`${scope}route`, 'wrong app']]));
  let pending;
  env.listeners.fetch({
    request: { method: 'GET', url: `${scope}route`, mode: 'navigate' },
    respondWith: (promise) => { pending = promise; },
  });
  assert.equal(await pending, 'own app');
});

test('external OAuth and write requests bypass the offline cache', () => {
  const env = environment('https://user.github.io/cosplayers_diary_app/');
  const unexpected = () => assert.fail('request must bypass the cache');
  env.listeners.fetch({
    request: { method: 'GET', url: 'https://accounts.google.com/gsi/client' },
    respondWith: unexpected,
  });
  env.listeners.fetch({
    request: { method: 'POST', url: 'https://user.github.io/cosplayers_diary_app/' },
    respondWith: unexpected,
  });
});
