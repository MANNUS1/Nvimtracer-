#!/usr/bin/env bash
set -e

echo "Instalando Usertracker Event Bus (Neovim <-> Antigravity)..."

# 1. Crear directorios globales
USERTRACKER_DIR="$HOME/.local/share/usertracker"
SPOOL_DIR="$USERTRACKER_DIR/spool"
mkdir -p "$SPOOL_DIR"

# 2. Instalar Hook Global de Antigravity
AGY_CONFIG_DIR="$HOME/.gemini/config"
HOOK_SCRIPT="$AGY_CONFIG_DIR/scripts/usertracker_hook.py"

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

hook_path = sys.argv[1]
script_path = sys.argv[2]

try:
    with open(hook_path, "r") as f:
        data = json.load(f)
except:
    data = {}

if "usertracker" not in data:
    data["usertracker"] = {}

data["usertracker"]["PreInvocation"] = [
    {
        "type": "command",
        "command": script_path
    }
]

# Remover viejo hook si existe
if "nvim-tracker" in data:
    del data["nvim-tracker"]

with open(hook_path, "w") as f:
    json.dump(data, f, indent=2)
' "$HOOKS_JSON" "$HOOK_SCRIPT"

# 3. Instalar el plugin de Neovim
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

echo "Instalación de Usertracker completada con éxito."
