extends RefCounted
## TEXTURE PROCEDURALI (disegnate pixel per pixel, nessun file immagine).
## Uso: Textures.carpet(), Textures.window_view(1), ...  Ognuna ritorna un ImageTexture.

static func carpet() -> ImageTexture:
	var img := Image.create_empty(128, 128, false, Image.FORMAT_RGB8)
	var r := RandomNumberGenerator.new()
	r.seed = 11
	for y in 128:
		for x in 128:
			var v := 0.4 + r.randf() * 0.1
			var k := r.randf()
			if k < 0.08:
				v = 0.25
			elif k < 0.14:
				v = 0.62
			img.set_pixel(x, y, Color(v, v, v * 1.03))
	return _done(img)


## Vista dalla finestra: cielo, edifici, alberi, strada con auto. seed diverso = vista diversa.
static func window_view(seed_v: int) -> ImageTexture:
	var w := 96
	var h := 240
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGB8)
	var r := RandomNumberGenerator.new()
	r.seed = seed_v * 97
	for y in h:
		var t := float(y) / h
		for x in w:
			img.set_pixel(x, y, Color(0.42, 0.62, 0.95).lerp(Color(0.78, 0.86, 0.97), clampf(t / 0.45, 0, 1)))
	var building_cols := [Color(0.8, 0.75, 0.35), Color(0.6, 0.6, 0.6), Color(0.3, 0.35, 0.33)]
	for i in 3:
		var bx := r.randi_range(-10, 70)
		var bw := r.randi_range(25, 50)
		var by := r.randi_range(85, 115)
		var bc: Color = building_cols[i]
		img.fill_rect(Rect2i(bx, by, bw, 150 - by), bc)
		for wy in range(by + 6, 145, 10):
			for wx in range(bx + 4, bx + bw - 4, 9):
				img.fill_rect(Rect2i(wx, wy, 5, 5), Color(0.25, 0.3, 0.35))
	for i in 7:
		var cx := r.randi_range(0, w)
		var cy := r.randi_range(80, 140)
		var rad := r.randi_range(10, 22)
		var gc := Color(0.15, 0.35, 0.15).lerp(Color(0.6, 0.6, 0.15), r.randf() * 0.5)
		for y in range(cy - rad, cy + rad):
			for x in range(cx - rad, cx + rad):
				if x >= 0 and x < w and y >= 0 and y < h and Vector2(x - cx, y - cy).length() < rad:
					img.set_pixel(x, y, gc.darkened(r.randf() * 0.2))
	img.fill_rect(Rect2i(0, 150, w, 90), Color(0.42, 0.42, 0.44))
	img.fill_rect(Rect2i(0, 195, w, 2), Color(0.9, 0.9, 0.9))
	var car_cols := [Color(0.1, 0.1, 0.12), Color(0.85, 0.85, 0.88), Color(0.5, 0.52, 0.55), Color(0.7, 0.1, 0.12), Color(0.2, 0.25, 0.35)]
	for row in 3:
		var y0 := 158 + row * 26
		var x := r.randi_range(-20, 0)
		while x < w:
			var cw := r.randi_range(28, 36)
			var cc: Color = car_cols[r.randi() % car_cols.size()]
			img.fill_rect(Rect2i(maxi(x, 0), y0, mini(cw, w - maxi(x, 0)), 14), cc)
			img.fill_rect(Rect2i(maxi(x + 6, 0), y0 + 2, maxi(mini(cw - 12, w - maxi(x + 6, 0)), 0), 5), Color(0.15, 0.2, 0.25))
			x += cw + r.randi_range(4, 12)
	return _done(img)


## Tenda plissettata (righe orizzontali chiare/scure).
static func blind() -> ImageTexture:
	var img := Image.create_empty(16, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		var v := 0.97 if y % 4 < 2 else 0.85
		for x in 16:
			img.set_pixel(x, y, Color(v, v, v))
	return _done(img)


## Schermo: desktop con finestre e barra delle applicazioni.
static func screen_desktop() -> ImageTexture:
	var w := 192
	var h := 108
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		for x in w:
			var t := float(y) / h * 0.8 + float(x) / w * 0.2
			img.set_pixel(x, y, Color(0.1, 0.25, 0.55).lerp(Color(0.45, 0.2, 0.55), t))
	img.fill_rect(Rect2i(0, h - 8, w, 8), Color(0.12, 0.12, 0.14))
	for i in 6:
		img.fill_rect(Rect2i(4 + i * 10, h - 6, 6, 4), Color(0.4, 0.6, 0.9))
	for i in 4:
		img.fill_rect(Rect2i(6, 6 + i * 14, 9, 9), Color(0.95, 0.8, 0.3))
	img.fill_rect(Rect2i(30, 14, 100, 62), Color(0.96, 0.96, 0.97))
	img.fill_rect(Rect2i(30, 14, 100, 7), Color(0.2, 0.45, 0.8))
	for i in 6:
		img.fill_rect(Rect2i(36, 28 + i * 7, 30 + (i * 17) % 50, 3), Color(0.55, 0.55, 0.6))
	img.fill_rect(Rect2i(100, 50, 70, 40), Color(0.15, 0.15, 0.17))
	img.fill_rect(Rect2i(100, 50, 70, 6), Color(0.3, 0.3, 0.33))
	return _done(img)


## Schermo: editor di codice (sfondo scuro, righe colorate).
static func screen_code() -> ImageTexture:
	var w := 192
	var h := 108
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGB8)
	img.fill(Color(0.1, 0.11, 0.14))
	img.fill_rect(Rect2i(0, 0, 30, h), Color(0.14, 0.15, 0.18))
	var cols := [Color(0.5, 0.8, 0.4), Color(0.9, 0.6, 0.3), Color(0.4, 0.65, 1.0), Color(0.8, 0.8, 0.85), Color(0.85, 0.45, 0.8)]
	var r := RandomNumberGenerator.new()
	r.seed = 3
	var indent := 0
	for line in 24:
		var y := 4 + line * 4
		indent = clampi(indent + r.randi_range(-1, 1), 0, 4)
		var x := 36 + indent * 8
		for s in r.randi_range(1, 4):
			var seg_len := r.randi_range(6, 26)
			if x + seg_len > w - 4:
				break
			img.fill_rect(Rect2i(x, y, seg_len, 2), cols[r.randi() % cols.size()])
			x += seg_len + 4
	return _done(img)


## Schermo: foglio di calcolo.
static func screen_sheet() -> ImageTexture:
	var w := 192
	var h := 108
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGB8)
	img.fill(Color(0.97, 0.97, 0.97))
	img.fill_rect(Rect2i(0, 0, w, 10), Color(0.13, 0.45, 0.25))
	for y in range(14, h, 6):
		img.fill_rect(Rect2i(0, y, w, 1), Color(0.82, 0.82, 0.82))
	for x in range(20, w, 28):
		img.fill_rect(Rect2i(x, 10, 1, h - 10), Color(0.82, 0.82, 0.82))
	var r := RandomNumberGenerator.new()
	r.seed = 5
	for y in range(16, h - 4, 6):
		for x in range(22, w - 20, 28):
			if r.randf() < 0.7:
				img.fill_rect(Rect2i(x + 2, y, r.randi_range(6, 20), 2), Color(0.3, 0.3, 0.3))
	return _done(img)


static func _done(img: Image) -> ImageTexture:
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
