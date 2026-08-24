@echo off
chcp 65001 >nul
cd /d "%~dp0"
set DBT_PROFILES_DIR=%~dp0dbt

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
echo   STEG 2 av 2 - bygger datagrunnlaget
echo ============================================
echo.
echo [1/4] Henter data fra Folkehelseinstituttets apne API...
echo.
%PY% src\hent_npr.py
if errorlevel 1 goto :feil

echo.
echo [2/4] Henter dbt-pakker...
echo.
%PY% src\kjor_dbt.py deps
if errorlevel 1 goto :feil

echo.
echo [3/4] Bygger datamodellen og kjorer alle 51 tester...
echo.
%PY% src\kjor_dbt.py build --full-refresh
if errorlevel 1 goto :feil

echo.
echo [4/4] Eksporterer tabeller til Power BI...
echo.
%PY% src\eksporter_mart.py
if errorlevel 1 goto :feil

echo.
echo ============================================
echo   FERDIG MED DEL 1 AV DATAGRUNNLAGET
echo ============================================
echo.
echo Tabellene ligger na i mappa  data\mart\
echo.
echo bro_enhet_rls.csv skal vaere tom na. Det er riktig -
echo den fylles nar NKI-eksporten er lastet ned.
echo.
echo Neste steg: les  powerbi\NKI_EKSPORT.md
echo.
pause
exit /b 0

:feil
cd /d "%~dp0"
echo.
echo ============================================
echo   NOE GIKK GALT
echo ============================================
echo.
echo Bla opp i vinduet og finn den FORSTE linjen som sier ERROR eller FEIL.
echo Kopier den linjen - resten er folgefeil.
echo.
pause
exit /b 1
