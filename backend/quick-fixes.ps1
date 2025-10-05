# QUICK FIXES FOR DEPLOYMENT READINESS
Write-Host "🚀 Running Quick Fixes for Deployment Readiness..." -ForegroundColor Yellow
Write-Host "=============================================" -ForegroundColor Yellow

# 1. Fix Jest Configuration for TypeScript
Write-Host "`n1. Configuring Jest for TypeScript..." -ForegroundColor Cyan
$jestConfig = @"
{
  "preset": "ts-jest",
  "testEnvironment": "node",
  "roots": ["<rootDir>/src", "<rootDir>/tests"],
  "testMatch": [
    "**/__tests__/**/*.ts",
    "**/?(*.)+(spec|test).ts"
  ],
  "transform": {
    "^.+\\.ts$": "ts-jest"
  },
  "collectCoverageFrom": [
    "src/**/*.ts",
    "!src/**/*.d.ts"
  ],
  "moduleFileExtensions": ["ts", "js", "json"],
  "setupFilesAfterEnv": ["<rootDir>/tests/setup.ts"]
}
"@

$jestConfig | Out-File -FilePath "jest.config.json" -Encoding utf8
Write-Host "✅ Jest configuration created" -ForegroundColor Green

# 2. Create test setup file
Write-Host "`n2. Creating test setup file..." -ForegroundColor Cyan
$testSetup = @"
// Test setup file
import { config } from 'dotenv';

// Load test environment variables
config({ path: '.env.test' });

// Mock console methods in tests to reduce noise
global.console = {
  ...console,
  log: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
};

// Set test timeout
jest.setTimeout(30000);
"@

New-Item -ItemType Directory -Force -Path "tests" | Out-Null
$testSetup | Out-File -FilePath "tests/setup.ts" -Encoding utf8
Write-Host "✅ Test setup file created" -ForegroundColor Green

# 3. Create test environment file
Write-Host "`n3. Creating test environment file..." -ForegroundColor Cyan
$testEnv = @"
# TEST ENVIRONMENT VARIABLES
NODE_ENV=test
PORT=5001

# Test Database (use a different database for tests)
DATABASE_URL=postgresql://postgres:admin123@localhost:5432/esports_platform_test?sslmode=disable
SUPABASE_URL=https://test.supabase.co
SUPABASE_ANON_KEY=test_anon_key
SUPABASE_SERVICE_ROLE_KEY=test_service_key

# Test JWT Secret
JWT_SECRET=test_jwt_secret_key_for_testing_only

# Test Payment Keys (use Stripe test keys)
STRIPE_SECRET_KEY=sk_test_test_key
STRIPE_WEBHOOK_SECRET=whsec_test_webhook
PAYMENT_WEBHOOK_SECRET=test_payment_webhook_secret

# Test Frontend
FRONTEND_URL=http://localhost:3000
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:5001
"@

$testEnv | Out-File -FilePath ".env.test" -Encoding utf8
Write-Host "✅ Test environment file created" -ForegroundColor Green

# 4. Fix TypeScript configuration for tests
Write-Host "`n4. Updating TypeScript configuration..." -ForegroundColor Cyan
$tsConfig = Get-Content "tsconfig.json" -Raw | ConvertFrom-Json
$tsConfig.compilerOptions.types = @("node", "jest")
$tsConfig.include = @("src/**/*", "tests/**/*")
$tsConfig | ConvertTo-Json -Depth 10 | Out-File -FilePath "tsconfig.json" -Encoding utf8
Write-Host "✅ TypeScript configuration updated" -ForegroundColor Green

# 5. Install missing dependencies
Write-Host "`n5. Installing missing test dependencies..." -ForegroundColor Cyan
try {
    npm install --save-dev @types/jest jest ts-jest supertest @types/supertest
    Write-Host "✅ Test dependencies installed" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to install dependencies: $($_.Exception.Message)" -ForegroundColor Red
}

# 6. Create a simple health check test
Write-Host "`n6. Creating basic health check test..." -ForegroundColor Cyan
$healthTest = @"
import request from 'supertest';
import app from '../src/app';

describe('Health Check', () => {
  it('should return 200 for health endpoint', async () => {
    const response = await request(app)
      .get('/api/health')
      .expect(200);
    
    expect(response.body).toHaveProperty('status', 'ok');
    expect(response.body).toHaveProperty('timestamp');
  });

  it('should handle 404 for unknown routes', async () => {
    await request(app)
      .get('/api/nonexistent')
      .expect(404);
  });
});
"@

$healthTest | Out-File -FilePath "tests/health.test.ts" -Encoding utf8
Write-Host "✅ Basic health test created" -ForegroundColor Green

# 7. Update package.json scripts
Write-Host "`n7. Updating package.json test scripts..." -ForegroundColor Cyan
$packageJson = Get-Content "package.json" -Raw | ConvertFrom-Json
$packageJson.scripts.test = "jest"
$packageJson.scripts."test:watch" = "jest --watch"
$packageJson.scripts."test:coverage" = "jest --coverage"
$packageJson | ConvertTo-Json -Depth 10 | Out-File -FilePath "package.json" -Encoding utf8
Write-Host "✅ Package.json scripts updated" -ForegroundColor Green

Write-Host "`n🎉 Quick fixes completed!" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Start your backend server: npm run dev" -ForegroundColor White
Write-Host "2. Run tests: npm test" -ForegroundColor White
Write-Host "3. Run deployment verification: ./deployment-verification.ps1" -ForegroundColor White
Write-Host "4. Check deployment health report" -ForegroundColor White