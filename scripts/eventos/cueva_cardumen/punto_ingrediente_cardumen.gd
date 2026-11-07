## punto_ingrediente_cardumen.gd
## Montón de SAL CARDUMEN o CONCHA CARDUMEN de la cueva (pokeruby bg_event de ShoalCave_*: `giveitem
## ITEM_SHOAL_SALT/SHELL`, `setmetatile` y FLAG_HIDE_TOOK_SHOAL_*). Cuelga de `NPCs` como un ItemOverworld oculto:
## AdministradorMapa lo encuentra por `coord_celda` y llama a `evento_accion()` al mirarlo y pulsar A.
##
## - Disponible = no cogido hoy (HistoriaCuevaCardumen) y, en las dos salas con marea, la sal solo con marea baja
##   (`MapScript1_15E1B9`: `goto_if_set FLAG_SYS_SHOAL_TIDE`). Con el montón grande dibujado en la capa `Ingredientes`
##   (metatiles 0x358 sal y 0x359 concha, `setmetatile ..., 1`) la celda es impasable; cogido, vuelve al montón
##   pequeño del layout y se puede pisar (`bloquea_paso`).
## - Disponible: «¡Obtuvo X!», fanfarria y «puso X en el bolsillo»; con la mochila llena solo MOCHILA_LLENA_REGALO
##   (Common_EventScript_ShowBagIsFull), sin marcar nada. Ya cogido: «Aquí había algo de SAL CARDUMEN, pero ahora no
##   queda nada.» Con la sal oculta por la marea alta no pasa nada.
## El resto del flujo (bloqueo del jugador, fanfarria) es el de ItemOverworld.gd.
@tool
class_name PuntoIngredienteCardumen
extends "res://scripts/ItemOverworld.gd"

const TEXTO_OBTENIDO: String = "OBJETO_OBTENIDO"
const TEXTO_MOCHILA_LLENA: String = "MOCHILA_LLENA_REGALO"
const TEXTO_SAL_VACIO: String = "CUEVA_CARDUMEN_SAL_VACIO"
const TEXTO_CONCHA_VACIO: String = "CUEVA_CARDUMEN_CONCHA_VACIO"
## Fuente de tileset_cuevas.tres y celdas de los metatiles grandes (0x358 y 0x359 = 856 y 857, en la franja de
## metatiles de la cueva: (n - 512) % 8, (n - 512) / 8).
const FUENTE_CUEVAS: int = 1
const CELDA_SAL_GRANDE: Vector2i = Vector2i(0, 43)
const CELDA_CONCHA_GRANDE: Vector2i = Vector2i(1, 43)

## true = SAL CARDUMEN, false = CONCHA CARDUMEN.
@export var es_sal: bool = true
## Número del ingrediente (1-4), el de FLAG_HIDE_TOOK_SHOAL_*_n.
@export_range(1, 4) var numero: int = 1
## La sal de la sala de entrada y de la interior no está con marea alta.
@export var solo_marea_baja: bool = false
## TileMapLayer (tileset_cuevas) donde se dibuja el montón grande.
@export var capa_visual: NodePath = ^"../../Ingredientes"


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	# ItemOverworld se oculta al estar «recogido»; aquí un montón vacío sigue siendo interactuable.
	visible = true
	var mapa := _mapa()
	if mapa != null and mapa.has_signal("mapa_activado"):
		mapa.mapa_activado.connect(func(_por_warp: bool) -> void: actualizar_visual())
	actualizar_visual()


func tipo() -> String:
	return HistoriaCuevaCardumen.SAL if es_sal else HistoriaCuevaCardumen.CONCHA


## ¿Está el montón grande ahora mismo?
func disponible() -> bool:
	return not HistoriaCuevaCardumen.recogido(tipo(), numero) and not _oculto_por_marea()


func _oculto_por_marea() -> bool:
	return solo_marea_baja and MareaCueva.marea_actual()


## Un montón grande es una celda impasable; sin él se puede pisar.
func bloquea_paso() -> bool:
	return disponible()


