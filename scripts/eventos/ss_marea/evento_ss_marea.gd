## evento_ss_marea.gd
## Guiones del interior del S.S. MAREA (pokeruby data/maps/SSTidalCorridor y SSTidalRooms/scripts.inc), en los tres mapas:
## - Pasillo: anuncio al entrar (OnFrame), MARINERO de la llegada (1,11), MARINERO de las visitas (16,7) y ventanillas.
## - Camarotes: la cama (Common_EventScript_OutOfCenterPartyHeal + anuncio) y el hombre de la MT49.
## - Los pasos por cualquiera de los tres mapas cuentan para el viaje (CountSSTidalStep de field_control_avatar.c).
## El estado está en CruceroSSMarea.
extends EventoGuionizado
class_name EventoSSMarea

const MOTIVO_PAUSA: StringName = &"ss_marea"
const SONIDO_ANUNCIO: String = "SE_DING_DONG"
const TEMA_CURACION: String = "POKEMON_RECUPERADOS"

const TEXTO_HORIZONTE: String = "SS_MAREA_HORIZONTE"
const TEXTO_CAMA: String = "SS_MAREA_CAMA"
const TEXTO_ESPERA: String = "SS_MAREA_MARINERO_ESPERA"
const TEXTO_LLEGADA: String = "SS_MAREA_MARINERO_LLEGADA"
const TEXTO_VISITAS: String = "SS_MAREA_MARINERO_VISITAS"
const TEXTO_CRUCERO: String = "SS_MAREA_MARINERO_CRUCERO"
const TEXTO_REGALO: String = "SS_MAREA_HOMBRE_REGALO"
const TEXTO_ROBO: String = "SS_MAREA_HOMBRE_ROBO"
const TEXTO_MOCHILA_LLENA: String = "MOCHILA_LLENA_REGALO"
const OBJETO_MT49: String = "MT49"
## FLAG_RECEIVED_TM49, FLAG_HIDE_TM_49_GIVER_SS_TIDAL.
const BANDERA_MT49: String = "ss_marea_mt49_recibida"
const BANDERA_OCULTAR_MT49: String = "ss_marea_mt49_oculto"
## FLAG_DEFEATED_SS_TIDAL_TRAINERS y npc_id de los entrenadores del barco.
const BANDERA_ENTRENADORES: String = "ss_marea_entrenadores_vencidos"
const ENTRENADORES: Array[String] = [
	"ss_marea_felipe", "ss_marea_leonardo", "ss_marea_cornelio", "ss_marea_tito", "ss_marea_tomas",
	"ss_marea_liz_joel", "ss_marea_gabriel", "ss_marea_anita",
]

@export var carteles: NodePath
@export var marinero_llegada: NodePath
@export var marinero_visitas: NodePath
@export var hombre_mt49: NodePath

## Sustituye al AdministradorMapa de la raíz del árbol (tests).
var administrador: Node = null


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var nodo_carteles := get_node_or_null(carteles)
	if nodo_carteles != null:
		for cartel in nodo_carteles.get_children():
			if cartel is CartelEvento:
				if str(cartel.name).begins_with("Ventanilla"):
					cartel.accionado.connect(_on_ventanilla)
				elif str(cartel.name).begins_with("Cama"):
					cartel.accionado.connect(_on_cama)
	_conectar_npc(marinero_llegada, _on_marinero_llegada)
	_conectar_npc(marinero_visitas, _on_marinero_visitas)
	_conectar_npc(hombre_mt49, _on_hombre_mt49)
	var mapa := obtener_mapa()
	if mapa != null:
		mapa.mapa_activado.connect(_on_mapa_activado)
	_conectar_pasos.call_deferred()


func _conectar_npc(ruta: NodePath, metodo: Callable) -> void:
	var nodo := get_node_or_null(ruta)
	if nodo != null and nodo.has_signal(&"hablado"):
		nodo.connect(&"hablado", metodo)


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


func _conectar_pasos() -> void:
	var admin_actual := _administrador()
	var jugador: Node = admin_actual.get("jugador") if admin_actual != null else null
	if jugador != null and jugador.has_signal(&"paso_iniciado") and not jugador.is_connected(&"paso_iniciado", _on_paso_jugador):
		jugador.connect(&"paso_iniciado", _on_paso_jugador)


func _exit_tree() -> void:
	var admin_actual: Node = _administrador() if is_inside_tree() else null
	var jugador: Node = admin_actual.get("jugador") if admin_actual != null else null
	if jugador != null and jugador.has_signal(&"paso_iniciado") and jugador.is_connected(&"paso_iniciado", _on_paso_jugador):
		jugador.disconnect(&"paso_iniciado", _on_paso_jugador)


func _on_mapa_activado(_por_warp: bool) -> void:
	_conectar_pasos()
	if get_node_or_null(marinero_llegada) == null:
		return  # el OnFrame del anuncio es solo del pasillo
	await esperar_fin_warp(_administrador())
	await guion_al_entrar()


## SSTidalCorridor_MapScript2_15FC9A.
func guion_al_entrar() -> void:
	if not is_inside_tree() or not comenzar(_administrador()):
		return
	var aviso := CruceroSSMarea.aviso_al_entrar()
	if not aviso.is_empty():
		await _anunciar(aviso)
	terminar()


