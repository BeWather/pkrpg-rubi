class_name CajaEquipo

extends AnimatedSprite2D

# Sistema de frames para las cajas del equipo:
# Frame 0: Caja vacía (sin Pokémon)
# Frame 1: Caja con Pokémon (estado normal)
# Frame 2: Cursor/foco (caja seleccionada)
# Frame 3: Selección para intercambio (solo desde menú)
# Frame 4: Pokémon debilitado (PS = 0)

@export var carpeta_iconos: String = "res://graficos/Icons/"
@export var icono_actual: int = 0
@export var configuracion: ConfiguracionPantallaEquipo

# Variables para la barra de salud
var ancho_barra_max: float = 48.0  # Ancho máximo de la barra de salud
var tween_salud: Tween
## Duración de animar_ps: la de toda la barra, y el mínimo para cambios pequeños.
const DURACION_PS_MAX: float = 1.2
const DURACION_PS_MIN: float = 0.4

# Variables para animación del icono
var tween_icono: Tween
var posicion_original_icono: Vector2
var pokemon_actual: BasePokemon  # Referencia al Pokémon actual para controlar animaciones

@onready var icono_as2d = $"icono_as2d"
@onready var label_nombre = $"nombre"
@onready var label_nivel = $"nv"
@onready var label_sexo = $"sexo"
@onready var label_ps = $"ps"
@onready var label_ps_max = $"ps_max"
@onready var estado_sprite = $"estado"
@onready var cursor_fijo = $"cursor-fijo"
@onready var cursor_movil = $"cursor-movil"
@onready var barra_salud_1 = $"BarraSalud1"
@onready var barra_salud_2 = $"BarraSalud2"

## Icono de objeto llevado (8x8; frame 0 = objeto, 1 = CARTA), hijo del icono
## del Pokémon para seguir su balanceo. Como en pokeruby (CreateHeldItemIcon)
## va en el centro del icono + (4, 10) → esquina en (16, 22) del icono 32x32.
const TEXTURA_OBJETO_LLEVADO: Texture2D = preload("res://UI/equipo/objeto_llevado.png")
const OFFSET_OBJETO_LLEVADO: Vector2 = Vector2(16, 22)
var icono_objeto: Sprite2D = null

## Icono de huevo (dos frames de 32x32, como los iconos normales).
const RUTA_ICONO_HUEVO: String = "res://graficos/Icons/iconEgg.png"
## Sufijo de la variante del fondo de la caja sin "Nv", barra ni "/" (un huevo
## no muestra nivel ni PS): pantalla-equipo-caja-larga.png → …-larga-huevo.png.
const SUFIJO_FONDO_HUEVO: String = "-huevo.png"
## Frames del fondo tal y como vienen en la escena, y su variante de huevo
## (se construye la primera vez que se necesita).
var _frames_fondo_normal: SpriteFrames = null
var _frames_fondo_huevo: SpriteFrames = null

## Modo MT/MO (`sub_808AE8C`): `sub_806D668` borra la barra y los números de PS y
## `DrawMonDescriptorStatus` pone un rótulo de 56x16 (DatosMaquinas.Descriptor).
const TEXTURA_DESCRIPTORES: Texture2D = preload("res://UI/equipo/descriptores_maquina.png")
const TAMANO_DESCRIPTOR: Vector2i = Vector2i(56, 16)
## Zona de cada fotograma (barra, "/" y números de PS) que se toma del fondo de huevo
## para borrar los PS conservando "Nv". Por defecto, la de las cajas largas.
@export var zona_sin_ps: Rect2i = Rect2i(64, 0, 86, 22)
## Esquina del rótulo dentro de la caja (`gUnknown_08376918`, relativo a la caja).
@export var posicion_descriptor: Vector2 = Vector2(88, 3)
## Descriptor a la vista (-1 = ninguno).
var descriptor_actual: int = -1
var _sprite_descriptor: Sprite2D = null
var _frames_fondo_sin_ps: SpriteFrames = null

# Estados de los frames
enum EstadoCaja {
	VACIA = 0,
	CON_POKEMON = 1,
	CURSOR = 2,
	SELECCIONADO = 3,
	DEBILITADO = 4
}

