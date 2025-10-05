# FINAL DEPLOYMENT READINESS CHECK
param(
    [string]$Environment = "development",
    [switch]$SkipTests = $false,
    [switch]$Verbose = $false
)

Write-Host "🚀 FINAL DEPLOYMENT READINESS CHECK" -ForegroundColor Yellow
Write-Host "====================================" -ForegroundColor Yellow
Write-Host "Environment: $Environment" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date)" -ForegroundColor Gray

$results = @{
    Environment = $Environment
    Timestamp = Get-Date
    Passed = 0
    Failed = 0
    Warnings = 0
    Tests = @{}
    Summary = ""
    DeploymentReady = $false
    Confidence = 0
}

function Test-Step {
    param(
        [string]$Name,
        [scriptblock]$Test,
        [string]$Category = "General"
    )
    
    Write-Host "`n🔍 Testing: $Name" -ForegroundColor Cyan
    
    try {
        $result = & $Test
        if ($result.Success) {
            Write-Host "✅ PASS: $Name" -ForegroundColor Green
            if ($Verbose -and $result.Message) {
                Write-Host "   Details: $($result.Message)" -ForegroundColor Gray
            }
            $results.Passed++
            $results.Tests[$Name] = @{ Status = "PASS"; Message = $result.Message; Category = $Category }
        } else {
            Write-Host "❌ FAIL: $Name" -ForegroundColor Red
            Write-Host "   Error: $($result.Message)" -ForegroundColor Red
            $results.Failed++
            $results.Tests[$Name] = @{ Status = "FAIL"; Message = $result.Message; Category = $Category }
        }
    } catch {
        Write-Host "❌ FAIL: $Name" -ForegroundColor Red
        Write-Host "   Exception: $($_.Exception.Message)" -ForegroundColor Red
        $results.Failed++
        $results.Tests[$Name] = @{ Status = "FAIL"; Message = $_.Exception.Message; Category = $Category }
    }
}

function Test-Warning {
    param(
        [string]$Name,
        [scriptblock]$Test,
        [string]$Category = "General"
    )
    
    Write-Host "`n⚠️  Checking: $Name" -ForegroundColor Yellow
    
    try {
        $result = & $Test
        if ($result.Success) {
            Write-Host "✅ OK: $Name" -ForegroundColor Green
            $results.Tests[$Name] = @{ Status = "OK"; Message = $result.Message; Category = $Category }
        } else {
            Write-Host "⚠️  WARNING: $Name" -ForegroundColor Yellow
            Write-Host "   Warning: $($result.Message)" -ForegroundColor Yellow
            $results.Warnings++
            $results.Tests[$Name] = @{ Status = "WARNING"; Message = $result.Message; Category = $Category }
        }
    } catch {
        Write-Host "⚠️  WARNING: $Name" -ForegroundColor Yellow
        Write-Host "   Exception: $($_.Exception.Message)" -ForegroundColor Yellow
        $results.Warnings++
        $results.Tests[$Name] = @{ Status = "WARNING"; Message = $_.Exception.Message; Category = $Category }
    }
}

# 1. ENVIRONMENT CHECKS
Test-Step -Name "Environment File Exists" -Category "Environment" -Test {
    $envFile = if ($Environment -eq "production") { ".env.production" } else { ".env" }
    if (Test-Path $envFile) {
        @{ Success = $true; Message = "Environment file found: $envFile" }
    } else {
        @{ Success = $false; Message = "Environment file not found: $envFile" }
    }
}

Test-Step -Name "Required Environment Variables" -Category "Environment" -Test {
    $envFile = if ($Environment -eq "production") { ".env.production" } else { ".env" }
    if (-not (Test-Path $envFile)) {
        return @{ Success = $false; Message = "Environment file not found" }
    }
    
    $envContent = Get-Content $envFile -Raw
    $requiredVars = @(
        "DATABASE_URL",
        "JWT_SECRET",
        "NODE_ENV",
        "PORT"
    )
    
    $missing = @()
    foreach ($var in $requiredVars) {
        if ($envContent -notmatch "$var\s*=\s*.+") {
            $missing += $var
        }
    }
    
    if ($missing.Count -eq 0) {
        @{ Success = $true; Message = "All required environment variables present" }
    } else {
        @{ Success = $false; Message = "Missing environment variables: $($missing -join ', ')" }
    }
}

# 2. DEPENDENCY CHECKS
Test-Step -Name "Node Modules Installed" -Category "Dependencies" -Test {
    if (Test-Path "node_modules") {
        $packageCount = (Get-ChildItem "node_modules" -Directory).Count
        @{ Success = $true; Message = "$packageCount packages installed" }
    } else {
        @{ Success = $false; Message = "node_modules directory not found" }
    }
}

