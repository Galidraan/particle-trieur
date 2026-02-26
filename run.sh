#!/bin/bash
# ParticleTrieur Launcher - macOS / Linux
# Requires Java 21 to be installed

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
JAR="$SCRIPT_DIR/ParticleTrieur.jar"

# Try to find Java 21
if [[ "$(uname)" == "Darwin" ]]; then
    # macOS
    JAVA_HOME=$(/usr/libexec/java_home -v 21 2>/dev/null)
else
    # Linux - search common locations
    for dir in /usr/lib/jvm/zulu-21* /usr/lib/jvm/java-21* /usr/lib/jvm/temurin-21*; do
        if [ -d "$dir" ]; then
            JAVA_HOME="$dir"
            break
        fi
    done
fi

if [ -z "$JAVA_HOME" ] || [ ! -f "$JAVA_HOME/bin/java" ]; then
    echo "Erreur : Java 21 introuvable."
    echo "Veuillez installer Azul Zulu JDK FX 21 depuis :"
    echo "https://www.azul.com/downloads/?package=jdk-fx#zulu"
    read -p "Appuyez sur Entrée pour fermer..."
    exit 1
fi

"$JAVA_HOME/bin/java" -jar "$JAR" "$@"
