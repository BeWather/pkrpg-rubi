## evento_casa_villa_raiz.gd
## Guiones de una planta de las casas de VILLA RAÍZ (pokeruby
## data/scripts/players_house.inc, data/maps/LittlerootTown_{Brendans,Mays}House_*).
## La casa 1 es la de BRUNO (BRENDAN) y la 2 la de AURA (MAY): según el sexo del
## jugador, una es su casa (MAMÁ) y la otra la del rival (su madre y el rival).
## Las coordenadas de las casas de Godot son las de Rubí.
##
## Casa del jugador:
## - Planta baja: entrar con MAMÁ (intro 3 → 4), no salir sin ver el cuarto (4),
##   volver arriba a poner el reloj (5), informe del GIMNASIO de PETALIA en la tele
##   (6 → 7) y MAMÁ según la historia (descansar en casa tras el rescate, MON. AMULETO
##   con la MEDALLA EQUILIBRIO).
## - MACHOKE de la mudanza (FLAG_HIDE_MACHOKE_MOVER_1/2): uno de espaldas
##   caminando en el sitio y otro yendo y viniendo con una caja, hasta poner el
##   reloj (intro 6). Las banderas son comunes a las dos casas, como en Rubí.
## - Cajas de la mudanza (TileAlterno en `cajas`, setmetatile): hasta el informe
##   del gimnasio (INTRO_STATE < 6), igual que los MACHOKE, en las dos casas.
## - Tele (TileAlterno en `tele`): pantalla encendida durante el informe del
##   gimnasio en la casa del jugador; se apaga tras el mensaje (TurnOffTVScreen).
## - Planta alta: subir (4 → 5) y poner el reloj (5 → 6, MAMÁ sube a verte).
## Casa del rival:
## - Planta baja: su madre; la primera vez que entras te ve, se acerca y se presenta
##   (HOUSES_STATE 1 → 2, FLAG_MET_RIVAL_MOM).
## - Planta alta: el rival se presenta y se va (VAR_LITTLEROOT_RIVAL_STATE 3,
##   VAR_LITTLEROOT_STATE 1). Su PC solo tiene un correo.
##
## Reloj de pared: RelojPared (src/wallclock.c), con el color de la casa en la que
## está (gSpecialVar_0x8004: MALE en la de BRUNO).
##
## Tras la LIGA, al bajar de tu cuarto: PAPÁ te da el TICKET BARCO y vuelve al GIMNASIO
## (PlayersHouse_1F_EventScript_GetSSTicketAndSeeLatiTV). MAMÁ lo comenta hasta que sales
## de la planta (en Rubí, hasta salir de casa: VAR_LITTLEROOT_HOUSES_STATE 4).
extends EventoGuionizado
class_name EventoCasaVillaRaiz

const MOTIVO_PAUSA: StringName = &"casa_villa_raiz"
const TipoMovimiento := NpcBase.TipoMovimientoNPC
const Intro := HistoriaVillaRaiz.Intro

const TEXTO_BONITO: String = "CASA_MAMA_BONITO"
const TEXTO_MUDANZA: String = "CASA_MAMA_MUDANZA"
const TEXTO_VER_CUARTO: String = "CASA_MAMA_VER_CUARTO"
const TEXTO_PON_RELOJ: String = "CASA_MAMA_PON_RELOJ"
const TEXTO_VEN_RAPIDO: String = "CASA_MAMA_VEN_RAPIDO"
const TEXTO_SALE_PAPA: String = "CASA_MAMA_SALE_PAPA"
const TEXTO_TELE: String = "CASA_TELE_GIMNASIO"
const TEXTO_SE_FUE_PAPA: String = "CASA_MAMA_SE_FUE_PAPA"
const TEXTO_VE_AL_VECINO: String = "CASA_MAMA_VE_AL_VECINO"
const TEXTO_HASTA_LUEGO: String = "CASA_MAMA_HASTA_LUEGO"
const TEXTO_CONOCISTE_ABEDUL: String = "CASA_MAMA_CONOCISTE_ABEDUL"
const TEXTO_DESCANSA: String = "CASA_MAMA_DESCANSA"
const TEXTO_CUIDATE: String = "CASA_MAMA_CUIDATE"
const TEXTO_MEDALLA_PAPA: String = "CASA_MAMA_MEDALLA_PAPA"
const TEXTO_NO_TE_ESFUERCES: String = "CASA_MAMA_NO_TE_ESFUERCES"
const TEXTO_MOCHILA_LLENA: String = "MOCHILA_LLENA_REGALO"
const OBJETO_MONEDA_AMULETO: String = "MONEDAAMULETO"
## FLAG_BADGE05_GET (MEDALLA EQUILIBRIO).
const INDICE_MEDALLA_PAPA: int = 4
const TEXTO_RELOJ_PARADO: String = "CASA_RELOJ_PARADO"
const TEXTO_HORA_CORRECTA: String = "CASA_RELOJ_HORA_CORRECTA"
const ESCENA_RELOJ: PackedScene = preload("res://UI/reloj-pared/reloj_pared.tscn")
const TEXTO_TU_CUARTO: String = "CASA_MAMA_TU_CUARTO"
const TEXTO_RIVAL_PREPARANDOSE: String = "CASA_RIVAL_PREPARANDOSE"
## Con variante _AURA / _BRUNO (HistoriaVillaRaiz.texto_rival).
const TEXTO_RIVAL_QUIEN_ERES: String = "CASA_RIVAL_QUIEN_ERES"
const TEXTO_MADRE_PRESENTA: String = "CASA_RIVAL_MAMA_PRESENTA"
const TEXTO_MADRE_ARRIBA: String = "CASA_RIVAL_MAMA_ARRIBA"
const TEXTO_MADRE_MARIDO: String = "CASA_RIVAL_MAMA_MARIDO"
const TEXTO_MADRE_SE_FUE: String = "CASA_RIVAL_MAMA_SE_FUE"
const TEXTO_MADRE_VUELVE: String = "CASA_RIVAL_MAMA_VUELVE_A_CASA"
const TEMA_ENTREVISTA: String = "THE_INTERVIEWERS"
const TEMA_CURACION: String = "POKEMON_RECUPERADOS"
const TEXTO_MACHOKE_ESPALDA: String = "CASA_MACHOKE_ESPALDA"
const TEXTO_MACHOKE_CAJA: String = "CASA_MACHOKE_CAJA"
const NACIONAL_MACHOKE: int = 67
const TEXTO_PAPA_TICKET: String = "CASA_PAPA_TICKET"
const TEXTO_PAPA_PUERTOS: String = "CASA_PAPA_PUERTOS"
const TEXTO_PAPA_VUELVO: String = "CASA_PAPA_VUELVO"
const TEXTO_MAMA_ESTE_PADRE: String = "CASA_MAMA_ESTE_PADRE"
const OBJETO_TICKET_BARCO: String = "TICKETBARCO"
## Objeto NORMAN, igual en las dos casas, y fila en la que PAPÁ alcanza al jugador.
const CELDA_PAPA: Vector2i = Vector2i(5, 6)
const FILA_ENTREGA_TICKET: int = 6