Test-Step -Name "TypeScript Dependencies" -Category "Dependencies" -Test {
    $packageJson = Get-Content "package.json" -Raw | ConvertFrom-Json
    $hasTsJest = $packageJson.devDependencies."ts-jest" -ne $null
    $hasTypescript = $packageJson.devDependencies.typescript -ne $null -or $packageJson.dependencies.typescript -ne $null
    
    if ($hasTsJest -and $hasTypescript) {
        @{ Success = $true; Message = "TypeScript and ts-jest configured" }
    } else {
        @{ Success = $false; Message = "Missing TypeScript dependencies (ts-jest: $hasTsJest, typescript: $hasTypescript)" }
    }
}

# 3. BUILD CHECKS
Test-Step -Name "TypeScript Compilation" -Category "Build" -Test {
    $compileResult = npm run build 2>&1
    if ($LASTEXITCODE -eq 0) {
        @{ Success = $true; Message = "TypeScript compilation successful" }
    } else {
        @{ Success = $false; Message = "TypeScript compilation failed: $compileResult" }
    }
}

# 4. TEST CHECKS (if not skipped)
if (-not $SkipTests) {
    Test-Step -Name "Jest Configuration" -Category "Testing" -Test {
        if (Test-Path "jest.config.json" -or Test-Path "jest.config.js") {
            @{ Success = $true; Message = "Jest configuration found" }
        } else {
            @{ Success = $false; Message = "Jest configuration not found" }
        }
    }
    
    Test-Warning -Name "Test Suite Execution" -Category "Testing" -Test {
        $testResult = npm test 2>&1
        if ($LASTEXITCODE -eq 0) {
            @{ Success = $true; Message = "All tests passed" }
        } else {
            @{ Success = $false; Message = "Some tests failed or test setup issues: $testResult" }
        }
    }
}

# 5. SERVER HEALTH CHECKS
Test-Step -Name "Server Start Check" -Category "Server" -Test {
    # Start server in background
    $serverProcess = Start-Process -FilePath "npm" -ArgumentList "run", "dev" -PassThru -WindowStyle Hidden -RedirectStandardOutput "server-output.log" -RedirectStandardError "server-error.log"
    Start-Sleep -Seconds 5
    
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:5000/api/health" -TimeoutSec 10
        Stop-Process -Id $serverProcess.Id -Force -ErrorAction SilentlyContinue
        @{ Success = $true; Message = "Server started and health endpoint responding" }
    } catch {
        Stop-Process -Id $serverProcess.Id -Force -ErrorAction SilentlyContinue
        @{ Success = $false; Message = "Server failed to start or health endpoint not responding: $($_.Exception.Message)" }
    } finally {
        Remove-Item "server-output.log" -ErrorAction SilentlyContinue
        Remove-Item "server-error.log" -ErrorAction SilentlyContinue
    }
}

# 6. SECURITY CHECKS
Test-Warning -Name "JWT Secret Strength" -Category "Security" -Test {
    $envFile = if ($Environment -eq "production") { ".env.production" } else { ".env" }
    if (Test-Path $envFile) {
        $envContent = Get-Content $envFile -Raw
        if ($envContent -match "JWT_SECRET\s*=\s*(.+)") {
            $jwtSecret = $matches[1].Trim()
            if ($jwtSecret.Length -ge 32) {
                @{ Success = $true; Message = "JWT secret appears to be strong (${$jwtSecret.Length} characters)" }
            } else {
                @{ Success = $false; Message = "JWT secret is too short (${$jwtSecret.Length} characters, should be 32+)" }
            }
        } else {
            @{ Success = $false; Message = "JWT_SECRET not found in environment file" }
        }
    } else {
        @{ Success = $false; Message = "Environment file not found" }
    }
}