func _ready() -> void:
	# Cargar configuración por defecto si no está asignada
	if not configuracion:
		configuracion = ConfiguracionPantallaEquipo.new()
	
	# Crear el Tween para animaciones de la barra de salud
	tween_salud = create_tween()
	tween_salud.pause()
	
	# Crear el Tween para animaciones del icono
	tween_icono = create_tween()
	tween_icono.pause()
	
	# Conectar señal para cambio de color de la barra
	if barra_salud_1:
		barra_salud_1.resized.connect(_on_barra_salud_resized)
	
	# Guardar posición original del icono
	if icono_as2d:
		posicion_original_icono = icono_as2d.position
		_crear_icono_objeto()


# --- API PÚBLICA PARA EL CONTROLADOR ---

# Estados visuales de la caja, controlados desde el exterior
enum Estado { NORMAL, CURSOR, SELECCIONADO, VACIO }

# Función principal para actualizar la caja con los datos de un Pokémon
func mostrar_datos_pokemon(pokemon: BasePokemon, animar_ps: bool = false) -> void:
	"""
	Rellena la caja con toda la información de un Pokémon.
	Ahora solo acepta objetos BasePokemon (modelo unificado).
	Esta es la función principal que el controlador debe llamar.
	La barra de PS se coloca al instante; animar_ps = true solo cuando los PS
	cambian con la pantalla abierta (p. ej. al usar una poción).
	"""
	if not pokemon:
		limpiar()
		return

	visible = true
	pokemon_actual = pokemon  # Guardar referencia para animaciones
	_ocultar_descriptor()

	if pokemon.huevo:
		_mostrar_datos_huevo(pokemon)
		return
	_usar_fondo_huevo(false)

	# Actualizar labels con datos del BasePokemon
	label_nombre.text = pokemon.get_nombre_mostrar()
	label_nivel.text = str(pokemon.nivel)
	label_ps.text = str(pokemon.estad_ps_actual)
	label_ps_max.text = str(pokemon.estad_ps)
	
	# Actualizar género
	match pokemon.sexo:
		"M":
			label_sexo.text = "♂"
			label_sexo.modulate = Color(0.188235, 0.74902, 0.937255, 1)   # Hex: 30BCEF
		"F":
			label_sexo.text = "♀"
			label_sexo.modulate = Color(1, 0.611765, 0.576471, 1)     # Hex: FE9C93
		_:
			label_sexo.text = ""

	# Actualizar icono
	if pokemon.numero_nacional > 0:
		cargar_icono(pokemon.numero_nacional)
		icono_as2d.visible = true
		# Configurar animación del icono basada en los PS
		configurar_animacion_icono()
	else:
		icono_as2d.visible = false

	actualizar_objeto_llevado(pokemon)

	# Actualizar sprite de estado (veneno, parálisis, etc.)
	actualizar_sprite_estado(pokemon)
	
	# Actualizar barra de salud
	actualizar_barra_salud(pokemon.estad_ps, pokemon.estad_ps_actual, animar_ps)
	barra_salud_1.visible = true
	barra_salud_2.visible = true

## Caja de un huevo (party_menu.c con MON_DATA_IS_EGG): icono de huevo y
## "HUEVO"; sin nivel, sexo, estado, barra ni números de PS.
func _mostrar_datos_huevo(pokemon: BasePokemon) -> void:
	_usar_fondo_huevo(true)
	label_nombre.text = pokemon.get_nombre_mostrar()
	label_nivel.text = ""
	label_sexo.text = ""
	label_ps.text = ""
	label_ps_max.text = ""
	estado_sprite.visible = false
	if tween_salud:
		tween_salud.kill()
	barra_salud_1.visible = false
	barra_salud_2.visible = false
	_cargar_icono_desde_ruta(RUTA_ICONO_HUEVO)
	icono_as2d.visible = true
	configurar_animacion_icono()
	actualizar_objeto_llevado(pokemon)

# Función para cambiar el estado visual de la caja (foco, selección, etc.)
func establecer_estado(nuevo_estado: Estado) -> void:
	"""
	Cambia la apariencia de la caja para reflejar su estado actual
	(normal, con cursor, seleccionada para intercambio, o vacía).
	"""
	match nuevo_estado:
		Estado.NORMAL:
			frame = 1 # Frame para estado normal
			quitar_foco_movil()
			# Volver a posición original cuando no hay cursor
			restaurar_posicion_icono()
		Estado.CURSOR:
			if frame != 3:
				frame = 2 # Frame para el cursor principal
			poner_foco_movil()
			# Aplicar animación de cursor (desplazamiento vertical)
			aplicar_animacion_cursor()
		Estado.SELECCIONADO:
			frame = 3 # Frame para el Pokémon seleccionado para intercambio
			poner_foco_fijo()
			restaurar_posicion_icono()
		Estado.VACIO:
			frame = 0 # Frame para caja vacía
			limpiar()