## Celdas de cada casa (iguales en Rubí y en Godot). Planta baja:
const CASA := {
	1: {
		"mama": Vector2i(2, 6), "mama_mira": TipoMovimiento.MIRAR_DERECHA,
		"madre_rival": Vector2i(2, 7), "madre_rival_mira": TipoMovimiento.MIRAR_DERECHA,
		"mama_puerta": Vector2i(9, 8), "mama_escalera": Vector2i(8, 4), "mama_tele": Vector2i(4, 5),
		"escalera": Vector2i(8, 2), "hacia_dentro": Vector2.LEFT, "ante_tele": Vector2i(5, 5),
		# MACHOKE: WALK_IN_PLACE_UP y WALK_RIGHT_AND_LEFT (rango 3).
		"machoke_espalda": Vector2i(4, 5), "machoke_caja": Vector2i(1, 3),
		"machoke_caja_mueve": TipoMovimiento.CAMINAR_DERECHA_IZQUIERDA,
		# Planta alta:
		"escalera_arriba": Vector2i(7, 1), "rival": Vector2i(1, 2),
	},
	2: {
		"mama": Vector2i(8, 6), "mama_mira": TipoMovimiento.MIRAR_IZQUIERDA,
		"madre_rival": Vector2i(8, 7), "madre_rival_mira": TipoMovimiento.MIRAR_IZQUIERDA,
		"mama_puerta": Vector2i(1, 8), "mama_escalera": Vector2i(2, 4), "mama_tele": Vector2i(6, 5),
		"escalera": Vector2i(2, 2), "hacia_dentro": Vector2.RIGHT, "ante_tele": Vector2i(5, 5),
		# MACHOKE: WALK_IN_PLACE_UP y WALK_LEFT_AND_RIGHT (rango 3).
		"machoke_espalda": Vector2i(6, 5), "machoke_caja": Vector2i(9, 3),
		"machoke_caja_mueve": TipoMovimiento.CAMINAR_IZQUIERDA_DERECHA,
		"escalera_arriba": Vector2i(1, 1), "rival": Vector2i(7, 2),
	},
}

## 1 = casa de BRUNO, 2 = casa de AURA.
@export_range(1, 2) var casa: int = 1
## 1 = planta baja, 2 = planta alta.
@export_range(1, 2) var planta: int = 1
@export var mama: NodePath
@export var papa: NodePath
@export var madre_rival: NodePath
@export var rival: NodePath
## Planta baja: MACHOKE de la mudanza (de espaldas y con caja).
@export var machoke_espalda: NodePath
@export var machoke_caja: NodePath
## Planta baja: TileAlterno de las cajas de la mudanza y de la pantalla de la tele.
@export var cajas: Array[NodePath] = []
@export var tele: NodePath
## Planta alta: reloj de pared (CartelEvento), PC del jugador (EventoPCCasa) y PC
## del rival (correo).
@export var reloj: NodePath
@export var pc_jugador: NodePath
@export var pc_rival: NodePath

