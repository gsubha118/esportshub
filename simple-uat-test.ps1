#!/usr/bin/env pwsh

Write-Host "FOCUSED UAT TESTING SUITE" -ForegroundColor Green
Write-Host "Testing: Webhooks | Dashboard | Brackets" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green

$BASE_URL = "http://localhost:5000"
$testResults = @{
    Webhooks = @()
    Dashboard = @()
    Brackets = @()
}

# Global Variables for Test Data
$organizerToken = $null
$playerToken = $null
$createdEventId = $null

# Helper function to make HTTP requests
function Invoke-TestRequest {
    param(
        [string]$Method = "GET",
        [string]$Uri,
        [hashtable]$Headers = @{},
        [object]$Body = $null,
        [string]$TestName
    )
    
    try {
        Write-Host "`nTesting: $TestName" -ForegroundColor Yellow
        Write-Host "   $Method $Uri"
        
        $params = @{
            Method = $Method
            Uri = $Uri
            Headers = $Headers
        }
        
        if ($Body) {
            $params.Body = ($Body | ConvertTo-Json)
            $params.ContentType = "application/json"
        }
        
        $response = Invoke-WebRequest @params
        
        Write-Host "   Status: $($response.StatusCode)" -ForegroundColor Green
        Write-Host "   Response: $($response.Content)"
        
        return @{
            Success = $true
            StatusCode = $response.StatusCode
            Content = $response.Content | ConvertFrom-Json -ErrorAction SilentlyContinue
            RawContent = $response.Content
        }
    }
    catch {
        Write-Host "   Failed: $($_.Exception.Message)" -ForegroundColor Red
        
        $statusCode = $null
        $content = $null
        
        if ($_.Exception -is [Microsoft.PowerShell.Commands.HttpResponseException]) {
            $statusCode = $_.Exception.Response.StatusCode.value__
            try {
                $content = $_.Exception.Response.Content | ConvertFrom-Json -ErrorAction SilentlyContinue
            } catch {
                $content = $_.Exception.Response.Content
            }
        }
        
        return @{
            Success = $false
            StatusCode = $statusCode
            Content = $content
            Error = $_.Exception.Message
        }
    }
}

# Server Health Check
Write-Host "`nSERVER HEALTH CHECK" -ForegroundColor Cyan
Write-Host "====================" -ForegroundColor Cyan

$healthResult = Invoke-TestRequest -Method "GET" -Uri "$BASE_URL/api/health" -TestName "Server Health Check"
if (-not ($healthResult.Success -and $healthResult.StatusCode -eq 200)) {
    Write-Host "SERVER NOT ACCESSIBLE" -ForegroundColor Red
    Write-Host "`nTo start the server:" -ForegroundColor Yellow
    Write-Host "1. Open a new terminal" -ForegroundColor White
    Write-Host "2. Navigate to backend directory" -ForegroundColor White
    Write-Host "3. Run: npm run dev" -ForegroundColor White
    exit 1
}

# Setup Authentication for Tests
Write-Host "`nAUTHENTICATION SETUP" -ForegroundColor Cyan
Write-Host "====================" -ForegroundColor Cyan

# Register and login organizer
$organizerData = @{
    email = "uat.organizer@test.com"
    password = "password123"
    role = "organizer"
}

$regOrgResult = Invoke-TestRequest -Method "POST" -Uri "$BASE_URL/api/auth/register" -Body $organizerData -TestName "Register Organizer"
$organizerLogin = @{
    email = "uat.organizer@test.com"
    password = "password123"
}

$loginOrgResult = Invoke-TestRequest -Method "POST" -Uri "$BASE_URL/api/auth/login" -Body $organizerLogin -TestName "Organizer Login"
if ($loginOrgResult.Success -and $loginOrgResult.Content.token) {
    $organizerToken = $loginOrgResult.Content.token
    Write-Host "   Organizer Token: $($organizerToken.Substring(0,20))..." -ForegroundColor Blue
}

# Register and login player
$playerData = @{
    email = "uat.player@test.com"
    password = "password123"
    role = "player"
}

$regPlayerResult = Invoke-TestRequest -Method "POST" -Uri "$BASE_URL/api/auth/register" -Body $playerData -TestName "Register Player"
$playerLogin = @{
    email = "uat.player@test.com"
    password = "password123"
}

$loginPlayerResult = Invoke-TestRequest -Method "POST" -Uri "$BASE_URL/api/auth/login" -Body $playerLogin -TestName "Player Login"
if ($loginPlayerResult.Success -and $loginPlayerResult.Content.token) {
    $playerToken = $loginPlayerResult.Content.token
    Write-Host "   Player Token: $($playerToken.Substring(0,20))..." -ForegroundColor Blue
}

