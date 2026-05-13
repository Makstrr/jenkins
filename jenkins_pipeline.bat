@echo off
setlocal

if "%WORKSPACE%"=="" set WORKSPACE=%CD%

if not exist "%WORKSPACE%\jenkins_env" (
    python -m venv "%WORKSPACE%\jenkins_env"
)
call "%WORKSPACE%\jenkins_env\Scripts\activate.bat"

cd /d "%WORKSPACE%\mlops\"
pip install -r requirements.txt > nul

if "%1"=="download" (
    python download.py
    exit /b 0
)

if "%1"=="train" (
    python train_model.py
    exit /b 0
)

if "%1"=="deploy" (
    set BUILD_ID=dontKillMe
    set JENKINS_NODE_COOKIE=dontKillMe
    set /p MODEL_URI=<best_model_uri.txt
    echo Starting MLflow server on port 5003...
    start /B cmd /c "set BUILD_ID=dontKillMe && set JENKINS_NODE_COOKIE=dontKillMe && mlflow models serve -m %MODEL_URI% -p 5003 --no-conda > mlflow.log 2>&1"
    exit /b 0
)

if "%1"=="healthy" (
    timeout /t 5 /nobreak > nul
    powershell -Command "try { $r = Invoke-RestMethod -Uri http://127.0.0.1:5003/invocations -Method POST -Body '{\"inputs\": [[0.5, -0.2, 0.8, -0.3, 1.2, -0.7, 0.1, -0.4]]}' -ContentType 'application/json'; Write-Output $r } catch { Write-Output 'Service not ready' }"
    exit /b 0
)

echo Usage: %0 {download|train|deploy|healthy}
exit /b 1