## Sustituye al AdministradorMapa de la raíz del árbol (tests).
var administrador: Node = null
## VAR_TEMP_1 tras el informe de la tele: "¡Hasta luego, cielo!" hasta salir.
var _recien_visto_informe: bool = false
## VAR_LITTLEROOT_HOUSES_STATE 4: PAPÁ se acaba de ir.
var _papa_recien_ido: bool = false
var _generacion_trote: int = 0


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	for hijo in get_children():
		if hijo is DisparadorEventoPorTiles:
			hijo.evento_activado.connect(_on_disparador)
	_conectar(mama, "hablado", _on_mama_hablada)
	_conectar(madre_rival, "hablado", _on_madre_rival_hablada)
	_conectar(rival, "hablado", _on_rival_hablado)
	_conectar(reloj, "accionado", _on_reloj)
	_conectar(machoke_espalda, "hablado", _on_machoke_hablado.bind(TEXTO_MACHOKE_ESPALDA))
	_conectar(machoke_caja, "hablado", _on_machoke_hablado.bind(TEXTO_MACHOKE_CAJA))
	var mapa := obtener_mapa()
	if mapa != null:
		mapa.mapa_activado.connect(_on_mapa_activado)
	preparar()
	_generacion_trote += 1
	_bucle_trote(_npc(machoke_espalda), _generacion_trote)


func _conectar(ruta: NodePath, senal: StringName, metodo: Callable) -> void:
	var nodo := get_node_or_null(ruta)
	if nodo != null and nodo.has_signal(senal):
		nodo.connect(senal, metodo)


func _npc(ruta: NodePath) -> Node2D:
	return get_node_or_null(ruta) as Node2D


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


func es_casa_del_jugador() -> bool:
	return casa == HistoriaVillaRaiz.casa_jugador()


func _celda(clave: String) -> Vector2i:
	return CASA[casa][clave]


## ============================================================================
## ON_TRANSITION / ON_FRAME
## ============================================================================

func _on_mapa_activado(_por_warp: bool) -> void:
	_recien_visto_informe = false
	_papa_recien_ido = false
	preparar()
	if not es_casa_del_jugador():
		# LittlerootTown_*House_1F_OnFrame (VAR_LITTLEROOT_HOUSES_STATE(_2) 1): la
		# madre del rival te ve entrar la primera vez.
		if planta == 1 and HistoriaVillaRaiz.madre_rival_por_conocer():
			await esperar_fin_warp(_administrador())
			await _presentacion_madre_rival()
		return
	if planta == 2:
		# LittlerootTown_*House_2F_OnTransition: subir al cuarto (intro 4 → 5).
		if HistoriaVillaRaiz.intro() == Intro.VER_CUARTO:
			HistoriaVillaRaiz.set_intro(Intro.PONER_RELOJ)
		return
	if HistoriaVillaRaiz.ticket_barco_por_recibir():
		await esperar_fin_warp(_administrador())
		await _entrega_ticket_barco()
		return
	match HistoriaVillaRaiz.intro():
		Intro.ENTRAR_EN_CASA, Intro.PONER_RELOJ, Intro.INFORME_GIMNASIO:
			await esperar_fin_warp(_administrador())
			await guion_planta_baja()


## Coloca a cada uno según la historia (OnTransition y flags FLAG_HIDE_*).
func preparar() -> void:
	if _en_curso:
		return
	var del_jugador := es_casa_del_jugador()
	if planta == 1:
		_preparar_mama(del_jugador)
		_preparar_papa(del_jugador)
		var npc_madre := _npc(madre_rival)
		if npc_madre != null:
			npc_madre.tipo_movimiento = CASA[casa]["madre_rival_mira"]
			colocar(npc_madre, _celda("madre_rival"))
			npc_madre.visible = not del_jugador
		_preparar_machokes()
		_preparar_tele(del_jugador)
		return
	var npc_mama := _npc(mama)
	if npc_mama != null:  # FLAG_HIDE_MOM_UPSTAIRS: solo sube en la escena del reloj
		npc_mama.visible = false
	var npc_rival := _npc(rival)
	if npc_rival != null:
		npc_rival.tipo_movimiento = TipoMovimiento.MIRAR_ARRIBA
		colocar(npc_rival, _celda("rival"))
		npc_rival.visible = not del_jugador and HistoriaVillaRaiz.rival_en_su_cuarto()
	_activar_cartel(pc_jugador, del_jugador)
	_activar_cartel(pc_rival, not del_jugador)


func _preparar_mama(del_jugador: bool) -> void:
	var npc_mama := _npc(mama)
	if npc_mama == null:
		return
	npc_mama.visible = del_jugador
	var celda := _celda("mama")
	var tipo: int = CASA[casa]["mama_mira"]
	match HistoriaVillaRaiz.intro():
		Intro.ENTRAR_EN_CASA, Intro.VER_CUARTO:
			celda = _celda("mama_puerta")
			tipo = TipoMovimiento.MIRAR_ARRIBA
		Intro.PONER_RELOJ:
			celda = _celda("mama_escalera")
			tipo = TipoMovimiento.MIRAR_ARRIBA
		Intro.INFORME_GIMNASIO:
			celda = _celda("mama_tele")
			tipo = TipoMovimiento.MIRAR_ARRIBA
	npc_mama.tipo_movimiento = tipo
	colocar(npc_mama, celda)