func _anunciar(clave: String) -> void:
	Singleton.play_sound.emit(SONIDO_ANUNCIO)
	await mensaje(clave)


## CountSSTidalStep + gUnknown_0815FD0D: el aviso sale al terminar el paso. Si algo ocupa al jugador (un combate), el
## siguiente paso vuelve a intentarlo.
func _on_paso_jugador(_origen: Vector2i, _destino: Vector2i) -> void:
	if not CruceroSSMarea.contar_paso():
		return
	var admin_actual := _administrador()
	var jugador: Node = admin_actual.get("jugador")
	while is_instance_valid(jugador) and jugador.get("paso_en_curso") == true:
		await get_tree().process_frame
	if not is_inside_tree() or not comenzar(admin_actual):
		return
	var aviso := CruceroSSMarea.aviso_por_pasos()
	if not aviso.is_empty():
		await _anunciar(aviso)
	terminar()


func _comenzar_con(npc: Node2D) -> bool:
	if not comenzar(npc.nodo_administrador):
		if npc.jugador and npc.jugador.has_method("esperar_dialogo"):
			npc.jugador.esperar_dialogo(false)
		return false
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	return true


## SSTidalCorridor_EventScript_15FDD6.
func _on_marinero_llegada(npc: Node2D) -> void:
	if _en_curso or not _comenzar_con(npc):
		return
	npc.mirar_jugador()
	var estado := CruceroSSMarea.estado()
	if estado != CruceroSSMarea.LLEGADA_CALAGUA and estado != CruceroSSMarea.LLEGADA_PORTUAL:
		await mensaje(TEXTO_ESPERA)
		terminar(false, [npc])
		return
	var a_calagua := estado == CruceroSSMarea.LLEGADA_CALAGUA
	SistemaGuardado.set_punto_curacion(CruceroSSMarea.CURACION_CALAGUA if a_calagua else CruceroSSMarea.CURACION_PORTUAL)  # setrespawn
	await mensaje(TEXTO_LLEGADA)
	if SistemaGuardado.get_flag(BANDERA_MT49):
		SistemaGuardado.set_flag(BANDERA_OCULTAR_MT49, true)
	var jugador: Node = admin.jugador
	var admin_actual: Node = admin
	terminar(true, [npc])
	jugador.no_control = true
	admin_actual.conectar_escalera(CruceroSSMarea.PUERTO_CALAGUA if a_calagua else CruceroSSMarea.PUERTO_PORTUAL,
			Vector2(CruceroSSMarea.CELDA_PUERTO), Vector2.DOWN)


## SSTidalCorridor_EventScript_15FE60.
func _on_marinero_visitas(npc: Node2D) -> void:
	if _en_curso or not _comenzar_con(npc):
		return
	npc.mirar_jugador()
	if not SistemaGuardado.get_flag(BANDERA_ENTRENADORES) and ENTRENADORES.all(SistemaGuardado.get_flag):
		SistemaGuardado.set_flag(BANDERA_ENTRENADORES, true)
	await mensaje(TEXTO_CRUCERO if SistemaGuardado.get_flag(BANDERA_ENTRENADORES) else TEXTO_VISITAS)
	terminar(false, [npc])


## SSTidalCorridor_EventScript_15FE3A.
func _on_ventanilla(_cartel: Node) -> void:
	if _en_curso or not comenzar(_administrador()):
		return
	if not CruceroSSMarea.ventanilla_disponible():
		await mensaje(TEXTO_HORIZONTE)
		terminar()
		return
	var jugador: Node = admin.jugador
	var admin_actual: Node = admin
	var celda: Vector2i = jugador.pos_celda_act
	terminar(true)
	jugador.no_control = true
	var ventanilla := VentanillaSSMarea.new()
	admin_actual.add_child(ventanilla)
	ventanilla.abrir(admin_actual, celda)


## SSTidalRooms_EventScript_15FF47.
func _on_cama(_cartel: Node) -> void:
	if _en_curso or not comenzar(_administrador()):
		return
	await mensaje(TEXTO_CAMA)
	await oscurecer_pantalla()
	await fanfarria(TEMA_CURACION, true)
	SistemaGuardado.curar_equipo_completo()
	await aclarar_pantalla()
	var aviso := CruceroSSMarea.aviso_tras_cama()
	if not aviso.is_empty():
		await _anunciar(aviso)
	terminar()


## SSTidalRooms_EventScript_15FF06.
func _on_hombre_mt49(npc: Node2D) -> void:
	if _en_curso or not _comenzar_con(npc):
		return
	npc.mirar_jugador()
	if SistemaGuardado.get_flag(BANDERA_MT49):
		await mensaje(TEXTO_ROBO)
		terminar(false, [npc])
		return
	await mensaje(TEXTO_REGALO, false)
	if await dar_objeto(npc, OBJETO_MT49):
		SistemaGuardado.set_flag(BANDERA_MT49, true)
		await mensaje(TEXTO_ROBO)
	else:
		await mensaje(TEXTO_MOCHILA_LLENA)  # Common_EventScript_ShowBagIsFull
	terminar(false, [npc])
