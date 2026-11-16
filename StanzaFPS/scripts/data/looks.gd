extends RefCounted
## ASPETTO DELLE PERSONE VERE (Matteo, Broski): modello ARROTONDATO "vestito" con le loro FOTO.
## Un personaggio di data/characters.gd usa questo aspetto se ha  "look": "nome"  (chiave di LOOKS).
## Il modello lo costruisce actors/character_model.gd (_build_person). Tutto in metri di gioco (omino = 1,8 m).
## (La vecchia versione a quadratini è in archivio_personaggi_cubetti/.)
##
## FOTO: testa, busto e gambe sono "dipinti" con ritagli delle foto in persongg/, proiettati da davanti,
##   da dietro e di fianco. I ritagli sono in textures/persone/<photos>_<parte>_<vista>.png e si rifanno con
##   python tools/foto_personaggi.py   (lì si correggono i rettangoli di ritaglio).
##
## FORME (sezioni ovali dal basso verso l'alto, come anelli di un vaso):
##   anello = [y, mezza larghezza (x), mezza profondità (z), spostamento in avanti/indietro (z, negativo = avanti)]
##   head       anelli della testa, relativi all'attaccatura del collo (y = 0); deve andare dal mento alla
##              cima dei capelli, perché la foto della testa va da lì a lì
##   torso      anelli del busto, y = altezza da terra; dall'orlo della maglia al colletto
##   leg        anelli di UNA gamba, relativi all'anca (y = 0 anca, -0.85 suola); dall'orlo al bacino
##   shoe       anelli di una scarpa (stessi riferimenti della gamba), sole = suola
##   round      quanto sono "squadrate" le sezioni (2 = ovale, 4 = quasi rettangolo con angoli tondi)
##
## COLORI: skin (braccia, mani, collo), hair (cima della testa), shirt (maniche, spalle), pants (cima delle gambe),
##   shoe_colors = [tomaia, suola, dettaglio]
## Braccia: arm_r spessore (raggio), sleeve_r / sleeve_l frazione coperta dalla manica,
##   bracelets_r / bracelets_l colori dei braccialetti dal polso in su

