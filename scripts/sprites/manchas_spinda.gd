@tool
## manchas_spinda.gd
## Manchas de SPINDA según su valor de personalidad (pokeruby DrawSpindaSpots,
## `src/pokemon_3.c`). El juego original suma 4 al índice de paleta de los
## píxeles crema (índices 1-3) bajo cuatro máscaras de 16×16 cuya posición sale
## de los cuatro bytes del PID. Aquí los sprites son RGBA, así que se sustituye
## cada crema por su color de mancha (la tabla es inequívoca: ningún otro índice
## usa esos tres colores). Solo se aplica al sprite FRONTAL; la espalda nunca
## lleva manchas.
##
## Análisis y validación: `documentacion/20261002-analisis-manchas-spinda-pokeruby.md`.
class_name ManchasSpinda
extends RefCounted

## Nombre interno de la especie (tabla Pokemon).
const NOMBRE_INTERNO: String = "SPINDA"

## Clave de `EstructuraGuardado.pokedex` con la personalidad del SPINDA de la
## POKéDEX (pokeruby `gSaveBlock2.pokedex.spindaPersonality`).
const CLAVE_POKEDEX: String = "personalidad_spinda"

## Desplazamiento de `graficos/pokemon/front{,-shiny}/SPINDA.png` respecto al
## front.png del decomp (bbox Godot (13,8) frente a decomp (16,14)). Si se
## cambian los PNG por otros con otro encuadre hay que recalcularlo.
const DESPLAZAMIENTO_SPRITE: Vector2i = Vector2i(-3, -6)

## Lado de cada máscara (16 filas de 16 bits).
const LADO_MASCARA: int = 16

## gSpindaSpotGraphics: esquina superior izquierda en coordenadas del decomp
## (con el nibble del PID a 8, es decir, sin desplazar) y 16 filas u16.
## El bit 0 de cada fila es la columna izquierda.
const MANCHAS: Array[Dictionary] = [
	{"origen": Vector2i(16, 14), "filas": [0x0070, 0x01FC, 0x03FE, 0x07FE, 0x07FF, 0x0FFF, 0x0FFF, 0x0FFF, 0x07FE, 0x07FE, 0x03FC, 0x01E0, 0, 0, 0, 0]},
	{"origen": Vector2i(40, 15), "filas": [0x01E0, 0x03F8, 0x07FC, 0x0FFE, 0x0FFE, 0x1FFF, 0x1FFF, 0x1FFF, 0x0FFE, 0x0FFE, 0x07FC, 0x07F8, 0x00E0, 0, 0, 0]},
	{"origen": Vector2i(22, 32), "filas": [0x001C, 0x003E, 0x007F, 0x007F, 0x007F, 0x007F, 0x007F, 0x003E, 0x001C, 0, 0, 0, 0, 0, 0, 0]},
	{"origen": Vector2i(34, 33), "filas": [0x003C, 0x007E, 0x00FF, 0x00FF, 0x00FF, 0x00FF, 0x00FF, 0x007E, 0x003C, 0, 0, 0, 0, 0, 0, 0]},
]

## Crema (índices 1-3) → mancha (índices 5-7), como RGBA8 empaquetado
## (`Color.to_rgba32()`). Se compara en enteros para no fallar por redondeo.
const COLORES_NORMAL: Dictionary = {
	0xF7E7ADFF: 0xDE8C4AFF, # (247,231,173) → (222,140,74)
	0xE7D6A5FF: 0xDE6B39FF, # (231,214,165) → (222,107,57)
	0xC6B584FF: 0xB55A29FF, # (198,181,132) → (181,90,41)
}

## Variocolor: los mismos cremas (el PNG front-shiny los comparte) → verdes.
const COLORES_SHINY: Dictionary = {
	0xF7E7ADFF: 0xB5C65AFF, # (247,231,173) → (181,198,90)
	0xE7D6A5FF: 0x94A539FF, # (231,214,165) → (148,165,57)
	0xC6B584FF: 0x738418FF, # (198,181,132) → (115,132,24)
}


