## tienda_decoracion_npc.gd
## Dependiente de una TIENDA DE DECORACIÓN de Rubí (`pokemartdecoration`), dirigido por datos: el NPC
## se indica con `npc` (un npc_evento) y la lista que vende con `id_tienda`, una clave de
## `BaseDatos/tiendas_decoracion.json` (`DatosTiendaDecoracion`). Se cuelga en `Eventos` de la
## escena, como `IntercambioNpc`.
##
## Guion (pokeruby `FortreeCity_DecorationShop_EventScript_ClerkDesks` / `ClerkChairs`): lock +
## faceplayer; `message Text_HowMayIServeYou` + `waitmessage` («¡Hola! ¿En qué puedo ayudarte?», sin
## esperar botón); `pokemartdecoration <lista>` (la pantalla `CompraDecoracionUI`) y, al salir,
## `msgbox Text_PleaseComeAgain` («¡Vuelve cuando quieras!»). Lo que se compra va al inventario de
## decoraciones del PC (`SistemaBasesSecretas`), no a la mochila.
##
## El dependiente está detrás de un MOSTRADOR: el AdministradorMapa resuelve la interacción
## «a través» del mostrador y la cámara se desplaza al abrir la pantalla igual que en la tienda de
## objetos (`vendedor_pokeshop.gd`).
extends EventoGuionizado
class_name TiendaDecoracionNpc

const MOTIVO_PAUSA: StringName = &"tienda_decoracion_npc"
const ESCENA_COMPRA: String = "res://UI/comprar/comprar_decoracion.tscn"

## Resultados de `atender`.
const ATENDIDA: StringName = &"atendida"
const SIN_DATOS: StringName = &"sin_datos"
const SIN_CONDICION: StringName = &"sin_condicion"

## Quien habla: el NPC (un npc_evento) detrás del mostrador.
@export var npc: NodePath
## Clave de `tiendas_decoracion.json` ("ARBORADA_MESAS"...).
@export var id_tienda: String = ""
## Saludo propio (clave de dialogos.csv) en lugar de `Text_HowMayIServeYou`; vacío = el estándar. La
## florista de la RUTA 104 dice `Text_PlayerWhatCanIDoForYou`.
@export var id_texto_saludo: String = ""
## `goto_if_unset <bandera>` antes de atender (formato de `CondicionTexto`); vacío = siempre atiende.
## El DecorClerk de PORTUAL exige FLAG_RECEIVED_SECRET_POWER.
@export var condicion: String = ""
## Texto (clave de dialogos.csv) cuando no se cumple `condicion`: el msgbox al que salta el goto.
@export var id_texto_sin_condicion: String = ""

## Sustituye al AdministradorMapa de la raíz del árbol (tests).
var administrador: Node = null
## Si es válido sustituye a la pantalla de compra: se llama con la lista de ids y se espera a que
## termine (tests).
var pantalla_compra: Callable = Callable()


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var hablante := get_node_or_null(npc)
	if hablante != null and hablante.has_signal("hablado"):
		hablante.hablado.connect(_on_hablado)


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


## lock + faceplayer al hablarle al dependiente.
func _on_hablado(hablante: Node2D) -> void:
	var administrador_npc: Node = hablante.nodo_administrador if hablante.nodo_administrador != null \
			else _administrador()
	if _en_curso or not comenzar(administrador_npc):
		if not _en_curso and hablante.jugador and hablante.jugador.has_method("esperar_dialogo"):
			hablante.jugador.esperar_dialogo(false)
		return
	hablante.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	hablante.mirar_jugador()
	await atender(hablante)
	terminar(false, [hablante])


## Todo el guion del dependiente. Devuelve ATENDIDA, SIN_CONDICION (no cumple `condicion`) o SIN_DATOS
## (tienda sin lista).
func atender(hablante: Node2D = null) -> StringName:
	if not condicion.is_empty() and not CondicionTexto.cumple(condicion):
		if not id_texto_sin_condicion.is_empty():
			await mensaje(id_texto_sin_condicion)
		return SIN_CONDICION
	var ids: Array[int] = DatosTiendaDecoracion.decoraciones(id_tienda)
	if ids.is_empty():
		push_warning("[TiendaDecoracionNpc] Tienda '%s' sin decoraciones" % id_tienda)
		return SIN_DATOS
	await _saludar()
	await _abrir_pantalla_compra(ids, hablante)
	await mensaje(DatosTiendaDecoracion.TEXTO_DESPEDIDA)  # Text_PleaseComeAgain
	return ATENDIDA


## `message` + `waitmessage`: el texto se escribe y el guion sigue sin esperar el botón al final (los \w
## internos sí esperan).
func _saludar() -> void:
	var saludo: String = id_texto_saludo if not id_texto_saludo.is_empty() else DatosTiendaDecoracion.TEXTO_SALUDO
	admin.cuadro_dialogo.mostrar(tr(saludo), false, false, _mensaje_terminado.emit, true)
	await _mensaje_terminado


## `pokemartdecoration`: fundido, la pantalla de compra con la cámara desplazada y fundido de vuelta
## hasta que se cierra.
func _abrir_pantalla_compra(ids: Array[int], hablante: Node2D) -> void:
	if pantalla_compra.is_valid():
		await pantalla_compra.call(ids)
		return
	var capa := get_tree().root.get_node_or_null("AdministradorMapa/Menu")
	if capa == null:
		return
	admin.cuadro_dialogo.cerrar()
	await Singleton.transicion("oscurecer")
	var camara := _desplazar_camara(hablante)
	var pantalla := (load(ESCENA_COMPRA) as PackedScene).instantiate() as CompraDecoracionUI
	pantalla.configurar_tienda(ids, self)
	capa.add_child(pantalla)
	Singleton.transicion("aclarar")
	await pantalla.compra_cerrada
	if is_instance_valid(camara):
		camara.quitar_posicion_fija()


## Mismo ajuste visual que `vendedor_pokeshop.gd` según el lado del mostrador por el que se habla.
func _desplazar_camara(hablante: Node2D) -> Camera2D:
	if hablante == null or hablante.nodo_administrador == null \
			or not hablante.nodo_administrador.has_method("celda_frente_jugador"):
		return null
	var desplazamiento := Vector2.ZERO
	match hablante.nodo_administrador.celda_frente_jugador() - hablante.coord_celda:
		Vector2i.RIGHT:
			desplazamiento = Vector2(48, 7)
		Vector2i.DOWN:
			desplazamiento = Vector2(64, -9)
		Vector2i.UP:
			desplazamiento = Vector2(64, 23)
		Vector2i.LEFT:
			desplazamiento = Vector2(80, 7)
	var jugador: Node = admin.get("jugador")
	if desplazamiento == Vector2.ZERO and jugador != null:
		desplazamiento = Vector2(64, 7) + Vector2(jugador.facing_direction) * 16
	var camara: Camera2D = jugador.get_node_or_null("Camera2D") if jugador != null else null
	if camara == null:
		camara = get_viewport().get_camera_2d()
	if desplazamiento == Vector2.ZERO or camara == null or not camara.has_method("establecer_posicion_fija"):
		return null
	camara.establecer_posicion_fija(camara.global_position + desplazamiento)
	return camara
