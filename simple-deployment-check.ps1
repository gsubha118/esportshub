#!/usr/bin/env pwsh

Write-Host "DEPLOYMENT HEALTH CHECK" -ForegroundColor Green
Write-Host "======================" -ForegroundColor Green

$BASE_URL = "http://localhost:5000"
$START_TIME = Get-Date

# Test Results
$results = @{
    ServerHealth = $null
    EndpointStatus = @()
    PerformanceMetrics = @{}
    TotalPassed = 0
    TotalTests = 0
}

function Test-Endpoint {
    param(
        [string]$Method = "GET",
        [string]$Endpoint,
        [string]$TestName,
        [hashtable]$Headers = @{},
        [object]$Body = $null,
        [int]$ExpectedStatus = 200
    )
    
    $uri = "$BASE_URL$Endpoint"
    $startTime = Get-Date
    
    try {
        Write-Host "Testing: $TestName" -ForegroundColor Yellow
        Write-Host "  $Method $uri"
        
        $params = @{
            Uri = $uri
            Method = $Method
            Headers = $Headers
            TimeoutSec = 5
        }
        
        if ($Body) {
            $params.Body = ($Body | ConvertTo-Json)
            $params.ContentType = "application/json"
        }
        
        $response = Invoke-WebRequest @params
        $latency = ((Get-Date) - $startTime).TotalMilliseconds
        
        $passed = $response.StatusCode -eq $ExpectedStatus
        $results.TotalTests++
        if ($passed) { $results.TotalPassed++ }
        
        Write-Host "  Status: $($response.StatusCode) | Latency: $([math]::Round($latency, 2))ms" -ForegroundColor $(if ($passed) { "Green" } else { "Red" })
        
        $results.EndpointStatus += @{
            Test = $TestName
            Endpoint = $Endpoint
            Method = $Method
            ExpectedStatus = $ExpectedStatus
            ActualStatus = $response.StatusCode
            Latency = $latency
            Pass = $passed
        }
        
        return @{
            Success = $true
            StatusCode = $response.StatusCode
            Latency = $latency
            Content = $response.Content
        }
    }
    catch {
        $latency = ((Get-Date) - $startTime).TotalMilliseconds
        $results.TotalTests++
        
        # Extract status code from error if available
        $actualStatus = if ($_.Exception -match "(\d{3})") { [int]$matches[1] } else { 0 }
        $passed = $actualStatus -eq $ExpectedStatus
        
        if ($passed) { $results.TotalPassed++ }
        
        Write-Host "  Status: $actualStatus | Error: $($_.Exception.Message)" -ForegroundColor $(if ($passed) { "Green" } else { "Red" })
        
        $results.EndpointStatus += @{
            Test = $TestName
            Endpoint = $Endpoint
            Method = $Method
            ExpectedStatus = $ExpectedStatus
            ActualStatus = $actualStatus
            Latency = $latency
            Pass = $passed
            Error = $_.Exception.Message
        }
        
        return @{
            Success = $false
            StatusCode = $actualStatus
            Error = $_.Exception.Message
            Latency = $latency
        }
    }
}

Write-Host "`nTesting Core Endpoints..." -ForegroundColor Cyan

# 1. Health Check
$healthResult = Test-Endpoint -Method "GET" -Endpoint "/api/health" -TestName "Server Health"
$results.ServerHealth = $healthResult.Success

# 2. CORS Test - Options request
Test-Endpoint -Method "OPTIONS" -Endpoint "/api/events" -TestName "CORS Preflight"

# 3. Public Endpoints (should work without auth)
Test-Endpoint -Method "GET" -Endpoint "/api/events" -TestName "List Events"

# 4. Protected Endpoints (should return 401 without auth)
Test-Endpoint -Method "GET" -Endpoint "/api/dashboard" -TestName "Dashboard (No Auth)" -ExpectedStatus 401
Test-Endpoint -Method "GET" -Endpoint "/api/tickets" -TestName "Tickets (No Auth)" -ExpectedStatus 401

# 5. Invalid Endpoints (should return 404)
Test-Endpoint -Method "GET" -Endpoint "/api/nonexistent" -TestName "Invalid Endpoint" -ExpectedStatus 404

# 6. Webhook Test (should return 401 without proper secret)
$webhookData = @{ test = "data" }
Test-Endpoint -Method "POST" -Endpoint "/api/webhooks/payment" -TestName "Webhook Security" -Body $webhookData -ExpectedStatus 401

Write-Host "`nPerformance Analysis..." -ForegroundColor Cyan

$totalLatency = ($results.EndpointStatus | Measure-Object -Property Latency -Sum).Sum
$avgLatency = if ($results.TotalTests -gt 0) { [math]::Round($totalLatency / $results.TotalTests, 2) } else { 0 }
$maxLatency = ($results.EndpointStatus | Measure-Object -Property Latency -Maximum).Maximum
$testDuration = ((Get-Date) - $START_TIME).TotalSeconds

$results.PerformanceMetrics = @{
    AverageLatency = $avgLatency
    MaxLatency = $maxLatency
    TestDuration = $testDuration
    TotalRequests = $results.TotalTests
}

