#!/usr/bin/env python3
import sys
import json
import os
import glob

def main():
    try:
        input_data = sys.stdin.read()
        payload = json.loads(input_data)
    except Exception:
        sys.exit(0)

    workspaces = payload.get("workspacePaths", [])
    if not workspaces:
        print(json.dumps({}))
        return

    workspace = workspaces[0]
    agents_dir = os.path.join(workspace, ".agents")
    state_files = glob.glob(os.path.join(agents_dir, "nvim_state_*.json"))

    if not state_files:
        print(json.dumps({}))
        return

    changes = []
    for fpath in state_files:
        try:
            with open(fpath, "r") as f:
                for line in f:
                    if line.strip():
                        changes.append(json.loads(line))
            os.remove(fpath)
        except Exception:
            pass

    if not changes:
        print(json.dumps({}))
        return

    summary = "El usuario ha realizado los siguientes cambios manualmente en Neovim:\n"
    for change in changes:
        summary += f"\nFile: {change['file']}\nDiff:\n{change['diff']}\n"

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
