"""Build code-drawn documentation media from the fictional dashboard screenshot.

Requires Pillow and ffmpeg. No account data or application processes are accessed.
Run from any directory: python tools/build-discovery-media.py
"""
from pathlib import Path
import subprocess
import tempfile
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "media"
OUT.mkdir(parents=True, exist_ok=True)
FONTS = Path("C:/Windows/Fonts")
BG, PANEL, TEXT, MUTED, BLUE = "#101318", "#202733", "#e9edf4", "#aab6c6", "#729ed4"

def font(size, bold=False):
    return ImageFont.truetype(str(FONTS / ("segoeuib.ttf" if bold else "segoeui.ttf")), size)

def text(draw, xy, value, size=25, color=TEXT, bold=False):
    draw.text(xy, value, font=font(size, bold), fill=color)

shot = Image.open(ROOT / "docs" / "screenshot.png").convert("RGB")
banner = Image.new("RGB", (1280, 640), BG)
d = ImageDraw.Draw(banner)
d.rounded_rectangle((48, 45, 132, 129), radius=20, fill=PANEL, outline=BLUE, width=2)
text(d, (60, 56), ">_", 48, BLUE, True)
text(d, (157, 57), "CODEX MANAGER", 43, TEXT, True)
text(d, (50, 178), "Your accounts.", 48, TEXT, True)
text(d, (50, 236), "One dashboard.", 48, TEXT, True)
text(d, (50, 325), "Switch accounts on Windows", 28)
text(d, (50, 369), "See remaining 5-hour + weekly usage", 23, MUTED)
text(d, (50, 415), "Local storage  /  Open source  /  MIT", 23, BLUE)
mini = shot.resize((650, 344), Image.Resampling.LANCZOS)
banner.paste(mini, (600, 177))
d.rounded_rectangle((48, 525, 405, 581), radius=12, fill="#355d8e")
text(d, (69, 535), "Download the Windows beta", 23, TEXT, True)
text(d, (600, 553), "github.com/DavitBadishyan/codex-manager", 22, MUTED)
text(d, (50, 605), "Unofficial companion for the Codex desktop app. Fictional demo data.", 16, MUTED)
banner.save(OUT / "social-preview.png", optimize=True)

frames = []
headings = [
    ("01  Install in a few clicks", "Download ZIP, extract everything, then double-click Install.cmd."),
    ("02  Add your accounts", "Choose Add account and complete sign-in in your browser."),
    ("03  Compare remaining usage", "Refresh to see available usage, reset times, and session status."),
    ("04  Choose an account", "Finish Codex work first, then switch. The Codex desktop app restarts."),
]
for index, (heading, caption) in enumerate(headings):
    frame = Image.new("RGB", (1280, 720), BG)
    draw = ImageDraw.Draw(frame)
    text(draw, (44, 22), heading, 37, TEXT, True)
    text(draw, (44, 72), caption, 24, MUTED)
    if index == 0:
        for n, (title, detail) in enumerate([
            ("Download", "Release ZIP"), ("Extract All", "Open the folder"),
            ("Install.cmd", "Double-click"), ("Codex Manager", "Desktop shortcut")]):
            x = 44 + n * 303
            draw.rounded_rectangle((x, 218, x + 282, 444), radius=20, fill=PANEL, outline="#39485f", width=2)
            text(draw, (x + 20, 238), str(n + 1).zfill(2), 44, BLUE, True)
            text(draw, (x + 20, 324), title, 27, TEXT, True)
            text(draw, (x + 20, 372), detail, 23, MUTED)
        text(draw, (44, 515), "Requires the official Microsoft Store Codex desktop app.", 28)
        text(draw, (44, 560), "Windows 10/11  |  No administrator access required", 26, BLUE)
    else:
        preview = shot.resize((1000, 529), Image.Resampling.LANCZOS)
        frame.paste(preview, (140, 122))
        if index == 1:
            box = (951, 152, 1020, 178)
        elif index == 2:
            box = (162, 303, 450, 505)
        else:
            box = (484, 492, 769, 519)
        draw.rounded_rectangle(box, radius=5, outline="#d4e5ff", width=3)
    text(draw, (44, 675), "CODEX MANAGER  /  Illustrated walkthrough — fictional accounts and sample usage", 19, MUTED)
    frames.append(frame)

frames[0].save(OUT / "quickstart.gif", save_all=True,
    append_images=frames[1:], duration=5000, loop=0, optimize=True)
with tempfile.TemporaryDirectory(prefix="codex-manager-media-") as stage:
    for index, frame in enumerate(frames):
        frame.save(Path(stage) / f"frame-{index:02d}.png")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", "1/5",
        "-i", str(Path(stage) / "frame-%02d.png"), "-c:v", "libx264", "-r", "24",
        "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(OUT / "walkthrough.mp4")], check=True)
print("Built social-preview.png, quickstart.gif, walkthrough.mp4 (fictional walkthrough).")
