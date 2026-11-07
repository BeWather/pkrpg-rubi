## ReflexionesAgua.gd
## Nodo gestor centralizado de reflejos y ondas de agua.
##
## Lo gestiona CapasAgua (res://escenas/mapas/capas_agua.tscn), que lo dibuja
## por encima del agua y por debajo del suelo:
##   Agua → CapasAgua[BackBufferAgua → AnclaClimaMundo → SombraPuente → AguaFX] → … → Suelo
##
## Uso en la escena:
##   - Sin configuración propia: basta con `reflejos` activo en CapasAgua, que crea
##     un AguaFX interno con los valores por defecto de este script.
##   - Con configuración propia: añadir un Node2D "AguaFX" con este script como
##     hijo de CapasAgua. Opcional: `tp_tile_data_map`; si no, se usa la capa de
##     datos 0 del mapa propietario de este nodo.
##   Los mapas sin migrar (AguaFX hijo directo del mapa) siguen funcionando: el
##   mapa lo encuentra por nombre (MapaConfiguracion.obtener_reflexiones()).
##
## Las fuentes del reflejo se toman del nodo "NPCs" del mapa activo.
## Si el jugador no está aún reparentado a ese nodo, se añade como fallback.
##
## Reflejo según la capa de datos de cada fuente (obtener_capa_fuente()):
##   - Capa 0: reflejo normal si hay REFLEJO (capa 0) bajo los pies.
##   - Capa >= 1 (p. ej. sobre un puente): el REFLEJO de la capa 0 se ignora.
##     Si la celda actual (o la anterior, como el GBA) tiene PUENTE_BAJO/MEDIO/ALTO
##     en la capa de la fuente, se dibuja un reflejo-silueta de color sólido
##     (`color_silueta_puente`) desplazado `desplazamientos_puente[tipo - 1]` px
##     más abajo (pokeruby: bridgeReflectionVerticalOffsets 12/28/44). Sin
##     bandera de puente no hay reflejo.
##
## Agua del backbuffer (reflejo opaco, como el GBA):
##   Con `reflejo_opaco_sobre_efectos` activo en la CapasAgua del mapa (que crea
##   el `BackBufferCopy` justo después de la capa `Agua`), los reflejos usan
##   `shader_reflejo_fondo`, que lee el agua de esa copia y dibuja píxeles opacos
##   con el agua ya mezclada (usa_agua_backbuffer()):
##   - Reflejo normal (FIJO / ONDAS_SHADER): mismo aspecto que el semitransparente
##     sobre el agua, pero tapa las nubes que haya debajo.
##   - Silueta de puente: mix(agua, sombra.rgb, sombra.a) con el color/alfa del
##     tile de la sombra de puente (obtener_color_sombra_puente()): sobre la
##     sombra da exactamente su color y sobre el agua clara parece la propia sombra.
##   Sin reflejo opaco todo sigue como antes (reflejo semitransparente y silueta
##   sólida `color_silueta_puente`).
##   El backbuffer y la capa de sombra se obtienen de la CapasAgua padre o, si no,
##   del MapaConfiguracion propietario (que también resuelve los mapas sin migrar).
##
## API pública:
##   reproducir_onda(pos_global: Vector2) -> void
##     Reproduce la animación de onda de agua en la posición indicada.
##     El personaje/NPC debe llamar esto al pisar un tile AGUA_SALPICA a ras de
##     agua (nunca sobre un puente: TPTileDataMap.admite_efectos_agua()).

extends Node2D
class_name ReflexionesAgua

enum ModoEfectoReflejo {
	FIJO,
	ONDAS_SHADER,
}

## Qué reflejo se está dibujando para una fuente.
enum TipoReflejo {
	NINGUNO,
	NORMAL,
	SILUETA_PUENTE,
}

# Referencia al mapa de datos de tiles (capa 0 por defecto)
@export var tp_tile_data_map: TPTileDataMap = null

# Shader compartido de reflejo de agua
@export var shader_reflejo: Shader = preload("res://UI/shaders/agua_reflejo.gdshader")

# Modo visual del reflejo. Permite dejar un reflejo fijo o usar el shader actual.
@export var modo_efecto_reflejo: ModoEfectoReflejo = ModoEfectoReflejo.FIJO

# Tinte/opacidad para el modo fijo sin shader.
# RGB próximo a blanco con leve tinte azul para simular el efecto pálido del GBA.
@export var color_reflejo_fijo: Color = Color(0.90, 0.92, 0.96, 0.52)

# Mezcla hacia blanco aplicada al shader de ondas (0.0 = sin cambio, 1.0 = blanco puro).
@export var paleness_reflejo: float = 0.30

# Separación vertical extra entre los pies de la entidad y el borde superior del reflejo (px)
@export var offset_y_reflejo: float = -2.0

