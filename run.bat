@echo off
:: ParticleTrieur Launcher - Windows
:: Requires Java 21 to be installed

set "SCRIPT_DIR=%~dp0"
set "JAR=%SCRIPT_DIR%ParticleTrieur.jar"
set "JAVA_EXE="

:: Search common Java 21 install locations
for /d %%D in (
    "%ProgramFiles%\Zulu\zulu-21*"
    "%ProgramFiles%\Java\jdk-21*"
    "%ProgramFiles%\Eclipse Adoptium\jdk-21*"
    "%ProgramFiles%\Amazon Corretto\jdk21*"
    "%ProgramFiles%\Microsoft\jdk-21*"
) do (
    if exist "%%~D\bin\java.exe" (
        set "JAVA_EXE=%%~D\bin\java.exe"
        goto :found
    )
)

:: Try JAVA_HOME
if defined JAVA_HOME (
    if exist "%JAVA_HOME%\bin\java.exe" (
        set "JAVA_EXE=%JAVA_HOME%\bin\java.exe"
        goto :found
    )
)

:: Try java on PATH
where java >nul 2>&1
if %errorlevel%==0 (
    set "JAVA_EXE=java"
    goto :found
)

echo Erreur : Java 21 introuvable.
echo Veuillez installer Azul Zulu JDK FX 21 depuis :
echo https://www.azul.com/downloads/?package=jdk-fx#zulu
pause
exit /b 1

:found
"%JAVA_EXE%" -jar "%JAR%" %*
