#!/usr/bin/env pwsh

Write-Host "🚀 Starting Comprehensive UAT Testing Suite" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green

$BASE_URL = "http://localhost:5000"
$results = @{}

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
        Write-Host "`n🔍 Testing: $TestName" -ForegroundColor Yellow
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
        
        Write-Host "   ✅ Status: $($response.StatusCode)" -ForegroundColor Green
        Write-Host "   📄 Response: $($response.Content)"
        
        return @{
            Success = $true
            StatusCode = $response.StatusCode
            Content = $response.Content | ConvertFrom-Json -ErrorAction SilentlyContinue
            RawContent = $response.Content
        }
    }
    catch {
        Write-Host "   ❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
        
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

# Test Results Storage
$testResults = @{
    Auth = @()
    Events = @()
    Tickets = @()
    Webhooks = @()
    Dashboard = @()
    Brackets = @()
}

# Global Variables for Test Data
$organizerToken = $null
$playerToken = $null
$createdEventId = $null

Write-Host "`n📋 MODULE 1: SERVER HEALTH CHECK" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan

$healthResult = Invoke-TestRequest -Method "GET" -Uri "$BASE_URL/api/health" -TestName "Server Health Check"
if ($healthResult.Success -and $healthResult.StatusCode -eq 200) {
    Write-Host "✅ SERVER HEALTH: PASS" -ForegroundColor Green
} else {
    Write-Host "❌ SERVER HEALTH: FAIL - Server not accessible" -ForegroundColor Red
    exit 1
}

Write-Host "`n📋 MODULE 2: AUTHENTICATION TESTING" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan

# Test 1: Register Organizer
$organizerData = @{
    email = "organizer@test.com"
    password = "password123"
    role = "organizer"
}

$regOrgResult = Invoke-TestRequest -Method "POST" -Uri "$BASE_URL/api/auth/register" -Body $organizerData -TestName "Register Organizer User"
$testResults.Auth += @{
    Test = "Register Organizer"
    Expected = "201 Created with JWT token"
    Actual = "Status: $($regOrgResult.StatusCode)"
    Pass = ($regOrgResult.Success -and $regOrgResult.StatusCode -eq 201)
}

# Test 2: Register Player
$playerData = @{
    email = "player@test.com"
    password = "password123"
    role = "player"
}

$regPlayerResult = Invoke-TestRequest -Method "POST" -Uri "$BASE_URL/api/auth/register" -Body $playerData -TestName "Register Player User"
$testResults.Auth += @{
    Test = "Register Player"
    Expected = "201 Created with JWT token"
    Actual = "Status: $($regPlayerResult.StatusCode)"
    Pass = ($regPlayerResult.Success -and $regPlayerResult.StatusCode -eq 201)
}

# Test 3: Login Organizer
$organizerLogin = @{
    email = "organizer@test.com"
    password = "password123"
}

$loginOrgResult = Invoke-TestRequest -Method "POST" -Uri "$BASE_URL/api/auth/login" -Body $organizerLogin -TestName "Organizer Login"
if ($loginOrgResult.Success -and $loginOrgResult.Content.token) {
    $organizerToken = $loginOrgResult.Content.token
    Write-Host "   🔑 Organizer Token: $($organizerToken.Substring(0,20))..." -ForegroundColor Blue
}
$testResults.Auth += @{
    Test = "Organizer Login"
    Expected = "200 OK with JWT token"
    Actual = "Status: $($loginOrgResult.StatusCode), Token: $($loginOrgResult.Content.token -ne $null)"
    Pass = ($loginOrgResult.Success -and $loginOrgResult.StatusCode -eq 200 -and $organizerToken)
}

# Test 4: Login Player
$playerLogin = @{
    email = "player@test.com"
    password = "password123"
}

$loginPlayerResult = Invoke-TestRequest -Method "POST" -Uri "$BASE_URL/api/auth/login" -Body $playerLogin -TestName "Player Login"
if ($loginPlayerResult.Success -and $loginPlayerResult.Content.token) {
    $playerToken = $loginPlayerResult.Content.token
    Write-Host "   🔑 Player Token: $($playerToken.Substring(0,20))..." -ForegroundColor Blue
}
$testResults.Auth += @{
    Test = "Player Login"
    Expected = "200 OK with JWT token"
    Actual = "Status: $($loginPlayerResult.StatusCode), Token: $($loginPlayerResult.Content.token -ne $null)"
    Pass = ($loginPlayerResult.Success -and $loginPlayerResult.StatusCode -eq 200 -and $playerToken)
}

# Test 5: Get Profile (Organizer)
if ($organizerToken) {
    $profileResult = Invoke-TestRequest -Method "GET" -Uri "$BASE_URL/api/auth/profile" -Headers @{"Authorization" = "Bearer $organizerToken"} -TestName "Get Organizer Profile"
    $testResults.Auth += @{
        Test = "Get Organizer Profile"
        Expected = "200 OK with user profile"
        Actual = "Status: $($profileResult.StatusCode)"
        Pass = ($profileResult.Success -and $profileResult.StatusCode -eq 200)
    }
}

Write-Host "`n📋 MODULE 3: EVENTS TESTING" -ForegroundColor Cyan
Write-Host "============================" -ForegroundColor Cyan

# Test 6: List Events (Public)
$listEventsResult = Invoke-TestRequest -Method "GET" -Uri "$BASE_URL/api/events" -TestName "List Events (Public)"
$testResults.Events += @{
    Test = "List Events (Public)"
    Expected = "200 OK with events array"
    Actual = "Status: $($listEventsResult.StatusCode)"
    Pass = ($listEventsResult.Success -and $listEventsResult.StatusCode -eq 200)
}

# Test 7: Create Event (Organizer Only)
if ($organizerToken) {
    $eventData = @{
        title = "CS:GO Championship 2024"
        description = "Professional esports tournament for UAT testing"
        game = "Counter-Strike: Global Offensive"
        start_time = "2024-12-01T10:00:00Z"
        end_time = "2024-12-01T20:00:00Z"
        bracket_type = "single_elimination"
        max_teams = 16
    }
    
    $createEventResult = Invoke-TestRequest -Method "POST" -Uri "$BASE_URL/api/events" -Headers @{"Authorization" = "Bearer $organizerToken"} -Body $eventData -TestName "Create Event (Organizer)"
    if ($createEventResult.Success -and $createEventResult.Content.event.id) {
        $createdEventId = $createEventResult.Content.event.id
        Write-Host "   🎯 Created Event ID: $createdEventId" -ForegroundColor Blue
    }
    $testResults.Events += @{
        Test = "Create Event (Organizer)"
        Expected = "201 Created with event object"
        Actual = "Status: $($createEventResult.StatusCode), Event ID: $createdEventId"
        Pass = ($createEventResult.Success -and $createEventResult.StatusCode -eq 201 -and $createdEventId)
    }
}

# Test 8: Join Event (Player)
if ($playerToken -and $createdEventId) {
    $joinEventResult = Invoke-TestRequest -Method "POST" -Uri "$BASE_URL/api/events/$createdEventId/join" -Headers @{"Authorization" = "Bearer $playerToken"} -TestName "Player Join Event"
    $testResults.Events += @{
        Test = "Player Join Event"
        Expected = "200 OK with ticket creation"
        Actual = "Status: $($joinEventResult.StatusCode)"
        Pass = ($joinEventResult.Success -and $joinEventResult.StatusCode -eq 200)
    }
}

# Test 9: Unauthorized Event Creation (Player tries to create event)
if ($playerToken) {
    $unauthorizedResult = Invoke-TestRequest -Method "POST" -Uri "$BASE_URL/api/events" -Headers @{"Authorization" = "Bearer $playerToken"} -Body $eventData -TestName "Unauthorized Event Creation (Player)"
    $testResults.Events += @{
        Test = "Unauthorized Event Creation (Security)"
        Expected = "403 Forbidden"
        Actual = "Status: $($unauthorizedResult.StatusCode)"
        Pass = ($unauthorizedResult.StatusCode -eq 403)
    }
}

Write-Host "`n📋 MODULE 4: WEBHOOK TESTING" -ForegroundColor Cyan
Write-Host "=============================" -ForegroundColor Cyan

# Test 10: Payment Webhook
$webhookData = @{
    external_payment_ref = "pending_123_player_test"
    status = "completed"
    webhook_secret = "test-webhook-secret-key"
}

$webhookResult = Invoke-TestRequest -Method "POST" -Uri "$BASE_URL/api/webhooks/payment" -Body $webhookData -TestName "Payment Webhook Simulation"
$testResults.Webhooks += @{
    Test = "Payment Webhook"
    Expected = "200 OK with ticket status update"
    Actual = "Status: $($webhookResult.StatusCode)"
    Pass = ($webhookResult.Success -and $webhookResult.StatusCode -eq 200)
}

# Test 11: Invalid Webhook Secret
$invalidWebhookData = @{
    external_payment_ref = "test_ref"
    status = "completed"
    webhook_secret = "wrong_secret"
}

$invalidWebhookResult = Invoke-TestRequest -Method "POST" -Uri "$BASE_URL/api/webhooks/payment" -Body $invalidWebhookData -TestName "Invalid Webhook Secret (Security)"
$testResults.Webhooks += @{
    Test = "Invalid Webhook Secret (Security)"
    Expected = "401 Unauthorized"
    Actual = "Status: $($invalidWebhookResult.StatusCode)"
    Pass = ($invalidWebhookResult.StatusCode -eq 401)
}

Write-Host "`n📋 MODULE 5: TICKETS TESTING" -ForegroundColor Cyan
Write-Host "=============================" -ForegroundColor Cyan

# Test 12: List User Tickets
if ($playerToken) {
    $ticketsResult = Invoke-TestRequest -Method "GET" -Uri "$BASE_URL/api/tickets" -Headers @{"Authorization" = "Bearer $playerToken"} -TestName "List Player Tickets"
    $testResults.Tickets += @{
        Test = "List Player Tickets"
        Expected = "200 OK with tickets array"
        Actual = "Status: $($ticketsResult.StatusCode)"
        Pass = ($ticketsResult.Success -and $ticketsResult.StatusCode -eq 200)
    }
}

Write-Host "`n📋 MODULE 6: DASHBOARD TESTING" -ForegroundColor Cyan
Write-Host "===============================" -ForegroundColor Cyan

# Test 13: Dashboard Endpoint
if ($organizerToken) {
    $dashboardResult = Invoke-TestRequest -Method "GET" -Uri "$BASE_URL/api/dashboard" -Headers @{"Authorization" = "Bearer $organizerToken"} -TestName "Organizer Dashboard"
    $testResults.Dashboard += @{
        Test = "Organizer Dashboard"
        Expected = "200 OK with dashboard data"
        Actual = "Status: $($dashboardResult.StatusCode)"
        Pass = ($dashboardResult.Success -and $dashboardResult.StatusCode -eq 200)
    }
}

Write-Host "`n📋 MODULE 7: BRACKET TESTING" -ForegroundColor Cyan
Write-Host "=============================" -ForegroundColor Cyan

# Test 14: Generate Matches/Brackets
if ($organizerToken -and $createdEventId) {
    $matchesResult = Invoke-TestRequest -Method "POST" -Uri "$BASE_URL/api/events/$createdEventId/matches" -Headers @{"Authorization" = "Bearer $organizerToken"} -TestName "Generate Event Matches"
    $testResults.Brackets += @{
        Test = "Generate Event Matches"
        Expected = "201 Created with matches"
        Actual = "Status: $($matchesResult.StatusCode)"
        Pass = ($matchesResult.Success -and $matchesResult.StatusCode -eq 201)
    }
}

# Test 15: Get Event with Bracket Info
if ($createdEventId) {
    $eventWithBracketResult = Invoke-TestRequest -Method "GET" -Uri "$BASE_URL/api/events/$createdEventId" -TestName "Get Event with Bracket Info"
    $testResults.Brackets += @{
        Test = "Get Event with Bracket Info"
        Expected = "200 OK with event and bracket data"
        Actual = "Status: $($eventWithBracketResult.StatusCode)"
        Pass = ($eventWithBracketResult.Success -and $eventWithBracketResult.StatusCode -eq 200)
    }
}

Write-Host "`n📊 COMPREHENSIVE UAT RESULTS SUMMARY" -ForegroundColor Magenta
Write-Host "======================================" -ForegroundColor Magenta

# Calculate module success rates
$moduleResults = @{}
foreach ($module in $testResults.Keys) {
    $tests = $testResults[$module]
    $passed = ($tests | Where-Object { $_.Pass -eq $true }).Count
    $total = $tests.Count
    $percentage = if ($total -gt 0) { [math]::Round(($passed / $total) * 100, 1) } else { 0 }
    
    $moduleResults[$module] = @{
        Passed = $passed
        Total = $total
        Percentage = $percentage
    }
    
    $status = if ($percentage -eq 100) { "✅" } elseif ($percentage -ge 75) { "⚠️" } else { "❌" }
    Write-Host "$status $module Module: $passed/$total tests passed ($percentage%)" -ForegroundColor $(if ($percentage -eq 100) { "Green" } elseif ($percentage -ge 75) { "Yellow" } else { "Red" })
    
    # Show failed tests
    $failedTests = $tests | Where-Object { $_.Pass -eq $false }
    foreach ($test in $failedTests) {
        Write-Host "   ❌ $($test.Test): Expected $($test.Expected), Got $($test.Actual)" -ForegroundColor Red
    }
}

# Overall summary
$totalPassed = ($testResults.Values | ForEach-Object { $_ } | Where-Object { $_.Pass -eq $true }).Count
$totalTests = ($testResults.Values | ForEach-Object { $_ }).Count
$overallPercentage = if ($totalTests -gt 0) { [math]::Round(($totalPassed / $totalTests) * 100, 1) } else { 0 }

Write-Host "`n🎯 OVERALL UAT RESULTS:" -ForegroundColor Cyan
Write-Host "   Total Tests: $totalTests" -ForegroundColor White
Write-Host "   Passed: $totalPassed" -ForegroundColor Green
Write-Host "   Failed: $($totalTests - $totalPassed)" -ForegroundColor Red
Write-Host "   Success Rate: $overallPercentage%" -ForegroundColor $(if ($overallPercentage -ge 90) { "Green" } elseif ($overallPercentage -ge 75) { "Yellow" } else { "Red" })

if ($overallPercentage -eq 100) {
    Write-Host "`n🏆 ALL TESTS PASSED! Platform ready for production." -ForegroundColor Green
} elseif ($overallPercentage -ge 90) {
    Write-Host "`n✨ EXCELLENT! Minor issues to address." -ForegroundColor Yellow
} elseif ($overallPercentage -ge 75) {
    Write-Host "`n⚠️  GOOD with some improvements needed." -ForegroundColor Yellow  
} else {
    Write-Host "`n🔧 NEEDS ATTENTION - Multiple issues found." -ForegroundColor Red
}

Write-Host "`n📄 UAT Testing Complete!" -ForegroundColor Green