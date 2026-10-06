#!/bin/bash
set -e

MODEL_ID="${MODEL_ID:-3327244}"
MODEL_DIR="${MODEL_DIR:-/workspace/runpod-slim/ComfyUI/models/diffusion_models}"

echo "======================================"
echo "   CIVITAI MODEL DOWNLOADER"
echo "======================================"
echo "MODEL_ID  : $MODEL_ID"
echo "MODEL_DIR : $MODEL_DIR"

if [ -z "$CIVITAI_TOKEN" ]; then
    echo "ERROR: CIVITAI_TOKEN is missing"
    exit 1
fi

apt-get update -qq
apt-get install -y -qq curl jq

mkdir -p "$MODEL_DIR"

echo "Getting model information..."

INFO=$(curl -fsSL \
    --retry 5 \
    --retry-delay 3 \
    -H "Authorization: Bearer $CIVITAI_TOKEN" \
    -H "Accept: application/json" \
    "https://civitai.com/api/v1/model-versions/$MODEL_ID")

NAME=$(echo "$INFO" | jq -r '.files[0].name')
URL=$(echo "$INFO" | jq -r '.files[0].downloadUrl')

echo "Model  : $(echo "$INFO" | jq -r '.model.name // "unknown"')"
echo "Version: $(echo "$INFO" | jq -r '.name // "unknown"')"
echo "File   : $NAME"

if [ -z "$NAME" ] || [ "$NAME" = "null" ]; then
    echo "ERROR: Model file not found"
    echo "$INFO" | jq .
    exit 1
fi

if [ -z "$URL" ] || [ "$URL" = "null" ]; then
    echo "ERROR: Download URL not found"
    exit 1
fi

TARGET="$MODEL_DIR/$NAME"

if [ -s "$TARGET" ]; then
    echo "Already exists - SKIP"
else
    echo "Downloading..."
    echo "Destination: $TARGET"

    curl -L \
        --fail \
        --retry 10 \
        --retry-delay 5 \
        --continue-at - \
        -H "Authorization: Bearer $CIVITAI_TOKEN" \
        -o "$TARGET" \
        "$URL"
fi

echo ""
echo "======================================"
echo "       DOWNLOAD SUCCESS"
echo "======================================"

ls -lh "$TARGET"
