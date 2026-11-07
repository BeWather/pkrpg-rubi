## evento_monte_pirico.gd
## Guiones de la CIMA del MONTE PÍRICO (pokeruby data/maps/MtPyre_Summit/scripts.inc y
## data/scripts/magma_summit.inc, versión Rubí: el EQUIPO MAGMA y MAGNO). Las celdas de la
## escena son las de Rubí.
##
## Robo del ORBE (coord_events (22,7), (23,7) y (24,7) con VAR_MT_PYRE_STATE == 0): el jugador
## mira al norte, MAGNO (objeto 2, que está en (23,6)) se vuelve hacia él, se aparta si el jugador
## está a un lado, anuncia que se lleva el ORBE AZUL, fundido a negro (desaparecen MAGNO y los tres
## soldados), se activa el estado del robo (CIUDAD PORTUAL), la ancianita (objeto 3) baja hasta el
## jugador, lamenta el robo y le da la ESFERA ROJA.
##
## Devolución (los mismos coord_events con VAR_MT_PYRE_STATE == 2, tras vencer a GROUDON): MAGNO
## reaparece en la cima, dice que ha venido a devolver la ESFERA AZUL y se marcha; estado 3.
##
## Ancianita (objeto 3, MtPyre_Summit_EventScript_15D623): su texto depende de si ya devolviste
## la ESFERA, de si ya venciste a GROUDON y de si GROUDON se despertó; con GROUDON vencido te
## pregunta si devuelves la ESFERA ROJA (insiste hasta que digas que sí).
extends EventoGuionizado
class_name EventoMontePirico

const MOTIVO_PAUSA: StringName = &"monte_pirico"

const TEXTO_MAGNO_ROBO: String = "MONTE_PIRICO_CIMA_MAGNO_ROBO"
const TEXTO_MAGNO_DEVUELVE: String = "MONTE_PIRICO_CIMA_MAGNO_DEVUELVE"
const TEXTO_ABUELA_ROBO: String = "MONTE_PIRICO_CIMA_ABUELA_ROBO"
const TEXTO_ABUELA_DEFECTO: String = "MONTE_PIRICO_CIMA_ABUELA_DEFECTO"
const TEXTO_ABUELA_GROUDON: String = "MONTE_PIRICO_CIMA_ABUELA_GROUDON"
const TEXTO_ABUELA_PREGUNTA: String = "MONTE_PIRICO_CIMA_ABUELA_PREGUNTA"
const TEXTO_ABUELA_INSISTE: String = "MONTE_PIRICO_CIMA_ABUELA_INSISTE"
const TEXTO_ABUELA_GRACIAS: String = "MONTE_PIRICO_CIMA_ABUELA_GRACIAS"
const TEXTO_ABUELA_ESPIRITU: String = "MONTE_PIRICO_CIMA_ABUELA_ESPIRITU"
const TEXTO_ENTREGA: String = "MONTE_PIRICO_CIMA_ENTREGA"

## Una por celda de disparo: id del DisparadorEventoPorTiles → columna (0 = (22,7), 1 = (23,7), 2 = (24,7)).
const COLUMNAS := {&"cima_izquierda": 0, &"cima_centro": 1, &"cima_derecha": 2}

const L := Vector2.LEFT
const R := Vector2.RIGHT
const U := Vector2.UP
const D := Vector2.DOWN

## Delay 50 tras girarse, delay 20 tras el fundido, delays 40 y 10 al recibir la ESFERA.
const FOTOGRAMAS_TRAS_GIRO: int = 50
const FOTOGRAMAS_TRAS_FUNDIDO: int = 20
const FOTOGRAMAS_ABUELA_ARRIBA: int = 40
const FOTOGRAMAS_ABUELA_MIRA: int = 10

## MtPyre_Summit_Movement_15D7A7 / _15D7B0 / _15D7B9 (MAGNO se marcha): un paso al lado y siete al sur.
const SALIDA_MAGNO := [
	[R, D, D, D, D, D, D, D],
	[R, D, D, D, D, D, D, D],
	[L, D, D, D, D, D, D, D],
]