# Si es true, sólo se muestra el reflejo cuando la entidad está directamente
# sobre un tile con flag REFLEJO. Si es false, se muestra siempre que haya
# un tile REFLEJO cerca (comportamiento más permisivo).
@export var estricto: bool = true

@export_group("Puentes")
## Desplazamiento vertical EXTRA (px) del reflejo-silueta según la altura del
## puente: índice 0 = PUENTE_BAJO, 1 = PUENTE_MEDIO, 2 = PUENTE_ALTO
## (pokeruby: bridgeReflectionVerticalOffsets = {12, 28, 44}).
@export var desplazamientos_puente: PackedFloat32Array = PackedFloat32Array([12.0, 28.0, 44.0])
## Color sólido del reflejo-silueta sobre un puente (paleta 10 del GBA: 74,115,172).
@export var color_silueta_puente: Color = Color8(74, 115, 172)
## Shader que rellena el frame con `color_silueta_puente` conservando su alfa
## (sin BackBufferCopy en el mapa).
@export var shader_silueta_puente: Shader = preload("res://UI/shaders/reflejo_silueta.gdshader")
## Override del color y alfa de la sombra del agua bajo los puentes que imita la
## silueta (solo con reflejo opaco). Alfa 0 = automático: se lee del primer tile
## usado de la capa de sombra de puente del mapa (CapasAgua.obtener_capa_sombra_puente():
## color predominante del tile × modulate del TileData × modulate/self_modulate
## de la capa). Si no hay capa ni override, la silueta usa `color_silueta_puente`.
@export var color_sombra_puente: Color = Color(0.0, 0.0, 0.0, 0.0)
@export_group("")

@export_group("Agua del backbuffer")
## Shader opaco (FIJO / ONDAS / SILUETA) que lee el agua de `hint_screen_texture`.
@export var shader_reflejo_fondo: Shader = preload("res://UI/shaders/reflejo_agua_fondo.gdshader")
@export_group("")

const FRAMES_ONDA_AGUA: SpriteFrames = preload("res://escenas/mapas/animaciones/onda_agua.tres")
## Profundidad máxima al resolver la capa de un NPC que sigue a otro.
const MAX_PROFUNDIDAD_LIDER := 4
## Valores del uniform `modo` de `reflejo_agua_fondo.gdshader`.
const MODO_FONDO_FIJO := 0
const MODO_FONDO_ONDAS := 1
const MODO_FONDO_SILUETA := 2
const TAMANO_TILE_PX: float = ConstantesGba.TAMANO_TILE
## El reflejo copia posición y frame de su fuente: debe procesarse después de ella (jugador y cámara a 100;
## AguaFX está antes que NPCs en el árbol), si no el reflejo va un fotograma por detrás.
const PRIORIDAD_PROCESO: int = 101

## Estructura interna por entidad rastreada
class DatosReflejo:
	var fuente: Node2D                      # Nodo raíz de la entidad (NPC / Jugador)
	var sprite_fuente: AnimatedSprite2D     # AnimatedSprite2D original
	var sprite_reflejo: AnimatedSprite2D    # Copia espejo, hijo de ReflexionesAgua
	var material_reflejo: ShaderMaterial
	var material_silueta: ShaderMaterial    # Material del reflejo-silueta de puente
	var material_fondo: ShaderMaterial      # Material opaco que lee el agua del backbuffer
	var callback_salida: Callable           # Conexión a fuente.tree_exiting (se desconecta al quitarla)
	var tiene_celda: bool = false           # celda_actual ya inicializada
	var tiene_celda_anterior: bool = false
	var celda_actual: Vector2 = Vector2.ZERO
	var celda_anterior: Vector2 = Vector2.ZERO  # Última celda distinta (previousCoords del GBA)
	var tipo_reflejo: int = 0               # ReflexionesAgua.TipoReflejo
	var tipo_puente: int = 0                # 0 = sin puente, 1..3 = BAJO/MEDIO/ALTO

var _reflejos: Array[DatosReflejo] = []

# Referencia al administrador de mapa para obtener la capa de datos
var _nodo_administrador: Node = null

# Nodo hijo que agrupa los sprites de reflejo
var _nodo_reflejos: Node2D = null

# Nodo hijo que agrupa las animaciones de onda (se dibuja encima de los reflejos)
var _nodo_ondas: Node2D = null

# Color de la sombra leído de la capa SombraPuente (cache por instancia de capa).
var _capa_sombra_cacheada: TileMapLayer = null
var _color_sombra_cacheado: Color = Color(0.0, 0.0, 0.0, 0.0)
var _color_sombra_resuelto: bool = false


func _ready() -> void:
	process_priority = PRIORIDAD_PROCESO
	_nodo_reflejos = get_node_or_null("ReflejosSprites") as Node2D
	if _nodo_reflejos == null:
		_nodo_reflejos = Node2D.new()
		_nodo_reflejos.name = "ReflejosSprites"
		add_child(_nodo_reflejos)
	_nodo_ondas = get_node_or_null("OndasAgua") as Node2D
	if _nodo_ondas == null:
		_nodo_ondas = Node2D.new()
		_nodo_ondas.name = "OndasAgua"
		add_child(_nodo_ondas)
	_nodo_administrador = get_tree().root.get_node_or_null("AdministradorMapa")
	call_deferred("_sincronizar_fuentes_mapa_activo")


