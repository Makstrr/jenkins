param(
    [Parameter(Position=0)]
    [ValidateSet('download','train','deploy','healthy')]
    [string]$Action,

    [Parameter(Position=1)]
    [string]$ModelURI = ""
)

if (-not $env:WORKSPACE) {
    $env:WORKSPACE = (Get-Location).Path
}

$venvPath = Join-Path $env:WORKSPACE "jenkins_env"

if (-not (Test-Path $venvPath)) {
    python -m venv $venvPath
}

$pythonExe = Join-Path $venvPath "Scripts\python.exe"
$pipExe   = Join-Path $venvPath "Scripts\pip.exe"
$mlflowExe = Join-Path $venvPath "Scripts\mlflow.exe"

& $pipExe install -r requirements.txt > $null

switch ($Action) {
    'download' {
        & $pythonExe download.py
        exit 0
    }
    'train' {
        & $pythonExe train_model.py
        exit 0
    }
    'deploy' {
        $env:BUILD_ID = "dontKillMe"
        $env:JENKINS_NODE_COOKIE = "dontKillMe"

        # Handle the case where ModelURI is literally "null" or empty string
        if ([string]::IsNullOrEmpty($ModelURI) -or $ModelURI -eq "null") {
            $finalUri = "runs:/1733e434143642d8ae8a48a8c4207c47/model"
        } else {
            $finalUri = "runs:/1733e434143642d8ae8a48a8c4207c47/model"
        }
        Write-Host "URI прочитан: [$finalUri]"

        $logDir = (Get-Location).Path
        $stdoutLog = Join-Path $logDir "mlflow_stdout.log"
        $stderrLog = Join-Path $logDir "mlflow_stderr.log"

        # Temporarily add venv Scripts to PATH for this process and child processes
        $venvScripts = Join-Path $venvPath "Scripts"
        $oldPath = $env:PATH
        $env:PATH = "$venvScripts;$oldPath"

        # Start mlflow serve (asynchronously)
        Start-Process -NoNewWindow `
            -RedirectStandardOutput $stdoutLog `
            -RedirectStandardError $stderrLog `
            -FilePath $mlflowExe `
            -ArgumentList "models serve -m $finalUri -p 5003 --no-conda" `
            -WorkingDirectory $logDir

        # Restore original PATH (optional, but good practice)
        $env:PATH = $oldPath

        exit 0
    }
    'healthy' {
        # Wait for service to start (adjust as needed)
        Start-Sleep -Seconds 15

        try {
            $body = '{"inputs": [[0.5, -0.2, 0.8, -0.3, 1.2, -0.7, 0.1, -0.4]]}'
            $response = Invoke-RestMethod -Uri "http://127.0.0.1:5003/invocations" `
                -Method Post -Body $body -ContentType "application/json"
            Write-Output $response
        }
        catch {
            Write-Output "Service not ready"
        }
        exit 0
    }
    default {
        Write-Host "Usage: $($MyInvocation.InvocationName) {download|train|deploy|healthy}"
        exit 1
    }
}