# Función para dejar la caja en su estado inicial (vacía y oculta)
func limpiar() -> void:
	"""Oculta la caja y todos sus elementos, dejándola en estado vacío."""
	_ocultar_descriptor()
	_usar_fondo_huevo(false)
	frame = 0
	visible = true
	label_nombre.text = ""
	label_nivel.text = ""
	label_ps.text = ""
	label_ps_max.text = ""
	label_sexo.text = ""
	icono_as2d.visible = false
	if icono_objeto:
		icono_objeto.visible = false
	estado_sprite.visible = false
	cursor_fijo.visible = false
	cursor_movil.visible = false
	pokemon_actual = null  # Limpiar referencia del Pokémon
	
	# Detener animaciones del icono
	if tween_icono:
		tween_icono.kill()
	
	# Resetear barras de salud
	if barra_salud_1:
		barra_salud_1.size.x = 0
	if barra_salud_2:
		barra_salud_2.size.x = 0

## Muestra u oculta el icono de objeto llevado (SetHeldItemIconVisibility).
func actualizar_objeto_llevado(pokemon: BasePokemon) -> void:
	if icono_objeto == null:
		return
	if not ObjetosLlevados.lleva_objeto(pokemon):
		icono_objeto.visible = false
		return
	icono_objeto.frame = 1 if ObjetosLlevados.es_carta(pokemon.objeto) else 0
	icono_objeto.visible = true

# --- FUNCIONES INTERNAS ---

func _crear_icono_objeto() -> void:
	icono_objeto = Sprite2D.new()
	icono_objeto.name = "icono_objeto"
	icono_objeto.texture = TEXTURA_OBJETO_LLEVADO
	icono_objeto.vframes = 2
	icono_objeto.centered = false
	# El icono del Pokémon no está centrado y se dibuja desplazado por su offset.
	icono_objeto.position = icono_as2d.offset + OFFSET_OBJETO_LLEVADO
	icono_objeto.visible = false
	icono_as2d.add_child(icono_objeto)

func actualizar_sprite_estado(pokemon: BasePokemon) -> void:
	"""Gestiona la visibilidad y el frame del sprite de estado."""
	var estado: int = pokemon.estado
	
	# Si el Pokémon tiene PS completos, no puede estar debilitado
	# Esto corrige el caso donde estado=0 pero el Pokémon no está realmente debilitado
	if pokemon.estad_ps_actual > 0 and estado == Singleton.ProblemaEstado.DEBILITADO:
		estado = Singleton.ProblemaEstado.NORMAL
	# GetMonStatusAndPokerus: con 0 PS es «DEB» antes que cualquier problema de estado.
	elif pokemon.estad_ps_actual <= 0:
		estado = Singleton.ProblemaEstado.DEBILITADO
	
	# Ocultar sprite para estados normales
	if estado == Singleton.ProblemaEstado.NORMAL or estado == Singleton.ProblemaEstado.POKERUS:
		estado_sprite.visible = false
	else:
		estado_sprite.visible = true
		estado_sprite.frame = estado

func cargar_icono(numero_nacional: int) -> void:
	"""Carga el icono del Pokémon desde la carpeta de recursos."""
	_cargar_icono_desde_ruta("res://graficos/Icons/icon%03d.png" % numero_nacional)

## Carga un icono de dos frames de 32x32 (izquierdo y derecho) en icono_as2d.
func _cargar_icono_desde_ruta(ruta_icono: String) -> void:
	if ResourceLoader.exists(ruta_icono):
		var textura_icono = load(ruta_icono)
		
		# Crear AtlasTexture para el primer frame (izquierdo, 32x32)
		var atlas_frame1 = AtlasTexture.new()
		atlas_frame1.atlas = textura_icono
		atlas_frame1.region = Rect2(0, 0, 32, 32)
		
		# Crear AtlasTexture para el segundo frame (derecho, 32x32)
		var atlas_frame2 = AtlasTexture.new()
		atlas_frame2.atlas = textura_icono
		atlas_frame2.region = Rect2(32, 0, 32, 32)
		
		# Crear un SpriteFrames para el AnimatedSprite2D
		var frames_resource = SpriteFrames.new()
		frames_resource.add_frame("default", atlas_frame1)
		frames_resource.add_frame("default", atlas_frame2)
		icono_as2d.frames = frames_resource
		
		# No reproducir automáticamente - se controlará según los PS
		icono_as2d.stop()
	else:
		print("ADVERTENCIA: No se encontró el icono en la ruta: %s" % ruta_icono)
		icono_as2d.frames = null

