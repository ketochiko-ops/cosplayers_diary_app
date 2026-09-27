import fs from 'node:fs';
import path from 'node:path';

const outputDirectory = process.argv[2] ?? 'build/web';
const sourceWorker = fs.readFileSync('web/app_service_worker.js', 'utf8');
const shellBlock = sourceWorker.match(/const APP_SHELL = \[([\s\S]*?)\];/);

if (!shellBlock) {
  throw new Error('Service WorkerのAPP_SHELL定義を読み取れません。');
}

const shellPaths = [...shellBlock[1].matchAll(/'([^']+)'/g)].map(
  (match) => match[1],
);
const requiredFiles = [
  'app_service_worker.js',
  'flutter_bootstrap.js',
  'index.html',
  'manifest.json',
  ...shellPaths.filter((entry) => entry !== './'),
];
const missing = requiredFiles.filter(
  (entry) => !fs.existsSync(path.join(outputDirectory, entry)),
);

if (missing.length > 0) {
  throw new Error(`PWA成果物が不足しています: ${missing.join(', ')}`);
}

const bootstrap = fs.readFileSync(
  path.join(outputDirectory, 'flutter_bootstrap.js'),
  'utf8',
);
if (!bootstrap.includes('app_service_worker.js')) {
  throw new Error('独自Service Workerが登録されていません。');
}
if (!bootstrap.includes("canvasKitBaseUrl: 'canvaskit/'")) {
  throw new Error('CanvasKitがローカル配信に固定されていません。');
}

JSON.parse(fs.readFileSync(path.join(outputDirectory, 'manifest.json'), 'utf8'));
console.log(`PWA成果物を検証しました（プリキャッシュ ${shellPaths.length}件）。`);
