# Antigravity Neovim Tracker

Este proyecto sincroniza tus cambios manuales en Neovim con el contexto de Antigravity (AGY).

## Arquitectura Global

En lugar de configuraciones tediosas por repositorio, este sistema funciona a nivel global:
1. **Neovim (Lua)**: Un plugin en tu configuración de Neovim detecta modificaciones manuales en cualquier buffer, calcula el delta, y lo guarda bajo `.agents/nvim_state_<PID>.json` en la raíz del repositorio actual.
2. **Antigravity (Python/Hook)**: Un hook global en `~/.gemini/config/hooks.json` se ejecuta antes de cada turno. Lee estos archivos JSON, inyecta el delta como un mensaje efímero, y los purga, evitando ensuciar tu contexto.

## Compatibilidad NixOS

El script de Antigravity utiliza un shebang de `nix-shell` para ejecutar Python 3 de forma efímera. Esto asegura que el hook funcione sin requerir una instalación global impura de Python en tu sistema.

## Instalación

Ejecuta el script de instalación para desplegar el hook y el plugin de Lua en tus configuraciones globales:

```bash
chmod +x install.sh
./install.sh
```
