#!/bin/bash
# =============================================
# Bulk seed avatar items: upload PNGs to Storage + create avatar_items rows
# Usage: bash scripts/seed_avatar_items.sh
# =============================================

set -e

# Load env
source .env

BASE_URL="$SUPABASE_URL"
SERVICE_KEY="$SUPABASE_SERVICE_ROLE_KEY"
BUCKET="avatars"
ASSETS_DIR="assets/images/avatars"

# Auth headers for service role
AUTH="Authorization: Bearer $SERVICE_KEY"
APIKEY="apikey: $SERVICE_KEY"

echo "=== Fetching category IDs ==="
CATEGORIES=$(curl -s "$BASE_URL/rest/v1/avatar_item_categories?select=id,name" \
  -H "$AUTH" -H "$APIKEY")

# Parse category IDs
get_category_id() {
  echo "$CATEGORIES" | python3 -c "
import json, sys
cats = json.load(sys.stdin)
for c in cats:
    if c['name'] == '$1':
        print(c['id'])
        break
"
}

FACE_ID=$(get_category_id "face")
EARS_ID=$(get_category_id "ears")
EYES_ID=$(get_category_id "eyes")
BROWS_ID=$(get_category_id "brows")
NOSES_ID=$(get_category_id "noses")
MOUTH_ID=$(get_category_id "mouth")
HAIR_ID=$(get_category_id "hair")
CLOTHES_ID=$(get_category_id "clothes")
ACCESSORIES_ID=$(get_category_id "additional_accessories")

echo "  face=$FACE_ID"
echo "  ears=$EARS_ID"
echo "  eyes=$EYES_ID"
echo "  brows=$BROWS_ID"
echo "  noses=$NOSES_ID"
echo "  mouth=$MOUTH_ID"
echo "  hair=$HAIR_ID"
echo "  clothes=$CLOTHES_ID"
echo "  accessories=$ACCESSORIES_ID"

echo ""
echo "=== Fetching base IDs ==="
BASES=$(curl -s "$BASE_URL/rest/v1/avatar_bases?select=id,name" \
  -H "$AUTH" -H "$APIKEY")

MALE_BASE_ID=$(echo "$BASES" | python3 -c "
import json, sys
bases = json.load(sys.stdin)
for b in bases:
    if b['name'] == 'male':
        print(b['id'])
        break
")

echo "  male_base=$MALE_BASE_ID"

# ── Upload helper ──────────────────────────────────────────────────
upload_and_insert() {
  local file_path="$1"
  local storage_path="$2"
  local category_id="$3"
  local name="$4"
  local display_name="$5"
  local gender="$6"

  local filename=$(basename "$file_path")

  # Upload to storage
  local upload_url="$BASE_URL/storage/v1/object/$BUCKET/$storage_path"
  local http_code=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "$upload_url" \
    -H "$AUTH" -H "$APIKEY" \
    -H "Content-Type: image/png" \
    -H "x-upsert: true" \
    --data-binary "@$file_path")

  if [ "$http_code" != "200" ]; then
    echo "  WARN: Upload $storage_path returned $http_code, retrying..."
    http_code=$(curl -s -o /dev/null -w "%{http_code}" \
      -X PUT "$upload_url" \
      -H "$AUTH" -H "$APIKEY" \
      -H "Content-Type: image/png" \
      --data-binary "@$file_path")
  fi

  local public_url="$BASE_URL/storage/v1/object/public/$BUCKET/$storage_path"

  # Insert avatar_items row
  local insert_response=$(curl -s -o /dev/null -w "%{http_code}" \
    "$BASE_URL/rest/v1/avatar_items" \
    -H "$AUTH" -H "$APIKEY" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=minimal" \
    -d "{
      \"category_id\": \"$category_id\",
      \"name\": \"$name\",
      \"display_name\": \"$display_name\",
      \"rarity\": \"common\",
      \"coin_price\": 0,
      \"image_url\": \"$public_url\",
      \"is_active\": true,
      \"gender\": \"$gender\"
    }")

  echo "  [$http_code/$insert_response] $name → $storage_path"
}

# ── Update base image ──────────────────────────────────────────────
update_base_image() {
  local file_path="$1"
  local base_id="$2"
  local storage_path="$3"

  # Upload
  curl -s -o /dev/null -w "" \
    -X POST "$BASE_URL/storage/v1/object/$BUCKET/$storage_path" \
    -H "$AUTH" -H "$APIKEY" \
    -H "Content-Type: image/png" \
    -H "x-upsert: true" \
    --data-binary "@$file_path"

  local public_url="$BASE_URL/storage/v1/object/public/$BUCKET/$storage_path"

  # Update base row
  curl -s -o /dev/null \
    "$BASE_URL/rest/v1/avatar_bases?id=eq.$base_id" \
    -X PATCH \
    -H "$AUTH" -H "$APIKEY" \
    -H "Content-Type: application/json" \
    -H "Prefer: return=minimal" \
    -d "{\"image_url\": \"$public_url\"}"

  echo "  Base image updated: $public_url"
}

# ── Helper to make display name from filename ──────────────────────
make_display_name() {
  # nose_01 → Nose 1, hair_22 → Hair 22, etc.
  local name="$1"
  local category="$2"
  local num=$(echo "$name" | sed 's/.*_//' | sed 's/^0*//')
  if [ -z "$num" ]; then num="1"; fi

  # Capitalize first letter
  local cap_cat=$(echo "$category" | sed 's/^./\U&/')
  echo "$cap_cat $num"
}

# =============================================
# EXECUTE
# =============================================

echo ""
echo "=== Uploading base image ==="
if [ -f "$ASSETS_DIR/bases/boybase.png" ]; then
  update_base_image "$ASSETS_DIR/bases/boybase.png" "$MALE_BASE_ID" "bases/male_base.png"
fi

echo ""
echo "=== Uploading male items ==="

# Map folder to category_id (no associative arrays for macOS bash 3)
get_cat_id() {
  case "$1" in
    face) echo "$FACE_ID" ;;
    ears) echo "$EARS_ID" ;;
    eyes) echo "$EYES_ID" ;;
    brows) echo "$BROWS_ID" ;;
    noses) echo "$NOSES_ID" ;;
    mouth) echo "$MOUTH_ID" ;;
    hair) echo "$HAIR_ID" ;;
    clothes) echo "$CLOTHES_ID" ;;
    additional_accessories) echo "$ACCESSORIES_ID" ;;
  esac
}

TOTAL=0
for folder in face ears eyes brows noses mouth hair clothes additional_accessories; do
  local_dir="$ASSETS_DIR/male/$folder"
  cat_id=$(get_cat_id "$folder")

  if [ -z "$cat_id" ]; then
    echo "  SKIP: No category ID for $folder"
    continue
  fi

  echo ""
  echo "--- $folder (category: $cat_id) ---"

  for file in "$local_dir"/*.png; do
    [ -f "$file" ] || continue

    basename_no_ext=$(basename "$file" .png)
    slug="male_${folder}_${basename_no_ext}"
    display=$(make_display_name "$basename_no_ext" "$folder")
    storage_path="items/male/${folder}/${basename_no_ext}.png"

    upload_and_insert "$file" "$storage_path" "$cat_id" "$slug" "$display" "male"
    TOTAL=$((TOTAL + 1))
  done
done

echo ""
echo "=== DONE: $TOTAL items uploaded ==="
