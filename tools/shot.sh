#!/bin/sh
# Usage: tools/shot.sh name  -> shots/name.png (full) and shots/name_s.png (1280 wide)
cd "$(dirname "$0")/.." || exit 1
pwsh -NoProfile -File tools/shot.ps1 -Out "shots/$1.png" >/dev/null && python -c "
from PIL import Image; im=Image.open('shots/$1.png'); im.thumbnail((1280,800)); im.save('shots/$1_s.png')" && echo "shots/$1_s.png"
