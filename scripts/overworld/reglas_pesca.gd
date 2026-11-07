class_name ReglasPesca
extends RefCounted

## Reglas del minijuego de pesca (pokeruby src/field_player_avatar.c,
## Task_Fishing: Fishing1..Fishing16). Funciones puras: el jugador
## (character.gd) lleva el flujo, las animaciones y los textos.
##
## Una ronda: aparecen puntos «·» en la caja de texto cada 20 frames. Pulsar A
## antes de tiempo falla ("No pican..." en la primera ronda, "Se ha escapado..."
## en las demás). Al completarse los puntos de la primera ronda se decide si
## pica (50 %, y solo si el mapa tiene tabla de pesca); en las siguientes pica
## siempre. Tras "¡Oh! ¡Han picado!" hay que pulsar A antes del plazo de la
## caña; después se juega otra ronda o el POKéMON queda enganchado.

## Índices de caña (tFishingRod): OLD_ROD, GOOD_ROD, SUPER_ROD.
const CANA_VIEJA: int = 0
const CANA_BUENA: int = 1
const SUPERCANA: int = 2

## nombre_interno del objeto (tabla Objetos) → índice de caña.
const INDICE_POR_OBJETO: Dictionary = {
	"CANAVIEJA": CANA_VIEJA,
	"CANABUENA": CANA_BUENA,
	"SUPERCANA": SUPERCANA,
}

## Clave `rod` de DatabaseManager.seleccionar_pokemon_salvaje por índice.
const CLAVES_TABLA: Array[String] = ["vieja", "buena", "super"]

## Fishing3: espera de un segundo antes de la primera ronda.
const FRAMES_ESPERA_LANZAR: int = 60
## Fishing5: frames entre punto y punto.
const FRAMES_POR_PUNTO: int = 20
## Fishing5: tope de puntos de una ronda.
const MAX_PUNTOS: int = 10
## Fishing8 (reelTimeouts): frames para tirar tras "¡Oh! ¡Han picado!".
const PLAZO_TIRAR: Array[int] = [36, 33, 30]
## Fishing2 (arr1 + Random() % arr2): rondas mínimas por caña.
const RONDAS_MINIMAS_BASE: Array[int] = [1, 1, 1]
const RONDAS_MINIMAS_AZAR: Array[int] = [1, 3, 6]
## Fishing9: probabilidad (%) de otra ronda según caña y rondas jugadas (< 2).
const PROBABILIDAD_OTRA_RONDA: Array = [[0, 0], [40, 10], [70, 30]]

const PUNTO: String = "·"


## Índice de caña del objeto; las desconocidas pescan como la CAÑA VIEJA.
static func indice_cana(nombre_interno: String) -> int:
	return int(INDICE_POR_OBJETO.get(nombre_interno.to_upper(), CANA_VIEJA))


static func clave_tabla(indice: int) -> String:
	return CLAVES_TABLA[clampi(indice, CANA_VIEJA, SUPERCANA)]


## Fishing2: tMinRoundsRequired.
static func rondas_minimas(indice: int, azar: int) -> int:
	var i: int = clampi(indice, CANA_VIEJA, SUPERCANA)
	return RONDAS_MINIMAS_BASE[i] + azar % RONDAS_MINIMAS_AZAR[i]


## Fishing4: puntos que hay que esperar en la ronda (`azar` = Random()).
## La primera ronda espera 3 puntos más.
static func puntos_requeridos(rondas_jugadas: int, azar: int) -> int:
	var puntos: int = azar % 10 + (4 if rondas_jugadas == 0 else 1)
	return mini(puntos, MAX_PUNTOS)


static func plazo_tirar(indice: int) -> int:
	return PLAZO_TIRAR[clampi(indice, CANA_VIEJA, SUPERCANA)]


## Fishing9: true si hay que jugar otra ronda tras tirar a tiempo.
## `azar` = Random() (se usa % 100).
static func otra_ronda(indice: int, rondas_jugadas: int, minimas: int, azar: int) -> bool:
	if rondas_jugadas < minimas:
		return true
	if rondas_jugadas < 2:
		var tabla: Array = PROBABILIDAD_OTRA_RONDA[clampi(indice, CANA_VIEJA, SUPERCANA)]
		return int(tabla[rondas_jugadas]) > azar % 100
	return false


## Fishing6: en la primera ronda pica si el mapa tiene tabla de pesca y
## Random() & 1 es 0. En las demás rondas pica siempre.
static func pica(rondas_jugadas: int, mapa_tiene_pesca: bool, azar: int) -> bool:
	if rondas_jugadas > 0:
		return true
	return mapa_tiene_pesca and azar & 1 == 0


## Texto de los puntos de la ronda.
static func texto_puntos(cantidad: int) -> String:
	return PUNTO.repeat(maxi(cantidad, 0))
