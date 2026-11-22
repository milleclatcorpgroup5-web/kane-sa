import { expect, test } from '@playwright/test';

test('health endpoint', async ({ request }) => {
  const r = await request.get('/api/health');
  expect(r.ok()).toBe(true);
  expect((await r.json()).status).toBe('ok');
});

test('paj dakèy: similatè mete ajou rezilta a', async ({ page }) => {
  await page.goto('/');
  await expect(page.getByRole('heading', { name: /Konbyen tan pou m rive/ })).toBeVisible();
  const before = await page.getByText(/Ou ap rive nan/).textContent();
  await page.getByLabel(/Mwen ka mete chak mwa/).fill('500');
  await expect(page.getByText(/Ou ap rive nan/)).not.toHaveText(before ?? '');
});

test('paj legal yo chaje', async ({ page }) => {
  for (const p of ['/conditions', '/confidentialite', '/inscription', '/connexion']) {
    const r = await page.goto(p);
    expect(r?.status()).toBe(200);
  }
});

test('paj prive voye sou koneksyon', async ({ page }) => {
  test.skip(!process.env.NEXT_PUBLIC_SUPABASE_URL, 'Mande Supabase konfigire');
  await page.goto('/kontwol');
  await expect(page).toHaveURL(/connexion/);
});

test('flux kliyan konplè (mande kont tès)', async ({ page }) => {
  test.skip(!process.env.E2E_EMAIL || !process.env.E2E_PASSWORD, 'Mete E2E_EMAIL ak E2E_PASSWORD');
  await page.goto('/connexion');
  await page.getByLabel(/imel/i).fill(process.env.E2E_EMAIL!);
  await page.getByLabel(/modpas/i).fill(process.env.E2E_PASSWORD!);
  await page.getByRole('button', { name: /konekte/i }).click();
  await expect(page).toHaveURL(/tableau-de-bord/);
  await page.goto('/kontwol');
  await page.getByLabel(/Montan/).fill('1500');
  await page.getByRole('button', { name: 'Anrejistre' }).click();
  await expect(page.getByRole('status').filter({ hasText: 'Anrejistre' })).toBeVisible();
});