# --- FUNCIONES PARA ANIMACIÓN DEL ICONO ---

func configurar_animacion_icono() -> void:
	"""Configura la animación del icono basada en los PS del Pokémon"""
	if not icono_as2d or not pokemon_actual:
		return
	
	# Si el Pokémon está debilitado (PS = 0), no se anima
	if pokemon_actual.estad_ps_actual <= 0:
		icono_as2d.stop()
		icono_as2d.frame = 0
		return
	
	# Calcular velocidad basada en el porcentaje de PS
	var porcentaje_ps = float(pokemon_actual.estad_ps_actual) / float(maxi(pokemon_actual.estad_ps, 1))
	var velocidad_base = 0.95  # Velocidad normal del frame
	
	# Un huevo no tiene barra de PS: siempre a velocidad normal.
	if pokemon_actual.huevo:
		pass
	# Si la barra está en rojo (menos del 25%), animación más lenta
	elif porcentaje_ps <= 0.25:
		velocidad_base *= 0.2  # 80% más lenta cuando está en rojo
	elif porcentaje_ps <= 0.5:
		velocidad_base *= 0.6  # 40% más lenta cuando está en rojo

	# Aplicar la velocidad y reproducir
	icono_as2d.speed_scale = velocidad_base
	icono_as2d.play("default")

func aplicar_animacion_cursor() -> void:
	"""Aplica la animación de desplazamiento vertical cuando el cursor está sobre la caja"""
	if not icono_as2d or not pokemon_actual:
		return
	
	# Detener cualquier animación de posición anterior
	if tween_icono:
		tween_icono.kill()
	
	# Si el Pokémon está debilitado, no aplicar desplazamiento
	if pokemon_actual.estad_ps_actual <= 0:
		return
	
	tween_icono = create_tween()
	tween_icono.set_loops()  # Loop infinito
	
	# Crear animación que sube y baja 1 pixel (total 2 pixels de rango)
	var pos_arriba = posicion_original_icono + Vector2(0, -1)
	var pos_abajo = posicion_original_icono + Vector2(0, 1)
	
	# Velocidad del desplazamiento sincronizada con los frames del icono
	var duracion_frame = 1.0 / (icono_as2d.speed_scale * 2.0)  # 2 frames por ciclo
	
	tween_icono.tween_property(icono_as2d, "position", pos_arriba, duracion_frame)
	tween_icono.tween_property(icono_as2d, "position", pos_abajo, duracion_frame)

func restaurar_posicion_icono() -> void:
	"""Restaura la posición original del icono con animación suave"""
	if not icono_as2d:
		return
	
	# Detener animación de cursor
	if tween_icono:
		tween_icono.kill()
	
	# Animar suavemente hacia la posición original
	tween_icono = create_tween()
	tween_icono.tween_property(icono_as2d, "position", posicion_original_icono, 0.2)
	
	# Reconfigurar la animación del icono según los PS
	configurar_animacion_icono()

func quitar_foco_movil() -> void:
	cursor_movil.visible = false

func quitar_foco_fijo() -> void:
	cursor_fijo.visible = false

func poner_foco_movil() -> void:
	cursor_movil.visible = true

func poner_foco_fijo() -> void:
	cursor_fijo.visible = true

# --- FUNCIONES PARA BARRA DE SALUD ---

func actualizar_barra_salud(ps_max: int, ps_actual: int, animar: bool = false) -> void:
	"""Actualiza la barra de salud; solo se anima si se pide (cambio de PS en pantalla)"""
	if not barra_salud_1 or not barra_salud_2:
		return

	if tween_salud:
		tween_salud.kill()

	if ps_max <= 0:
		barra_salud_1.size.x = 0
		barra_salud_2.size.x = 0
		return

	var porcentaje = clampf(float(ps_actual) / float(ps_max), 0.0, 1.0)
	var nuevo_ancho = ancho_barra_max * porcentaje

	if not animar:
		barra_salud_1.size.x = nuevo_ancho
		barra_salud_2.size.x = nuevo_ancho
		_on_barra_salud_resized()
		return

	tween_salud = create_tween()
	
	# Animar ambas barras al mismo tiempo
	tween_salud.parallel().tween_property(barra_salud_1, "size", Vector2(nuevo_ancho, barra_salud_1.size.y), 0.5)
	tween_salud.parallel().tween_property(barra_salud_2, "size", Vector2(nuevo_ancho, barra_salud_2.size.y), 0.5)