## FLAG_HIDE_NORMAN_LITTLEROOT: solo está mientras espera para dar el TICKET BARCO.
func _preparar_papa(del_jugador: bool) -> void:
	var npc_papa := _npc(papa)
	if npc_papa == null:
		return
	npc_papa.tipo_movimiento = TipoMovimiento.SIN_MOVIMIENTO
	colocar(npc_papa, CELDA_PAPA)
	npc_papa.visible = del_jugador and HistoriaVillaRaiz.ticket_barco_por_recibir()


## FLAG_HIDE_MACHOKE_MOVER_1/2: se van al poner el reloj (intro 6).
func _preparar_machokes() -> void:
	var de_mudanza := HistoriaVillaRaiz.intro() < Intro.INFORME_GIMNASIO
	var npc_espalda := _npc(machoke_espalda)
	if npc_espalda != null:
		npc_espalda.tipo_movimiento = TipoMovimiento.MIRAR_ARRIBA
		colocar(npc_espalda, _celda("machoke_espalda"))
		npc_espalda.visible = de_mudanza
	var npc_caja := _npc(machoke_caja)
	if npc_caja != null:
		npc_caja.tipo_movimiento = CASA[casa]["machoke_caja_mueve"] if de_mudanza else TipoMovimiento.SIN_MOVIMIENTO
		colocar(npc_caja, _celda("machoke_caja"))
		npc_caja.visible = de_mudanza
	for ruta in cajas:
		_tile_alterno(ruta, de_mudanza)


## La tele se enciende en la casa del jugador mientras dura el informe del
## gimnasio; el guion la apaga tras el mensaje (_informe_del_gimnasio).
func _preparar_tele(del_jugador: bool) -> void:
	_tile_alterno(tele, del_jugador and HistoriaVillaRaiz.intro() == Intro.INFORME_GIMNASIO)


func _tile_alterno(ruta: NodePath, encendido: bool) -> void:
	var tile := get_node_or_null(ruta) as TileAlterno if not ruta.is_empty() else null
	if tile != null:
		tile.activo = encendido


## MOVEMENT_TYPE_WALK_IN_PLACE_UP: npc_base no anima los CAMINAR_ENLUGAR_*.
func _bucle_trote(npc: Node2D, generacion: int) -> void:
	if npc == null:
		return
	while generacion == _generacion_trote and is_instance_valid(npc) and is_inside_tree():
		if npc.is_visible_in_tree() and not _en_curso:
			await trotar_en_sitio(npc, Vector2.UP, 1, 16)
		else:
			await get_tree().process_frame


## Un PC u otro "cartel" deja de leerse fuera del grupo Cartel.
func _activar_cartel(ruta: NodePath, activo: bool) -> void:
	var nodo := get_node_or_null(ruta)
	if nodo == null:
		return
	if activo and not nodo.is_in_group("Cartel"):
		nodo.add_to_group("Cartel")
	elif not activo and nodo.is_in_group("Cartel"):
		nodo.remove_from_group("Cartel")


## LittlerootTown_*House_1F_OnFrame de la casa del jugador.
func guion_planta_baja() -> void:
	match HistoriaVillaRaiz.intro():
		Intro.ENTRAR_EN_CASA:
			await _entrar_con_mama()
		Intro.PONER_RELOJ:
			await _sube_a_poner_el_reloj()
		Intro.INFORME_GIMNASIO:
			await _informe_del_gimnasio()


## PlayersHouse_1F_EventScript_EnterHouseMovingIn.
func _entrar_con_mama() -> void:
	if not comenzar(_administrador()):
		return
	var npc_mama := _npc(mama)
	await mensaje(TEXTO_BONITO, false)
	var hacia_dentro: Vector2 = CASA[casa]["hacia_dentro"]
	if npc_mama != null:
		# Common_Movement_FacePlayer: el jugador está a su lado, hacia dentro (por
		# posición, no por la mirada del jugador, que aún mira a la escalera).
		mirar(npc_mama, hacia_dentro)
	girar_jugador(-hacia_dentro)  # mira a MAMÁ, junto a la puerta
	await mensaje(TEXTO_MUDANZA)
	admin.cuadro_dialogo.cerrar()
	HistoriaVillaRaiz.set_intro(Intro.VER_CUARTO)
	await recorrer_jugador([Vector2.UP])
	if npc_mama != null:
		mirar(npc_mama, Vector2.UP)
	terminar(false, [npc_mama] if npc_mama != null else [])


## LittlerootTown_*House_1F_EventScript_GoUpstairsToSetClock: MAMÁ te lleva a la
## escalera y subes.
func _sube_a_poner_el_reloj() -> void:
	if not comenzar(_administrador()):
		return
	var npc_mama := _npc(mama)
	await mensaje(TEXTO_PON_RELOJ)
	admin.cuadro_dialogo.cerrar()
	var tareas: Array[Callable] = []
	if Vector2i(admin.jugador.pos_celda_act) != _celda("escalera"):
		tareas.append(recorrer_jugador.bind([Vector2.UP]))
	if npc_mama != null:
		tareas.append(caminar.bind(npc_mama, Vector2.UP))
	await en_paralelo(tareas)
	_subir_al_cuarto([npc_mama] if npc_mama != null else [])


