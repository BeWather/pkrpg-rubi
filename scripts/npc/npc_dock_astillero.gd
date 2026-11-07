@tool
## npc_dock_astillero.gd
## MUÉLLEZ (DOCK), el ingeniero de los ASTILLEROS BABOR de CIUDAD PORTUAL (pokeruby
## SlateportCity_SternsShipyard_1F_EventScript_Dock, lockall). Con `textos_condicionales`
## (SYS_GAME_CLEAR, MEDALLA_7, entrega de las PIEZAS DEVON, mercancía rechazada) gira
## hacia el jugador y dice el texto de la primera condición cumplida.
## Sin ninguna es la primera visita: primero habla solo (sin girar), luego se vuelve
## hacia el jugador, le pide que busque al CAP. BABOR, recupera su mirada y activa
## `bandera_rechazada` (FLAG_DOCK_REJECTED_DEVON_GOODS) y `bandera_soldados`
## (FLAG_HIDE_EVIL_TEAM_SLATEPORT: los soldados MAGMA se van del exterior).
## Diálogo y bloqueo del jugador: patrón de npc_dialogo_condicional.gd.
extends "res://scripts/npc/npc_dialogo_condicional.gd"

const TEXTO_NO_ENTIENDE: String = "PORTUAL_ASTILLEROS_DOCK_NOENTIENDO"
const TEXTO_ENCARGO: String = "PORTUAL_ASTILLEROS_DOCK_ENCARGO"

## FLAG_DOCK_REJECTED_DEVON_GOODS.
@export var bandera_rechazada: String = "astillero_mercancia_rechazada"
## FLAG_HIDE_EVIL_TEAM_SLATEPORT.
@export var bandera_soldados: String = "portual_soldados_ocultos"


func _procesar_interaccion() -> void:
	if not CondicionTexto.resolver(textos_condicionales, "").is_empty():
		super._procesar_interaccion()
		return
	interrupcion_pendiente = false
	if _secuencia_activa:
		return
	if nodo_administrador == null or nodo_administrador.cuadro_dialogo == null:
		if jugador and jugador.has_method("esperar_dialogo"):
			jugador.esperar_dialogo(false)
		cambiar_estado(EstadoNPC.IDLE)
		return
	_primera_visita()


func _primera_visita() -> void:
	_secuencia_activa = true
	cambiar_estado(EstadoNPC.INTERACTING)
	_bloquear_jugador(true)
	var cuadro = nodo_administrador.cuadro_dialogo
	cuadro.mostrar(tr(TEXTO_NO_ENTIENDE), true, false, _mensaje_terminado.emit)
	await _mensaje_terminado
	cuadro.cerrar()
	mirar_jugador()  # Common_Movement_FacePlayer
	cuadro.mostrar(tr(TEXTO_ENCARGO), true, false, _mensaje_terminado.emit)
	await _mensaje_terminado
	cuadro.cerrar()
	update_direction(direccion_base)  # Common_Movement_FaceOriginalDirection
	SistemaGuardado.set_flag(bandera_rechazada, true)
	SistemaGuardado.set_flag(bandera_soldados, true)
	_bloquear_jugador(false)
	_secuencia_activa = false
	cambiar_estado(EstadoNPC.IDLE)
