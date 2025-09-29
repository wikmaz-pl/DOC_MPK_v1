#!/bin/bash
set -euo pipefail

# Sprawdzenie uprawnień root
if [ "$(id -u)" -ne 0 ]; then
    echo "Ten skrypt musi być uruchomiony z uprawnieniami roota (użyj sudo)." >&2
    exit 1
fi

# Klonowanie repozytorium jeśli nie istnieje
APP_DIR="/opt/document-search"
if [ -d "$APP_DIR" ]; then
    echo "Katalog aplikacji $APP_DIR już istnieje. Pomijam klonowanie."
else
    echo "Klonowanie repozytorium..."
    git clone https://github.com/wikmaz-pl/DOC_MPK_v1.git "$APP_DIR"
fi

# Instalacja zależności backendowych Python
cd "$APP_DIR/backend"
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# Instalacja zależności frontendowych Node.js
cd "$APP_DIR/frontend"
npm install

# Możesz tu dodać inne komendy dotyczące konfiguracji aplikacji

echo "Instalacja zakończona pomyślnie."
