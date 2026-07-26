/**
 * MINTA spec — masold at IC_00x_<szerviz>.spec.ts nevre es szabd a szervizedre.
 *
 * Konvencio: egy .spec.ts egy szerviz vagy egy IC_xxx feladat.
 * Futtatas:  npm run test:list   (nincs halozat, csak listaz)
 *            npm test            (eles hivas a .env-ben megadott rendszerre)
 */
import { test, expect, APIRequestContext } from '@playwright/test';
import {
  createSapContext,
  fetchCsrf,
  odataResults,
  sapEnv,
  withClient,
  writeHeaders,
} from '../utils/sap';

// A tesztelt entitas — csereld a sajatodra.
const ENTITY_SET = 'AccountSet';

let ctx: APIRequestContext;

test.beforeAll(async () => {
  ctx = await createSapContext();
});

test.afterAll(async () => {
  await ctx.dispose();
});

test.describe('IC_000 — szerviz alapellenorzes', () => {
  test('a service document elerheto (auth + szerviz-nev jo)', async () => {
    const res = await ctx.get(withClient(''));
    expect(res.status(), 'service document nem 200').toBe(200);
  });

  test('a $metadata tartalmazza a vart EntitySet-et', async () => {
    const env = sapEnv();
    const res = await ctx.get(`$metadata?sap-client=${env.client}`);
    expect(res.status()).toBe(200);

    const xml = await res.text();
    expect(xml, `${ENTITY_SET} hianyzik a metadatabol`).toContain(ENTITY_SET);
  });
});

test.describe('IC_000 — olvaso hivasok', () => {
  test('EntitySet lekerdezes visszaad sorokat', async () => {
    const res = await ctx.get(withClient(`${ENTITY_SET}?$top=5`));
    expect(res.status()).toBe(200);

    const rows = odataResults(await res.json());
    expect(rows.length, 'ures eredmeny — jo a teszt-mandant?').toBeGreaterThan(0);
    expect(rows.length).toBeLessThanOrEqual(5);
  });

  test('$filter szukiti az eredmenyt', async () => {
    // A filter-mezot a $metadata alapjan csereld.
    const res = await ctx.get(withClient(`${ENTITY_SET}?$filter=Bukrs eq '1000'&$top=10`));
    expect(res.status()).toBe(200);

    const rows = odataResults<{ Bukrs?: string }>(await res.json());
    for (const row of rows) {
      expect(row.Bukrs).toBe('1000');
    }
  });

  test('nem letezo kulcsra 404 jon', async () => {
    const res = await ctx.get(withClient(`${ENTITY_SET}('ZZZZZZZZZZ')`));
    expect([400, 404], `varatlan status: ${res.status()}`).toContain(res.status());
  });
});

/**
 * Iro tesztek: alapbol kihagyva, mert adatot modositanak a rendszerben.
 * Engedelyezd (skip -> describe), ha van dedikalt teszt-mandant es teszt-adat.
 */
test.describe.skip('IC_000 — iro hivasok (CSRF)', () => {
  test('POST letrehoz egy entitast', async () => {
    const csrf = await fetchCsrf(ctx);

    const res = await ctx.post(withClient(ENTITY_SET), {
      headers: writeHeaders(csrf),
      data: { Bukrs: '1000', Name: 'Playwright teszt' },
    });

    expect(res.status(), await res.text()).toBe(201);
    const [created] = odataResults<{ Name?: string }>(await res.json());
    expect(created.Name).toBe('Playwright teszt');
  });

  test('CSRF token nelkul a POST 403-at ad', async () => {
    const res = await ctx.post(withClient(ENTITY_SET), {
      headers: { 'Content-Type': 'application/json' },
      data: { Bukrs: '1000', Name: 'Nincs token' },
    });
    expect(res.status()).toBe(403);
  });
});
