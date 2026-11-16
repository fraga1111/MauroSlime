extends RefCounted
## VERSIONE "MINECRAFT" DELLE PERSONE VERE (Matteo, Broski): tutta a cubi, pochi dettagli, leggerissima.
## Nel menu, scelto Matteo o Broski, il pulsante ASPETTO (tasto T) passa da BLENDER a MINECRAFT.
## La usa actors/character_model.gd (_build_cubes) quando il personaggio ha  "stile": "minecraft".
## La chiave è la stessa di data/looks.gd ("look" del personaggio). Tutto in metri di gioco (omino = 1,8 m).
##
## pal      tavolozza: una LETTERA -> un colore. Le stesse lettere servono nei disegni e nei blocchi.
## shiny    lettere lucide (metallo, perle)     depth  spessore dei quadratini per lettera (default 0.01)
##
## DISEGNI A QUADRATINI (pixel art): array di righe, dall'alto in basso; "." = niente (si vede sotto).
##   face   faccia vista DA DAVANTI: colonna 0 = sinistra di chi guarda (= destra del personaggio). 10×10
##   side   fianchi della testa: colonna 0 = davanti (naso), ultima = nuca. Uguale per i due lati. 10×10
##   back   nuca vista da dietro. 10×10
##   shirt_front / shirt_back   busto: 10 colonne, righe da 1/13 dell'altezza, partendo dal colletto
##
## BLOCCHI: [dimensioni, posizione, lettera, (rotazione Y in gradi)]
##   head_boxes  relativi alla testa (y = 0 attaccatura del collo, cranio da 0.04 a 0.32)
##   leg_boxes   relativi all'anca (y = 0 anca, -0.85 suola). x positiva = verso l'ESTERNO: valgono per le due gambe
##   torso_boxes relativi al busto (y = altezza da terra, z negativa = davanti): collane, tasche...
##
## Corpo:  torso [dimensioni, y centro, lettera]   hem = orlo della maglia   leg_x = distanza delle gambe dal centro
## Braccia: arm_w spessore, sleeve lettera e frazione coperta dalla manica (_r destro, _l sinistro),
##          bracelets_r / bracelets_l = lettere dei braccialetti dal polso in su

