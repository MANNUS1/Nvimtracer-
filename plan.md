# Arquitectura: Sincronización Heurística de Cambios Manuales (Neovim -> Antigravity)

## 1. El Problema Central
`git diff` es inútil para este caso de uso porque es agnóstico al autor: si yo (la IA) escribo código, Git lo registra igual que si lo escribes tú. Esto genera ruido. El objetivo es aislar y capturar **estrictamente las pulsaciones y cambios manuales que tú haces en Neovim**, aplicando heurísticas de compresión antes de inyectarlo en mi contexto.

## 2. Componente 1: El Motor de Tracking en Neovim (Lua)
Diseñaremos un módulo en Lua para tu configuración de Neovim basado en la detección de "Baselines" temporales:

*   **Generación de Baseline (`BufReadPost`, `FileChangedShellPost`):** 
    Cuando abres un archivo, o cuando Neovim detecta que la IA modificó el archivo externamente y lo recarga (`autoread`), Neovim guarda silenciosamente una copia temporal del estado actual del buffer. Este es nuestro "punto cero".
*   **Cálculo de Delta (`BufWritePost`):** 
    Cada vez que tú presionas `<C-s>` o guardas manualmente, Neovim calcula en background un diff unificado entre el archivo temporal (Baseline) y tu buffer actual.
*   **Volcado al Workspace:** 
    Neovim guarda o actualiza este diff en un registro central del proyecto (ej. `.agents/nvim_manual_state.json`). Este registro contiene exclusivamente lo que *tú* cambiaste.

## 3. Componente 2: El Interceptor de Antigravity (`PreInvocation` Hook)
No usaremos un envío activo desde Neovim (que generaría spam), sino que Antigravity "jalará" el dato justo cuando sea necesario a través de un Hook nativo:

*   **Disparo:** Fracciones de segundo antes de que el modelo reciba tu prompt, se ejecuta el hook `PreInvocation`.
*   **Lectura y Heurística (Script Bash/Python):**
    El hook lee `.agents/nvim_manual_state.json` y toma decisiones basadas en densidad de información:
    *   *Modificación Quirúrgica (< 50 líneas cambiadas):* Extrae el diff completo.
    *   *Modificación Masiva (>= 50 líneas cambiadas):* Extrae solo los nombres de los archivos alterados para evitar saturar mis tokens y hacerme perder foco en tu prompt real.
*   **Inyección Efímera y Purga:** 
    El script me envía este resumen como un `ephemeralMessage` (solo lo veo en ese turno, no contamina el historial largo de la conversación) y, acto seguido, **vacía el registro JSON**. De esta forma, cada turno inicia limpio.

## 4. Flujo de Vida
1. **Yo (IA) modifico código** -> Neovim recarga -> Baseline se reinicia.
2. **Tú escribes código** -> Guardas -> Neovim guarda tu Delta en el JSON local.
3. **Me pides ayuda en el chat** -> Hook lee el JSON -> Me inyecta tu código -> Hook purga el JSON.

---
*Esperando confirmación del usuario para proceder con la implementación.*
