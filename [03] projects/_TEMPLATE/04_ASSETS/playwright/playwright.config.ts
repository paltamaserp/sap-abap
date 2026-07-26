import { defineConfig } from '@playwright/test';
import * as dotenv from 'dotenv';
import * as path from 'path';

// A .env a playwright/ mappaban el (lasd .env.example). Titok nem verziozodik.
dotenv.config({ path: path.resolve(__dirname, '.env') });

const sapUrl = process.env.SAP_URL ?? '';
const service = process.env.SAP_SERVICE ?? '';
const client = process.env.SAP_CLIENT ?? '';

// SAP_URL vegen '/' — a szerviz-path ehhez fuzodik.
const baseURL = sapUrl && service
  ? `${sapUrl.endsWith('/') ? sapUrl : sapUrl + '/'}sap/opu/odata/sap/${service}/`
  : undefined;

export default defineConfig({
  testDir: './tests',
  // API tesztek: nincs bongeszo, gyorsak, de az SAP dev rendszert ne terheljuk.
  workers: 2,
  fullyParallel: false,
  // Csak CI-n tiltjuk a .only-t es ismetlunk halozati hiba miatt.
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  reporter: process.env.CI ? [['list'], ['html', { open: 'never' }]] : [['list'], ['html', { open: 'never' }]],
  timeout: 60_000,
  expect: { timeout: 15_000 },
  use: {
    baseURL,
    // Dev/qa rendszeren gyakran onalairt a tanusitvany — .env-bol kapcsolhato.
    ignoreHTTPSErrors: process.env.SAP_TLS_VERIFY === '0',
    extraHTTPHeaders: {
      Accept: 'application/json',
    },
    trace: 'retain-on-failure',
  },
});
