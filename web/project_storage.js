'use strict';

window.cosplayProjectStorage = (() => {
  const fileName = 'CosplayDiary.project.json';
  const basePath = new URL('.', document.baseURI).pathname;
  const databaseName = basePath === '/' ? 'cosplay-diary-project' : `cosplay-diary-project:${basePath}`;
  let folder = null;
  function imagePath(path) {
    if (typeof path !== 'string' || !/^images\/[a-zA-Z0-9_-]+\.(jpg|jpeg|png|webp|heic)$/.test(path)) {
      throw new Error('画像の保存パスが不正です。');
    }
    return path;
  }
  function photos(content) {
    const state = JSON.parse(content);
    const rows = state.photos ?? [];
    if (!Array.isArray(rows)) throw new Error('画像一覧の形式が不正です。');
    const paths = rows.map(row => imagePath(row.relativePath));
    if (new Set(paths).size !== paths.length) throw new Error('画像パスが重複しています。');
    return paths;
  }
  function openDatabase() {
    return new Promise((resolve, reject) => {
      const request = indexedDB.open(databaseName, 2);
      request.onupgradeneeded = () => {
        for (const name of ['handles', 'assets']) {
          if (!request.result.objectStoreNames.contains(name)) request.result.createObjectStore(name);
        }
      };
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
  }
  async function transaction(storeName, mode, action) {
    const db = await openDatabase();
    return new Promise((resolve, reject) => {
      const tx = db.transaction(storeName, mode);
      let result;
      try {
        const request = action(tx.objectStore(storeName));
        if (request) request.onsuccess = () => { result = request.result; };
      } catch (error) { try { tx.abort(); } catch (_) {} db.close(); reject(error); return; }
      tx.oncomplete = () => { db.close(); resolve(result); };
      tx.onerror = tx.onabort = () => { db.close(); reject(tx.error || new Error('保存できませんでした。')); };
    });
  }
  const cached = path => transaction('assets', 'readonly', store => store.get(imagePath(path)));
  const remember = handle => transaction('handles', 'readwrite', store => handle ? store.put(handle, 'projectFolder') : store.delete('projectFolder'));
  async function permission(handle, request = false) {
    if (!handle || handle.kind !== 'directory') throw new Error('プロジェクトフォルダを指定してください。');
    let value = await handle.queryPermission({ mode: 'readwrite' });
    if (value !== 'granted' && request) value = await handle.requestPermission({ mode: 'readwrite' });
    if (value !== 'granted') throw new Error('フォルダへのアクセスを許可するため再指定してください。');
  }
  async function imageFile(handle, path, create = false) {
    const directory = await handle.getDirectoryHandle('images', { create });
    return directory.getFileHandle(imagePath(path).slice(7), { create });
  }
  async function inspect(handle) {
    await permission(handle);
    // Lookup through the directory each time so removed/replaced files are found.
    const content = await (await (await handle.getFileHandle(fileName)).getFile()).text();
    const entries = [];
    for (const path of photos(content)) {
      const file = await (await imageFile(handle, path)).getFile();
      entries.push([path, file.size, file.lastModified]);
    }
    return { content, revision: JSON.stringify([content, entries]), name: handle.name };
  }
  async function cachedFiles(content) {
    const files = [];
    for (const path of photos(content)) {
      const blob = await cached(path);
      if (!(blob instanceof Blob)) throw new Error(`画像が端末にありません: ${path}。元のプロジェクトフォルダを開き直してください。`);
      files.push([path, blob]);
    }
    return files;
  }
  async function sameBlob(a, b) {
    if (a.size !== b.size) return false;
    const x = new Uint8Array(await a.arrayBuffer());
    const y = new Uint8Array(await b.arrayBuffer());
    return x.every((value, index) => value === y[index]);
  }
  async function writeImages(handle, files, previousPaths) {
    const directory = await handle.getDirectoryHandle('images', { create: true });
    for (const [path, blob] of files) {
      if (previousPaths.has(path)) continue; // Image IDs are immutable.
      let existing;
      try { existing = await directory.getFileHandle(path.slice(7)); }
      catch (error) { if (error.name !== 'NotFoundError') throw error; }
      if (existing) {
        if (!await sameBlob(await existing.getFile(), blob)) throw new Error(`同じ画像名で内容が異なります: ${path}`);
        continue;
      }
      const file = await directory.getFileHandle(path.slice(7), { create: true });
      const writable = await file.createWritable();
      await writable.write(blob);
      await writable.close();
    }
  }
  async function writeJson(handle, content) {
    const file = await handle.getFileHandle(fileName, { create: true });
    const writable = await file.createWritable();
    await writable.write(content);
    await writable.close();
  }
  async function choose(create, content) {
    try {
      const selected = await window.showDirectoryPicker({ id: 'cosplay-project', mode: 'readwrite' });
      await permission(selected, true);
      if (create) {
        for await (const _ of selected.entries()) throw new Error('新規作成では空のフォルダを指定してください。既存のプロジェクトは「開く」を使ってください。');
        const files = await cachedFiles(content);
        await writeImages(selected, files, new Set());
        await writeJson(selected, content); // JSON commits after every image exists.
      }
      const result = await inspect(selected);
      await remember(selected);
      folder = selected;
      return JSON.stringify(result);
    } catch (error) {
      if (error.name === 'AbortError') return null;
      throw error;
    }
  }
  async function writeLocalFolder(content, expectedRevision) {
    const before = await inspect(folder);
    if (before.revision !== expectedRevision) throw new Error('フォルダの内容が別の場所で変更されました。再指定して使用する内容を選んでください。');
    const files = await cachedFiles(content); // Preflight all assets before mutation.
    await writeImages(folder, files, new Set(photos(before.content)));
    if ((await inspect(folder)).revision !== expectedRevision) throw new Error('保存中にプロジェクトが外部で変更されました。再指定してください。');
    await writeJson(folder, content);
    return JSON.stringify(await inspect(folder));
  }
  async function loadAssets() {
    const before = await inspect(folder);
    const files = [];
    for (const path of photos(before.content)) {
      const file = await (await imageFile(folder, path)).getFile();
      const old = await cached(path);
      if (old && !await sameBlob(old, file)) throw new Error(`画像IDが同じで内容が異なります: ${path}。画像の元データを確認してください。`);
      // File snapshots can become unreadable after their source is removed.
      // Materialize bytes so recovery never depends on the original folder.
      files.push([path, new Blob([await file.arrayBuffer()])]);
    }
    if ((await inspect(folder)).revision !== before.revision) throw new Error('読み込み中にプロジェクトが変更されました。再指定してください。');
    await transaction('assets', 'readwrite', store => {
      for (const [path, file] of files) store.put(file, path);
    });
  }
  return {
    get supportsLocalFolder() { return 'showDirectoryPicker' in window; },
    openLocalFolder: () => choose(false),
    createLocalFolder: content => choose(true, content),
    reconnectLocalFolder: async (request = false) => {
      const handle = await transaction('handles', 'readonly', store => store.get('projectFolder'));
      if (!handle) return null;
      await permission(handle, request);
      const result = await inspect(handle);
      folder = handle;
      return JSON.stringify(result);
    },
    readLocalFolder: async () => JSON.stringify(await inspect(folder)),
    writeLocalFolder,
    loadAssets,
    disconnectLocalFolder: async () => { folder = null; await remember(null); },
    saveAsset: async (path, bytes) => {
      imagePath(path);
      const blob = new Blob([bytes]);
      const old = await cached(path);
      if (old && !await sameBlob(old, blob)) throw new Error('同じ画像IDの内容は上書きできません。');
      await transaction('assets', 'readwrite', store => store.put(blob, path));
    },
    readAsset: async path => {
      const blob = await cached(path);
      if (!blob) throw new Error('画像を読み込めません。プロジェクトフォルダを再指定してください。');
      return new Uint8Array(await blob.arrayBuffer());
    },
    existsAsset: async path => !!(await cached(path)),
    deleteAsset: path => transaction('assets', 'readwrite', store => store.delete(imagePath(path))),
    listAssets: async () => JSON.stringify(await transaction('assets', 'readonly', store => store.getAllKeys())),
  };
})();