@export var magno: NodePath = ^"../../NPCs/Magno"
@export var abuela: NodePath = ^"../../NPCs/Abuela"
## Contenedor de los NPC (para refrescar su visibilidad tras cambiar las banderas HIDE).
@export var npcs: NodePath = ^"../../NPCs"

## Sustituye al AdministradorMapa de la raíz del árbol (tests).
var administrador: Node = null


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	for hijo in get_children():
		if hijo is DisparadorEventoPorTiles:
			hijo.evento_activado.connect(_on_disparador)
	var vieja := _npc(abuela)
	if vieja != null and vieja.has_signal("hablado"):
		vieja.hablado.connect(_on_abuela)


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


func _npc(ruta: NodePath) -> Node2D:
	return get_node_or_null(ruta) as Node2D


## Vuelve a evaluar bandera_ocultar / bandera_mostrar de todos los NPC del mapa (removeobject masivo).
func refrescar_npcs() -> void:
	var contenedor := get_node_or_null(npcs)
	if contenedor == null:
		return
	for hijo in contenedor.get_children():
		if hijo.has_method("aplicar_bandera_ocultar"):
			hijo.aplicar_bandera_ocultar()


## lock + faceplayer: false si ya hay un guion en curso o no hay administrador (el jugador queda libre).
func _empezar(npc: Node2D) -> bool:
	var administrador_npc: Node = npc.nodo_administrador if npc.nodo_administrador != null else _administrador()
	if _en_curso or not comenzar(administrador_npc):
		if not _en_curso and npc.jugador and npc.jugador.has_method("esperar_dialogo"):
			npc.jugador.esperar_dialogo(false)
		return false
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	npc.mirar_jugador()  # faceplayer
	return true


## ============================================================================
## COORD_EVENTS (22,7), (23,7), (24,7)
## ============================================================================

func _on_disparador(id: StringName) -> void:
	if not COLUMNAS.has(id) or _en_curso:
		return
	match HistoriaMontePirico.estado():
		0:
			if not SistemaGuardado.get_flag(HistoriaMontePirico.BANDERA_JEFE_OCULTO):
				await escena_robo(int(COLUMNAS[id]))
		2:
			if not SistemaGuardado.get_flag(HistoriaMontePirico.BANDERA_JEFE_OCULTO):
				await escena_devolucion(int(COLUMNAS[id]))


## MtPyre_Summit_EventScript_15D4E1 (`columna` es VAR_0x8008).
func escena_robo(columna: int) -> void:
	if not comenzar(_administrador()):
		return
	var jefe := _npc(magno)
	var vieja := _npc(abuela)
	girar_jugador(U)  # walk_in_place_fastest_up
	if jefe != null:
		mirar(jefe, D)  # walk_in_place_fastest_down
	await esperar_fotogramas(FOTOGRAMAS_TRAS_GIRO)
	await _apartar_jefe(jefe, columna)
	await mensaje(TEXTO_MAGNO_ROBO)  # msgbox + closemessage
	await oscurecer_pantalla()
	# removeobject 2, 4, 5 y 6 + setflag FLAG_HIDE_LEADER / FLAG_HIDE_GRUNTS_MT_PYRE_SUMMIT.
	SistemaGuardado.set_flag(HistoriaMontePirico.BANDERA_JEFE_OCULTO, true)
	SistemaGuardado.set_flag(HistoriaMontePirico.BANDERA_SOLDADOS_OCULTOS, true)
	refrescar_npcs()
	await aclarar_pantalla()
	await esperar_fotogramas(FOTOGRAMAS_TRAS_FUNDIDO)
	HistoriaMontePirico.marcar_orbe_robado()  # MtPyre_Summit_EventScript_15D57A
	await _acercar_abuela(vieja, columna)
	await mensaje(TEXTO_ABUELA_ROBO, false)
	if vieja != null and await dar_objeto(vieja, HistoriaMontePirico.OBJETO_ESFERA):  # giveitem
		SistemaGuardado.set_flag(HistoriaMontePirico.BANDERA_ESFERA_RECIBIDA, true)
	terminar(false, [vieja] if vieja != null else [])