# Create test event for subsequent tests
if ($organizerToken) {
    $eventData = @{
        title = "UAT Test Tournament"
        description = "Tournament for focused UAT testing"
        game = "CS:GO"
        start_time = "2024-12-15T10:00:00Z"
        end_time = "2024-12-15T18:00:00Z"
        bracket_type = "single_elimination"
        max_teams = 8
    }
    
    $createEventResult = Invoke-TestRequest -Method "POST" -Uri "$BASE_URL/api/events" -Headers @{"Authorization" = "Bearer $organizerToken"} -Body $eventData -TestName "Create Test Event"
    if ($createEventResult.Success -and $createEventResult.Content.event.id) {
        $createdEventId = $createEventResult.Content.event.id
        Write-Host "   Test Event ID: $createdEventId" -ForegroundColor Blue
    }
}

# Join event as player to create ticket for webhook tests
if ($playerToken -and $createdEventId) {
    $joinResult = Invoke-TestRequest -Method "POST" -Uri "$BASE_URL/api/events/$createdEventId/join" -Headers @{"Authorization" = "Bearer $playerToken"} -TestName "Player Join Event"
}

# MODULE 1: WEBHOOK TESTING (PAYMENT FLOW)
Write-Host "`nMODULE 1: WEBHOOK TESTING (Payment Flow)" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Test 1: Valid Payment Webhook
$webhookData = @{
    external_payment_ref = "pending_$($createdEventId)_uat_player"
    status = "completed"
    webhook_secret = "test-webhook-secret-key"
}

$webhookResult = Invoke-TestRequest -Method "POST" -Uri "$BASE_URL/api/webhooks/payment" -Body $webhookData -TestName "Valid Payment Webhook"
$testResults.Webhooks += @{
    Test = "Valid Payment Webhook Processing"
    Expected = "200 OK with ticket status update"
    Actual = "Status: $($webhookResult.StatusCode)"
    Pass = ($webhookResult.Success -and $webhookResult.StatusCode -eq 200)
    Details = if ($webhookResult.Content) { $webhookResult.Content } else { $webhookResult.Error }
}

# Test 2: Invalid Webhook Secret (Security Test)
$invalidWebhookData = @{
    external_payment_ref = "test_ref"
    status = "completed"
    webhook_secret = "invalid_secret"
}

$invalidWebhookResult = Invoke-TestRequest -Method "POST" -Uri "$BASE_URL/api/webhooks/payment" -Body $invalidWebhookData -TestName "Invalid Webhook Secret"
$testResults.Webhooks += @{
    Test = "Webhook Security (Invalid Secret)"
    Expected = "401 Unauthorized"
    Actual = "Status: $($invalidWebhookResult.StatusCode)"
    Pass = ($invalidWebhookResult.StatusCode -eq 401)
    Details = if ($invalidWebhookResult.Content) { $invalidWebhookResult.Content } else { $invalidWebhookResult.Error }
}

# Test 3: Failed Payment Webhook
$failedWebhookData = @{
    external_payment_ref = "pending_$($createdEventId)_uat_player"
    status = "failed"
    webhook_secret = "test-webhook-secret-key"
}

$failedWebhookResult = Invoke-TestRequest -Method "POST" -Uri "$BASE_URL/api/webhooks/payment" -Body $failedWebhookData -TestName "Failed Payment Webhook"
$testResults.Webhooks += @{
    Test = "Failed Payment Status Update"
    Expected = "200 OK with failed status"
    Actual = "Status: $($failedWebhookResult.StatusCode)"
    Pass = ($failedWebhookResult.Success -and $failedWebhookResult.StatusCode -eq 200)
    Details = if ($failedWebhookResult.Content) { $failedWebhookResult.Content } else { $failedWebhookResult.Error }
}

# MODULE 2: DASHBOARD TESTING (ORGANIZER OVERVIEW)
Write-Host "`nMODULE 2: DASHBOARD TESTING (Organizer Overview)" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

# Test 4: Organizer Dashboard Access
if ($organizerToken) {
    $dashboardResult = Invoke-TestRequest -Method "GET" -Uri "$BASE_URL/api/dashboard" -Headers @{"Authorization" = "Bearer $organizerToken"} -TestName "Organizer Dashboard Access"
    $testResults.Dashboard += @{
        Test = "Organizer Dashboard Access"
        Expected = "200 OK with dashboard data"
        Actual = "Status: $($dashboardResult.StatusCode)"
        Pass = ($dashboardResult.Success -and $dashboardResult.StatusCode -eq 200)
        Details = if ($dashboardResult.Content) { $dashboardResult.Content } else { $dashboardResult.Error }
    }
}

