#!/usr/bin/env python3
import sys
import json
import os
import glob

MAX_DIFF_LENGTH = 2000

def emit_empty_and_exit():
    print(json.dumps({}))
    sys.exit(0)

def main():
    try:
        input_data = sys.stdin.read()
        if not input_data.strip():
            emit_empty_and_exit()
        payload = json.loads(input_data)
    except Exception:
        emit_empty_and_exit()

    workspaces = payload.get("workspacePaths", [])
    if not workspaces:
        emit_empty_and_exit()

    active_workspace = os.path.abspath(workspaces[0])
    
    spool_dir = os.path.expanduser("~/.local/share/usertracker/spool")
    if not os.path.exists(spool_dir):
        emit_empty_and_exit()

    state_files = glob.glob(os.path.join(spool_dir, "*.json"))
    if not state_files:
        emit_empty_and_exit()

    changes = []
    
    for original_fpath in state_files:
        basename = os.path.basename(original_fpath)
        
        # Filtro de I/O de alta velocidad (sin abrir el archivo)
        if "@@_" in basename:
            encoded_repo = basename.split("@@_")[0]
            event_repo = encoded_repo.replace("@@", "/")
            if not (active_workspace.startswith(event_repo) or event_repo.startswith(active_workspace)):
                continue # No es nuestro repo, ignorar (dejamos el archivo para la otra instancia)
                
        processing_fpath = f"{original_fpath}.processing"
        try:
            os.rename(original_fpath, processing_fpath)
        except OSError:
            continue
            
        try:
            with open(processing_fpath, "r") as f:
                event = json.load(f)
                
            changes.append(event)
            # Lo consumimos, lo borramos
            try:
                os.remove(processing_fpath)
            except OSError:
                pass
        except Exception:
            try:
                os.remove(processing_fpath)
            except OSError:
                pass

    if not changes:
        emit_empty_and_exit()

    # Sort changes by timestamp
    changes.sort(key=lambda x: x.get("timestamp", 0))

    summary = "El usuario ha modificado código manualmente. Aquí tienes los diffs capturados:\n"
    for change in changes:
        diff = change.get('diff', '')
        if len(diff) > MAX_DIFF_LENGTH:
            diff = diff[:MAX_DIFF_LENGTH] + "\n...[DIFF TRUNCADO: Demasiado grande para el contexto]"
            
        summary += f"\nArchivo: {change.get('file', 'Desconocido')} (Origen: {change.get('origin', 'Desconocido')})\nDiff:\n{diff}\n"

    # Auditoría
    audit_log_path = os.path.expanduser("~/.local/share/usertracker/audit.log")
    try:
        from datetime import datetime
        with open(audit_log_path, "a") as logf:
            ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            logf.write(f"[{ts}] --- INYECCIÓN ENVIADA AL WORKSPACE {active_workspace} ---\n")
            logf.write(summary + "\n\n")
    except Exception:
        pass

    out = {
        "injectSteps": [
            {
                "ephemeralMessage": summary
            }
        ]
    }
    
    print(json.dumps(out))

if __name__ == "__main__":
    main()
