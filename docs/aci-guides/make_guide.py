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
BUILD = "343"
STAMP = "HB-0827.72"
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
            0,
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


def img(name):
    p = ATT / name
    if p.exists():
        return p
    raise FileNotFoundError(name)


def step_block(c, n, title, body, y, width=CONTENT_W):
    badge(c, n, MARGIN, y - 2)
    c.setFillColor(NAVY)
    c.setFont("Helvetica-Bold", 10.5)
    c.drawString(MARGIN + 22, y, title)
    return draw_wrapped(c, body, MARGIN + 22, y - 14, width - 22, size=9.5, leading=12.5)


def main():
    mark = wordmark_path()
    crop = Image.open(mark).crop((20, 20, 1180, Image.open(mark).height - 16))
    cropped = ROOT / "wordmark-crop.png"
    crop.save(cropped)

    home = img("IMG_0181.jpg")
    tf = img("IMG_0179.PNG")
    upload = img("IMG_0182.jpeg")
    files = img("IMG_0183.jpeg")
    pick = img("IMG_0184.jpeg")
    reading = img("IMG_0185.jpeg")
    sales = img("IMG_0434.PNG")
    dash = img("Open Items Heartbeat 8.png")

    c = canvas.Canvas(str(OUT), pagesize=letter)
    pages = 4

    # PAGE 1 — update
    header(c, 1, pages, cropped)
    footer(c)
    y = H - 112
    y = section(c, "What changed in this drop", y)
    y = draw_wrapped(
        c,
        "Build 343 adds the Sales ScoreCard page and dashboard callout. Sales is always the first card on Operational Heartbeat. Loss Revenue is always second. Health on Sales is Sales YoY %: over 0% is Healthy, flat is Watch, below 0% is At Risk. After you update, reload the master workbook so Sales numbers refresh.",
        MARGIN, y, CONTENT_W, size=9.5, leading=13,
    )
    y -= 10
    y = section(c, "Update Heartbeat in TestFlight", y)
    y = step_block(
        c, 1, "Open TestFlight from the Home Screen",
        "Find the TestFlight app on the iPad Home Screen and tap it. Do not open the old Heartbeat icon first — update inside TestFlight so you get Build 343.",
        y,
    )
    y -= 8
    pair_h = 210
    left_w = (CONTENT_W - 12) / 2
    draw_img(c, home, MARGIN, y, left_w, pair_h)
    draw_img(c, tf, MARGIN + left_w + 12, y, left_w, pair_h)
    y -= pair_h + 14
    y = step_block(
        c, 2, "Tap Update on Fulfillment Heartbeat",
        "On the TestFlight app page, confirm Version 1.0 Build 343. Tap Update. When it finishes, open Heartbeat. The sidebar stamp must read HB-0827.72  1.0 (343). If it shows an older stamp, tap Update again.",
        y,
    )
    c.showPage()

    # PAGE 2 — choose file
    header(c, 2, pages, cropped)
    footer(c)
    y = H - 112
    y = section(c, "Reload the master file", y)
    y = draw_wrapped(
        c,
        "New Sales data does not appear until you load the workbook again. Use the master Excel file that includes a tab named exactly Sales. You can also use the individual Sales upload card. Prefer iCloud Files if OneDrive fails on a work iPad.",
        MARGIN, y, CONTENT_W, size=9.5, leading=13,
    )
    y -= 10
    y = step_block(
        c, 3, "Go to Upload and tap Choose file or Reload",
        "Heartbeat opens on Upload when no file is loaded. If data is already in the app, open Upload from the menu, then tap Choose file or Reload on Master workbook.",
        y,
    )
    y -= 8
    draw_img(c, upload, MARGIN, y, CONTENT_W, 248)
    y -= 260
    y = step_block(
        c, 4, "Open Files and pick the shared folder",
        "In the iOS file picker, choose iCloud Drive (or the folder that was shared with you). Open the Heartbeat folder that holds the master workbook.",
        y,
    )
    c.showPage()

    # PAGE 3 — select and wait
    header(c, 3, pages, cropped)
    footer(c)
    y = H - 112
    y = section(c, "Select the workbook", y)
    y = step_block(
        c, 5, "Tap the master Excel file",
        "Select Heartbeat Master Week 27.xlsx or the current week file your team posted. The Sales tab name must be Sales. Individual Sales exports also work from the Sales card on Upload.",
        y,
    )
    y -= 8
    draw_img(c, files, MARGIN, y, CONTENT_W * 0.48, 220)
    draw_img(c, pick, MARGIN + CONTENT_W * 0.52, y, CONTENT_W * 0.48, 220)
    y -= 234
    y = step_block(
        c, 6, "Wait for Reading master workbook",
        "Keep the iPad awake until the banner says the file is loaded. Then Who’s looking appears. Pick your role. Company view shows every store. Region, Director, District, and OM views show only your scope.",
        y,
    )
    y -= 8
    draw_img(c, reading, MARGIN, y, CONTENT_W, 210)
    c.showPage()

    # PAGE 4 — new features
    header(c, 4, pages, cropped)
    footer(c)
    y = H - 112
    y = section(c, "New: Sales ScoreCard", y)
    y = draw_wrapped(
        c,
        "Dashboard order is Sales, then Loss Revenue, then the rest. The Sales card uses Total Sales $ from the export Total column. Open Sales ScoreCard for week totals, YoY, orders, AOS, AIV, items, and tap a store to see Sunday through Saturday.",
        MARGIN, y, CONTENT_W, size=9.5, leading=13,
    )
    y -= 8
    draw_img(c, dash, MARGIN, y, CONTENT_W, 188)
    y -= 200
    y = draw_wrapped(
        c,
        "Sales ScoreCard page — markets and stores. Status follows Sales YoY %. Empty Unassigned market rows are hidden. Reload data if Sales still shows the previous week.",
        MARGIN, y, CONTENT_W, size=9, leading=12, color=MUTED,
    )
    y -= 8
    draw_img(c, sales, MARGIN, y, CONTENT_W, 188)
    y -= 200
    y = section(c, "Master file tab names", y)
    tabs = (
        "Sales  ·  Lost Revenue  ·  Missing Items  ·  5 Star  ·  Pre-Sub OOS  ·  "
        "Pre Sub OOS Item  ·  Pick Path  ·  Aisle Mapper  ·  Prep Not Ready  ·  "
        "Dynacap  ·  Schedule Quality  ·  Picker ScoreCard  ·  PPH  ·  Labor"
    )
    draw_wrapped(c, tabs, MARGIN, y, CONTENT_W, size=8.5, leading=12, color=TEXT)

    c.save()
    print(OUT)


if __name__ == "__main__":
    main()
