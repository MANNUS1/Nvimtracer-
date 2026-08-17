# Arquitectura de Tracking: Nvimtracker <-> Antigravity

## Filosofía de Diseño
El rastreo de modificaciones en el repositorio se rige por el principio de **Separación de Responsabilidades (Separation of Concerns)**. Para garantizar latencia cero y evitar la destrucción del contexto del LLM por operaciones masivas, el sistema divide el rastreo en dos capas estrictas:

### 1. Capa CRUD (Delegada a Snacks Explorer)
Todas las operaciones estructurales del sistema de archivos son interceptadas a través del módulo de explorador de Snacks (`snacks.nvim`), inyectando proxys (*monkey-patching*) en sus rutinas asíncronas.
- **Borrado (`d / ds`):** Interceptado vía `snacks.explorer.actions.trash`. Emite un delta semántico `+++ /dev/null`.
- **Renombramiento/Movimiento (`r / m`):** Interceptado vía `snacks.rename.rename_file`. Sobrescribe el callback `on_rename` para emitir un diff indicando el nuevo y antiguo path. Esto evita que el LLM alucine la destrucción y creación de un archivo nuevo masivo, ahorrando miles de tokens.
- **Creación (`a`):** Snacks genera un archivo de 0 bytes en disco. Se ignora intencionalmente en esta capa para evitar ruido en el contexto. El evento real de valor ocurre en la Capa Quirúrgica cuando el usuario deposita código.

### 2. Capa Quirúrgica (Delegada a Neovim Core)
Las alteraciones del contenido del código son interceptadas de forma nativa a través de los eventos de buffer de Neovim.
- **Generación de Delta (`BufWritePost`):** Cada vez que se presiona `C-s` o se guarda un archivo, un hilo asíncrono ejecuta `diff -u` entre la memoria RAM y el disco. 
- **Resolución de Creación:** Si un archivo recién creado en Snacks Explorer es guardado con texto por primera vez, esta capa detectará una base vacía (`""`) y enviará el 100% de la inserción como una inyección nueva.

## Manejo de Edge Cases y Fallos
- **Race Conditions (Condiciones de Carrera):** `agy_hook.py` realiza un renombramiento atómico (`os.rename`) del archivo JSON temporal al momento de leer, previniendo pérdida de datos si el usuario guarda código concurrentemente.
- **Poison Pills:** Un error de formato en el log asíncrono no colapsa el sistema; el parser JSON aísla la excepción a nivel de línea.
- **Context Blowout:** Los diffs masivos (> 2000 caracteres) que resultan del formateo automático se truncan de forma coercitiva en Python antes de inyectarse al LLM.
- **Auditoría Permanente:** Toda la telemetría enviada a Antigravity persiste en modo *append-only* en `.agents/injection_audit.log` para observabilidad en tiempo real.
