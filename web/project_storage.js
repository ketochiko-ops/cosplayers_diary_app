'use strict';

// Persist only the user-selected file handle; project contents are plain JSON.
window.cosplayProjectStorage = (() => {
  const fileName = 'CosplayDiary.project.json';
  const basePath = new URL('.', document.baseURI).pathname;
  const databaseName = basePath === '/' ? 'cosplay-diary-project' : `cosplay-diary-project:${basePath}`;
  let localHandle = null;

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
      const request = indexedDB.open(databaseName, 1);
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
      let result;
      request.onsuccess = () => { result = request.result; };
      transaction.oncomplete = () => { database.close(); resolve(result); };
      transaction.onerror = transaction.onabort = () => { database.close(); reject(transaction.error || request.error); };
    });
  }

  async function readLocal(handle) {
    const file = await handle.getFile();
    const content = await file.text();
    return snapshot(content, content, handle.name);
  }

  async function openLocalFile() {
    try {
      const [handle] = await window.showOpenFilePicker({ types: projectType(), multiple: false });
      if (await handle.queryPermission({ mode: 'readwrite' }) !== 'granted' &&
          await handle.requestPermission({ mode: 'readwrite' }) !== 'granted') {
        throw new Error('ファイルへの書き込みが許可されていません');
      }
      const result = await readLocal(handle);
      await storedHandle(handle);
      localHandle = handle;
      return result;
    } catch (error) {
      if (error.name === 'AbortError') return null;
      throw error;
    }
  }

  async function createLocalFile(content) {
    try {
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
    } catch (error) {
      if (error.name === 'AbortError') return null;
      throw error;
    }
  }

  async function reconnectLocalFile(requestPermission = false) {
    const handle = await storedHandle();
    if (!handle) return null;
    const permission = await handle.queryPermission({ mode: 'readwrite' });
    if (permission !== 'granted' && (!requestPermission ||
        await handle.requestPermission({ mode: 'readwrite' }) !== 'granted')) {
      throw new Error('ファイルへのアクセスを許可するため再指定してください');
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

  return {
    get supportsLocalFile() {
      return 'showOpenFilePicker' in window && 'showSaveFilePicker' in window;
    },
    openLocalFile,
    createLocalFile,
    reconnectLocalFile,
    readLocalFile: async () => {
      if (!localHandle) throw new Error('プロジェクトファイルを再指定してください');
      if (await localHandle.queryPermission({ mode: 'readwrite' }) !== 'granted') {
        throw new Error('ファイルへのアクセス権限がありません。再指定してください');
      }
      return readLocal(localHandle);
    },
    writeLocalFile,
    disconnectLocalFile,
  };
})();
