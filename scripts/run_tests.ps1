# Runs every self-check under tests/ headlessly.
# Usage: powershell -ExecutionPolicy Bypass -File scripts/run_tests.ps1
# Requires godot 4.7+ on PATH. Exit code 0 = all tests passed.

$ErrorActionPreference = "Stop"

$testFiles = Get-ChildItem -Path "tests" -Filter "*.gd" | Sort-Object Name
if ($testFiles.Count -eq 0) {
    Write-Host "No test scripts found under tests/"
    exit 1
}

$failed = 0
foreach ($test in $testFiles) {
    Write-Host "==> $($test.Name)"
    godot --headless --path . -s "res://tests/$($test.Name)"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAILED: $($test.Name) (exit $LASTEXITCODE)"
        $failed++
    }
}

if ($failed -eq 0) {
    Write-Host "ALL TESTS PASSED ($($testFiles.Count) scripts)"
    exit 0
} else {
    Write-Host "$failed of $($testFiles.Count) test script(s) FAILED"
    exit 1
}
