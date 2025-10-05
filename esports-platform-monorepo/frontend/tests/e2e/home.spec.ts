import { test, expect } from '@playwright/test';

test.describe('Home Page', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
  });

  test('should display the main heading', async ({ page }) => {
    await expect(page.locator('h1')).toContainText('Welcome to Esports Platform');
  });

  test('should display featured tournaments section', async ({ page }) => {
    await expect(page.locator('h2')).toContainText('Featured Tournaments');
  });

  test('should have navigation links', async ({ page }) => {
    await expect(page.locator('nav a')).toHaveCount(3); // Home, Tournaments, Dashboard
  });

  test('should display tournament cards', async ({ page }) => {
    await expect(page.locator('.tournament-card')).toHaveCount(3);
  });
});

test.describe('Navigation', () => {
  test('should navigate to tournaments page', async ({ page }) => {
    await page.goto('/');
    await page.click('text=Tournaments');
    await expect(page).toHaveURL('/events');
    await expect(page.locator('h1')).toContainText('Tournaments');
  });

  test('should navigate to dashboard when logged in', async ({ page }) => {
    // This would require authentication setup
    // For now, just test that the link exists
    await page.goto('/');
    await expect(page.locator('text=Dashboard')).toBeVisible();
  });
});
