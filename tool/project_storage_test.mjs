import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const source = fs.readFileSync('web/project_storage.js', 'utf8');
const filename = 'CosplayDiary.project.json';
const stateJson = (photos = [], name = '作品') => JSON.stringify({ genres: [{id:'g',name}], photos });
function environment(baseURI = 'https://app.example/') {
  const state = { permission:'granted', requests:0, writes:0, cancel:false, abort:false, missing:false, tick:1 };
  const stores = {handles:new Map(), assets:new Map()};
  const databaseNames = [];
  const notFound = () => Object.assign(new Error('missing'), {name:'NotFoundError'});
  class FileHandle {
    kind = 'file';
    constructor(name) { this.name = name; this.bytes = new Uint8Array(); this.modified = state.tick++; }
    async getFile() {
      const file = new File([this.bytes], this.name, {lastModified:this.modified});
      const read = file.arrayBuffer.bind(file);
      file.arrayBuffer = () => this.unreadable ? Promise.reject(notFound()) : read();
      return file;
    }
    async createWritable() {
      let bytes;
      return {
        write: async value => { bytes = value instanceof Blob ? new Uint8Array(await value.arrayBuffer()) : new TextEncoder().encode(value); },
        close: async () => { this.bytes = bytes; this.modified = state.tick++; state.writes++; },
      };
    }
    edit(text) { this.bytes = new TextEncoder().encode(text); this.modified = state.tick++; }
  }
  class Directory {
    kind = 'directory';
    constructor(name) { this.name=name; this.files=new Map(); this.directories=new Map(); }
    async queryPermission() { return state.permission; }
    async requestPermission() { state.requests++; return state.permission; }
    async *entries() {
      if(state.missing) throw notFound();
      yield* this.files.entries(); yield* this.directories.entries();
    }
    async getFileHandle(name, {create=false} = {}) {
      if(state.missing) throw notFound();
      if(!this.files.has(name) && create) this.files.set(name,new FileHandle(name));
      if(!this.files.has(name)) throw notFound();
      return this.files.get(name);
    }
    async getDirectoryHandle(name, {create=false} = {}) {
      if(state.missing) throw notFound();
      if(!this.directories.has(name) && create) this.directories.set(name,new Directory(name));
      if(!this.directories.has(name)) throw notFound();
      return this.directories.get(name);
    }
  }
  const directory = new Directory('cosplayers_diary_project');
  const indexedDB = { open(name) {
    databaseNames.push(name);
    const request={};
    request.result={
      objectStoreNames:{contains:name=>name in stores}, createObjectStore:name=>{stores[name]=new Map();}, close(){},
      transaction(name) {
        let pending=0; let completed=false;
        const mutations=[];
        const tx={objectStore(){
          function operation(result, change=()=>{}) {
            pending++;
            const request={};
            queueMicrotask(()=>{ request.result=result; request.onsuccess?.(); mutations.push(change); pending--; finish(); });
            return request;
          }
          return {
            get:key=>operation(stores[name].get(key)),
            put:(value,key)=>operation(undefined,()=>stores[name].set(key,value)),
            delete:key=>operation(undefined,()=>stores[name].delete(key)),
            getAllKeys:()=>operation([...stores[name].keys()]),
          };
        }};
        function finish() {
          if(pending || completed) return;
          completed=true;
          if(state.abort) { tx.error=new Error('transaction aborted'); tx.onabort?.(); }
          else { for(const change of mutations) change(); tx.oncomplete?.(); }
        }
        queueMicrotask(finish);
        return tx;
      },
    };
    queueMicrotask(()=>request.onsuccess());
    return request;
  }};
  const window={showDirectoryPicker:async()=>{
    if(state.cancel) throw Object.assign(new Error('cancel'),{name:'AbortError'});
    return directory;
  }};
  vm.runInNewContext(source,{window,indexedDB,document:{baseURI},URL,Blob,Uint8Array});
  return {state,stores,directory,databaseNames,api:window.cosplayProjectStorage};
}
const photo={id:'photo-1',relativePath:'images/photo-1.png',originalName:'test.png'};

