#!/usr/bin/env bash
# CONTROLLO COMPLETO DEL PROGETTO (da Git Bash):
#   bash tools/check.sh           -> importa, avvia menu e partite senza grafica, test di rampa e telecamera
#   bash tools/check.sh --shots   -> in più salva screenshot in tools/shots/ (apre una finestra per qualche secondo)
# Finisce con "TUTTO OK" oppure "CI SONO ERRORI".

cd "$(dirname "$0")/.." || exit 1
G=$(ls ../Godot/Godot_v*_console.exe 2>/dev/null | head -1)
if [ -z "$G" ]; then
	echo "Godot non trovato in ../Godot (serve il file Godot_v..._console.exe)"
	exit 1
fi
fail=0

run() {
	local label=$1; shift
	local out
	out=$(timeout 180 "$G" "$@" 2>&1)
	if echo "$out" | grep -qE "SCRIPT ERROR|ERROR:|Parse Error"; then
		echo "  [ERRORE] $label"
		echo "$out" | grep -E -A3 "SCRIPT ERROR|ERROR:|Parse Error" | head -30
		fail=1
	else
		echo "  [ok] $label"
	fi
}

echo "1) importazione e script"
run "importazione" --headless --path . --import
echo "2) menu e partite (senza grafica)"
run "menu" --headless --path . --quit-after 120
for c in 0 1 2 3 4; do
	run "partita personaggio $c" --headless --path . --quit-after 300 -- --autostart --char=$c
done
echo "3) test giocatore: rampa e telecamera"
out=$(timeout 240 "$G" --headless --fixed-fps 60 --path . -s res://tools/test_player.gd 2>&1)
echo "$out" | grep -E "^  |TEST|ERROR" | head -30
echo "$out" | grep -q "TEST OK" || fail=1
echo "$out" | grep -qE "SCRIPT ERROR|Parse Error" && fail=1
echo "4) test mosse: corsa, scivolata, a terra, visuale frontale, super salto"
out=$(timeout 240 "$G" --headless --fixed-fps 60 --path . -s res://tools/test_moves.gd 2>&1)
echo "$out" | grep -E "^  |TEST|ERROR" | head -30
echo "$out" | grep -q "TEST OK" || fail=1
echo "$out" | grep -qE "SCRIPT ERROR|Parse Error" && fail=1

if [ "${1:-}" = "--shots" ]; then
	echo "5) screenshot in tools/shots/"
	mkdir -p tools/shots
	dir=$(pwd -W 2>/dev/null || pwd)/tools/shots
	rm -f tools/shots/*.png
	timeout 90 "$G" --path . -- --shot="$dir/menu.png" >/dev/null 2>&1
	timeout 90 "$G" --path . -- --autostart --overview --shot="$dir/stanza_dall_alto.png" >/dev/null 2>&1
	timeout 90 "$G" --path . -- --autostart --char=0 --door --shot="$dir/terza_persona.png" >/dev/null 2>&1
	timeout 90 "$G" --path . -- --autostart --char=4 --weapon=1 --door --shot="$dir/spillatrice.png" >/dev/null 2>&1
	timeout 90 "$G" --path . -- --autostart --char=1 --weapon=2 --door --front --shot="$dir/telefono.png" >/dev/null 2>&1
	timeout 90 "$G" --path . -- --autostart --char=2 --weapon=3 --door --front --shot="$dir/pinza.png" >/dev/null 2>&1
	timeout 90 "$G" --path . -- --autostart --char=1 --desk --shot="$dir/sopra_la_scrivania.png" >/dev/null 2>&1
	timeout 90 "$G" --path . -- --autostart --char=2 --ramp --shot="$dir/rampa.png" >/dev/null 2>&1
	timeout 90 "$G" --path . -- --autostart --char=0 --wall --shot="$dir/muro_di_fianco.png" >/dev/null 2>&1
	timeout 90 "$G" --path . -- --autostart --char=0 --back --shot="$dir/spalle_al_muro.png" >/dev/null 2>&1
	timeout 90 "$G" --path . -- --autostart --char=3 --door --front --shot="$dir/visuale_frontale.png" >/dev/null 2>&1
	timeout 90 "$G" --path . -- --autostart --char=3 --door --prone --shot="$dir/a_terra.png" >/dev/null 2>&1
	timeout 90 "$G" --path . -s res://tools/ritratti.gd -- --shot="$dir/ritratti.png" >/dev/null 2>&1
	timeout 90 "$G" --path . -s res://tools/armi.gd -- --shot="$dir/armi.png" >/dev/null 2>&1
	ls tools/shots
fi

if [ $fail = 0 ]; then echo "TUTTO OK"; else echo "CI SONO ERRORI"; exit 1; fi
