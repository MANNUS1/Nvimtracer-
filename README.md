<div align="center">
  <h1>🔭 Usertracker Event Bus</h1>
  <p><strong>El puente de sincronización asíncrona entre tus manos (Neovim) y tu agente (Antigravity).</strong></p>
</div>

---

## 💡 ¿Qué es Usertracker?

Usertracker (Nvimtracer) es un sistema de telemetría hiper-optimizado diseñado para trabajar a nivel global. Observa silenciosamente tus operaciones y modificaciones manuales en Neovim y las inyecta en tiempo real como mensajes efímeros en el chat de Antigravity (AGY).

De esta forma, la IA siempre sabe **qué archivos tocaste, qué eliminaste y qué creaste** en segundo plano, previniendo asincronías y garantizando que el agente siempre opere con contexto fresco.

## 🏗 Arquitectura "Spooler"

El sistema funciona mediante un patrón de Productor/Consumidor de bajísima latencia:

1. **Productor Nvim (Lua)**: Escucha eventos nativos de guardado (`BufWritePost`) y genera parches (`diff -uwB`) ignorando ruido como espacios o saltos de línea vacíos. Los deltas se encolan asíncronamente en el directorio global temporal (`~/.local/share/usertracker/spool`).
2. **Deep CRUD Hooking (Snacks.nvim)**: Modifica en tiempo de ejecución las funciones internas del explorador nativo (`Snacks.input.input`, `Snacks.rename`, `actions.explorer_del`) para rastrear creaciones explícitas, borrados y movimientos sin esperar a que existan buffers activos.
3. **Consumidor AGY (Python)**: Un hook global ligero en `~/.gemini/config/hooks.json` drena la cola de eventos en la fracción de segundo previa al turno de la IA, filtrando a velocidad extrema solo los eventos que pertenecen a tu Workspace actual.

## 🚀 Características Destacadas

- **Global & Zero-Config**: Detecta de inmediato cualquier carpeta abierta en el sistema; sin dependencias o `.git` estrictos.
- **Aislamiento de Ruido**: Ignora buffers efímeros, terminales y binarios pesados (`.sqlite`, `.png`, `node_modules`).
- **Autogestionado**: Los archivos de la cola de eventos se auto-purguen conforme la IA los procesa. Cero degradación del disco.

## ⚙️ Instalación

```bash
git clone https://github.com/tu-usuario/nvimtracer.git
cd nvimtracer
chmod +x install.sh
./install.sh
```

> **Aviso:** Requiere `python3` y `diff` (`GNU diffutils`) instalados en el sistema. El soporte CRUD asume una versión moderna de Neovim y Snacks.nvim.