test('creates a project folder containing JSON masters and images directory, without ZIP',async()=>{
  const {api,directory}=environment();
  const result=JSON.parse(await api.createLocalFolder(stateJson()));
  assert.equal(result.name,'cosplayers_diary_project');
  assert.equal(JSON.parse(result.content).genres[0].name,'作品');
  assert.equal(await (await directory.files.get(filename).getFile()).text(),stateJson());
  assert.ok(directory.directories.has('images'));
  const saved=JSON.parse(await api.writeLocalFolder(stateJson([],'更新'),result.revision));
  assert.equal(saved.content,stateJson([],'更新'));
});

test('saves images before committing their JSON references and reloads them from the folder',async()=>{
  const {api,directory,stores}=environment();
  await api.saveAsset(photo.relativePath,new Uint8Array([1,2,3]));
  const first=JSON.parse(await api.createLocalFolder(stateJson([photo])));
  assert.deepEqual([...new Uint8Array(await (await directory.directories.get('images').files.get('photo-1.png').getFile()).arrayBuffer())],[1,2,3]);
  stores.assets.clear();
  await api.openLocalFolder();
  await api.loadAssets();
  assert.deepEqual([...await api.readAsset(photo.relativePath)],[1,2,3]);
  assert.equal(JSON.parse(await api.readLocalFolder()).revision,first.revision);
});

test('a missing cached image cannot create an incomplete project',async()=>{
  const {api,directory}=environment();
  await assert.rejects(api.createLocalFolder(stateJson([photo])),/画像が端末にありません/);
  assert.equal(directory.files.size,0);
});

test('loaded image cache remains readable after the source file disappears',async()=>{
  const {api,directory,stores}=environment();
  await api.saveAsset(photo.relativePath,new Uint8Array([1,2,3]));
  await api.createLocalFolder(stateJson([photo]));
  stores.assets.clear();
  await api.loadAssets();
  const images=directory.directories.get('images');
  images.files.get('photo-1.png').unreadable=true;
  images.files.delete('photo-1.png');
  await assert.rejects(api.readLocalFolder(),/missing/);
  assert.deepEqual([...await api.readAsset(photo.relativePath)],[1,2,3]);
});

test('new creation never overwrites a nonempty folder',async()=>{
  const {api,directory}=environment();
  (await directory.getFileHandle('unrelated.txt',{create:true})).edit('keep');
  await assert.rejects(api.createLocalFolder(stateJson()),/空ではありません/);
  assert.equal(await (await directory.files.get('unrelated.txt').getFile()).text(),'keep');
  assert.equal(directory.files.size,1);
});

test('picker cancellation is distinct from folder errors',async()=>{
  const {api,state}=environment();
  state.cancel=true;
  assert.equal(await api.createLocalFolder(stateJson()),null);
  assert.equal(await api.openLocalFolder(),null);
  state.cancel=false;
  await assert.rejects(api.openLocalFolder(),/missing/);
});

test('reconnect never requests permission without an explicit button action',async()=>{
  const {api,state}=environment();
  await api.createLocalFolder(stateJson());
  state.permission='prompt';
  await assert.rejects(api.reconnectLocalFolder(),/再指定/);
  assert.equal(state.requests,0);
  await assert.rejects(api.reconnectLocalFolder(true),/再指定/);
  assert.equal(state.requests,1);
  state.permission='granted';
  assert.ok(await api.reconnectLocalFolder());
});

test('external JSON changes are detected before any overwrite',async()=>{
  const {api,directory,state}=environment();
  const first=JSON.parse(await api.createLocalFolder(stateJson()));
  directory.files.get(filename).edit(stateJson([],'外部変更'));
  const writes=state.writes;
  await assert.rejects(api.writeLocalFolder(stateJson([],'端末'),first.revision),/別の場所/);
  assert.equal(state.writes,writes);
  assert.equal(JSON.parse(JSON.parse(await api.readLocalFolder()).content).genres[0].name,'外部変更');
});

