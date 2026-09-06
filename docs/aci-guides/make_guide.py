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
BUILD = "434"
STAMP = "HB-0828.63"
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


def img(name):
    p = ATT / name
    if p.exists():
        return p
    alt = Path("/workspace/artifacts/searched_images") / name
    if alt.exists():
        return alt
    for fallback in ATT.iterdir():
        if fallback.suffix.lower() in {".png", ".jpg", ".jpeg"} and "018" in fallback.name:
            return fallback
    raise FileNotFoundError(name)


def step_block(c, n, title, body, y, width=CONTENT_W):
    badge(c, n, MARGIN, y - 2)
    c.setFillColor(NAVY)
    c.setFont("Helvetica-Bold", 10.5)
    c.drawString(MARGIN + 22, y, title)
    return draw_wrapped(c, body, MARGIN + 22, y - 14, width - 22, size=9.5, leading=12.5)


def make_mac_panel() -> Path:
    dest = ROOT / "mac-install-panel.png"
    font_b = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 28)
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 22)
    panel = Image.new("RGB", (1400, 520), (245, 247, 252))
    draw = ImageDraw.Draw(panel)
    steps = [
        ("1", "Open the Mac App Store", "Search TestFlight and click Get / Install."),
        ("2", "Open TestFlight on the Mac", "Sign in with the same Apple ID used on your iPad invite."),
        ("3", "Open the Heartbeat invite", "Use the email invite or the app already listed under Apps."),
        ("4", "Install Fulfillment Heartbeat", "Confirm Version 1.0 Build 434, then click Install / Update."),
    ]
    icon_path = Path("/workspace/artifacts/searched_images/DcH3m.jpg")
    icon = None
    if icon_path.exists():
        icon = Image.open(icon_path).convert("RGBA").resize((88, 88), Image.Resampling.LANCZOS)
    y = 28
    for num, title, body in steps:
        draw.rounded_rectangle((24, y, 1376, y + 108), 16, fill=(255, 255, 255), outline=(201, 212, 232), width=2)
        draw.ellipse((48, y + 28, 96, y + 76), fill=(0, 61, 165))
        bbox = draw.textbbox((0, 0), num, font=font_b)
        draw.text((72 - (bbox[2] - bbox[0]) / 2, y + 36), num, font=font_b, fill=(255, 255, 255))
        draw.text((120, y + 22), title, font=font_b, fill=(0, 61, 165))
        draw.text((120, y + 60), body, font=font, fill=(20, 26, 41))
        if icon and num == "1":
            panel.paste(icon, (1280, y + 10), icon)
        y += 120
    panel.save(dest)
    return dest


