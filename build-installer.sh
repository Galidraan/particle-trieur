#!/bin/bash
# =============================================================================
# ParticleTrieur — Build d'installateur natif (macOS / Linux)
#
# Ce script produit un installateur autonome (.dmg ou .deb) contenant :
#   - Le JRE 21 embarqué (via jpackage)
#   - Le fat JAR avec JavaFX multi-plateforme
#   - Un environnement Python portable avec miso + TensorFlow pré-installés
#
# Prérequis sur la machine de BUILD uniquement :
#   - JDK 21 (Azul Zulu, Temurin, ou autre)
#   - Maven 3.8+
#   - curl
#   - ~5 Go d'espace disque libre
#
# Usage :
#   ./build-installer.sh              # Build pour l'OS courant
#   ./build-installer.sh --type rpm   # Linux : forcer le type RPM
#   ./build-installer.sh --skip-jar   # Ne pas recompiler le JAR
# =============================================================================

set -euo pipefail

# ======================== Configuration ======================================

APP_NAME="ParticleTrieur"
APP_VERSION="4.0.0"
MAIN_CLASS="particletrieur.Launcher"
JAR_NAME="ParticleTrieur.jar"

# Python standalone — https://github.com/indygreg/python-build-standalone/releases
# Utiliser la variante "install_only" pour un Python portable minimal
PYTHON_VERSION="3.11.9"
PYTHON_BUILD_TAG="20240726"

# Répertoires de travail
DIST_DIR="dist"
BUILD_DIR="build-installer"
CACHE_DIR=".build-cache"

# Options depuis les arguments
SKIP_JAR=false
CUSTOM_TYPE=""

for arg in "$@"; do
    case "$arg" in
        --skip-jar)   SKIP_JAR=true ;;
        --type)       shift; CUSTOM_TYPE="$1" ;;
        --type=*)     CUSTOM_TYPE="${arg#--type=}" ;;
    esac
done

# ======================== Détection OS / Architecture ========================

OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
    Darwin)
        PLATFORM="macOS"
        INSTALLER_TYPE="${CUSTOM_TYPE:-dmg}"
        ICON_PATH="src/main/resources/mac/ParticleTrieur.icns"
        case "$ARCH" in
            arm64)  PYTHON_TRIPLE="aarch64-apple-darwin" ;;
            x86_64) PYTHON_TRIPLE="x86_64-apple-darwin" ;;
            *) echo "❌ Architecture macOS non supportée : $ARCH"; exit 1 ;;
        esac
        ;;
    Linux)
        PLATFORM="Linux"
        INSTALLER_TYPE="${CUSTOM_TYPE:-deb}"
        ICON_PATH="src/main/resources/icons/icon.png"
        case "$ARCH" in
            x86_64)  PYTHON_TRIPLE="x86_64-unknown-linux-gnu" ;;
            aarch64) PYTHON_TRIPLE="aarch64-unknown-linux-gnu" ;;
            *) echo "❌ Architecture Linux non supportée : $ARCH"; exit 1 ;;
        esac
        ;;
    *)
        echo "❌ OS non supporté : $OS"
        echo "   Pour Windows, utiliser build-installer.bat"
        exit 1
        ;;
esac

PYTHON_FILENAME="cpython-${PYTHON_VERSION}+${PYTHON_BUILD_TAG}-${PYTHON_TRIPLE}-install_only.tar.gz"
PYTHON_URL="https://github.com/indygreg/python-build-standalone/releases/download/${PYTHON_BUILD_TAG}/${PYTHON_FILENAME}"

# ======================== Vérifications ======================================

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║       ParticleTrieur — Build d'installateur natif           ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "  Plateforme :   $PLATFORM ($ARCH)"
echo "  Python :       $PYTHON_VERSION ($PYTHON_TRIPLE)"
echo "  Installateur : $INSTALLER_TYPE"
echo ""

# Vérifier JDK 21
if ! java -version 2>&1 | grep -q "21\."; then
    echo "❌ JDK 21 requis. Version détectée :"
    java -version 2>&1 | head -1
    echo ""
    echo "Installer depuis : https://www.azul.com/downloads/?package=jdk#zulu"
    exit 1
fi

# Vérifier jpackage
if ! command -v jpackage &> /dev/null; then
    echo "❌ jpackage introuvable. Il est inclus dans le JDK 21."
    echo "   Vérifier que JAVA_HOME pointe vers un JDK (pas un JRE)."
    exit 1
fi

# Vérifier Maven
if ! command -v mvn &> /dev/null; then
    echo "❌ Maven introuvable. Installer depuis : https://maven.apache.org/"
    exit 1
fi

# Vérifier l'icône
if [ ! -f "$ICON_PATH" ]; then
    echo "⚠️  Icône non trouvée à $ICON_PATH — l'installateur aura l'icône par défaut."
    ICON_OPT=""
else
    ICON_OPT="--icon $ICON_PATH"
fi

# ======================== Étape 1 : Fat JAR ==================================

if [ "$SKIP_JAR" = true ] && [ -f "target/$JAR_NAME" ]; then
    echo "► Étape 1/5 : Compilation du fat JAR ... SKIP (--skip-jar)"
else
    echo "► Étape 1/5 : Compilation du fat JAR ..."
    mvn clean package -q -DskipTests
    echo "  ✓ target/$JAR_NAME ($(du -h "target/$JAR_NAME" | cut -f1))"
fi

# ======================== Étape 2 : Téléchargement Python ====================

mkdir -p "$CACHE_DIR"
PYTHON_CACHE="$CACHE_DIR/$PYTHON_FILENAME"

