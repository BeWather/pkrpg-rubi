## evento_kecleon_invisible.gd
## KECLEON invisibles de las RUTAS 119 y 120 (pokeruby EventScript_Kecleon, data/scripts/static_pokemon.inc):
## sin DETECTOR DEVON solo avisan; con él preguntan y atacan (Nv. 30). Su bandera FLAG_HIDE_KECLEON_* se
## pone antes del combate: no vuelven pase lo que pase. Cada objeto lleva la suya en `bandera_ocultar`.
extends EventoGuionizado
class_name EventoKecleonInvisible

const MOTIVO_PAUSA_KECLEON: StringName = &"kecleon_invisible"

const ESPECIE_KECLEON: String = "KECLEON"
const NUMERO_KECLEON: int = EventoCiudadArborada.NUMERO_KECLEON
## setwildbattle SPECIES_KECLEON, 30, ITEM_NONE.
const NIVEL_KECLEON: int = 30
const OBJETO_DETECTOR: String = EventoCiudadArborada.OBJETO_DETECTOR
const BOLSILLO_CLAVE: int = EventoCiudadArborada.BOLSILLO_CLAVE

## delay 40 entre que aparece el KECLEON y el combate.
const FOTOGRAMAS_ANTES_DEL_COMBATE: int = 40
## Movement_KecleonAppears: cada espera entre set_visible y set_invisible.
const PARPADEO: Array[int] = [4, 4, 4, 4, 8, 8, 8, 8, 16, 16]

const TEXTO_INVISIBLE: String = "KECLEON_INVISIBLE"
const TEXTO_PREGUNTA: String = "KECLEON_PREGUNTA"
const TEXTO_ATACA: String = "KECLEON_ATACA"

## Resultado del combate contra un KECLEON.
enum Combate { SIGUE, DERROTA_TRANSFERIDA, DERROTA, RECHAZADO }

## Los objetos con EventScript_Kecleon del mapa.
@export var kecleones: Array[NodePath] = []

## Sustituye al AdministradorMapa de la raíz del árbol (tests).
var administrador: Node = null


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA_KECLEON


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	for ruta in kecleones:
		var npc := get_node_or_null(ruta)
		if npc != null and npc.has_signal("hablado"):
			npc.hablado.connect(_on_kecleon)


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


## lock + faceplayer: false si ya hay un guion en curso o no hay administrador.
func _empezar_con(npc: Node2D) -> bool:
	var administrador_npc: Node = npc.nodo_administrador if npc.nodo_administrador != null else _administrador()
	if _en_curso or not comenzar(administrador_npc):
		if not _en_curso and npc.jugador and npc.jugador.has_method("esperar_dialogo"):
			npc.jugador.esperar_dialogo(false)
		return false
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	npc.mirar_jugador()
	return true


## EventScript_Kecleon.
func _on_kecleon(npc: Node2D) -> void:
	if not _empezar_con(npc):
		return
	if not SistemaGuardado.tiene_objeto(OBJETO_DETECTOR, 1, BOLSILLO_CLAVE):
		await mensaje(TEXTO_INVISIBLE)  # Text_SomethingUnseeable
		terminar(false, [npc])
		return
	if not await preguntar_si_no(TEXTO_PREGUNTA):  # EventScript_AskUseDevonScope
		terminar(false, [npc])
		return
	# EventScript_BattleKecleon.
	await mensaje(TEXTO_ATACA)
	admin.cuadro_dialogo.cerrar()  # closemessage
	npc.tipo_movimiento = NpcBase.TipoMovimientoNPC.SIN_MOVIMIENTO
	npc.mirar_jugador()  # Common_Movement_FacePlayer
	await _aparecer(npc)
	# *_EventScript_HideKecleon*: antes de dowildbattle, para que no vuelva pase lo que pase.
	SistemaGuardado.set_flag(npc.bandera_ocultar, true)
	var resultado := await _combatir_kecleon()
	if resultado == Combate.RECHAZADO:
		SistemaGuardado.set_flag(npc.bandera_ocultar, false)
		_volver_invisible(npc)
		terminar(false, [npc])
		return
	npc.aplicar_bandera_ocultar()  # removeobject al volver al mapa (FLAG_SYS_CTRL_OBJ_DELETE)
	terminar(resultado == Combate.DERROTA_TRANSFERIDA, [npc])


## Movement_KecleonAppears + waitse + playmoncry + delay 40 + waitmoncry.
func _aparecer(npc: Node2D) -> void:
	var sprite: CanvasItem = npc.animated_sprite
	for i in PARPADEO.size():
		if sprite != null:
			sprite.visible = i % 2 == 0
		await esperar_fotogramas(PARPADEO[i])
	if sprite != null:
		sprite.visible = true
	var reproductor = grito(NUMERO_KECLEON)
	await esperar_fotogramas(FOTOGRAMAS_ANTES_DEL_COMBATE)
	await esperar_grito(reproductor)


## El objeto vuelve a estar como al cargar el mapa (combate rechazado o derrota).
func _volver_invisible(npc: Node2D) -> void:
	npc.tipo_movimiento = NpcBase.TipoMovimientoNPC.INVISIBLE
	if npc.animated_sprite:
		npc.animated_sprite.visible = false


## setwildbattle + dowildbattle.
func _combatir_kecleon() -> Combate:
	var manager: Variant = admin.get("battle_manager")
	if manager == null:
		push_warning("[%s] Sin OverworldBattleManager" % motivo_pausa)
		return Combate.RECHAZADO
	var lugar: String = str(admin.obtener_seccion_lugar_actual()) if admin.has_method("obtener_seccion_lugar_actual") else ""
	var ejecucion: ResultadoEjecucionBatalla = await manager.combatir_salvaje(ESPECIE_KECLEON, NIVEL_KECLEON, lugar)
	if ejecucion.fue_rechazada():
		push_warning("[%s] Combate rechazado: %s" % [motivo_pausa, ejecucion.codigo_error])
		return Combate.RECHAZADO
	if ResultadoBatalla.es_derrota_jugador(ejecucion.resultado):
		return Combate.DERROTA_TRANSFERIDA if manager.recuperar_derrota_estandar() else Combate.DERROTA
	return Combate.SIGUE
