#!/bin/bash
set -e

COMFY_DIR="/workspace/runpod-slim/ComfyUI"

MODEL_ID="${MODEL_ID:-3327244}"
MODEL_DIR="${MODEL_DIR:-$COMFY_DIR/models/diffusion_models}"

echo "======================================"
echo "   RUNPOD COMFYUI INSTALLER"
echo "======================================"
echo "ComfyUI : $COMFY_DIR"
echo "Model ID: $MODEL_ID"
echo ""

# ======================================
# INSTALL SYSTEM PACKAGES
# ======================================

echo "Installing system packages..."

apt-get update -qq
apt-get install -y -qq curl jq git wget

mkdir -p "$MODEL_DIR"


# ======================================
# CIVITAI MAIN MODEL
# ======================================

echo ""
echo "======================================"
echo "   CIVITAI MAIN MODEL"
echo "======================================"

if [ -z "$CIVITAI_TOKEN" ]; then
    echo "ERROR: CIVITAI_TOKEN is missing"
    exit 1
fi

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

ls -lh "$TARGET"


# ======================================
# CIVITAI LORAS
# ======================================

echo ""
echo "======================================"
echo "   CIVITAI LORAS"
echo "======================================"

LORA_DIR="$COMFY_DIR/models/loras"

mkdir -p "$LORA_DIR"

CIVITAI_LORA_VERSIONS=(
    "3215719"
    "3116175"
    "3105253"
    "3068874"
    "3122721"
)

for LORA_VERSION_ID in "${CIVITAI_LORA_VERSIONS[@]}"; do

    echo ""
    echo "--------------------------------------"
    echo "LoRA Version: $LORA_VERSION_ID"
    echo "--------------------------------------"

    INFO=$(curl -fsSL \
        --retry 5 \
        --retry-delay 3 \
        -H "Authorization: Bearer $CIVITAI_TOKEN" \
        -H "Accept: application/json" \
        "https://civitai.com/api/v1/model-versions/$LORA_VERSION_ID")

    LORA_NAME=$(echo "$INFO" | jq -r '.files[0].name')
    LORA_URL=$(echo "$INFO" | jq -r '.files[0].downloadUrl')

    echo "File: $LORA_NAME"

    if [ -z "$LORA_NAME" ] || [ "$LORA_NAME" = "null" ]; then
        echo "ERROR: LoRA file not found for version $LORA_VERSION_ID"
        echo "$INFO" | jq .
        exit 1
    fi

    if [ -z "$LORA_URL" ] || [ "$LORA_URL" = "null" ]; then
        echo "ERROR: Download URL not found"
        exit 1
    fi

    TARGET="$LORA_DIR/$LORA_NAME"

    if [ -s "$TARGET" ]; then
        echo "Already exists - SKIP"
    else
        echo "Downloading..."

        curl -L \
            --fail \
            --retry 10 \
            --retry-delay 5 \
            --continue-at - \
            -H "Authorization: Bearer $CIVITAI_TOKEN" \
            -o "$TARGET" \
            "$LORA_URL"

        echo "Downloaded:"
        ls -lh "$TARGET"
    fi

done

echo ""
echo "All Civitai LoRAs installed."

# ======================================
# PERSONAL LORA - GOOGLE DRIVE
# ======================================

echo ""
echo "======================================"
echo "   PERSONAL LORA - GOOGLE DRIVE"
echo "======================================"

LORA_ID="1cM6S0oilj8NC5HVgR8psjCyt_UDdmiKl"
LORA_NAME="personal_lora.safetensors"

mkdir -p "$LORA_DIR"

if [ -s "$LORA_DIR/$LORA_NAME" ]; then
    echo "Personal LoRA already exists - SKIP"
else
    echo "Installing gdown..."

    pip install -q -U gdown

    echo "Downloading personal LoRA..."

    gdown \
        "https://drive.google.com/uc?id=$LORA_ID" \
        -O "$LORA_DIR/$LORA_NAME" \
        --continue
fi

ls -lh "$LORA_DIR/$LORA_NAME"


# ======================================
# KREA 2 VAE
# ======================================

echo ""
echo "======================================"
echo "   KREA 2 VAE"
echo "======================================"

VAE_DIR="$COMFY_DIR/models/vae"
VAE_FILE="$VAE_DIR/qwen_image_vae.safetensors"

mkdir -p "$VAE_DIR"

if [ -s "$VAE_FILE" ]; then
    echo "VAE already exists - SKIP"
else
    wget -c \
        "https://huggingface.co/Comfy-Org/Krea-2/resolve/main/vae/qwen_image_vae.safetensors" \
        -O "$VAE_FILE"
fi

ls -lh "$VAE_FILE"


# ======================================
# KREA 2 TEXT ENCODER
# ======================================

echo ""
echo "======================================"
echo "   KREA 2 TEXT ENCODER"
echo "======================================"

TEXT_ENCODER_DIR="$COMFY_DIR/models/text_encoders"
TEXT_FILE="$TEXT_ENCODER_DIR/qwen3vl_4b_fp8_scaled.safetensors"

mkdir -p "$TEXT_ENCODER_DIR"

if [ -s "$TEXT_FILE" ]; then
    echo "Text Encoder already exists - SKIP"
else
    wget -c \
        "https://huggingface.co/Comfy-Org/Krea-2/resolve/main/text_encoders/qwen3vl_4b_fp8_scaled.safetensors" \
        -O "$TEXT_FILE"
fi

ls -lh "$TEXT_FILE"


# ======================================
# RGTREE COMFY
# ======================================

echo ""
echo "======================================"
echo "   RGTREE COMFY"
echo "======================================"

CUSTOM_NODE_DIR="$COMFY_DIR/custom_nodes/rgthree-comfy"

if [ -d "$CUSTOM_NODE_DIR/.git" ]; then
    echo "rgthree-comfy already installed - UPDATE"

    cd "$CUSTOM_NODE_DIR"
    git pull --ff-only
else
    echo "Installing rgthree-comfy..."

    rm -rf "$CUSTOM_NODE_DIR"

    git clone \
        https://github.com/rgthree/rgthree-comfy.git \
        "$CUSTOM_NODE_DIR"
fi

echo "rgthree-comfy installed."


# ======================================
# INSTALL WORKFLOW
# ======================================

echo ""
echo "======================================"
echo "   INSTALL WORKFLOW"
echo "======================================"

WORKFLOW_DIR="$COMFY_DIR/user/default/workflows"

mkdir -p "$WORKFLOW_DIR"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$SCRIPT_DIR/workflows/moodyKrea2Minimal_v40.json" ]; then

    cp \
        "$SCRIPT_DIR/workflows/moodyKrea2Minimal_v40.json" \
        "$WORKFLOW_DIR/moodyKrea2Minimal_v40.json"

    echo "Workflow installed:"
    ls -lh "$WORKFLOW_DIR/moodyKrea2Minimal_v40.json"

else

    echo "WARNING: Workflow file not found:"
    echo "$SCRIPT_DIR/workflows/moodyKrea2Minimal_v40.json"

fi


# ======================================
# DONE
# ======================================

echo ""
echo "======================================"
echo "       INSTALLATION COMPLETE"
echo "======================================"

echo ""
echo "Models:"
echo "  $MODEL_DIR"
echo "  $LORA_DIR"
echo "  $VAE_DIR"
echo "  $TEXT_ENCODER_DIR"

echo ""
echo "Custom Nodes:"
echo "  $CUSTOM_NODE_DIR"

echo ""
echo "Workflow:"
echo "  $WORKFLOW_DIR/moodyKrea2Minimal_v40.json"

echo ""
echo "DONE."
