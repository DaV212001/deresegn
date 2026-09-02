"""
Generate PDF documents from the Security Assessment Submission markdown files.
Uses fpdf2 with TTF Unicode fonts and diagram images embedded.
"""
import os
import re
from fpdf import FPDF

SUBMISSION_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(SUBMISSION_DIR)
FONT_DIR = os.path.join(PROJECT_DIR, "assets", "fonts")

DIAGRAM_IMAGES = {
    "01": {
        "srs_invoice_flow": os.path.join(SUBMISSION_DIR, "srs_invoice_flow.png"),
        "srs_auth_flow": os.path.join(SUBMISSION_DIR, "srs_auth_flow.png"),
    },
    "02": {
        "mobile_arch": os.path.join(SUBMISSION_DIR, "mobile_architecture_layers.png"),
        "system_arch": os.path.join(SUBMISSION_DIR, "system_architecture.png"),
        "dfd": os.path.join(SUBMISSION_DIR, "data_flow_diagram.png"),
    },
    "03": {
        "auth_flow": os.path.join(SUBMISSION_DIR, "auth_flow_diagram.png"),
    },
    "06": {
        "data_storage": os.path.join(SUBMISSION_DIR, "data_storage_diagram.png"),
    },
    "08": {
        "api_interaction": os.path.join(SUBMISSION_DIR, "api_interaction_diagram.png"),
    },
}

CONTACT_EMAIL = "amanuielt@mssethiopia.com"
CONTACT_PHONE = "+251 911 058 179"


def sanitize(text):
    """Replace problematic Unicode chars with ASCII equivalents."""
    text = text.replace("\u2014", "-")   # em-dash
    text = text.replace("\u2013", "-")   # en-dash
    text = text.replace("\u2018", "'")   # left single quote
    text = text.replace("\u2019", "'")   # right single quote
    text = text.replace("\u201c", '"')   # left double quote
    text = text.replace("\u201d", '"')   # right double quote
    text = text.replace("\u2022", "-")   # bullet
    text = text.replace("\u2026", "...") # ellipsis
    text = text.replace("\u2192", "->")  # right arrow
    text = text.replace("\u2190", "<-")  # left arrow
    text = text.replace("\u2194", "<->") # double arrow
    text = text.replace("\u25bc", "v")   # down triangle
    text = text.replace("\u25b6", ">")   # right triangle
    text = text.replace("\u2713", "[x]") # check
    text = text.replace("\u2717", "[ ]") # cross
    text = text.replace("\u2610", "[ ]") # ballot box
    text = text.replace("\u2611", "[x]") # ballot box checked
    text = text.replace("\u2612", "[x]") # ballot box with X
    text = text.replace("\u2500", "-")   # box drawing
    text = text.replace("\u2502", "|")   # box drawing
    text = text.replace("\u250c", "+")   # box drawing
    text = text.replace("\u2510", "+")
    text = text.replace("\u2514", "+")
    text = text.replace("\u2518", "+")
    text = text.replace("\u251c", "+")
    text = text.replace("\u2524", "+")
    text = text.replace("\u252c", "+")
    text = text.replace("\u2534", "+")
    text = text.replace("\u253c", "+")
    text = text.replace("\u2588", "#")   # full block
    text = text.replace("\u25cf", "*")   # black circle
    # Remove any remaining non-latin-1 chars
    return text.encode("latin-1", errors="replace").decode("latin-1")


HEADER_IMG = os.path.join(SUBMISSION_DIR, "letterhead_image2.png")
FOOTER_IMG = os.path.join(SUBMISSION_DIR, "letterhead_image3.png")


