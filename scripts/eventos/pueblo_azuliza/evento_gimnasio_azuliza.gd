## Guion de MARCIAL, líder del GIMNASIO de PUEBLO AZULIZA.
extends EventoGuionizado
class_name EventoGimnasioAzuliza

const MOTIVO_PAUSA: StringName = &"gimnasio_azuliza"
const ENTRENADOR_MARCIAL: int = 266
const INDICE_MEDALLA: int = 1
const OBJETO_MT08: String = "MT08"
const BANDERA_MT08: String = "azuliza_mt08_recibida"
const MUSICA_LIDER: String = "GYM_LEADER_BATTLE"
const FANFARRIA_MEDALLA: String = "OBTENIDA_MEDALLA"

const TEXTO_RETO: String = "AZULIZA_GIMNASIO_MARCIAL_RETO"
const TEXTO_MEDALLA: String = "AZULIZA_GIMNASIO_MEDALLA_RECIBIDA"
const TEXTO_MEDALLA_INFO: String = "AZULIZA_GIMNASIO_MEDALLA_INFO"
const TEXTO_MT08: String = "AZULIZA_GIMNASIO_MT08"
const TEXTO_POST: String = "AZULIZA_GIMNASIO_MARCIAL_POST"
const TEXTO_MOCHILA_LLENA: String = "MOCHILA_LLENA_REGALO"

## Entrenadores del gimnasio (npc_id de las escenas): cada uno vencido ilumina la sala.
const IDS_ENTRENADORES: PackedStringArray = ["azuliza_hideki", "azuliza_tesa", "azuliza_laura"]
## sFlashLevelPixelRadii de pokeruby: radio (px) por nivel de luz. Con 0 entrenadores
## vencidos el nivel es 4 (24 px); con 3, el 1 (72 px). Con la Medalla, 0 (todo iluminado).
const RADIOS_NIVEL: PackedInt32Array = [200, 72, 56, 40, 24]
const SUFIJO_COMBATE: String = "_combate"
## playse SE_MU_PACHI antes de animateflash.
const SONIDO_LUZ: String = "SE_MU_PACHI"

@export var marcial: NodePath

var administrador: Node = null
var _nivel_luz: int = -1


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var lider := get_node_or_null(marcial)
	if lider != null and lider.has_signal("hablado"):
		lider.hablado.connect(_on_marcial)
	# setflashradius al cargar el mapa: sin animación.
	_actualizar_luz(false)
	set_process(true)


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	EfectoOscuridadCueva.limpiar_radio_guion()


## DewfordTown_Gym_EventScript_1530BE: tras vencer a un entrenador (o a MARCIAL) el
## círculo de visión crece con animación.
func _process(_delta: float) -> void:
	if _nivel_luz != calcular_nivel_luz():
		_actualizar_luz(true)
	elif EfectoOscuridadCueva.radio_guion != RADIOS_NIVEL[_nivel_luz]:
		# Otro mapa limpió el valor al descargarse (recarga del mismo mapa).
		_actualizar_luz(false)


## Nivel de luz: 0 con la Medalla; si no, 4 menos los entrenadores vencidos.
func calcular_nivel_luz() -> int:
	if SistemaGuardado.tiene_medalla(INDICE_MEDALLA):
		return 0
	var vencidos := 0
	for id_entrenador: String in IDS_ENTRENADORES:
		if SistemaGuardado.get_flag(id_entrenador + SUFIJO_COMBATE):
			vencidos += 1
	return RADIOS_NIVEL.size() - 1 - vencidos


func _actualizar_luz(animar: bool) -> void:
	_nivel_luz = calcular_nivel_luz()
	if animar:
		Singleton.play_sound.emit(SONIDO_LUZ)
	EfectoOscuridadCueva.fijar_radio_guion(RADIOS_NIVEL[_nivel_luz], animar)


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


func _on_marcial(marcial_npc: Node2D) -> void:
	var administrador_npc: Node = marcial_npc.nodo_administrador if marcial_npc.nodo_administrador != null else _administrador()
	if _en_curso or not comenzar(administrador_npc):
		if not _en_curso and marcial_npc.jugador and marcial_npc.jugador.has_method("esperar_dialogo"):
			marcial_npc.jugador.esperar_dialogo(false)
		return
	marcial_npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	marcial_npc.mirar_jugador()
	if SistemaGuardado.tiene_medalla(INDICE_MEDALLA):
		await _tras_combate(marcial_npc)
		return
	await mensaje(TEXTO_RETO)
	var resultado := await combatir(ENTRENADOR_MARCIAL, MUSICA_LIDER)
	if resultado != &"victoria":
		terminar(resultado == &"derrota_transferida", [marcial_npc])
		return
	await mensaje_con_fanfarria(TEXTO_MEDALLA, FANFARRIA_MEDALLA)
	await mensaje(TEXTO_MEDALLA_INFO, false)
	EventoGimnasioPetalia.dar_medalla(INDICE_MEDALLA)
	await _dar_mt08(marcial_npc)


func _tras_combate(marcial_npc: Node2D) -> void:
	if not SistemaGuardado.get_flag(BANDERA_MT08):
		await _dar_mt08(marcial_npc)
		return
	await mensaje(TEXTO_POST)
	terminar(false, [marcial_npc])


func _dar_mt08(marcial_npc: Node2D) -> void:
	if not await dar_objeto(marcial_npc, OBJETO_MT08):
		await mensaje(TEXTO_MOCHILA_LLENA)
		terminar(false, [marcial_npc])
		return
	SistemaGuardado.set_flag(BANDERA_MT08, true)
	await mensaje(TEXTO_MT08)
	terminar(false, [marcial_npc])
