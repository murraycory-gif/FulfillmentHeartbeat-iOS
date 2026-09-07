#!/usr/bin/env python3
"""ACI tester guide — locked Fulfillment Heartbeat format."""
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
BUILD = "533"
STAMP = "HB-0828.202"
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
        color = (0, int(61 + (169 - 61) * t), int(165 + (224 - 165) * t), 255)
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


def local(name):
    p = ROOT / name
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

    home = local("tf-home.jpg")
    tf = local("tf-update.png")
    load = local("load-screen.png")
    splash = local("splash-mark.png")
    dash = local("dash-metrics.png")
    lost = local("dash-lost.png")
    sales = local("sales-page.png")
    overview = local("dash-overview.png")

    c = canvas.Canvas(str(OUT), pagesize=letter)
    pages = 5

    header(c, 1, pages, cropped)
    footer(c)
    y = H - 112
    y = section(c, "Version for this drop", y)
    y = draw_wrapped(
        c,
        "Version 1.0  ·  Build 533  ·  HB-0828.202. After Update, the sidebar stamp must read HB-0828.202  1.0 (533). This build is for iPhone, iPad, and Apple silicon Mac.",
        MARGIN, y, CONTENT_W, size=10, leading=13,
    )
    y -= 10
    y = section(c, "Biggest change — no file upload", y)
    y = draw_wrapped(
        c,
        "Testers do not load an Excel file. Ops publishes Heartbeat Daily Report.xlsx to the Heartbeat server. You open the app. The load screen pulls that file. Then Who's Looking appears. Then the dashboard. If the app was already installed, force-close it once after Update so it picks up the new week.",
        MARGIN, y, CONTENT_W, size=9.5, leading=13,
    )
    y -= 10
    y = section(c, "What else landed", y)
    y = draw_wrapped(
        c,
        "Dashboard callouts now show the metric itself, not only Healthy / Watch / At Risk. Sales and Loss Revenue stay first. 5 Star shows Flash, COE, OTT, Pre-Sub OOS%, OTH 5%. Labor, Schedule, Pick Path, Pre-Sub, and Dynacap follow the same one-row boxes. Filters refresh the page you are on. Store rows read Store | District | Market. Who's Looking still scopes the company, region, market, district, or OM view.",
        MARGIN, y, CONTENT_W, size=9.5, leading=13,
    )
    y -= 12
    y = section(c, "Update on iPad or iPhone", y)
    y = step_block(
        c, 1, "Open TestFlight from the Home Screen",
        "Tap TestFlight first. Do not open the old Heartbeat icon until Update finishes.",
        y,
    )
    y -= 8
    pair_h = 176
    left_w = (CONTENT_W - 12) / 2
    draw_img(c, home, MARGIN, y, left_w, pair_h)
    draw_img(c, tf, MARGIN + left_w + 12, y, left_w, pair_h)
    y -= pair_h + 12
    step_block(
        c, 2, "Tap Update on Fulfillment Heartbeat",
        "Confirm Version 1.0 Build 533. Tap Update. Force-close Heartbeat, open it, and check the sidebar stamp HB-0828.202  1.0 (533).",
        y,
    )
    c.showPage()

    header(c, 2, pages, cropped)
    footer(c)
    y = H - 112
    y = section(c, "Open the app — data is already there", y)
    y = step_block(
        c, 3, "Stay on the load screen",
        "Fulfillment wordmark, heart and pulse, then a short grocery line. Do not leave the app. When the new week is on the server the file downloads here. You will not use Choose file.",
        y,
    )
    y -= 8
    draw_img(c, splash, MARGIN, y, CONTENT_W * 0.32, 168)
    draw_img(c, load, MARGIN + CONTENT_W * 0.34, y, CONTENT_W * 0.66, 168)
    y -= 180
    y = step_block(
        c, 4, "Pick Who's Looking",
        "Backstage Support is total company. EVP Region is that region only. Director / Market VP / Sr Director Sales is the market and districts. Operations Manager is assigned stores. After you tap a role, the dashboard opens for that scope.",
        y,
    )
    y -= 8
    y = section(c, "Do not upload", y)
    y = draw_wrapped(
        c,
        "Upload stays in the app for Ops only if a tab must be patched. Testers should not pick a local Excel. If you still see Choose file on every launch, you are not on Build 533. Update again from TestFlight and force-close.",
        MARGIN, y, CONTENT_W, size=9.5, leading=13,
    )
    c.showPage()

    header(c, 3, pages, cropped)
    footer(c)
    y = H - 112
    y = section(c, "Dashboard callouts", y)
    y = draw_wrapped(
        c,
        "Sales is first. Loss Revenue is second. Each card has one row of metric boxes. The box color is the health of that metric. Tap the card chevron for the scorecard page. Tap Regions to expand the grain under that metric. Sales expand stays the region / day table. Other sections show that section's metrics in the expand.",
        MARGIN, y, CONTENT_W, size=9.5, leading=13,
    )
    y -= 8
    draw_img(c, overview, MARGIN, y, CONTENT_W, 168)
    y -= 180
    draw_img(c, dash, MARGIN, y, CONTENT_W, 210)
    y -= 222
    y = draw_wrapped(
        c,
        "5 Star: Flash, COE, OTT, Pre-Sub OOS%, OTH 5%. Loss Revenue: Total Lost Revenue, Post Sub OOS Foregone, Refund $, Reduced Capacity Missed Sales, Cancelled Orders LDAP, Kill Switch. Labor: Target vs Actual, Act Cost %, Cost Target %, Schedule Efficiency %, UPLH, WAGE, AIV. Picker boxes count shoppers. Schedule: Sch Effi %, Staffing % Pch vs TGT, Under, Over. Pick Path: Pick Path, AVG PPH. Pre-Sub: stores above 5%, at goal, close to goal, and the number 1 item. Dynacap: Pieces / hr, Store PPH, Utilization.",
        MARGIN, y, CONTENT_W, size=9, leading=12,
    )
    c.showPage()

    header(c, 4, pages, cropped)
    footer(c)
    y = H - 112
    y = section(c, "Scorecard pages and store rows", y)
    y = draw_wrapped(
        c,
        "Every page except the dashboard uses the same table chrome. Region / market / district is the top table. Store rows read Store | District | Market, for example 1674 | 44 | SoCal. Store tables start collapsed. Tap the Store banner to expand. Filters at the top apply to every page. Clear Filters returns to total company without a long rebuild.",
        MARGIN, y, CONTENT_W, size=9.5, leading=13,
    )
    y -= 8
    draw_img(c, sales, MARGIN, y, CONTENT_W, 250)
    y -= 262
    y = step_block(
        c, 5, "Swipe between pages",
        "Swipe left or right from Dashboard to Sales, Loss Revenue, and the rest. The next page is warmed after you land. If a swipe feels heavy, pause one second on the page, then swipe again.",
        y,
    )
    c.showPage()

    header(c, 5, pages, cropped)
    footer(c)
    y = H - 112
    y = section(c, "How data gets into the app", y)
    y = draw_wrapped(
        c,
        "Ops exports Heartbeat Daily Report.xlsx from Power BI and replaces that file in the Heartbeat server bucket. Testers never touch that file. On open, Heartbeat compares the server file size to the last load. If it changed, the load screen downloads and Who's Looking appears. If it did not change, the last week is already on the device and the dashboard opens from cache.",
        MARGIN, y, CONTENT_W, size=9.5, leading=13,
    )
    y -= 12
    y = section(c, "If something looks old", y)
    y = step_block(
        c, 6, "Force-close and open once",
        "Swipe Heartbeat out of the app switcher, then open it. Stay on the load screen. Sidebar stamp must be HB-0828.202  1.0 (533). If the stamp is older, TestFlight did not finish Update.",
        y,
    )
    y -= 10
    y = step_block(
        c, 7, "Check the week on the blue banner",
        "Each page banner shows the data window for that scorecard, for example Aug 30 – Sep 5, 2026. If the dates are last week, the new file is not on the server yet or the app has not pulled it.",
        y,
    )
    y -= 14
    y = section(c, "Mac testers", y)
    y = draw_wrapped(
        c,
        "Install TestFlight from the Mac App Store. Open the same Heartbeat invite. Install or Update to 1.0 (533). The window uses the iPad layout. No Excel picker. Who's Looking still runs on first open after a force-quit.",
        MARGIN, y, CONTENT_W, size=9.5, leading=13,
    )
    y -= 14
    y = section(c, "Support check", y)
    y = draw_wrapped(
        c,
        "Stamp HB-0828.202  1.0 (533). Load screen then Who's Looking. Dashboard Sales first, Loss Revenue second. No Choose file for testers. Store rows show number, district, and market. Filters change every page. New week appears after Ops replaces Heartbeat Daily Report.xlsx and you force-close once.",
        MARGIN, y, CONTENT_W, size=9.5, leading=13,
    )
    c.save()
    print(OUT)


if __name__ == "__main__":
    main()
