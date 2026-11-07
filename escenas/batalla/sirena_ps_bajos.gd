extends Node
class_name SirenaPsBajos
## Sirena de PS bajos del jugador (SE_LOW_HEALTH), como `HandleLowHpMusicChange` y
## `BattleStopLowHpSound` de battle_gfx_sfx_util.c: suena en bucle mientras algún
## Pokémon activo del jugador tenga la barra en nivel 1 y se corta cuando ninguno
## la tiene, o de forma definitiva al sonar la música de victoria o al oscurecer.
##
## Los PS se cambian desde muchos sitios del combate, así que se consultan en cada
## cuadro en vez de enganchar cada uno. Como en la ROM, el estado de un slot solo
## cambia con su barra ya en reposo: durante la animación de PS, o con el cuadro
## oculto en un cambio de Pokémon, conserva el que tenía.

const NOMBRE_SONIDO: String = "SE_LOW_HEALTH"
## Escala de la barra (GetHPBarLevel) y margen en píxeles para darla por asentada.
const ESCALA_BARRA: int = 48
const MARGEN_BARRA_ASENTADA: float = 1.0

var _b: BattleSceneController
var _reproductor: AudioStreamPlayer
var _slot_en_rojo: Array[bool] = [false, false]
var _detenida: bool = false


func _init(batalla: BattleSceneController = null) -> void:
	_b = batalla


func _ready() -> void:
	_reproductor = AudioStreamPlayer.new()
	_reproductor.stream = Singleton.se.get(NOMBRE_SONIDO)
	add_child(_reproductor)


func _process(_delta: float) -> void:
	actualizar(_leer_slots())


## GetHPBarLevel (battle_interface.c): 4 lleno, 3 verde, 2 amarillo, 1 rojo, 0 sin PS.
static func nivel_barra(ps: int, ps_max: int) -> int:
	if ps_max <= 0 or ps <= 0:
		return 0
	if ps == ps_max:
		return 4
	# GetScaledHPFraction: con PS restantes la fracción vale al menos 1.
	var fraccion: int = maxi(1, ps * ESCALA_BARRA / ps_max)
	if fraccion >= 25:
		return 3
	if fraccion >= 10:
		return 2
	return 1


## `lecturas` trae un diccionario por slot del jugador, vacío si no hay Pokémon:
## {ps, ps_max, barra (ancho visible en píxeles), visible}.
func actualizar(lecturas: Array[Dictionary]) -> void:
	if _detenida:
		return
	var alguno_en_rojo: bool = false
	for i: int in range(_slot_en_rojo.size()):
		var lectura: Dictionary = lecturas[i] if i < lecturas.size() else {}
		if lectura.is_empty():
			_slot_en_rojo[i] = false
		elif _barra_asentada(lectura):
			_slot_en_rojo[i] = nivel_barra(int(lectura.ps), int(lectura.ps_max)) == 1
		alguno_en_rojo = alguno_en_rojo or _slot_en_rojo[i]
	if alguno_en_rojo:
		if not _reproductor.playing:
			_reproductor.play()
	elif _reproductor.playing:
		_reproductor.stop()


## BattleStopLowHpSound: no vuelve a sonar en lo que queda de batalla.
func detener() -> void:
	_detenida = true
	if is_instance_valid(_reproductor):
		_reproductor.stop()


func esta_sonando() -> bool:
	return is_instance_valid(_reproductor) and _reproductor.playing


func _barra_asentada(lectura: Dictionary) -> bool:
	if not bool(lectura.visible):
		return false
	var destino: float = float(ESCALA_BARRA) * float(lectura.ps) / float(maxi(int(lectura.ps_max), 1))
	return absf(float(lectura.barra) - destino) <= MARGEN_BARRA_ASENTADA


func _leer_slots() -> Array[Dictionary]:
	var secundario: BasePokemon = null
	if _b.formato_batalla == Singleton.FormatoBatalla.DOBLE and _b.pokemones_activos_jugador.size() > 1:
		secundario = _b.pokemones_activos_jugador[1]
	return [_leer_slot(_b.slot_jugador, _b.poke_jugador), _leer_slot(_b.slot_jugador_secundario, secundario)]


func _leer_slot(slot: BattleSlot, pokemon: BasePokemon) -> Dictionary:
	if pokemon == null or not is_instance_valid(slot) or not is_instance_valid(slot.cuadro_ps):
		return {}
	return {
		"ps": pokemon.estad_ps_actual,
		"ps_max": pokemon.estad_ps,
		"barra": slot.cuadro_ps.linea_salud_1.size.x,
		"visible": slot.cuadro_ps.visible,
	}
