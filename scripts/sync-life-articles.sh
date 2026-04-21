#!/bin/bash
# Sync articles from tomyshogo/life repo's news/ directory
# Converts plain Markdown to Astro-compatible format with frontmatter

set -uo pipefail

LIFE_REPO="tomyshogo/life"
SOURCE_DIR="news"
TARGET_DIR="src/pages/posts"
WORK_DIR=$(pwd)
TEMP_DIR=$(mktemp -d)

trap 'rm -rf "$TEMP_DIR"' EXIT

echo "Fetching articles from $LIFE_REPO/$SOURCE_DIR..."

# Use LIFE_REPO_TOKEN if available (for private repos), fallback to GH_TOKEN
TOKEN="${LIFE_REPO_TOKEN:-${GH_TOKEN:-}}"

if [ -n "$TOKEN" ]; then
  CLONE_URL="https://x-access-token:${TOKEN}@github.com/$LIFE_REPO.git"
else
  CLONE_URL="https://github.com/$LIFE_REPO.git"
fi

# Clone the repo (shallow, sparse)
if ! git clone --depth 1 --filter=blob:none --sparse \
  "$CLONE_URL" "$TEMP_DIR/life" 2>&1; then
  echo "Warning: Could not clone $LIFE_REPO. Skipping sync."
  exit 0
fi

cd "$TEMP_DIR/life"
git sparse-checkout set "$SOURCE_DIR" 2>/dev/null || true
cd "$WORK_DIR"

SOURCE_PATH="$TEMP_DIR/life/$SOURCE_DIR"

if [ ! -d "$SOURCE_PATH" ]; then
  echo "No $SOURCE_DIR directory found in $LIFE_REPO. Skipping."
  exit 0
fi

# Find all markdown files
MD_FILES=$(find "$SOURCE_PATH" -name "*.md" -type f 2>/dev/null || true)

if [ -z "$MD_FILES" ]; then
  echo "No markdown files found in $SOURCE_DIR/. Skipping."
  exit 0
fi

# Ensure target directory exists
mkdir -p "$TARGET_DIR"

SYNCED=0

while IFS= read -r file; do
  [ -z "$file" ] && continue

  filename=$(basename "$file")
  target="$TARGET_DIR/$filename"

  # Skip if file already exists and content hasn't changed
  if [ -f "$target" ]; then
    existing_body=$(sed '1,/^---$/d' "$target" | sed '1,/^---$/d')
    new_body=$(cat "$file")
    if [ "$existing_body" = "$new_body" ]; then
      echo "  Skip (unchanged): $filename"
      continue
    fi
  fi

  # Check if the file already has frontmatter
  first_line=$(head -n 1 "$file")
  if [ "$first_line" = "---" ]; then
    cp "$file" "$target"
    echo "  Synced (with existing frontmatter): $filename"
  else
    # Generate frontmatter from filename and content
    # Expected filename format: YYYYMMDD-title.md or any-name.md
    title=$(echo "$filename" | sed 's/\.md$//' | sed 's/^[0-9]*-//' | sed 's/-/ /g')

    # Try to extract date from filename (YYYYMMDD pattern)
    date_str=$(echo "$filename" | grep -oE '^[0-9]{8}' || true)
    if [ -n "$date_str" ]; then
      pub_date="${date_str:0:4}-${date_str:4:2}-${date_str:6:2}"
    else
      pub_date=$(date +%Y-%m-%d)
    fi

    # Extract first non-empty, non-heading line as description
    description=$(grep -m 1 -v '^#\|^$\|^-\|^>' "$file" || echo "$title")
    description=$(echo "$description" | head -c 120)
    # Escape single quotes for YAML
    title=$(echo "$title" | sed "s/'/''/g")
    description=$(echo "$description" | sed "s/'/''/g")

    cat > "$target" <<EOF
---
layout: ../../layouts/MarkdownPostLayout.astro
title: '$title'
pubDate: $pub_date
description: '$description'
author: 'tomy'
tags: ["life"]
---

$(cat "$file")
EOF
    echo "  Synced (frontmatter added): $filename"
  fi

  SYNCED=$((SYNCED + 1))
done <<< "$MD_FILES"

echo "Done. $SYNCED article(s) synced."
