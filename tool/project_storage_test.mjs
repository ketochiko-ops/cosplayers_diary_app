import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const source = fs.readFileSync('web/project_storage.js', 'utf8');
function environment(baseURI = 'https://app.example/') {
  const state = { content: '{}', permission: 'granted', missing: false, cancel: false, requests: 0, writes: 0, stored: null, abortTransaction: false };
  const handle = {
    name: 'project.json',
    queryPermission: async () => state.permission,
    requestPermission: async () => { state.requests++; return state.permission; },
    getFile: async () => {
      if (state.missing) throw new Error('missing file');
      return { text: async () => state.content };
    },
    createWritable: async () => {
      if (state.missing) throw new Error('missing file');
      let pending;
      return { write: async (content) => { pending = content; }, close: async () => { state.content = pending; state.writes++; } };
    },
  };
  const databases = [];
  const indexedDB = {
    open: (name) => {
      databases.push(name);
      const request = {};
      request.result = {
        close() {},
        transaction() {
          const transaction = { objectStore() {
            function operation(result, mutate = () => {}) {
              const request = {};
              queueMicrotask(() => {
                request.result = result;
                request.onsuccess?.();
                if (state.abortTransaction) {
                  transaction.error = new Error('transaction aborted');
                  transaction.onabort?.();
                } else {
                  mutate();
                  transaction.oncomplete?.();
                }
              });
              return request;
            }
            return { get: () => operation(state.stored), put: (value) => operation(undefined, () => { state.stored = value; }), delete: () => operation(undefined, () => { state.stored = null; }) };
          } };
          return transaction;
        },
      };
      queueMicrotask(() => request.onsuccess());
      return request;
    },
  };
  function picker() {
    if (state.cancel) throw Object.assign(new Error('cancel'), { name: 'AbortError' });
    return handle;
  }
  const window = { showSaveFilePicker: async () => picker(), showOpenFilePicker: async () => [picker()] };
  vm.runInNewContext(source, { window, indexedDB, document: { baseURI }, URL });
  return { state, databases, storage: window.cosplayProjectStorage };
}

test('creates uncompressed JSON and saves repeated changes to the chosen file', async () => {
  const { state, storage } = environment();
  const created = JSON.parse(await storage.createLocalFile('{"diary":[]}'));
  assert.equal(created.content, state.content);
  assert.equal(state.stored.name, 'project.json');
  await storage.writeLocalFile('{"diary":[1]}', created.revision);
  await storage.writeLocalFile('{"diary":[1,2]}', '{"diary":[1]}');
  assert.equal(state.content, '{"diary":[1,2]}');
  assert.equal(state.writes, 3);
});

test('startup does not request permission without a user action', async () => {
  const { state, storage } = environment();
  await storage.createLocalFile('{}');
  state.permission = 'prompt';
  await assert.rejects(storage.reconnectLocalFile(), /再指定/);
  assert.equal(state.requests, 0);
  state.permission = 'granted';
  assert.equal(JSON.parse(await storage.reconnectLocalFile(true)).content, '{}');
});

test('external changes and deleted files cannot be silently overwritten', async () => {
  const { state, storage } = environment();
  await storage.createLocalFile('{}');
  state.content = 'external';
  await assert.rejects(storage.writeLocalFile('new', '{}'), /変更/);
  assert.equal(state.writes, 1);
  state.missing = true;
  await assert.rejects(storage.readLocalFile(), /missing/);
  await assert.rejects(storage.writeLocalFile('new', 'external'), /missing/);
});

test('picker cancellation is distinct from a file error', async () => {
  const { state, storage } = environment();
  state.cancel = true;
  assert.equal(await storage.createLocalFile('{}'), null);
  assert.equal(await storage.openLocalFile(), null);
  state.cancel = false;
  state.missing = true;
  await assert.rejects(storage.openLocalFile(), /missing/);
});

test('failed IndexedDB commit is not reported as a connected project', async () => {
  const { state, storage } = environment();
  state.abortTransaction = true;
  await assert.rejects(storage.createLocalFile('{}'), /transaction aborted/);
});


test('permission loss is detected even before the next edit', async () => {
  const { state, storage } = environment();
  await storage.createLocalFile('{}');
  state.permission = 'denied';
  await assert.rejects(storage.readLocalFile(), /権限/);
  assert.equal(state.requests, 0);
});

test('file handles are isolated by Pages project while production keeps its database', async () => {
  const production = environment();
  const preview = environment('https://user.github.io/cosplayers_diary_app/');
  const sibling = environment('https://user.github.io/another-project/');
  for (const env of [production, preview, sibling]) await env.storage.createLocalFile('{}');
  assert.equal(production.databases[0], 'cosplay-diary-project');
  assert.equal(preview.databases[0], 'cosplay-diary-project:/cosplayers_diary_app/');
  assert.notEqual(preview.databases[0], sibling.databases[0]);
});
