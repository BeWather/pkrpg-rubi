class_name DibujoConcurso
extends RefCounted

## Dibujo de la página MOV. CONCURSO compartido por la ficha del Pokémon (pantalla_info.gd)
## y la ficha de olvidar movimiento: icono de categoría y corazones de EXHIB./INHIB.

const TEXTURA_CATEGORIAS: Texture2D = preload("res://UI/poke-info/categorias-concurso.png")
const TEXTURA_CORAZONES: Texture2D = preload("res://UI/poke-info/corazones-concurso.png")
## Corazones (sub_80A057C): fotogramas de corazones-concurso.png.
const CORAZON_ATRACTIVO_VACIO: int = 0
const CORAZON_ATRACTIVO_LLENO: int = 1
const CORAZON_INTERFERENCIA_LLENO: int = 2
const CORAZON_INTERFERENCIA_VACIO: int = 3
const MAX_CORAZONES: int = 8
const ANCHO_CORAZON: int = 8


## Icono de categoría de concurso (gContestMoves[].contestCategory + 18).
static func asignar_icono_categoria(icono: Sprite2D, mov: Movimiento) -> void:
	icono.texture = TEXTURA_CATEGORIAS
	icono.region_rect = Rect2(0, clampi(mov.get_categoria_concurso(), 0, 4) * 16, 32, 16)


## sub_80A057C: appeal/10 corazones de atractivo y jam/10 de interferencia (0xFF = ninguno).
## `sprites` tiene MAX_CORAZONES de atractivo seguidos de MAX_CORAZONES de interferencia.
static func pintar_corazones(sprites: Array[Sprite2D], atractivo: int, interferencia: int) -> void:
	var llenos_a := 0 if atractivo == 0xFF else atractivo / 10
	var llenos_i := 0 if interferencia == 0xFF else interferencia / 10
	for i in range(MAX_CORAZONES):
		var a := CORAZON_ATRACTIVO_LLENO if i < llenos_a else CORAZON_ATRACTIVO_VACIO
		var j := CORAZON_INTERFERENCIA_LLENO if i < llenos_i else CORAZON_INTERFERENCIA_VACIO
		sprites[i].region_rect = Rect2(a * ANCHO_CORAZON, 0, ANCHO_CORAZON, ANCHO_CORAZON)
		sprites[MAX_CORAZONES + i].region_rect = Rect2(j * ANCHO_CORAZON, 0, ANCHO_CORAZON, ANCHO_CORAZON)


## Número de corazones llenos de atractivo e interferencia a la vista (para pruebas).
static func contar_corazones_llenos(sprites: Array[Sprite2D]) -> Vector2i:
	var resultado := Vector2i.ZERO
	for i in range(MAX_CORAZONES):
		if int(sprites[i].region_rect.position.x) == CORAZON_ATRACTIVO_LLENO * ANCHO_CORAZON:
			resultado.x += 1
		if int(sprites[MAX_CORAZONES + i].region_rect.position.x) == CORAZON_INTERFERENCIA_LLENO * ANCHO_CORAZON:
			resultado.y += 1
	return resultado
