#!/bin/bash
# Bulk seed FEMALE avatar items: upload PNGs to Storage + create avatar_items rows
set -e
source .env

BASE_URL="$SUPABASE_URL"
SERVICE_KEY="$SUPABASE_SERVICE_ROLE_KEY"
BUCKET="avatars"
ASSETS_DIR="assets/images/avatars"
AUTH="Authorization: Bearer $SERVICE_KEY"
APIKEY="apikey: $SERVICE_KEY"

echo "=== Fetching category IDs ==="
CATEGORIES=$(curl -s "$BASE_URL/rest/v1/avatar_item_categories?select=id,name" -H "$AUTH" -H "$APIKEY")

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

echo "=== Fetching female base ID ==="
FEMALE_BASE_ID=$(curl -s "$BASE_URL/rest/v1/avatar_bases?select=id&name=eq.female" -H "$AUTH" -H "$APIKEY" | python3 -c "import json,sys; print(json.load(sys.stdin)[0]['id'])")
echo "  female_base=$FEMALE_BASE_ID"

# Upload helper
upload_and_insert() {
  local file_path="$1" storage_path="$2" category_id="$3" name="$4" display_name="$5" gender="$6"
  curl -s -o /dev/null -w "" -X POST "$BASE_URL/storage/v1/object/$BUCKET/$storage_path" \
    -H "$AUTH" -H "$APIKEY" -H "Content-Type: image/png" -H "x-upsert: true" --data-binary "@$file_path"
  local public_url="$BASE_URL/storage/v1/object/public/$BUCKET/$storage_path"
  local code=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/rest/v1/avatar_items" \
    -H "$AUTH" -H "$APIKEY" -H "Content-Type: application/json" -H "Prefer: return=minimal" \
    -d "{\"category_id\":\"$category_id\",\"name\":\"$name\",\"display_name\":\"$display_name\",\"rarity\":\"common\",\"coin_price\":0,\"image_url\":\"$public_url\",\"is_active\":true,\"gender\":\"$gender\"}")
  echo "  [$code] $name"
}

# Upload female base image
echo ""
echo "=== Uploading female base image ==="
curl -s -o /dev/null -X POST "$BASE_URL/storage/v1/object/$BUCKET/bases/female_base.png" \
  -H "$AUTH" -H "$APIKEY" -H "Content-Type: image/png" -H "x-upsert: true" \
  --data-binary "@$ASSETS_DIR/bases/girlbase.png"
FEMALE_BASE_URL="$BASE_URL/storage/v1/object/public/$BUCKET/bases/female_base.png"
curl -s -o /dev/null "$BASE_URL/rest/v1/avatar_bases?id=eq.$FEMALE_BASE_ID" -X PATCH \
  -H "$AUTH" -H "$APIKEY" -H "Content-Type: application/json" -H "Prefer: return=minimal" \
  -d "{\"image_url\":\"$FEMALE_BASE_URL\"}"
echo "  Base updated: $FEMALE_BASE_URL"

# Category map
get_cat_id() {
  case "$1" in
    face) echo "$FACE_ID" ;; ears) echo "$EARS_ID" ;; eyes) echo "$EYES_ID" ;;
    brows) echo "$BROWS_ID" ;; noses) echo "$NOSES_ID" ;; mouth) echo "$MOUTH_ID" ;;
    hair) echo "$HAIR_ID" ;; clothes) echo "$CLOTHES_ID" ;;
    additional_accessories) echo "$ACCESSORIES_ID" ;;
  esac
}

make_display_name() {
  local name="$1" category="$2"
  local num=$(echo "$name" | sed 's/.*_//' | sed 's/^0*//')
  if [ -z "$num" ]; then num="1"; fi
  local cap_cat=$(echo "$category" | sed 's/^./\U&/')
  echo "$cap_cat $num"
}

echo ""
echo "=== Uploading female items ==="
TOTAL=0
for folder in face ears eyes brows noses mouth hair clothes additional_accessories; do
  local_dir="$ASSETS_DIR/female/$folder"
  cat_id=$(get_cat_id "$folder")
  [ -z "$cat_id" ] && continue

  echo ""
  echo "--- $folder ---"
  for file in "$local_dir"/*.png; do
    [ -f "$file" ] || continue
    basename_no_ext=$(basename "$file" .png)
    slug="female_${folder}_${basename_no_ext}"
    display=$(make_display_name "$basename_no_ext" "$folder")
    storage_path="items/female/${folder}/${basename_no_ext}.png"
    upload_and_insert "$file" "$storage_path" "$cat_id" "$slug" "$display" "female"
    TOTAL=$((TOTAL + 1))
  done
done

echo ""
echo "=== DONE: $TOTAL female items uploaded ==="
