#!/bin/bash
# ============================================================================
# ParticleTrieur - macOS ARM (Apple Silicon) Build Script
# ============================================================================
# Creates a self-contained .dmg with embedded Python + miso library.
# No conda/Python installation required on the user's machine.
#
# Prerequisites (build machine only):
#   - conda or miniconda installed
#   - conda-pack: conda install -c conda-forge conda-pack
#   - Java 21 (Azul Zulu JDK FX recommended)
#   - Maven
#
# Usage: ./build-macos-arm.sh
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
APP_NAME="ParticleTrieur"
CONDA_ENV_NAME="miso-bundle"
PYTHON_VERSION="3.10"

echo "============================================"
echo " ParticleTrieur macOS ARM Build"
echo "============================================"

# ---------------------------------------------------
# Step 1: Build the JAR
# ---------------------------------------------------
echo ""
echo "[1/5] Building JAR with Maven..."
cd "$SCRIPT_DIR"
mvn -B package --file pom.xml -q
echo "  -> JAR built: target/ParticleTrieur.jar"

# ---------------------------------------------------
# Step 2: Create conda environment with miso
# ---------------------------------------------------
echo ""
echo "[2/5] Creating Python environment..."

# Remove existing env if present
conda env remove -n "$CONDA_ENV_NAME" -y 2>/dev/null || true

# Create fresh environment
conda create -n "$CONDA_ENV_NAME" python="$PYTHON_VERSION" -y -q

# Install miso from local sources  
echo "  -> Installing miso from local sources..."
conda run -n "$CONDA_ENV_NAME" pip install -q "$SCRIPT_DIR/python/miso-src/"

echo "  -> Python environment ready"

# ---------------------------------------------------
# Step 3: Pack the conda environment
# ---------------------------------------------------
echo ""
echo "[3/5] Packing Python environment (this may take a few minutes)..."

PACKED_ENV="$BUILD_DIR/miso-python-env.tar.gz"
mkdir -p "$BUILD_DIR"

# Install conda-pack if needed
conda install -n base -c conda-forge conda-pack -y -q 2>/dev/null || true

conda pack -n "$CONDA_ENV_NAME" -o "$PACKED_ENV" --force -q
echo "  -> Packed: $PACKED_ENV ($(du -h "$PACKED_ENV" | cut -f1))"

# ---------------------------------------------------
# Step 4: Assemble the .app bundle
# ---------------------------------------------------
echo ""
echo "[4/5] Assembling application bundle..."

APP_DIR="$BUILD_DIR/$APP_NAME.app/Contents"
rm -rf "$BUILD_DIR/$APP_NAME.app"
mkdir -p "$APP_DIR/MacOS"
mkdir -p "$APP_DIR/Resources"

# Copy JAR
cp "$SCRIPT_DIR/target/ParticleTrieur.jar" "$APP_DIR/Resources/"

# Unpack Python environment
echo "  -> Extracting Python environment..."
mkdir -p "$APP_DIR/Resources/python-env"
tar -xzf "$PACKED_ENV" -C "$APP_DIR/Resources/python-env"

# Make Python environment relocatable (conda-pack post-install step)
if [ -f "$APP_DIR/Resources/python-env/bin/conda-unpack" ]; then
    "$APP_DIR/Resources/python-env/bin/conda-unpack" 2>/dev/null || true
fi

# Create the launcher script
cat > "$APP_DIR/MacOS/$APP_NAME" << 'LAUNCHER_EOF'
#!/bin/bash
# ParticleTrieur Launcher - macOS ARM (self-contained)
DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Find Java 21
JAVA_HOME=$(/usr/libexec/java_home -v 21 2>/dev/null)
if [ -z "$JAVA_HOME" ] || [ ! -f "$JAVA_HOME/bin/java" ]; then
    osascript -e 'display dialog "Java 21 not found.\n\nPlease install Azul Zulu JDK FX 21 from:\nhttps://www.azul.com/downloads/?package=jdk-fx#zulu" buttons {"OK"} default button "OK" with icon stop with title "ParticleTrieur"'
    exit 1
fi

exec "$JAVA_HOME/bin/java" \
    -XstartOnFirstThread \
    -jar "$DIR/Resources/ParticleTrieur.jar" "$@"
LAUNCHER_EOF
chmod +x "$APP_DIR/MacOS/$APP_NAME"

# Create Info.plist
cat > "$APP_DIR/Info.plist" << 'PLIST_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>ParticleTrieur</string>
    <key>CFBundleDisplayName</key>
    <string>ParticleTrieur</string>
    <key>CFBundleIdentifier</key>
    <string>com.microfossil.particletrieur</string>
    <key>CFBundleVersion</key>
    <string>3.0.5</string>
    <key>CFBundleShortVersionString</key>
    <string>3.0.5</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>ParticleTrieur</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>LSArchitecturePriority</key>
    <array>
        <string>arm64</string>
    </array>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST_EOF

echo "  -> App bundle created: $BUILD_DIR/$APP_NAME.app"

# ---------------------------------------------------
# Step 5: Create DMG
# ---------------------------------------------------
echo ""
echo "[5/5] Creating DMG..."

DMG_PATH="$BUILD_DIR/${APP_NAME}-macOS-arm64.dmg"
rm -f "$DMG_PATH"

# Create a temporary DMG directory with app + Applications symlink
DMG_STAGING="$BUILD_DIR/dmg-staging"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -R "$BUILD_DIR/$APP_NAME.app" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGING" \
    -ov -format UDZO \
    "$DMG_PATH" -quiet

rm -rf "$DMG_STAGING"

DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)
echo "  -> DMG created: $DMG_PATH ($DMG_SIZE)"

# ---------------------------------------------------
# Cleanup
# ---------------------------------------------------
echo ""
echo "============================================"
echo " Build complete!"
echo " DMG: $DMG_PATH ($DMG_SIZE)"
echo "============================================"
echo ""
echo "To clean up the build conda env:"
echo "  conda env remove -n $CONDA_ENV_NAME"