## warp a la planta alta (7,1) / (1,1).
func _subir_al_cuarto(npcs: Array) -> void:
	var jugador: Node = admin.jugador
	var admin_actual := admin
	terminar(true, npcs)
	jugador.end_dialog()
	jugador.no_control = true
	if int(admin_actual.get("coneccion")) != 0:
		return  # el paso acabó en la escalera y su warp ya está en marcha
	# Como la escalera (dar_paso): se llega a la escalera de arriba y se baja un paso
	# para no volver a pisarla.
	admin_actual.conectar_escalera("nodo_casa_%d_piso_2" % casa, Vector2(_celda("escalera_arriba")), Vector2.DOWN, true)


## PlayersHouse_1F_EventScript_PetalburgGymReport{Male,Female}.
func _informe_del_gimnasio() -> void:
	if not comenzar(_administrador()):
		return
	var npc_mama := _npc(mama)
	var hacia_dentro: Vector2 = CASA[casa]["hacia_dentro"]
	if npc_mama != null:
		mirar(npc_mama, -hacia_dentro)
		# LittlerootTown_*House_1F_EventScript_1B6B9D.
		await exclamacion(npc_mama)
		await esperar_fotogramas(48)
	await mensaje(TEXTO_VEN_RAPIDO)
	admin.cuadro_dialogo.cerrar()
	await _ir_hacia(_celda("ante_tele"))
	reproducir_musica(TEMA_ENTREVISTA)
	await mensaje(TEXTO_SALE_PAPA)
	admin.cuadro_dialogo.cerrar()
	if npc_mama != null:
		await caminar(npc_mama, hacia_dentro)
		mirar(npc_mama, -hacia_dentro)
	await recorrer_jugador([hacia_dentro])
	# LittlerootTown_*House_1F_EventScript_1B6BBE.
	girar_jugador(Vector2.UP)
	await mensaje(TEXTO_TELE)
	restaurar_musica_mapa()  # fadedefaultbgm
	_tile_alterno(tele, false)  # special TurnOffTVScreen
	SistemaGuardado.set_flag(HistoriaVillaRaiz.BANDERA_TELE, true)  # FLAG_SYS_TV_HOME
	await esperar_fotogramas(35)
	girar_jugador(hacia_dentro)
	await mensaje(TEXTO_SE_FUE_PAPA, false)
	await mensaje(TEXTO_VE_AL_VECINO)
	admin.cuadro_dialogo.cerrar()
	_recien_visto_informe = true
	if npc_mama != null:
		await recorrer(npc_mama, [hacia_dentro, Vector2.DOWN])
		mirar(npc_mama, -hacia_dentro)
		npc_mama.tipo_movimiento = CASA[casa]["mama_mira"]
	HistoriaVillaRaiz.set_intro(Intro.TERMINADA)
	terminar(false, [npc_mama] if npc_mama != null else [])


## PlayersHouse_1F_EventScript_GetSSTicketAndSeeLatiTV. Con la mochila llena no marca la
## bandera y PAPÁ sigue esperando la próxima vez que entres.
func _entrega_ticket_barco() -> void:
	if _en_curso or not HistoriaVillaRaiz.ticket_barco_por_recibir() or not comenzar(_administrador()):
		return
	var npc_papa := _npc(papa)
	var hacia_dentro: Vector2 = CASA[casa]["hacia_dentro"]
	await esperar_fotogramas(16)
	await _ir_a_entrega_ticket()
	girar_jugador(hacia_dentro)
	if npc_papa != null:
		mirar(npc_papa, -hacia_dentro)
		Singleton.play_sound.emit("SE_PIN")
		await exclamacion(npc_papa)
		await esperar_fotogramas(68)  # Common_Movement_Delay48 + delay 20
		await recorrer(npc_papa, [-hacia_dentro, -hacia_dentro])
	await mensaje(TEXTO_PAPA_TICKET, false)
	if not await dar_objeto(npc_papa, OBJETO_TICKET_BARCO):
		await mensaje(TEXTO_MOCHILA_LLENA)
		terminar(false, [npc_papa] if npc_papa != null else [])
		return
	SistemaGuardado.set_flag(HistoriaVillaRaiz.BANDERA_TICKET_BARCO, true)
	await mensaje(TEXTO_PAPA_PUERTOS)
	admin.cuadro_dialogo.cerrar()
	if npc_papa != null:
		await caminar(npc_papa, hacia_dentro)
	await mensaje(TEXTO_PAPA_VUELVO)
	admin.cuadro_dialogo.cerrar()
	if npc_papa != null:
		await en_paralelo([_jugador_mira_abajo_con_retraso, recorrer.bind(npc_papa, camino_de_papa(casa))])
		await esperar_fotogramas(8)
		Singleton.play_sound.emit("puerta_entrada")  # playse SE_DOOR
		npc_papa.visible = false  # removeobject
	_papa_recien_ido = true
	terminar(false, [npc_papa] if npc_papa != null else [])


## LittlerootTown_BrendansHouse_1F_Movement_1B6E4F: delay_16 ×3 y mira abajo.
func _jugador_mira_abajo_con_retraso() -> void:
	await esperar_fotogramas(48)
	girar_jugador(Vector2.DOWN)


