class_name ControladorClimaOverworld
extends CanvasLayer

signal clima_cambiado(clima_id: StringName)
signal transicion_iniciada(origen_id: StringName, destino_id: StringName)

const CLIMA_NINGUNO: DefinicionClima = preload("res://recursos/clima/ninguno.tres")
## Capa de canvas del clima (y de la oscuridad de cueva): sobre el mapa, bajo
## CapaMovCampo del jugador (4: franja y Pokémon de los movimientos de campo)
## y bajo Menu (5: diálogos, menú de pausa y Telon).
const CAPA_CANVAS := 3

class EstadoVisual extends RefCounted:
	var raiz: Control
	var tinte: ColorRect
	var copia_pantalla: BackBufferCopy
	var efecto: EfectoClimaBase
	## Canal de mundo (bajo el ancla del mapa actual); null si el clima no tiene
	## `escena_mundo` o no hay ancla.
	var mundo: EfectoClimaMundoBase
	var definicion: DefinicionClima
	var intensidad: float = 1.0
	var factor: float = 1.0

var _actual: EstadoVisual = null
var _objetivo: EstadoVisual = null
var _definicion_actual: DefinicionClima = CLIMA_NINGUNO
var _definicion_objetivo: DefinicionClima = null
var _intensidad_actual: float = 1.0
var _firma_actual: Array = []
var _tween_activo: Tween = null
var _token_solicitud: int = 0
var _transicionando: bool = false
var _destellos_habilitados: bool = true
## Nodo `AnclaClimaMundo` del mapa actual (lo fija el administrador antes de
## aplicar el clima del mapa). Sin ancla el canal de mundo no se instancia.
var _ancla_mundo: Node2D = null


func _ready() -> void:
	layer = CAPA_CANVAS
	var viewport: Viewport = get_viewport()
	if not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)


func aplicar_inmediato(definicion: DefinicionClima, intensidad: float = -1.0) -> void:
	var nueva_definicion: DefinicionClima = _normalizar_definicion(definicion)
	var nueva_intensidad: float = nueva_definicion.intensidad_normalizada(intensidad)
	if (
		not _transicionando
		and _coincide_definicion(nueva_definicion)
		and is_equal_approx(nueva_intensidad, _intensidad_actual)
	):
		return
	_token_solicitud += 1
	_cancelar_tween()
	_liberar_estado(_actual)
	_liberar_estado(_objetivo)
	_actual = null
	_objetivo = null
	_definicion_objetivo = null
	_transicionando = false
	_definicion_actual = nueva_definicion
	_firma_actual = nueva_definicion.obtener_firma_visual()
	_intensidad_actual = nueva_intensidad
	if not _definicion_actual.es_sin_clima():
		_actual = _crear_estado(_definicion_actual, _intensidad_actual, 1.0)
	clima_cambiado.emit(_definicion_actual.id)


func transicionar_a(definicion: DefinicionClima, duracion: float = 1.0, intensidad: float = -1.0) -> void:
	var destino: DefinicionClima = _normalizar_definicion(definicion)
	var intensidad_destino: float = destino.intensidad_normalizada(intensidad)
	if duracion <= 0.0:
		aplicar_inmediato(destino, intensidad_destino)
		return
	if not _transicionando and _coincide_definicion(destino) and is_equal_approx(intensidad_destino, _intensidad_actual):
		return

	_token_solicitud += 1
	var token: int = _token_solicitud
	_rebasar_transicion_interrumpida()
	_definicion_objetivo = destino
	_objetivo = null if destino.es_sin_clima() else _crear_estado(destino, intensidad_destino, 0.0)
	_transicionando = true
	transicion_iniciada.emit(_definicion_actual.id, destino.id)

	_tween_activo = create_tween()
	_tween_activo.set_parallel(true)
	if _actual != null:
		_tween_activo.tween_method(Callable(self, "_set_factor_actual"), _actual.factor, 0.0, duracion)
	if _objetivo != null:
		_tween_activo.tween_method(Callable(self, "_set_factor_objetivo"), 0.0, 1.0, duracion)
	_tween_activo.finished.connect(_finalizar_transicion.bind(token, intensidad_destino), CONNECT_ONE_SHOT)


