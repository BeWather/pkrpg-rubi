class_name PalabrasFaciles
extends RefCounted

## PALABRAS FÁCILES (easy chat de pokeruby): catálogo de grupos y palabras
## (tablas PalabrasFacilesGrupos y PalabrasFaciles de poke.db, que rellena
## herramientas/importar_palabras_faciles.py) y qué grupos y palabras puede
## usar el jugador. Sin nodos: la pantalla de selección y quienes guardan
## frases (cartas, perfil, frase de moda...) trabajan con los ids de 16 bits.
##
## Referencia pokeruby: include/constants/easy_chat.h (EC_GROUP_*, EC_WORD_*),
## src/easy_chat_1.c (CopyEasyChatWord) y src/easy_chat_2.c (sub_80EAD7C:
## grupos visibles; sub_80EADC0: palabras visibles; UnlockTrendySaying).

## EC_GROUP_*: el id de una palabra es `grupo << 9 | valor`.
const GRUPO_POKEMON: int = 0x00
const GRUPO_TRAINER: int = 0x01
const GRUPO_EVENTS: int = 0x11
const GRUPO_MOVE_1: int = 0x12
const GRUPO_MOVE_2: int = 0x13
const GRUPO_TRENDY_SAYING: int = 0x14
const GRUPO_POKEMON_2: int = 0x15
const BITS_VALOR: int = 9

## 0xFFFF: hueco vacío de una frase (EC_WORD_UNDEFINED).
const PALABRA_VACIA: int = 0xFFFF
## Texto de un hueco vacío al imprimir una frase (CopyEasyChatWord).
const TEXTO_VACIA: String = ""
## Texto de un id que no existe: el de reserva de CopyEasyChatWord en la ROM
## española ("(?)" en 0x08430029, easy_chat_runtime_validation.csv).
const TEXTO_DESCONOCIDA: String = "(?)"

## FLAG_SYS_HIPSTER_MEET (el MODERNO de Malvalona) y FLAG_SYS_GAME_CLEAR.
const BANDERA_MODERNO: String = "SYS_HIPSTER_MEET"
const BANDERA_JUEGO_COMPLETADO: String = "SYS_GAME_CLEAR"
## Cada dicho de ARGOT se desbloquea aparte (gSaveBlock1.unk2D8C, 33 bits):
## bandera "argot_<índice>".
const PREFIJO_BANDERA_ARGOT: String = "argot_"
const TOTAL_ARGOT: int = 33

static var _grupos: Array[Dictionary] = []
static var _palabras: Dictionary = {}       ## id -> fila de PalabrasFaciles
static var _por_grupo: Dictionary = {}      ## grupo_id -> Array[int] de ids en orden
static var _cargado: bool = false


static func grupo_de(id_palabra: int) -> int:
	return id_palabra >> BITS_VALOR


static func valor_de(id_palabra: int) -> int:
	return id_palabra & ((1 << BITS_VALOR) - 1)


## Los 22 grupos ({id, referencia, nombre, tipo}) en orden.
static func grupos() -> Array[Dictionary]:
	_cargar()
	return _grupos


## Nombre oficial del grupo ("ENTRENADOR", "ARGOT"...), o "" si no existe.
static func nombre_grupo(grupo: int) -> String:
	_cargar()
	for fila: Dictionary in _grupos:
		if int(fila.get("id", -1)) == grupo:
			return str(fila.get("nombre", ""))
	return ""


## Ids de las palabras de `grupo`, en el orden de la ROM.
static func palabras_de_grupo(grupo: int) -> Array[int]:
	_cargar()
	var ids: Array[int] = []
	ids.assign(_por_grupo.get(grupo, []))
	return ids


static func existe(id_palabra: int) -> bool:
	_cargar()
	return _palabras.has(id_palabra)


## Fila de la palabra (id, grupo_id, indice, texto, numero_nacional,
## numero_movimiento, especie), o {} si no existe.
static func datos(id_palabra: int) -> Dictionary:
	_cargar()
	return _palabras.get(id_palabra, {})


