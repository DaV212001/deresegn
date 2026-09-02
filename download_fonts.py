import urllib.request
import re
import os

os.makedirs('assets/fonts', exist_ok=True)

def download_font(family, wght, filename):
    url = f"https://fonts.googleapis.com/css2?family={family}:wght@{wght}"
    # Use a basic user agent to get TTF
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 6.0)'})
    try:
        with urllib.request.urlopen(req) as response:
            css = response.read().decode('utf-8')
            # Look for url(...)
            match = re.search(r"url\((https://fonts\.gstatic\.com[^)]+)\)", css)
            if not match:
                match = re.search(r"url\('(https://fonts\.gstatic\.com[^)]+)'\)", css)
            if match:
                ttf_url = match.group(1)
                print(f"Downloading {filename} from {ttf_url}")
                req2 = urllib.request.Request(ttf_url, headers={'User-Agent': 'Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 6.0)'})
                with urllib.request.urlopen(req2) as resp2:
                    with open(f"assets/fonts/{filename}", 'wb') as f:
                        f.write(resp2.read())
            else:
                print(f"Could not find TTF for {family} {wght}")
                print(css)
    except Exception as e:
        print(f"Failed to fetch CSS: {e}")

download_font("Inter", "400", "Inter-Regular.ttf")
download_font("Inter", "600", "Inter-SemiBold.ttf")
download_font("Inter", "700", "Inter-Bold.ttf")
download_font("JetBrains+Mono", "500", "JetBrainsMono-Medium.ttf")
print("Done.")