func _sincronizar_fuentes_mapa_activo() -> void:
	var fuentes_deseadas: Array[Node2D] = _obtener_fuentes_mapa_activo()
	var fuentes_registradas: Dictionary = {}
	for fuente: Node2D in fuentes_deseadas:
		fuentes_registradas[fuente] = true

	for i: int in range(_reflejos.size() - 1, -1, -1):
		var fuente_actual: Node2D = _reflejos[i].fuente
		if not is_instance_valid(fuente_actual) or not fuentes_registradas.has(fuente_actual):
			_liberar_datos(_reflejos[i])
			_reflejos.remove_at(i)

	for fuente: Node2D in fuentes_deseadas:
		add_fuente(fuente)


func _obtener_fuentes_mapa_activo() -> Array[Node2D]:
	var fuentes: Array[Node2D] = []
	var mapa_actual := _obtener_mapa_actual()
	if mapa_actual == null:
		return fuentes

	var nodo_npcs := mapa_actual.get_node_or_null("NPCs")
	if nodo_npcs != null:
		for child: Node in nodo_npcs.get_children():
			if child is Node2D:
				var fuente := child as Node2D
				if _resolver_sprite_fuente(fuente) != null:
					fuentes.append(fuente)

	var jugador := _obtener_jugador_actual()
	if jugador != null and not fuentes.has(jugador) and _resolver_sprite_fuente(jugador) != null:
		fuentes.append(jugador)

	return fuentes


func _obtener_jugador_actual() -> Node2D:
	if _nodo_administrador == null:
		return null
	var jugador = _nodo_administrador.get("jugador")
	return jugador as Node2D if jugador is Node2D else null


func _obtener_mapa_actual() -> MapaConfiguracion:
	if _nodo_administrador == null:
		return null
	var mapa = _nodo_administrador.get("mapa_actual")
	return mapa as MapaConfiguracion if mapa is MapaConfiguracion else null


## Registra una entidad para que tenga reflejo de agua.
## Se llama automáticamente para los hijos de "NPCs" del mapa activo,
## pero también puede invocarse manualmente.
func add_fuente(fuente: Node2D) -> void:
	# Evitar duplicados
	for d: DatosReflejo in _reflejos:
		if d.fuente == fuente:
			return

	var sprite_src: AnimatedSprite2D = _resolver_sprite_fuente(fuente)
	if sprite_src == null:
		return

	var datos := DatosReflejo.new()
	datos.fuente = fuente
	datos.sprite_fuente = sprite_src

	# Crear el AnimatedSprite2D de reflejo como hijo de este nodo
	var reflejo := AnimatedSprite2D.new()
	reflejo.centered = sprite_src.centered
	reflejo.texture_filter = sprite_src.texture_filter
	reflejo.visible = false

	var mat := ShaderMaterial.new()
	mat.shader = shader_reflejo
	datos.material_reflejo = mat
	datos.sprite_reflejo = reflejo

	_nodo_reflejos.add_child(reflejo)
	_reflejos.append(datos)

	# Escuchar si la fuente sale del árbol para limpiar
	datos.callback_salida = _on_fuente_saliendo.bind(fuente)
	fuente.tree_exiting.connect(datos.callback_salida, CONNECT_ONE_SHOT)


## Elimina el seguimiento de una entidad.
func remove_fuente(fuente: Node2D) -> void:
	for i: int in range(_reflejos.size()):
		if _reflejos[i].fuente == fuente:
			_liberar_datos(_reflejos[i])
			_reflejos.remove_at(i)
			return


## Libera el sprite espejo y desconecta `tree_exiting`; sin esto, volver a
## registrar la fuente (p. ej. al regresar a un mapa) la conectaría dos veces.
func _liberar_datos(datos: DatosReflejo) -> void:
	if is_instance_valid(datos.sprite_reflejo):
		datos.sprite_reflejo.queue_free()
	var fuente: Node2D = datos.fuente
	if is_instance_valid(fuente) and datos.callback_salida.is_valid() \
			and fuente.tree_exiting.is_connected(datos.callback_salida):
		fuente.tree_exiting.disconnect(datos.callback_salida)


func _on_fuente_saliendo(fuente: Node2D) -> void:
	remove_fuente(fuente)


func _process(_delta: float) -> void:
	_sincronizar_fuentes_mapa_activo()
	for datos: DatosReflejo in _reflejos:
		_actualizar_reflejo(datos)


