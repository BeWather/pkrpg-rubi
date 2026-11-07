@tool
## npc_arenque_casa.gd
## SR. ARENQUE en su casa de la RUTA 104 (pokeruby Route104_MrBrineysHouse_EventScript_15BCEB).
## - Visible con `bandera_mostrar` (inversa de FLAG_HIDE_MR_BRINEY_ROUTE104_HOUSE, que
##   quitan DEVON 3F y PUEBLO AZULIZA). PEEKO usa la misma bandera.
## - ON_TRANSITION con VAR_BRINEY_HOUSE_STATE 1 (`bandera_persecucion`, la pone el
##   rescate de PEEKO en el TÚNEL FERVERGAL): ARENQUE a (9,3) y PEEKO a (9,6),
##   persiguiéndose con secuencias de caminata. Con el POKéNAV oculta al rival de FÉRRICA.
## - Al hablarle: la primera vez «¡Un segundo, grumete!» (FLAG_MR_BRINEY_SAILING_INTRO)
##   y la pregunta de navegar; sin la CARTA entregada, la de la CARTA; sin las PIEZAS
##   entregadas, la del paquete; con todo entregado, el menú AZULIZA / SALIR.
##   NO / SALIR → despedida.
## - SÍ / AZULIZA → «¡Rumbo a AZULIZA!»: ARENQUE y PEEKO dejan la casa, ARENQUE espera
##   en el muelle de la RUTA 104 y el jugador sale allí (warp a (13,51) de Rubí); el viaje
##   lo hace EventoBarcaArenque (Route104_EventScript_14EFD5).
extends "res://scripts/npc/npc_dialogo_condicional.gd"


const TEXTO_UN_SEGUNDO: String = "ARENQUE_UN_SEGUNDO"
const TEXTO_NAVEGAR: String = "ARENQUE_NAVEGAR"
const TEXTO_CARTA: String = "ARENQUE_CARTA"
const TEXTO_PAQUETE: String = "ARENQUE_PAQUETE"
const TEXTO_ADONDE: String = "ARENQUE_ADONDE"
const TEXTO_RECADOS: String = "ARENQUE_RECADOS"
const TEXTO_PEEKO_TE_DEBE: String = "ARENQUE_PEEKO_TE_DEBE"
const TEXTO_RUMBO: String = "ARENQUE_RUMBO"
const OPCION_AZULIZA: String = "ARENQUE_OPCION_AZULIZA"
const OPCION_SALIR: String = "ARENQUE_OPCION_SALIR"

## FLAG_MR_BRINEY_SAILING_INTRO.
const BANDERA_PRESENTACION: String = "arenque_presentacion"
## FLAG_DELIVERED_STEVEN_LETTER.
const BANDERA_CARTA: String = "carta_maximo_entregada"
## FLAG_DELIVERED_DEVON_GOODS.
const BANDERA_PIEZAS: String = "piezas_devon_entregadas"

## VAR_BRINEY_HOUSE_STATE 1.
@export var bandera_persecucion: String = "arenque_casa_persecucion"
@export var peeko: NodePath
@export var celda_persecucion: Vector2i = Vector2i(9, 3)
@export var celda_persecucion_peeko: Vector2i = Vector2i(9, 6)

## Celda de Godot de la RUTA 104 a la que sale el jugador ((13,51) de Rubí).
const SALIDA_RUTA_104 := Vector2(15, 51)

signal zarpar_solicitado

var _celda_inicial: Vector2i
var _tipo_inicial: int
var _celda_inicial_peeko: Vector2i
var _tipo_inicial_peeko: int


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	_celda_inicial = coord
	_tipo_inicial = tipo_movimiento
	var npc_peeko := _peeko()
	if npc_peeko != null:
		_celda_inicial_peeko = npc_peeko.coord
		_tipo_inicial_peeko = npc_peeko.tipo_movimiento
	var mapa := _obtener_mapa_propio()
	if mapa != null:
		mapa.mapa_activado.connect(func(_por_warp: bool) -> void: preparar())
	preparar()


func _peeko() -> Node2D:
	return get_node_or_null(peeko) as Node2D if not peeko.is_empty() else null


