#!/usr/bin/env bash
# PRIMI PIANI di Matteo e Broski (testa e busto da 4 lati) -> tools/shots/primi_piani.png
#   bash tools/primo_piano.sh
cd "$(dirname "$0")/.." || exit 1
G=$(ls ../Godot/Godot_v*_console.exe | head -1)
dir=$(pwd -W 2>/dev/null || pwd)/tools/shots
mkdir -p tools/shots
timeout 180 "$G" --headless --path . --import >/dev/null 2>&1   # texture appena rifatte
for r in 0 1; do
	for c in 0 1 2 3; do
		x=$(python -c "print(($c-1.5)*1.3)")
		y=$(python -c "print(1.55-$r*2.3)")
		timeout 90 "$G" --path . -s res://tools/ritratti.gd -- --from=3 --cam=$x,$y,0.7 --shot="$dir/_pp_${r}_${c}.png" >/dev/null 2>&1
	done
done
python - "$dir" <<'EOF'
import sys
from PIL import Image
d = sys.argv[1]
out = Image.new("RGB", (4 * 500, 2 * 560))
for r in range(2):
    for c in range(4):
        im = Image.open(f"{d}/_pp_{r}_{c}.png")
        w, h = im.size
        out.paste(im.crop((w // 2 - 250, h // 2 - 280, w // 2 + 250, h // 2 + 280)), (c * 500, r * 560))
out.save(f"{d}/primi_piani.png")
EOF
rm -f tools/shots/_pp_*.png
echo "tools/shots/primi_piani.png"
