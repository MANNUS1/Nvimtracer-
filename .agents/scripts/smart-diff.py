#!/usr/bin/env python3
import json
import sys
import os

TRACK_FILE = "/tmp/agy-nvim-changes.json"

def main():
    # 1. Leer Payload desde stdin (proveído por Antigravity Hook)
    payload_str = sys.stdin.read()
    if not payload_str.strip():
        print("{}")
        return
        
    payload = json.loads(payload_str)
    transcript_path = payload.get("transcriptPath")
    
    # 2. Verificar si hay cambios registrados por Neovim
    data = {}
    if os.path.exists(TRACK_FILE):
        with open(TRACK_FILE, "r") as f:
            try:
                data = json.load(f)
            except Exception:
                pass
        
    # 3. Control de Flujo: Evitar spam en bucles internos.
    is_user_turn = True
    if transcript_path and os.path.exists(transcript_path):
        try:
            with open(transcript_path, "r") as f:
                lines = f.readlines()
                if lines:
                    last_line = json.loads(lines[-1])
                    if last_line.get("type") != "USER_INPUT":
                        is_user_turn = False
        except Exception:
            pass
            
    if not is_user_turn:
        print("{}")
        return
        
    # --- NUEVO: DETECCIÓN CRUD VÍA SNAPSHOT ---
    SNAPSHOT_FILE = "/tmp/agy-fs-snapshot.json"
    WORKSPACE_DIR = os.path.abspath(os.path.join(os.getcwd(), ".."))
    
    deleted_files = []
    created_files = []
    
    if os.path.exists(SNAPSHOT_FILE):
        try:
            with open(SNAPSHOT_FILE, "r") as f:
                snap_data = json.load(f)
                old_files = set(snap_data.get("files", []))
                
            # Obtener archivos actuales
            current_files = set()
            for root, dirs, set_files in os.walk(WORKSPACE_DIR):
                dirs[:] = [d for d in dirs if d not in ['.git', '.agents', 'node_modules', '.venv', '__pycache__']]
                for fl in set_files:
                    current_files.add(os.path.join(root, fl))
                    
            deleted_files = list(old_files - current_files)
            created_files = list(current_files - old_files)
        except Exception:
            pass

    # 4. Procesar la Heurística de Densidad para Modificaciones
    total_lines = 0
    full_diff = ""
    file_list = []
    
    for path, diff_text in data.items():
        if not isinstance(diff_text, str):
            continue
            
        lines = diff_text.split("\n")
        changed_lines = len([l for l in lines if (l.startswith("+") or l.startswith("-")) and not (l.startswith("+++") or l.startswith("---"))])
        total_lines += changed_lines
        
        full_diff += f"\n**Archivo Modificado:** `{path}`\n```diff\n{diff_text}\n```\n"
        file_list.append(path)
        
    if total_lines == 0 and not deleted_files and not created_files:
        print("{}")
        return
        
    # Construir el mensaje final combinando CRUD
    message = "> [!NOTE]\n> **[NEOVIM & FS DELTA TRACKER]**\n> Has realizado los siguientes cambios manuales desde nuestro último turno:\n\n"
    
    if deleted_files:
        message += "**Archivos Eliminados:**\n" + "\n".join([f"> - `{f}`" for f in deleted_files]) + "\n\n"
    
    if created_files:
        message += "**Archivos Creados Nuevos:**\n" + "\n".join([f"> - `{f}`" for f in created_files]) + "\n\n"
        
    if total_lines > 0:
        if total_lines < 50:
            message += f"**Modificaciones de Código:**\n{full_diff}"
        else:
            files = "\n> - ".join(file_list)
            message += f"**Modificaciones Masivas ({total_lines} líneas):**\n> Archivos alterados:\n> - {files}\n> *(Se omitió el diff completo por densidad de tokens)*"

    # 5. Purga y Debug Log
    try:
        with open("nvim_tracker.log", "a") as log:
            log.write("=== INYECCIÓN DE TURNO ===\n")
            log.write(message + "\n\n")
            
        with open(TRACK_FILE, "w") as f:
            f.write("{}")
    except Exception:
        pass

    # 6. Salida: Enviar el Ephemeral Message a Antigravity
    response = {
        "injectSteps": [
            {
                "ephemeralMessage": message
            }
        ]
    }
    print(json.dumps(response))

if __name__ == "__main__":
    main()
