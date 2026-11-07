## evento_devon_ferrica.gd
## Guiones de DEVON S.A. de CIUDAD FÉRRICA (pokeruby data/maps/RustboroCity_DevonCorp_1F,
## _2F y _3F). Las tres plantas están en una sola escena, apiladas con un paso de 14
## filas: Godot (x, y) = Rubí (x, y) para 1F, (x, y − 14) para 2F y (x, y − 28) para 3F.
##
## 1F: el GUARDIA de la escalera ((15,5), vaga) bloquea la subida en (14,2) mirando
##     abajo hasta FLAG_RETURNED_DEVON_GOODS (OnTransition: BlockStairs).
## 2F: cinco INVESTIGADORES. Los cuatro primeros hablan según el progreso; el quinto,
##     con el REGENERADOR de FÓSILES, revive un FÓSIL RAÍZ (LILEEP) o FÓSIL GARRA
##     (ANORITH) a nivel 20. VAR_FOSSIL_RESURRECTION_STATE pasa de 1 a 2 al entrar en
##     el mapa o al hablar con cualquiera de los otros cuatro.
## 3F: al llegar con la devolución de las PIEZAS (OnFrame con VAR_DEVON_CORP_3F_STATE 0),
##     un EMPLEADO le deja esperando, le lleva ante el SR. PEÑAS (STONE) y éste le da
##     la CARTA para MÁXIMO y el POKéNAV. Después da el REPARTIR EXP al traer la CARTA
##     entregada. El EMPLEADO (objeto 2, FLAG_HIDE_EMPLOYEE_DEVON_CORP_3F) se va a la
##     RUTA 116 con las PIEZAS entregadas y vuelve al dar la ACOPIO BALL.
extends EventoGuionizado
class_name EventoDevonFerrica

const MOTIVO_PAUSA: StringName = &"devon_ferrica"
const TipoMovimiento := NpcBase.TipoMovimientoNPC

const T := "FERRICA_DEVON_"
const TEXTO_FOSIL_INTRO: String = T + "2F_FOSIL_INTRO"
const TEXTO_FOSIL_PREGUNTA: String = T + "2F_FOSIL_PREGUNTA"
const TEXTO_FOSIL_NO: String = T + "2F_FOSIL_NO"
const TEXTO_FOSIL_ENTREGA: String = T + "2F_FOSIL_ENTREGA"
const TEXTO_FOSIL_ESPERA: String = T + "2F_FOSIL_ESPERA"
const TEXTO_FOSIL_LISTO: String = T + "2F_FOSIL_LISTO"
const TEXTO_FOSIL_RECIBIDO: String = T + "2F_FOSIL_RECIBIDO"
const TEXTO_FOSIL_MOTE: String = T + "2F_FOSIL_MOTE"
const TEXTO_FOSIL_LLENO: String = T + "2F_FOSIL_LLENO"
const TEXTO_BOLAS_DESPUES: String = T + "2F_BOLAS_DESPUES"
const TEXTO_POKENAV_DESPUES: String = T + "2F_POKENAV_DESPUES"
const TEXTO_PISO: String = T + "3F_PISO"
const TEXTO_ACOMPANAME: String = T + "3F_ACOMPANAME"
const TEXTO_ADELANTE: String = T + "3F_ADELANTE"
const TEXTO_FAVOR: String = T + "3F_FAVOR"
const TEXTO_REGALO: String = T + "3F_REGALO"
const TEXTO_POKENAV_RECIBIDO: String = T + "3F_POKENAV_RECIBIDO"
const TEXTO_POKENAV_EXPLICA: String = T + "3F_POKENAV_EXPLICA"
const TEXTO_PRESIDENTE_CUENTO: String = T + "3F_PRESIDENTE_CUENTO"
const TEXTO_PRESIDENTE_GRACIAS: String = T + "3F_PRESIDENTE_GRACIAS"
const TEXTO_PRESIDENTE_REPARTIR: String = T + "3F_PRESIDENTE_REPARTIR"
const TEXTO_PRESIDENTE_MODAS: String = T + "3F_PRESIDENTE_MODAS"
const TEXTO_MOCHILA_LLENA: String = "MOCHILA_LLENA_REGALO"
const MUSICA_SIGUEME: String = "SIGUEME"