## ¿La especie `nombre_interno` lleva manchas según su personalidad?
static func aplica_a(nombre_interno: String) -> bool:
	return nombre_interno.strip_edges().to_upper() == NOMBRE_INTERNO


## Pinta las manchas sobre `imagen` (sprite frontal de SPINDA), modificándola
## en sitio. Convierte la imagen a RGBA8 si hace falta. Los píxeles fuera del
## lienzo se ignoran y solo cambian los tres colores crema.
static func aplicar(imagen: Image, personalidad: int, es_shiny: bool) -> void:
	if imagen == null or imagen.is_empty():
		return
	if imagen.is_compressed() and imagen.decompress() != OK:
		push_warning("[MANCHAS_SPINDA] No se pudo descomprimir la imagen")
		return
	if imagen.get_format() != Image.FORMAT_RGBA8:
		imagen.convert(Image.FORMAT_RGBA8)

	var ancho: int = imagen.get_width()
	var alto: int = imagen.get_height()
	var colores: Dictionary = COLORES_SHINY if es_shiny else COLORES_NORMAL
	# int es de 64 bits en GDScript: el PID de Gen 3 es u32.
	var pid: int = personalidad & 0xFFFFFFFF

	for mancha: Dictionary in MANCHAS:
		# Nibble bajo → X, nibble alto → Y; desplazamiento = nibble − 8.
		var esquina: Vector2i = (mancha["origen"] as Vector2i) + DESPLAZAMIENTO_SPRITE \
				+ Vector2i((pid & 0xF) - 8, ((pid >> 4) & 0xF) - 8)
		var filas: Array = mancha["filas"]
		for j in LADO_MASCARA:
			var y: int = esquina.y + j
			if y < 0 or y >= alto:
				continue
			var fila: int = filas[j]
			for b in LADO_MASCARA:
				if (fila >> b) & 1 == 0:
					continue
				var x: int = esquina.x + b
				if x < 0 or x >= ancho:
					continue
				var actual: int = imagen.get_pixel(x, y).to_rgba32()
				# Un píxel ya manchado no es crema: nunca recibe un segundo cambio
				# (en el original, el índice 5-7 no cumple la condición 1-3).
				if colores.has(actual):
					imagen.set_pixel(x, y, Color.hex(colores[actual]))
		# Siguiente byte del PID para la siguiente mancha.
		pid >>= 8


## Devuelve una textura NUEVA con las manchas aplicadas; `base` no se toca.
## Si `base` es nula o no tiene imagen, devuelve `base`.
static func textura_con_manchas(base: Texture2D, personalidad: int, es_shiny: bool) -> Texture2D:
	if base == null:
		return null
	var original: Image = base.get_image()
	if original == null or original.is_empty():
		return base
	# Se duplica siempre: con el renderer dummy (--headless) get_image() devuelve
	# la imagen interna de la textura, y modificarla mancharía la base.
	var imagen := original.duplicate() as Image
	aplicar(imagen, personalidad, es_shiny)
	return ImageTexture.create_from_image(imagen)


## pokeruby atkF1_trysetcaughtmondexflags: la PRIMERA captura en combate de un
## SPINDA guarda su personalidad en la POKéDEX (huevos e intercambios no la
## tocan). `ya_atrapado` debe consultarse ANTES de marcar la especie como
## atrapada. Devuelve true si se guardó.
static func registrar_primera_captura(pokedex: Dictionary, nombre_interno: String, personalidad: int, ya_atrapado: bool) -> bool:
	if ya_atrapado or not aplica_a(nombre_interno):
		return false
	pokedex[CLAVE_POKEDEX] = personalidad & 0xFFFFFFFF
	return true


## Personalidad del SPINDA de la POKéDEX (0 = patrón "de fábrica", como
## pokeruby al iniciar la POKéDEX). Tolera el float que deja el JSON.
static func personalidad_en_pokedex(pokedex: Dictionary) -> int:
	return int(pokedex.get(CLAVE_POKEDEX, 0)) & 0xFFFFFFFF
