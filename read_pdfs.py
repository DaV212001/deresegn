import fitz
import sys

def extract_pdf(path, out_file, max_pages=None):
    try:
        with fitz.open(path) as doc:
            text = ""
            limit = len(doc)
            if max_pages is not None:
                limit = min(limit, max_pages)
            for i in range(limit):
                text += f"\n--- PAGE {i+1} ---\n"
                text += doc[i].get_text()
            with open(out_file, "w", encoding="utf-8") as f:
                f.write(text)
            print(f"Extracted {path} to {out_file}")
    except Exception as e:
        print(f"Error extracting {path}: {e}")

guideline_path = r"C:\Users\Abel Seyoum\Downloads\Mobile_Application_Security_Testing_Requirements_Document_4_2.pdf"
sample_path = r"C:\Users\Abel Seyoum\Downloads\Telegram Desktop\1772175903078-fx_doc_fortune_doc_merged (2).pdf"

extract_pdf(guideline_path, "guideline.txt")
extract_pdf(sample_path, "sample.txt", max_pages=48)
