@tool
class_name CapasAgua
extends Node2D

## Capas de efectos de agua de un mapa (reflejos, ondas, nubes del clima y sombra
## de los puentes) en el orden de dibujo correcto.
##
## Uso: instanciar `res://escenas/mapas/capas_agua.tscn` como hermano JUSTO
## DESPUÉS de la TileMapLayer del agua (`Agua`) y antes de `Suelo`, en (0, 0);
## activar en el inspector las piezas que use el mapa y, si tiene puentes sobre
## agua, añadirle una TileMapLayer hija `SombraPuente` (mismo tile_set que `Agua`)
## y pintar en ella la sombra bajo los puentes.
##
## Orden de dibujo resultante (siempre el mismo, aunque se reordene en el árbol):
##   [BackBufferAgua] → [AnclaClimaMundo] → [SombraPuente] → [AguaFX]
## - BackBufferAgua (BackBufferCopy, modo viewport) y AnclaClimaMundo (Node2D
##   donde ControladorClimaOverworld instancia las nubes) son hijos INTERNOS
##   creados en código (delante de los hijos normales): no aparecen en el árbol
##   de escena y el usuario no puede desordenarlos. El backbuffer solo se crea si
##   alguna pieza activa lo necesita (`necesita_backbuffer()`).
## - SombraPuente: hijo TileMapLayer normal (lo pinta el usuario). La sombra está
##   activa si la capa tiene celdas. `capa_sombra_puente` permite apuntar a otra
##   TileMapLayer hija; si está vacío se usa la primera TileMapLayer hija.
## - AguaFX (ReflexionesAgua): si hay un hijo ReflexionesAgua se usa ese, con su
##   propia configuración (modo, offset, tp_tile_data_map…); en ejecución se mueve
##   al final de los hijos para dibujarse tras la sombra. Si no hay ninguno y
##   `reflejos` está activo, se crea uno INTERNO (detrás de los hijos) con los
##   valores por defecto de ReflexionesAgua (FIJO, offset -2, capa de datos 0 del
##   mapa), que son los que usan los mapas actuales.
##
## Fuente única de verdad: MapaConfiguracion.obtener_capas_agua() y sus
## obtener_ancla_clima_mundo/obtener_backbuffer/obtener_capa_sombra_puente/
## obtener_reflexiones delegan aquí. Avisos del editor: ValidadorCapasAgua.

const NOMBRE_BACKBUFFER := &"BackBufferAgua"
const NOMBRE_ANCLA := &"AnclaClimaMundo"
const NOMBRE_REFLEXIONES := &"AguaFX"

## AguaFX: reflejos de los personajes sobre las celdas REFLEJO (y silueta sobre
## los puentes) y ondas de AGUA_SALPICA. Los mares que solo llevan SURF (con su
## propia capa de oleaje animado) no lo necesitan.
@export var reflejos: bool = true:
	set(valor):
		reflejos = valor
		_al_cambiar_configuracion()

## Reflejo opaco que lee el agua del backbuffer y tapa lo dibujado entre el agua
## y AguaFX (nubes, sombra del puente), como en el GBA. Crea el backbuffer.
@export var reflejo_opaco_sobre_efectos: bool = false:
	set(valor):
		reflejo_opaco_sobre_efectos = valor
		_al_cambiar_configuracion()

## Ancla del canal de mundo del clima (nubes entre el agua y el suelo). Crea el
## backbuffer: las nubes mezclan con el agua copiada (shader `nube_clima`).
@export var canal_clima_mundo: bool = false:
	set(valor):
		canal_clima_mundo = valor
		_al_cambiar_configuracion()

## TileMapLayer hija con la sombra del agua bajo los puentes. Vacío = la primera
## TileMapLayer hija (normalmente `SombraPuente`).
@export var capa_sombra_puente: TileMapLayer = null:
	set(valor):
		capa_sombra_puente = valor
		_al_cambiar_configuracion()

var _backbuffer: BackBufferCopy = null
var _ancla: Node2D = null
var _reflexiones_internas: ReflexionesAgua = null
var _piezas_sincronizadas: bool = false


func _enter_tree() -> void:
	# Crear las piezas internas aquí (y no en _ready) permite que existan antes
	# del _ready de los hijos y del mapa; Node admite añadir hijos en enter_tree.
	_sincronizar_piezas()


func _ready() -> void:
	_sincronizar_piezas()
	if Engine.is_editor_hint():
		call_deferred("update_configuration_warnings")
	else:
		ordenar_hijos()


func _notification(what: int) -> void:
	if what != NOTIFICATION_CHILD_ORDER_CHANGED:
		return
	if Engine.is_editor_hint():
		call_deferred("update_configuration_warnings")
	elif _piezas_sincronizadas:
		# Un ReflexionesAgua hijo añadido o quitado en ejecución sustituye o
		# recupera el AguaFX interno (diferido: no tocar hijos en plena adición).
		call_deferred("_sincronizar_piezas")


func _get_configuration_warnings() -> PackedStringArray:
	return ValidadorCapasAgua.validar_capas_agua(self)


# ---------------------------------------------------------------------------
# API
# ---------------------------------------------------------------------------

## true si alguna pieza activa necesita la copia del agua (BackBufferCopy).
func necesita_backbuffer() -> bool:
	return reflejo_opaco_sobre_efectos or canal_clima_mundo


## BackBufferCopy interno (copia solo el agua), o null si ninguna pieza lo usa.
func obtener_backbuffer() -> BackBufferCopy:
	_asegurar_piezas()
	return _backbuffer if is_instance_valid(_backbuffer) else null


