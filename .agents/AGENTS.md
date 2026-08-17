---
name: usertracker-rules
description: Reglas fundamentales de ejecución e interacción para el proyecto Usertracker.
---

# Proyecto Usertracker

**Objetivo Central:** Rastrear y registrar los cambios manuales del usuario a través de todos sus repositorios, aislando las acciones automatizadas de la IA (Usertracker Event Bus).

## Protocolo de Ejecución y Aprobación
1. **Fricción por Aprobación:** Tienes prohibido tocar, modificar o sobreescribir código en el disco sin la aprobación explícita del usuario.
2. **Propuesta Deductiva:** Debes presentar y someter a debate técnico cualquier propuesta de diseño o modificación antes de pasar a la fase de escritura.
3. **Instalación Obligatoria:** Tras ejecutar los cambios autorizados en el código fuente, es imperativo compilar o desplegar utilizando el script de instalación (`./install.sh`).
4. **Resumen Visual:** Una vez instalados los cambios, provee un resumen visual conciso en texto plano documentando el estado resultante del sistema.

## Restricciones de Interfaz (CLI)
- **Cero Mermaid:** El entorno de trabajo es estrictamente terminal (Antigravity CLI). Está terminantemente prohibido usar diagramas Mermaid. Toda representación arquitectónica o visual debe estructurarse usando **arte ASCII puro**.
