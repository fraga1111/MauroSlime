# Mauro of Duty

Il gioco si chiamava **MauroSlime** (il repository e la cartella dei salvataggi hanno ancora quel nome).

Sparatutto in terza persona fatto con **Godot 4.7.2**: sei un omino alto 10 cm dentro un vero ufficio,
con evidenziatori, spillatrici e telefoni come armi. Si gioca anche in **multiplayer sulla stessa rete**.

## Come giocare (Windows)

1. Scarica **[Gioca.bat](https://github.com/fraga1111/MauroSlime/raw/main/Gioca.bat)**
   (se il browser lo apre come testo: tasto destro sul link → "Salva link con nome").
2. Mettilo in una cartella qualsiasi (es. sul Desktop) e fai **doppio clic**.
   - La prima volta scarica Godot (circa 85 MB) e prepara il gioco: ci vuole qualche minuto.
   - Le volte dopo scarica da solo l'ultima versione del gioco e parte subito.
3. Se Windows avvisa "PC protetto da Windows": **Ulteriori informazioni → Esegui comunque**.
4. La prima volta che giochi in multiplayer Windows chiede di consentire Godot sulla rete: rispondi **Sì**.

## Multiplayer

Nel menu, pannello **MULTIPLAYER** in alto a destra:
- uno preme **OSPITA PARTITA**;
- gli altri vedono comparire **ENTRA: partita di ...** (oppure scrivono l'IP di chi ospita e premono **UNISCITI**).

Funziona sulla stessa rete (ufficio, casa). Tutti devono avere la stessa versione: con `Gioca.bat` è automatico.

## Comandi

WASD muovi · Shift corri · Spazio salta · B super salto · Ctrl accovacciati (correndo scivoli) · Z a terra ·
Click sinistro spara · Click destro mira · R ricarica · 1-4 / rotellina / Q cambia arma · V visuale frontale ·
T aspetto Blender/Minecraft (Matteo, Broski) · Esc libera il mouse

## Per chi modifica il gioco

Guida al progetto: [CLAUDE.md](CLAUDE.md). Godot non è nel repository (è troppo grande):
mettilo nella cartella `Godot/` oppure lascia che lo scarichi `Gioca.bat`.