func limpiar_inmediato() -> void:
	aplicar_inmediato(CLIMA_NINGUNO)


func obtener_clima_actual_id() -> StringName:
	return _definicion_actual.id


func obtener_clima_objetivo_id() -> StringName:
	return _definicion_objetivo.id if _definicion_objetivo != null else _definicion_actual.id


func esta_transicionando() -> bool:
	return _transicionando


func obtener_token_solicitud() -> int:
	return _token_solicitud


## Estados con algún efecto vivo (de pantalla o de mundo). Nunca más de 2.
func obtener_cantidad_efectos_vivos() -> int:
	var cantidad: int = 0
	if _estado_tiene_efecto(_actual):
		cantidad += 1
	if _estado_tiene_efecto(_objetivo):
		cantidad += 1
	return cantidad


## Efectos de mundo vivos (como mucho uno por estado).
func obtener_cantidad_efectos_mundo_vivos() -> int:
	var cantidad: int = 0
	if _estado_tiene_mundo(_actual):
		cantidad += 1
	if _estado_tiene_mundo(_objetivo):
		cantidad += 1
	return cantidad


## Fija el ancla del canal de mundo. Al cambiar, los efectos de mundo del ancla
## anterior se liberan y los estados vivos que tengan `escena_mundo` se recrean
## bajo la nueva ancla con su factor de mezcla actual. `null` = sin canal de mundo.
func configurar_ancla_mundo(ancla: Node2D) -> void:
	var anterior_valida: bool = _ancla_mundo != null and is_instance_valid(_ancla_mundo)
	if ancla == null and not anterior_valida:
		_ancla_mundo = null
		return
	if anterior_valida and ancla == _ancla_mundo:
		return
	_liberar_mundo_estado(_actual)
	_liberar_mundo_estado(_objetivo)
	_ancla_mundo = ancla
	_crear_mundo_estado(_actual)
	_crear_mundo_estado(_objetivo)


func obtener_ancla_mundo() -> Node2D:
	if _ancla_mundo != null and not is_instance_valid(_ancla_mundo):
		_ancla_mundo = null
	return _ancla_mundo


func configurar_destellos_habilitados(habilitados: bool) -> void:
	_destellos_habilitados = habilitados
	_configurar_destellos_estado(_actual, habilitados)
	_configurar_destellos_estado(_objetivo, habilitados)


func _crear_estado(definicion: DefinicionClima, intensidad: float, factor: float) -> EstadoVisual:
	var estado := EstadoVisual.new()
	estado.definicion = definicion
	estado.intensidad = intensidad
	estado.factor = factor
	estado.raiz = Control.new()
	estado.raiz.name = "Clima_%s" % String(definicion.id)
	estado.raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(estado.raiz)

	# El tinte va antes del efecto: las gotas de lluvia no se oscurecen (en el GBA
	# los sprites del clima no pasan por la gamma de paleta del mundo).
	estado.tinte = ColorRect.new()
	estado.tinte.name = "Tinte"
	estado.tinte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if definicion.modo_tinte == DefinicionClima.ModoTinte.MULTIPLICAR:
		# MUL desde este CanvasLayer multiplica lo ya dibujado en el render target
		# del viewport (el mundo, que está en capas inferiores).
		var material := CanvasItemMaterial.new()
		material.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
		estado.tinte.material = material
	estado.raiz.add_child(estado.tinte)

	if definicion.requiere_copia_pantalla:
		estado.copia_pantalla = BackBufferCopy.new()
		estado.copia_pantalla.name = "BackBufferClimaPantalla"
		estado.copia_pantalla.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
		estado.raiz.add_child(estado.copia_pantalla)

	if definicion.escena_efecto != null:
		var nodo_efecto: Node = definicion.escena_efecto.instantiate()
		if nodo_efecto is EfectoClimaBase:
			estado.efecto = nodo_efecto as EfectoClimaBase
			estado.raiz.add_child(estado.efecto)
		else:
			push_error("[CLIMA] La escena de '%s' no hereda EfectoClimaBase" % String(definicion.id))
			nodo_efecto.queue_free()

	_crear_mundo_estado(estado)
	_actualizar_area_estado(estado, _obtener_area_visible())
	_set_factor_estado(estado, factor)
	_configurar_destellos_estado(estado, _destellos_habilitados)
	return estado