class DocPDF(FPDF):
    def __init__(self, title="", doc_num=""):
        super().__init__()
        self.doc_title = title
        self.doc_num = doc_num
        self.set_auto_page_break(auto=True, margin=26)

    def header(self):
        if os.path.exists(HEADER_IMG):
            self.image(HEADER_IMG, x=0, y=0, w=210)
            self.set_y(54)
        else:
            self.set_font("Helvetica", "B", 9)
            self.set_text_color(47, 50, 131)
            self.cell(0, 6, sanitize("Deresegn POS - Security Assessment Submission"), align="L")
            self.cell(0, 6, "Confidential", align="R", new_x="LMARGIN", new_y="NEXT")
            self.set_draw_color(47, 50, 131)
            self.line(10, self.get_y(), 200, self.get_y())
            self.ln(4)

    def footer(self):
        if os.path.exists(FOOTER_IMG):
            self.image(FOOTER_IMG, x=0, y=275.2, w=210)
            self.set_y(-14)
            self.set_font("Helvetica", "B", 8)
            self.set_text_color(100, 100, 100)
            self.cell(0, 5, f"Page {self.page_no()}/{{nb}}", align="R")
        else:
            self.set_y(-20)
            self.set_draw_color(47, 50, 131)
            self.line(10, self.get_y(), 200, self.get_y())
            self.ln(2)
            self.set_font("Helvetica", "I", 8)
            self.set_text_color(128)
            self.cell(0, 5, sanitize(f"Micro Sun & Solution PLC  |  {CONTACT_EMAIL}"), align="L")
            self.cell(0, 5, f"Page {self.page_no()}/{{nb}}", align="R")

    def add_cover_page(self, subtitle=""):
        self.add_page()
        self.set_y(65)
        self.set_font("Helvetica", "B", 28)
        self.set_text_color(47, 50, 131)
        self.cell(0, 15, "Deresegn POS", align="C", new_x="LMARGIN", new_y="NEXT")
        self.ln(5)
        self.set_font("Helvetica", "", 16)
        self.set_text_color(80)
        self.cell(0, 10, sanitize(self.doc_title), align="C", new_x="LMARGIN", new_y="NEXT")
        if subtitle:
            self.set_font("Helvetica", "I", 12)
            self.cell(0, 8, sanitize(subtitle), align="C", new_x="LMARGIN", new_y="NEXT")
        self.ln(20)
        self.set_draw_color(47, 50, 131)
        self.line(60, self.get_y(), 150, self.get_y())
        self.ln(15)

        meta = [
            ("Document Version:", "1.0"),
            ("Application Version:", "1.0.3+4"),
            ("Date:", "August 5, 2026"),
            ("Classification:", "Confidential"),
            ("Prepared by:", "Micro Sun & Solution PLC"),
            ("Email:", CONTACT_EMAIL),
            ("Phone:", CONTACT_PHONE),
        ]
        for label, value in meta:
            self.set_font("Helvetica", "B", 10)
            self.set_text_color(60)
            self.cell(55, 7, label, align="R")
            self.set_font("Helvetica", "", 10)
            self.set_text_color(80)
            self.cell(0, 7, f"  {value}", new_x="LMARGIN", new_y="NEXT")

    def add_heading(self, text, level=1):
        text = sanitize(text)
        self.set_x(10)
        self.ln(3)
        if level == 1:
            if self.get_y() > 240:
                self.add_page()
            self.set_x(10)
            self.set_font("Helvetica", "B", 15)
            self.set_text_color(47, 50, 131)
            self.cell(0, 10, text, new_x="LMARGIN", new_y="NEXT")
            self.set_draw_color(47, 50, 131)
            self.line(10, self.get_y(), 200, self.get_y())
            self.ln(4)
        elif level == 2:
            if self.get_y() > 250:
                self.add_page()
            self.set_x(10)
            self.set_font("Helvetica", "B", 12)
            self.set_text_color(47, 50, 131)
            self.cell(0, 9, text, new_x="LMARGIN", new_y="NEXT")
            self.ln(2)
        else:
            if self.get_y() > 255:
                self.add_page()
            self.set_x(10)
            self.set_font("Helvetica", "B", 10.5)
            self.set_text_color(60)
            self.cell(0, 8, text, new_x="LMARGIN", new_y="NEXT")
            self.ln(1)
        self.set_x(10)

    def add_paragraph(self, text):
        text = sanitize(text.replace("**", ""))
        self.set_x(10)
        self.set_font("Helvetica", "", 9.5)
        self.set_text_color(40)
        self.multi_cell(180, 5, text)
        self.set_x(10)
        self.ln(2)

    def add_bullet(self, text, indent=0):
        text = sanitize(text.replace("**", ""))
        self.set_font("Helvetica", "", 9.5)
        self.set_text_color(40)
        x = 15 + indent * 5
        self.set_x(x)
        bullet_w = 180 - (x - 10)
        self.cell(5, 5, "-")
        self.multi_cell(bullet_w - 5, 5, text)
        self.set_x(10)

    def add_table(self, headers, rows):
        if not headers or not rows:
            return
        self.set_x(10)
        self.ln(2)
        n_cols = len(headers)
        avail_w = 180

        min_col_w = 12
        font_size = 7
        if n_cols * min_col_w > avail_w:
            font_size = 5.5
            min_col_w = 8

        if n_cols >= 7:
            col_widths = [max(min_col_w, avail_w / n_cols)] * n_cols
        elif n_cols == 6:
            col_widths = [25, 32, 32, 32, 25, 24]
        elif n_cols == 5:
            col_widths = [28, 38, 42, 38, 34]
        elif n_cols == 4:
            col_widths = [28, 48, 66, 38]
        elif n_cols == 3:
            col_widths = [42, 75, 63]
        elif n_cols == 2:
            col_widths = [55, 125]
        else:
            col_widths = [avail_w]

        total = sum(col_widths)
        col_widths = [w * avail_w / total for w in col_widths]

        # Header
        self.set_x(10)
        self.set_fill_color(47, 50, 131)
        self.set_text_color(255)
        self.set_font("Helvetica", "B", min(font_size + 0.5, 7.5))
        for i, h in enumerate(headers):
            w = col_widths[i] if i < len(col_widths) else col_widths[-1]
            max_h_chars = max(3, int(w / 1.8))
            self.cell(w, 6, sanitize(h)[:max_h_chars], border=1, fill=True, align="C")
        self.ln()

        # Rows
        self.set_font("Helvetica", "", font_size)
        self.set_text_color(40)
        fill = False
        for row in rows:
            while len(row) < n_cols:
                row.append("")

            if self.get_y() > 255:
                self.add_page()
                self.set_x(10)
                self.set_fill_color(47, 50, 131)
                self.set_text_color(255)
                self.set_font("Helvetica", "B", min(font_size + 0.5, 7.5))
                for i, h in enumerate(headers):
                    w = col_widths[i] if i < len(col_widths) else col_widths[-1]
                    max_h_chars = max(3, int(w / 1.8))
                    self.cell(w, 6, sanitize(h)[:max_h_chars], border=1, fill=True, align="C")
                self.ln()
                self.set_font("Helvetica", "", font_size)
                self.set_text_color(40)
                fill = False

            if fill:
                self.set_fill_color(240, 240, 248)
            else:
                self.set_fill_color(255, 255, 255)

            y_start = self.get_y()
            max_y = y_start

            for i in range(n_cols):
                cell_text = sanitize(row[i].replace("**", "").strip()) if i < len(row) else ""
                w = col_widths[i] if i < len(col_widths) else col_widths[-1]
                self.set_xy(10 + sum(col_widths[:i]), y_start)
                max_chars = max(5, int(w * 3.5))
                cell_text = cell_text[:max_chars]
                if w < 15:
                    self.cell(w, 5, cell_text[:int(w/1.5)], border=1, fill=True, align="C")
                else:
                    self.multi_cell(w, 4, cell_text, border=1, fill=True, align="L")
                if self.get_y() > max_y:
                    max_y = self.get_y()

            self.set_xy(10, max_y)
            fill = not fill

        self.set_x(10)
        self.ln(3)

    def add_image_diagram(self, image_path, caption=""):
        if not os.path.exists(image_path):
            self.add_paragraph(f"[Diagram: {caption} - Image not found]")
            return
        self.set_x(10)
        self.ln(3)
        if self.get_y() > 150:
            self.add_page()
        try:
            self.image(image_path, x=15, w=180)
        except Exception as e:
            self.add_paragraph(sanitize(f"[Diagram could not be loaded: {e}]"))
        if caption:
            self.set_font("Helvetica", "I", 8.5)
            self.set_text_color(100)
            self.cell(0, 5, sanitize(caption), align="C", new_x="LMARGIN", new_y="NEXT")
        self.set_x(10)
        self.ln(4)

    def add_code_block(self, content):
        self.set_x(10)
        self.ln(2)
        self.set_fill_color(245, 245, 250)
        self.set_font("Courier", "", 6.5)
        self.set_text_color(40)
        for line in content.split("\n")[:60]:
            if self.get_y() > 260:
                self.add_page()
            self.set_x(10)
            self.cell(180, 3.8, sanitize(line[:120]), fill=True, new_x="LMARGIN", new_y="NEXT")
        self.set_x(10)
        self.ln(3)


