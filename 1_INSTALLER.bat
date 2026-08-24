@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo.
echo ============================================
echo   STEG 1 av 2 - installerer programpakker
echo ============================================
echo.

rem Finn ut hva Python heter pa denne maskinen.
rem Python Install Manager (nytt fra python.org) gir kommandoen "py".
rem Gammel installer og Microsoft Store gir "python".
rem Vi tester at kommandoen faktisk KJORER, ikke bare at den finnes -
rem Windows har en tom snarvei som heter python.exe og bare apner butikken.
set "PY="
python -c "print(1)" >nul 2>&1
if not errorlevel 1 set "PY=python"
if defined PY goto :funnet
py -c "print(1)" >nul 2>&1
if not errorlevel 1 set "PY=py"
if defined PY goto :funnet

echo FEIL: Finner ingen Python pa denne maskinen.
echo.
echo Slik installerer du:
echo   1. Ga til https://www.python.org/downloads/
echo   2. Last ned og kjor. Klikk "Install Python".
echo      (Det finnes ingen "Add to PATH"-avkryssing lenger - det er normalt.)
echo   3. Apne et nytt cmd-vindu og skriv:  py install 3.13
echo   4. Kjor denne fila pa nytt.
echo.
pause
exit /b 1

:funnet
echo Bruker kommandoen: %PY%
%PY% --version
echo.
echo Installerer pakker. Dette tar 1-3 minutter.
echo.
%PY% -m pip install --upgrade pip
%PY% -m pip install -r requirements.txt
if errorlevel 1 (
    echo.
    echo FEIL under installasjon. Kopier den forste linjen som sier ERROR.
    pause
    exit /b 1
)

rem Husk hvilken kommando som virket, sa de neste filene slipper a lete.
echo %PY%> .python_kommando

echo.
echo ============================================
echo   Ferdig. Kjor deretter 2_HENT_DATA.bat
echo ============================================
pause