test('removed JSON is not recreated silently by autosave',async()=>{
  const {api,directory}=environment();
  const first=JSON.parse(await api.createLocalFolder(stateJson()));
  directory.files.delete(filename);
  await assert.rejects(api.writeLocalFolder(stateJson(),first.revision),/missing/);
  assert.equal(directory.files.has(filename),false);
});

test('missing images and revoked folder permission are detected before another edit',async()=>{
  const {api,directory,state}=environment();
  await api.saveAsset(photo.relativePath,new Uint8Array([1]));
  await api.createLocalFolder(stateJson([photo]));
  const images=directory.directories.get('images');
  images.files.delete('photo-1.png');
  await assert.rejects(api.readLocalFolder(),/missing/);
  state.permission='denied';
  await assert.rejects(api.readLocalFolder(),/再指定/);
});

test('external image changes alter the revision and block stale JSON saves',async()=>{
  const {api,directory}=environment();
  await api.saveAsset(photo.relativePath,new Uint8Array([1]));
  const first=JSON.parse(await api.createLocalFolder(stateJson([photo])));
  directory.directories.get('images').files.get('photo-1.png').edit('changed');
  await assert.rejects(api.writeLocalFolder(stateJson([photo]),first.revision),/別の場所/);
});

test('malicious image paths cannot escape the project folder',async()=>{
  const {api,directory}=environment();
  await assert.rejects(api.saveAsset('../secret.png',new Uint8Array([1])),/パス/);
  await assert.rejects(api.createLocalFolder(stateJson([{...photo,relativePath:'images/../secret.png'}])),/パス/);
  assert.equal(directory.files.size,0);
});

test('immutable cached images cannot be replaced under an existing ID',async()=>{
  const {api}=environment();
  await api.saveAsset(photo.relativePath,new Uint8Array([1]));
  await assert.rejects(api.saveAsset(photo.relativePath,new Uint8Array([2])),/上書き/);
  assert.deepEqual([...await api.readAsset(photo.relativePath)],[1]);
});

test('aborted handle transaction is not reported as a connected folder',async()=>{
  const {api,state,stores}=environment();
  state.abort=true;
  await assert.rejects(api.createLocalFolder(stateJson()),/transaction aborted/);
  assert.equal(stores.handles.has('projectFolder'),false);
});

test('Pages projects keep separate folder handles and image caches',async()=>{
  const a=environment();
  const b=environment('https://user.github.io/repo/');
  const c=environment('https://user.github.io/another/');
  for(const env of[a,b,c]) await env.api.saveAsset(photo.relativePath,new Uint8Array([1]));
  assert.equal(a.databaseNames[0],'cosplay-diary-project');
  assert.equal(b.databaseNames[0],'cosplay-diary-project:/repo/');
  assert.notEqual(b.databaseNames[0],c.databaseNames[0]);
});

test('browser fallback remains usable without a directory picker',()=>{
  const window={};
  vm.runInNewContext(source,{window,document:{baseURI:'https://app.example/'},URL,Blob,Uint8Array});
  assert.equal(window.cosplayProjectStorage.supportsLocalFolder,false);
});


test('creates the named project inside the chosen location and preserves existing contents',async()=>{
  const {api,directory}=environment();
  directory.name='Documents';
  (await directory.getFileHandle('unrelated.txt',{create:true})).edit('keep');
  const result=JSON.parse(await api.createLocalFolder(stateJson()));
  assert.equal(result.name,'cosplayers_diary_project');
  const project=directory.directories.get('cosplayers_diary_project');
  assert.equal(await(await project.files.get(filename).getFile()).text(),stateJson());
  assert.ok(project.directories.has('images'));
  assert.equal(await(await directory.files.get('unrelated.txt').getFile()).text(),'keep');
  await assert.rejects(api.createLocalFolder(stateJson([],'別の内容')),/空ではありません/);
  assert.equal(await(await project.files.get(filename).getFile()).text(),stateJson());
});
