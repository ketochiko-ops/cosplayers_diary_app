import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const source = fs.readFileSync('web/project_storage.js', 'utf8');
const scope = 'https://www.googleapis.com/auth/drive.file';

function createStorage(fetch) {
  const oauth2 = {
    initTokenClient: (config) => ({
      requestAccessToken: () => config.callback({
        access_token: 'test-token',
        scope,
      }),
    }),
    hasGrantedAllScopes: () => true,
    revoke: () => {},
  };
  const window = { google: { accounts: { oauth2 } } };
  vm.runInNewContext(source, {
    window,
    google: window.google,
    fetch,
    Headers,
    Blob,
    URLSearchParams,
    indexedDB: {},
  });
  return window.cosplayProjectStorage;
}

function response(body, status = 200) {
  return {
    ok: status >= 200 && status < 300,
    status,
    json: async () => body,
    text: async () => typeof body === 'string' ? body : JSON.stringify(body),
  };
}

test('Google Drive connection reads the app project', async () => {
  const calls = [];
  const storage = createStorage(async (url, options) => {
    calls.push({ url, options });
    if (url.includes('?alt=media')) return response('{"diary":[]}');
    if (url.includes('q=')) {
      const query = new URL(url).searchParams.get('q');
      return response({ files: query.includes('mimeType')
        ? [{ id: 'folder-1', name: 'CosplayDiary' }]
        : [{ id: 'file-1', name: 'CosplayDiary.project.json', version: '7' }],
      });
    }
    throw new Error(`Unexpected request: ${url}`);
  });

  const project = JSON.parse(await storage.connectGoogleDrive('client-id'));

  assert.equal(project.content, '{"diary":[]}');
  assert.equal(project.revision, '7');
  assert.ok(calls.every((call) => call.options.headers.get('Authorization') === 'Bearer test-token'));
});

test('Google Drive refuses to overwrite a newer version', async () => {
  let patched = false;
  const storage = createStorage(async (url, options) => {
    if (url.includes('q=')) {
      const query = new URL(url).searchParams.get('q');
      return response({ files: query.includes('mimeType')
        ? [{ id: 'folder-1' }]
        : [{ id: 'file-1', name: 'project.json', version: '7' }],
      });
    }
    if (url.includes('?alt=media')) return response('{}');
    if (url.includes('fields=id,name,version')) return response({ id: 'file-1', version: '8' });
    if (options.method === 'PATCH') patched = true;
    return response({});
  });

  await storage.connectGoogleDrive('client-id');
  await assert.rejects(storage.writeGoogleDrive('{"new":true}', '7'), /別の端末/);
  assert.equal(patched, false);
});
