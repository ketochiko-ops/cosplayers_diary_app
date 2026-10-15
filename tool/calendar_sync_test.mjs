import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';
const source = fs.readFileSync('web/calendar_sync.js', 'utf8');
const marker = 'Cosplayers Diary dedicated calendar v1';
function response(body, status = 200) {
  return { ok: status >= 200 && status < 300, status, json: async () => body };
}
function environment(handler) {
  const calls = [];
  let denied = false;
  const oauth2 = {
    initTokenClient: (config) => {
      assert.ok(config.scope.includes('calendar.app.created'));
      assert.ok(config.scope.includes('calendar.calendarlist.readonly'));
      assert.ok(!config.scope.split(' ').includes('https://www.googleapis.com/auth/calendar'));
      return { requestAccessToken: () => config.callback({ access_token: 'test-token', expires_in: 3600 }) };
    },
    hasGrantedAllScopes: () => !denied,
    revoke() {},
  };
  const window = { google: { accounts: { oauth2 } } };
  vm.runInNewContext(source, {
    window, URLSearchParams, Intl, AbortController, setTimeout, clearTimeout,
    fetch: async (url, options) => {
      calls.push({ url, options });
      assert.equal(options.headers.Authorization, 'Bearer test-token');
      return handler(url, options, calls);
    },
  });
  return { api: window.cosplayCalendar, calls, deny: () => { denied = true; } };
}
const dedicated = { id: 'dedicated', summary: 'コスプレ日記', accessRole: 'owner', description: marker, selected: false };
const primary = { id: 'personal-account', primary: true, accessRole: 'owner', description: '' };

test('connect discovers hidden dedicated calendar and never writes primary', async () => {
  const { api, calls } = environment(async (url) => {
    assert.ok(url.includes('showHidden=true'));
    return response({ items: [primary, dedicated] });
  });
  const connected = JSON.parse(await api.connect('client-id'));
  assert.equal(connected.id, 'dedicated');
  assert.equal(connected.selected, false);
  assert.equal(calls.length, 1);
});

test('new calendar starts hidden and visibility changes only its calendar list entry', async () => {
  const { api, calls } = environment(async (url, options) => {
    if (url.includes('/calendarList?')) return response({ items: [primary] });
    if (url.endsWith('/calendars')) {
      assert.equal(JSON.parse(options.body).summary, 'コスプレ日記');
      return response({ id: 'new-calendar', summary: 'コスプレ日記' });
    }
    return response({});
  });
  await api.connect('client-id');
  await api.setVisible(true);
  assert.ok(calls.slice(2).every(c => c.url.endsWith('/calendarList/new-calendar')));
  assert.equal(JSON.parse(calls[2].options.body).selected, false);
  assert.equal(JSON.parse(calls[3].options.body).selected, true);
});

test('calendar and event pagination returns all data before reconciliation', async () => {
  let eventPages = 0;
  const { api } = environment(async (url) => {
    if (url.includes('/calendarList?')) return response({ items: [primary, dedicated] });
    eventPages++;
    return eventPages === 1 ? response({ items: [{ id: 'first' }], nextPageToken: 'page-two' }) : response({ items: [{ id: 'second' }] });
  });
  await api.connect('client-id');
  assert.equal(JSON.parse(await api.listEvents()).length, 2);
});

test('updates and deletes use ETags and a conflict is not retried', async () => {
  const { api, calls } = environment(async (url) => url.includes('/calendarList?')
    ? response({ items: [dedicated] }) : response({}, 412));
  await api.connect('client-id');
  await assert.rejects(api.putEvent(JSON.stringify({ id: 'id', summary: 'new' }), 'id', 'etag-1'), /別の端末/);
  assert.equal(calls[1].options.headers['If-Match'], 'etag-1');
  assert.equal(calls.length, 2);
  await assert.rejects(api.deleteEvent('id', 'etag-1'), /別の端末/);
  assert.equal(calls[2].options.headers['If-Match'], 'etag-1');
});

test('scope denial, rate limits and sign-out cannot trigger silent retries', async () => {
  const env = environment(async (url) => url.includes('/calendarList?')
    ? response({ items: [dedicated] }) : response({}, 429));
  env.deny();
  await assert.rejects(env.api.connect('client-id'), /許可/);
  assert.equal(env.calls.length, 0);
  const active = environment(async (url) => url.includes('/calendarList?')
    ? response({ items: [dedicated] }) : response({}, 429));
  await active.api.connect('client-id');
  await assert.rejects(active.api.listEvents(), /利用制限/);
  assert.equal(active.calls.length, 2);
  await active.api.disconnect();
  await assert.rejects(active.api.listEvents(), /再接続/);
  assert.equal(active.calls.length, 2);
});

test('ambiguous calendars do not create yet another copy', async () => {
  const { api, calls } = environment(async () => response({ items: [dedicated, { ...dedicated, id: 'duplicate' }] }));
  await assert.rejects(api.connect('client-id'), /複数/);
  assert.equal(calls.length, 1);
});

test('expired authorization pauses reads without leaking or persisting its token', async () => {
  const { api, calls } = environment(async (url) => url.includes('/calendarList?')
    ? response({ items: [dedicated] }) : response({}, 401));
  await api.connect('client-id');
  await assert.rejects(api.listEvents(), /期限/);
  await assert.rejects(api.listEvents(), /期限/);
  assert.equal(calls.length, 2);
});


test('a remembered dedicated calendar is reused even after its description is edited', async () => {
  const { api, calls } = environment(async () => response({ items: [primary, { ...dedicated, description: 'edited' }] }));
  const connection = JSON.parse(await api.connect('client-id', JSON.stringify(['dedicated'])));
  assert.equal(connection.id, 'dedicated');
  assert.equal(calls.length, 1);
});
