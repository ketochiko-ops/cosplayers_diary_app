import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import test from 'node:test';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const script = fileURLToPath(
  new URL('./prepare_vercel_output.mjs', import.meta.url),
);

test('creates a static Vercel output with an SPA fallback', () => {
  const temporaryDirectory = fs.mkdtempSync(
    path.join(os.tmpdir(), 'cosplay-vercel-output-'),
  );
  const sourceDirectory = path.join(temporaryDirectory, 'web');

  try {
    fs.mkdirSync(sourceDirectory);
    fs.writeFileSync(path.join(sourceDirectory, 'index.html'), '<main>app</main>');
    fs.writeFileSync(path.join(sourceDirectory, 'main.dart.js'), 'void 0;');

    const result = spawnSync(process.execPath, [script, sourceDirectory], {
      cwd: temporaryDirectory,
      encoding: 'utf8',
    });

    assert.equal(result.status, 0, result.stderr);
    assert.equal(
      fs.readFileSync(
        path.join(temporaryDirectory, '.vercel/output/static/index.html'),
        'utf8',
      ),
      '<main>app</main>',
    );
    assert.equal(
      fs.readFileSync(
        path.join(temporaryDirectory, '.vercel/output/static/main.dart.js'),
        'utf8',
      ),
      'void 0;',
    );
    assert.deepEqual(
      JSON.parse(
        fs.readFileSync(
          path.join(temporaryDirectory, '.vercel/output/config.json'),
          'utf8',
        ),
      ),
      {
        version: 3,
        routes: [
          { handle: 'filesystem' },
          { src: '/.*', dest: '/index.html' },
        ],
      },
    );
  } finally {
    fs.rmSync(temporaryDirectory, { recursive: true, force: true });
  }
});