# Test 5: Dashboard Data Integrity
if ($organizerToken) {
    $dashboardDataResult = Invoke-TestRequest -Method "GET" -Uri "$BASE_URL/api/dashboard/stats" -Headers @{"Authorization" = "Bearer $organizerToken"} -TestName "Dashboard Statistics"
    $testResults.Dashboard += @{
        Test = "Dashboard Statistics Data"
        Expected = "200 OK with stats object"
        Actual = "Status: $($dashboardDataResult.StatusCode)"
        Pass = ($dashboardDataResult.Success -and $dashboardDataResult.StatusCode -eq 200)
        Details = if ($dashboardDataResult.Content) { $dashboardDataResult.Content } else { $dashboardDataResult.Error }
    }
}

# Test 6: Unauthorized Dashboard Access (Security Test)
if ($playerToken) {
    $unauthorizedDashResult = Invoke-TestRequest -Method "GET" -Uri "$BASE_URL/api/dashboard" -Headers @{"Authorization" = "Bearer $playerToken"} -TestName "Unauthorized Dashboard Access"
    $testResults.Dashboard += @{
        Test = "Dashboard Security (Player Access Denied)"
        Expected = "403 Forbidden"
        Actual = "Status: $($unauthorizedDashResult.StatusCode)"
        Pass = ($unauthorizedDashResult.StatusCode -eq 403)
        Details = if ($unauthorizedDashResult.Content) { $unauthorizedDashResult.Content } else { $unauthorizedDashResult.Error }
    }
}

# MODULE 3: BRACKET TESTING (MATCH GENERATION & RETRIEVAL)
Write-Host "`nMODULE 3: BRACKET TESTING (Match Generation & Retrieval)" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

# Test 7: Generate Tournament Matches
if ($organizerToken -and $createdEventId) {
    $generateMatchesResult = Invoke-TestRequest -Method "POST" -Uri "$BASE_URL/api/events/$createdEventId/matches" -Headers @{"Authorization" = "Bearer $organizerToken"} -TestName "Generate Tournament Matches"
    $testResults.Brackets += @{
        Test = "Match Generation"
        Expected = "201 Created with matches array"
        Actual = "Status: $($generateMatchesResult.StatusCode)"
        Pass = ($generateMatchesResult.Success -and $generateMatchesResult.StatusCode -eq 201)
        Details = if ($generateMatchesResult.Content) { $generateMatchesResult.Content } else { $generateMatchesResult.Error }
    }
}

# Test 8: Retrieve Event with Bracket Information
if ($createdEventId) {
    $eventBracketResult = Invoke-TestRequest -Method "GET" -Uri "$BASE_URL/api/events/$createdEventId/bracket" -TestName "Retrieve Event Bracket"
    $testResults.Brackets += @{
        Test = "Bracket Data Retrieval"
        Expected = "200 OK with bracket structure"
        Actual = "Status: $($eventBracketResult.StatusCode)"
        Pass = ($eventBracketResult.Success -and $eventBracketResult.StatusCode -eq 200)
        Details = if ($eventBracketResult.Content) { $eventBracketResult.Content } else { $eventBracketResult.Error }
    }
}

# Test 9: Match Details Retrieval
if ($organizerToken -and $createdEventId) {
    $matchesListResult = Invoke-TestRequest -Method "GET" -Uri "$BASE_URL/api/events/$createdEventId/matches" -Headers @{"Authorization" = "Bearer $organizerToken"} -TestName "List Event Matches"
    $testResults.Brackets += @{
        Test = "Match List Retrieval"
        Expected = "200 OK with matches array"
        Actual = "Status: $($matchesListResult.StatusCode)"
        Pass = ($matchesListResult.Success -and $matchesListResult.StatusCode -eq 200)
        Details = if ($matchesListResult.Content) { $matchesListResult.Content } else { $matchesListResult.Error }
    }
}

# Test 10: Bracket Type Validation
if ($organizerToken) {
    $invalidBracketEvent = @{
        title = "Invalid Bracket Test"
        description = "Testing invalid bracket type"
        game = "Valorant"
        start_time = "2024-12-20T10:00:00Z"
        end_time = "2024-12-20T18:00:00Z"
        bracket_type = "invalid_type"
        max_teams = 4
    }
    
    $invalidBracketResult = Invoke-TestRequest -Method "POST" -Uri "$BASE_URL/api/events" -Headers @{"Authorization" = "Bearer $organizerToken"} -Body $invalidBracketEvent -TestName "Invalid Bracket Type Validation"
    $testResults.Brackets += @{
        Test = "Bracket Type Validation"
        Expected = "400 Bad Request (validation error)"
        Actual = "Status: $($invalidBracketResult.StatusCode)"
        Pass = ($invalidBracketResult.StatusCode -eq 400)
        Details = if ($invalidBracketResult.Content) { $invalidBracketResult.Content } else { $invalidBracketResult.Error }
    }
}