if [ -f "$PYTHON_CACHE" ]; then
    echo "► Étape 2/5 : Python standalone déjà en cache"
else
    echo "► Étape 2/5 : Téléchargement de Python standalone ..."
    echo "  URL : $PYTHON_URL"
    curl -L --progress-bar -o "$PYTHON_CACHE" "$PYTHON_URL"
    echo "  ✓ Téléchargé ($(du -h "$PYTHON_CACHE" | cut -f1))"
fi

# ======================== Étape 3 : Environnement Python =====================

echo "► Étape 3/5 : Création de l'environnement Python avec miso ..."

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR/python-env"

# Extraire Python standalone
tar xzf "$PYTHON_CACHE" --strip-components=1 -C "$DIST_DIR/python-env"

# Déterminer le binaire Python
if [ -f "$DIST_DIR/python-env/bin/python3" ]; then
    PYTHON_BIN="$DIST_DIR/python-env/bin/python3"
elif [ -f "$DIST_DIR/python-env/bin/python" ]; then
    PYTHON_BIN="$DIST_DIR/python-env/bin/python"
else
    echo "❌ Binaire Python introuvable dans python-env/"
    ls -la "$DIST_DIR/python-env/bin/" 2>/dev/null || ls -la "$DIST_DIR/python-env/"
    exit 1
fi

# Créer le symlink python -> python3 si nécessaire (le code Java cherche "python")
if [ ! -f "$DIST_DIR/python-env/bin/python" ] && [ -f "$DIST_DIR/python-env/bin/python3" ]; then
    ln -sf python3 "$DIST_DIR/python-env/bin/python"
fi

# Mise à jour de pip
echo "  Mise à jour de pip ..."
"$PYTHON_BIN" -m pip install --upgrade pip --quiet 2>&1 | tail -1 || true

# Installer miso avec toutes ses dépendances (TensorFlow, scikit-learn, etc.)
echo "  Installation de miso + dépendances (cela peut prendre quelques minutes) ..."
"$PYTHON_BIN" -m pip install ./python/miso-src/ --quiet

# Vérifier l'installation
if "$PYTHON_BIN" -c "import miso; print('  ✓ miso', miso.__version__ if hasattr(miso,'__version__') else 'OK')"; then
    :
else
    echo "❌ Échec de l'installation de miso"
    exit 1
fi

# Nettoyage pour réduire la taille
# NB: ne pas supprimer __pycache__ ni .pyc — TensorFlow en a besoin pour s'initialiser
echo "  Nettoyage de l'environnement Python ..."
find "$DIST_DIR/python-env" -name "*.dist-info" -type d -exec rm -rf {} + 2>/dev/null || true
rm -rf "$DIST_DIR/python-env/share/man" 2>/dev/null || true
rm -rf "$DIST_DIR/python-env/share/doc" 2>/dev/null || true

PYENV_SIZE=$(du -sh "$DIST_DIR/python-env" | cut -f1)
echo "  ✓ Environnement Python prêt ($PYENV_SIZE)"

# ======================== Étape 4 : Préparation ==============================

echo "► Étape 4/5 : Préparation du répertoire de distribution ..."

cp "target/$JAR_NAME" "$DIST_DIR/"

echo "  ✓ Contenu de $DIST_DIR/ :"
echo "    - $JAR_NAME ($(du -h "$DIST_DIR/$JAR_NAME" | cut -f1))"
echo "    - python-env/ ($PYENV_SIZE)"

# ======================== Étape 5 : jpackage =================================

echo "► Étape 5/5 : Création de l'installateur ($INSTALLER_TYPE) ..."

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Construction de la commande jpackage
JPACKAGE_CMD=(
    jpackage
    --type "$INSTALLER_TYPE"
    --input "$DIST_DIR"
    --name "$APP_NAME"
    --main-jar "$JAR_NAME"
    --main-class "$MAIN_CLASS"
    --java-options "-Xmx4G"
    --app-version "$APP_VERSION"
    --dest "$BUILD_DIR"
)

# Ajouter l'icône si disponible
if [ -n "$ICON_OPT" ]; then
    JPACKAGE_CMD+=(--icon "$ICON_PATH")
fi

# Options spécifiques à la plateforme
case "$OS" in
    Darwin)
        JPACKAGE_CMD+=(
            --mac-package-name "$APP_NAME"
        )
        ;;
    Linux)
        JPACKAGE_CMD+=(
            --linux-shortcut
            --linux-menu-group "Science"
            --description "Particle classification and analysis using deep learning"
        )
        ;;
esac

# Exécuter jpackage
"${JPACKAGE_CMD[@]}"

# ======================== Résultat ===========================================

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    BUILD TERMINÉ ✓                          ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

INSTALLER=$(find "$BUILD_DIR" -maxdepth 1 \( -name "*.dmg" -o -name "*.deb" -o -name "*.rpm" \) | head -n 1)
if [ -n "$INSTALLER" ]; then
    echo "  Installateur : $INSTALLER"
    echo "  Taille :       $(du -h "$INSTALLER" | cut -f1)"
    echo ""
    echo "  L'utilisateur n'a qu'à :"
    case "$INSTALLER_TYPE" in
        dmg) echo "    1. Ouvrir le .dmg" ; echo "    2. Glisser $APP_NAME dans Applications" ;;
        deb) echo "    sudo dpkg -i $INSTALLER" ;;
        rpm) echo "    sudo rpm -i $INSTALLER" ;;
    esac
else
    echo "  ⚠️  Installateur non trouvé dans $BUILD_DIR/"
    ls -la "$BUILD_DIR/"
fi
echo ""
