/**
 * Small Firestore REST client: enough to commit documents into a named
 * database, with no npm dependencies so the bootstrap script stays runnable
 * from a bare checkout.
 */

import { createSign } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';

const SCOPE = 'https://www.googleapis.com/auth/datastore';
const TOKEN_ENDPOINT = 'https://oauth2.googleapis.com/token';

function base64Url(value) {
  return Buffer.from(value).toString('base64url');
}

async function serviceAccountToken(keyFile) {
  const key = JSON.parse(readFileSync(keyFile, 'utf8'));
  const issuedAt = Math.floor(Date.now() / 1000);
  const claims = {
    iss: key.client_email,
    scope: SCOPE,
    aud: TOKEN_ENDPOINT,
    iat: issuedAt,
    exp: issuedAt + 3600,
  };

  const payload = `${base64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))}.${base64Url(JSON.stringify(claims))}`;
  const signature = createSign('RSA-SHA256').update(payload).end().sign(key.private_key, 'base64url');

  const response = await fetch(TOKEN_ENDPOINT, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: `${payload}.${signature}`,
    }),
  });

  if (!response.ok) {
    throw new Error(`Token exchange failed (${response.status}): ${await response.text()}`);
  }
  return (await response.json()).access_token;
}

/**
 * Resolves credentials in the order that needs the least setup:
 * an explicit token, a service-account key, then the local gcloud login.
 */
export async function resolveAccessToken() {
  if (process.env.GOOGLE_ACCESS_TOKEN) {
    return process.env.GOOGLE_ACCESS_TOKEN;
  }

  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    return serviceAccountToken(process.env.GOOGLE_APPLICATION_CREDENTIALS);
  }

  const args = ['auth', 'print-access-token'];
  if (process.env.GCLOUD_ACCOUNT) args.push(`--account=${process.env.GCLOUD_ACCOUNT}`);

  try {
    return execFileSync('gcloud', args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
  } catch (error) {
    throw new Error(
      'No credentials. Set GOOGLE_APPLICATION_CREDENTIALS to a service-account key, ' +
        'or sign in with `gcloud auth login` (optionally set GCLOUD_ACCOUNT).\n' +
        String(error.stderr ?? error.message).trim(),
    );
  }
}

/** JS value -> Firestore REST `Value`. */
function toValue(value) {
  if (value === null || value === undefined) return { nullValue: null };
  if (value instanceof Date) return { timestampValue: value.toISOString() };
  if (Array.isArray(value)) return { arrayValue: { values: value.map(toValue) } };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'number') {
    return Number.isInteger(value) ? { integerValue: String(value) } : { doubleValue: value };
  }
  if (typeof value === 'object') {
    return { mapValue: { fields: Object.fromEntries(Object.entries(value).map(([k, v]) => [k, toValue(v)])) } };
  }
  return { stringValue: String(value) };
}

export class FirestoreClient {
  constructor({ projectId, databaseId, accessToken }) {
    this.projectId = projectId;
    this.databaseId = databaseId;
    this.accessToken = accessToken;
    this.basePath = `projects/${projectId}/databases/${databaseId}/documents`;
  }

  async #request(method, path, body) {
    const response = await fetch(`https://firestore.googleapis.com/v1/${path}`, {
      method,
      headers: {
        authorization: `Bearer ${this.accessToken}`,
        'content-type': 'application/json',
        'x-goog-user-project': this.projectId,
      },
      body: body === undefined ? undefined : JSON.stringify(body),
    });

    if (!response.ok) {
      throw new Error(`Firestore ${method} ${path} failed (${response.status}): ${await response.text()}`);
    }
    return response.json();
  }

  /**
   * Writes documents by id, creating or overwriting each one. Commits come in
   * chunks because a single Firestore commit caps out at 500 writes.
   */
  async commit(collection, documents, { chunkSize = 200 } = {}) {
    let written = 0;

    for (let offset = 0; offset < documents.length; offset += chunkSize) {
      const chunk = documents.slice(offset, offset + chunkSize);
      const writes = chunk.map(({ id, data }) => ({
        update: {
          name: `${this.basePath}/${collection}/${id}`,
          fields: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, toValue(v)])),
        },
      }));

      await this.#request('POST', `${this.basePath}:commit`, { writes });
      written += chunk.length;
    }

    return written;
  }

  /** Number of documents currently in `collection` (bounded by `limit`). */
  async count(collection, limit = 1000) {
    const result = await this.#request('POST', `${this.basePath}:runQuery`, {
      structuredQuery: {
        from: [{ collectionId: collection }],
        select: { fields: [{ fieldPath: '__name__' }] },
        limit,
      },
    });
    return result.filter((row) => row.document).length;
  }
}
