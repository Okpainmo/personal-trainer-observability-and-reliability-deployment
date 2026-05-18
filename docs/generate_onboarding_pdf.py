from pathlib import Path
import re
import textwrap


ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "intern-onboarding-guide.md"
OUTPUT = ROOT / "intern-onboarding-guide.pdf"

PAGE_WIDTH = 595
PAGE_HEIGHT = 842
MARGIN_X = 54
MARGIN_TOP = 58
MARGIN_BOTTOM = 52
LINE_HEIGHT = 14


def escape_pdf_text(value: str) -> str:
    return value.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")


def wrap_line(line: str, width: int) -> list[str]:
    if not line:
        return [""]
    return textwrap.wrap(line, width=width, replace_whitespace=False, drop_whitespace=False) or [line]


def parse_markdown(text: str) -> list[dict]:
    blocks = []
    in_code = False
    for raw in text.splitlines():
        line = raw.rstrip()
        if line.startswith("```"):
            in_code = not in_code
            blocks.append({"kind": "space", "text": ""})
            continue
        if in_code:
            blocks.append({"kind": "code", "text": line})
        elif line.startswith("# "):
            blocks.append({"kind": "h1", "text": line[2:]})
        elif line.startswith("## "):
            blocks.append({"kind": "h2", "text": line[3:]})
        elif line.startswith("### "):
            blocks.append({"kind": "h3", "text": line[4:]})
        elif line.startswith("- "):
            blocks.append({"kind": "bullet", "text": line[2:]})
        elif re.match(r"^\d+\. ", line):
            blocks.append({"kind": "number", "text": line})
        elif not line:
            blocks.append({"kind": "space", "text": ""})
        else:
            blocks.append({"kind": "p", "text": line})
    return blocks


def block_lines(block: dict) -> tuple[str, int, list[str], int]:
    kind = block["kind"]
    text = block["text"]
    if kind == "h1":
        return "F2", 18, wrap_line(text, 54), 8
    if kind == "h2":
        return "F2", 14, wrap_line(text, 66), 6
    if kind == "h3":
        return "F2", 12, wrap_line(text, 75), 4
    if kind == "code":
        return "F3", 9, wrap_line(text, 92), 0
    if kind == "bullet":
        return "F1", 10, wrap_line("- " + text, 88), 0
    if kind == "number":
        return "F1", 10, wrap_line(text, 88), 0
    if kind == "space":
        return "F1", 10, [""], 2
    return "F1", 10, wrap_line(text, 88), 0


def render_pages(blocks: list[dict]) -> list[str]:
    pages = []
    commands = []
    y = PAGE_HEIGHT - MARGIN_TOP

    def new_page():
        nonlocal commands, y
        pages.append("\n".join(commands))
        commands = []
        y = PAGE_HEIGHT - MARGIN_TOP

    def add_text(font: str, size: int, x: int, y_pos: int, text: str):
        commands.append(f"BT /{font} {size} Tf {x} {y_pos} Td ({escape_pdf_text(text)}) Tj ET")

    for block in blocks:
        font, size, lines, extra_before = block_lines(block)
        needed = (len(lines) * LINE_HEIGHT) + extra_before + 4
        if y - needed < MARGIN_BOTTOM:
            new_page()
        y -= extra_before
        for idx, line in enumerate(lines):
            x = MARGIN_X
            if block["kind"] == "code":
                x = MARGIN_X + 8
            if block["kind"] in {"bullet", "number"} and idx > 0:
                x = MARGIN_X + 14
            if line:
                add_text(font, size, x, y, line)
            y -= LINE_HEIGHT
    if commands:
        pages.append("\n".join(commands))
    return pages


def build_pdf(pages: list[str]) -> bytes:
    objects = []

    def add_object(content: str) -> int:
        objects.append(content)
        return len(objects)

    font_regular = add_object("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>")
    font_bold = add_object("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>")
    font_mono = add_object("<< /Type /Font /Subtype /Type1 /BaseFont /Courier >>")

    page_refs = []
    contents_refs = []
    for page in pages:
        stream = page.encode("utf-8")
        content_ref = add_object(f"<< /Length {len(stream)} >>\nstream\n{page}\nendstream")
        contents_refs.append(content_ref)
        page_ref = add_object(
            "<< /Type /Page /Parent 0 0 R "
            f"/MediaBox [0 0 {PAGE_WIDTH} {PAGE_HEIGHT}] "
            f"/Resources << /Font << /F1 {font_regular} 0 R /F2 {font_bold} 0 R /F3 {font_mono} 0 R >> >> "
            f"/Contents {content_ref} 0 R >>"
        )
        page_refs.append(page_ref)

    kids = " ".join(f"{ref} 0 R" for ref in page_refs)
    pages_ref = add_object(f"<< /Type /Pages /Kids [{kids}] /Count {len(page_refs)} >>")

    for ref in page_refs:
        objects[ref - 1] = objects[ref - 1].replace("/Parent 0 0 R", f"/Parent {pages_ref} 0 R")

    catalog_ref = add_object(f"<< /Type /Catalog /Pages {pages_ref} 0 R >>")

    output = bytearray(b"%PDF-1.4\n")
    offsets = [0]
    for idx, obj in enumerate(objects, start=1):
        offsets.append(len(output))
        output.extend(f"{idx} 0 obj\n{obj}\nendobj\n".encode("utf-8"))
    xref = len(output)
    output.extend(f"xref\n0 {len(objects) + 1}\n".encode("ascii"))
    output.extend(b"0000000000 65535 f \n")
    for offset in offsets[1:]:
        output.extend(f"{offset:010d} 00000 n \n".encode("ascii"))
    output.extend(
        f"trailer\n<< /Size {len(objects) + 1} /Root {catalog_ref} 0 R >>\n"
        f"startxref\n{xref}\n%%EOF\n".encode("ascii")
    )
    return bytes(output)


def main():
    markdown = SOURCE.read_text(encoding="utf-8")
    pages = render_pages(parse_markdown(markdown))
    OUTPUT.write_bytes(build_pdf(pages))
    print(f"wrote {OUTPUT}")


if __name__ == "__main__":
    main()