## CopyEasyChatWord: texto de una palabra; "" para un hueco vacío y "(?)" si
## el id no existe.
static func texto(id_palabra: int) -> String:
	if id_palabra == PALABRA_VACIA:
		return TEXTO_VACIA
	var fila: Dictionary = datos(id_palabra)
	if fila.is_empty():
		return TEXTO_DESCONOCIDA
	return str(fila.get("texto", TEXTO_DESCONOCIDA))


## Frase completa: las palabras separadas por espacios, saltando los huecos.
static func frase(ids: Array) -> String:
	var partes: PackedStringArray = []
	for id_palabra in ids:
		if int(id_palabra) != PALABRA_VACIA:
			partes.append(texto(int(id_palabra)))
	return " ".join(partes)


## sub_80EAD7C: ¿aparece el grupo en la pantalla? ARGOT, tras conocer al
## MODERNO; HOENN y los ataques, con el juego completado; POKéMON 2, con la
## POKéDEX NACIONAL.
static func grupo_desbloqueado(grupo: int) -> bool:
	match grupo:
		GRUPO_TRENDY_SAYING:
			return SistemaGuardado.get_flag(BANDERA_MODERNO)
		GRUPO_EVENTS, GRUPO_MOVE_1, GRUPO_MOVE_2:
			return SistemaGuardado.get_flag(BANDERA_JUEGO_COMPLETADO)
		GRUPO_POKEMON_2:
			return PokedexPartida.nacional_disponible()
	return existe_grupo(grupo)


static func existe_grupo(grupo: int) -> bool:
	return not nombre_grupo(grupo).is_empty()


## sub_80EADC0: ¿se puede elegir la palabra? Su grupo tiene que estar
## desbloqueado; además, en ARGOT cada dicho se desbloquea aparte y en POKéMON
## (Hoenn) sólo salen las especies vistas en la POKéDEX.
static func palabra_desbloqueada(id_palabra: int) -> bool:
	var fila: Dictionary = datos(id_palabra)
	if fila.is_empty():
		return false
	var grupo: int = grupo_de(id_palabra)
	if not grupo_desbloqueado(grupo):
		return false
	match grupo:
		GRUPO_TRENDY_SAYING:
			return argot_desbloqueado(int(fila.get("indice", -1)))
		GRUPO_POKEMON:
			var especie: Variant = fila.get("especie")
			return especie != null and SistemaGuardado.pokemon_visto(str(especie))
	return true


## Palabras de `grupo` que el jugador puede elegir ahora, en orden.
static func palabras_disponibles(grupo: int) -> Array[int]:
	var ids: Array[int] = []
	if not grupo_desbloqueado(grupo):
		return ids
	for id_palabra: int in palabras_de_grupo(grupo):
		if palabra_desbloqueada(id_palabra):
			ids.append(id_palabra)
	return ids


static func argot_desbloqueado(indice: int) -> bool:
	return indice >= 0 and indice < TOTAL_ARGOT \
		and SistemaGuardado.get_flag(PREFIJO_BANDERA_ARGOT + str(indice))


## UnlockTrendySaying: fuera de 0-32 no hace nada.
static func desbloquear_argot(indice: int) -> void:
	if indice >= 0 and indice < TOTAL_ARGOT:
		SistemaGuardado.set_flag(PREFIJO_BANDERA_ARGOT + str(indice), true)


## Vacía la caché (tests o tras reimportar la BD).
static func recargar() -> void:
	_cargado = false
	_cargar()


static func _cargar() -> void:
	if _cargado:
		return
	_grupos.clear()
	_palabras.clear()
	_por_grupo.clear()
	for fila: Dictionary in DatabaseManager.obtener_grupos_palabras_faciles():
		_grupos.append(fila)
	for fila: Dictionary in DatabaseManager.obtener_palabras_faciles():
		var id_palabra: int = int(fila.get("id", -1))
		_palabras[id_palabra] = fila
		var grupo: int = int(fila.get("grupo_id", -1))
		if not _por_grupo.has(grupo):
			_por_grupo[grupo] = []
		(_por_grupo[grupo] as Array).append(id_palabra)
	# Sin BD no se marca como cargado: se reintenta en la próxima consulta.
	_cargado = not _grupos.is_empty()