def parse_markdown(md_text):
    """Parse markdown into structured elements."""
    elements = []
    lines = md_text.split("\n")
    i = 0
    while i < len(lines):
        line = lines[i].rstrip()

        if not line.strip():
            i += 1
            continue

        # Skip metadata lines
        if line.startswith("**Document Version:") or line.startswith("**Application Version:") or \
           line.startswith("**Date:") or line.startswith("**Classification:") or \
           line.startswith("**Prepared by:") or line.strip() == "---" or \
           line.startswith("**Submitted by:") or line.startswith("**Application:"):
            i += 1
            continue

        # Headings
        if line.startswith("# "):
            elements.append(("h1", line[2:].strip()))
            i += 1
            continue
        if line.startswith("## "):
            elements.append(("h2", line[3:].strip()))
            i += 1
            continue
        if line.startswith("### "):
            elements.append(("h3", line[4:].strip()))
            i += 1
            continue
        if line.startswith("#### "):
            elements.append(("h3", line[5:].strip()))
            i += 1
            continue

        # Code blocks
        if line.strip().startswith("```"):
            code_lines = []
            i += 1
            while i < len(lines) and not lines[i].strip().startswith("```"):
                code_lines.append(lines[i].rstrip())
                i += 1
            i += 1
            elements.append(("code", "\n".join(code_lines)))
            continue

        # Tables
        if "|" in line and i + 1 < len(lines) and "---" in lines[i + 1]:
            headers = [c.strip() for c in line.split("|") if c.strip()]
            i += 2
            rows = []
            while i < len(lines) and "|" in lines[i] and lines[i].strip():
                row = [c.strip() for c in lines[i].split("|") if c.strip()]
                rows.append(row)
                i += 1
            elements.append(("table", (headers, rows)))
            continue

        # Bullets
        if line.strip().startswith("- ") or line.strip().startswith("* "):
            indent = (len(line) - len(line.lstrip())) // 2
            text = re.sub(r'^[\-\*]\s+', '', line.strip())
            elements.append(("bullet", (text, indent)))
            i += 1
            continue

        # Numbered list
        if re.match(r'^\d+\.\s', line.strip()):
            text = re.sub(r'^\d+\.\s+', '', line.strip())
            elements.append(("bullet", (text, 0)))
            i += 1
            continue

        # Block quote
        if line.strip().startswith("> "):
            text = line.strip()[2:].strip()
            elements.append(("note", text))
            i += 1
            continue

        # Regular paragraph - collect consecutive lines
        para_lines = [line.strip()]
        i += 1
        while i < len(lines) and lines[i].strip() and \
              not lines[i].startswith("#") and "|" not in lines[i] and \
              not lines[i].startswith("```") and not lines[i].strip().startswith("- ") and \
              not lines[i].strip().startswith("* ") and not lines[i].strip() == "---" and \
              not lines[i].strip().startswith("> ") and \
              not re.match(r'^\d+\.\s', lines[i].strip()):
            para_lines.append(lines[i].strip())
            i += 1
        elements.append(("paragraph", " ".join(para_lines)))

    return elements


