#!/bin/bash
# Double-click this file to start Widgetbook server
# Then open http://localhost:8081 in your browser

cd "$(dirname "$0")"

# Build if not exists
if [ ! -d "build/web" ]; then
    echo "Building Widgetbook..."
    flutter build web --release
fi

echo ""
echo "=========================================="
echo "  Widgetbook running at:"
echo "  http://localhost:8081"
echo "=========================================="
echo ""
echo "Press Ctrl+C to stop"
echo ""

# Start server
cd build/web
python3 -m http.server 8081
