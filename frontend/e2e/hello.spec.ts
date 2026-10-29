import { expect, test } from '@playwright/test';

test('AC4: root shows the greeting from the backend', async ({ page }) => {
  await page.route('**/api/v1/hello', (route) => route.fulfill({ json: { message: 'Hello, traveller!' } }));
  await page.goto('/');
  await expect(page.getByTestId('hello-message')).toHaveText('Hello, traveller!');
});

test('AC5: backend down shows error with Retry, which recovers', async ({ page }) => {
  await page.route('**/api/v1/hello', (route) => route.abort());
  await page.goto('/');
  await expect(page.getByTestId('hello-error')).toBeVisible();
  await expect(page.getByTestId('hello-message')).toHaveCount(0);

  await page.unroute('**/api/v1/hello');
  await page.route('**/api/v1/hello', (route) => route.fulfill({ json: { message: 'Back again' } }));
  await page.getByTestId('hello-retry').click();
  await expect(page.getByTestId('hello-message')).toHaveText('Back again');
});