func _actualizar_reflejo(datos: DatosReflejo) -> void:
	var fuente: Node2D = datos.fuente
	var reflejo: AnimatedSprite2D = datos.sprite_reflejo

	if not is_instance_valid(fuente) or not is_instance_valid(reflejo):
		return

	# Un objeto liberado compara igual a null en Godot 4, así que no se puede
	# usar `!= null` como guarda: pasar la referencia muerta a un parámetro
	# tipado AnimatedSprite2D rompe con "previously freed".
	if not is_instance_valid(datos.sprite_fuente):
		datos.sprite_fuente = null
	var sprite_src: AnimatedSprite2D = _resolver_sprite_fuente(fuente, datos.sprite_fuente)
	if sprite_src == null or not is_instance_valid(sprite_src):
		reflejo.visible = false
		return
	datos.sprite_fuente = sprite_src

	# Filtro: solo sprites de más de un tile (16 px) de alto tienen reflejo, salvo
	# los que lo piden con la meta `reflejo_aunque_bajo` (bolas de objeto).
	var altura_px: float = _obtener_altura_sprite(sprite_src)
	if altura_px <= TAMANO_TILE_PX and not sprite_src.get_meta(&"reflejo_aunque_bajo", false):
		reflejo.visible = false
		return

	# Visibilidad: fuente visible + tipo de reflejo según su capa de datos
	# (capa 0: REFLEJO bajo sus pies; capa >= 1: solo silueta sobre PUENTE_*).
	var fuente_visible: bool = fuente.visible and sprite_src.visible
	var tiles_altura: int = ceili(altura_px / TAMANO_TILE_PX)
	var tipo: int = evaluar_reflejo(datos, tiles_altura)

	if not fuente_visible or tipo == TipoReflejo.NINGUNO:
		reflejo.visible = false
		return

	# Sincronizar SpriteFrames y frame actual
	if reflejo.sprite_frames != sprite_src.sprite_frames:
		reflejo.sprite_frames = sprite_src.sprite_frames
	if reflejo.animation != sprite_src.animation:
		reflejo.animation = sprite_src.animation
		reflejo.frame = sprite_src.frame
	else:
		reflejo.frame = sprite_src.frame

	reflejo.texture_filter = sprite_src.texture_filter
	reflejo.offset = sprite_src.offset
	reflejo.centered = sprite_src.centered
	reflejo.flip_h = sprite_src.flip_h
	reflejo.scale = sprite_src.scale
	reflejo.rotation = sprite_src.global_rotation
	reflejo.skew = sprite_src.skew

	if tipo == TipoReflejo.SILUETA_PUENTE:
		_aplicar_silueta_puente(datos, sprite_src)
	else:
		_aplicar_modo_efecto(datos, sprite_src)
	var offset_extra_y: float = -16.0 if sprite_src.name == &"pesca" else 0.0
	offset_extra_y += obtener_desplazamiento_puente(datos.tipo_puente) if tipo == TipoReflejo.SILUETA_PUENTE else 0.0

	# Usar la posición global del AnimatedSprite2D activo permite respetar offsets
	# y variaciones de tamaño entre sprites y animaciones de la misma entidad.
	reflejo.global_position = sprite_src.global_position + sprite_src.sprite_frames.get_frame_texture(sprite_src.animation, sprite_src.frame).get_size() * Vector2(0.0, 1.0) * sprite_src.scale + Vector2(0.0, offset_y_reflejo + offset_extra_y)

	reflejo.visible = true


func _aplicar_modo_efecto(datos: DatosReflejo, sprite_src: AnimatedSprite2D) -> void:
	var reflejo := datos.sprite_reflejo
	if usa_agua_backbuffer():
		_aplicar_modo_efecto_fondo(datos, sprite_src)
		return
	match modo_efecto_reflejo:
		ModoEfectoReflejo.FIJO:
			reflejo.material = null
			reflejo.flip_v = true
			reflejo.modulate = _multiplicar_colores(sprite_src.modulate, color_reflejo_fijo)
		ModoEfectoReflejo.ONDAS_SHADER:
			if datos.material_reflejo == null:
				datos.material_reflejo = ShaderMaterial.new()
			if datos.material_reflejo.shader != shader_reflejo:
				datos.material_reflejo.shader = shader_reflejo
			datos.material_reflejo.set_shader_parameter(&"paleness", paleness_reflejo)
			reflejo.material = datos.material_reflejo
			reflejo.flip_v = false
			reflejo.modulate = sprite_src.modulate


