/**
 * MINTA spec — masold at <feladatkod>_<szerviz>.spec.ts nevre es szabd a
 * szervizedre. Ezt a fajlt ne szerkeszd.
 *
 * Konvencio: egy .spec.ts egy szerviz vagy egy <feladatkod> feladat.
 * Futtatas:  npm run test:list   (nincs halozat, csak listaz)
 *            npm test            (eles hivas a .env-ben megadott rendszerre)
 *
 * A lenti konstansok PLACEHOLDER-ek — masolas utan toltsd ki oket a szerviz
 * $metadata-ja alapjan. Kitoltes nelkul a tesztek listazodnak, de elszallnak.
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

/** A tesztelt EntitySet neve a $metadata-bol, pl. 'BusinessPartnerSet'. */
const ENTITY_SET = '<EntitySet>';

/** Egy szuresre alkalmas mezo es a vart erteke. */
const FILTER_FIELD = '<Mezo>';
const FILTER_VALUE = '<ertek>';

/** Letrehozashoz kuldott minta-rekord (a kotelezo mezokkel). */
const NEW_RECORD: Record<string, string> = {
  '<Mezo1>': '<ertek1>',
  '<Mezo2>': '<ertek2>',
};

let ctx: APIRequestContext;

test.beforeAll(async () => {
  ctx = await createSapContext();
});

test.afterAll(async () => {
  // Optional chaining: ha a beforeAll elszallt (pl. hianyos .env), a ctx
  // undefined — e nelkul egy masodik hiba elfedne az igazi okot.
  await ctx?.dispose();
});

test.describe('Szerviz alapellenorzes', () => {
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

test.describe('Olvaso hivasok', () => {
  test('EntitySet lekerdezes visszaad sorokat', async () => {
    const res = await ctx.get(withClient(`${ENTITY_SET}?$top=5`));
    expect(res.status()).toBe(200);

    const rows = odataResults(await res.json());
    expect(rows.length, 'ures eredmeny — jo a teszt-mandant?').toBeGreaterThan(0);
    expect(rows.length).toBeLessThanOrEqual(5);
  });

  test('$filter szukiti az eredmenyt', async () => {
    const res = await ctx.get(
      withClient(`${ENTITY_SET}?$filter=${FILTER_FIELD} eq '${FILTER_VALUE}'&$top=10`),
    );
    expect(res.status()).toBe(200);

    const rows = odataResults<Record<string, unknown>>(await res.json());
    for (const row of rows) {
      expect(row[FILTER_FIELD]).toBe(FILTER_VALUE);
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
test.describe.skip('Iro hivasok (CSRF)', () => {
  test('POST letrehoz egy entitast', async () => {
    const csrf = await fetchCsrf(ctx);

    const res = await ctx.post(withClient(ENTITY_SET), {
      headers: writeHeaders(csrf),
      data: NEW_RECORD,
    });

    expect(res.status(), await res.text()).toBe(201);
    const [created] = odataResults<Record<string, unknown>>(await res.json());
    const [firstField] = Object.keys(NEW_RECORD);
    expect(created[firstField]).toBe(NEW_RECORD[firstField]);
  });

  test('CSRF token nelkul a POST 403-at ad', async () => {
    const res = await ctx.post(withClient(ENTITY_SET), {
      headers: { 'Content-Type': 'application/json' },
      data: NEW_RECORD,
    });
    expect(res.status()).toBe(403);
  });
});
