#!/usr/bin/env bash
set -e

echo "Instalando sistema global de tracking Neovim <-> Antigravity..."

# 1. Instalar Hook Global de Antigravity
AGY_CONFIG_DIR="$HOME/.gemini/config"
HOOK_SCRIPT="$AGY_CONFIG_DIR/scripts/nvim_tracker_hook.py"

mkdir -p "$AGY_CONFIG_DIR/scripts"
cp agy_hook.py "$HOOK_SCRIPT"
chmod +x "$HOOK_SCRIPT"

HOOKS_JSON="$AGY_CONFIG_DIR/hooks.json"
if [ ! -f "$HOOKS_JSON" ]; then
    echo "{}" > "$HOOKS_JSON"
fi

# Inyectar el hook de forma segura
python3 -c '
import json
import sys
import os

hook_path = sys.argv[1]
script_path = sys.argv[2]

try:
    with open(hook_path, "r") as f:
        data = json.load(f)
except:
    data = {}

if "nvim-tracker" not in data:
    data["nvim-tracker"] = {}

data["nvim-tracker"]["PreInvocation"] = [
    {
        "type": "command",
        "command": script_path
    }
]

with open(hook_path, "w") as f:
    json.dump(data, f, indent=2)
' "$HOOKS_JSON" "$HOOK_SCRIPT"

# 2. Instalar el plugin de Neovim
NVIM_LUA_DIR="$HOME/.config/nvim/lua"
mkdir -p "$NVIM_LUA_DIR"
cp nvim_tracker.lua "$NVIM_LUA_DIR/agy_tracker.lua"

NVIM_INIT="$HOME/.config/nvim/init.lua"
if [ ! -f "$NVIM_INIT" ]; then
    touch "$NVIM_INIT"
fi

if ! grep -q 'require("agy_tracker").setup()' "$NVIM_INIT"; then
    echo "" >> "$NVIM_INIT"
    echo '-- Antigravity Neovim Tracker' >> "$NVIM_INIT"
    echo 'require("agy_tracker").setup()' >> "$NVIM_INIT"
    echo "✓ Plugin inyectado automáticamente en $NVIM_INIT"
else
    echo "✓ El plugin ya estaba inyectado en $NVIM_INIT"
fi

echo "Instalación y configuración completadas."