# RESULTS SUMMARY AND CONFIDENCE SCORING
Write-Host "`nFOCUSED UAT RESULTS SUMMARY" -ForegroundColor Magenta
Write-Host "============================" -ForegroundColor Magenta

$moduleScores = @{}
$overallPassed = 0
$overallTotal = 0

foreach ($module in $testResults.Keys) {
    $tests = $testResults[$module]
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
    
    $status = if ($percentage -eq 100) { "[PASS]" } elseif ($percentage -ge 80) { "[WARN]" } else { "[FAIL]" }
    $color = if ($percentage -eq 100) { "Green" } elseif ($percentage -ge 80) { "Yellow" } else { "Red" }
    Write-Host "`n$status $module Module: $passed/$total tests passed ($percentage%)" -ForegroundColor $color
    
    # Show detailed results
    foreach ($test in $tests) {
        $testStatus = if ($test.Pass) { "[PASS]" } else { "[FAIL]" }
        $testColor = if ($test.Pass) { "Green" } else { "Red" }
        Write-Host "   $testStatus $($test.Test): $($test.Actual)" -ForegroundColor $testColor
        if (-not $test.Pass -and $test.Details) {
            Write-Host "      Details: $($test.Details)" -ForegroundColor Gray
        }
    }
}

# Calculate Overall Confidence Score
$overallPercentage = if ($overallTotal -gt 0) { [math]::Round(($overallPassed / $overallTotal) * 100, 1) } else { 0 }

Write-Host "`nUAT CONFIDENCE SCORE" -ForegroundColor Cyan
Write-Host "====================" -ForegroundColor Cyan
Write-Host "Module Breakdown:" -ForegroundColor White
Write-Host "   Webhooks (Payment Flow): $($moduleScores.Webhooks.Passed)/$($moduleScores.Webhooks.Total) ($($moduleScores.Webhooks.Percentage)%)" -ForegroundColor White
Write-Host "   Dashboard (Organizer Overview): $($moduleScores.Dashboard.Passed)/$($moduleScores.Dashboard.Total) ($($moduleScores.Dashboard.Percentage)%)" -ForegroundColor White
Write-Host "   Brackets (Match Generation & Retrieval): $($moduleScores.Brackets.Passed)/$($moduleScores.Brackets.Total) ($($moduleScores.Brackets.Percentage)%)" -ForegroundColor White

Write-Host "`nOVERALL UAT RESULTS:" -ForegroundColor Cyan
Write-Host "   Total Tests: $overallTotal" -ForegroundColor White
Write-Host "   Passed: $overallPassed" -ForegroundColor Green
Write-Host "   Failed: $($overallTotal - $overallPassed)" -ForegroundColor Red

$successColor = if ($overallPercentage -ge 90) { "Green" } elseif ($overallPercentage -ge 75) { "Yellow" } else { "Red" }
Write-Host "   Success Rate: $overallPercentage%" -ForegroundColor $successColor

# Confidence Rating
if ($overallPercentage -eq 100) {
    Write-Host "`nCONFIDENCE SCORE: EXCELLENT (100%)" -ForegroundColor Green
    Write-Host "   All critical UAT tests passed. Platform ready for deployment." -ForegroundColor Green
} elseif ($overallPercentage -ge 90) {
    Write-Host "`nCONFIDENCE SCORE: HIGH ($overallPercentage%)" -ForegroundColor Yellow
    Write-Host "   Minor issues detected. Review failed tests before deployment." -ForegroundColor Yellow
} elseif ($overallPercentage -ge 75) {
    Write-Host "`nCONFIDENCE SCORE: MODERATE ($overallPercentage%)" -ForegroundColor Yellow  
    Write-Host "   Several issues found. Address critical failures before deployment." -ForegroundColor Yellow
} elseif ($overallPercentage -ge 50) {
    Write-Host "`nCONFIDENCE SCORE: LOW ($overallPercentage%)" -ForegroundColor Red
    Write-Host "   Significant issues detected. Deployment not recommended." -ForegroundColor Red
} else {
    Write-Host "`nCONFIDENCE SCORE: CRITICAL ($overallPercentage%)" -ForegroundColor Red
    Write-Host "   Major failures detected. Immediate attention required." -ForegroundColor Red
}

Write-Host "`nFocused UAT Testing Complete!" -ForegroundColor Green
Write-Host "Test modules: Webhooks | Dashboard | Brackets" -ForegroundColor Blue

# Export results to file
$resultsSummary = @{
    TestDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    ModulesTested = @("Webhooks", "Dashboard", "Brackets")
    OverallScore = $overallPercentage
    ModuleScores = $moduleScores
    DetailedResults = $testResults
}

$resultsSummary | ConvertTo-Json -Depth 10 | Out-File "simple-uat-results.json" -Encoding UTF8
Write-Host "`nResults saved to: simple-uat-results.json" -ForegroundColor Blue