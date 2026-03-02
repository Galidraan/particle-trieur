@echo off
REM =============================================================================
REM ParticleTrieur — Build d'installateur Windows (.exe)
REM
REM Ce script produit un installateur Windows autonome contenant :
REM   - Le JRE 21 embarque (via jpackage)
REM   - Le fat JAR avec JavaFX
REM   - Un environnement Python portable avec miso + TensorFlow pre-installe
REM
REM Prerequis sur la machine de BUILD uniquement :
REM   - JDK 21 (Azul Zulu, Temurin, ou autre)
REM   - Maven 3.8+
REM   - WiX Toolset 3.x (https://wixtoolset.org/releases/)
REM   - curl (inclus dans Windows 10+)
REM   - ~5 Go d'espace disque libre
REM
REM Usage :
REM   build-installer.bat
REM   build-installer.bat --skip-jar
REM =============================================================================

setlocal enabledelayedexpansion

REM ======================== Configuration ======================================

set APP_NAME=ParticleTrieur
set APP_VERSION=4.0.0
set MAIN_CLASS=particletrieur.Launcher
set JAR_NAME=ParticleTrieur.jar
set INSTALLER_TYPE=exe

REM Python standalone — https://github.com/indygreg/python-build-standalone/releases
set PYTHON_VERSION=3.11.9
set PYTHON_BUILD_TAG=20240726
set PYTHON_TRIPLE=x86_64-pc-windows-msvc
set PYTHON_FILENAME=cpython-%PYTHON_VERSION%+%PYTHON_BUILD_TAG%-%PYTHON_TRIPLE%-install_only.tar.gz
set PYTHON_URL=https://github.com/indygreg/python-build-standalone/releases/download/%PYTHON_BUILD_TAG%/%PYTHON_FILENAME%

REM Repertoires
set DIST_DIR=dist
set BUILD_DIR=build-installer
set CACHE_DIR=.build-cache

set SKIP_JAR=false
if "%1"=="--skip-jar" set SKIP_JAR=true

REM ======================== Verification =======================================

echo.
echo ==============================================================
echo     ParticleTrieur — Build d'installateur Windows
echo ==============================================================
echo.
echo   Python :       %PYTHON_VERSION%
echo   Installateur : %INSTALLER_TYPE%
echo.

REM Verifier JDK
java -version 2>&1 | findstr /i "21\." >nul
if errorlevel 1 (
    echo [ERREUR] JDK 21 requis.
    echo   Installer depuis : https://www.azul.com/downloads/?package=jdk#zulu
    exit /b 1
)

REM Verifier jpackage
where jpackage >nul 2>&1
if errorlevel 1 (
    echo [ERREUR] jpackage introuvable. Verifier que JAVA_HOME pointe vers un JDK 21.
    exit /b 1
)

REM Verifier Maven
where mvn >nul 2>&1
if errorlevel 1 (
    echo [ERREUR] Maven introuvable. Installer depuis : https://maven.apache.org/
    exit /b 1
)

REM ======================== Etape 1 : Fat JAR ==================================

if "%SKIP_JAR%"=="true" (
    if exist "target\%JAR_NAME%" (
        echo [1/5] Compilation du fat JAR ... SKIP ^(--skip-jar^)
        goto step2
    )
)

echo [1/5] Compilation du fat JAR ...
call mvn clean package -q -DskipTests
if errorlevel 1 (
    echo [ERREUR] Echec de la compilation Maven
    exit /b 1
)
echo   OK : target\%JAR_NAME%

:step2
REM ======================== Etape 2 : Telecharger Python =======================

if not exist "%CACHE_DIR%" mkdir "%CACHE_DIR%"

if exist "%CACHE_DIR%\%PYTHON_FILENAME%" (
    echo [2/5] Python standalone deja en cache
) else (
    echo [2/5] Telechargement de Python standalone ...
    echo   URL : %PYTHON_URL%
    curl -L --progress-bar -o "%CACHE_DIR%\%PYTHON_FILENAME%" "%PYTHON_URL%"
    if errorlevel 1 (
        echo [ERREUR] Echec du telechargement
        exit /b 1
    )
    echo   OK
)

REM ======================== Etape 3 : Environnement Python =====================

echo [3/5] Creation de l'environnement Python avec miso ...

if exist "%DIST_DIR%" rmdir /s /q "%DIST_DIR%"
mkdir "%DIST_DIR%\python-env"

REM Extraire Python (tar est disponible sur Windows 10+)
echo   Extraction de Python ...
tar xzf "%CACHE_DIR%\%PYTHON_FILENAME%" --strip-components=1 -C "%DIST_DIR%\python-env"
if errorlevel 1 (
    echo [ERREUR] Echec de l'extraction de Python
    exit /b 1
)

REM Determiner le binaire Python
set PYTHON_BIN=%DIST_DIR%\python-env\python.exe
if not exist "%PYTHON_BIN%" (
    echo [ERREUR] python.exe introuvable dans python-env\
    dir "%DIST_DIR%\python-env\"
    exit /b 1
)

REM Mise a jour de pip
echo   Mise a jour de pip ...
"%PYTHON_BIN%" -m pip install --upgrade pip --quiet 2>nul

REM Installer miso + dependances
echo   Installation de miso + dependances (cela peut prendre quelques minutes) ...
"%PYTHON_BIN%" -m pip install .\python\miso-src\ --quiet
if errorlevel 1 (
    echo [ERREUR] Echec de l'installation de miso
    exit /b 1
)

REM Verifier
"%PYTHON_BIN%" -c "import miso; print('  OK : miso installe')"
if errorlevel 1 (
    echo [ERREUR] miso non fonctionnel
    exit /b 1
)

REM Nettoyage pour reduire la taille
REM NB: ne pas supprimer __pycache__ -- TensorFlow en a besoin pour s'initialiser
echo   Nettoyage de l'environnement Python ...
for /d /r "%DIST_DIR%\python-env" %%d in (*.dist-info) do (
    if exist "%%d" rmdir /s /q "%%d" 2>nul
)

echo   OK : environnement Python pret

REM ======================== Etape 4 : Preparation ==============================

echo [4/5] Preparation du repertoire de distribution ...

copy "target\%JAR_NAME%" "%DIST_DIR%\" >nul
echo   OK

REM ======================== Etape 5 : jpackage =================================

echo [5/5] Creation de l'installateur (%INSTALLER_TYPE%) ...

if exist "%BUILD_DIR%" rmdir /s /q "%BUILD_DIR%"
mkdir "%BUILD_DIR%"

set ICON_OPT=
if exist "src\main\resources\windows\ParticleTrieur.ico" (
    set ICON_OPT=--icon src\main\resources\windows\ParticleTrieur.ico
)

jpackage ^
    --type %INSTALLER_TYPE% ^
    --input "%DIST_DIR%" ^
    --name "%APP_NAME%" ^
    --main-jar "%JAR_NAME%" ^
    --main-class "%MAIN_CLASS%" ^
    --java-options "-Xmx4G" ^
    --app-version "%APP_VERSION%" ^
    --dest "%BUILD_DIR%" ^
    --win-dir-chooser ^
    --win-menu ^
    --win-shortcut ^
    %ICON_OPT%

if errorlevel 1 (
    echo.
    echo [ERREUR] Echec de jpackage
    echo   Verifier que WiX Toolset 3.x est installe :
    echo   https://wixtoolset.org/releases/
    exit /b 1
)

REM ======================== Resultat ===========================================

echo.
echo ==============================================================
echo              BUILD TERMINE
echo ==============================================================
echo.

for %%f in (%BUILD_DIR%\*.exe %BUILD_DIR%\*.msi) do (
    echo   Installateur : %%f
    echo.
    echo   L'utilisateur n'a qu'a :
    echo     1. Double-cliquer sur %%~nxf
    echo     2. Suivre l'assistant d'installation
)
echo.

endlocal