## Reflejo normal opaco (con BackBufferCopy): mismo aspecto que el clásico sobre
## el agua, pero el agua viene del backbuffer y tapa las nubes de debajo.
func _aplicar_modo_efecto_fondo(datos: DatosReflejo, sprite_src: AnimatedSprite2D) -> void:
	var reflejo := datos.sprite_reflejo
	var mat_fondo := _obtener_material_fondo(datos)
	reflejo.material = mat_fondo
	reflejo.modulate = sprite_src.modulate
	match modo_efecto_reflejo:
		ModoEfectoReflejo.FIJO:
			mat_fondo.set_shader_parameter(&"modo", MODO_FONDO_FIJO)
			mat_fondo.set_shader_parameter(&"color_reflejo", color_reflejo_fijo)
			reflejo.flip_v = true
		ModoEfectoReflejo.ONDAS_SHADER:
			mat_fondo.set_shader_parameter(&"modo", MODO_FONDO_ONDAS)
			mat_fondo.set_shader_parameter(&"paleness", paleness_reflejo)
			reflejo.flip_v = false


func _obtener_material_fondo(datos: DatosReflejo) -> ShaderMaterial:
	if datos.material_fondo == null:
		datos.material_fondo = ShaderMaterial.new()
	if datos.material_fondo.shader != shader_reflejo_fondo:
		datos.material_fondo.shader = shader_reflejo_fondo
	return datos.material_fondo


## Reflejo-silueta de puente: espejo vertical del frame actual (flip_v, igual que
## el modo FIJO). Con BackBufferCopy: color de la sombra del puente mezclado con
## el agua del backbuffer; sin él: relleno sólido de `color_silueta_puente`.
func _aplicar_silueta_puente(datos: DatosReflejo, sprite_src: AnimatedSprite2D) -> void:
	var reflejo := datos.sprite_reflejo
	if usa_agua_backbuffer():
		var mat_fondo := _obtener_material_fondo(datos)
		mat_fondo.set_shader_parameter(&"modo", MODO_FONDO_SILUETA)
		mat_fondo.set_shader_parameter(&"color_sombra", obtener_color_silueta_fondo())
		reflejo.material = mat_fondo
		reflejo.flip_v = true
		reflejo.modulate = Color(1.0, 1.0, 1.0, sprite_src.modulate.a)
		return
	if datos.material_silueta == null:
		datos.material_silueta = ShaderMaterial.new()
	if datos.material_silueta.shader != shader_silueta_puente:
		datos.material_silueta.shader = shader_silueta_puente
	datos.material_silueta.set_shader_parameter(&"color_silueta", color_silueta_puente)
	reflejo.material = datos.material_silueta
	reflejo.flip_v = true
	reflejo.modulate = Color(1.0, 1.0, 1.0, sprite_src.modulate.a)


static func _multiplicar_colores(a: Color, b: Color) -> Color:
	return Color(a.r * b.r, a.g * b.g, a.b * b.b, a.a * b.a)


# ---------------------------------------------------------------------------
# Agua del backbuffer y color de la sombra del puente
# ---------------------------------------------------------------------------

## true si los reflejos deben leer el agua del backbuffer (reflejo opaco): lo
## decide la CapasAgua padre (`reflejo_opaco_sobre_efectos` y backbuffer activo)
## o, si no la hay, el MapaConfiguracion propietario (MapaConfiguracion.usa_reflejo_opaco()).
func usa_agua_backbuffer() -> bool:
	var capas := _obtener_capas_agua_padre()
	if capas != null:
		return capas.usa_reflejo_opaco()
	var mapa := _obtener_mapa_propietario()
	return mapa != null and mapa.usa_reflejo_opaco()


## BackBufferCopy que copia solo el agua (de la CapasAgua padre o del mapa
## propietario), o null si no hay o no está activo.
func buscar_backbuffer_agua() -> BackBufferCopy:
	var capas := _obtener_capas_agua_padre()
	var copia: BackBufferCopy = null
	if capas != null:
		copia = capas.obtener_backbuffer()
	else:
		var mapa := _obtener_mapa_propietario()
		copia = mapa.obtener_backbuffer() if mapa != null else null
	return copia if CapasAgua.backbuffer_activo(copia) else null


## CapasAgua que gestiona este AguaFX (su padre), o null en mapas sin migrar.
func _obtener_capas_agua_padre() -> CapasAgua:
	return get_parent() as CapasAgua


## Color (rgb) y alfa de la sombra del agua bajo los puentes: el override
## `color_sombra_puente` si su alfa > 0; si no, el leído del tile de la capa de
## sombra de puente (cacheado); Color(0, 0, 0, 0) si no hay.
func obtener_color_sombra_puente() -> Color:
	if color_sombra_puente.a > 0.0:
		return color_sombra_puente
	var capa: TileMapLayer = _buscar_capa_sombra()
	if not _color_sombra_resuelto or capa != _capa_sombra_cacheada:
		_capa_sombra_cacheada = capa
		_color_sombra_cacheado = leer_color_sombra_de_capa(capa)
		_color_sombra_resuelto = true
	return _color_sombra_cacheado


## Olvida el color de sombra cacheado (p. ej. tras repintar `SombraPuente`).
func refrescar_color_sombra_puente() -> void:
	_color_sombra_resuelto = false
	_capa_sombra_cacheada = null


