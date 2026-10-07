'use strict';

// Only the user-selected file handle is kept in IndexedDB. OAuth tokens stay in memory.
window.cosplayProjectStorage = (() => {
  const folderName = 'CosplayDiary';
  const fileName = 'CosplayDiary.project.json';
  const driveScope = 'https://www.googleapis.com/auth/drive.file';
  let localHandle = null;
  let driveToken = null;
  let driveFileId = null;

  function snapshot(content, revision, name) {
    return JSON.stringify({ content, revision, name });
  }

  function projectType() {
    return [{
      description: 'コスプレ日記プロジェクト',
      accept: { 'application/json': ['.json'] },
    }];
  }

  function openDatabase() {
    return new Promise((resolve, reject) => {
      const request = indexedDB.open('cosplay-diary-project', 1);
      request.onupgradeneeded = () => request.result.createObjectStore('handles');
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
  }

  async function storedHandle(value) {
    const database = await openDatabase();
    return new Promise((resolve, reject) => {
      const transaction = database.transaction('handles', value === undefined ? 'readonly' : 'readwrite');
      const store = transaction.objectStore('handles');
      const request = value === undefined
        ? store.get('project')
        : value === null ? store.delete('project') : store.put(value, 'project');
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
      transaction.oncomplete = () => database.close();
    });
  }

  async function readLocal(handle) {
    const file = await handle.getFile();
    const content = await file.text();
    return snapshot(content, content, handle.name);
  }

  async function openLocalFile() {
    const [handle] = await window.showOpenFilePicker({ types: projectType(), multiple: false });
    localHandle = handle;
    await storedHandle(handle);
    return readLocal(handle);
  }

  async function createLocalFile(content) {
    const handle = await window.showSaveFilePicker({
      suggestedName: fileName,
      types: projectType(),
    });
    const writable = await handle.createWritable();
    await writable.write(content);
    await writable.close();
    localHandle = handle;
    await storedHandle(handle);
    return snapshot(content, content, handle.name);
  }

  async function reconnectLocalFile() {
    const handle = await storedHandle();
    if (!handle) return null;
    const permission = await handle.queryPermission({ mode: 'readwrite' });
    if (permission !== 'granted' &&
        await handle.requestPermission({ mode: 'readwrite' }) !== 'granted') {
      throw new Error('ファイルへのアクセスが許可されていません');
    }
    localHandle = handle;
    return readLocal(handle);
  }

  async function writeLocalFile(content, expectedRevision) {
    if (!localHandle) throw new Error('プロジェクトファイルを再接続してください');
    const current = await (await localHandle.getFile()).text();
    if (current !== expectedRevision) {
      throw new Error('ファイルが別の場所で変更されました。再接続して内容を選んでください');
    }
    const writable = await localHandle.createWritable();
    await writable.write(content);
    await writable.close();
    return snapshot(content, content, localHandle.name);
  }

  async function disconnectLocalFile() {
    localHandle = null;
    await storedHandle(null);
  }

  function authorize(clientId) {
    if (!window.google?.accounts?.oauth2) {
      throw new Error('Google認証ライブラリを読み込めません。オンラインで再試行してください');
    }
    return new Promise((resolve, reject) => {
      const client = google.accounts.oauth2.initTokenClient({
        client_id: clientId,
        scope: driveScope,
        callback: (response) => {
          if (response.error || !response.access_token ||
              !google.accounts.oauth2.hasGrantedAllScopes(response, driveScope)) {
            reject(new Error(response.error_description || 'Driveへのアクセスが許可されませんでした'));
            return;
          }
          driveToken = response.access_token;
          resolve();
        },
        error_callback: (error) => reject(new Error(error.message || error.type || 'Google認証に失敗しました')),
      });
      client.requestAccessToken({ prompt: 'select_account' });
    });
  }

  async function driveRequest(url, options = {}) {
    if (!driveToken) throw new Error('Google Driveを再接続してください');
    const headers = new Headers(options.headers || {});
    headers.set('Authorization', `Bearer ${driveToken}`);
    const response = await fetch(url, { ...options, headers });
    if (response.status === 401) {
      driveToken = null;
      throw new Error('Google認証の期限が切れました。再接続してください');
    }
    if (!response.ok) {
      throw new Error(`Google Driveでエラーが発生しました (${response.status})`);
    }
    return response;
  }

  async function listFiles(query) {
    const parameters = new URLSearchParams({
      q: query,
      fields: 'nextPageToken,files(id,name,version)',
      spaces: 'drive',
      pageSize: '100',
    });
    const response = await driveRequest(`https://www.googleapis.com/drive/v3/files?${parameters}`);
    const data = await response.json();
    return data.files || [];
  }

  async function folderId(create) {
    const folders = await listFiles(
      "name = 'CosplayDiary' and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
    );
    if (folders.length) return folders[0].id;
    if (!create) return null;
    const response = await driveRequest('https://www.googleapis.com/drive/v3/files?fields=id', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name: folderName, mimeType: 'application/vnd.google-apps.folder' }),
    });
    return (await response.json()).id;
  }

  async function projectMetadata(createFolder) {
    const parent = await folderId(createFolder);
    if (!parent) return { parent, file: null };
    const files = await listFiles(
      `'${parent}' in parents and name = '${fileName}' and trashed = false`,
    );
    return { parent, file: files[0] || null };
  }

  async function readDrive(file) {
    const response = await driveRequest(
      `https://www.googleapis.com/drive/v3/files/${encodeURIComponent(file.id)}?alt=media`,
    );
    return snapshot(await response.text(), file.version, file.name);
  }

  async function connectGoogleDrive(clientId) {
    await authorize(clientId);
    const { file } = await projectMetadata(false);
    driveFileId = file?.id || null;
    return file ? readDrive(file) : snapshot(null, null, fileName);
  }

  async function createGoogleDrive(content) {
    const { parent, file } = await projectMetadata(true);
    if (file) throw new Error('Drive上に既にプロジェクトがあります。再接続してください');
    const boundary = `cosplayDiary${Date.now()}`;
    const body = new Blob([
      `--${boundary}\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n`,
      JSON.stringify({ name: fileName, parents: [parent], mimeType: 'application/json' }),
      `\r\n--${boundary}\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n`,
      content,
      `\r\n--${boundary}--`,
    ]);
    const response = await driveRequest(
      'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&fields=id,name,version',
      { method: 'POST', headers: { 'Content-Type': `multipart/related; boundary=${boundary}` }, body },
    );
    const created = await response.json();
    driveFileId = created.id;
    return snapshot(content, created.version, created.name);
  }

  async function writeGoogleDrive(content, expectedRevision) {
    if (!driveFileId) throw new Error('Google Driveを再接続してください');
    const metadataResponse = await driveRequest(
      `https://www.googleapis.com/drive/v3/files/${encodeURIComponent(driveFileId)}?fields=id,name,version`,
    );
    const metadata = await metadataResponse.json();
    if (metadata.version !== expectedRevision) {
      throw new Error('Drive上のプロジェクトが別の端末で更新されました。再接続して内容を選んでください');
    }
    const response = await driveRequest(
      `https://www.googleapis.com/upload/drive/v3/files/${encodeURIComponent(driveFileId)}?uploadType=media&fields=id,name,version`,
      {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: content,
      },
    );
    const updated = await response.json();
    return snapshot(content, updated.version, updated.name);
  }

  async function disconnectGoogleDrive() {
    if (driveToken && window.google?.accounts?.oauth2) {
      google.accounts.oauth2.revoke(driveToken);
    }
    driveToken = null;
    driveFileId = null;
  }

  return {
    get supportsLocalFile() {
      return 'showOpenFilePicker' in window && 'showSaveFilePicker' in window;
    },
    openLocalFile,
    createLocalFile,
    reconnectLocalFile,
    writeLocalFile,
    disconnectLocalFile,
    connectGoogleDrive,
    createGoogleDrive,
    writeGoogleDrive,
    disconnectGoogleDrive,
  };
})();