func _ya_recogido() -> bool:
	return HistoriaCuevaCardumen.recogido(tipo(), numero)


func _set_bandera(valor: bool) -> void:
	HistoriaCuevaCardumen.marcar_recogido(tipo(), numero, valor)


## Dibuja (o quita) el montón grande en la capa `Ingredientes`.
func actualizar_visual() -> void:
	var capa := get_node_or_null(capa_visual) as TileMapLayer
	if capa == null:
		return
	if disponible():
		capa.set_cell(coord, FUENTE_CUEVAS, CELDA_SAL_GRANDE if es_sal else CELDA_CONCHA_GRANDE)
	else:
		capa.erase_cell(coord)


func evento_accion() -> void:
	if _en_proceso or _oculto_por_marea():
		return
	if _ya_recogido():
		var admin := _iniciar_interaccion()
		if admin != null:
			admin.cuadro_dialogo.mostrar(tr(TEXTO_SAL_VACIO if es_sal else TEXTO_CONCHA_VACIO), true, true, _liberar_jugador)
		return
	recoger_item()


## `giveitem` + `setmetatile` + `setflag`; con la mochila llena, solo el aviso.
func recoger_item() -> void:
	if _en_proceso or _datos_objeto_validos().is_empty():
		return
	var admin := _iniciar_interaccion()
	if admin == null:
		return
	SistemaGuardado.inicializar_mochila_estructura()
	var metas: Dictionary = SistemaGuardado.dar_objeto_jugador(objeto_a_entregar, cantidad)
	if not bool(metas.get("exito", false)):
		admin.cuadro_dialogo.mostrar(tr(TEXTO_MOCHILA_LLENA), true, true, _liberar_jugador)
		return
	_set_bandera(true)
	actualizar_visual()
	var datos: Dictionary = SistemaGuardado.obtener_datos_objeto_completos(objeto_a_entregar)
	var mensaje: String = tr(TEXTO_OBTENIDO).replace("{key}", str(datos.get("nombre", objeto_a_entregar)))
	# Sin esperar tecla: al acabar el texto suena la fanfarria y sigue el bolsillo.
	admin.cuadro_dialogo.mostrar(mensaje, false, false, _tras_obtener.bind(metas))


func _tras_obtener(metas: Dictionary) -> void:
	if con_fanfarrias:
		await _reproducir_fanfarria_objeto()
	if not _interaccion_vigente():
		_liberar_jugador()
		return
	var datos: Dictionary = SistemaGuardado.obtener_datos_objeto_completos(objeto_a_entregar)
	var mensaje: String = tr(ID_TEXTO_GUARDADO)
	mensaje = mensaje.replace("{key}", str(datos.get("nombre", objeto_a_entregar)))
	mensaje = mensaje.replace("{bname}", str(metas.get("bolsillo_nombre", "")).to_upper())
	var admin := _obtener_administrador()
	if not is_instance_valid(admin) or admin.get("cuadro_dialogo") == null:
		_liberar_jugador()
		return
	admin.cuadro_dialogo.mostrar(mensaje, true, true, _liberar_jugador)


## Bloquea al jugador y devuelve el AdministradorMapa; null (sin bloquear) si no hay cuadro de diálogo.
func _iniciar_interaccion() -> Node:
	var admin: Node = _obtener_administrador()
	if admin == null or admin.get("cuadro_dialogo") == null:
		push_warning("[PuntoIngredienteCardumen] '%s': AdministradorMapa/cuadro de diálogo no disponible." % id_item)
		return null
	_en_proceso = true
	_admin_interaccion = admin
	if admin.get("jugador"):
		_control_previo = bool(admin.jugador.no_control)
	Singleton.mantener_pausa(&"item_overworld", true)
	if admin.get("jugador"):
		admin.jugador.no_control = true
	return admin


func _mapa() -> Node:
	var nodo: Node = get_parent()
	while nodo != null and not nodo is MapaConfiguracion:
		nodo = nodo.get_parent()
	return nodo