## MAGNO se aparta del jugador si este llegó por un lado (walk_left/right + walk_in_place_fastest_down).
func _apartar_jefe(jefe: Node2D, columna: int) -> void:
	if jefe == null or columna == 1:
		return
	await caminar(jefe, L if columna == 0 else R)
	mirar(jefe, D)


## MtPyre_Summit_EventScript_15D5AA / _15D5BF / _15D5CA: la ancianita baja hasta el jugador.
func _acercar_abuela(vieja: Node2D, columna: int) -> void:
	if vieja == null:
		return
	match columna:
		0:
			await recorrer(vieja, [D, D])
			mirar(vieja, L)
			girar_jugador(R)  # walk_in_place_fastest_right
		1:
			await caminar(vieja, D)
		2:
			await recorrer(vieja, [D, D])
			mirar(vieja, R)
			girar_jugador(L)  # walk_in_place_fastest_left


## MtPyre_Summit_EventScript_15D6F2: MAGNO vuelve, devuelve el ORBE AZUL y se marcha.
func escena_devolucion(columna: int) -> void:
	if not comenzar(_administrador()):
		return
	var jefe := _npc(magno)
	girar_jugador(U)
	if jefe != null:
		mirar(jefe, D)
	await esperar_fotogramas(FOTOGRAMAS_TRAS_GIRO)
	await _apartar_jefe(jefe, columna)
	await mensaje(TEXTO_MAGNO_DEVUELVE)
	if jefe != null:
		await recorrer(jefe, SALIDA_MAGNO[columna])
		jefe.visible = false  # removeobject 2
	SistemaGuardado.set_flag(HistoriaMontePirico.BANDERA_JEFE_OCULTO, true)
	HistoriaMontePirico.fijar_estado(3)
	terminar(false, [])


## ============================================================================
## ANCIANITA (MtPyre_Summit_EventScript_15D623)
## ============================================================================

func _on_abuela(npc: Node2D) -> void:
	if not _empezar(npc):
		return
	if SistemaGuardado.get_flag(HistoriaMontePirico.BANDERA_ESFERA_DEVUELTA):
		await mensaje(TEXTO_ABUELA_ESPIRITU)
	elif SistemaGuardado.get_flag(HistoriaMontePirico.BANDERA_LEGENDARIO_COMPLETADO):
		var acepta := await preguntar_si_no(TEXTO_ABUELA_PREGUNTA)
		while not acepta:
			acepta = await preguntar_si_no(TEXTO_ABUELA_INSISTE)
		await _devolver_esfera(npc)
	elif SistemaGuardado.get_flag(HistoriaMontePirico.BANDERA_LEGENDARIO_ESCAPO):
		await mensaje(TEXTO_ABUELA_GROUDON)
	else:
		await mensaje(TEXTO_ABUELA_DEFECTO)
	terminar(false, [npc])


## Common_EventScript_PlayerHandedOverTheItem (fanfarria, «¡{PN} entregó X!» y takeitem) y el
## agradecimiento: la ancianita mira arriba 40 fotogramas, vuelve a mirarte y habla.
func _devolver_esfera(npc: Node2D) -> void:
	var datos: Dictionary = SistemaGuardado.obtener_datos_objeto_completos(HistoriaMontePirico.OBJETO_ESFERA)
	await mensaje_con_fanfarria(TEXTO_ENTREGA, Fanfarria.TEMA_MT_MO,
			{"{objeto}": str(datos.get("nombre", HistoriaMontePirico.OBJETO_ESFERA))})
	SistemaGuardado.quitar_objeto_jugador(HistoriaMontePirico.OBJETO_ESFERA, 1, int(datos.get("bolsillo_id", 0)))
	admin.cuadro_dialogo.cerrar()  # closemessage
	mirar(npc, U)  # walk_in_place_fastest_up
	await esperar_fotogramas(FOTOGRAMAS_ABUELA_ARRIBA)
	npc.mirar_jugador()  # Common_Movement_FacePlayer
	await esperar_fotogramas(FOTOGRAMAS_ABUELA_MIRA)
	await mensaje(TEXTO_ABUELA_GRACIAS)
	SistemaGuardado.set_flag(HistoriaMontePirico.BANDERA_ESFERA_DEVUELTA, true)
