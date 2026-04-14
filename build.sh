#!/bin/bash
# Cloudflare Pages build script for Owlio Flutter web app
set -e

FLUTTER_VERSION="${FLUTTER_VERSION:-3.38.9}"

echo "=== Installing Flutter SDK $FLUTTER_VERSION ==="
git clone --depth 1 --branch "$FLUTTER_VERSION" https://github.com/flutter/flutter.git /opt/flutter
export PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:$PATH"

flutter precache --web
flutter doctor -v

echo "=== Creating .env from environment variables ==="
cat > .env << EOF
ENVIRONMENT=${ENVIRONMENT:-production}
SUPABASE_URL=${SUPABASE_URL}
SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}
SENTRY_DSN=${SENTRY_DSN:-}
POSTHOG_API_KEY=${POSTHOG_API_KEY:-}
POSTHOG_HOST=${POSTHOG_HOST:-https://app.posthog.com}
CDN_URL=${CDN_URL:-}
EOF

echo "=== Building Flutter web ==="
flutter build web --release

echo "=== Build complete ==="