## Route104_MrBrineysHouse_MapScript1_15BCB8.
func preparar() -> void:
	# _15BCD0: con el POKéNAV, el rival deja CIUDAD FÉRRICA (FLAG_HIDE_RIVAL_RUSTBORO).
	if SistemaGuardado.get_flag(Singleton.BANDERA_POKENAV):
		SistemaGuardado.set_flag(HistoriaFerrica.BANDERA_RIVAL, false)
	if _secuencia_activa:
		return
	var persecucion := SistemaGuardado.get_flag(bandera_persecucion)
	tipo_movimiento = TipoMovimientoNPC.CAMINAR_ABA_IZQ_ARR_DER if persecucion else _tipo_inicial
	EventoGuionizado.colocar(self, celda_persecucion if persecucion else _celda_inicial)
	var npc_peeko := _peeko()
	if npc_peeko != null:
		npc_peeko.tipo_movimiento = TipoMovimientoNPC.CAMINAR_IZQ_ARR_DER_ABA if persecucion else _tipo_inicial_peeko
		EventoGuionizado.colocar(npc_peeko, celda_persecucion_peeko if persecucion else _celda_inicial_peeko)


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
	var cuadro = nodo_administrador.cuadro_dialogo
	var zarpar := false
	var despedida := TEXTO_RECADOS
	if not SistemaGuardado.get_flag(BANDERA_PRESENTACION):
		SistemaGuardado.set_flag(BANDERA_PRESENTACION, true)
		cuadro.mostrar(tr(TEXTO_UN_SEGUNDO), true, false, _mensaje_terminado.emit)
		await _mensaje_terminado
		zarpar = await _preguntar_si_no(TEXTO_NAVEGAR)
	elif not SistemaGuardado.get_flag(BANDERA_CARTA):
		zarpar = await _preguntar_si_no(TEXTO_CARTA)
	elif not SistemaGuardado.get_flag(BANDERA_PIEZAS):
		zarpar = await _preguntar_si_no(TEXTO_PAQUETE)
	else:
		# message + multichoicedefault 21, 8, 14 (AZULIZA / SALIR).
		despedida = TEXTO_PEEKO_TE_DEBE
		zarpar = await _preguntar_opciones(TEXTO_ADONDE, PackedStringArray([tr(OPCION_AZULIZA), tr(OPCION_SALIR)]))
	cuadro.mostrar(tr(TEXTO_RUMBO if zarpar else despedida), true, false, _mensaje_terminado.emit)
	await _mensaje_terminado
	cuadro.cerrar()
	_bloquear_jugador(false)
	_secuencia_activa = false
	cambiar_estado(EstadoNPC.IDLE)
	if zarpar:
		if zarpar_solicitado.get_connections().is_empty():
			zarpar()
		else:
			zarpar_solicitado.emit()


## Route104_MrBrineysHouse_EventScript_15BDAB: VAR_BOARD_BRINEY_BOAT_ROUTE104_STATE 1,
## clearflag FLAG_HIDE_MR_BRINEY_ROUTE104, setflag FLAG_HIDE_MR_BRINEY_ROUTE104_HOUSE /
## FLAG_HIDE_PEEKO_BRINEY_HOUSE y warp MAP_ROUTE104, 255, 13, 51.
func zarpar() -> void:
	SistemaGuardado.set_flag(EventoBarcaArenque.BANDERA_EMBARCA, true)
	SistemaGuardado.set_flag(EventoBarcaArenque.BANDERA_ARENQUE_RUTA_104, true)
	SistemaGuardado.set_flag(EventoBarcaArenque.BANDERA_ARENQUE_CASA, false)
	if nodo_administrador == null or not nodo_administrador.has_method("conectar_escalera"):
		return
	if jugador:
		jugador.end_dialog()
		jugador.no_control = true
	nodo_administrador.conectar_escalera(EventoBarcaArenque.MAPA_RUTA_104, SALIDA_RUTA_104, Vector2.DOWN)


## Menú de dos opciones; la primera devuelve true. Cancelar equivale a la segunda.
func _preguntar_opciones(texto: String, opciones: PackedStringArray) -> bool:
	var dialogo: NinePatchRect = nodo_administrador.cuadro_dialogo
	dialogo.cerrar()
	dialogo.preguntaSiNo(tr(texto), opciones)
	while true:
		var datos: Array = await dialogo.comando_ejecutado
		if datos.size() >= 2 and str(datos[0]) == "respuesta_confirmacion":
			var parametros: Array = datos[1]
			return not parametros.is_empty() and str(parametros[0]) == "Y"
	return false
