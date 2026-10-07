import { defineConfig } from '@playwright/test';
import * as dotenv from 'dotenv';
import * as path from 'path';
import { serviceRoot } from './utils/sap';

// A .env a playwright/ mappaban el (lasd .env.example). Titok nem verziozodik.
// A REST Client ezzel szemben a repo gyokerenek .env-jet olvassa — a ketto kulon.
dotenv.config({ path: path.resolve(__dirname, '.env') });

// A szerviz-URL-t a utils/sap.ts epiti — egy forras, hogy ne csusszon el a
// context baseURL-jetol. .env nelkul (pl. `npm run test:list`) undefined marad,
// hogy a config betoltese ne bukjon el.
let baseURL: string | undefined;
try {
  baseURL = serviceRoot();
} catch {
  baseURL = undefined;
}

export default defineConfig({
  testDir: './tests',
  // API tesztek: nincs bongeszo, gyorsak, de az SAP dev rendszert ne terheljuk.
  workers: 2,
  fullyParallel: false,
  // Csak CI-n tiltjuk a .only-t es ismetlunk halozati hiba miatt.
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  reporter: [['list'], ['html', { open: 'never' }]],
  timeout: 60_000,
  expect: { timeout: 15_000 },
  use: {
    // A beepitett `request` fixture-hoz. A specek jellemzoen a
    // createSapContext()-tel nyitnak sajat contextet (az visz auth-ot is) —
    // ez az ertek annak csak a hatterebeni parja, hogy a ketto ne terjen el.
    baseURL,
    // Dev/qa rendszeren gyakran onalairt a tanusitvany — .env-bol kapcsolhato.
    ignoreHTTPSErrors: process.env.SAP_TLS_VERIFY === '0',
    extraHTTPHeaders: {
      Accept: 'application/json',
    },
    trace: 'retain-on-failure',
  },
});
