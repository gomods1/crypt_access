"""Contact sheets of the distinct frames of each cutscene video, with timestamps, used to write the
cutscene descriptions (tools/desc/cutscenes_en.md). Needs Pillow and ffmpeg (winget yt-dlp.FFmpeg).
python tools/video_sheets.py "<game>/data/video" <out_dir> [names...]"""
import os, subprocess, sys, glob, shutil
from PIL import Image, ImageDraw, ImageChops, ImageStat, ImageFont

FFMPEG = os.path.expandvars(r"%LOCALAPPDATA%\Microsoft\WinGet\Packages\yt-dlp.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-N-127043-g5a54fcf75e-win64-gpl\bin\ffmpeg.exe")
video_dir, out_dir = sys.argv[1], sys.argv[2]
names = sys.argv[3:] or [os.path.splitext(os.path.basename(p))[0] for p in glob.glob(os.path.join(video_dir, "*.ogv"))]
STEP = 0.5  # seconds between sampled frames
os.makedirs(out_dir, exist_ok=True)
font = ImageFont.truetype(r"C:\Windows\Fonts\arialbd.ttf", 22)

for name in names:
    tmp = os.path.join(out_dir, "_frames_" + name)
    shutil.rmtree(tmp, ignore_errors=True)
    os.makedirs(tmp)
    subprocess.run([FFMPEG, "-v", "error", "-i", os.path.join(video_dir, name + ".ogv"), "-vf", f"fps={1/STEP},scale=320:-1",
                    os.path.join(tmp, "f%04d.png")], check=True)
    frames = sorted(glob.glob(os.path.join(tmp, "f*.png")))
    keep = []
    prev = None
    for i, path in enumerate(frames):
        img = Image.open(path).convert("RGB")
        t = i * STEP
        if prev is None:
            keep.append((t, img))
            prev = img
            continue
        diff = ImageStat.Stat(ImageChops.difference(img, prev)).mean
        if sum(diff) / 3 > 12:
            keep.append((t, img))
            prev = img
    # Cap the sheet size: keep at most 30 frames, evenly.
    if len(keep) > 30:
        idx = [round(i * (len(keep) - 1) / 29) for i in range(30)]
        keep = [keep[i] for i in idx]
    cols = 5
    rows = (len(keep) + cols - 1) // cols
    w, h = keep[0][1].size
    sheet = Image.new("RGB", (cols * w, rows * h), "white")
    d = ImageDraw.Draw(sheet)
    for n, (t, img) in enumerate(keep):
        x, y = (n % cols) * w, (n // cols) * h
        sheet.paste(img, (x, y))
        d.rectangle([x, y, x + 70, y + 26], fill="yellow")
        d.text((x + 3, y + 1), f"{t:.1f}", fill="black", font=font)
    sheet.save(os.path.join(out_dir, name + ".png"))
    shutil.rmtree(tmp, ignore_errors=True)
    print(name, len(frames), "frames,", len(keep), "kept")
