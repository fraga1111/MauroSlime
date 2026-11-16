extends RefCounted
## ARMI. Tutti i personaggi hanno le stesse armi e possono cambiarle in partita
## (tasti 1, 2, 3, 4 · rotellina del mouse · Q = arma successiva). Nel menu si sceglie quella di partenza.
## Per aggiungere un'arma: copia un blocco { ... } e fai il modello in actors/gun_models.gd.
##
## name        nome a schermo
## model       modello in actors/gun_models.gd
## damage      danno per colpo
## fire_delay  secondi tra un colpo e l'altro (più basso = spara più veloce)
## auto        true = tieni premuto per sparare a raffica, false = un colpo per click
## mag         colpi nel caricatore     reserve  munizioni di scorta iniziali
## spread      dispersione dei colpi (1 = normale, più alto = meno preciso)
## kick        rinculo (1 = normale)
## flash       colore della fiammata quando spara
## tracer      (facoltativo) colore del colpo luminoso che si vede volare (actors/effetti.gd)
## splat       (facoltativo) colore della macchia dove colpisce, al posto del buco scuro

const LIST := [
	{
		"name": "EVIDENZIATORE",
		"model": "evidenziatore",
		"damage": 1, "fire_delay": 0.09, "auto": true,
		"mag": 30, "reserve": 180, "spread": 1.0, "kick": 1.0,
		"flash": Color(0.9, 1.0, 0.2),
		"tracer": Color(0.85, 1.0, 0.05), "splat": Color(0.85, 1.0, 0.1),   # giallo fluo
	},
	{
		"name": "SPILLATRICE",
		"model": "spillatrice",
		"damage": 3, "fire_delay": 0.22, "auto": false,
		"mag": 12, "reserve": 72, "spread": 0.6, "kick": 1.8,
		"flash": Color(0.9, 0.92, 1.0),
	},
	{
		"name": "TELEFONO",
		"model": "telefono",
		"damage": 1, "fire_delay": 0.065, "auto": true,
		"mag": 40, "reserve": 240, "spread": 1.4, "kick": 0.8,
		"flash": Color(0.6, 1.0, 0.6),
	},
	{
		"name": "SPILLATRICE A PINZA",
		"model": "pinza",
		"damage": 2, "fire_delay": 0.14, "auto": true,
		"mag": 20, "reserve": 140, "spread": 0.8, "kick": 1.3,
		"flash": Color(0.95, 0.95, 1.0),
	},
]
