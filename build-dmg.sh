#!/bin/bash
# Script pour générer un DMG installateur macOS à partir du .jar

set -e

# Variables à adapter

APP_NAME="ParticleTrieur"
JAR_NAME="ParticleTrieur.jar" # Nom réel du jar
MAIN_CLASS="particletrieur.Launcher"
ICON_PATH="src/main/resources/mac/ParticleTrieur.icns" # Mets à jour si besoin
DIST_DIR="dist"
BUILD_DIR="build-mac"

# Nettoyage et préparation
rm -rf "$DIST_DIR" "$BUILD_DIR"
mkdir -p "$DIST_DIR" "$BUILD_DIR"

# Copie le .jar dans dist/
cp "target/$JAR_NAME" "$DIST_DIR/"

# Commande jpackage
jpackage \
  --type dmg \
  --input "$DIST_DIR" \
  --name "$APP_NAME" \
  --main-jar "$JAR_NAME" \
  --main-class "$MAIN_CLASS" \
  --icon "$ICON_PATH" \
  --java-options "-Xmx2G" \
  --dest "$BUILD_DIR"

DMG_FILE=$(find "$BUILD_DIR" -name '*.dmg' | head -n 1)
if [ -f "$DMG_FILE" ]; then
    echo "\nLe DMG a été généré : $DMG_FILE"
else
    echo "\nErreur : DMG non généré. Vérifie les logs."
    exit 1
fi