## Color que recibe la silueta en modo backbuffer: la sombra del puente o, si no
## hay, `color_silueta_puente` (alfa 1 → sólido, igual que sin backbuffer).
func obtener_color_silueta_fondo() -> Color:
	var sombra: Color = obtener_color_sombra_puente()
	return sombra if sombra.a > 0.0 else color_silueta_puente


## Capa de sombra de puente de la CapasAgua padre o, si no, del mapa propietario.
func _buscar_capa_sombra() -> TileMapLayer:
	var capas := _obtener_capas_agua_padre()
	if capas != null:
		return capas.obtener_capa_sombra_puente()
	var mapa := _obtener_mapa_propietario()
	return mapa.obtener_capa_sombra_puente() if mapa != null else null


## Color efectivo del primer tile usado de `capa`: color predominante de los
## texels con alfa > 0 de su región en el atlas × modulate del TileData ×
## modulate y self_modulate de la capa. Color(0, 0, 0, 0) si no se puede leer.
static func leer_color_sombra_de_capa(capa: TileMapLayer) -> Color:
	var vacio := Color(0.0, 0.0, 0.0, 0.0)
	if capa == null or not is_instance_valid(capa) or capa.tile_set == null:
		return vacio
	var celdas: Array[Vector2i] = capa.get_used_cells()
	if celdas.is_empty():
		return vacio
	var celda: Vector2i = celdas[0]
	var source_id: int = capa.get_cell_source_id(celda)
	if not capa.tile_set.has_source(source_id):
		return vacio
	var atlas := capa.tile_set.get_source(source_id) as TileSetAtlasSource
	if atlas == null or atlas.texture == null:
		return vacio
	var coords: Vector2i = capa.get_cell_atlas_coords(celda)
	if not atlas.has_tile(coords):
		return vacio
	var imagen: Image = atlas.texture.get_image()
	if imagen == null or imagen.is_empty():
		return vacio
	if imagen.is_compressed():
		imagen = imagen.duplicate() as Image
		if imagen.decompress() != OK:
			return vacio
	var color: Color = _color_predominante(imagen, atlas.get_tile_texture_region(coords))
	if color.a <= 0.0:
		return vacio
	var alternativo: int = capa.get_cell_alternative_tile(celda)
	var tile_data: TileData = atlas.get_tile_data(coords, alternativo)
	if tile_data != null:
		color = _multiplicar_colores(color, tile_data.modulate)
	color = _multiplicar_colores(color, capa.modulate)
	return _multiplicar_colores(color, capa.self_modulate)


## Color más frecuente entre los texels con alfa > 0 de `region` (alfa 0 si no hay).
static func _color_predominante(imagen: Image, region: Rect2i) -> Color:
	var limites: Rect2i = region.intersection(Rect2i(Vector2i.ZERO, imagen.get_size()))
	var cuentas: Dictionary = {}
	var mejor := Color(0.0, 0.0, 0.0, 0.0)
	var mejor_cuenta: int = 0
	for y: int in range(limites.position.y, limites.end.y):
		for x: int in range(limites.position.x, limites.end.x):
			var color: Color = imagen.get_pixel(x, y)
			if color.a <= 0.0:
				continue
			var clave: int = color.to_rgba32()
			var cuenta: int = int(cuentas.get(clave, 0)) + 1
			cuentas[clave] = cuenta
			if cuenta > mejor_cuenta:
				mejor_cuenta = cuenta
				mejor = color
	return mejor


## Decide qué reflejo corresponde a la fuente de `datos` y lo guarda en
## `datos.tipo_reflejo` / `datos.tipo_puente` (también lo devuelve).
## - Capa de datos 0 (o capa inexistente en el mapa): reflejo NORMAL si hay
##   REFLEJO de la capa 0 bajo los pies (_esta_sobre_reflejo).
## - Capa >= 1: se ignora el REFLEJO de la capa 0. SILUETA_PUENTE si la celda
##   actual o, en su defecto, la anterior (previousCoords del GBA) tiene una
##   bandera PUENTE_* en la capa de la fuente; si no, NINGUNO.
func evaluar_reflejo(datos: DatosReflejo, tiles_altura: int = 1) -> int:
	datos.tipo_puente = 0
	# Comprobar antes de asignar: una referencia liberada a una variable tipada
	# rompe con "previously freed".
	if not is_instance_valid(datos.fuente):
		datos.tipo_reflejo = TipoReflejo.NINGUNO
		return datos.tipo_reflejo
	var fuente: Node2D = datos.fuente
	_registrar_celda(datos, _celda_de_fuente(fuente))

	var capa: int = obtener_capa_fuente(fuente)
	var tp_capa: TPTileDataMap = _obtener_tp_capa(capa) if capa >= 1 else null
	if tp_capa == null or tp_capa.layer_id <= 0:
		var sobre_reflejo: bool = _esta_sobre_reflejo(fuente, tiles_altura)
		datos.tipo_reflejo = TipoReflejo.NORMAL if sobre_reflejo else TipoReflejo.NINGUNO
		return datos.tipo_reflejo

	var tipo_puente: int = tp_capa.get_tipo_puente(datos.celda_actual)
	if tipo_puente == 0 and datos.tiene_celda_anterior:
		tipo_puente = tp_capa.get_tipo_puente(datos.celda_anterior)
	datos.tipo_puente = tipo_puente
	datos.tipo_reflejo = TipoReflejo.SILUETA_PUENTE if tipo_puente > 0 else TipoReflejo.NINGUNO
	return datos.tipo_reflejo


