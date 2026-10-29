/**
 * Kozos SAP Gateway / OData helper a Playwright request API-hoz.
 *
 * Feladatai:
 *  - Basic auth osszeallitasa a .env-bol (titok soha nem kerul a kodba).
 *  - sap-client query paraméter automatikus hozzafuzese.
 *  - CSRF token + session cookie kezelese az iro (POST/MERGE/DELETE) hivasokhoz.
 */
import { APIRequestContext, request as pwRequest, expect } from '@playwright/test';

export interface SapEnv {
  url: string;
  client: string;
  username: string;
  password: string;
  service: string;
}

/** .env beolvasas + kotelezo mezok ellenorzese. Hianynal beszedes hiba. */
export function sapEnv(): SapEnv {
  const env = {
    url: process.env.SAP_URL ?? '',
    client: process.env.SAP_CLIENT ?? '',
    username: process.env.SAP_USERNAME ?? '',
    password: process.env.SAP_PASSWORD ?? '',
    service: process.env.SAP_SERVICE ?? '',
  };
  const missing = Object.entries(env)
    .filter(([, v]) => !v)
    .map(([k]) => k.toUpperCase());
  if (missing.length > 0) {
    throw new Error(
      `Hianyzo .env kulcs(ok): SAP_${missing.join(', SAP_')}. ` +
        'Masold at a .env.example fajlt .env nevre es toltsd ki.',
    );
  }
  return env;
}

/** A szerviz gyoker-URL-je, '/' vegzodessel. */
export function serviceRoot(env: SapEnv = sapEnv()): string {
  const base = env.url.endsWith('/') ? env.url : `${env.url}/`;
  return `${base}sap/opu/odata/sap/${env.service}/`;
}

/**
 * SAP-ra elokonfiguralt request context: Basic auth + JSON Accept.
 * Hasznalat test.beforeAll-ban, a context-et afterAll-ban dispose-old.
 */
export async function createSapContext(env: SapEnv = sapEnv()): Promise<APIRequestContext> {
  return pwRequest.newContext({
    baseURL: serviceRoot(env),
    httpCredentials: { username: env.username, password: env.password },
    ignoreHTTPSErrors: process.env.SAP_TLS_VERIFY === '0',
    extraHTTPHeaders: { Accept: 'application/json' },
  });
}

/** sap-client + $format=json ratoltese egy relativ path-ra. */
export function withClient(pathname: string, env: SapEnv = sapEnv()): string {
  const sep = pathname.includes('?') ? '&' : '?';
  return `${pathname}${sep}sap-client=${env.client}&$format=json`;
}

/**
 * CSRF token + session cookie lekerese.
 * Iro muvelet (POST/MERGE/PUT/DELETE) elott kotelezo — nelkule 403 CSRF hiba.
 */
export async function fetchCsrf(
  ctx: APIRequestContext,
  env: SapEnv = sapEnv(),
): Promise<{ token: string; cookie: string }> {
  const res = await ctx.get(`?sap-client=${env.client}`, {
    headers: { 'X-CSRF-Token': 'Fetch' },
  });
  expect(res.status(), 'CSRF fetch nem sikerult').toBe(200);

  const headers = res.headers();
  const token = headers['x-csrf-token'];
  if (!token) {
    throw new Error('Nem jott vissza x-csrf-token header. Auth vagy szerviz-nev hibas?');
  }
  // A set-cookie tobb cookie-t is tartalmazhat; a Cookie headerhez a name=value reszek kellenek.
  const raw = (await res.headersArray())
    .filter((h) => h.name.toLowerCase() === 'set-cookie')
    .map((h) => h.value.split(';')[0])
    .join('; ');

  return { token, cookie: raw };
}

/** Iro hivasokhoz szukseges headerek egy helyen. */
export function writeHeaders(csrf: { token: string; cookie: string }): Record<string, string> {
  return {
    'X-CSRF-Token': csrf.token,
    Cookie: csrf.cookie,
    'Content-Type': 'application/json',
  };
}

/**
 * OData V2 valasz kicsomagolasa: { d: { results: [...] } } vagy { d: {...} }.
 * V4-nel a 'value' kulcsot hasznald helyette.
 */
export function odataResults<T = Record<string, unknown>>(body: any): T[] {
  if (body?.d?.results) return body.d.results as T[];
  if (body?.d) return [body.d as T];
  return [];
}
