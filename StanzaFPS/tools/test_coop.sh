#!/usr/bin/env bash
# TEST CO-OP: due copie del gioco senza grafica sullo stesso computer (una ospita, l'altra si unisce).
# Uso (da Git Bash nella cartella StanzaFPS):  bash tools/test_coop.sh   -> "TEST OK" oppure "TEST FALLITO"
cd "$(dirname "$0")/.."
G="../Godot/Godot_v4.7.2-stable_win64_console.exe"
log_h=$(mktemp)
log_c=$(mktemp)
timeout 120 "$G" --headless --path . -s res://tools/test_coop.gd -- --ruolo=host >"$log_h" 2>&1 &
ph=$!
sleep 4
timeout 110 "$G" --headless --path . -s res://tools/test_coop.gd -- --ruolo=client >"$log_c" 2>&1 &
pc=$!
wait $pc; rc=$?
wait $ph; rh=$?
grep -hE "^\[|SCRIPT ERROR|Parse Error" "$log_h" "$log_c" | head -40
rm -f "$log_h" "$log_c"
if [ $rc = 0 ] && [ $rh = 0 ]; then echo "TEST OK"; else echo "TEST FALLITO (host $rh, client $rc)"; exit 1; fi
