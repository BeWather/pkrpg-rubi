@tool
## npc_ascensor_centro_comercial.gd
## Ascensor del CENTRO COMERCIAL de CIUDAD CALAGUA (pokeruby
## `LilycoveCity_DepartmentStoreElevator`, objeto 1: TEALA en (0,5)).
##
## Guion de Rubí (`..._EventScript_Attendant`): lock + faceplayer; el mensaje con
## la pregunta («¿A qué planta vas?»); un `multichoice` con las plantas (de la
## 5ª a la 1ª); y el `setdynamicwarp` que fija el destino de la puerta del
## ascensor para que al salir el jugador aparezca en esa planta.
##
## Las seis plantas del edificio están apiladas en una sola escena (la del
## CENTRO COMERCIAL): 1F en las filas 0..7, 2F en -13..-6, 3F en -26..-19,
## 4F en -39..-32 y 5F en -52..-45. La celda del ascensor es la (2,1) de Rubí
## en cada planta.
extends "res://scripts/npc/npc_dialogo_condicional.gd"

const TEXTO_SALUDO: String = "CALAGUA_CC_ASCENSOR"

## Destino de cada planta en la escena del CENTRO COMERCIAL (la celda (2,1) de
## Rubí de esa planta). En el orden del menú de Rubí (de la 5ª a la 1ª).
const DESTINOS: Array[Vector2] = [
	Vector2(2, 1),    # PB: MOSTRADOR
	Vector2(2, -12),  # P1: ZONA de ENTRENADORES
	Vector2(2, -25),  # P2: COLECCI?N para el COMBATE
	Vector2(2, -38),  # P3: RINC?N de las MT
	Vector2(2, -51),  # P4: PLANTA de POK?MU?ECOS
]

## MultichoiceList_57 (script_menu.c): PB, P1, P2, P3, P4.
const CLAVES_PLANTA: Array[String] = [
	"CALAGUA_CC_ASCENSOR_PLANTA_1",
	"CALAGUA_CC_ASCENSOR_PLANTA_2",
	"CALAGUA_CC_ASCENSOR_PLANTA_3",
	"CALAGUA_CC_ASCENSOR_PLANTA_4",
	"CALAGUA_CC_ASCENSOR_PLANTA_5",
]

## Warps de la puerta del ascensor (los que se redirsigen a la planta elegida).
@export var warps_puerta: Array[NodePath] = []

## Sustituye al multichoice (tests): devuelve el índice de la planta elegida.
var elegir_planta: Callable = Callable()
var planta_actual: int = 0  # Índice del menú: PB por defecto.
var viaje_activo: bool = false


func iniciar_en_planta(planta: int) -> void:
	planta_actual = clampi(planta, 0, DESTINOS.size() - 1)
	_fijar_destino(planta_actual)


func exportar_estado_guardado() -> Dictionary:
	var datos := super.exportar_estado_guardado()
	datos["planta_ascensor"] = planta_actual
	return datos


func restaurar_estado_guardado(datos: Dictionary) -> void:
	super.restaurar_estado_guardado(datos)
	iniciar_en_planta(int(datos.get("planta_ascensor", 0)))


func _procesar_interaccion() -> void:
	interrupcion_pendiente = false
	if _secuencia_activa:
		return
	if nodo_administrador == null or nodo_administrador.cuadro_dialogo == null:
		if jugador and jugador.has_method("esperar_dialogo"):
			jugador.esperar_dialogo(false)
		cambiar_estado(EstadoNPC.IDLE)
		return
	_conversar()


func _conversar() -> void:
	_secuencia_activa = true
	cambiar_estado(EstadoNPC.INTERACTING)
	mirar_jugador()  # faceplayer
	_bloquear_jugador(true)
	var planta := await _elegir_planta_del_jugador()
	if planta >= 0 and planta < DESTINOS.size():
		_fijar_destino(planta)
		if planta != planta_actual:
			nodo_administrador.cuadro_dialogo.cerrar()
			await _viajar()
			planta_actual = planta
	nodo_administrador.cuadro_dialogo.cerrar()
	_bloquear_jugador(false)
	_volver_a_direccion_base()
	_secuencia_activa = false
	cambiar_estado(EstadoNPC.IDLE)


## Menú de plantas. Devuelve el índice elegido o -1 si el jugador sale.
func _elegir_planta_del_jugador() -> int:
	if elegir_planta.is_valid():
		return int(elegir_planta.call())
	var opciones := PackedStringArray()
	for clave in CLAVES_PLANTA:
		opciones.append(tr(clave))
	# Aquí B cancela (case 127 de Ruby); no elige la última planta.
	var dialogo = nodo_administrador.cuadro_dialogo
	dialogo.cerrar()
	if dialogo.get("menu_confirmacion") != null:
		dialogo.menu_confirmacion.respuesta_cancelar = "-1"
	dialogo.preguntaSiNo(tr(TEXTO_SALUDO), opciones)
	while true:
		var datos: Array = await dialogo.comando_ejecutado
		if datos.size() < 2 or str(datos[0]) != "respuesta_confirmacion":
			continue
		var parametros: Array = datos[1]
		var respuesta := str(parametros[0]) if not parametros.is_empty() else "N"
		if dialogo.get("menu_confirmacion") != null:
			dialogo.menu_confirmacion.respuesta_cancelar = ""
		return int(respuesta) if respuesta.is_valid_int() else -1
	return -1


## ShakeScreenInElevator: ±1 px cada 3 ticks, 23 cambios (69 ticks).
## sub_810ED60: alternar las luces cada 8 ticks, ocho veces.
func _viajar() -> void:
	viaje_activo = true
	update_direction(Vector2.DOWN)
	var luces := get_node("../../Suelo2") as TileMapLayer
	var camara := get_viewport().get_camera_2d()
	var offset_base := camara.offset if camara != null else Vector2.ZERO
	Singleton.play_sound.emit("SE_ELEVATOR")
	for tick in range(1, 70):
		if tick % 8 == 0 and tick <= 64:
			luces.visible = not luces.visible
		if camara != null and tick % 3 == 0:
			camara.offset = offset_base + Vector2(0, -1 if (tick / 3) % 2 == 1 else 1)
		await get_tree().create_timer(1.0 / 60.0).timeout
	luces.visible = false
	if camara != null:
		camara.offset = offset_base
	Singleton.play_sound.emit("SE_DING_DONG")
	viaje_activo = false


## `setdynamicwarp`: la puerta del ascensor pasa a llevar a la planta elegida.
func _fijar_destino(planta: int) -> void:
	if planta < 0 or planta >= DESTINOS.size():
		return
	var destino := DESTINOS[planta]
	for ruta in warps_puerta:
		var warp := get_node_or_null(ruta)
		if warp == null:
			continue
		warp.ruta_mapa_destino = "ciudad_calagua_centro_comercial"
		warp.posicion_destino = destino
