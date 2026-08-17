#!/usr/bin/env python3
import sys
import json
import os
import glob
import uuid

MAX_DIFF_LENGTH = 2000  # Character limit for a single diff to prevent context blowout

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

    workspace = workspaces[0]
    agents_dir = os.path.join(workspace, ".agents")
    state_files = glob.glob(os.path.join(agents_dir, "nvim_state_*.json"))

    if not state_files:
        emit_empty_and_exit()

    changes = []
    
    for original_fpath in state_files:
        # 1. Atomic rename to prevent race conditions (Data Loss prevention)
        processing_fpath = f"{original_fpath}.processing.{uuid.uuid4().hex}"
        try:
            os.rename(original_fpath, processing_fpath)
        except Exception:
            # File might have been processed by another hook instance
            continue
            
        try:
            with open(processing_fpath, "r") as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        # 2. Poison pill prevention (isolate exceptions per line)
                        changes.append(json.loads(line))
                    except Exception:
                        pass
        finally:
            # 3. Always clean up the processed file, regardless of parsing errors
            try:
                os.remove(processing_fpath)
            except OSError:
                pass

    if not changes:
        emit_empty_and_exit()

    summary = "El usuario ha modificado código manualmente en el editor (Neovim). Aquí tienes el diff:\n"
    for change in changes:
        diff = change.get('diff', '')
        # 4. Context Blowout prevention
        if len(diff) > MAX_DIFF_LENGTH:
            diff = diff[:MAX_DIFF_LENGTH] + "\n...[DIFF TRUNCADO: Demasiado grande para el contexto]"
            
        summary += f"\nArchivo: {change.get('file', 'Desconocido')}\nDiff:\n{diff}\n"

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
