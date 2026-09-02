import sys
import pypdf

pdf_path = r"C:\Users\Abel Seyoum\Downloads\Mobile_Application_Security_Testing_Requirements_Document_4_2.pdf"
out_path = r"C:\flutter_dev\deresegn\pdf_text.txt"

try:
    with open(pdf_path, "rb") as f:
        reader = pypdf.PdfReader(f)
        text = []
        for i, page in enumerate(reader.pages):
            text.append(f"--- PAGE {i+1} ---")
            text.append(page.extract_text())
            
    with open(out_path, "w", encoding="utf-8", errors="replace") as f:
        f.write("\n".join(text))
    print("PDF text extracted successfully.")
except Exception as e:
    print(f"Error: {e}")
