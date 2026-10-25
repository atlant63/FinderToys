#!/usr/bin/env python3
import sys, zipfile, os, tempfile, re

def normalize_docx(docx_path):
    if not os.path.exists(docx_path):
        return
    td = tempfile.mkdtemp()
    tmp_out = os.path.join(td, "mod.docx")
    try:
        with zipfile.ZipFile(docx_path, "r") as zin, zipfile.ZipFile(tmp_out, "w") as zout:
            for item in zin.infolist():
                buf = zin.read(item.filename)
                if item.filename in ("word/document.xml", "word/styles.xml"):
                    s = buf.decode("utf-8")
                    # Bump small font sizes (<12pt) to 12pt (val="24")
                    for v in ("16", "17", "18", "19", "20", "21", "22", "23"):
                        s = s.replace(f'w:val="{v}"', 'w:val="24"')
                    # Proportional header bump: 14pt (28) -> 15pt (30)
                    s = s.replace('w:val="28"', 'w:val="30"')
                    # Normalize fonts to classic legal Times New Roman
                    for f in ("Arial", "Calibri", "Liberation Sans", "Linux Libertine"):
                        s = re.sub(rf'w:ascii="{f}"', 'w:ascii="Times New Roman"', s)
                        s = re.sub(rf'w:hAnsi="{f}"', 'w:hAnsi="Times New Roman"', s)
                        s = re.sub(rf'w:cs="{f}"', 'w:cs="Times New Roman"', s)
                    # Relax single line spacing to 1.15x
                    s = s.replace('w:line="240"', 'w:line="276"')
                    buf = s.encode("utf-8")
                zout.writestr(item, buf)
        os.replace(tmp_out, docx_path)
    finally:
        if os.path.exists(td):
            os.system(f'rm -rf "{td}"')

if __name__ == "__main__":
    if len(sys.argv) > 1:
        normalize_docx(sys.argv[1])