## Desplazamiento vertical extra (px) del reflejo-silueta para un tipo de puente
## 1..3; 0 fuera de rango.
func obtener_desplazamiento_puente(tipo_puente: int) -> float:
	if tipo_puente < 1 or tipo_puente > desplazamientos_puente.size():
		return 0.0
	return desplazamientos_puente[tipo_puente - 1]


## Capa de datos (layer_id) en la que está una fuente:
## - Jugador (AdministradorMapa.jugador): Singleton.capa_activa.
## - NPC con `capa_datos >= 0` (npc_base, PokemonInicialOverworld…): esa capa.
## - NPC con `capa_datos = -1` ("cualquier capa"): la de su líder si está
##   siguiendo a alguien (npc_base.lider); si no, 0 (a ras de suelo/agua).
## - Cualquier otro nodo: 0.
func obtener_capa_fuente(fuente: Node2D, profundidad: int = 0) -> int:
	if fuente == null or not is_instance_valid(fuente):
		return 0
	if fuente == _obtener_jugador_actual():
		return _capa_activa_jugador()
	if "capa_datos" in fuente:
		var capa_datos: Variant = fuente.get("capa_datos")
		if capa_datos is int and int(capa_datos) >= 0:
			return int(capa_datos)
		if "lider" in fuente and profundidad < MAX_PROFUNDIDAD_LIDER:
			var lider: Variant = fuente.get("lider")
			if is_instance_valid(lider) and lider is Node2D:
				return obtener_capa_fuente(lider as Node2D, profundidad + 1)
	return 0


func _capa_activa_jugador() -> int:
	return Singleton.capa_activa


## Celda (coordenadas del mapa) en la que está la fuente.
func _celda_de_fuente(fuente: Node2D) -> Vector2:
	var mapa := _obtener_mapa_referencia()
	if mapa != null:
		return Vector2(mapa.global_to_map_cell(fuente.global_position))
	return Vector2(floor(fuente.global_position.x / TAMANO_TILE_PX), floor(fuente.global_position.y / TAMANO_TILE_PX))


## Lleva la celda actual y la última distinta (previousCoords del GBA).
static func _registrar_celda(datos: DatosReflejo, celda: Vector2) -> void:
	if not datos.tiene_celda:
		datos.celda_actual = celda
		datos.tiene_celda = true
		return
	if celda != datos.celda_actual:
		datos.celda_anterior = datos.celda_actual
		datos.tiene_celda_anterior = true
		datos.celda_actual = celda


## Capa de datos exacta `layer_id` del mapa al que pertenece este AguaFX (o del
## mapa actual). null si no existe: la fuente se trata entonces como capa 0.
func _obtener_tp_capa(layer_id: int) -> TPTileDataMap:
	var mapa := _obtener_mapa_referencia()
	if mapa == null:
		return null
	return mapa.get_capa_por_id(layer_id)


## Devuelve true si hay un tile REFLEJO dentro del rango de tiles que ocupa el sprite.
## tiles_altura indica cuántos tiles mide el sprite verticalmente (ceili(altura_px / 16)).
## Un sprite de 32 px (2 tiles) detecta agua hasta 2 celdas hacia abajo.
func _esta_sobre_reflejo(fuente: Node2D, tiles_altura: int = 1) -> bool:
	var tp: TPTileDataMap = _obtener_tp()
	if tp == null:
		return false
	# Buscar un tile REFLEJO desde 1 hasta tiles_altura celdas por debajo de los pies.
	var celda_pies: Vector2 = _global_a_celda(fuente.global_position, tp)
	for i: int in range(1, tiles_altura + 1):
		if tp.has_flag(celda_pies + Vector2(0, i), TPTileDataMap.Flags.REFLEJO):
			return true
	# Si no es estricto, aceptar también el tile actual como fallback permisivo.
	if not estricto:
		return tp.has_flag(celda_pies, TPTileDataMap.Flags.REFLEJO)
	return false


## Capa de datos 0 para el REFLEJO: el export `tp_tile_data_map` o, si no, la
## del mapa de referencia (el propietario de este AguaFX). Debe ser el mismo mapa
## con el que _global_a_celda calcula la celda: si se usara el mapa activo, un
## mapa vecino visible leería las banderas del activo con sus propias celdas.
func _obtener_tp() -> TPTileDataMap:
	if tp_tile_data_map != null:
		return tp_tile_data_map
	var mapa := _obtener_mapa_referencia()
	if mapa == null:
		return null
	return mapa.get_capa_resuelta(0)