## Movement_1B6E49 / 1B6E54: de la llegada de la escalera a la fila de PAPÁ. Una partida
## que ya pasó la LIGA puede entrar por la puerta: primero sube y luego va de lado.
func _ir_a_entrega_ticket() -> void:
	var celda: Vector2i = admin.jugador.pos_celda_act
	var destino := Vector2i(_celda("escalera").x, FILA_ENTREGA_TICKET)
	var pasos: Array = []
	var vertical := signi(destino.y - celda.y)
	for i in absi(destino.y - celda.y):
		pasos.append(Vector2(0, vertical))
	var lateral := signi(destino.x - celda.x)
	for i in absi(destino.x - celda.x):
		pasos.append(Vector2(lateral, 0))
	await recorrer_jugador(pasos)


## LittlerootTown_BrendansHouse_1F_Movement_1B6E3D / 1B6E43.
static func camino_de_papa(numero_casa: int) -> Array:
	var hacia_puerta := Vector2.RIGHT if numero_casa == 1 else Vector2.LEFT
	return [Vector2.DOWN, hacia_puerta, hacia_puerta, Vector2.DOWN]


## Desde la escalera (o la casilla de debajo) baja hasta la fila de `destino` y
## luego va de lado (walk_down ×2, walk_left/right ×3 de Rubí).
func _ir_hacia(destino: Vector2i) -> void:
	var celda: Vector2i = admin.jugador.pos_celda_act
	var pasos: Array = []
	for i in maxi(destino.y - celda.y, 0):
		pasos.append(Vector2.DOWN)
	var lateral := signi(destino.x - celda.x)
	for i in absi(destino.x - celda.x):
		pasos.append(Vector2(lateral, 0))
	await recorrer_jugador(pasos)


## ============================================================================
## DISPARADORES Y CONVERSACIONES
## ============================================================================

func _on_disparador(id_evento: StringName) -> void:
	if id_evento == &"ver_cuarto" and es_casa_del_jugador() \
			and HistoriaVillaRaiz.intro() == Intro.VER_CUARTO:
		_ve_a_ver_tu_cuarto()


## LittlerootTown_*House_1F_EventScript_GoSeeRoom.
func _ve_a_ver_tu_cuarto() -> void:
	if _en_curso or not comenzar(_administrador()):
		return
	var npc_mama := _npc(mama)
	if npc_mama != null:
		mirar(npc_mama, CASA[casa]["hacia_dentro"])
	await mensaje(TEXTO_VER_CUARTO)
	admin.cuadro_dialogo.cerrar()
	if npc_mama != null:
		mirar(npc_mama, Vector2.UP)
	await recorrer_jugador([Vector2.UP])
	terminar(false, [npc_mama] if npc_mama != null else [])


## LittlerootTown_*House_1F_EventScript_1B6BE9.
func _on_mama_hablada(npc: Node2D) -> void:
	if _en_curso or not _comenzar_con(npc):
		return
	npc.mirar_jugador()
	if _papa_recien_ido:
		await mensaje(TEXTO_MAMA_ESTE_PADRE)
	elif SistemaGuardado.tiene_medalla(INDICE_MEDALLA_PAPA) \
			and not SistemaGuardado.get_flag(HistoriaVillaRaiz.BANDERA_MONEDA_AMULETO):
		await _dar_moneda_amuleto(npc)
	elif SistemaGuardado.get_flag(HistoriaVillaRaiz.BANDERA_RESCATADO) \
			or SistemaGuardado.tiene_medalla(INDICE_MEDALLA_PAPA):
		await mensaje(TEXTO_DESCANSA)
		admin.cuadro_dialogo.cerrar()
		await _descansar_en_casa()
		await mensaje(TEXTO_CUIDATE)
	elif _recien_visto_informe:
		await mensaje(TEXTO_HASTA_LUEGO)
	elif HistoriaVillaRaiz.intro() >= Intro.TERMINADA:
		await mensaje(TEXTO_CONOCISTE_ABEDUL)
	else:
		await mensaje(TEXTO_BONITO)
	terminar(false, [npc])


## LittlerootTown_BrendansHouse_1F_EventScript_1B6C3D. Con la mochila llena no marca
## la bandera y MAMÁ vuelve a ofrecerla.
func _dar_moneda_amuleto(npc: Node2D) -> void:
	await mensaje(TEXTO_MEDALLA_PAPA, false)
	if not await dar_objeto(npc, OBJETO_MONEDA_AMULETO):
		await mensaje(TEXTO_MOCHILA_LLENA)  # Common_EventScript_ShowBagIsFull
		return
	await mensaje(TEXTO_NO_TE_ESFUERCES)
	SistemaGuardado.set_flag(HistoriaVillaRaiz.BANDERA_MONEDA_AMULETO, true)


## Common_EventScript_OutOfCenterPartyHeal.
func _descansar_en_casa() -> void:
	await oscurecer_pantalla()
	await fanfarria(TEMA_CURACION, true)
	SistemaGuardado.curar_equipo_completo()
	await aclarar_pantalla()