Write-Host "  Average Latency: ${avgLatency}ms" -ForegroundColor White
Write-Host "  Max Latency: ${maxLatency}ms" -ForegroundColor White
Write-Host "  Test Duration: $([math]::Round($testDuration, 2))s" -ForegroundColor White

# Performance Grade
$performanceGrade = if ($avgLatency -lt 50) { "EXCELLENT" } 
                   elseif ($avgLatency -lt 200) { "GOOD" } 
                   elseif ($avgLatency -lt 1000) { "ACCEPTABLE" } 
                   else { "POOR" }

Write-Host "  Performance Grade: $performanceGrade" -ForegroundColor White

Write-Host "`nDeployment Health Report" -ForegroundColor Magenta
Write-Host "========================" -ForegroundColor Magenta

$successRate = if ($results.TotalTests -gt 0) { [math]::Round(($results.TotalPassed / $results.TotalTests) * 100, 1) } else { 0 }

Write-Host "Server Health: $(if ($results.ServerHealth) { 'OK' } else { 'FAILED' })" -ForegroundColor $(if ($results.ServerHealth) { "Green" } else { "Red" })
Write-Host "Test Success Rate: $successRate% ($($results.TotalPassed)/$($results.TotalTests) tests)" -ForegroundColor White
Write-Host "Performance: $performanceGrade (${avgLatency}ms avg)" -ForegroundColor White

# Environment Check (without loading from process)
Write-Host "`nEnvironment Check:" -ForegroundColor Cyan
$envFile = Join-Path $PWD "backend\.env"
if (Test-Path $envFile) {
    Write-Host "  .env file: FOUND" -ForegroundColor Green
    $envContent = Get-Content $envFile
    $envCount = ($envContent | Where-Object { $_ -and $_ -notlike "#*" }).Count
    Write-Host "  Environment variables: $envCount defined" -ForegroundColor White
} else {
    Write-Host "  .env file: MISSING" -ForegroundColor Red
}

# SSL Check
$sslStatus = if ($BASE_URL -like "https://*") { "ENABLED" } else { "HTTP ONLY (Development)" }
Write-Host "SSL Status: $sslStatus" -ForegroundColor $(if ($BASE_URL -like "https://*") { "Green" } else { "Yellow" })

# Calculate Deployment Confidence
$confidence = 0
if ($results.ServerHealth) { $confidence += 30 }
$confidence += ($successRate * 0.4)
if ($avgLatency -lt 500) { $confidence += 20 }
if (Test-Path $envFile) { $confidence += 10 }

$confidenceGrade = if ($confidence -ge 80) { "HIGH" } 
                  elseif ($confidence -ge 60) { "MODERATE" } 
                  else { "LOW" }

Write-Host "`nDeployment Confidence: $([math]::Round($confidence, 1))% - $confidenceGrade" -ForegroundColor $(
    if ($confidence -ge 80) { "Green" } 
    elseif ($confidence -ge 60) { "Yellow" } 
    else { "Red" }
)

# Export Results
$fullReport = @{
    TestDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    ServerHealth = $results.ServerHealth
    SuccessRate = $successRate
    TestsPassed = $results.TotalPassed
    TotalTests = $results.TotalTests
    PerformanceGrade = $performanceGrade
    PerformanceMetrics = $results.PerformanceMetrics
    DeploymentConfidence = [math]::Round($confidence, 1)
    ConfidenceGrade = $confidenceGrade
    EndpointResults = $results.EndpointStatus
    Environment = @{
        BaseURL = $BASE_URL
        SSLEnabled = $BASE_URL -like "https://*"
        EnvFileExists = Test-Path $envFile
    }
}

$fullReport | ConvertTo-Json -Depth 5 | Out-File "deployment-status.json" -Encoding UTF8

Write-Host "`nFailed Tests:" -ForegroundColor Red
$failedTests = $results.EndpointStatus | Where-Object { -not $_.Pass }
foreach ($test in $failedTests) {
    Write-Host "  $($test.Test): Expected $($test.ExpectedStatus), got $($test.ActualStatus)" -ForegroundColor Red
    if ($test.Error) {
        Write-Host "    Error: $($test.Error)" -ForegroundColor Gray
    }
}

Write-Host "`nReport saved to: deployment-status.json" -ForegroundColor Blue
Write-Host "DEPLOYMENT HEALTH CHECK COMPLETE!" -ForegroundColor Green

# Recommendations
Write-Host "`nRecommendations:" -ForegroundColor Yellow
if (-not $results.ServerHealth) {
    Write-Host "  - Server health check failed - verify backend is running" -ForegroundColor White
}
if ($successRate -lt 80) {
    Write-Host "  - Low success rate - investigate failing endpoints" -ForegroundColor White
}
if ($avgLatency -gt 500) {
    Write-Host "  - High latency detected - optimize API performance" -ForegroundColor White
}
if ($BASE_URL -like "http://*") {
    Write-Host "  - Enable HTTPS for production deployment" -ForegroundColor White
}
Write-Host "  - Restart server to load .env variables: cd backend && npm run dev" -ForegroundColor White