## Convierte posición global a celda de tile (Vector2 con coords flotantes truncadas).
func _global_a_celda(pos_global: Vector2, tp: TPTileDataMap) -> Vector2:
	var mapa := _obtener_mapa_referencia()
	if mapa != null:
		return Vector2(mapa.global_to_map_cell(pos_global))
	var tile_size: float = float(tp.tile_size) if tp.tile_size > 0 else TAMANO_TILE_PX
	return Vector2(floor(pos_global.x / tile_size), floor(pos_global.y / tile_size))


## Busca el AnimatedSprite2D principal de una entidad.
func _resolver_sprite_fuente(nodo: Node2D, sprite_actual: AnimatedSprite2D = null) -> AnimatedSprite2D:
	if _es_sprite_fuente_valido(sprite_actual) and sprite_actual.visible:
		return sprite_actual
	var sprite_visible := _buscar_animated_sprite(nodo, true)
	if sprite_visible != null:
		return sprite_visible
	if _es_sprite_fuente_valido(sprite_actual):
		return sprite_actual
	return _buscar_animated_sprite(nodo, false)


func _buscar_animated_sprite(nodo: Node2D, preferir_visible: bool = true) -> AnimatedSprite2D:
	# Orden de prioridad de búsqueda: nombre canónico, luego primer hijo AnimatedSprite2D válido.
	var candidatos: Array[StringName] = [&"AnimatedSprite2D", &"basico", &"sprite"]
	var fallback: AnimatedSprite2D = null
	for nombre: StringName in candidatos:
		var hijo: Node = nodo.get_node_or_null(NodePath(nombre))
		if hijo is AnimatedSprite2D:
			var sprite := hijo as AnimatedSprite2D
			if not _es_sprite_fuente_valido(sprite):
				continue
			if fallback == null:
				fallback = sprite
			if not preferir_visible or sprite.visible:
				return sprite
	# Fallback: buscar cualquier AnimatedSprite2D hijo directo válido.
	for hijo: Node in nodo.get_children():
		if hijo is AnimatedSprite2D:
			var sprite := hijo as AnimatedSprite2D
			if not _es_sprite_fuente_valido(sprite):
				continue
			if fallback == null:
				fallback = sprite
			if not preferir_visible or sprite.visible:
				return sprite
	return fallback


## Devuelve la altura en píxeles del frame actual, incluyendo la escala vertical.
static func _obtener_altura_sprite(sprite: AnimatedSprite2D) -> float:
	if sprite.sprite_frames == null:
		return 0.0
	if not sprite.sprite_frames.has_animation(sprite.animation):
		return 0.0
	var tex: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if tex == null:
		return 0.0
	return tex.get_height() * absf(sprite.scale.y)


static func _es_sprite_fuente_valido(sprite: AnimatedSprite2D) -> bool:
	if sprite == null or not is_instance_valid(sprite):
		return false
	if sprite.get_meta(&"sin_reflejo", false):
		return false
	var nombre := String(sprite.name).to_lower()
	return not nombre.begins_with("reflejo")


func _obtener_mapa_propietario() -> MapaConfiguracion:
	var nodo: Node = self
	while nodo != null:
		if nodo is MapaConfiguracion:
			return nodo as MapaConfiguracion
		nodo = nodo.get_parent()
	return null


## Mapa con el que se calculan celdas y se leen banderas: el propietario de este
## AguaFX y, solo si no tiene, el mapa activo.
func _obtener_mapa_referencia() -> MapaConfiguracion:
	var mapa := _obtener_mapa_propietario()
	if mapa == null:
		mapa = _obtener_mapa_actual()
	return mapa


## Reproduce la animación de onda de agua centrada en pos_global.
## Llamar desde character.gd / npc_base.gd al pisar un tile AGUA_SALPICA (vía
## MapaConfiguracion.reproducir_onda).
func reproducir_onda(pos_global: Vector2) -> void:
	if FRAMES_ONDA_AGUA == null:
		push_warning("[AguaFX] reproducir_onda(): FRAMES_ONDA_AGUA no cargó (onda_agua.tres)")
		return
	if _nodo_ondas == null:
		push_warning("[AguaFX] reproducir_onda(): _nodo_ondas es null")
		return
	var onda := AnimatedSprite2D.new()
	onda.sprite_frames = FRAMES_ONDA_AGUA
	onda.animation = &"onda"
	onda.centered = true
	onda.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_nodo_ondas.add_child(onda)
	# Tras add_child: con el nodo aún fuera del árbol, global_position se tomaba
	# como local y la onda salía desplazada por la posición del mapa en el Overworld.
	onda.global_position = pos_global
	onda.play(&"onda")
	onda.animation_finished.connect(onda.queue_free)
