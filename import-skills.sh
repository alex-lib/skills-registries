#!/bin/bash

set -e

REPO_URL="$1"
SKILLY_URL="${SKILLY_URL:-http://localhost:3000}"
NAMESPACE="${NAMESPACE:-global}"
REF="${REF:-main}"
SEMVER="${SEMVER:-1.0.0}"
TEMP_DIR="/tmp/skills-import"
SKILLY_COOKIE="${SKILLY_COOKIE:-}"

if [ -z "$REPO_URL" ]; then
    echo "Usage:"
    echo "./import-skills.sh https://github.com/user/repository.git"
    exit 1
fi

echo "========================================"
echo "Skilly Skills Import"
echo "========================================"
echo "Repository: $REPO_URL"
echo "Skilly:     $SKILLY_URL"
echo "Namespace:  $NAMESPACE"
echo "Ref:        $REF"
echo ""

echo "Cloning repository..."

rm -rf "$TEMP_DIR"

git clone --depth 1 --branch "$REF" "$REPO_URL" "$TEMP_DIR"

echo ""
echo "Searching for SKILL.md files..."

SKILL_COUNT=$(find "$TEMP_DIR" -name "SKILL.md" -type f | wc -l | tr -d ' ')

echo "Found $SKILL_COUNT skills"
echo ""

SUCCESS=0
FAILED=0

find "$TEMP_DIR" -name "SKILL.md" -type f | while read -r SKILL_FILE; do

    SKILL_DIR=$(dirname "$SKILL_FILE")

    # Путь относительно корня репозитория.
    SUBDIR="${SKILL_DIR#$TEMP_DIR/}"

    # Если SKILL.md находится непосредственно в корне,
    # subdir должен быть null.
    if [ "$SUBDIR" = "$SKILL_DIR" ]; then
        SUBDIR=""
    fi

    SKILL_SLUG=$(basename "$SKILL_DIR")

    echo "----------------------------------------"
    echo "Skill:    $SKILL_SLUG"
    echo "Subdir:   $SUBDIR"
    echo "----------------------------------------"

    if [ -n "$SUBDIR" ]; then
        SUBDIR_JSON=$(jq -n --arg value "$SUBDIR" '$value')
    else
        SUBDIR_JSON="null"
    fi

    PAYLOAD=$(jq -n \
        --arg namespaceSlug "$NAMESPACE" \
        --arg semver "$SEMVER" \
        --arg skillSlug "$SKILL_SLUG" \
        --arg title "$SKILL_SLUG" \
        --arg description "" \
        --arg toolHarness "generic" \
        --arg visibility "org" \
        --arg url "$REPO_URL" \
        --arg ref "$REF" \
        --argjson subdir "$SUBDIR_JSON" \
        '{
            namespaceSlug: $namespaceSlug,
            semver: $semver,

            metadata: {
                skillSlug: $skillSlug,
                title: $title,
                description: $description,
                categories: [],
                tags: [],
                toolHarness: $toolHarness,
                usageExamples: null,
                visibility: $visibility,
                whatChanged: null
            },

            pointer: {
                url: $url,
                ref: $ref,
                subdir: $subdir
            }
        }'
    )

    RESPONSE=$(curl -sS \
        -w "\nHTTP_STATUS:%{http_code}" \
        -X POST "$SKILLY_URL/api/proposals" \
        -H "Content-Type: application/json" \
        -H "Cookie: $SKILLY_COOKIE" \
        --data "$PAYLOAD"
    )

    HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS" | cut -d: -f2)
    BODY=$(echo "$RESPONSE" | sed '/HTTP_STATUS:/d')

    if [ "$HTTP_STATUS" -ge 200 ] && [ "$HTTP_STATUS" -lt 300 ]; then
        echo "SUCCESS ($HTTP_STATUS)"
        SUCCESS=$((SUCCESS + 1))
    else
        echo "FAILED ($HTTP_STATUS)"
        echo "$BODY"
        FAILED=$((FAILED + 1))
    fi

    echo ""

    sleep 1

done

echo "========================================"
echo "Import completed"
echo "========================================"
echo "Found:    $SKILL_COUNT"
echo "Success:  $SUCCESS"
echo "Failed:   $FAILED"
echo "========================================"