def should_replace_with_diagram(content, diagram_map, diagram_inserted):
    """Check if a code block should be replaced with a diagram image."""
    checks = [
        ("api_interaction", ["Branch Login", "MoR Login with Branch JWT", "Invoicing / Receipts"]),
        ("srs_invoice_flow", ["Register Invoice", "Build Invoice Payload", "POST /api/invoice/register"]),
        ("srs_auth_flow", ["Enter Branch TIN", "POST /api/branch/login", "Sign MoR login payload"]),
        ("mobile_arch", ["PRESENTATION LAYER", "STATE MANAGEMENT", "SERVICE LAYER"]),
        ("system_arch", ["Backend API Server", "api.deresegn.com", "MoR e-Invoice"]),
        ("dfd", ["Branch Login", "MoR Login Request", "Invoice Payload"]),
        ("auth_flow", ["AuthInterceptor", "onRequest", "ConfigPreference.init"]),
        ("data_storage", ["MOBILE DEVICE", "flutter_secure_storage", "BACKEND SERVER"]),
    ]
    for key, keywords in checks:
        if key in diagram_map and not diagram_inserted.get(key, False):
            if any(kw in content for kw in keywords):
                return key
    return None


def render_doc(md_path, pdf_path, title, subtitle, doc_num, diagram_map=None):
    if diagram_map is None:
        diagram_map = {}

    with open(md_path, "r", encoding="utf-8") as f:
        md_text = f.read()

    md_text = md_text.replace("amanuielt@mssmea.com", CONTACT_EMAIL)
    md_text = md_text.replace("+251 947 990 585", CONTACT_PHONE)

    elements = parse_markdown(md_text)

    pdf = DocPDF(title=title, doc_num=doc_num)
    pdf.alias_nb_pages()
    pdf.add_cover_page(subtitle)
    pdf.add_page()

    diagram_inserted = {k: False for k in diagram_map}

    for etype, content in elements:
        if etype == "h1":
            pdf.add_heading(content, 1)
        elif etype == "h2":
            pdf.add_heading(content, 2)
        elif etype == "h3":
            pdf.add_heading(content, 3)
        elif etype == "paragraph":
            pdf.add_paragraph(content)
        elif etype == "bullet":
            text, indent = content
            pdf.add_bullet(text, indent)
        elif etype == "note":
            pdf.set_font("Helvetica", "I", 9)
            pdf.set_text_color(100, 60, 0)
            pdf.multi_cell(0, 5, sanitize(content.replace("**", "")))
            pdf.set_text_color(40)
            pdf.ln(2)
        elif etype == "table":
            headers, rows = content
            pdf.add_table(headers, rows)
        elif etype == "code":
            diag_key = should_replace_with_diagram(content, diagram_map, diagram_inserted)
            if diag_key:
                captions = {
                    "api_interaction": "Figure: Mobile API Interaction & Gateway Architecture",
                    "srs_invoice_flow": "Figure: Invoice Registration Workflow",
                    "srs_auth_flow": "Figure: Authentication & MoR Setup Workflow",
                    "mobile_arch": "Figure: Mobile Application Layer Architecture",
                    "system_arch": "Figure: System Architecture Diagram",
                    "dfd": "Figure: Data Flow Diagram",
                    "auth_flow": "Figure: Authentication & Token Lifecycle Flow",
                    "data_storage": "Figure: Data Storage Architecture",
                }
                pdf.add_image_diagram(diagram_map[diag_key], captions.get(diag_key, ""))
                diagram_inserted[diag_key] = True
            else:
                pdf.add_code_block(content)

    for suffix in ["", "_v2", "_latest"]:
        out_p = pdf_path if not suffix else pdf_path.replace(".pdf", f"{suffix}.pdf")
        try:
            pdf.output(out_p)
            size_kb = os.path.getsize(out_p) / 1024
            status = "" if not suffix else f" (Saved as {os.path.basename(out_p)})"
            print(f"  [OK] {os.path.basename(out_p)}{status} ({size_kb:.0f} KB)")
            break
        except PermissionError:
            continue


