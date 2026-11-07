## fondo_gba.gd
## Un fondo de tiles de la GBA (BG de 32x32 entradas, 256x256 px, con repetición) dibujado sobre la pantalla
## lógica de 240x160. Lo usa el viaje en TELEFÉRICO (ViajeTeleferico), que lo maneja como pokeruby: copia y rellena
## trozos del mapa (CableCarUtil_CopyWrapped / FillWrapped) y mueve el desplazamiento (REG_BGxHOFS / VOFS).
##
## Cada entrada del mapa es un u16 como en la GBA: tile en los bits 0-9, volteo horizontal el 10, vertical el 11 y
## paleta del 12 al 15. El atlas (graficos/teleferico/fondo.png) trae las cuatro paletas ya aplicadas, una debajo de
## otra, con el índice 0 transparente. La entrada 0 (tile 0 de la paleta 0) no se dibuja. No se dibujan los volteos:
## ningún mapa del viaje los usa.
class_name FondoGba
extends Control

const ATLAS: Texture2D = preload("res://graficos/teleferico/fondo.png")
const LADO: int = 32
const TILE: int = 8
const ALTO_PALETA: int = 256
const PALETAS: int = 4
const PANTALLA := Vector2i(240, 160)

## 32x32 entradas, fila a fila.
var mapa: PackedInt32Array = PackedInt32Array()
## REG_BGxHOFS / REG_BGxVOFS (0-255, como los u8 del original).
var desplazamiento: Vector2i = Vector2i.ZERO:
	set(valor):
		desplazamiento = Vector2i(valor.x & 0xFF, valor.y & 0xFF)
		queue_redraw()


func _init() -> void:
	mapa.resize(LADO * LADO)
	mapa.fill(0)
	size = Vector2(PANTALLA)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## CableCarUtil_FillWrapped: rellena un rectángulo del mapa (con vuelta al otro lado).
func rellenar(valor: int, izquierda: int, arriba: int, ancho: int, alto: int) -> void:
	var y := arriba & 0xFF
	for _i in alto:
		var x := izquierda & 0xFF
		for _j in ancho:
			mapa[(y % LADO) * LADO + (x % LADO)] = valor
			x = (x + 1) % LADO
		y = (y + 1) % LADO
	queue_redraw()


## CableCarUtil_CopyWrapped: copia `ancho` x `alto` entradas de `origen` (desde el índice `desde`, fila a fila).
func copiar(origen: PackedInt32Array, izquierda: int, arriba: int, ancho: int, alto: int, desde: int = 0) -> void:
	var indice := desde
	var y := arriba & 0xFF
	for _i in alto:
		var x := izquierda & 0xFF
		for _j in ancho:
			mapa[(y % LADO) * LADO + (x % LADO)] = origen[indice]
			indice += 1
			x = (x + 1) % LADO
		y = (y + 1) % LADO
	queue_redraw()


func entrada(columna: int, fila: int) -> int:
	return mapa[(fila % LADO) * LADO + (columna % LADO)]


func poner(columna: int, fila: int, valor: int) -> void:
	mapa[(fila % LADO) * LADO + (columna % LADO)] = valor
	queue_redraw()


## Región del atlas de una entrada (Rect2() si la paleta no existe).
static func region_de(valor: int) -> Rect2:
	var tile := valor & 0x3FF
	var paleta := (valor >> 12) & 0xF
	if paleta >= PALETAS:
		return Rect2()
	# 16 tiles por fila del atlas: columna = tile % 16, fila = tile / 16.
	return Rect2((tile & 15) * TILE, (tile >> 4) * TILE + paleta * ALTO_PALETA, TILE, TILE)


func _draw() -> void:
	for fila in LADO:
		var py := posmod(fila * TILE - desplazamiento.y, LADO * TILE)
		if py >= PANTALLA.y:
			py -= LADO * TILE
		if py <= -TILE:
			continue
		for columna in LADO:
			var valor := mapa[fila * LADO + columna]
			if valor == 0:
				continue
			var px := posmod(columna * TILE - desplazamiento.x, LADO * TILE)
			if px >= PANTALLA.x:
				px -= LADO * TILE
			if px <= -TILE:
				continue
			var region := region_de(valor)
			if region.size == Vector2.ZERO:
				continue
			draw_texture_rect_region(ATLAS, Rect2(px, py, TILE, TILE), region)
