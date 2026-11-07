## rival.gd
## Datos del rival de Rubí, consultados desde cualquier mapa. No es un nodo ni
## guarda estado: lo que persiste está en SistemaGuardado (sexo del jugador,
## inicial elegido y la bandera de cada encuentro).
##
## - Jugador chico → AURA (MAY); jugadora → BRUNO (BRENDAN)
##   (Common_EventScript_SetupRivalGfxId).
## - Su equipo depende del inicial del jugador (VAR_STARTER_MON): el rival lleva
##   el que tiene ventaja (TREECKO → TORCHIC, TORCHIC → MUDKIP, MUDKIP → TREECKO).
class_name Rival
extends RefCounted

## encuentro -> {rival -> [ID con TREECKO, ID con TORCHIC, ID con MUDKIP]}
## (switch VAR_STARTER_MON de Route103, Route110, Route119 y LilycoveCity).
const ENCUENTROS := {
	&"ruta_103": {"AURA": [532, 535, 529], "BRUNO": [523, 526, 520]},
	&"ruta_110": {"AURA": [533, 536, 530], "BRUNO": [524, 527, 521]},
	&"ruta_119": {"AURA": [534, 537, 531], "BRUNO": [525, 528, 522]},
	&"ciudad_calagua": {"AURA": [665, 666, 664], "BRUNO": [662, 663, 661]},
}

## Música de encuentro (MUS_ENCOUNTER_MAY / MUS_ENCOUNTER_BRENDAN).
const MUSICA_ENCUENTRO := {"AURA": "TEMA_AURA", "BRUNO": "BRENDAN"}

const RUTA_SPRITES := "res://escenas/avatares/rival_%s%s.tres"
## Aura a pie usa 16×24; Bruno a pie y ambos en bici usan 32×32.
## El anclaje conserva el centro horizontal y los pies a 2 px del nodo.
static func offset_sprite(en_bici: bool = false, sexo: String = "") -> Vector2:
	var frames := sprite(en_bici, sexo)
	var tam := frames.get_frame_texture("camina_abajo_1", 0).get_size()
	return Vector2(-tam.x / 2.0, 2.0 - tam.y)


## true si el rival es AURA. `sexo` vacío = el del jugador de la partida.
static func es_aura(sexo: String = "") -> bool:
	if sexo.is_empty():
		sexo = str(SistemaGuardado.datos_vivos.jugador.get("sexo", "M"))
	return sexo == "M"


## "AURA" o "BRUNO": prefijo de los textos y clave de las tablas.
static func clave(sexo: String = "") -> String:
	return "AURA" if es_aura(sexo) else "BRUNO"


## ID de entrenador del rival en `encuentro`. `inicial` < 0 = el de la partida.
static func entrenador_id(encuentro: StringName, inicial: int = -1, sexo: String = "") -> int:
	if not ENCUENTROS.has(encuentro):
		push_error("[RIVAL] Encuentro desconocido: %s" % encuentro)
		return 0
	if inicial < 0:
		inicial = SistemaGuardado.get_inicial()
	return ENCUENTROS[encuentro][clave(sexo)][clampi(inicial, 0, 2)]


static func musica_encuentro(sexo: String = "") -> String:
	return MUSICA_ENCUENTRO[clave(sexo)]


## SpriteFrames del rival a pie o en BICI CARRERA (animaciones camina_*).
static func sprite(en_bici: bool = false, sexo: String = "") -> SpriteFrames:
	return load(RUTA_SPRITES % [clave(sexo).to_lower(), "_bici" if en_bici else ""]) as SpriteFrames
