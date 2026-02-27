#!/bin/bash
# Script pour générer le .jar exécutable avec toutes les dépendances et python-env

set -e

# Aller à la racine du projet (là où se trouve ce script)
cd "$(dirname "$0")"

echo "Nettoyage du projet..."
mvn clean

echo "Compilation et création du fat jar..."
mvn package

# Cherche le jar généré
JAR_FILE=$(find target -name '*shaded.jar' | head -n 1)

if [ -f "$JAR_FILE" ]; then
    echo "\nLe .jar exécutable a été généré : $JAR_FILE"
    echo "Pour l'exécuter :"
    echo "    java -jar $JAR_FILE"
else
    echo "\nErreur : aucun .jar shaded trouvé dans target/"
    exit 1
fi
