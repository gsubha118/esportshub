const http = require('http');
const https = require('https');

// Test configuration
const BASE_URL = 'http://localhost:5000';
const API_BASE = `${BASE_URL}/api`;

// Test results storage
let testResults = {
  passed: 0,
  failed: 0,
  tests: []
};

// Helper function to make HTTP requests
function makeRequest(options, data = null) {
  return new Promise((resolve, reject) => {
    const client = options.protocol === 'https:' ? https : http;
    
    const req = client.request(options, (res) => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        try {
          const responseData = body ? JSON.parse(body) : null;
          resolve({
            statusCode: res.statusCode,
            headers: res.headers,
            data: responseData
          });
        } catch (e) {
          resolve({
            statusCode: res.statusCode,
            headers: res.headers,
            data: body
          });
        }
      });
    });

    req.on('error', reject);
    
    if (data) {
      req.write(typeof data === 'string' ? data : JSON.stringify(data));
    }
    
    req.end();
  });
}

// Test runner
async function runTest(name, testFn) {
  console.log(`\n🔍 Running: ${name}`);
  try {
    const result = await testFn();
    testResults.tests.push({ name, status: 'PASS', result });
    testResults.passed++;
    console.log(`✅ PASS: ${name}`);
    return result;
  } catch (error) {
    testResults.tests.push({ name, status: 'FAIL', error: error.message });
    testResults.failed++;
    console.log(`❌ FAIL: ${name} - ${error.message}`);
    return null;
  }
}

// Test functions
async function testServerHealth() {
  const options = {
    hostname: 'localhost',
    port: 5000,
    path: '/api/health',
    method: 'GET'
  };

  const response = await makeRequest(options);
  if (response.statusCode !== 200) {
    throw new Error(`Expected 200, got ${response.statusCode}`);
  }
  if (response.data?.status !== 'OK') {
    throw new Error(`Expected status OK, got ${response.data?.status}`);
  }
  return response.data;
}

async function testCreateOrganizerUser() {
  const options = {
    hostname: 'localhost',
    port: 5000,
    path: '/api/auth/register',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    }
  };

  const userData = {
    email: 'organizer@test.com',
    password: 'password123',
    role: 'organizer'
  };

  const response = await makeRequest(options, userData);
  if (response.statusCode !== 201) {
    throw new Error(`Expected 201, got ${response.statusCode}: ${JSON.stringify(response.data)}`);
  }
  return response.data;
}

async function testCreatePlayerUser() {
  const options = {
    hostname: 'localhost',
    port: 5000,
    path: '/api/auth/register',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    }
  };

  const userData = {
    email: 'player@test.com',
    password: 'password123',
    role: 'player'
  };

  const response = await makeRequest(options, userData);
  if (response.statusCode !== 201) {
    throw new Error(`Expected 201, got ${response.statusCode}: ${JSON.stringify(response.data)}`);
  }
  return response.data;
}

async function testOrganizerLogin() {
  const options = {
    hostname: 'localhost',
    port: 5000,
    path: '/api/auth/login',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    }
  };

  const loginData = {
    email: 'organizer@test.com',
    password: 'password123'
  };

  const response = await makeRequest(options, loginData);
  if (response.statusCode !== 200) {
    throw new Error(`Expected 200, got ${response.statusCode}: ${JSON.stringify(response.data)}`);
  }
  if (!response.data?.token) {
    throw new Error('No JWT token received');
  }
  return response.data.token;
}

async function testPlayerLogin() {
  const options = {
    hostname: 'localhost',
    port: 5000,
    path: '/api/auth/login',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    }
  };

  const loginData = {
    email: 'player@test.com',
    password: 'password123'
  };

  const response = await makeRequest(options, loginData);
  if (response.statusCode !== 200) {
    throw new Error(`Expected 200, got ${response.statusCode}: ${JSON.stringify(response.data)}`);
  }
  if (!response.data?.token) {
    throw new Error('No JWT token received');
  }
  return response.data.token;
}

// Main UAT test execution
async function runUATTests() {
  console.log('🚀 Starting UAT Tests for Esports Platform');
  console.log('===============================================');

  // Wait for server to be ready
  console.log('⏳ Waiting for server to start...');
  await new Promise(resolve => setTimeout(resolve, 3000));

  // Test basic server health
  await runTest('Server Health Check', testServerHealth);

  // Test user registration and authentication
  const organizerData = await runTest('Create Organizer User', testCreateOrganizerUser);
  const playerData = await runTest('Create Player User', testCreatePlayerUser);

  const organizerToken = await runTest('Organizer Login', testOrganizerLogin);
  const playerToken = await runTest('Player Login', testPlayerLogin);

  // Store tokens for subsequent tests
  global.organizerToken = organizerToken;
  global.playerToken = playerToken;

  // Print results
  console.log('\n📊 UAT Test Results Summary');
  console.log('============================');
  console.log(`✅ Passed: ${testResults.passed}`);
  console.log(`❌ Failed: ${testResults.failed}`);
  console.log(`📈 Success Rate: ${((testResults.passed / (testResults.passed + testResults.failed)) * 100).toFixed(1)}%`);

  if (testResults.failed > 0) {
    console.log('\n❌ Failed Tests:');
    testResults.tests
      .filter(test => test.status === 'FAIL')
      .forEach(test => console.log(`   - ${test.name}: ${test.error}`));
  }

  process.exit(testResults.failed > 0 ? 1 : 0);
}

// Check if server is running, if not, start it
async function checkServerAndStart() {
  try {
    await testServerHealth();
    console.log('✅ Server is already running');
    await runUATTests();
  } catch (error) {
    console.log('⚠️  Server not running, need to start it first');
    console.log('Please run "npm run dev" in the backend directory in a separate terminal, then run this script again.');
    process.exit(1);
  }
}

checkServerAndStart();