# 7. PRODUCTION READINESS CHECKS
if ($Environment -eq "production") {
    Test-Step -Name "Production Environment Variables" -Category "Production" -Test {
        $envFile = ".env.production"
        if (-not (Test-Path $envFile)) {
            return @{ Success = $false; Message = "Production environment file not found" }
        }
        
        $envContent = Get-Content $envFile -Raw
        $prodVars = @(
            "STRIPE_SECRET_KEY",
            "SUPABASE_URL",
            "SUPABASE_ANON_KEY",
            "FRONTEND_URL"
        )
        
        $missing = @()
        foreach ($var in $prodVars) {
            if ($envContent -notmatch "$var\s*=\s*.+") {
                $missing += $var
            }
        }
        
        if ($missing.Count -eq 0) {
            @{ Success = $true; Message = "All production environment variables present" }
        } else {
            @{ Success = $false; Message = "Missing production environment variables: $($missing -join ', ')" }
        }
    }
    
    Test-Warning -Name "Production Security" -Category "Production" -Test {
        $envFile = ".env.production"
        if (Test-Path $envFile) {
            $envContent = Get-Content $envFile -Raw
            $issues = @()
            
            if ($envContent -match "NODE_ENV\s*=\s*development") {
                $issues += "NODE_ENV should be 'production'"
            }
            if ($envContent -match "DATABASE_URL.*localhost") {
                $issues += "DATABASE_URL appears to use localhost"
            }
            if ($envContent -match "sslmode=disable") {
                $issues += "SSL should be enabled for production database"
            }
            
            if ($issues.Count -eq 0) {
                @{ Success = $true; Message = "Production security settings look good" }
            } else {
                @{ Success = $false; Message = "Security issues: $($issues -join ', ')" }
            }
        } else {
            @{ Success = $false; Message = "Production environment file not found" }
        }
    }
}

# Calculate deployment confidence
$total = $results.Passed + $results.Failed + $results.Warnings
if ($total -gt 0) {
    $results.Confidence = [math]::Round((($results.Passed + ($results.Warnings * 0.5)) / $total) * 100, 1)
} else {
    $results.Confidence = 0
}

# Determine if ready for deployment
$results.DeploymentReady = ($results.Failed -eq 0) -and ($results.Confidence -ge 80)

# Generate summary
Write-Host "`n📊 DEPLOYMENT READINESS SUMMARY" -ForegroundColor Yellow
Write-Host "================================" -ForegroundColor Yellow
Write-Host "✅ Passed: $($results.Passed)" -ForegroundColor Green
Write-Host "❌ Failed: $($results.Failed)" -ForegroundColor Red
Write-Host "⚠️  Warnings: $($results.Warnings)" -ForegroundColor Yellow
Write-Host "🎯 Confidence: $($results.Confidence)%" -ForegroundColor Cyan

if ($results.DeploymentReady) {
    Write-Host "🚀 DEPLOYMENT STATUS: READY" -ForegroundColor Green -BackgroundColor Black
    $results.Summary = "Platform is ready for deployment"
} elseif ($results.Failed -eq 0) {
    Write-Host "⚠️  DEPLOYMENT STATUS: READY WITH WARNINGS" -ForegroundColor Yellow -BackgroundColor Black
    $results.Summary = "Platform is ready for deployment but has warnings that should be addressed"
} else {
    Write-Host "❌ DEPLOYMENT STATUS: NOT READY" -ForegroundColor Red -BackgroundColor Black
    $results.Summary = "Platform has critical issues that must be resolved before deployment"
}

# Show critical failures
if ($results.Failed -gt 0) {
    Write-Host "`n🔴 CRITICAL ISSUES TO RESOLVE:" -ForegroundColor Red
    $results.Tests.GetEnumerator() | Where-Object { $_.Value.Status -eq "FAIL" } | ForEach-Object {
        Write-Host "  • $($_.Key): $($_.Value.Message)" -ForegroundColor Red
    }
}

# Show warnings
if ($results.Warnings -gt 0) {
    Write-Host "`n⚠️  WARNINGS TO CONSIDER:" -ForegroundColor Yellow
    $results.Tests.GetEnumerator() | Where-Object { $_.Value.Status -eq "WARNING" } | ForEach-Object {
        Write-Host "  • $($_.Key): $($_.Value.Message)" -ForegroundColor Yellow
    }
}

# Save detailed report
$reportFile = "final-deployment-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
$results | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportFile -Encoding utf8
Write-Host "`n📄 Detailed report saved: $reportFile" -ForegroundColor Gray

# Next steps
Write-Host "`n📋 NEXT STEPS:" -ForegroundColor Cyan
if ($results.DeploymentReady) {
    Write-Host "1. Deploy to your chosen platform (Vercel, Railway, etc.)" -ForegroundColor White
    Write-Host "2. Update production environment variables" -ForegroundColor White
    Write-Host "3. Run post-deployment health checks" -ForegroundColor White
} else {
    Write-Host "1. Fix all critical issues listed above" -ForegroundColor White
    Write-Host "2. Run this script again: ./final-deployment-check.ps1" -ForegroundColor White
    Write-Host "3. Consider running: ./quick-fixes.ps1" -ForegroundColor White
}

exit $results.Failed