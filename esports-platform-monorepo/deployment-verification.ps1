#!/usr/bin/env pwsh

Write-Host "🚀 DEPLOYMENT VERIFICATION SUITE" -ForegroundColor Green
Write-Host "Testing: Production Readiness | Database | CORS | SSL | Performance" -ForegroundColor Green
Write-Host "=======================================================================" -ForegroundColor Green

# Configuration
$BASE_URL = "http://localhost:5000"
$VERCEL_FRONTEND_URL = "http://localhost:3000"  # Simulated frontend for CORS testing
$START_TIME = Get-Date

# Test Results Storage
$deploymentResults = @{
    Auth = @()
    Events = @()
    Tickets = @()
    Webhooks = @()
    Dashboard = @()
    Brackets = @()
    Database = @()
    CORS = @()
    Environment = @()
    Performance = @()
    SSL = @()
}

# Global Variables
$organizerToken = $null
$playerToken = $null
$createdEventId = $null
$totalRequests = 0
$totalLatency = 0

# Enhanced HTTP Request Function with Performance Metrics
function Invoke-DeploymentTest {
    param(
        [string]$Method = "GET",
        [string]$Uri,
        [hashtable]$Headers = @{},
        [object]$Body = $null,
        [string]$TestName,
        [string]$Module = "General",
        [bool]$ExpectFailure = $false,
        [int]$ExpectedStatus = 200
    )
    
    $requestStart = Get-Date
    
    try {
        Write-Host "`n🔍 Testing: $TestName" -ForegroundColor Yellow
        Write-Host "   $Method $Uri"
        
        $params = @{
            Method = $Method
            Uri = $Uri
            Headers = $Headers
            TimeoutSec = 10
        }
        
        # Add CORS headers for cross-origin testing
        if ($Headers.Keys -notcontains "Origin") {
            $params.Headers["Origin"] = $VERCEL_FRONTEND_URL
        }
        
        if ($Body) {
            $params.Body = ($Body | ConvertTo-Json)
            $params.ContentType = "application/json"
        }
        
        $response = Invoke-WebRequest @params
        $requestEnd = Get-Date
        $latency = ($requestEnd - $requestStart).TotalMilliseconds
        
        $global:totalRequests++
        $global:totalLatency += $latency
        
        Write-Host "   ✅ Status: $($response.StatusCode) | Latency: $([math]::Round($latency, 2))ms" -ForegroundColor Green
        
        # Check for CORS headers
        $corsHeaders = @{
            "Access-Control-Allow-Origin" = $response.Headers["Access-Control-Allow-Origin"]
            "Access-Control-Allow-Methods" = $response.Headers["Access-Control-Allow-Methods"]
            "Access-Control-Allow-Headers" = $response.Headers["Access-Control-Allow-Headers"]
        }
        
        $testResult = @{
            Test = $TestName
            Method = $Method
            Uri = $Uri
            Expected = "Status: $ExpectedStatus"
            Actual = "Status: $($response.StatusCode)"
            Pass = ($response.StatusCode -eq $ExpectedStatus)
            Latency = $latency
            CORSHeaders = $corsHeaders
            ResponseSize = $response.Content.Length
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        
        try {
            $testResult.Content = $response.Content | ConvertFrom-Json -ErrorAction SilentlyContinue
        } catch {
            $testResult.Content = $response.Content
        }
        
        $deploymentResults[$Module] += $testResult
        
        return @{
            Success = $true
            StatusCode = $response.StatusCode
            Content = $testResult.Content
            Headers = $response.Headers
            Latency = $latency
            RawContent = $response.Content
        }
    }
    catch {
        $requestEnd = Get-Date
        $latency = ($requestEnd - $requestStart).TotalMilliseconds
        
        Write-Host "   ❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "   ⏱️ Latency: $([math]::Round($latency, 2))ms" -ForegroundColor Gray
        
        $statusCode = $null
        $content = $null
        
        if ($_.Exception -is [System.Net.WebException]) {
            $response = $_.Exception.Response
            if ($response) {
                $statusCode = [int]$response.StatusCode
            }
        }
        
        $testResult = @{
            Test = $TestName
            Method = $Method
            Uri = $Uri
            Expected = "Status: $ExpectedStatus"
            Actual = "Error: $($_.Exception.Message)"
            Pass = $ExpectFailure
            Latency = $latency
            Error = $_.Exception.Message
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        
        $deploymentResults[$Module] += $testResult
        
        return @{
            Success = $false
            StatusCode = $statusCode
            Content = $content
            Error = $_.Exception.Message
            Latency = $latency
        }
    }
}

# 1. ENVIRONMENT VARIABLES VERIFICATION
Write-Host "`n🔧 STEP 1: ENVIRONMENT VARIABLES VERIFICATION" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

$envVars = @{
    "DATABASE_URL" = $env:DATABASE_URL
    "SUPABASE_URL" = $env:SUPABASE_URL
    "SUPABASE_ANON_KEY" = $env:SUPABASE_ANON_KEY
    "JWT_SECRET" = $env:JWT_SECRET
    "PAYMENT_WEBHOOK_SECRET" = $env:PAYMENT_WEBHOOK_SECRET
    "NODE_ENV" = $env:NODE_ENV
    "PORT" = $env:PORT
}

foreach ($var in $envVars.GetEnumerator()) {
    $status = if ($var.Value) { "✅ SET" } else { "❌ MISSING" }
    $value = if ($var.Value) { 
        if ($var.Key -like "*SECRET*" -or $var.Key -like "*KEY*") {
            "$($var.Value.Substring(0, [Math]::Min(10, $var.Value.Length)))..." 
        } else { 
            $var.Value 
        }
    } else { 
        "NOT SET" 
    }
    
    Write-Host "   $status $($var.Key): $value" -ForegroundColor $(if ($var.Value) { "Green" } else { "Red" })
    
    $deploymentResults.Environment += @{
        Variable = $var.Key
        Set = [bool]$var.Value
        Value = if ($var.Value) { "SET" } else { "MISSING" }
    }
}

# 2. SERVER HEALTH CHECK
Write-Host "`n💓 STEP 2: SERVER HEALTH CHECK" -ForegroundColor Cyan
Write-Host "===============================" -ForegroundColor Cyan

$healthResult = Invoke-DeploymentTest -Method "GET" -Uri "$BASE_URL/api/health" -TestName "Server Health Check" -Module "Performance"

if (-not $healthResult.Success) {
    Write-Host "❌ SERVER NOT ACCESSIBLE - STARTING SERVER REQUIRED" -ForegroundColor Red
    Write-Host "   Please ensure the backend server is running on localhost:5000" -ForegroundColor Yellow
    Write-Host "   Command: cd backend && npm run dev" -ForegroundColor White
    exit 1
}

# 3. DATABASE CONNECTIVITY TEST
Write-Host "`n🗄️  STEP 3: DATABASE CONNECTIVITY (Supabase)" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# Test database through API endpoints that require DB access
$dbTests = @(
    @{ Name = "Database Connection via Users Query"; Endpoint = "/api/auth/profile"; RequiresAuth = $true },
    @{ Name = "Database Read via Events List"; Endpoint = "/api/events"; RequiresAuth = $false }
)

foreach ($test in $dbTests) {
    $headers = @{}
    if ($test.RequiresAuth -and $organizerToken) {
        $headers["Authorization"] = "Bearer $organizerToken"
    }
    
    $result = Invoke-DeploymentTest -Method "GET" -Uri "$BASE_URL$($test.Endpoint)" -Headers $headers -TestName $test.Name -Module "Database"
}

# 4. AUTHENTICATION MODULE TESTING
Write-Host "`n🔐 STEP 4: AUTHENTICATION MODULE" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan

# Test 1: Register Organizer
$organizerData = @{
    email = "deploy.organizer@test.com"
    password = "securepassword123"
    role = "organizer"
}

$regOrgResult = Invoke-DeploymentTest -Method "POST" -Uri "$BASE_URL/api/auth/register" -Body $organizerData -TestName "Register Organizer" -Module "Auth" -ExpectedStatus 201

# Test 2: Register Player
$playerData = @{
    email = "deploy.player@test.com"
    password = "securepassword123"
    role = "player"
}

$regPlayerResult = Invoke-DeploymentTest -Method "POST" -Uri "$BASE_URL/api/auth/register" -Body $playerData -TestName "Register Player" -Module "Auth" -ExpectedStatus 201

# Test 3: Login Organizer
$organizerLogin = @{
    email = "deploy.organizer@test.com"
    password = "securepassword123"
}

$loginOrgResult = Invoke-DeploymentTest -Method "POST" -Uri "$BASE_URL/api/auth/login" -Body $organizerLogin -TestName "Organizer Login" -Module "Auth"

if ($loginOrgResult.Success -and $loginOrgResult.Content.token) {
    $organizerToken = $loginOrgResult.Content.token
    Write-Host "   🔑 Organizer Token: $($organizerToken.Substring(0,20))..." -ForegroundColor Blue
}

# Test 4: Login Player
$playerLogin = @{
    email = "deploy.player@test.com"
    password = "securepassword123"
}

$loginPlayerResult = Invoke-DeploymentTest -Method "POST" -Uri "$BASE_URL/api/auth/login" -Body $playerLogin -TestName "Player Login" -Module "Auth"

if ($loginPlayerResult.Success -and $loginPlayerResult.Content.token) {
    $playerToken = $loginPlayerResult.Content.token
    Write-Host "   🔑 Player Token: $($playerToken.Substring(0,20))..." -ForegroundColor Blue
}

# Test 5: Get Profile (with auth)
if ($organizerToken) {
    $profileResult = Invoke-DeploymentTest -Method "GET" -Uri "$BASE_URL/api/auth/profile" -Headers @{"Authorization" = "Bearer $organizerToken"} -TestName "Get User Profile" -Module "Auth"
}

# 5. EVENTS MODULE TESTING
Write-Host "`n📅 STEP 5: EVENTS MODULE" -ForegroundColor Cyan
Write-Host "========================" -ForegroundColor Cyan

# Test 1: List Events (Public)
$listEventsResult = Invoke-DeploymentTest -Method "GET" -Uri "$BASE_URL/api/events" -TestName "List Events (Public)" -Module "Events"

# Test 2: Create Event (Organizer)
if ($organizerToken) {
    $eventData = @{
        title = "Deployment Test Championship"
        description = "Test tournament for deployment verification"
        game = "Valorant"
        start_time = "2024-12-30T10:00:00Z"
        end_time = "2024-12-30T18:00:00Z"
        bracket_type = "single_elimination"
        max_teams = 16
    }
    
    $createEventResult = Invoke-DeploymentTest -Method "POST" -Uri "$BASE_URL/api/events" -Headers @{"Authorization" = "Bearer $organizerToken"} -Body $eventData -TestName "Create Event" -Module "Events" -ExpectedStatus 201
    
    if ($createEventResult.Success -and $createEventResult.Content.event.id) {
        $createdEventId = $createEventResult.Content.event.id
        Write-Host "   🎯 Created Event ID: $createdEventId" -ForegroundColor Blue
    }
}

# Test 3: Get Event Details
if ($createdEventId) {
    $eventDetailsResult = Invoke-DeploymentTest -Method "GET" -Uri "$BASE_URL/api/events/$createdEventId" -TestName "Get Event Details" -Module "Events"
}

# Test 4: Join Event (Player)
if ($playerToken -and $createdEventId) {
    $joinEventResult = Invoke-DeploymentTest -Method "POST" -Uri "$BASE_URL/api/events/$createdEventId/join" -Headers @{"Authorization" = "Bearer $playerToken"} -TestName "Player Join Event" -Module "Events"
}

# 6. TICKETS MODULE TESTING
Write-Host "`n🎫 STEP 6: TICKETS MODULE" -ForegroundColor Cyan
Write-Host "==========================" -ForegroundColor Cyan

# Test 1: List Player Tickets
if ($playerToken) {
    $ticketsResult = Invoke-DeploymentTest -Method "GET" -Uri "$BASE_URL/api/tickets" -Headers @{"Authorization" = "Bearer $playerToken"} -TestName "List Player Tickets" -Module "Tickets"
}

# 7. WEBHOOKS MODULE TESTING
Write-Host "`n🪝 STEP 7: WEBHOOKS MODULE (Payment Flow)" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Test 1: Valid Payment Webhook
$webhookData = @{
    external_payment_ref = "deploy_test_payment_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    status = "completed"
    webhook_secret = "test-webhook-secret-key"
    amount = 25.00
    currency = "USD"
}

$webhookResult = Invoke-DeploymentTest -Method "POST" -Uri "$BASE_URL/api/webhooks/payment" -Body $webhookData -TestName "Payment Webhook Processing" -Module "Webhooks"

# Test 2: Invalid Webhook Secret (Security Test)
$invalidWebhookData = @{
    external_payment_ref = "test_invalid"
    status = "completed"
    webhook_secret = "wrong_secret"
}

$invalidWebhookResult = Invoke-DeploymentTest -Method "POST" -Uri "$BASE_URL/api/webhooks/payment" -Body $invalidWebhookData -TestName "Invalid Webhook Secret (Security)" -Module "Webhooks" -ExpectedStatus 401

# 8. DASHBOARD MODULE TESTING
Write-Host "`n📊 STEP 8: DASHBOARD MODULE (Organizer Overview)" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

# Test 1: Organizer Dashboard Access
if ($organizerToken) {
    $dashboardResult = Invoke-DeploymentTest -Method "GET" -Uri "$BASE_URL/api/dashboard" -Headers @{"Authorization" = "Bearer $organizerToken"} -TestName "Organizer Dashboard Access" -Module "Dashboard"
}

# Test 2: Dashboard Statistics
if ($organizerToken) {
    $dashboardStatsResult = Invoke-DeploymentTest -Method "GET" -Uri "$BASE_URL/api/dashboard/stats" -Headers @{"Authorization" = "Bearer $organizerToken"} -TestName "Dashboard Statistics" -Module "Dashboard"
}

# Test 3: Unauthorized Dashboard Access (Security)
if ($playerToken) {
    $unauthorizedDashResult = Invoke-DeploymentTest -Method "GET" -Uri "$BASE_URL/api/dashboard" -Headers @{"Authorization" = "Bearer $playerToken"} -TestName "Unauthorized Dashboard Access" -Module "Dashboard" -ExpectedStatus 403
}

# 9. BRACKETS MODULE TESTING
Write-Host "`n🏆 STEP 9: BRACKETS MODULE (Match Generation & Retrieval)" -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan

# Test 1: Generate Tournament Matches
if ($organizerToken -and $createdEventId) {
    $generateMatchesResult = Invoke-DeploymentTest -Method "POST" -Uri "$BASE_URL/api/events/$createdEventId/matches" -Headers @{"Authorization" = "Bearer $organizerToken"} -TestName "Generate Tournament Matches" -Module "Brackets" -ExpectedStatus 201
}

# Test 2: Retrieve Event Bracket
if ($createdEventId) {
    $bracketResult = Invoke-DeploymentTest -Method "GET" -Uri "$BASE_URL/api/events/$createdEventId/bracket" -TestName "Retrieve Event Bracket" -Module "Brackets"
}

# Test 3: List Event Matches
if ($organizerToken -and $createdEventId) {
    $matchesResult = Invoke-DeploymentTest -Method "GET" -Uri "$BASE_URL/api/events/$createdEventId/matches" -Headers @{"Authorization" = "Bearer $organizerToken"} -TestName "List Event Matches" -Module "Brackets"
}

# 10. CORS TESTING (Cross-Origin Requests)
Write-Host "`n🌐 STEP 10: CORS TESTING (Cross-Origin Requests)" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

$corsTestHeaders = @{
    "Origin" = "https://your-app.vercel.app"
    "Access-Control-Request-Method" = "POST"
    "Access-Control-Request-Headers" = "Content-Type,Authorization"
}

# CORS Preflight Test
$corsPreflightResult = Invoke-DeploymentTest -Method "OPTIONS" -Uri "$BASE_URL/api/events" -Headers $corsTestHeaders -TestName "CORS Preflight Request" -Module "CORS"

# CORS Actual Request Test
$corsActualResult = Invoke-DeploymentTest -Method "GET" -Uri "$BASE_URL/api/events" -Headers @{"Origin" = "https://your-app.vercel.app"} -TestName "CORS Actual Request" -Module "CORS"

# 11. SSL/TLS CHECK (if applicable)
Write-Host "`n🔒 STEP 11: SSL/TLS VERIFICATION" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

# For localhost, we'll simulate SSL checks
$sslStatus = if ($BASE_URL -like "https://*") {
    try {
        $sslResult = Invoke-WebRequest -Uri $BASE_URL -Method HEAD -TimeoutSec 5
        "✅ SSL/TLS Certificate Valid"
    } catch {
        "❌ SSL/TLS Issues Detected"
    }
} else {
    "⚠️ HTTP Only (Development Mode)"
}

Write-Host "   $sslStatus" -ForegroundColor $(if ($sslStatus -like "✅*") { "Green" } elseif ($sslStatus -like "⚠️*") { "Yellow" } else { "Red" })

$deploymentResults.SSL += @{
    Test = "SSL/TLS Certificate Check"
    Status = $sslStatus
    URL = $BASE_URL
    Protocol = if ($BASE_URL -like "https://*") { "HTTPS" } else { "HTTP" }
}

# 12. PERFORMANCE METRICS CALCULATION
Write-Host "`n⚡ STEP 12: PERFORMANCE METRICS" -ForegroundColor Cyan
Write-Host "===============================" -ForegroundColor Cyan

$averageLatency = if ($totalRequests -gt 0) { [math]::Round($totalLatency / $totalRequests, 2) } else { 0 }
$totalTestTime = ((Get-Date) - $START_TIME).TotalSeconds

Write-Host "   📊 Total Requests: $totalRequests" -ForegroundColor White
Write-Host "   ⚡ Average Latency: ${averageLatency}ms" -ForegroundColor White
Write-Host "   ⏱️ Total Test Time: $([math]::Round($totalTestTime, 2)) seconds" -ForegroundColor White

$performanceGrade = switch ($averageLatency) {
    { $_ -le 100 } { "🟢 EXCELLENT" }
    { $_ -le 300 } { "🟡 GOOD" }
    { $_ -le 1000 } { "🟠 ACCEPTABLE" }
    default { "🔴 POOR" }
}

Write-Host "   🏆 Performance Grade: $performanceGrade" -ForegroundColor White

# 13. GENERATE DEPLOYMENT HEALTH REPORT
Write-Host "`n📋 GENERATING DEPLOYMENT HEALTH REPORT" -ForegroundColor Magenta
Write-Host "=======================================" -ForegroundColor Magenta

# Calculate module scores
$moduleScores = @{}
$overallPassed = 0
$overallTotal = 0

foreach ($module in $deploymentResults.Keys) {
    if ($module -in @("Environment", "Performance", "SSL")) { continue }
    
    $tests = $deploymentResults[$module]
    $passed = ($tests | Where-Object { $_.Pass -eq $true }).Count
    $total = $tests.Count
    $percentage = if ($total -gt 0) { [math]::Round(($passed / $total) * 100, 1) } else { 0 }
    
    $moduleScores[$module] = @{
        Passed = $passed
        Total = $total
        Percentage = $percentage
    }
    
    $overallPassed += $passed
    $overallTotal += $total
    
    $status = switch ($percentage) {
        100 { "🟢 EXCELLENT" }
        { $_ -ge 80 } { "🟡 GOOD" }
        { $_ -ge 60 } { "🟠 ACCEPTABLE" }
        default { "🔴 POOR" }
    }
    
    Write-Host "`n$status $module Module: $passed/$total tests ($percentage%)" -ForegroundColor $(
        switch ($percentage) {
            100 { "Green" }
            { $_ -ge 80 } { "Yellow" }
            { $_ -ge 60 } { "DarkYellow" }
            default { "Red" }
        }
    )
    
    # Show failed tests
    $failedTests = $tests | Where-Object { $_.Pass -eq $false }
    foreach ($test in $failedTests) {
        Write-Host "   ❌ $($test.Test): $($test.Actual)" -ForegroundColor Red
    }
}

# Calculate overall scores
$overallPercentage = if ($overallTotal -gt 0) { [math]::Round(($overallPassed / $overallTotal) * 100, 1) } else { 0 }

# Generate uptime score (based on successful health checks and response times)
$uptimeScore = if ($healthResult.Success -and $averageLatency -lt 1000) { 99.9 } elseif ($healthResult.Success) { 95.0 } else { 0.0 }

# Environment variables score
$envSetCount = ($deploymentResults.Environment | Where-Object { $_.Set }).Count
$envTotalCount = $deploymentResults.Environment.Count
$envScore = if ($envTotalCount -gt 0) { [math]::Round(($envSetCount / $envTotalCount) * 100, 1) } else { 0 }

Write-Host "`n🏆 DEPLOYMENT HEALTH REPORT" -ForegroundColor Cyan
Write-Host "============================" -ForegroundColor Cyan
Write-Host "📊 Overall Test Success: $overallPercentage% ($overallPassed/$overallTotal tests)" -ForegroundColor White
Write-Host "⚡ Performance Score: $performanceGrade (${averageLatency}ms avg)" -ForegroundColor White
Write-Host "💓 Uptime Score: $uptimeScore%" -ForegroundColor White
Write-Host "🔧 Environment Config: $envScore% ($envSetCount/$envTotalCount variables)" -ForegroundColor White
Write-Host "🔒 SSL Status: $sslStatus" -ForegroundColor White

# Final deployment confidence score
$deploymentConfidence = [math]::Round(($overallPercentage * 0.4 + $uptimeScore * 0.2 + $envScore * 0.2 + (if ($averageLatency -lt 500) { 100 } else { 50 }) * 0.2), 1)

$confidenceGrade = switch ($deploymentConfidence) {
    { $_ -ge 95 } { "🏆 PRODUCTION READY" }
    { $_ -ge 85 } { "✅ DEPLOYMENT APPROVED" }
    { $_ -ge 75 } { "⚠️ REVIEW REQUIRED" }
    default { "❌ NOT READY" }
}

Write-Host "`n🎯 FINAL DEPLOYMENT CONFIDENCE SCORE: $deploymentConfidence%" -ForegroundColor Cyan
Write-Host "🏅 DEPLOYMENT STATUS: $confidenceGrade" -ForegroundColor $(
    switch ($deploymentConfidence) {
        { $_ -ge 85 } { "Green" }
        { $_ -ge 75 } { "Yellow" }
        default { "Red" }
    }
)

# Export comprehensive report
$deploymentReport = @{
    TestDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Environment = "Development/Staging"
    BaseURL = $BASE_URL
    TotalTests = $overallTotal
    PassedTests = $overallPassed
    OverallSuccess = $overallPercentage
    PerformanceMetrics = @{
        AverageLatency = $averageLatency
        TotalRequests = $totalRequests
        TestDuration = $totalTestTime
        Grade = $performanceGrade
    }
    UptimeScore = $uptimeScore
    EnvironmentScore = $envScore
    DeploymentConfidence = $deploymentConfidence
    Status = $confidenceGrade
    ModuleScores = $moduleScores
    DetailedResults = $deploymentResults
    Recommendations = @()
}

# Add recommendations based on results
if ($overallPercentage -lt 100) {
    $deploymentReport.Recommendations += "Address failing tests before production deployment"
}
if ($averageLatency -gt 500) {
    $deploymentReport.Recommendations += "Optimize API performance - average latency is high"
}
if ($envScore -lt 100) {
    $deploymentReport.Recommendations += "Set all required environment variables"
}
if ($BASE_URL -like "http://*") {
    $deploymentReport.Recommendations += "Enable SSL/TLS for production deployment"
}

$deploymentReport | ConvertTo-Json -Depth 10 | Out-File "deployment-health-report.json" -Encoding UTF8

Write-Host "`n💾 Comprehensive report saved to: deployment-health-report.json" -ForegroundColor Blue
Write-Host "🔍 Review detailed results for production deployment planning" -ForegroundColor Blue

Write-Host "`n🚀 DEPLOYMENT VERIFICATION COMPLETE!" -ForegroundColor Green