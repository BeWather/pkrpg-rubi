@tool
## npc_duena_floristeria.gd
## Dueña de la FLORISTERÍA PITIMINÍ (pokeruby Route104_PrettyPetalFlowerShop_EventScript_15BE0B).
## - ON_TRANSITION: sin FLAG_MET_PRETTY_PETAL_SHOP_OWNER o sin la MEDALLA 3 se coloca
##   en `celda_sin_tienda`; con las dos, detrás del mostrador (su celda de la escena)
##   y atiende la tienda (FLAG_TEMP_1).
## - Sin tienda: saludo; la primera vez pregunta el nombre (y activa la bandera), las
##   siguientes solo si quieres saber de BAYAS; SÍ → explicación, NO → despedida.
## - Con tienda: `pokemartdecoration2` (EventScript_15BE7C), la tienda de PLANTAS de decoración.
##   Emite `hablado` como `npc_evento` y la atiende el `TiendaDecoracionNpc` de `Eventos`
##   (`RUTA104_FLORISTERIA`). Sin nadie escuchando solo saluda y se despide.
extends "res://scripts/npc/npc_dialogo_condicional.gd"

## Emitida al hablarle con la tienda abierta: la atiende el evento de la tienda.
signal hablado(npc: Node2D)

const TEXTO_HOLA: String = "FLORISTERIA_DUENA_HOLA"
const TEXTO_NOMBRE: String = "FLORISTERIA_DUENA_NOMBRE"
const TEXTO_BAYAS: String = "FLORISTERIA_DUENA_BAYAS"
const TEXTO_EXPLICA: String = "FLORISTERIA_DUENA_EXPLICA"
const TEXTO_FLORES: String = "FLORISTERIA_DUENA_FLORES"
const TEXTO_TIENDA: String = "FLORISTERIA_DUENA_TIENDA"
const TEXTO_VUELVE: String = "FLORISTERIA_DUENA_VUELVE"

## FLAG_MET_PRETTY_PETAL_SHOP_OWNER (la consulta también la florista de la RUTA 104).
@export var bandera_conocida: String = "floristeria_duena_conocida"
## FLAG_BADGE03_GET.
@export var medalla_tienda: int = 3
## setobjectxyperm 1, 4, 6.
@export var celda_sin_tienda: Vector2i = Vector2i(4, 6)

## FLAG_TEMP_1: la tienda está abierta en esta visita.
var tienda_abierta: bool = false
var _celda_tienda: Vector2i


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	_celda_tienda = coord
	var mapa := _obtener_mapa_propio()
	if mapa != null:
		mapa.mapa_activado.connect(func(_por_warp: bool) -> void: preparar())
	preparar()


## Route104_PrettyPetalFlowerShop_MapScript1_15BDEA.
func preparar() -> void:
	if _secuencia_activa:
		return
	tienda_abierta = SistemaGuardado.get_flag(bandera_conocida) \
		and SistemaGuardado.tiene_medalla(medalla_tienda - 1)
	EventoGuionizado.colocar(self, _celda_tienda if tienda_abierta else celda_sin_tienda)


func _procesar_interaccion() -> void:
	interrupcion_pendiente = false
	if _secuencia_activa:
		return
	if nodo_administrador == null or nodo_administrador.cuadro_dialogo == null:
		if jugador and jugador.has_method("esperar_dialogo"):
			jugador.esperar_dialogo(false)
		cambiar_estado(EstadoNPC.IDLE)
		return
	if tienda_abierta and not hablado.get_connections().is_empty():
		hablado.emit(self)
		return
	_conversar()


func _conversar() -> void:
	_secuencia_activa = true
	cambiar_estado(EstadoNPC.INTERACTING)
	mirar_jugador()  # faceplayer
	_bloquear_jugador(true)
	var cuadro = nodo_administrador.cuadro_dialogo
	if tienda_abierta:
		cuadro.mostrar(tr(TEXTO_TIENDA), true, false, _mensaje_terminado.emit)
		await _mensaje_terminado
		continuar_dialogo(tr(TEXTO_VUELVE), true, _mensaje_terminado.emit)
		await _mensaje_terminado
	else:
		cuadro.mostrar(tr(TEXTO_HOLA), true, false, _mensaje_terminado.emit)
		await _mensaje_terminado
		var pregunta := TEXTO_BAYAS
		if not SistemaGuardado.get_flag(bandera_conocida):
			SistemaGuardado.set_flag(bandera_conocida, true)
			pregunta = TEXTO_NOMBRE
		var respuesta := TEXTO_EXPLICA if await _preguntar_si_no(pregunta) else TEXTO_FLORES
		cuadro.mostrar(tr(respuesta), true, false, _mensaje_terminado.emit)
		await _mensaje_terminado
	cuadro.cerrar()
	_bloquear_jugador(false)
	_secuencia_activa = false
	cambiar_estado(EstadoNPC.IDLE)