## Anima a la vez la barra y el número de PS desde `ps_desde` hasta `ps_hasta`
## (sub_806F8AC + PartyMenuDoPrintHP de pokeruby, al usar una medicina) y
## vuelve cuando termina: se puede esperar con await. La duración es
## proporcional a la parte de la barra que cambia (DURACION_PS_MIN-MAX).
func animar_ps(ps_desde: int, ps_hasta: int, ps_max: int) -> void:
	if not barra_salud_1 or not barra_salud_2:
		return
	if tween_salud:
		tween_salud.kill()
	if ps_max <= 0 or ps_desde == ps_hasta:
		_colocar_ps(float(ps_hasta), ps_max)
		return
	var fraccion: float = float(absi(ps_hasta - ps_desde)) / float(ps_max)
	var duracion: float = clampf(fraccion * DURACION_PS_MAX, DURACION_PS_MIN, DURACION_PS_MAX)
	_colocar_ps(float(ps_desde), ps_max)
	tween_salud = create_tween()
	tween_salud.tween_method(_colocar_ps.bind(ps_max), float(ps_desde), float(ps_hasta), duracion)
	await tween_salud.finished
	_colocar_ps(float(ps_hasta), ps_max)

## Pone la barra (ancho y color) y el número de PS en el valor `ps` (entero
## redondeado), sin animación. Paso de animar_ps.
func _colocar_ps(ps: float, ps_max: int) -> void:
	var ancho: float = ancho_barra_max * clampf(ps / float(maxi(ps_max, 1)), 0.0, 1.0)
	barra_salud_1.size.x = ancho
	barra_salud_2.size.x = ancho
	_on_barra_salud_resized()
	label_ps.text = str(roundi(ps))

func _on_barra_salud_resized() -> void:
	"""Cambia el color de la barra según el porcentaje de salud"""
	if not barra_salud_1:
		return
		
	var ancho_actual = barra_salud_1.size.x
	var porcentaje = ancho_actual / ancho_barra_max
	
	# Umbrales de GetHPBarLevel (battle_interface.c): rojo < 10/48, amarillo < 25/48.
	if porcentaje < 10.0 / 48.0:
		barra_salud_1.color = Color.hex(0xa84048ff)
		barra_salud_2.color = Color.hex(0xfb7f67ff)
	elif porcentaje < 25.0 / 48.0:
		barra_salud_1.color = Color.hex(0xc8a808ff)
		barra_salud_2.color = Color.hex(0xf8e038ff)
	else:  # Más del 50% - Verde
		barra_salud_1.color = Color.hex(0x58d080ff)
		barra_salud_2.color = Color.hex(0x70f8a8ff)

# --- FONDO DE LA CAJA PARA HUEVOS ---

## Cambia el fondo de la caja a la variante sin "Nv", barra ni "/" (o la
## restaura) conservando el frame actual (normal, cursor, seleccionada...).
func _usar_fondo_huevo(activo: bool) -> void:
	if _frames_fondo_normal == null:
		_frames_fondo_normal = sprite_frames
	var destino: SpriteFrames = _obtener_frames_fondo_huevo() if activo else _frames_fondo_normal
	if destino == null or sprite_frames == destino:
		return
	var frame_previo := frame
	sprite_frames = destino
	frame = frame_previo

## Duplica los frames del fondo apuntando cada región a la variante "-huevo"
## de su atlas. null si la escena no usa un atlas con variante de huevo.
func _obtener_frames_fondo_huevo() -> SpriteFrames:
	if _frames_fondo_huevo != null:
		return _frames_fondo_huevo
	if _frames_fondo_normal == null or not _frames_fondo_normal.has_animation(&"default"):
		return null
	var copia := SpriteFrames.new()
	if not copia.has_animation(&"default"):
		copia.add_animation(&"default")
	copia.set_animation_speed(&"default", _frames_fondo_normal.get_animation_speed(&"default"))
	copia.set_animation_loop(&"default", _frames_fondo_normal.get_animation_loop(&"default"))
	for i in range(_frames_fondo_normal.get_frame_count(&"default")):
		var original := _frames_fondo_normal.get_frame_texture(&"default", i) as AtlasTexture
		if original == null or original.atlas == null:
			return null
		var ruta_huevo := original.atlas.resource_path.get_basename() + SUFIJO_FONDO_HUEVO
		if not ResourceLoader.exists(ruta_huevo):
			return null
		var region := AtlasTexture.new()
		region.atlas = load(ruta_huevo) as Texture2D
		region.region = original.region
		copia.add_frame(&"default", region, _frames_fondo_normal.get_frame_duration(&"default", i))
	_frames_fondo_huevo = copia
	return _frames_fondo_huevo