const OBJETO_CARTA: String = "CARTAGUILLE"
const OBJETO_REPARTIR_EXP: String = "REPARTIREXP"
const FOSILES := {
	1: {"objeto": "FOSILRAIZ", "especie": "LILEEP"},
	2: {"objeto": "FOSILGARRA", "especie": "ANORITH"},
}
const NIVEL_FOSIL: int = 20
## SistemaGuardado.agregar_pokemon_al_equipo: origen FOSSIL.
const ORIGEN_FOSIL: int = 7
const MAX_EQUIPO: int = 6

## Pantalla de nombre (Common_EventScript_NameReceivedPartyMon).
const SCN_ENTRADA_NOMBRE: PackedScene = preload("res://escenas/entrada_nombre/entrada_nombre.tscn")
const TITULO_MOTE: String = "¿Mote de %s?"
const MAX_CARACTERES_MOTE: int = 10
const ENTRADA_NOMBRE_POKEMON: int = 2

## Celdas de la escena. 1F: el guardia ((15,5) en map.json) y donde bloquea.
const GUARDIA_LIBRE := Vector2i(15, 5)
const GUARDIA_BLOQUEA := Vector2i(14, 2)
## 3F ((x, y − 28)): el empleado en (3,5) o, antes de la reunión, en (3,2).
const EMPLEADO_ESPERA := Vector2i(3, -23)
const EMPLEADO_REUNION := Vector2i(3, -26)
## Plantas: la 3F empieza en y = −28 (filas −28..−20).
const PRIMERA_FILA_3F: int = -28
const ULTIMA_FILA_3F: int = -20

const L := Vector2.LEFT
const R := Vector2.RIGHT
const U := Vector2.UP
const D := Vector2.DOWN

## RustboroCity_DevonCorp_3F_Movement_*.
static var EMPLEADO_SE_VA: Array = [R, R, R, D, R, R, R, R]
static var EMPLEADO_VUELVE: Array = [L, L, L, L, U, L, L, L]
static var EMPLEADO_GUIA: Array = [R, R, R, D, R, R, R, R, R, R, R, R, R]
static var JUGADOR_SIGUE: Array = [R, R, R, R, D, R, R, R, R, R, R, R, R]
## PlayerApproachDesk (tras 2 × delay_16): baja dos y mira a la derecha.
static var JUGADOR_AL_DESPACHO: Array = [D, D]

@export var guardia_escalera: NodePath
@export var empleado_3f: NodePath
@export var presidente: NodePath
@export var presidente_mesa: NodePath
@export var cientifico_hablar: NodePath
@export var cientifico_bolas: NodePath
@export var cientifico_pokenav: NodePath
@export var cientifico_suenos: NodePath
@export var cientifico_fosil: NodePath

## Sustituye al AdministradorMapa de la raíz del árbol (tests).
var administrador: Node = null
## Sustituye a la pantalla de nombre (tests): recibe el BasePokemon y devuelve el mote.
var pedir_mote: Callable = Callable()

signal _nombre_introducido(nombre: String)


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	for ruta in [cientifico_hablar, cientifico_bolas, cientifico_pokenav, cientifico_suenos]:
		_conectar(ruta, _on_cientifico_hablado)
	_conectar(cientifico_fosil, _on_fosil_hablado)
	_conectar(presidente, _on_presidente_hablado)
	_conectar(presidente_mesa, _on_presidente_hablado)
	var mapa := obtener_mapa()
	if mapa != null:
		mapa.mapa_activado.connect(_on_mapa_activado)
	preparar()


func _conectar(ruta: NodePath, metodo: Callable) -> void:
	var npc := _npc(ruta)
	if npc != null and npc.has_signal("hablado"):
		npc.hablado.connect(metodo)


func _npc(ruta: NodePath) -> Node2D:
	return get_node_or_null(ruta) as Node2D


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


func _on_mapa_activado(_por_warp: bool) -> void:
	# RustboroCity_DevonCorp_2F_OnTransition.
	_actualizar_fosil()
	preparar()
	if en_piso_3() and not HistoriaFerrica.presidente_visto():
		reunion_con_el_presidente()  # RustboroCity_DevonCorp_3F_OnFrame


## ¿Está el jugador en la 3F? (por su celda: las tres plantas comparten escena).
## Con un warp en curso (mapa_activado llega con el telón negro y antes de
## teletransportar al jugador) cuenta la celda de destino del warp.
func en_piso_3() -> bool:
	var adm := _administrador()
	var jugador: Node = adm.get("jugador") if adm != null else null
	if jugador == null:
		return false
	var y: int = jugador.pos_celda_act.y
	if int(adm.get("coneccion")) != 0 and adm.get("coneccion_posicion") is Vector2:
		y = int(floorf((adm.get("coneccion_posicion") as Vector2).y))
	return y >= PRIMERA_FILA_3F and y <= ULTIMA_FILA_3F


