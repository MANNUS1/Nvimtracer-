# Antigravity Neovim Tracker

Este proyecto sincroniza tus cambios manuales en Neovim con el contexto de Antigravity (AGY).

## Arquitectura Global

En lugar de configuraciones tediosas por repositorio, este sistema funciona a nivel global:
1. **Neovim (Lua)**: Un plugin en tu configuración de Neovim detecta modificaciones manuales en cualquier buffer, calcula el delta, y lo guarda bajo `.agents/nvim_state_<PID>.json` en la raíz del repositorio actual.
2. **Antigravity (Python/Hook)**: Un hook global en `~/.gemini/config/hooks.json` se ejecuta antes de cada turno. Lee estos archivos JSON, inyecta el delta como un mensaje efímero, y los purga, evitando ensuciar tu contexto.

## Requisitos

El script de Antigravity (Hook) está escrito en Python 3. Requiere que `python3` esté disponible en el `$PATH` de tu sistema (usando el shebang estándar `#!/usr/bin/env python3`).

## Instalación

Ejecuta el script de instalación para desplegar el hook y el plugin de Lua en tus configuraciones globales:

```bash
chmod +x install.sh
./install.sh
```