## LittlerootTown_*House_1F_EventScript_1B6CA6 / 1B6CB9: lock, faceplayer,
## playmoncry SPECIES_MACHOKE, msgbox y waitmoncry.
func _on_machoke_hablado(npc: Node2D, clave: String) -> void:
	if _en_curso or not _comenzar_con(npc):
		return
	npc.mirar_jugador()
	var reproductor: Variant = grito(NACIONAL_MACHOKE)
	await mensaje(clave, false)
	await esperar_grito(reproductor)
	terminar(false, [npc])


## LittlerootTown_BrendansHouse_1F_EventScript_152744 / MaysHouse_1F_EventScript_152982:
## la madre del rival se sobresalta al verte entrar, se acerca y se presenta. Solo
## una vez (FLAG_MET_RIVAL_MOM).
func _presentacion_madre_rival() -> void:
	# Pudo cambiar durante la espera del warp (otra escena, o ya la ha visto).
	if _en_curso or not HistoriaVillaRaiz.madre_rival_por_conocer():
		return
	if not comenzar(_administrador()):
		return
	var npc_madre := _npc(madre_rival)
	if npc_madre != null:
		Singleton.play_sound.emit("SE_PIN")
		await exclamacion(npc_madre)
		await esperar_fotogramas(48)  # Movement_1A0835: delay_16 ×3
		# El jugador gira hacia ella (walk_in_place_fastest) mientras ella viene: sin
		# colisiones, como el applymovement de Rubí.
		girar_jugador(CASA[casa]["hacia_dentro"])
		await recorrer(npc_madre, camino_de_la_madre_rival(casa))
	else:
		girar_jugador(CASA[casa]["hacia_dentro"])
	await mensaje(HistoriaVillaRaiz.texto_rival(TEXTO_MADRE_PRESENTA))
	SistemaGuardado.set_flag(HistoriaVillaRaiz.BANDERA_MADRE_RIVAL_CONOCIDA, true)  # HOUSES_STATE 2
	terminar(false, [npc_madre] if npc_madre != null else [])


## LittlerootTown_BrendansHouse_1F_Movement_152782 / MaysHouse_1F_Movement_1529C0:
## de su sitio (2,7) / (8,7) a abajo y cinco casillas hacia el jugador, que entra
## por la puerta.
static func camino_de_la_madre_rival(numero_casa: int) -> Array:
	var camino: Array = [Vector2.DOWN]
	camino.append_array(EventoVillaRaiz._repetir(Vector2.LEFT if numero_casa == 2 else Vector2.RIGHT, 5))
	return camino


## RivalsHouse_1F_EventScript_RivalMom.
func _on_madre_rival_hablada(npc: Node2D) -> void:
	if _en_curso or not _comenzar_con(npc):
		return
	npc.mirar_jugador()
	var clave := TEXTO_MADRE_ARRIBA
	if SistemaGuardado.get_flag(HistoriaVillaRaiz.BANDERA_RIVAL_RUTA_103):
		clave = TEXTO_MADRE_VUELVE
	elif SistemaGuardado.get_flag(HistoriaVillaRaiz.BANDERA_RIVAL_SE_FUE):
		clave = TEXTO_MADRE_SE_FUE
	elif SistemaGuardado.get_flag(HistoriaVillaRaiz.BANDERA_RIVAL_CONOCIDO):
		clave = TEXTO_MADRE_MARIDO
	await mensaje(HistoriaVillaRaiz.texto_rival(clave))
	terminar(false, [npc])


## LittlerootTown_*House_2F_EventScript_152A9D: el rival se presenta y se va por
## la escalera; el camino depende de hacia dónde mira el jugador (VAR_FACING).
func _on_rival_hablado(npc: Node2D) -> void:
	if _en_curso or not HistoriaVillaRaiz.rival_en_su_cuarto() or not _comenzar_con(npc):
		return
	var mirada: Vector2 = admin.jugador.facing_direction
	await mensaje(TEXTO_RIVAL_PREPARANDOSE)
	reproducir_musica(Rival.musica_encuentro())
	npc.mirar_jugador()
	await exclamacion(npc)
	await esperar_fotogramas(48)
	await mensaje(HistoriaVillaRaiz.texto_rival(TEXTO_RIVAL_QUIEN_ERES))
	admin.cuadro_dialogo.cerrar()
	await recorrer(npc, camino_del_rival(casa, mirada))
	await esperar_fotogramas(8)
	Singleton.play_sound.emit("puerta_salida")  # playse SE_EXIT
	npc.visible = false  # removeobject
	SistemaGuardado.set_flag(HistoriaVillaRaiz.BANDERA_RIVAL_CONOCIDO, true)  # RIVAL_STATE 3, LITTLEROOT_STATE 1
	restaurar_musica_mapa()  # savebgm 0 + fadedefaultbgm
	terminar(false, [npc])


