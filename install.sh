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

# ======================================
# INSTALL WORKFLOW
# ======================================

COMFY_DIR="/workspace/runpod-slim/ComfyUI"
WORKFLOW_DIR="$COMFY_DIR/user/default/workflows"

mkdir -p "$WORKFLOW_DIR"

cp "$(dirname "$0")/workflows/moodyKrea2Minimal_v40.json" \
   "$WORKFLOW_DIR/moodyKrea2Minimal_v40.json"

echo ""
echo "Workflow installed:"
ls -lh "$WORKFLOW_DIR/moodyKrea2Minimal_v40.json"


# ==============================
# PERSONAL LORA - GOOGLE DRIVE
# ==============================

COMFY_DIR="/workspace/runpod-slim/ComfyUI"
LORA_DIR="$COMFY_DIR/models/loras"

LORA_ID="1cM6S0oilj8NC5HVgR8psjCyt_UDdmiKl"
LORA_NAME="personal_lora.safetensors"

mkdir -p "$LORA_DIR"

echo "======================================"
echo "   PERSONAL LORA"
echo "======================================"

if [ -f "$LORA_DIR/$LORA_NAME" ] && [ -s "$LORA_DIR/$LORA_NAME" ]; then
    echo "LoRA already exists - SKIP"
else
    echo "Installing gdown..."
    pip install -q -U gdown

    echo "Downloading personal LoRA..."

    gdown \
      "https://drive.google.com/file/d/$LORA_ID/view?usp=drive_link" \
      -O "$LORA_DIR/$LORA_NAME" \
      --continue
fi

ls -lh "$LORA_DIR/$LORA_NAME"


# ==============================
# CIVITAI LORA
# ==============================

COMFY_DIR="/workspace/runpod-slim/ComfyUI"
LORA_DIR="$COMFY_DIR/models/loras"

LORA_VERSION_ID="3215719"

mkdir -p "$LORA_DIR"

echo "======================================"
echo "   CIVITAI LORA"
echo "======================================"
echo "Version ID : $LORA_VERSION_ID"
echo "Destination: $LORA_DIR"

if [ -z "$CIVITAI_TOKEN" ]; then
    echo "ERROR: CIVITAI_TOKEN is missing"
    exit 1
fi

INFO=$(curl -fsSL \
    --retry 5 \
    --retry-delay 3 \
    -H "Authorization: Bearer $CIVITAI_TOKEN" \
    -H "Accept: application/json" \
    "https://civitai.com/api/v1/model-versions/$LORA_VERSION_ID")

LORA_NAME=$(echo "$INFO" | jq -r '.files[0].name')
LORA_URL=$(echo "$INFO" | jq -r '.files[0].downloadUrl')

if [ -z "$LORA_NAME" ] || [ "$LORA_NAME" = "null" ]; then
    echo "ERROR: LoRA file not found"
    echo "$INFO" | jq .
    exit 1
fi

if [ -z "$LORA_URL" ] || [ "$LORA_URL" = "null" ]; then
    echo "ERROR: LoRA download URL not found"
    exit 1
fi

TARGET="$LORA_DIR/$LORA_NAME"

if [ -s "$TARGET" ]; then
    echo "LoRA already exists - SKIP"
else
    echo "Downloading: $LORA_NAME"

    curl -L \
        --fail \
        --retry 10 \
        --retry-delay 5 \
        --continue-at - \
        -H "Authorization: Bearer $CIVITAI_TOKEN" \
        -o "$TARGET" \
        "$LORA_URL"
fi

echo "LoRA installed:"
ls -lh "$TARGET"


# ==============================
# KREA 2 MODELS
# ==============================

COMFY_DIR="/workspace/runpod-slim/ComfyUI"

VAE_DIR="$COMFY_DIR/models/vae"
TEXT_ENCODER_DIR="$COMFY_DIR/models/text_encoders"

mkdir -p "$VAE_DIR" "$TEXT_ENCODER_DIR"

echo "======================================"
echo "   KREA 2 MODELS"
echo "======================================"

# ------------------------------
# VAE
# ------------------------------

VAE_FILE="$VAE_DIR/qwen_image_vae.safetensors"

if [ -s "$VAE_FILE" ]; then
    echo "VAE already exists - SKIP"
else
    echo "Downloading VAE..."

    wget -c \
      "https://huggingface.co/Comfy-Org/Krea-2/resolve/main/vae/qwen_image_vae.safetensors" \
      -O "$VAE_FILE"
fi

# ------------------------------
# TEXT ENCODER
# ------------------------------

TEXT_FILE="$TEXT_ENCODER_DIR/qwen3vl_4b_fp8_scaled.safetensors"

if [ -s "$TEXT_FILE" ]; then
    echo "Text Encoder already exists - SKIP"
else
    echo "Downloading Text Encoder..."

    wget -c \
      "https://huggingface.co/Comfy-Org/Krea-2/resolve/main/text_encoders/qwen3vl_4b_fp8_scaled.safetensors" \
      -O "$TEXT_FILE"
fi

echo "Krea-2 models installed."


# ==============================
# RGTREE COMFY
# ==============================

CUSTOM_NODE_DIR="$COMFY_DIR/custom_nodes/rgthree-comfy"

if [ -d "$CUSTOM_NODE_DIR" ]; then
    echo "rgthree-comfy already installed - UPDATE"

    cd "$CUSTOM_NODE_DIR"
    git pull
else
    echo "Installing rgthree-comfy..."

    git clone \
      https://github.com/rgthree/rgthree-comfy.git \
      "$CUSTOM_NODE_DIR"
fi

echo "rgthree-comfy installed."