def main():
    print("=" * 50)
    print("Deresegn POS - PDF Document Generator")
    print("=" * 50)

    docs = [
        ("01_Requirements_Documentation_SRS.md",
         "01_Requirements_Documentation_SRS.pdf",
         "Requirements Documentation (SRS)",
         "Software Requirements Specification", "01"),
        ("02_System_Architecture_Design_SDD.md",
         "02_System_Architecture_Design_SDD.pdf",
         "System & Architecture Design (SDD)",
         "System Design Document", "02"),
        ("03_Technical_Specifications_TDD.md",
         "03_Technical_Specifications_TDD.pdf",
         "Technical Specifications (TDD/LLD)",
         "Technical Design Document", "03"),
        ("04_User_Documentation_Guide.md",
         "04_User_Documentation_Guide.pdf",
         "User Documentation",
         "User Guide", "04"),
        ("05_Application_Binary_README.md",
         "05_Application_Binary_README.pdf",
         "Application Binary Submission",
         "Binary Packaging Instructions", "05"),
        ("06_Data_Classification.md",
         "06_Data_Classification.pdf",
         "Data Classification",
         "Data Sensitivity & Handling", "06"),
        ("07_Security_Documentation.md",
         "07_Security_Documentation.pdf",
         "Security Documentation",
         "Threat Model & Security Controls", "07"),
        ("08_Mobile_API_User_Documentation_Guide.md",
         "08_Mobile_API_User_Documentation_Guide.pdf",
         "Mobile API User Documentation",
         "API Guide & Gateway Specifications", "08"),
    ]

    for md_file, pdf_file, title, subtitle, doc_num in docs:
        md_path = os.path.join(SUBMISSION_DIR, md_file)
        pdf_path = os.path.join(SUBMISSION_DIR, pdf_file)

        if not os.path.exists(md_path):
            print(f"  [SKIP] {md_file} (not found)")
            continue

        diagrams = DIAGRAM_IMAGES.get(doc_num, {})
        try:
            render_doc(md_path, pdf_path, title, subtitle, doc_num, diagrams)
        except Exception as e:
            print(f"  [FAIL] {md_file}: {e}")

    print()
    print("Done! PDFs are in:")
    print(f"  {SUBMISSION_DIR}")


if __name__ == "__main__":
    main()