## LittlerootTown_BrendansHouse_2F_Movement_152C11 / 152C1C / 152C25 / 152C30.
static func camino_del_rival(numero_casa: int, mirada_jugador: Vector2) -> Array:
	var camino: Array = []
	if numero_casa == 2:  # AURA, de (7,2) a la escalera (1,1)
		if mirada_jugador == Vector2.RIGHT:
			camino.append(Vector2.DOWN)
			camino.append_array(EventoVillaRaiz._repetir(Vector2.LEFT, 6))
			camino.append_array([Vector2.UP, Vector2.UP])
		else:
			camino.append_array(EventoVillaRaiz._repetir(Vector2.LEFT, 6))
			camino.append(Vector2.UP)
	else:  # BRUNO, de (1,2) a la escalera (7,1)
		if mirada_jugador == Vector2.LEFT:
			camino.append(Vector2.DOWN)
			camino.append_array(EventoVillaRaiz._repetir(Vector2.RIGHT, 6))
			camino.append_array([Vector2.UP, Vector2.UP])
		else:
			camino.append_array(EventoVillaRaiz._repetir(Vector2.RIGHT, 6))
			camino.append(Vector2.UP)
	return camino


func _comenzar_con(npc: Node2D) -> bool:
	if not comenzar(npc.nodo_administrador):
		if npc.jugador and npc.jugador.has_method("esperar_dialogo"):
			npc.jugador.esperar_dialogo(false)
		return false
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	return true


## ============================================================================
## RELOJ (LittlerootTown_*House_2F_EventScript_1B69EB)
## ============================================================================

func _on_reloj(_cartel: Node) -> void:
	if _en_curso or not comenzar(_administrador()):
		return
	if SistemaGuardado.get_flag(HistoriaVillaRaiz.BANDERA_RELOJ):
		await _ver_reloj(RelojPared.Modo.VER)  # ScrSpecial_ViewWallClock
		terminar()
		return
	await mensaje(TEXTO_RELOJ_PARADO)
	admin.cuadro_dialogo.cerrar()
	if not es_casa_del_jugador():
		terminar()
		return
	await _ver_reloj(RelojPared.Modo.AJUSTAR)  # StartWallClock
	await esperar_fotogramas(30)
	SistemaGuardado.set_flag(HistoriaVillaRaiz.BANDERA_RELOJ, true)
	if HistoriaVillaRaiz.intro() != Intro.PONER_RELOJ:
		terminar()
		return
	HistoriaVillaRaiz.set_intro(Intro.INFORME_GIMNASIO)
	await _mama_sube_a_verte()
	terminar()


## fadescreen 1 + special StartWallClock / ScrSpecial_ViewWallClock + waitstate.
## El reloj va en la capa del menú, por debajo del cuadro de diálogo (la pregunta
## de la hora) y del telón (los fundidos). Sin esa capa (dobles de los tests),
## solo el fundido.
func _ver_reloj(modo: RelojPared.Modo) -> void:
	await oscurecer_pantalla()
	var capa: Node = admin.get_node_or_null("Menu")
	if capa == null:
		await esperar_fotogramas(30)
		await aclarar_pantalla()
		return
	var reloj: RelojPared = ESCENA_RELOJ.instantiate()
	reloj.configurar(modo, casa == 1)
	reloj.preguntar = _hora_correcta
	capa.add_child(reloj)
	var cuadro: Node = admin.cuadro_dialogo
	if cuadro != null and cuadro.get_parent() == capa:
		capa.move_child(reloj, cuadro.get_index())
	await aclarar_pantalla()
	reloj.activar()
	await reloj.terminado
	if reloj.confirmado:
		RelojJuego.ajustar(reloj.hora, reloj.minuto)  # RtcInitLocalTimeOffset
	await oscurecer_pantalla()
	admin.cuadro_dialogo.cerrar()
	reloj.queue_free()
	await aclarar_pantalla()


## Task_SetClock3/4: "¿Es la hora correcta?". Con NO (o B) se borra la pregunta y
## se sigue ajustando.
func _hora_correcta() -> bool:
	var correcta := await preguntar_si_no(TEXTO_HORA_CORRECTA)
	if not correcta:
		admin.cuadro_dialogo.cerrar()
	return correcta


## LittlerootTown_BrendansHouse_2F_EventScript_1B6A31 / 1B6A61.
func _mama_sube_a_verte() -> void:
	var npc_mama := _npc(mama)
	if npc_mama == null:
		return
	var hacia_el_jugador := Vector2.LEFT if casa == 1 else Vector2.RIGHT
	npc_mama.tipo_movimiento = TipoMovimiento.SIN_MOVIMIENTO
	colocar(npc_mama, _celda("escalera_arriba"))
	npc_mama.visible = true  # addobject
	await esperar_fotogramas(8)
	await caminar(npc_mama, Vector2.DOWN)
	mirar(npc_mama, hacia_el_jugador)
	await esperar_fotogramas(24)
	await caminar(npc_mama, hacia_el_jugador)
	girar_jugador(-hacia_el_jugador)
	await mensaje(TEXTO_TU_CUARTO)
	admin.cuadro_dialogo.cerrar()
	await recorrer(npc_mama, [-hacia_el_jugador, Vector2.UP])
	await esperar_fotogramas(8)
	Singleton.play_sound.emit("puerta_salida")  # playse SE_EXIT
	npc_mama.visible = false  # removeobject
	if npc_mama.estado_actual != NpcBase.EstadoNPC.IDLE:
		npc_mama.cambiar_estado(NpcBase.EstadoNPC.IDLE)
