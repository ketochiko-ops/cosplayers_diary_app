'use strict';

// The OAuth token never leaves memory. All calls use the visitor's own consent.
window.cosplayCalendar = (() => {
  const api = 'https://www.googleapis.com/calendar/v3';
  const scopes = [
    'https://www.googleapis.com/auth/calendar.app.created',
    'https://www.googleapis.com/auth/calendar.calendarlist.readonly',
  ];
  const marker = 'Cosplayers Diary dedicated calendar v1';
  const description = `${marker}\nコスプレ活動の日記・予定専用です。カレンダー一覧のチェックで表示・非表示を切り替えられます。Geminiには「コスプレ日記カレンダー」と指定してください。`;
  let token = null;
  let calendarId = null;
  let expiresAt = 0;

  function authorize(clientId) {
    if (!clientId || !window.google?.accounts?.oauth2) {
      throw new Error('Google認証の設定またはライブラリを確認してください。オンラインで再接続できます。');
    }
    token = null;
    calendarId = null;
    return new Promise((resolve, reject) => {
      const oauth = window.google.accounts.oauth2;
      const client = oauth.initTokenClient({
        client_id: clientId, scope: scopes.join(' '),
        callback(response) {
          if (response.error || !response.access_token || !oauth.hasGrantedAllScopes(response, ...scopes)) {
            reject(new Error('カレンダーへのアクセスが許可されませんでした。')); return;
          }
          token = response.access_token;
          expiresAt = Date.now() + Math.max(0, Number(response.expires_in || 3600) - 30) * 1000;
          resolve();
        },
        error_callback() { reject(new Error('Google認証を完了できませんでした。接続ボタンから再試行してください。')); },
      });
      client.requestAccessToken({ prompt: 'select_account' });
    });
  }

  async function request(path, options = {}) {
    if (!token || Date.now() >= expiresAt) {
      token = null;
      throw new Error('Google認証の期限が切れました。再接続してください。');
    }
    const abort = new AbortController();
    const timeout = setTimeout(() => abort.abort(), 20000);
    try {
      const response = await fetch(`${api}${path}`, {
        ...options, signal: abort.signal,
        headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json', ...options.headers },
      });
      if (response.status === 401) {
        token = null;
        throw new Error('Google認証の期限が切れました。再接続してください。');
      }
      if (response.status === 412) throw new Error('別の端末で予定が変更されました。「今すぐ同期」で最新内容を確認してください。');
      if (!response.ok) {
        const details = await response.json().catch(() => ({}));
        const reasons = details.error?.errors?.map(e => e.reason) || [];
        if (response.status === 429 || reasons.some(r => /[Rr]ateLimit|quotaExceeded/.test(r))) {
          throw new Error('Googleの利用制限に達しました。自動再試行は停止しました。時間をおいて同期してください。');
        }
        if (response.status === 404 || response.status === 410) {
          throw new Error('カレンダーまたは予定が見つかりません。カレンダーを削除した場合は再接続してください。');
        }
        const error = new Error(`Googleカレンダーでエラーが発生しました (${response.status})。変更は端末に保持しています。`);
        error.status = response.status;
        throw error;
      }
      return response.status === 204 ? null : response.json();
    } catch (error) {
      if (error.name === 'AbortError' || error instanceof TypeError) {
        throw new Error('カレンダーへ通信できませんでした。端末のデータを保持して同期を停止しました。オンラインで再同期してください。');
      }
      throw error;
    } finally {
      clearTimeout(timeout);
    }
  }

  async function pages(path, parameters) {
    const items = [];
    let pageToken;
    for (let page = 0; page < 20; page++) {
      const query = new URLSearchParams({ ...parameters, ...(pageToken ? { pageToken } : {}) });
      const result = await request(`${path}?${query}`);
      if (!Array.isArray(result.items || [])) throw new Error('カレンダーの応答形式が不正です。');
      items.push(...(result.items || []));
      pageToken = result.nextPageToken;
      if (!pageToken) return items;
    }
    throw new Error('カレンダーの件数が多すぎるため同期を停止しました。データは変更していません。');
  }

  async function connect(clientId, knownCalendarIds = '[]') {
    await authorize(clientId);
    const calendars = await pages('/users/me/calendarList', { showHidden: 'true', maxResults: '250' });
    const known = JSON.parse(knownCalendarIds);
    const remembered = calendars.filter(c => !c.primary && c.accessRole === 'owner' && known.includes(c.id));
    const matches = remembered.length ? remembered : calendars.filter(c => !c.primary && c.accessRole === 'owner' && c.description?.startsWith(marker));
    if (matches.length > 1) throw new Error('専用カレンダーが複数あります。Googleカレンダーで重複を整理して再接続してください。');
    let calendar = matches[0];
    if (!calendar) {
      calendar = await request('/calendars', {
        method: 'POST', body: JSON.stringify({ summary: 'コスプレ日記', description, timeZone: Intl.DateTimeFormat().resolvedOptions().timeZone || 'Asia/Tokyo' }),
      });
      calendarId = calendar.id;
      // New calendars do not clutter the user's existing calendar view.
      await setVisible(false);
      calendar.selected = false;
    }
    calendarId = calendar.id;
    if (!calendarId || calendarId === 'primary') throw new Error('専用カレンダーを特定できませんでした。');
    return JSON.stringify({ id: calendarId, name: calendar.summary || 'コスプレ日記', selected: calendar.selected === true });
  }

  function eventPath(id) {
    if (!calendarId) throw new Error('Googleカレンダーに再接続してください。');
    return `/calendars/${encodeURIComponent(calendarId)}/events${id ? `/${encodeURIComponent(id)}` : ''}`;
  }
  async function listEvents() {
    return JSON.stringify(await pages(eventPath(), { showDeleted: 'true', singleEvents: 'false', maxResults: '2500' }));
  }
  async function putEvent(source, existingId, etag) {
    const event = JSON.parse(source);
    if (existingId) {
      if (!etag) throw new Error('競合確認用の情報が不足しています。再同期してください。');
      delete event.id;
      return JSON.stringify(await request(`${eventPath(existingId)}?sendUpdates=none`, {
        method: 'PATCH', headers: { 'If-Match': etag }, body: JSON.stringify(event),
      }));
    }
    try {
      return JSON.stringify(await request(`${eventPath()}?sendUpdates=none`, { method: 'POST', body: JSON.stringify(event) }));
    } catch (error) {
      if (error.status === 409) {
        // A timed-out insert can already have succeeded. Never insert duplicates.
        throw new Error('同じ日記の予定が既にあります。「今すぐ同期」で確認してください。');
      }
      throw error;
    }
  }
  async function deleteEvent(id, etag) {
    if (!etag) throw new Error('競合確認用の情報が不足しています。再同期してください。');
    await request(`${eventPath(id)}?sendUpdates=none`, { method: 'DELETE', headers: { 'If-Match': etag } });
  }
  async function setVisible(visible) {
    if (!calendarId || calendarId === 'primary') throw new Error('専用カレンダーに接続してください。');
    await request(`/users/me/calendarList/${encodeURIComponent(calendarId)}`, { method: 'PATCH', body: JSON.stringify({ selected: visible }) });
  }
  async function disconnect() {
    const previous = token;
    token = null; calendarId = null; expiresAt = 0;
    if (previous && window.google?.accounts?.oauth2) window.google.accounts.oauth2.revoke(previous, () => {});
  }
  return { connect, listEvents, putEvent, deleteEvent, setVisible, disconnect };
})();
