@echo off
chcp 65001 >nul
cd /d "%~dp0"

set "PY="
if exist .python_kommando set /p PY=<.python_kommando
if not defined PY (
    python -c "print(1)" >nul 2>&1
    if not errorlevel 1 set "PY=python"
)
if not defined PY (
    py -c "print(1)" >nul 2>&1
    if not errorlevel 1 set "PY=py"
)
if not defined PY (
    echo FEIL: Finner ingen Python. Kjor 1_INSTALLER.bat forst.
    pause
    exit /b 1
)

echo.
echo ============================================
echo   Legger NKI-dataene inn i modellen
echo ============================================
echo.
echo [1/3] Finner og validerer eksporten...

%PY% src\finn_nki.py
if errorlevel 1 (
    pause
    exit /b 1
)

echo [2/3] Bygger datamodellen pa nytt...
echo.
%PY% src\kjor_dbt.py build --full-refresh
if errorlevel 1 (
    echo.
    echo Bygget feilet. Bla opp og finn den forste ERROR-linjen.
    pause
    exit /b 1
)

echo.
echo [3/3] Eksporterer til Power BI og kontrollerer...
echo.
%PY% src\eksporter_mart.py

%PY% src\sjekk_modell.py
if errorlevel 2 (
    echo.
    echo Modellen virker, men mangler foretaksniva. Les meldingen over.
    pause
    exit /b 0
)
if errorlevel 1 (
    pause
    exit /b 1
)

echo.
pause