## Espera a que el warp teletransporte al jugador (el telón empieza a aclararse).
func _esperar_teletransporte() -> void:
	await get_tree().process_frame
	var adm := _administrador()
	while is_instance_valid(adm) and int(adm.get("coneccion")) != 0:
		await get_tree().process_frame


## OnTransition de 1F y 3F: guardia de la escalera y empleado de la 3F.
func preparar() -> void:
	if _en_curso:
		return
	var guardia := _npc(guardia_escalera)
	if guardia != null:
		if HistoriaFerrica.piezas_devueltas():
			guardia.tipo_movimiento = TipoMovimiento.PASEAR_RANGO
			guardia.rango = Vector2i(2, 1)
			colocar(guardia, GUARDIA_LIBRE)
		else:
			guardia.tipo_movimiento = TipoMovimiento.MIRAR_ABAJO  # setobjectmovementtype 2, 8
			guardia.rango = Vector2i.ZERO
			colocar(guardia, GUARDIA_BLOQUEA)  # setobjectxyperm 2, 14, 2
	var empleado := _npc(empleado_3f)
	if empleado != null:
		if HistoriaFerrica.presidente_visto():
			empleado.tipo_movimiento = TipoMovimiento.MIRAR_DERECHA
			colocar(empleado, EMPLEADO_ESPERA)
		else:
			empleado.tipo_movimiento = TipoMovimiento.MIRAR_IZQUIERDA  # setobjectmovementtype 2, 9
			colocar(empleado, EMPLEADO_REUNION)  # setobjectxyperm 2, 3, 2
		# FLAG_HIDE_EMPLOYEE_DEVON_CORP_3F: se va a la RUTA 116 con las PIEZAS entregadas
		# (MUSEO de PORTUAL) y vuelve con la ACOPIO BALL.
		empleado.visible = empleado_presente()


static func empleado_presente() -> bool:
	return not (SistemaGuardado.get_flag(HistoriaFervergal.BANDERA_ENTREGADAS)
			and not SistemaGuardado.get_flag(HistoriaFervergal.BANDERA_ACOPIO_BALL))


## lock + faceplayer desde la interacción de un NPC.
func _comenzar_con(npc: Node2D) -> bool:
	var administrador_npc: Node = npc.nodo_administrador if npc.nodo_administrador != null else _administrador()
	if _en_curso or not comenzar(administrador_npc):
		if not _en_curso and npc.jugador and npc.jugador.has_method("esperar_dialogo"):
			npc.jugador.esperar_dialogo(false)
		return false
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	if npc.tipo_movimiento != TipoMovimiento.INVISIBLE:
		npc.mirar_jugador()
	return true


func _tiene(objeto: String) -> bool:
	var bolsillo := int(SistemaGuardado.obtener_datos_objeto_completos(objeto).get("bolsillo_id", 0))
	return SistemaGuardado.get_cantidad_objeto(objeto, bolsillo) > 0


## ============================================================================
## 2F: INVESTIGADORES
## ============================================================================

## RustboroCity_DevonCorp_2F_EventScript_SetFossilReady.
func _actualizar_fosil() -> void:
	if HistoriaFerrica.estado_fosil() == HistoriaFerrica.Fosil.REGENERANDO:
		SistemaGuardado.set_contador(HistoriaFerrica.CONTADOR_FOSIL, HistoriaFerrica.Fosil.LISTO)


func _texto_cientifico(npc: Node2D) -> String:
	if npc == _npc(cientifico_bolas) and SistemaGuardado.get_flag(HistoriaFerrica.BANDERA_EMPLEADO_CONOCIDO):
		return TEXTO_BOLAS_DESPUES
	if npc == _npc(cientifico_pokenav) and SistemaGuardado.get_flag(HistoriaFervergal.BANDERA_POKENAV):
		return TEXTO_POKENAV_DESPUES
	return npc.id_texto


func _on_cientifico_hablado(npc: Node2D) -> void:
	if not _comenzar_con(npc):
		return
	_actualizar_fosil()
	await mensaje(_texto_cientifico(npc))
	terminar(false, [npc])


