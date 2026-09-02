#!/usr/bin/env python3
"""ACI tester guide — locked Fulfillment Heartbeat format.

Update BUILD / STAMP / screenshots for each TestFlight drop, then:
    python3 make_guide.py
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
from reportlab.lib.pagesizes import letter
from reportlab.lib.colors import HexColor, white
from reportlab.pdfgen import canvas

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[1]
ATT = Path("/workspace/attachments")
OUT = ROOT / "Fulfillment-Heartbeat-ACI-Test-Users-Update-Guide.pdf"

VERSION_NAME = "1.0"
BUILD = "310"
STAMP = "HB-0827.39"
AUDIENCE = "ACI Test Users"
VERSION = f"Version {VERSION_NAME}  ·  Build {BUILD}  ·  {STAMP}"

NAVY = HexColor("#003DA5")
PULSE = HexColor("#00A9E0")
BG = HexColor("#F5F7FC")
TEXT = HexColor("#141A29")
MUTED = HexColor("#5B6578")
LINE = HexColor("#C9D4E8")
SOFT = HexColor("#EEF2FB")
CARD = HexColor("#FFFFFF")
W, H = letter
MARGIN = 28
CONTENT_W = W - MARGIN * 2


def wordmark_path() -> Path:
    dest = ROOT / "wordmark.png"
    if dest.exists():
        return dest
    font_path = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
    img = Image.new("RGBA", (1600, 220), (245, 247, 252, 255))
    draw = ImageDraw.Draw(img)
    font = ImageFont.truetype(font_path, 92)
    x, y = 40, 48
    draw.text((x, y), "Fulfill", font=font, fill=(0, 61, 165, 255))
    left = draw.textbbox((x, y), "Fulfill", font=font)
    draw.text((left[2] + 2, y), "ment", font=font, fill=(0, 169, 224, 255))
    end = draw.textbbox((left[2] + 2, y), "ment", font=font)
    uy = end[3] + 8
    for i in range(end[2] - x):
        t = i / max(end[2] - x - 1, 1)
        color = (
            int(0 + (0 - 0) * t),
            int(61 + (169 - 61) * t),
            int(165 + (224 - 165) * t),
            255,
        )
        draw.line([(x + i, uy), (x + i, uy + 5)], fill=color)
    heart_src = REPO / "FulfillmentHeartbeat/Assets.xcassets/HeartbeatMark.imageset/HeartbeatMark@3x.png"
    heart = Image.open(heart_src).convert("RGBA").resize((120, 120), Image.Resampling.LANCZOS)
    hx, hy = end[2] + 36, y - 8
    img.paste(heart, (hx, hy), heart)
    pts = [
        (hx + 92, hy + 60), (hx + 120, hy + 60), (hx + 132, hy + 54),
        (hx + 144, hy + 62), (hx + 156, hy + 22), (hx + 170, hy + 94),
        (hx + 182, hy + 52), (hx + 194, hy + 60), (hx + 252, hy + 60),
        (hx + 268, hy + 50), (hx + 282, hy + 60), (hx + 342, hy + 60),
    ]
    for width in range(8, 0, -1):
        draw.line(pts, fill=(0, 169, 224, 90 if width > 5 else 255), width=width, joint="curve")
    img.save(dest)
    return dest


def wrap_lines(c, text, width, font="Helvetica", size=10):
    words = text.split()
    lines, line = [], ""
    for word in words:
        trial = (line + " " + word).strip()
        if c.stringWidth(trial, font, size) <= width:
            line = trial
        else:
            if line:
                lines.append(line)
            line = word
    if line:
        lines.append(line)
    return lines


def draw_wrapped(c, text, x, y, width, font="Helvetica", size=10, leading=13, color=TEXT):
    c.setFont(font, size)
    c.setFillColor(color)
    for line in wrap_lines(c, text, width, font, size):
        c.drawString(x, y, line)
        y -= leading
    return y


def header(c, page, total, mark):
    c.setFillColor(BG)
    c.rect(0, H - 86, W, 86, fill=1, stroke=0)
    c.drawImage(str(mark), MARGIN, H - 78, width=300, height=46, mask="auto")
    c.setFillColor(NAVY)
    c.setFont("Helvetica-Bold", 9)
    c.drawRightString(W - MARGIN, H - 42, AUDIENCE)
    c.setFillColor(PULSE)
    c.setFont("Helvetica", 8)
    c.drawRightString(W - MARGIN, H - 55, VERSION)
    c.setFillColor(PULSE)
    c.rect(0, H - 88, W, 3, fill=1, stroke=0)
    c.setFillColor(NAVY)
    c.rect(0, H - 91, W, 3, fill=1, stroke=0)
    c.setFillColor(MUTED)
    c.setFont("Helvetica", 8)
    c.drawRightString(W - MARGIN, H - 28, f"{page} / {total}")


def footer(c):
    c.setFillColor(SOFT)
    c.rect(0, 0, W, 24, fill=1, stroke=0)
    c.setFillColor(MUTED)
    c.setFont("Helvetica", 7.5)
    c.drawString(MARGIN, 10, "Internal  ·  Albertsons Companies  ·  Fulfillment Heartbeat")
    c.drawRightString(W - MARGIN, 10, VERSION)


def badge(c, n, x, y):
    c.setFillColor(NAVY)
    c.circle(x + 8, y + 3, 8, fill=1, stroke=0)
    c.setFillColor(white)
    c.setFont("Helvetica-Bold", 8)
    c.drawCentredString(x + 8, y, str(n))


def section(c, title, y):
    c.setFillColor(NAVY)
    c.setFont("Helvetica-Bold", 12)
    c.drawString(MARGIN, y, title)
    return y - 16


def draw_img(c, path, x, y_top, max_w, max_h):
    im = Image.open(path)
    iw, ih = im.size
    scale = min(max_w / iw, max_h / ih)
    tw, th = iw * scale, ih * scale
    y = y_top - th
    c.setFillColor(CARD)
    c.setStrokeColor(LINE)
    c.setLineWidth(0.5)
    c.roundRect(x - 1.5, y - 1.5, tw + 3, th + 3, 4, fill=1, stroke=1)
    c.drawImage(str(path), x, y, tw, th)
    return y


def main():
    mark = wordmark_path()
    crop = Image.open(mark).crop((20, 20, 1180, Image.open(mark).height - 16))
    cropped = ROOT / "wordmark-crop.png"
    crop.save(cropped)
    c = canvas.Canvas(str(OUT), pagesize=letter)
    header(c, 1, 4, cropped)
    footer(c)
    c.setFont("Helvetica", 9)
    c.setFillColor(MUTED)
    c.drawString(MARGIN, H - 108, "Template ready. Edit this script’s pages for the next drop.")
    c.save()
    print(OUT)


if __name__ == "__main__":
    main()