func _set_factor_actual(factor: float) -> void:
	_set_factor_estado(_actual, factor)


func _set_factor_objetivo(factor: float) -> void:
	_set_factor_estado(_objetivo, factor)


func _set_factor_estado(estado: EstadoVisual, factor: float) -> void:
	if estado == null:
		return
	estado.factor = clampf(factor, 0.0, 1.0)
	if estado.tinte != null:
		estado.tinte.color = calcular_color_tinte(estado.definicion, estado.factor * estado.intensidad)
	if estado.efecto != null:
		estado.efecto.set_factor_mezcla(estado.factor)
	if estado.mundo != null and is_instance_valid(estado.mundo):
		estado.mundo.set_factor_mezcla(estado.factor)


## Color del ColorRect de tinte para una mezcla `peso` (factor × intensidad).
## VELO: el alfa del tinte escala con el peso. MULTIPLICAR: blanco (neutro) hacia
## el tinte opaco, sin alfa.
static func calcular_color_tinte(definicion: DefinicionClima, peso: float) -> Color:
	var mezcla: float = clampf(peso, 0.0, 1.0)
	if definicion.modo_tinte == DefinicionClima.ModoTinte.MULTIPLICAR:
		var opaco := Color(definicion.tinte.r, definicion.tinte.g, definicion.tinte.b, 1.0)
		return Color.WHITE.lerp(opaco, mezcla)
	var color: Color = definicion.tinte
	color.a *= mezcla
	return color


func _finalizar_transicion(token: int, intensidad_destino: float) -> void:
	if token != _token_solicitud:
		return
	_liberar_estado(_actual)
	_actual = _objetivo
	_objetivo = null
	_definicion_actual = _definicion_objetivo if _definicion_objetivo != null else CLIMA_NINGUNO
	_firma_actual = _definicion_actual.obtener_firma_visual()
	_definicion_objetivo = null
	_intensidad_actual = intensidad_destino
	_transicionando = false
	_tween_activo = null
	if _actual != null:
		_set_factor_estado(_actual, 1.0)
	clima_cambiado.emit(_definicion_actual.id)


func _rebasar_transicion_interrumpida() -> void:
	_cancelar_tween()
	if not _transicionando:
		return
	var conservar_objetivo: bool = _objetivo != null and (_actual == null or _objetivo.factor > _actual.factor)
	if conservar_objetivo:
		_liberar_estado(_actual)
		_actual = _objetivo
		_definicion_actual = _actual.definicion
		_firma_actual = _definicion_actual.obtener_firma_visual()
		_intensidad_actual = _actual.intensidad
	else:
		_liberar_estado(_objetivo)
	_objetivo = null
	_definicion_objetivo = null
	_transicionando = false


func _cancelar_tween() -> void:
	if _tween_activo != null and _tween_activo.is_valid():
		_tween_activo.kill()
	_tween_activo = null


func _liberar_estado(estado: EstadoVisual) -> void:
	if estado == null:
		return
	if estado.efecto != null and is_instance_valid(estado.efecto):
		estado.efecto.detener()
	_liberar_mundo_estado(estado)
	if estado.raiz != null and is_instance_valid(estado.raiz):
		estado.raiz.visible = false
		estado.raiz.queue_free()


func _estado_tiene_efecto(estado: EstadoVisual) -> bool:
	return estado != null and (estado.efecto != null or _estado_tiene_mundo(estado))