const LOOKS := {
	# ------------------------------------------------------------------ MATTEO
	# alto e magro, capelli castano scuro spettinati, camicia salvia a maniche corte,
	# pantaloni neri morbidi, sneakers crema e beige, braccialetto d'argento a destra, cordino nero a sinistra
	"matteo": {
		"photos": "matteo",
		"skin": Color(0.86, 0.66, 0.56), "hair": Color(0.15, 0.1, 0.08),
		"shirt": Color(0.55, 0.565, 0.54), "pants": Color(0.05, 0.045, 0.06),
		"shoe_colors": [Color(0.93, 0.91, 0.86), Color(0.95, 0.94, 0.9), Color(0.84, 0.77, 0.65)],
		"round": 2.4,
		"head": [
			[0.02, 0.012, 0.012, -0.05],
			[0.03, 0.035, 0.05, -0.045],
			[0.055, 0.065, 0.085, -0.03],
			[0.1, 0.088, 0.105, -0.015],
			[0.16, 0.1, 0.115, -0.005],
			[0.22, 0.104, 0.118, 0.0],
			[0.27, 0.1, 0.115, 0.002],
			[0.3, 0.083, 0.098, 0.002],
			[0.315, 0.055, 0.068, 0.0],
			[0.32, 0.012, 0.012, 0.0],
		],
		"neck": [0.052, -0.04, 0.09],                  # raggio, da y, a y (relativi alla testa)
		"torso": [
			[0.86, 0.16, 0.09, 0.0],
			[0.865, 0.2, 0.118, 0.0],
			[1.0, 0.195, 0.115, 0.0],
			[1.15, 0.19, 0.115, 0.0],
			[1.28, 0.2, 0.118, 0.0],
			[1.39, 0.218, 0.12, 0.0],
			[1.45, 0.212, 0.112, 0.005],
			[1.485, 0.17, 0.094, 0.01],
			[1.505, 0.09, 0.07, 0.01],
			[1.51, 0.05, 0.05, 0.01],
		],
		"leg_x": 0.1,
		"leg": [
			[-0.74, 0.06, 0.07, 0.0],
			[-0.73, 0.078, 0.085, 0.0],
			[-0.55, 0.08, 0.088, 0.0],
			[-0.35, 0.085, 0.092, 0.0],
			[-0.15, 0.096, 0.1, 0.0],
			[0.0, 0.105, 0.11, 0.0],
			[0.05, 0.095, 0.1, 0.0],
			[0.06, 0.06, 0.06, 0.0],
		],
		"shoe": [
			[-0.835, 0.05, 0.13, -0.045],
			[-0.8, 0.058, 0.15, -0.045],
			[-0.77, 0.056, 0.14, -0.035],
			[-0.745, 0.05, 0.11, -0.015],
			[-0.72, 0.04, 0.06, 0.01],
			[-0.71, 0.02, 0.03, 0.01],
		],
		"sole": [-0.852, -0.822, 0.064, 0.158, -0.045],  # da y, a y, mezza larghezza, mezza lunghezza, avanti
		"arm_r": 0.042,
		"sleeve_r": 0.42, "sleeve_l": 0.3,
		"bracelets_r": [Color(0.82, 0.82, 0.85)],
		"bracelets_l": [Color(0.04, 0.04, 0.04)],
	},

	# ------------------------------------------------------------------ BROSKI
	# baffi, mullet, orecchini, collanine (nelle foto), maglietta nera,
	# jeans chiarissimi larghissimi che coprono le scarpe, sneakers bianche con dettagli rossi
	"broski": {
		"photos": "broski",
		"skin": Color(0.8, 0.58, 0.47), "hair": Color(0.09, 0.065, 0.055),
		"shirt": Color(0.07, 0.065, 0.075), "pants": Color(0.55, 0.68, 0.8),
		"shoe_colors": [Color(0.95, 0.95, 0.94), Color(0.95, 0.95, 0.94), Color(0.78, 0.1, 0.14)],
		"round": 2.4,
		"head": [
			[0.0, 0.012, 0.012, -0.05],
			[0.01, 0.04, 0.05, -0.045],
			[0.04, 0.075, 0.09, -0.03],
			[0.09, 0.1, 0.112, -0.015],
			[0.16, 0.114, 0.122, -0.005],
			[0.22, 0.118, 0.125, 0.0],
			[0.27, 0.112, 0.12, 0.003],
			[0.3, 0.092, 0.102, 0.003],
			[0.318, 0.06, 0.07, 0.0],
			[0.325, 0.012, 0.012, 0.0],
		],
		"neck": [0.058, -0.04, 0.08],
		"torso": [
			[0.86, 0.18, 0.1, 0.0],
			[0.865, 0.225, 0.13, 0.0],
			[1.0, 0.222, 0.128, 0.0],
			[1.15, 0.22, 0.128, 0.0],
			[1.28, 0.23, 0.13, 0.0],
			[1.39, 0.25, 0.132, 0.0],
			[1.45, 0.24, 0.122, 0.005],
			[1.485, 0.19, 0.1, 0.01],
			[1.505, 0.1, 0.075, 0.01],
			[1.51, 0.055, 0.055, 0.01],
		],
		"leg_x": 0.125,
		"leg": [
			[-0.8, 0.09, 0.11, -0.01],
			[-0.79, 0.125, 0.15, -0.01],
			[-0.6, 0.135, 0.16, -0.005],
			[-0.4, 0.138, 0.158, 0.0],
			[-0.2, 0.13, 0.148, 0.0],
			[0.0, 0.122, 0.135, 0.0],
			[0.05, 0.11, 0.12, 0.0],
			[0.06, 0.07, 0.07, 0.0],
		],
		"shoe": [
			[-0.835, 0.052, 0.13, -0.06],
			[-0.8, 0.06, 0.15, -0.06],
			[-0.77, 0.058, 0.14, -0.05],
			[-0.745, 0.05, 0.11, -0.03],
			[-0.72, 0.04, 0.06, 0.0],
			[-0.71, 0.02, 0.03, 0.0],
		],
		"sole": [-0.855, -0.815, 0.066, 0.16, -0.06],
		"arm_r": 0.05,
		"sleeve_r": 0.36, "sleeve_l": 0.25,
		"bracelets_r": [],
		"bracelets_l": [Color(0.82, 0.82, 0.85), Color(0.04, 0.04, 0.045), Color(0.45, 0.08, 0.12)],
	},
}