const LOOKS := {
	# ------------------------------------------------------------------ MATTEO
	# alto e magro, capelli castano scuro spettinati in su, camicia salvia a maniche corte,
	# pantaloni neri morbidi, sneakers color crema, orecchino a sinistra, braccialetti ai polsi
	"matteo": {
		"pal": {
			"k": Color(0.93, 0.77, 0.66), "K": Color(0.84, 0.65, 0.55),   # pelle, ombra (naso/orecchie)
			"h": Color(0.16, 0.11, 0.08), "b": Color(0.2, 0.14, 0.1),      # capelli, sopracciglia
			"w": Color(0.95, 0.95, 0.93), "e": Color(0.3, 0.2, 0.12),      # occhi
			"m": Color(0.66, 0.42, 0.4), "t": Color(0.76, 0.63, 0.55),     # labbra, barba corta
			"s": Color(0.55, 0.59, 0.5), "c": Color(0.6, 0.64, 0.55),      # camicia, colletto
			"d": Color(0.47, 0.51, 0.43), "p": Color(0.5, 0.54, 0.46),     # cuciture, abbottonatura
			"o": Color(0.66, 0.69, 0.62),                                  # bottoni
			"x": Color(0.82, 0.82, 0.85), "n": Color(0.05, 0.05, 0.05),    # argento, cordino nero
			"P": Color(0.08, 0.08, 0.09), "Q": Color(0.04, 0.04, 0.05),    # pantaloni, cuciture
			"W": Color(0.94, 0.93, 0.89), "C": Color(0.96, 0.94, 0.88),    # suola, tomaia
			"B": Color(0.84, 0.77, 0.65), "L": Color(0.98, 0.97, 0.93),    # camoscio beige, lacci
		},
		"shiny": "x",
		"depth": {"h": 0.016, "c": 0.022},
		"face": [
			"hhhhhhhhhh",
			"hh......hh",
			"..........",
			".bbb..bbb.",
			"..we..ew..",
			"....KK....",
			"....KK....",
			"...tmmt...",
			"..tttttt..",
			"...tttt...",
		],
		"side": [
			"hhhhhhhhhh",
			".hhhhhhhhh",
			"..hhhhhhhh",
			"...h..hhhh",
			"...h...hhh",
			"...h...hhh",
			"........hh",
			"..tt....hh",
			".ttt....h.",
			".tt.......",
		],
		"back": [
			"hhhhhhhhhh", "hhhhhhhhhh", "hhhhhhhhhh", "hhhhhhhhhh", "hhhhhhhhhh",
			"hhhhhhhhhh", "hhhhhhhhhh", "hhhhhhhhhh", ".hhhhhhhh.", "..hhhhhh..",
		],
		"head_boxes": [
			[Vector3(0.312, 0.05, 0.312), Vector3(0, 0.34, 0), "h"],              # calotta
			[Vector3(0.12, 0.05, 0.1), Vector3(-0.03, 0.385, -0.09), "h", 12.0],  # ciuffi spettinati
			[Vector3(0.09, 0.065, 0.08), Vector3(0.06, 0.39, -0.08), "h", -20.0],
			[Vector3(0.13, 0.04, 0.12), Vector3(0.0, 0.375, 0.03), "h", 8.0],
			[Vector3(0.08, 0.035, 0.09), Vector3(-0.09, 0.37, 0.08), "h", -10.0],
			[Vector3(0.07, 0.03, 0.07), Vector3(0.09, 0.37, 0.07), "h", 25.0],
			[Vector3(0.035, 0.05, 0.02), Vector3(0.03, 0.31, -0.155), "h"],       # ciocca sulla fronte
			[Vector3(0.012, 0.028, 0.012), Vector3(-0.168, 0.12, 0.02), "x"],     # orecchino (orecchio sinistro)
			[Vector3(0.128, 0.008, 0.128), Vector3(0, 0.0, 0), "x"],              # catenina
		],
		"torso": [Vector3(0.46, 0.6, 0.24), 1.17, "s"],
		"hem": [Vector3(0.48, 0.07, 0.26), 0.87, "s"],
		"shirt_front": [
			"ccckkkkccc",
			".ccckkccc.",
			"..ckxxkc..",
			"...ckkc...",
			"....pp....",
			"....po....",
			"....pp....",
			"....po....",
			"....pp....",
			"....po....",
			"....pp....",
			"....po....",
			"....pp....",
		],
		"shirt_back": [
			"cccccccccc",
			"..........",
			"..........",
			"dddddddddd",
		],
		"leg_x": 0.12,
		"leg_boxes": [
			[Vector3(0.2, 0.42, 0.23), Vector3(0, -0.2, 0), "P"],          # coscia
			[Vector3(0.19, 0.3, 0.22), Vector3(0, -0.54, 0), "P"],         # stinco
			[Vector3(0.2, 0.04, 0.23), Vector3(0, -0.68, 0), "P"],         # orlo morbido
			[Vector3(0.006, 0.6, 0.02), Vector3(0.1, -0.38, 0), "Q"],      # cucitura laterale
			[Vector3(0.2, 0.05, 0.33), Vector3(0, -0.825, -0.045), "W"],   # suola
			[Vector3(0.18, 0.1, 0.29), Vector3(0, -0.75, -0.035), "C"],    # tomaia
			[Vector3(0.17, 0.07, 0.07), Vector3(0, -0.765, -0.165), "B"],  # punta in camoscio
			[Vector3(0.186, 0.08, 0.05), Vector3(0, -0.755, 0.095), "B"],  # tallone in camoscio
			[Vector3(0.006, 0.05, 0.09), Vector3(0.092, -0.75, -0.03), "B"],  # fascia laterale
			[Vector3(0.07, 0.015, 0.13), Vector3(0, -0.695, -0.09), "L"],  # lacci
		],
		"arm_w": 0.1,
		"sleeve": "s", "sleeve_r": 0.5, "sleeve_l": 0.33,
		"bracelets_r": ["x"],
		"bracelets_l": ["n"],
	},

	# ------------------------------------------------------------------ BROSKI
	# baffi folti, taglio mullet (lati rasati, lunghi dietro), orecchini (cerchietto a destra,
	# perla a sinistra), collanine, maglietta nera, jeans chiarissimi larghissimi, sneakers bianche e rosse
	"broski": {
		"pal": {
			"k": Color(0.85, 0.65, 0.52), "K": Color(0.74, 0.54, 0.42),    # pelle, ombra
			"h": Color(0.15, 0.1, 0.07), "f": Color(0.5, 0.4, 0.33),       # capelli, sfumatura rasata
			"b": Color(0.13, 0.08, 0.05), "M": Color(0.12, 0.08, 0.05),    # sopracciglia, baffi
			"w": Color(0.95, 0.94, 0.92), "e": Color(0.22, 0.13, 0.07),    # occhi
			"m": Color(0.55, 0.32, 0.3), "t": Color(0.62, 0.48, 0.39),     # labbra, barba corta
			"s": Color(0.12, 0.11, 0.105), "r": Color(0.18, 0.17, 0.16),   # maglietta nera, girocollo
			"n": Color(0.04, 0.04, 0.045), "g": Color(0.78, 0.7, 0.55),    # catena nera, perline
			"x": Color(0.82, 0.82, 0.85), "O": Color(0.96, 0.95, 0.92),    # argento, perla
			"V": Color(0.45, 0.08, 0.12),                                  # cordino bordeaux
			"J": Color(0.5, 0.66, 0.8), "j": Color(0.61, 0.75, 0.87),     # jeans, zone sbiadite
			"D": Color(0.4, 0.54, 0.68),                                  # pieghe e tasche
			"W": Color(0.95, 0.95, 0.94), "R": Color(0.78, 0.1, 0.14),     # sneakers bianche, dettagli rossi
		},
		"shiny": "xOn",
		"depth": {"h": 0.016, "M": 0.02, "f": 0.006, "r": 0.016, "n": 0.018, "g": 0.02},
		"face": [
			"hhhhhhhhhh",
			"hhh.hh.hhh",
			"f........f",
			".bbb..bbb.",
			"..we..ew..",
			"....KK....",
			"..MMMMMM..",
			"..MtmmtM..",
			"..tttttt..",
			"...tttt...",
		],
		"side": [
			"hhhhhhhhhh",
			"hhhhhhhhhh",
			".ffffffhhh",
			"..fff..hhh",
			"..ff...hhh",
			"..ff...hhh",
			"..f....hhh",
			"tt.....hhh",
			"ttt...hhhh",
			"tt...hhhhh",
		],
		"back": [
			"hhhhhhhhhh", "hhhhhhhhhh", "hhhhhhhhhh", "hhhhhhhhhh", "hhhhhhhhhh",
			"hhhhhhhhhh", "hhhhhhhhhh", "hhhhhhhhhh", "hhhhhhhhhh", "hhhhhhhhhh",
		],
		"head_boxes": [
			[Vector3(0.312, 0.045, 0.312), Vector3(0, 0.338, 0), "h"],            # calotta
			[Vector3(0.14, 0.045, 0.12), Vector3(0.03, 0.38, -0.08), "h", -10.0], # ciuffo spettinato
			[Vector3(0.1, 0.04, 0.1), Vector3(-0.06, 0.375, -0.02), "h", 15.0],
			[Vector3(0.12, 0.04, 0.12), Vector3(0.02, 0.372, 0.07), "h", 5.0],
			[Vector3(0.05, 0.045, 0.02), Vector3(0.05, 0.3, -0.153), "h"],        # frangetta
			[Vector3(0.04, 0.035, 0.02), Vector3(-0.045, 0.305, -0.153), "h"],
			[Vector3(0.26, 0.15, 0.04), Vector3(0, 0.035, 0.157), "h"],           # mullet: lunghi dietro
			[Vector3(0.035, 0.11, 0.09), Vector3(0.13, 0.045, 0.12), "h"],
			[Vector3(0.035, 0.11, 0.09), Vector3(-0.13, 0.045, 0.12), "h"],
			[Vector3(0.012, 0.03, 0.026), Vector3(0.168, 0.12, 0.015), "x"],      # cerchietto (orecchio destro)
			[Vector3(0.006, 0.03, 0.006), Vector3(-0.168, 0.115, 0.015), "x"],    # perla (orecchio sinistro)
			[Vector3(0.026, 0.026, 0.026), Vector3(-0.168, 0.088, 0.015), "O"],
			[Vector3(0.142, 0.016, 0.142), Vector3(0, 0.0, 0), "n"],              # collanine al collo
			[Vector3(0.136, 0.012, 0.136), Vector3(0, 0.02, 0), "n"],
		],
		"torso": [Vector3(0.5, 0.6, 0.26), 1.17, "s"],
		"hem": [Vector3(0.52, 0.07, 0.28), 0.87, "s"],
		"shirt_front": [
			"rrrkkkkrrr",
			"...rrrr...",
		],
		"torso_boxes": [                                             # collanine sul petto
			[Vector3(0.17, 0.014, 0.02), Vector3(0, 1.458, -0.14), "n"],
			[Vector3(0.11, 0.014, 0.02), Vector3(0, 1.44, -0.14), "n"],
			[Vector3(0.05, 0.02, 0.024), Vector3(-0.02, 1.447, -0.142), "g"],
		],
		"shirt_back": [
			"..rrrrrr..",
		],
		"leg_x": 0.145,
		"leg_boxes": [
			[Vector3(0.27, 0.3, 0.28), Vector3(0, -0.15, 0), "J"],              # jeans a palloncino
			[Vector3(0.29, 0.26, 0.34), Vector3(0.005, -0.41, -0.01), "J"],
			[Vector3(0.28, 0.18, 0.32), Vector3(0, -0.61, 0), "J"],
			[Vector3(0.26, 0.07, 0.3), Vector3(0, -0.725, -0.01), "J"],       # orlo che copre la scarpa
			[Vector3(0.12, 0.2, 0.01), Vector3(0.0, -0.2, -0.142), "j"],       # sbiaditure
			[Vector3(0.14, 0.16, 0.01), Vector3(0.01, -0.42, -0.182), "j"],
			[Vector3(0.012, 0.25, 0.012), Vector3(-0.045, -0.14, -0.143), "D"],  # pieghe
			[Vector3(0.012, 0.2, 0.012), Vector3(0.045, -0.12, -0.143), "D"],
			[Vector3(0.012, 0.3, 0.012), Vector3(-0.03, -0.42, -0.183), "D"],
			[Vector3(0.012, 0.1, 0.035), Vector3(0.137, -0.06, -0.08), "D"],    # tasca
			[Vector3(0.21, 0.07, 0.33), Vector3(0, -0.815, -0.05), "W"],       # suola alta
			[Vector3(0.215, 0.018, 0.335), Vector3(0, -0.83, -0.05), "R"],     # riga rossa sulla suola
			[Vector3(0.18, 0.07, 0.09), Vector3(0, -0.76, -0.17), "W"],        # punta
			[Vector3(0.006, 0.025, 0.09), Vector3(0.093, -0.765, -0.14), "R"], # dettaglio rosso esterno
			[Vector3(0.006, 0.025, 0.09), Vector3(-0.093, -0.765, -0.14), "R"],# dettaglio rosso interno
		],
		"arm_w": 0.12,
		"sleeve": "s", "sleeve_r": 0.4, "sleeve_l": 0.27,
		"bracelets_r": [],
		"bracelets_l": ["x", "n", "V"],
	},
}
