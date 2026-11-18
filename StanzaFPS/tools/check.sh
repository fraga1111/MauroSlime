#!/usr/bin/env bash
# CONTROLLO COMPLETO DEL PROGETTO (da Git Bash):
#   bash tools/check.sh           -> importa, avvia menu e partite senza grafica, test di rampa e telecamera
#   bash tools/check.sh --shots   -> in più salva screenshot in tools/shots/ (apre una finestra per qualche secondo)
#   bash tools/check.sh --rapido  -> solo importazione, menu e UNA partita (niente test di rampa/mosse): per modifiche piccole
#   --char=N                      -> con --rapido, la partita è col personaggio N (default 0)
#   --solo=nome1,nome2            -> fa SOLO questi screenshot (implica --shots), es. --solo=ritratti,menu
#                                    nomi: menu stanza_dall_alto terza_persona spillatrice telefono pinza sopra_la_scrivania
#                                          rampa muro_di_fianco spalle_al_muro visuale_frontale a_terra garage macchinina aeroplanino nemici
#                                          forziere classifica storico ritratti armi
# Finisce con "TUTTO OK" oppure "CI SONO ERRORI".

cd "$(dirname "$0")/.." || exit 1
G=$(ls ../Godot/Godot_v*_console.exe 2>/dev/null | head -1)
if [ -z "$G" ]; then
	echo "Godot non trovato in ../Godot (serve il file Godot_v..._console.exe)"
	exit 1
fi
fail=0
shots=0; rapido=0; char=0; solo=""
for a in "$@"; do
	case $a in
		--shots) shots=1 ;;
		--rapido) rapido=1 ;;
		--char=*) char=${a#--char=} ;;
		--solo=*) solo=",${a#--solo=},"; shots=1 ;;
	esac
done

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
if [ $rapido = 1 ]; then
	run "partita personaggio $char" --headless --path . --quit-after 300 -- --autostart --char=$char
else
for c in 0 1 2 3 4 5; do
	run "partita personaggio $c" --headless --path . --quit-after 300 -- --autostart --char=$c
done
fi
if [ $rapido = 0 ]; then
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
echo "5) test veicoli: macchinina (gas, sterzo, rampa) e aeroplanino (decollo)"
out=$(timeout 240 "$G" --headless --fixed-fps 60 --path . -s res://tools/test_veicoli.gd 2>&1)
echo "$out" | grep -E "^  |TEST|ERROR" | head -30
echo "$out" | grep -q "TEST OK" || fail=1
echo "$out" | grep -qE "SCRIPT ERROR|Parse Error" && fail=1
echo "6) test nemici: ondate, inseguimento, spari, ondata successiva più forte"
out=$(timeout 300 "$G" --headless --fixed-fps 60 --path . -s res://tools/test_nemici.gd 2>&1)
echo "$out" | grep -E "^ondata|TEST|ERROR" | head -30
echo "$out" | grep -q "TEST OK" || fail=1
echo "$out" | grep -qE "SCRIPT ERROR|Parse Error" && fail=1
echo "7) test novità: classifica, nemici con alone e senza il tuo personaggio, forziere, zoom, storico"
out=$(timeout 300 "$G" --headless --fixed-fps 60 --path . -s res://tools/test_novita.gd 2>&1)
echo "$out" | grep -E "^ondata|^io:|^armi|^zoom|^storico|TEST|ERROR" | head -30
echo "$out" | grep -q "TEST OK" || fail=1
echo "$out" | grep -qE "SCRIPT ERROR|Parse Error" && fail=1
echo "8) test co-op online: chi ospita e un amico contro le stesse ondate"
out=$(bash tools/test_coop.sh 2>&1)
echo "$out" | tail -8
echo "$out" | tail -1 | grep -q "TEST OK" || fail=1

fi

# shot nome argomenti...  -> tools/shots/nome.png (saltato se --solo non lo nomina)
shot() {
	local name=$1; shift
	[ -n "$solo" ] && [[ "$solo" != *",$name,"* ]] && return
	timeout 90 "$G" "$@" "--shot=$dir/$name.png" >/dev/null 2>&1
}

if [ $shots = 1 ]; then
	echo "6) screenshot in tools/shots/"
	mkdir -p tools/shots
	dir=$(pwd -W 2>/dev/null || pwd)/tools/shots
	if [ -z "$solo" ]; then rm -f tools/shots/*.png; fi
	shot menu --path . --
	shot stanza_dall_alto --path . -- --autostart --overview
	shot terza_persona --path . -- --autostart --char=0 --door
	shot spillatrice --path . -- --autostart --char=4 --weapon=1 --door
	shot telefono --path . -- --autostart --char=1 --weapon=2 --door --front
	shot pinza --path . -- --autostart --char=2 --weapon=3 --door --front
	shot sopra_la_scrivania --path . -- --autostart --char=1 --desk
	shot rampa --path . -- --autostart --char=2 --ramp
	shot muro_di_fianco --path . -- --autostart --char=0 --wall
	shot spalle_al_muro --path . -- --autostart --char=0 --back
	shot visuale_frontale --path . -- --autostart --char=3 --door --front
	shot a_terra --path . -- --autostart --char=3 --door --prone
	shot garage --path . -- --autostart --char=0 --garage
	shot macchinina --path . -- --autostart --char=0 --guida
	shot aeroplanino --path . -- --autostart --char=3 --vola
	shot nemici --path . -- --autostart --char=0 --shotframe=600
	shot forziere --path . -- --autostart --char=4 --door --forziere --nonemici --shotframe=200
	shot classifica --path . -- --autostart --char=0 --door --classifica --nonemici
	shot storico --path . -- --storico
	shot ritratti --path . -s res://tools/ritratti.gd --
	shot armi --path . -s res://tools/armi.gd --
	ls tools/shots
fi

if [ $fail = 0 ]; then echo "TUTTO OK"; else echo "CI SONO ERRORI"; exit 1; fi