## El efecto de mundo puede haberse liberado junto con su mapa (interiores).
func _estado_tiene_mundo(estado: EstadoVisual) -> bool:
	return estado != null and estado.mundo != null and is_instance_valid(estado.mundo)


## Instancia `escena_mundo` del estado bajo el ancla actual, con su intensidad y
## factor. No hace nada si el clima no tiene canal de mundo o no hay ancla.
func _crear_mundo_estado(estado: EstadoVisual) -> void:
	if estado == null or estado.mundo != null or estado.definicion.escena_mundo == null:
		return
	var ancla: Node2D = obtener_ancla_mundo()
	if ancla == null or not ancla.is_inside_tree():
		return
	var nodo: Node = estado.definicion.escena_mundo.instantiate()
	if not (nodo is EfectoClimaMundoBase):
		push_error("[CLIMA] La escena de mundo de '%s' no hereda EfectoClimaMundoBase" % String(estado.definicion.id))
		nodo.queue_free()
		return
	estado.mundo = nodo as EfectoClimaMundoBase
	estado.mundo.name = "ClimaMundo_%s" % String(estado.definicion.id)
	ancla.add_child(estado.mundo)
	estado.mundo.configurar(estado.intensidad)
	estado.mundo.set_factor_mezcla(estado.factor)


func _liberar_mundo_estado(estado: EstadoVisual) -> void:
	if estado == null or estado.mundo == null:
		return
	if is_instance_valid(estado.mundo):
		estado.mundo.detener()
		estado.mundo.visible = false
		estado.mundo.queue_free()
	estado.mundo = null


func _normalizar_definicion(definicion: DefinicionClima) -> DefinicionClima:
	if definicion == null:
		return CLIMA_NINGUNO
	var resuelta: DefinicionClima = definicion.resolver()
	return CLIMA_NINGUNO if resuelta == null else resuelta


func _coincide_definicion(definicion: DefinicionClima) -> bool:
	return definicion == _definicion_actual and definicion.obtener_firma_visual() == _firma_actual


func obtener_diagnostico() -> Dictionary:
	return {
		"actual": obtener_clima_actual_id(),
		"objetivo": obtener_clima_objetivo_id(),
		"intensidad": _intensidad_actual,
		"factor_actual": _actual.factor if _actual != null else 0.0,
		"factor_objetivo": _objetivo.factor if _objetivo != null else 0.0,
		"transicionando": _transicionando,
		"efectos_vivos": obtener_cantidad_efectos_vivos(),
		"efectos_mundo": obtener_cantidad_efectos_mundo_vivos(),
		"ancla_mundo": obtener_ancla_mundo() != null,
	}


func _obtener_area_visible() -> Rect2:
	var rect: Rect2 = get_viewport().get_visible_rect()
	return Rect2(Vector2.ZERO, rect.size)


func _on_viewport_size_changed() -> void:
	var area: Rect2 = _obtener_area_visible()
	_actualizar_area_estado(_actual, area)
	_actualizar_area_estado(_objetivo, area)


func _actualizar_area_estado(estado: EstadoVisual, area: Rect2) -> void:
	if estado == null:
		return
	if estado.raiz != null:
		estado.raiz.position = area.position
		estado.raiz.size = area.size
	if estado.tinte != null:
		estado.tinte.position = Vector2.ZERO
		estado.tinte.size = area.size
	if estado.efecto != null:
		estado.efecto.actualizar_area_visible(Rect2(Vector2.ZERO, area.size))
		estado.efecto.configurar(estado.intensidad, Rect2(Vector2.ZERO, area.size))


func _configurar_destellos_estado(estado: EstadoVisual, habilitados: bool) -> void:
	if estado == null or estado.efecto == null:
		return
	if "destellos_habilitados" in estado.efecto:
		estado.efecto.set("destellos_habilitados", habilitados and estado.definicion.permite_destellos)


func _exit_tree() -> void:
	_token_solicitud += 1
	_cancelar_tween()
	_liberar_estado(_actual)
	_liberar_estado(_objetivo)
	_actual = null
	_objetivo = null