## RustboroCity_DevonCorp_2F_EventScript_FossilScientist.
func _on_fosil_hablado(npc: Node2D) -> void:
	if not _comenzar_con(npc):
		return
	match HistoriaFerrica.estado_fosil():
		HistoriaFerrica.Fosil.LISTO:
			await _fosil_listo(npc)
			return
		HistoriaFerrica.Fosil.REGENERANDO:
			await mensaje(TEXTO_FOSIL_ESPERA)
			terminar(false, [npc])
			return
	await mensaje(TEXTO_FOSIL_INTRO)
	for tipo: int in FOSILES:
		if _tiene(FOSILES[tipo]["objeto"]):
			await _ofrecer_fosil(npc, tipo)  # NoticeRootFossil / NoticeClawFossil
			return
	terminar(false, [npc])


func _ofrecer_fosil(npc: Node2D, tipo: int) -> void:
	admin.cuadro_dialogo.cerrar()  # closemessage
	Singleton.play_sound.emit("SE_PIN")
	await exclamacion(npc)
	await esperar_fotogramas(48)  # Common_Movement_Delay48
	if not await preguntar_si_no(TEXTO_FOSIL_PREGUNTA):
		await mensaje(TEXTO_FOSIL_NO)  # DeclineGiveFossil
		terminar(false, [npc])
		return
	var objeto: String = FOSILES[tipo]["objeto"]
	var datos := SistemaGuardado.obtener_datos_objeto_completos(objeto)
	await mensaje(TEXTO_FOSIL_ENTREGA, true, {"{objeto}": str(datos.get("nombre", objeto))})
	SistemaGuardado.quitar_objeto_jugador(objeto, 1, int(datos.get("bolsillo_id", 0)))
	SistemaGuardado.set_contador(HistoriaFerrica.CONTADOR_FOSIL, HistoriaFerrica.Fosil.REGENERANDO)
	SistemaGuardado.set_contador(HistoriaFerrica.CONTADOR_FOSIL_ELEGIDO, tipo)
	terminar(false, [npc])


## RustboroCity_DevonCorp_2F_EventScript_LileepReady / AnorithReady.
func _fosil_listo(npc: Node2D) -> void:
	var tipo := SistemaGuardado.get_contador(HistoriaFerrica.CONTADOR_FOSIL_ELEGIDO)
	if not FOSILES.has(tipo):
		terminar(false, [npc])
		return
	var especie: String = FOSILES[tipo]["especie"]
	var nombre := _nombre_especie(especie)
	await mensaje(TEXTO_FOSIL_LISTO, true, {"{mon}": nombre})
	if SistemaGuardado.get_equipo().size() >= MAX_EQUIPO:
		await mensaje(TEXTO_FOSIL_LLENO)  # TooManyPokemon
		terminar(false, [npc])
		return
	SistemaGuardado.set_contador(HistoriaFerrica.CONTADOR_FOSIL, HistoriaFerrica.Fosil.NADA)
	SistemaGuardado.set_flag(HistoriaFerrica.BANDERA_FOSIL_RECIBIDO, true)
	await mensaje_con_fanfarria(TEXTO_FOSIL_RECIBIDO, FANFARRIA_OBJETO, {"{mon}": nombre})
	var seccion := ""
	if admin.has_method("obtener_seccion_lugar_actual"):
		seccion = str(admin.obtener_seccion_lugar_actual())
	var recibido: bool = SistemaGuardado.agregar_pokemon_al_equipo(especie, NIVEL_FOSIL, "", ORIGEN_FOSIL, seccion)
	var pokemon: BasePokemon = SistemaGuardado.get_equipo().back() if recibido else null
	if await preguntar_si_no(TEXTO_FOSIL_MOTE, {"{mon}": nombre}) and pokemon != null:
		await _poner_mote(pokemon)
	terminar(false, [npc])


static func _nombre_especie(especie: String) -> String:
	var datos: Dictionary = DatabaseManager.obtener_datos_pokemon(especie)
	return str(datos.get("nombre", especie))


## Common_EventScript_NameReceivedPartyMon.
func _poner_mote(pokemon: BasePokemon) -> void:
	admin.cuadro_dialogo.cerrar()
	var mote := ""
	if pedir_mote.is_valid():
		mote = str(await pedir_mote.call(pokemon))
	else:
		mote = await _pantalla_de_nombre(pokemon)
	if not mote.is_empty():
		pokemon.mote = mote


