"""Contact sheets of the bestiary portraits (data/bestiary), labelled, used to write tools/desc/desc_en.txt.
python tools/portrait_sheets.py "<game>/data/bestiary" <out_dir>"""
import glob, os, sys
from PIL import Image, ImageDraw, ImageFont
src = sys.argv[1]; out = sys.argv[2]
files = sorted(glob.glob(os.path.join(src, "*.png")))
font = ImageFont.truetype(r"C:\Windows\Fonts\arialbd.ttf", 16)
W, H, cols, per = 176, 240, 8, 24
os.makedirs(out, exist_ok=True)
for s in range(0, len(files), per):
    chunk = files[s:s+per]
    rows = (len(chunk) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * W, rows * (H + 20)), "white")
    d = ImageDraw.Draw(sheet)
    for i, f in enumerate(chunk):
        img = Image.open(f).convert("RGB"); img.thumbnail((W, H))
        x, y = (i % cols) * W, (i // cols) * (H + 20)
        sheet.paste(img, (x, y + 20))
        d.text((x + 2, y + 1), os.path.basename(f).replace("bestiary_", "").replace(".png", ""), fill="black", font=font)
    sheet.save(os.path.join(out, f"best{s // per + 1}.png"))
    print(len(chunk))
