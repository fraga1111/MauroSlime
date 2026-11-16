extends RefCounted
## PERSONAGGI GIOCABILI. Ogni voce di LIST = una scheda nel menu (l'ordine è quello del menu).
## Per aggiungere un personaggio: copia un blocco { ... }, cambia i valori. Nient'altro da toccare.
## Tutti i personaggi sono UGUALI come abilità (vita, velocità, salto in config.gd)
## e possono usare tutte le armi (data/weapons.gd): l'arma si sceglie nel menu dopo il personaggio
## e si può cambiare anche in partita. Cambia solo l'aspetto.
##
## Testi:     name (nome nella scheda del menu)
## Aspetto:   hat        copricapo: "helmet" | "bandana" | "hardhat"  (nuovi in actors/character_model.gd)
##            scale      grandezza dell'omino (1 = 1,8 m di gioco; solo aspetto)
##            skin, uniform (busto/braccia), uniform2 (gambe/zaino), vest (giubbotto),
##            hat_color, accent (colore del personaggio in menu e dettagli)
##            look       (al posto di hat/skin/uniform...) persona vera: chiave di data/looks.gd

const LIST := [
	{
		"name": "MAURO",
		"hat": "helmet", "scale": 1.0,
		"skin": Color(0.94, 0.76, 0.6),
		"uniform": Color(0.33, 0.4, 0.24), "uniform2": Color(0.24, 0.29, 0.17),
		"vest": Color(0.42, 0.37, 0.25), "hat_color": Color(0.27, 0.33, 0.19),
		"accent": Color(0.35, 0.95, 0.4),
	},
	{
		"name": "ANTONINO",
		"hat": "bandana", "scale": 0.95,
		"skin": Color(0.78, 0.58, 0.44),
		"uniform": Color(0.13, 0.13, 0.15), "uniform2": Color(0.09, 0.09, 0.1),
		"vest": Color(0.2, 0.2, 0.23), "hat_color": Color(0.9, 0.15, 0.15),
		"accent": Color(1.0, 0.3, 0.3),
	},
	{
		"name": "JESN",
		"hat": "hardhat", "scale": 1.12,
		"skin": Color(0.62, 0.44, 0.32),
		"uniform": Color(0.3, 0.33, 0.4), "uniform2": Color(0.22, 0.24, 0.3),
		"vest": Color(1.0, 0.5, 0.05), "hat_color": Color(1.0, 0.82, 0.1),
		"accent": Color(1.0, 0.65, 0.15),
	},
	{
		"name": "MATTEO",
		"look": "matteo", "scale": 1.06,
		"accent": Color(0.6, 0.85, 0.55),
	},
	{
		"name": "BROSKI",
		"look": "broski", "scale": 1.0,
		"accent": Color(0.45, 0.75, 1.0),
	},
]
