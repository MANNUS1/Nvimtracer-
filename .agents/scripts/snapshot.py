#!/usr/bin/env python3
import json
import os
import sys

SNAPSHOT_FILE = "/tmp/agy-fs-snapshot.json"
WORKSPACE_DIR = os.path.abspath(os.path.join(os.getcwd(), ".."))

def get_all_files():
    files_set = set()
    for root, dirs, set_files in os.walk(WORKSPACE_DIR):
        # Ignorar carpetas ruidosas
        dirs[:] = [d for d in dirs if d not in ['.git', '.agents', 'node_modules', '.venv', '__pycache__']]
        for f in set_files:
            files_set.add(os.path.join(root, f))
    return list(files_set)

def main():
    payload_str = sys.stdin.read()
    if not payload_str.strip():
        return
        
    payload = json.loads(payload_str)
    
    # Tomar snapshot de todos los archivos actuales (estado final después de que la IA actuó)
    current_files = get_all_files()
    
    with open(SNAPSHOT_FILE, "w") as f:
        json.dump({"files": current_files}, f)
        
    # Responder con el contrato exacto del hook 'Stop' (permitir que el agente se detenga)
    print(json.dumps({"decision": "stop"}))

if __name__ == "__main__":
    main()
