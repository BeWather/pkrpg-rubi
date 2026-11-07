class_name BuscaObjetos
extends RefCounted

## Cálculos del BUSCAOBJETOS (pokeruby src/item_use.c: ItemfinderCheckForHiddenItems,
## sub_80C9838, GetPlayerDirectionTowardsHiddenItem y RotatePlayerAndExitItemfinder).
## Funciones estáticas sobre distancias en celdas (objeto - jugador); la búsqueda
## de los objetos ocultos y la animación en el campo están en
## AdministradorMapa.usar_buscaobjetos().

## Alcance: 7 celdas a cada lado en horizontal y 5 en vertical (la pantalla).
const ALCANCE_X: int = 7
const ALCANCE_Y: int = 5
## SE_ITEMFINDER suena 4 veces, una cada 32 frames, antes del resultado.
const PITIDOS: int = 4
const FRAMES_ENTRE_PITIDOS: int = 32
## Giros en el sitio cuando el objeto está bajo los pies (data[3] == 4).
const GIROS_DEBAJO: int = 4

const CLAVE_REACCIONA: String = "BUSCAOBJETOS_REACCIONA"  ## gOtherText_ItemfinderResponding
const CLAVE_DEBAJO: String = "BUSCAOBJETOS_DEBAJO"        ## gOtherText_ItemfinderItemUnderfoot
const CLAVE_NADA: String = "BUSCAOBJETOS_NADA"            ## gOtherText_NoResponse

## gItemFinderDirections, en el orden en que gira el jugador (horario).
const GIRO_HORARIO: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]


static func en_alcance(distancia: Vector2i) -> bool:
	return absi(distancia.x) <= ALCANCE_X and absi(distancia.y) <= ALCANCE_Y


## Distancia al objeto que elige el BUSCAOBJETOS entre `distancias` (objeto -
## jugador), o null si ninguno está al alcance. Gana la menor distancia
## Manhattan; a igualdad, la de menor |y| y, después, la que está más al sur
## (sub_80C9838).
static func objetivo(distancias: Array[Vector2i]) -> Variant:
	var elegida: Variant = null
	for distancia: Vector2i in distancias:
		if not en_alcance(distancia):
			continue
		if elegida == null or _mejor(distancia, elegida as Vector2i):
			elegida = distancia
	return elegida


static func _mejor(nueva: Vector2i, actual: Vector2i) -> bool:
	var suma_actual: int = absi(actual.x) + absi(actual.y)
	var suma_nueva: int = absi(nueva.x) + absi(nueva.y)
	if suma_actual != suma_nueva:
		return suma_nueva < suma_actual
	if absi(actual.y) != absi(nueva.y):
		return absi(nueva.y) < absi(actual.y)
	return actual.y < nueva.y


## GetPlayerDirectionTowardsHiddenItem: hacia dónde se gira el jugador. Si la
## distancia horizontal es mayor, hacia el lado; si no (o empatan), en vertical.
## Vector2i.ZERO = el objeto está bajo los pies.
static func direccion(distancia: Vector2i) -> Vector2i:
	if distancia == Vector2i.ZERO:
		return Vector2i.ZERO
	if absi(distancia.x) > absi(distancia.y):
		return Vector2i.LEFT if distancia.x < 0 else Vector2i.RIGHT
	return Vector2i.UP if distancia.y < 0 else Vector2i.DOWN


## Las 4 direcciones de RotatePlayerAndExitItemfinder: empieza por la siguiente
## (en sentido horario) a la que mira y termina mirando donde miraba.
static func giros_debajo(mirada: Vector2i) -> Array[Vector2i]:
	var giros: Array[Vector2i] = []
	var inicio: int = maxi(GIRO_HORARIO.find(mirada), 0)
	for i in range(1, GIROS_DEBAJO + 1):
		giros.append(GIRO_HORARIO[(inicio + i) % GIRO_HORARIO.size()])
	return giros
