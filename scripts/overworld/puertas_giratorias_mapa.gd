class_name PuertasGiratoriasMapa
extends Node2D

## Contenedor de las puertas giratorias (PuertaGiratoria) de un mapa: el
## CheckForRotatingGatePuzzleCollision de pokeruby. Hijo directo del mapa;
## character.gd lo consulta al decidir un paso (`bloquea_paso`) y al empezarlo
## (`procesar_paso`, que es lo que hace girar las puertas).
##
## Como en Rubí, solo la PRIMERA puerta cuyo brazo toca el paso cuenta: si gira,
## el paso sigue; si no puede girar, el paso se bloquea.

const GRUPO := &"puertas_giratorias"
const GRUPO_VOLATIL := &"estado_mapa_volatil"
## Un paso más corto que esto no es el andar normal del jugador (GetPlayerSpeed()
## != 1 en Rubí): la puerta gira en 8 fotogramas en vez de 16.
const DURACION_PASO_RAPIDO_MAX: float = 0.2


func _enter_tree() -> void:
	add_to_group(GRUPO)
	add_to_group(GRUPO_VOLATIL)


func puertas() -> Array[PuertaGiratoria]:
	var lista: Array[PuertaGiratoria] = []
	for hijo in get_children():
		if hijo is PuertaGiratoria:
			lista.append(hijo)
	return lista


## Primera puerta cuyo brazo toca el paso hacia `destino` en `direccion`, o null.
## `sentido` recibe el sentido de giro en [0].
func _puerta_tocada(destino: Vector2i, direccion: Vector2i, sentido: Array) -> PuertaGiratoria:
	for puerta in puertas():
		var s := puerta.sentido_de_empuje(destino, direccion)
		if s != PuertaGiratoria.Sentido.NINGUNO:
			sentido[0] = s
			return puerta
	return null


## ¿Un brazo que no puede girar cierra el paso hacia `destino` en `direccion`?
## Sin efectos secundarios (character.can_move lo llama a menudo).
func bloquea_paso(datos: TPTileDataMap, destino: Vector2i, direccion: Vector2) -> bool:
	var sentido: Array = [PuertaGiratoria.Sentido.NINGUNO]
	var puerta := _puerta_tocada(destino, Vector2i(direccion), sentido)
	if puerta == null:
		return false
	return not puerta.puede_girar(datos, sentido[0])


## El jugador empieza un paso de `origen` a `destino`: si empuja un brazo que
## puede girar, la puerta gira. Devuelve la puerta girada o null.
func procesar_paso(datos: TPTileDataMap, origen: Vector2i, destino: Vector2i, rapido: bool = false) -> PuertaGiratoria:
	var direccion := destino - origen
	if absi(direccion.x) + absi(direccion.y) != 1:
		return null
	var sentido: Array = [PuertaGiratoria.Sentido.NINGUNO]
	var puerta := _puerta_tocada(destino, direccion, sentido)
	if puerta == null or not puerta.puede_girar(datos, sentido[0]):
		return null
	puerta.girar(sentido[0], rapido)
	return puerta


## Orientaciones actuales (para guardarlas y restaurarlas en simulaciones).
func orientaciones() -> Array[int]:
	var lista: Array[int] = []
	for puerta in puertas():
		lista.append(puerta.orientacion)
	return lista


func fijar_orientaciones(lista: Array[int]) -> void:
	var todas := puertas()
	for i in mini(todas.size(), lista.size()):
		todas[i].orientacion = lista[i]


## OnTransition de Rubí (RotatingGate_InitPuzzle): al volver al mapa, las
## puertas recuperan la orientación de fábrica.
func regenerar_estado_volatil(_desde_carga: bool = false) -> void:
	for puerta in puertas():
		puerta.restaurar()