def main():
    mark = wordmark_path()
    crop = Image.open(mark).crop((20, 20, 1180, Image.open(mark).height - 16))
    cropped = ROOT / "wordmark-crop.png"
    crop.save(cropped)

    home = img("IMG_0181.jpg")
    tf = img("IMG_0179.PNG")
    upload = ROOT / "upload-current.png"
    files = img("IMG_0183.jpeg")
    pick = img("IMG_0184.jpeg")
    reading = img("IMG_0185.jpeg")
    dash = ROOT / "dash-current.jpg"
    labor = ROOT / "labor-current.png"
    header_shot = img("Open Items Heartbeat 14.png")
    tf_devices = Path("/workspace/artifacts/searched_images/shSow.jpg")
    mac_panel = make_mac_panel()

    c = canvas.Canvas(str(OUT), pagesize=letter)
    pages = 6

    header(c, 1, pages, cropped)
    footer(c)
    y = H - 112
    y = section(c, "Version for this drop", y)
    y = draw_wrapped(
        c,
        "Version 1.0  ·  Build 434  ·  HB-0828.63. Sidebar stamp after update must read HB-0828.63  1.0 (434). This build is for iPhone, iPad, and Apple silicon Mac.",
        MARGIN, y, CONTENT_W, size=10, leading=13,
    )
    y -= 10
    y = section(c, "What changed", y)
    y = draw_wrapped(
        c,
        "Labor in the master file is now the small store workbook: one row per store, STORE_ID first, plus a Total row. Do not put the 150,000-row day export on the Labor tab. The app opens Upload in a couple of seconds. Sales, Loss Revenue, 5 Star, and Labor land first so you can use the dashboard while Picker finishes. Dashboard cards are white with one health badge. Healthy / Watch / At Risk chips sit behind Metrics tap to expand. Region rows are unchanged.",
        MARGIN, y, CONTENT_W, size=9.5, leading=13,
    )
    y -= 10
    y = section(c, "Update on iPad or iPhone", y)
    y = step_block(
        c, 1, "Open TestFlight from the Home Screen",
        "Tap TestFlight first. Do not open the old Heartbeat icon until Update finishes. Testers still on an older 1.0 build must update before loading a master file.",
        y,
    )
    y -= 8
    pair_h = 188
    left_w = (CONTENT_W - 12) / 2
    draw_img(c, home, MARGIN, y, left_w, pair_h)
    draw_img(c, tf, MARGIN + left_w + 12, y, left_w, pair_h)
    y -= pair_h + 12
    step_block(
        c, 2, "Tap Update on Fulfillment Heartbeat",
        "Confirm Version 1.0 Build 434. Tap Update. Open Heartbeat and check the sidebar stamp HB-0828.63  1.0 (434).",
        y,
    )
    c.showPage()

    header(c, 2, pages, cropped)
    footer(c)
    y = H - 112
    y = section(c, "Reload the master file", y)
    y = draw_wrapped(
        c,
        "New code does not change numbers until you load the workbook again. Labor tab in the master must be STORE_ID, Sch Effi%, Empower Hrs, Sch_Hrs, ActHrs, CostTrgt%, ActCost%, Target vs Actual%, Charged Hrs, and a Total row. Prefer iCloud Files if OneDrive fails on a work iPad.",
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
    step_block(
        c, 4, "Open Files and pick the shared folder",
        "In the file picker, choose iCloud Drive or the folder that was shared with you. Open the Heartbeat folder that holds the master workbook.",
        y,
    )
    c.showPage()

    header(c, 3, pages, cropped)
    footer(c)
    y = H - 112
    y = section(c, "Select the workbook", y)
    y = step_block(
        c, 5, "Tap the master Excel file",
        "Select Heartbeat Master Week 27.xlsx or the current week file. Individual cards still replace one KPI if you are patching one tab.",
        y,
    )
    y -= 8
    draw_img(c, files, MARGIN, y, CONTENT_W * 0.48, 210)
    draw_img(c, pick, MARGIN + CONTENT_W * 0.52, y, CONTENT_W * 0.48, 210)
    y -= 224
    y = step_block(
        c, 6, "Watch X of 15 scorecards",
        "The popup counts loaded tabs. Light scorecards finish first and the dashboard opens. Picker may still merge after that. If a tab is missing it is listed in red. Stay in the app until Who’s looking appears on a first load.",
        y,
    )
    y -= 8
    draw_img(c, reading, MARGIN, y, CONTENT_W, 200)
    c.showPage()

    header(c, 4, pages, cropped)
    footer(c)
    y = H - 112
    y = section(c, "Dashboard and Labor", y)
    y = draw_wrapped(
        c,
        "Callouts stay Sales then Loss Revenue first. Cards are white with one badge. Tap Metrics to see Healthy / Watch / At Risk. Tap Regions under a card for the grain table. Labor tiles use Target vs Actual, CostTrgt%, ActCost%, and Sch Effi% from the store file. If Labor is blank, the master still has the old day-level Labor tab. Replace that tab and Reload.",
        MARGIN, y, CONTENT_W, size=9.5, leading=13,
    )
    y -= 8
    draw_img(c, dash, MARGIN, y, CONTENT_W, 200)
    y -= 212
    draw_img(c, labor, MARGIN, y, CONTENT_W, 188)
    y -= 200
    y = section(c, "Share email", y)
    draw_wrapped(
        c,
        "Share uses Apple Mail only. Pick Dashboard, all pages except Checklist, or individual pages. Every store in the filter is a stacked card so numbers stay on the page.",
        MARGIN, y, CONTENT_W, size=9.5, leading=13,
    )
    c.showPage()

    header(c, 5, pages, cropped)
    footer(c)
    y = H - 112
    y = section(c, "Now available on Mac computers", y)
    y = draw_wrapped(
        c,
        "Apple silicon MacBook (M1, M2, M3, M4) installs the same TestFlight build. Layout matches the iPad. Intel Macs need the Mac Catalyst archive when that build is posted. Use the same Apple ID that received the tester invite.",
        MARGIN, y, CONTENT_W, size=9.5, leading=13,
    )
    y -= 8
    if tf_devices.exists():
        draw_img(c, tf_devices, MARGIN, y, CONTENT_W, 168)
        y -= 180
    y = step_block(
        c, 7, "Install TestFlight on the Mac, then Heartbeat",
        "Mac App Store → search TestFlight → Get. Open TestFlight → accept Heartbeat → Install. Confirm Version 1.0 Build 434. The window opens at iPad size. Load the master file from iCloud Drive the same way as the iPad.",
        y,
    )
    y -= 8
    draw_img(c, mac_panel, MARGIN, y, CONTENT_W, 210)
    c.showPage()

    header(c, 6, pages, cropped)
    footer(c)
    y = H - 112
    y = section(c, "Master file tab names (15)", y)
    tabs = (
        "Sales  ·  Lost Revenue  ·  Missing Items  ·  5 Star  ·  Pre-Sub OOS  ·  "
        "Pre-Sub OOS Item  ·  Pick Path  ·  Path Picker  ·  Aisle Mapper  ·  "
        "Prep Not Ready  ·  Dynacap  ·  Schedule Quality  ·  Picker ScoreCard  ·  PPH  ·  Labor"
    )
    y = draw_wrapped(c, tabs, MARGIN, y, CONTENT_W, size=8.5, leading=12, color=TEXT)
    y -= 16
    y = section(c, "Confirm the build", y)
    y = draw_wrapped(
        c,
        "Sidebar stamp must read HB-0828.63  1.0 (434) on iPhone, iPad, and Mac. If it does not, open TestFlight and tap Update, then reload the master file.",
        MARGIN, y, CONTENT_W, size=9.5, leading=13,
    )
    y -= 16
    y = section(c, "If a scorecard is missing after load", y)
    draw_wrapped(
        c,
        "The popup lists the missing tab names. Add that exact tab to the master workbook or use the individual upload card. Picker ScoreCard must be named Picker ScoreCard or Picker ScorCard.",
        MARGIN, y, CONTENT_W, size=9.5, leading=13,
    )

    c.save()
    print(OUT)


if __name__ == "__main__":
    main()
