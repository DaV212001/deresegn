import base64
import requests
import json
import os

def generate_mermaid_image(mmd_file, out_file):
    try:
        with open(mmd_file, 'r', encoding='utf-8') as f:
            code = f.read()
        
        payload = {
            "code": code,
            "mermaid": {"theme": "default"}
        }
        
        json_str = json.dumps(payload)
        encoded = base64.urlsafe_b64encode(json_str.encode('utf-8')).decode('utf-8')
        
        url = f"https://mermaid.ink/img/{encoded}"
        print(f"Downloading from {url}")
        
        r = requests.get(url)
        if r.status_code == 200:
            with open(out_file, 'wb') as f:
                f.write(r.content)
            print(f"Saved {out_file}")
        else:
            print(f"Failed to generate {out_file}: {r.status_code}")
            print(r.text)
    except Exception as e:
        print(f"Error processing {mmd_file}: {e}")

# generate_mermaid_image('dfd.mmd', 'dfd.png')
# generate_mermaid_image('sys_arch.mmd', 'sys_arch.png')
generate_mermaid_image('erd.mmd', 'erd.png')