# --- MODO MT/MO: PUEDE / NO PUEDE / APRENDIDO ---

## `sub_806D668` + `DrawMonDescriptorStatus`: quita la barra, la "/" y los números de
## PS (y el estado) y muestra el rótulo `descriptor` (DatosMaquinas.Descriptor).
func mostrar_descriptor(descriptor: int) -> void:
	if pokemon_actual == null:
		return
	descriptor_actual = descriptor
	if not pokemon_actual.huevo:
		var sin_ps := _obtener_frames_fondo_sin_ps()
		if sin_ps != null and sprite_frames != sin_ps:
			var frame_previo := frame
			sprite_frames = sin_ps
			frame = frame_previo
	label_ps.visible = false
	label_ps_max.visible = false
	barra_salud_1.visible = false
	barra_salud_2.visible = false
	estado_sprite.visible = false
	if _sprite_descriptor == null:
		_sprite_descriptor = Sprite2D.new()
		_sprite_descriptor.name = "descriptor"
		_sprite_descriptor.texture = TEXTURA_DESCRIPTORES
		_sprite_descriptor.centered = false
		_sprite_descriptor.region_enabled = true
		add_child(_sprite_descriptor)
	_sprite_descriptor.region_rect = Rect2(Vector2(0, descriptor * TAMANO_DESCRIPTOR.y), TAMANO_DESCRIPTOR)
	_sprite_descriptor.position = posicion_descriptor
	_sprite_descriptor.visible = true


## Vuelve a la caja normal (barra y números de PS) sin recargar el icono.
func quitar_descriptor() -> void:
	if descriptor_actual < 0:
		return
	_ocultar_descriptor()
	if pokemon_actual == null:
		return
	_usar_fondo_huevo(pokemon_actual.huevo)
	if not pokemon_actual.huevo:
		barra_salud_1.visible = true
		barra_salud_2.visible = true
		actualizar_sprite_estado(pokemon_actual)


func _ocultar_descriptor() -> void:
	descriptor_actual = -1
	if _sprite_descriptor != null:
		_sprite_descriptor.visible = false
	label_ps.visible = true
	label_ps_max.visible = true


## Fotogramas del fondo normal con `zona_sin_ps` copiada de la variante de huevo:
## sin barra, "/" ni números, pero con "Nv". null si no hay variante de huevo.
func _obtener_frames_fondo_sin_ps() -> SpriteFrames:
	if _frames_fondo_sin_ps != null:
		return _frames_fondo_sin_ps
	if _frames_fondo_normal == null:
		_frames_fondo_normal = sprite_frames
	var huevo := _obtener_frames_fondo_huevo()
	if _frames_fondo_normal == null or huevo == null:
		return null
	var copia := SpriteFrames.new()
	if not copia.has_animation(&"default"):
		copia.add_animation(&"default")
	copia.set_animation_speed(&"default", _frames_fondo_normal.get_animation_speed(&"default"))
	copia.set_animation_loop(&"default", _frames_fondo_normal.get_animation_loop(&"default"))
	for i in range(_frames_fondo_normal.get_frame_count(&"default")):
		var normal := _imagen_fotograma(_frames_fondo_normal.get_frame_texture(&"default", i) as AtlasTexture)
		var sin_ps := _imagen_fotograma(huevo.get_frame_texture(&"default", i) as AtlasTexture)
		if normal == null or sin_ps == null or normal.get_size() != sin_ps.get_size():
			return null
		normal.blit_rect(sin_ps, zona_sin_ps, zona_sin_ps.position)
		copia.add_frame(&"default", ImageTexture.create_from_image(normal), _frames_fondo_normal.get_frame_duration(&"default", i))
	_frames_fondo_sin_ps = copia
	return _frames_fondo_sin_ps


func _imagen_fotograma(textura: AtlasTexture) -> Image:
	if textura == null or textura.atlas == null:
		return null
	var imagen: Image = textura.atlas.get_image()
	if imagen == null:
		return null
	if imagen.is_compressed():
		imagen.decompress()
	imagen.convert(Image.FORMAT_RGBA8)
	return imagen.get_region(Rect2i(textura.region))
