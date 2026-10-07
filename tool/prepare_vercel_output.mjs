import fs from 'node:fs';
import path from 'node:path';

const sourceDirectory = process.argv[2] ?? 'build/web';
const outputDirectory = '.vercel/output';
const staticDirectory = path.join(outputDirectory, 'static');

if (!fs.existsSync(path.join(sourceDirectory, 'index.html'))) {
  throw new Error(
    `${sourceDirectory} にWebビルドがありません。先にflutter build webを実行してください。`,
  );
}

fs.rmSync(outputDirectory, { recursive: true, force: true });
fs.mkdirSync(staticDirectory, { recursive: true });
fs.cpSync(sourceDirectory, staticDirectory, { recursive: true });
const config = {
  version: 3,
  routes: [
    { handle: 'filesystem' },
    { src: '/.*', dest: '/index.html' },
  ],
};
fs.writeFileSync(
  path.join(outputDirectory, 'config.json'),
  `${JSON.stringify(config, null, 2)}\n`,
);

console.log(`${sourceDirectory} をVercel Build Outputへ変換しました。`);
