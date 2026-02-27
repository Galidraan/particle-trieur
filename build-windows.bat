@echo off
:: ============================================================================
:: ParticleTrieur - Windows x64 Build Script
:: ============================================================================
:: Creates a self-contained installer with embedded Python + miso library.
:: No conda/Python installation required on the user's machine.
::
:: Prerequisites (build machine only):
::   - conda or miniconda installed
::   - conda-pack: conda install -c conda-forge conda-pack
::   - Java 21 (any JDK 21)
::   - Maven
::   - Inno Setup 6 (https://jrsoftware.org/isdl.php)
::
:: Usage: build-windows.bat
:: ============================================================================

setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
set "BUILD_DIR=%SCRIPT_DIR%build-win"
set "APP_NAME=ParticleTrieur"
set "CONDA_ENV_NAME=miso-bundle-win"
set "PYTHON_VERSION=3.10"

echo ============================================
echo  ParticleTrieur Windows x64 Build
echo ============================================

:: ---------------------------------------------------
:: Step 1: Build the JAR
:: ---------------------------------------------------
echo.
echo [1/5] Building JAR with Maven...
cd /d "%SCRIPT_DIR%"
call mvn -B package --file pom.xml -q
if %errorlevel% neq 0 (
    echo ERROR: Maven build failed
    exit /b 1
)
echo   -^> JAR built: target\ParticleTrieur.jar

:: ---------------------------------------------------
:: Step 2: Create conda environment with miso
:: ---------------------------------------------------
echo.
echo [2/5] Creating Python environment...

:: Remove existing env if present
call conda env remove -n %CONDA_ENV_NAME% -y 2>nul

:: Create fresh environment
call conda create -n %CONDA_ENV_NAME% python=%PYTHON_VERSION% -y -q
if %errorlevel% neq 0 (
    echo ERROR: Failed to create conda environment
    exit /b 1
)

:: Install miso from local sources
echo   -^> Installing miso from local sources...
call conda run -n %CONDA_ENV_NAME% pip install -q "%SCRIPT_DIR%python\miso-src\"
if %errorlevel% neq 0 (
    echo ERROR: Failed to install miso
    exit /b 1
)
echo   -^> Python environment ready

:: ---------------------------------------------------
:: Step 3: Pack the conda environment
:: ---------------------------------------------------
echo.
echo [3/5] Packing Python environment (this may take a few minutes)...

if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"

:: Install conda-pack if needed
call conda install -n base -c conda-forge conda-pack -y -q 2>nul

call conda pack -n %CONDA_ENV_NAME% -o "%BUILD_DIR%\miso-python-env.tar.gz" --force -q
if %errorlevel% neq 0 (
    echo ERROR: Failed to pack conda environment
    exit /b 1
)
echo   -^> Packed: %BUILD_DIR%\miso-python-env.tar.gz

:: ---------------------------------------------------
:: Step 4: Assemble application directory
:: ---------------------------------------------------
echo.
echo [4/5] Assembling application directory...

set "APP_DIR=%BUILD_DIR%\%APP_NAME%"
if exist "%APP_DIR%" rmdir /s /q "%APP_DIR%"
mkdir "%APP_DIR%"

:: Copy JAR
copy "%SCRIPT_DIR%target\ParticleTrieur.jar" "%APP_DIR%\" >nul

:: Copy launcher
copy "%SCRIPT_DIR%run.bat" "%APP_DIR%\" >nul

:: Unpack Python environment
echo   -^> Extracting Python environment...
mkdir "%APP_DIR%\python-env"
tar -xzf "%BUILD_DIR%\miso-python-env.tar.gz" -C "%APP_DIR%\python-env"

:: Run conda-unpack if available
if exist "%APP_DIR%\python-env\Scripts\conda-unpack.exe" (
    "%APP_DIR%\python-env\Scripts\conda-unpack.exe" 2>nul
)

echo   -^> Application directory assembled: %APP_DIR%

:: ---------------------------------------------------
:: Step 5: Create installer with Inno Setup
:: ---------------------------------------------------
echo.
echo [5/5] Creating installer with Inno Setup...

:: Try to find Inno Setup
set "ISCC="
for %%D in (
    "%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
    "%ProgramFiles%\Inno Setup 6\ISCC.exe"
) do (
    if exist "%%~D" set "ISCC=%%~D"
)

if not defined ISCC (
    echo WARNING: Inno Setup not found. Skipping installer creation.
    echo   You can install it from: https://jrsoftware.org/isdl.php
    echo   Then run: ISCC.exe "%SCRIPT_DIR%inno\innoSetupScript-v4.iss"
    echo.
    echo   The application folder is ready at: %APP_DIR%
    exit /b 0
)

"%ISCC%" "%SCRIPT_DIR%inno\innoSetupScript-v4.iss"
if %errorlevel% neq 0 (
    echo ERROR: Inno Setup build failed
    exit /b 1
)

echo.
echo ============================================
echo  Build complete!
echo  Installer: %BUILD_DIR%\ParticleTrieurSetup-4.0.0.exe
echo ============================================
echo.
echo To clean up the build conda env:
echo   conda env remove -n %CONDA_ENV_NAME%
