class_name RegistroConcursos
extends RefCounted
## Lo que la partida guarda de los concursos (gSaveBlock1.contestWinners[13] de pokeruby
## y las variables de premio y cuadro pendientes):
## - `ganadores`: 8 pósters de vestíbulo (0 NORMAL, 1 ALTO, 2-4 AVANZADO y 5-7 EXPERTO,
##   el más reciente primero), sean del jugador o de un rival;
## - `museo`: 5 cuadros del MUSEO de CALAGUA por categoría ({} = sin cuadro);
## - `premio_pendiente`: objeto que la recepción guarda si la mochila estaba llena
##   (VAR_CONTEST_PRIZE_PICKUP; "" = nada);
## - `cuadro_pendiente`: el cuadro que el ARTISTA ofrece llevar al museo
##   (eCurContestWinner). En Rubí vive solo en RAM y se pierde al recargar; aquí se
##   guarda (decisión D-D del change 2026-10-27-sistema-concursos).
## Cada ganador es {personalidad, ot_id, especie, mote, entrenador, categoria, shiny};
## en el museo y en el cuadro, `categoria` es el rótulo (captionId 0..14).

const NUM_GANADORES: int = 8
const NUM_MUSEO: int = 5
const RUTA_CONFIG: String = "res://BaseDatos/config_concursos.json"
## CONTEST_WINNER_HYPER_1 - 1 y CONTEST_WINNER_MASTER_1 - 1.
const PRIMERO_AVANZADO: int = 2
const PRIMERO_EXPERTO: int = 5
const HISTORIAL: int = 3

var ganadores: Array[Dictionary] = []
var museo: Array[Dictionary] = []
var premio_pendiente: String = ""
var cuadro_pendiente: Dictionary = {}


## Registro de partida nueva: ganadores por defecto (gDefaultContestWinners) y museo vacío.
static func nuevo() -> RegistroConcursos:
	var registro := RegistroConcursos.new()
	registro.ganadores.clear()
	for g in ganadores_por_defecto():
		registro.ganadores.append(g)
	while registro.ganadores.size() < NUM_GANADORES:
		registro.ganadores.append({})
	registro.museo.clear()
	for i in NUM_MUSEO:
		registro.museo.append({})
	return registro


## `ganadores_por_defecto` de BaseDatos/config_concursos.json.
static func ganadores_por_defecto() -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	if not FileAccess.file_exists(RUTA_CONFIG):
		return lista
	var config: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUTA_CONFIG))
	if config is Dictionary and config.get("ganadores_por_defecto") is Array:
		for g in config["ganadores_por_defecto"]:
			if g is Dictionary:
				lista.append(_normalizar(g))
	return lista


## Datos de póster de un concursante.
static func ganador_desde(c: ConcursanteConcurso, categoria: int) -> Dictionary:
	return {
		"personalidad": c.personalidad,
		"ot_id": c.ot_id,
		"especie": c.especie,
		"mote": c.mote,
		"entrenador": c.entrenador,
		"categoria": categoria,
		"shiny": c.shiny,
	}


## captionId de Contest_SaveWinner: Random() % 3 + 3 × categoría.
static func rotulo_cuadro(categoria: int, aleatorio: AleatorioConcurso) -> int:
	return aleatorio.modulo(3) + 3 * categoria


## Contest_SaveWinner(nivel) + GetContestWinnerSaveIdx: póster del vestíbulo.
func registrar_ganador(nivel: int, ganador: Dictionary) -> void:
	var indice: int = nivel
	if nivel == 2 or nivel == 3:
		indice = PRIMERO_AVANZADO if nivel == 2 else PRIMERO_EXPERTO
		var k: int = indice + HISTORIAL - 1
		while k > indice:
			ganadores[k] = ganadores[k - 1].duplicate()
			k -= 1
	ganadores[indice] = ganador.duplicate()


## Ganador más reciente de un nivel (para el póster).
func ganador_de_nivel(nivel: int, antiguedad: int = 0) -> Dictionary:
	var indice: int = nivel
	if nivel == 2:
		indice = PRIMERO_AVANZADO + antiguedad
	elif nivel == 3:
		indice = PRIMERO_EXPERTO + antiguedad
	return ganadores[indice] if indice < ganadores.size() else {}


## Contest_SaveWinner(CONTEST_SAVE_FOR_MUSEUM): sustituye el cuadro de la categoría.
func guardar_en_museo(categoria: int, cuadro: Dictionary) -> void:
	museo[categoria] = cuadro.duplicate()


## CountPlayerMuseumPaintings.
func cuadros_en_museo() -> int:
	var total: int = 0
	for cuadro in museo:
		if not cuadro.is_empty():
			total += 1
	return total


func tiene_cuadro(categoria: int) -> bool:
	return not museo[categoria].is_empty()


func to_dict() -> Dictionary:
	return {
		"ganadores": ganadores.duplicate(true),
		"museo": museo.duplicate(true),
		"premio_pendiente": premio_pendiente,
		"cuadro_pendiente": cuadro_pendiente.duplicate(true),
	}


## Partidas sin bloque `concursos` (o con uno incompleto) cargan con los valores de
## partida nueva en lo que falte.
static func from_dict(d: Dictionary) -> RegistroConcursos:
	var registro := RegistroConcursos.nuevo()
	var lista: Variant = d.get("ganadores")
	if lista is Array:
		for i in mini(lista.size(), NUM_GANADORES):
			if lista[i] is Dictionary:
				registro.ganadores[i] = _normalizar(lista[i])
	lista = d.get("museo")
	if lista is Array:
		for i in mini(lista.size(), NUM_MUSEO):
			if lista[i] is Dictionary:
				registro.museo[i] = _normalizar(lista[i]) if not lista[i].is_empty() else {}
	registro.premio_pendiente = str(d.get("premio_pendiente", ""))
	var cuadro: Variant = d.get("cuadro_pendiente")
	registro.cuadro_pendiente = _normalizar(cuadro) if cuadro is Dictionary and not cuadro.is_empty() else {}
	return registro


## JSON devuelve números como float: se vuelven a enteros.
static func _normalizar(g: Dictionary) -> Dictionary:
	if g.is_empty():
		return {}
	return {
		"personalidad": int(g.get("personalidad", 0)),
		"ot_id": int(g.get("ot_id", 0)),
		"especie": str(g.get("especie", "")),
		"mote": str(g.get("mote", "")),
		"entrenador": str(g.get("entrenador", "")),
		"categoria": int(g.get("categoria", 0)),
		"shiny": bool(g.get("shiny", false)),
	}