## Ancla del canal de mundo del clima, o null si `canal_clima_mundo` está apagado.
func obtener_ancla_clima_mundo() -> Node2D:
	_asegurar_piezas()
	return _ancla if is_instance_valid(_ancla) else null


## TileMapLayer de sombra de los puentes (export o primera TileMapLayer hija), o
## null. Puede estar vacía: ver `sombra_activa()`.
func obtener_capa_sombra_puente() -> TileMapLayer:
	if is_instance_valid(capa_sombra_puente):
		return capa_sombra_puente
	for hijo: Node in get_children():
		if hijo is TileMapLayer:
			return hijo as TileMapLayer
	return null


## true si hay capa de sombra con alguna celda pintada.
func sombra_activa() -> bool:
	var capa := obtener_capa_sombra_puente()
	return capa != null and not capa.get_used_cells().is_empty()


## AguaFX activo (hijo ReflexionesAgua o el interno), o null si `reflejos` está
## apagado.
func obtener_reflexiones() -> ReflexionesAgua:
	if not reflejos:
		return null
	var hija := obtener_reflexiones_hija()
	if hija != null:
		return hija
	_asegurar_piezas()
	return _reflexiones_internas if is_instance_valid(_reflexiones_internas) else null


## Primer hijo (no interno) ReflexionesAgua, o null.
func obtener_reflexiones_hija() -> ReflexionesAgua:
	for hijo: Node in get_children():
		if hijo is ReflexionesAgua:
			return hijo as ReflexionesAgua
	return null


## true si los reflejos deben leer el agua del backbuffer (reflejo opaco).
func usa_reflejo_opaco() -> bool:
	return reflejo_opaco_sobre_efectos and backbuffer_activo(obtener_backbuffer())


## TileMapLayer del agua: el hermano inmediatamente anterior, o null.
func obtener_capa_agua() -> TileMapLayer:
	var padre := get_parent()
	if padre == null:
		return null
	var indice: int = get_index()
	if indice <= 0:
		return null
	return padre.get_child(indice - 1) as TileMapLayer


## Coloca las TileMapLayer hijas antes de los ReflexionesAgua hijos (la sombra se
## dibuja antes que los reflejos). Se llama en _ready en ejecución.
func ordenar_hijos() -> void:
	for hijo: Node in get_children():
		if hijo is ReflexionesAgua:
			move_child(hijo, get_child_count() - 1)


static func backbuffer_activo(copia: BackBufferCopy) -> bool:
	return copia != null and is_instance_valid(copia) and copia.visible \
		and copia.copy_mode != BackBufferCopy.COPY_MODE_DISABLED


# ---------------------------------------------------------------------------
# Piezas internas
# ---------------------------------------------------------------------------

func _al_cambiar_configuracion() -> void:
	if _piezas_sincronizadas:
		_sincronizar_piezas()
	if Engine.is_editor_hint() and is_inside_tree():
		update_configuration_warnings()


func _asegurar_piezas() -> void:
	if not _piezas_sincronizadas:
		_sincronizar_piezas()


## Crea o quita las piezas internas según los exports, en orden fijo:
## backbuffer → ancla (delante de los hijos) … AguaFX interno (detrás).
func _sincronizar_piezas() -> void:
	_piezas_sincronizadas = true
	if necesita_backbuffer():
		if not is_instance_valid(_backbuffer):
			_backbuffer = BackBufferCopy.new()
			_backbuffer.name = NOMBRE_BACKBUFFER
			_backbuffer.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
			add_child(_backbuffer, false, INTERNAL_MODE_FRONT)
	else:
		_backbuffer = _quitar_pieza(_backbuffer) as BackBufferCopy

	if canal_clima_mundo:
		if not is_instance_valid(_ancla):
			_ancla = Node2D.new()
			_ancla.name = NOMBRE_ANCLA
			add_child(_ancla, false, INTERNAL_MODE_FRONT)
	else:
		_ancla = _quitar_pieza(_ancla) as Node2D

	# El backbuffer siempre el primero (índice relativo a los internos delanteros).
	if is_instance_valid(_backbuffer) and _backbuffer.get_index(true) != 0:
		move_child(_backbuffer, 0)

	# AguaFX interno: solo en ejecución (ReflexionesAgua no es @tool) y solo si no
	# hay un ReflexionesAgua hijo con configuración propia.
	var hija := obtener_reflexiones_hija()
	var quiere_interno: bool = reflejos and hija == null and not Engine.is_editor_hint()
	if quiere_interno and not is_instance_valid(_reflexiones_internas):
		_reflexiones_internas = ReflexionesAgua.new()
		_reflexiones_internas.name = NOMBRE_REFLEXIONES
		add_child(_reflexiones_internas, false, INTERNAL_MODE_BACK)
	elif not quiere_interno:
		_reflexiones_internas = _quitar_pieza(_reflexiones_internas) as ReflexionesAgua

	# Con `reflejos` apagado, un AguaFX hijo no dibuja ni procesa (solo en
	# ejecución: en el editor cambiar `visible` se guardaría en la escena).
	if hija != null and not Engine.is_editor_hint():
		hija.visible = reflejos
		hija.process_mode = Node.PROCESS_MODE_INHERIT if reflejos else Node.PROCESS_MODE_DISABLED


func _quitar_pieza(pieza: Node) -> Node:
	if is_instance_valid(pieza):
		if pieza.get_parent() == self:
			remove_child(pieza)
		pieza.queue_free()
	return null