func _pantalla_de_nombre(pokemon: BasePokemon) -> String:
	var capa: Node = admin.get_node_or_null("Menu")
	if capa == null:
		return ""
	await oscurecer_pantalla()
	var entrada := SCN_ENTRADA_NOMBRE.instantiate() as Control
	entrada.z_index = 2
	var respuesta := {"lista": false, "nombre": ""}
	entrada.connect("nombre_confirmado", func(nombre: String) -> void:
		respuesta["lista"] = true
		respuesta["nombre"] = nombre
		_nombre_introducido.emit(nombre), CONNECT_ONE_SHOT)
	entrada.connect("cancelado", func() -> void:
		respuesta["lista"] = true
		_nombre_introducido.emit(""), CONNECT_ONE_SHOT)
	capa.add_child(entrada)
	entrada.call("configurar", TITULO_MOTE % pokemon.get_nombre_mostrar(), MAX_CARACTERES_MOTE,
		false, ENTRADA_NOMBRE_POKEMON, maxi(pokemon.numero_nacional, 1))
	await aclarar_pantalla()
	if not bool(respuesta["lista"]):
		await _nombre_introducido
	await oscurecer_pantalla()
	entrada.queue_free()
	await aclarar_pantalla()
	return str(respuesta["nombre"]).strip_edges()


## ============================================================================
## 3F: SR. PEÑAS
## ============================================================================

## RustboroCity_DevonCorp_3F_EventScript_MeetPresident.
func reunion_con_el_presidente() -> void:
	var empleado := _npc(empleado_3f)
	if empleado == null or not comenzar(_administrador()):
		return
	empleado.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	# OnWarp: turnobject LOCALID_PLAYER, 4. Se gira en cuanto aparece, durante el
	# fundido, y el diálogo espera a que acabe el bloqueo del teletransporte.
	await _esperar_teletransporte()
	girar_jugador(R)
	await esperar_fotogramas(33)
	await mensaje(TEXTO_PISO)
	await recorrer(empleado, EMPLEADO_SE_VA)
	await esperar_fotogramas(80)
	await recorrer(empleado, EMPLEADO_VUELVE)
	await mensaje(TEXTO_ACOMPANAME)
	reproducir_musica(MUSICA_SIGUEME)  # MUS_FOLLOW_ME
	await en_paralelo([_recorrer.bind(empleado, EMPLEADO_GUIA), recorrer_jugador.bind(JUGADOR_SIGUE)])
	mirar(empleado, L)
	await mensaje(TEXTO_ADELANTE)
	restaurar_musica_mapa()  # fadedefaultbgm
	await en_paralelo([_empleado_al_despacho.bind(empleado), _jugador_al_despacho])
	await mensaje(TEXTO_FAVOR, false)
	if not await dar_objeto(empleado, OBJETO_CARTA):
		await mensaje(TEXTO_MOCHILA_LLENA, false)
	await mensaje(TEXTO_REGALO)
	await mensaje_con_fanfarria(TEXTO_POKENAV_RECIBIDO)
	HistoriaFerrica.recibir_pokenav()  # FLAG_SYS_POKENAV_GET, FLAG_RECEIVED_POKENAV y lo que desbloquea
	await mensaje(TEXTO_POKENAV_EXPLICA)
	terminar(false, [empleado])


func _recorrer(npc: Node2D, pasos: Array) -> void:
	await recorrer(npc, pasos)


func _empleado_al_despacho(empleado: Node2D) -> void:
	await esperar_fotogramas(16)
	mirar(empleado, D)


func _jugador_al_despacho() -> void:
	await esperar_fotogramas(32)
	await recorrer_jugador(JUGADOR_AL_DESPACHO)
	girar_jugador(R)


## RustboroCity_DevonCorp_3F_EventScript_MrStone (también desde el objeto invisible).
func _on_presidente_hablado(npc: Node2D) -> void:
	if not _comenzar_con(npc):
		return
	var jefe := _npc(presidente)
	if SistemaGuardado.get_flag(HistoriaFerrica.BANDERA_REPARTIR_EXP):
		await mensaje(TEXTO_PRESIDENTE_MODAS)  # MrStoneAfterFavor
	elif SistemaGuardado.get_flag(HistoriaFerrica.BANDERA_CARTA):
		await mensaje(TEXTO_PRESIDENTE_GRACIAS, false)  # GiveExpShare
		if not await dar_objeto(npc, OBJETO_REPARTIR_EXP):
			await mensaje(TEXTO_MOCHILA_LLENA)  # Common_EventScript_ShowBagIsFull
			terminar(false, [npc])
			return
		SistemaGuardado.set_flag(HistoriaFerrica.BANDERA_REPARTIR_EXP, true)
		await mensaje(TEXTO_PRESIDENTE_REPARTIR)
	else:
		await mensaje(TEXTO_PRESIDENTE_CUENTO)
	if jefe != null:
		mirar(jefe, L)  # Common_Movement_FaceOriginalDirection
	terminar(false, [npc])
