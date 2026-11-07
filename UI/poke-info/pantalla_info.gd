## PantallaInfoPokemon
# Estructura principal de la pantalla de información de Pokémon.
#
# Esta escena gestiona la visualización de datos de un Pokémon, incluyendo:
# - Información básica (nombre, especie, nivel, sexo, marcas, entrenador, habilidad, pokéball, sprite, notas)
# - Estadísticas (objeto, cintas, stats, experiencia, barra de experiencia)
# - Movimientos (lista, PP, tipo, potencia, precisión, menú de intercambio de movimientos)
# - Movimientos de concurso (categoría, corazones de EXHIB./INHIB., descripción de concurso)
# - Estado y Pokerus (iconos, visibilidad animada)
#
# Navegación:
# - Entre páginas (info básica, estadísticas, mov. combate, mov. concurso)
# - Entre Pokémon en la lista
# - Menú de movimientos con cursor móvil y fijo, intercambio de posiciones
#
# Uso con launcher_directo_info:
# - El nodo puede ser instanciado y mostrado desde cualquier escena usando el método
#   `mostrar_info_lista_pokemon(pokemones, indice_inicial)`
# - Permite mostrar la info de uno o varios Pokémon y navegar entre ellos.
# - Al cerrar la pantalla, emite la señal `pantalla_cerrada` y notifica el último Pokémon visto.
#
# Ejemplo de uso:
#   var pantalla_info = PantallaInfoPokemon.new()
#   add_child(pantalla_info)
#   pantalla_info.mostrar_info_lista_pokemon([pokemon1, pokemon2], 0)
#
# El sistema está preparado para integrarse con un launcher o menú externo que requiera mostrar
# la información detallada de un Pokémon de forma directa y navegable.
extends Node2D

class_name PantallaInfoPokemon

# Importar las clases necesarias
const PokeballSprite_SCN = preload("res://UI/pokeball_sprite.gd")
const PokemonSprite_SCN = preload("res://UI/pokemon_sprite.gd")
## Colores del nombre del EO (paleta graphics/fonts/unknown_81E6692.pal de pokeruby).
const TEXTO_EO_VARON: LabelSettings = preload("res://UI/poke-info/texto_eo_varon.tres")
const TEXTO_EO_MUJER: LabelSettings = preload("res://UI/poke-info/texto_eo_mujer.tres")

## Variante de la pantalla para un huevo (pokemon_summary_screen.c): cabecera ESTADO en
## lugar de HABILIDAD, sin "Nº" y con la pestaña de un solo círculo. Generadas con
## herramientas/generar_info_huevo.py.
const TEXTURA_PAG1: Texture2D = preload("res://UI/poke-info/pantalla-info-pag1.png")
const TEXTURA_PAG1_HUEVO: Texture2D = preload("res://UI/poke-info/pantalla-info-pag1-huevo.png")
const TEXTURA_PESTANA_HUEVO: Texture2D = preload("res://UI/poke-info/pantalla-info-titulos-huevo.png")
const TEXTURA_SPRITE_HUEVO: Texture2D = preload("res://graficos/crianza/huevo.png")
const TEXTO_NOTA_HUEVO: String = "(HUEVO)."
const TEXTO_NOTA_VISTO: String = "(visto)."
const TEXTO_NOTA_FATIDICO: String = "encuentro repentino."
const TEXTO_NOTA_INTERCAMBIO: String = "Recibido en un intercambio."
const TEXTO_INTERROGANTE: String = "(?)"
## Fotograma "(?)" de graficos/tipos-pokemon.png (el tipo desconocido del huevo).
const FRAME_TIPO_DESCONOCIDO: int = 18
## Ciclos que le quedan al huevo (BasePokemon.felicidad) para cada mensaje de estado.
const CICLOS_HUEVO_INMINENTE: int = 5
const CICLOS_HUEVO_PRONTO: int = 10
const CICLOS_HUEVO_ALGO_DE_TIEMPO: int = 40
const TEXTO_HUEVO_INMINENTE: String = "Está haciendo ruidos.\n¡Está a punto de abrirse!"
const TEXTO_HUEVO_PRONTO: String = "A veces se mueve.\nDebería abrirse pronto."
const TEXTO_HUEVO_ALGO_DE_TIEMPO: String = "¿Qué nacerá de éste?\nAún le queda para abrirse."
const TEXTO_HUEVO_MUCHO_TIEMPO: String = "Parece que a este HUEVO le\nva a costar mucho abrirse."
const TEXTO_HUEVO_GUARDERIA: String = "Extraño HUEVO hallado por\nla pareja de la GUARDERÍA."
const TEXTO_HUEVO_OTRO_ORIGEN: String = "Un peculiar HUEVO POKéMON\nobtenido en un lugar agradable."

## Sonido (pokemon_summary_screen.c): SE_SELECT al cambiar de página o de Pokémon, mover el
## cursor de movimientos y salir; el grito suena al mostrar un Pokémon (no un huevo).
const SONIDO_SELECCION: String = "SE_SELECT"
## SE_HAZURE del decomp (acción no válida) no existe en Singleton.se: se usa SE_FAILURE en su lugar.
## Buscar "SE_HAZURE" para localizar todos los usos.
const SONIDO_HAZURE: String = "SE_FAILURE"
const RUTA_GRITO: String = "res://Audio/SE/Cries/%03dCry.ogg"

## Páginas (PSS_PAGE_* de pokemon_summary_screen.c).
const PAGINA_INFO: int = 0
const PAGINA_HABILIDADES: int = 1
const PAGINA_MOV_COMBATE: int = 2
const PAGINA_MOV_CONCURSO: int = 3
## MOV. COMBATE y MOV. CONCURSO comparten el panel y la caja; solo cambia el fondo
## (BG1CNT 0xA00 / 0xC00) y el contenido.
const TEXTURA_PANEL_COMBATE: Texture2D = preload("res://UI/poke-info/pantalla-info-pag3v.png")
const TEXTURA_PANEL_CONCURSO: Texture2D = preload("res://UI/poke-info/pantalla-info-pag3v-concurso.png")
const TEXTURA_CAJA_COMBATE: Texture2D = preload("res://UI/poke-info/pantalla-info-pag3-extra.png")
const TEXTURA_CAJA_CONCURSO: Texture2D = preload("res://UI/poke-info/pantalla-info-pag3-extra-concurso.png")
## Fotogramas de pantalla-info-titulos.png: el de modo menú (CAMBIO) va justo después.
const FRAME_TITULO_MOV_COMBATE: int = 2
const FRAME_TITULO_MOV_CONCURSO: int = 4

# Referencias a los elementos de la UI
@onready var pantalla_pag1 = $"Pantalla-info-pag1"
@onready var pantalla_pag2 = $"Pantalla-info-pag2v"
@onready var pantalla_pag3 = $"Pantalla-info-pag3v"
@onready var pantalla_pag3_extra = $"Pantalla-info-pag3-extra"
@onready var mm_salir = $"Pantalla-info-pag3v/salir"
@onready var titulo_sprite = $"Pantalla-info-pestanas"
@onready var pokeball_sprite = $"Pantalla-info-pag1/PokeballSprite"  # Ruta corregida
@onready var pokemon_sprite = $"Pantalla-info-pag1/PokemonSprite"  # Sprite del Pokémon
@onready var pantalla_info_estado = $"Pantalla-info-estado"
@onready var pantalla_info_estado_icono = $"Pantalla-info-estado/Pantalla-info-estado-icono"

# Página 1 - Información básica
@onready var num_dex = $"Pantalla-info-pag1/num_dex"
@onready var mote = $"Pantalla-info-pag1/mote"
@onready var nombre_interno = $"Pantalla-info-pag1/nombre_interno"
@onready var nivel = $"Pantalla-info-pag1/nivel"
@onready var sexo = $"Pantalla-info-pag1/sexo"
@onready var variocolor = $"Pantalla-info-pag1/variocolor"
@onready var tipo1 = $"Pantalla-info-pag1/tipo1"
@onready var tipo2 = $"Pantalla-info-pag1/tipo2"
@onready var marca_circulo = $"Pantalla-info-pag1/marca_circulo"
@onready var marca_cuadrado = $"Pantalla-info-pag1/marca_cuadrado"
@onready var marca_triangulo = $"Pantalla-info-pag1/marca_triangulo"
@onready var marca_corazon = $"Pantalla-info-pag1/marca_corazon"
@onready var eo_nombre = $"Pantalla-info-pag1/eo_nombre"
@onready var eo_id = $"Pantalla-info-pag1/eo_id"
@onready var habilidad = $"Pantalla-info-pag1/habilidad"
@onready var habilidad_descripcion = $"Pantalla-info-pag1/habilidad_descripcion"
@onready var notas = $"Pantalla-info-pag1/notas"
@onready var curado = $"Pantalla-info-pag1/curado"

# Página 2 - Estadísticas
@onready var objeto = $"Pantalla-info-pag2v/objeto"
@onready var cintas = $"Pantalla-info-pag2v/cintas"
@onready var ps = $"Pantalla-info-pag2v/ps"
@onready var ataque = $"Pantalla-info-pag2v/ataque"
@onready var defensa = $"Pantalla-info-pag2v/defensa"
@onready var at_esp = $"Pantalla-info-pag2v/at_esp"
@onready var def_esp = $"Pantalla-info-pag2v/def_esp"
@onready var veloc = $"Pantalla-info-pag2v/veloc"
@onready var puntos_exp = $"Pantalla-info-pag2v/puntos_exp"
@onready var sig_nivel = $"Pantalla-info-pag2v/sig_nivel"
@onready var barra_exp = $"Pantalla-info-pag2v/BarraExp"

# Página 3 - Movimientos
@onready var mov1 = $"Pantalla-info-pag3v/mov1"
@onready var mov2 = $"Pantalla-info-pag3v/mov2"
@onready var mov3 = $"Pantalla-info-pag3v/mov3"
@onready var mov4 = $"Pantalla-info-pag3v/mov4"
@onready var pp1 = $"Pantalla-info-pag3v/pp1"
@onready var pp2 = $"Pantalla-info-pag3v/pp2"
@onready var pp3 = $"Pantalla-info-pag3v/pp3"
@onready var pp4 = $"Pantalla-info-pag3v/pp4"
@onready var mov_desc = $"Pantalla-info-pag3v/mov_desc"
@onready var mov_potencia = $"Pantalla-info-pag3-extra/mov_potencia"
@onready var mov_precision = $"Pantalla-info-pag3-extra/mov_precision"
@onready var cursor_movil = $"Pantalla-info-pag3v/cursor_movil"
@onready var cursor_fijo = $"Pantalla-info-pag3v/cursor_fijo"

# Nodos de sprites de tipo para los movimientos
@onready var tipo_mov1 = $"Pantalla-info-pag3v/tipo1"
@onready var tipo_mov2 = $"Pantalla-info-pag3v/tipo2"
@onready var tipo_mov3 = $"Pantalla-info-pag3v/tipo3"
@onready var tipo_mov4 = $"Pantalla-info-pag3v/tipo4"

# Página MOV. CONCURSO
@onready var categorias_mov: Array[Sprite2D] = [
	$"Pantalla-info-pag3v/categoria1", $"Pantalla-info-pag3v/categoria2",
	$"Pantalla-info-pag3v/categoria3", $"Pantalla-info-pag3v/categoria4",
]
@onready var etiqueta_exhib: Label = $"Pantalla-info-pag3-extra/etiqueta_exhib"
@onready var etiqueta_inhib: Label = $"Pantalla-info-pag3-extra/etiqueta_inhib"
@onready var corazones: Node2D = $"Pantalla-info-pag3-extra/Corazones"
var sprites_corazon: Array[Sprite2D] = []

# Estado de la pantalla
var pagina_actual: int = 0  # PAGINA_INFO .. PAGINA_MOV_CONCURSO
var movimiento_seleccionado: int = 0  # Para la página de movimientos
var pokemon_actual: BasePokemon
var lista_pokemon: Array[BasePokemon] = []  # Lista completa de Pokémon disponibles
var indice_pokemon_actual: int = 0  # Índice del Pokémon actual en la lista
var activo: bool = false
var tween_estado: Tween = null
var tween_pag2: Tween = null
var tween_pag3: Tween = null
var pestana_huevo: Sprite2D = null
var _reproductor_se: AudioStreamPlayer = null
var _reproductor_grito: AudioStreamPlayer = null

var modo_menu_movimientos: bool = false
# Estado del modo cambio de posición de movimientos
var modo_cambio_posicion_movimientos: bool = false
var posicion_cambio_movimiento: int = -1

# Señales
signal pantalla_cerrada(indice_final: int)
signal pokemon_cambiado(pokemon: BasePokemon, indice: int)  # Para notificar cambios

func _ready() -> void:
	# Inicialmente oculta
	self.visible = false
	self.activo = false
	pantalla_pag2.visible = false
	pantalla_pag3.visible = false
	pantalla_pag3_extra.visible = false
	mm_salir.visible = false
	cursor_movil.visible = false
	cursor_fijo.visible = false
	modo_menu_movimientos = false
	for corazon: Node in corazones.get_children():
		sprites_corazon.append(corazon as Sprite2D)

	# Pestaña de un huevo: solo el primer círculo (fotograma 0 del atlas de títulos).
	pestana_huevo = Sprite2D.new()
	pestana_huevo.texture = TEXTURA_PESTANA_HUEVO
	pestana_huevo.centered = false
	pestana_huevo.region_enabled = true
	pestana_huevo.region_rect = Rect2(0, 0, 240, 16)
	pestana_huevo.visible = false
	add_child(pestana_huevo)
	move_child(pestana_huevo, titulo_sprite.get_index() + 1)

	# Inicializar en página 1
	mostrar_pagina(0)

# --- SONIDO ---

## Reproduce `sonido` (clave de Singleton.se).
func _reproducir_se(sonido: String) -> void:
	if not Singleton.se.has(sonido):
		push_warning("[PANTALLA_INFO] Sonido no registrado: %s" % sonido)
		return
	if not is_instance_valid(_reproductor_se):
		_reproductor_se = AudioStreamPlayer.new()
		_reproductor_se.name = "ReproductorSE"
		add_child(_reproductor_se)
	_reproductor_se.stream = Singleton.se[sonido]
	_reproductor_se.play()

## Grito del Pokémon actual (SummaryScreen_SpritePlayCry): corta el anterior y no suena
## con un huevo.
func _reproducir_grito() -> void:
	_detener_grito()
	if pokemon_actual == null or pokemon_actual.huevo or pokemon_actual.numero_nacional <= 0:
		return
	var ruta := RUTA_GRITO % pokemon_actual.numero_nacional
	if not ResourceLoader.exists(ruta):
		return
	if not is_instance_valid(_reproductor_grito):
		_reproductor_grito = AudioStreamPlayer.new()
		_reproductor_grito.name = "ReproductorGrito"
		add_child(_reproductor_grito)
	_reproductor_grito.stream = load(ruta) as AudioStream
	_reproductor_grito.play()

## StopCryAndClearCrySongs.
func _detener_grito() -> void:
	if is_instance_valid(_reproductor_grito):
		_reproductor_grito.stop()

# --- FUNCIONES DEL MENÚ DE MOVIMIENTOS ---

func entrar_modo_menu_movimientos() -> void:
	"""Activa el modo menú de movimientos en la página 3."""
	if not pokemon_actual or pokemon_actual.movimientos.size() == 0:
		return

	_reproducir_se(SONIDO_SELECCION)
	modo_menu_movimientos = true
	mm_salir.visible = true
	movimiento_seleccionado = 0
	titulo_sprite.frame = frame_titulo()
	# Mostrar cursor móvil
	if cursor_movil:
		cursor_movil.visible = true
		actualizar_posicion_cursor_movimientos()

	# Animar entrada de pantalla_pag3_extra
	if pantalla_pag3_extra:
		pantalla_pag3_extra.visible = true
		pantalla_pag3_extra.position.x = 80
		var tween = create_tween()
		tween.tween_property(pantalla_pag3_extra, "position:x", 0, 0.1)

	print("📱 [PANTALLA_INFO] Modo menú movimientos activado")

func salir_modo_menu_movimientos() -> void:
	"""Sale del modo menú de movimientos."""
	_reproducir_se(SONIDO_SELECCION)
	modo_menu_movimientos = false
	mm_salir.visible = false
	titulo_sprite.frame = frame_titulo()

	# Ocultar cursor móvil
	if cursor_movil:
		cursor_movil.visible = false

	# Animar salida de pantalla_pag3_extra
	if pantalla_pag3_extra:
		var tween = create_tween()
		tween.tween_property(pantalla_pag3_extra, "position:x", 80, 0.1)
		tween.tween_callback(Callable(pantalla_pag3_extra, "hide"))

	print("📱 [PANTALLA_INFO] Modo menú movimientos desactivado")

func mover_cursor_movimientos_arriba() -> void:
	"""Mueve el cursor hacia arriba en el menú de movimientos."""
	if not pokemon_actual or pokemon_actual.movimientos.size() == 0:
		return

	var num_movimientos = pokemon_actual.movimientos.size()
	var num_opciones = min(4, num_movimientos) + 1  # +1 para SALIR

	_reproducir_se(SONIDO_SELECCION)
	# Mover hacia arriba
	movimiento_seleccionado = (movimiento_seleccionado - 1 + num_opciones) % num_opciones

	# Si vamos más allá de los movimientos disponibles, saltar a SALIR
	if movimiento_seleccionado >= num_movimientos:
		movimiento_seleccionado = num_movimientos  # Posición de SALIR

	actualizar_posicion_cursor_movimientos()

func mover_cursor_movimientos_abajo() -> void:
	"""Mueve el cursor hacia abajo en el menú de movimientos."""
	if not pokemon_actual or pokemon_actual.movimientos.size() == 0:
		return

	var num_movimientos = pokemon_actual.movimientos.size()
	var num_opciones = min(4, num_movimientos) + 1  # +1 para SALIR

	_reproducir_se(SONIDO_SELECCION)
	# Mover hacia abajo
	movimiento_seleccionado = (movimiento_seleccionado + 1) % num_opciones

	# Si vamos más allá de los movimientos disponibles, ir a SALIR
	if movimiento_seleccionado >= num_movimientos:
		movimiento_seleccionado = num_movimientos  # Posición de SALIR

	actualizar_posicion_cursor_movimientos()

func actualizar_posicion_cursor_movimientos() -> void:
	"""Actualiza la posición del cursor móvil en el menú de movimientos."""
	if not cursor_movil:
		return

	var num_movimientos = pokemon_actual.movimientos.size() if pokemon_actual else 0

	# Posición Y base del primer movimiento + offset por línea (16 píxeles entre opciones)
	var y_base = 16  # Ajustar según la posición del primer movimiento en la escena
	var y_position = y_base + (movimiento_seleccionado * 16)

	# Si estamos en SALIR (después del último movimiento)
	if movimiento_seleccionado >= num_movimientos:
		# SALIR está justo debajo del 4to movimiento
		y_position = y_base + (4 * 16)
		mov_desc.text = ""
		mov_potencia.text = "---"
		mov_precision.text = "---"
		DibujoConcurso.pintar_corazones(sprites_corazon, 0, 0)
	elif es_pagina_concurso():
		var movi_concurso: Movimiento = pokemon_actual.movimientos[movimiento_seleccionado]
		mov_desc.text = movi_concurso.get_descripcion_concurso()
		DibujoConcurso.pintar_corazones(sprites_corazon, movi_concurso.get_atractivo(), movi_concurso.get_interferencia())
	else:
		var movi: Movimiento = pokemon_actual.movimientos[movimiento_seleccionado]
		mov_desc.text = movi.get_descripcion()
		mov_potencia.text = "---" if movi.get_potencia() == -1 or movi.get_potencia() == 0 else str(movi.get_potencia())
		mov_precision.text = "---" if movi.get_precision() == -1 or movi.get_precision() == 0 else str(movi.get_precision())

	cursor_movil.position.y = y_position
	print("🎯 [MOVIMIENTOS] Cursor en movimiento %d (Y: %d)" % [movimiento_seleccionado, y_position])

func seleccionar_movimiento() -> void:
	"""Selecciona el movimiento actual o ejecuta SALIR."""
	var num_movimientos = pokemon_actual.movimientos.size() if pokemon_actual else 0

	# Si estamos en SALIR
	if movimiento_seleccionado >= num_movimientos:
		salir_modo_menu_movimientos()
		return

	# Si hay 2 o más movimientos, activar modo cambio de posición
	if num_movimientos >= 2:
		_reproducir_se(SONIDO_SELECCION)
		modo_cambio_posicion_movimientos = true
		posicion_cambio_movimiento = movimiento_seleccionado
		# Marcar la posición con cursor_fijo
		if cursor_fijo:
			cursor_fijo.visible = true
			cursor_fijo.position.y = cursor_movil.position.y
		print("🔄 [MOVIMIENTOS] Modo cambio de posición activado en %d" % movimiento_seleccionado)
		return

	# Con un solo movimiento no hay nada que intercambiar: SE_HAZURE (en Singleton.se es
	# SE_FAILURE) y el cursor se queda donde está (MonKnowsMultipleMoves en el decomp).
	_reproducir_se(SONIDO_HAZURE)

func _input(event: InputEvent) -> void:
	if not activo:
		return

	# Si estamos en modo intercambio de movimientos
	if modo_cambio_posicion_movimientos:
		if event.is_action_pressed("btn_arriba"):
			mover_cursor_intercambio_arriba()
		elif event.is_action_pressed("btn_abajo"):
			mover_cursor_intercambio_abajo()
		elif event.is_action_pressed("btn_accion"):
			realizar_intercambio_movimientos()
		elif event.is_action_pressed("btn_cancelar"):
			cancelar_intercambio_movimientos(false)
		return
	# Si estamos en modo menú de movimientos
	elif modo_menu_movimientos:
		if event.is_action_pressed("btn_arriba"):
			mover_cursor_movimientos_arriba()
		elif event.is_action_pressed("btn_abajo"):
			mover_cursor_movimientos_abajo()
		elif event.is_action_pressed("btn_accion"):
			seleccionar_movimiento()
		elif event.is_action_pressed("btn_cancelar"):
			salir_modo_menu_movimientos()
		return

	# Navegación normal (un huevo solo tiene la página de información)
	if event.is_action_pressed("btn_izquierda"):
		if pagina_actual > 0:
			pagina_anterior()
	elif event.is_action_pressed("btn_derecha"):
		if pagina_actual < PAGINA_MOV_CONCURSO and not es_huevo_actual():
			pagina_siguiente()
	elif event.is_action_pressed("btn_arriba"):
		# En otras páginas: navegar Pokémon
		if indice_pokemon_actual > 0:
			pokemon_anterior()
	elif event.is_action_pressed("btn_abajo"):
		# En otras páginas: navegar Pokémon
		if indice_pokemon_actual < lista_pokemon.size() - 1:
			pokemon_siguiente()
	elif event.is_action_pressed("btn_accion"):
		if pagina_actual >= PAGINA_MOV_COMBATE:
			entrar_modo_menu_movimientos()
	elif event.is_action_pressed("btn_cancelar"):
		cerrar_pantalla()
# --- FUNCIONES DE INTERCAMBIO DE MOVIMIENTOS ---
func mover_cursor_intercambio_arriba() -> void:
	var num_movimientos = pokemon_actual.movimientos.size() if pokemon_actual else 0
	_reproducir_se(SONIDO_SELECCION)
	movimiento_seleccionado = (movimiento_seleccionado - 1 + num_movimientos) % num_movimientos
	actualizar_posicion_cursor_movimientos()

func mover_cursor_intercambio_abajo() -> void:
	var num_movimientos = pokemon_actual.movimientos.size() if pokemon_actual else 0
	_reproducir_se(SONIDO_SELECCION)
	movimiento_seleccionado = (movimiento_seleccionado + 1) % num_movimientos
	actualizar_posicion_cursor_movimientos()

func realizar_intercambio_movimientos() -> void:
	# var num_movimientos = pokemon_actual.movimientos.size() if pokemon_actual else 0
	if posicion_cambio_movimiento == movimiento_seleccionado:
		# Si selecciona el mismo, cancelar
		cancelar_intercambio_movimientos(false)
		return
	# Intercambiar movimientos
	var temp = pokemon_actual.movimientos[posicion_cambio_movimiento]
	pokemon_actual.movimientos[posicion_cambio_movimiento] = pokemon_actual.movimientos[movimiento_seleccionado]
	pokemon_actual.movimientos[movimiento_seleccionado] = temp
	print("🔄 [MOVIMIENTOS] Intercambiados %d <-> %d" % [posicion_cambio_movimiento, movimiento_seleccionado])
	# Actualizar UI
	llenar_pagina_movimientos()
	actualizar_posicion_cursor_movimientos()
	# Salir del modo intercambio
	cancelar_intercambio_movimientos(true)

func cancelar_intercambio_movimientos(cambiado: bool) -> void:
	_reproducir_se(SONIDO_SELECCION)
	modo_cambio_posicion_movimientos = false
	if !cambiado:
		movimiento_seleccionado = posicion_cambio_movimiento
		actualizar_posicion_cursor_movimientos()
	posicion_cambio_movimiento = -1
	if cursor_fijo:
		cursor_fijo.visible = false

# --- API PÚBLICA ---

func mostrar_info_pokemon(pokemon: BasePokemon) -> void:
	"""
	Muestra la información del Pokémon especificado (versión legacy).
	Para compatibilidad con código existente.
	"""
	mostrar_info_lista_pokemon([pokemon], 0)

func mostrar_info_lista_pokemon(pokemones: Array, indice_inicial: int = 0) -> void:
	"""
	Muestra la información de una lista de Pokémon, empezando por el índice especificado.
	Args:
		pokemones: Array de BasePokemon o Array[BasePokemon]
		indice_inicial: Índice del Pokémon inicial a mostrar
	"""
	# Convertir Array genérico a Array[BasePokemon] si es necesario
	lista_pokemon.clear()
	for poke in pokemones:
		if poke is BasePokemon:
			lista_pokemon.append(poke)

	if lista_pokemon.is_empty():
		print("❌ [PANTALLA_INFO] No se proporcionaron Pokémon válidos")
		return

	# Validar índice inicial
	indice_inicial = clamp(indice_inicial, 0, lista_pokemon.size() - 1)
	indice_pokemon_actual = indice_inicial

	# Cargar el Pokémon inicial
	cargar_pokemon_actual()

	print("📱 [PANTALLA_INFO] Lista cargada: %d Pokémon, mostrando índice %d" % [lista_pokemon.size(), indice_inicial])

func cargar_pokemon_actual() -> void:
	"""
	Carga los datos del Pokémon actualmente seleccionado.
	"""
	if indice_pokemon_actual < 0 or indice_pokemon_actual >= lista_pokemon.size():
		print("❌ [PANTALLA_INFO] Índice inválido: %d" % indice_pokemon_actual)
		return

	pokemon_actual = lista_pokemon[indice_pokemon_actual]

	# Llenar todos los datos
	llenar_pagina_info_basica()
	llenar_pagina_estadisticas()
	llenar_pagina_movimientos()
	aplicar_modo_huevo(es_huevo_actual())

	# Si estamos en una página de movimientos, actualizar info del movimiento
	if pagina_actual >= PAGINA_MOV_COMBATE:
		movimiento_seleccionado = 0  # Reset al primer movimiento

	# Mostrar la pantalla si no estaba activa
	if not self.visible:
		pagina_actual = 0
		movimiento_seleccionado = 0
		mostrar_pagina(0)
		self.visible = true
		self.activo = true

	# Emitir señal de cambio (para posibles listeners externos)
	pokemon_cambiado.emit(pokemon_actual, indice_pokemon_actual)

	_reproducir_grito()

	print("🔄 [PANTALLA_INFO] Pokémon cargado: %s (%d/%d)" % [pokemon_actual.nombre_interno, indice_pokemon_actual + 1, lista_pokemon.size()])

func es_huevo_actual() -> bool:
	return pokemon_actual != null and pokemon_actual.huevo

## Cambia el aspecto de la pantalla entre un Pokémon y un huevo: fondo y pestaña de la
## variante de huevo, y vuelta a la página de información (un huevo no tiene más).
func aplicar_modo_huevo(es_huevo: bool) -> void:
	pantalla_pag1.texture = TEXTURA_PAG1_HUEVO if es_huevo else TEXTURA_PAG1
	pestana_huevo.visible = es_huevo
	titulo_sprite.visible = not es_huevo
	if es_huevo and pagina_actual != 0:
		pagina_actual = 0
		pantalla_pag2.visible = false
		pantalla_pag3.visible = false
		pantalla_pag3_extra.visible = false
		mm_salir.visible = false
	if not es_huevo:
		titulo_sprite.frame = frame_titulo()

## Notas del entrenador (PokemonSummaryScreen_PrintTrainerMemo): naturaleza y, en la línea
## siguiente, cómo se conoció al Pokémon:
## - nivel de encuentro 0: nacido de un huevo, "Nv5, LUGAR (HUEVO)."
## - encuentro fatídico: "Nv7, encuentro repentino."
## - sin lugar conocido: "Recibido en un intercambio."
## - resto: "Nv7, LUGAR (visto)."
static func texto_notas_encuentro(naturaleza: String, nivel: int, lugar: String, fatidico: bool) -> String:
	var texto := ""
	if naturaleza != "":
		texto = "Naturaleza [color=red]" + naturaleza.to_upper() + "[/color],"
	var lugar_rojo := "[color=red]" + lugar + "[/color]"
	if nivel == 0:
		texto += " Nv[color=red]" + str(Guarderia.NIVEL_HUEVO) + "[/color],
"
		texto += (lugar_rojo + " " if lugar != "" else "") + TEXTO_NOTA_HUEVO
	elif fatidico:
		texto += " Nv[color=red]" + str(nivel) + "[/color],
" + TEXTO_NOTA_FATIDICO
	elif lugar == "":
		texto += "
" + TEXTO_NOTA_INTERCAMBIO
	else:
		texto += " Nv[color=red]" + str(nivel) + "[/color],
" + lugar_rojo + " " + TEXTO_NOTA_VISTO
	return texto if texto != "" else "No hay información adicional."

## Mensaje de estado según los ciclos que le faltan al huevo (pokemon_summary_screen.c).
static func texto_estado_huevo(ciclos_restantes: int) -> String:
	if ciclos_restantes <= CICLOS_HUEVO_INMINENTE:
		return TEXTO_HUEVO_INMINENTE
	if ciclos_restantes <= CICLOS_HUEVO_PRONTO:
		return TEXTO_HUEVO_PRONTO
	if ciclos_restantes <= CICLOS_HUEVO_ALGO_DE_TIEMPO:
		return TEXTO_HUEVO_ALGO_DE_TIEMPO
	return TEXTO_HUEVO_MUCHO_TIEMPO

## Datos de la página de información de un huevo: sin especie, nivel, sexo ni habilidad;
## EO, ID y tipo desconocidos, y el estado en el recuadro que ocupa la habilidad.
func llenar_pagina_info_huevo() -> void:
	num_dex.visible = false
	nombre_interno.visible = false
	nivel.visible = false
	sexo.visible = false
	variocolor.visible = false
	habilidad.visible = false
	# El nombre baja junto a la Poké Ball, donde va el nivel en un Pokémon.
	mote.position = Vector2(26, 126)
	mote.text = pokemon_actual.get_nombre_mostrar()

	eo_nombre.text = TEXTO_INTERROGANTE
	eo_nombre.label_settings = eo_id.label_settings
	eo_id.text = TEXTO_INTERROGANTE
	tipo1.frame = FRAME_TIPO_DESCONOCIDO
	tipo1.visible = true
	tipo2.visible = false

	habilidad_descripcion.position.y = 74
	habilidad_descripcion.text = texto_estado_huevo(pokemon_actual.felicidad)
	notas.text = TEXTO_HUEVO_GUARDERIA if pokemon_actual.encuentro_lugar == Lugares.GUARDERIA_POKEMON 			else TEXTO_HUEVO_OTRO_ORIGEN

	if pokeball_sprite:
		pokeball_sprite.mostrar_estado_estatico(PokeballSprite.obtener_pokeball_de_objeto(pokemon_actual.encuentro_bola))
	if pokemon_sprite:
		pokemon_sprite.sprite_frames.clear_all()
		pokemon_sprite.sprite_frames.add_animation("principal")
		pokemon_sprite.sprite_frames.add_frame("principal", TEXTURA_SPRITE_HUEVO)
		pokemon_sprite.animation = "principal"
		pokemon_sprite.frame = 0
		pokemon_sprite.flip_h = false
	actualizar_estado_pantalla_info()

func cerrar_pantalla() -> void:
	"""
	Solicita el cierre de la pantalla pero no la cierra inmediatamente.
	El controlador padre manejará la transición y cerrará la pantalla cuando corresponda.
	"""
	# Desactivar entrada de usuario pero mantener visible
	self.activo = false
	_reproducir_se(SONIDO_SELECCION)
	_detener_grito()

	# Emitir señal con el último Pokémon visto para mantener la posición en pantallas anteriores
	if pokemon_actual and indice_pokemon_actual >= 0:
		pokemon_cambiado.emit(pokemon_actual, indice_pokemon_actual)
		print("📤 [PANTALLA_INFO] Solicitando cierre con último Pokémon visto: %s (índice %d)" % [pokemon_actual.get_nombre_mostrar(), indice_pokemon_actual])

	emit_signal("pantalla_cerrada", indice_pokemon_actual)

func ocultar_pantalla() -> void:
	"""
	Oculta la pantalla. Usado por el controlador padre durante las transiciones.
	"""
	self.visible = false
	print("👻 [PANTALLA_INFO] Pantalla ocultada por transición")

# --- NAVEGACIÓN ENTRE PÁGINAS ---

func pagina_siguiente() -> void:
	"""Cambia a la siguiente página."""
	_reproducir_se(SONIDO_SELECCION)
	pagina_actual = pagina_actual + 1
	if pagina_actual == PAGINA_HABILIDADES:
		animar_pagina(pantalla_pag2, true)
	elif pagina_actual == PAGINA_MOV_COMBATE:
		animar_pagina(pantalla_pag3, true)
	# MOV. COMBATE -> MOV. CONCURSO: el panel ya está a la vista, solo cambia el contenido.
	mostrar_pagina(pagina_actual)

func pagina_anterior() -> void:
	"""Cambia a la página anterior."""
	_reproducir_se(SONIDO_SELECCION)
	pagina_actual = pagina_actual - 1
	if pagina_actual == PAGINA_HABILIDADES:
		animar_pagina(pantalla_pag3, false)
	elif pagina_actual == PAGINA_INFO:
		animar_pagina(pantalla_pag2, false)
	# MOV. CONCURSO -> MOV. COMBATE: el panel sigue a la vista, solo cambia el contenido.
	mostrar_pagina(pagina_actual)

func mostrar_pagina(numero_pagina: int) -> void:
	"""
	Muestra una página específica y oculta las demás.
	"""
	# Ocultar todas las páginas con animación si estaban visibles
	# animar_pagina(pantalla_pag2, false)
	# animar_pagina(pantalla_pag3, false)
	pantalla_pag1.visible = true
	pantalla_pag3_extra.visible = false
	mm_salir.visible = false
	aplicar_vista_movimientos()
	if titulo_sprite:
		titulo_sprite.frame = frame_titulo(numero_pagina)

## Fotograma de la pestaña para `pagina` (por defecto la actual); en las páginas de
## movimientos, el modo menú usa el siguiente (CAMBIO en vez de INFO.).
func frame_titulo(pagina: int = pagina_actual) -> int:
	var menu := 1 if modo_menu_movimientos else 0
	match pagina:
		PAGINA_MOV_COMBATE:
			return FRAME_TITULO_MOV_COMBATE + menu
		PAGINA_MOV_CONCURSO:
			return FRAME_TITULO_MOV_CONCURSO + menu
	return pagina

func es_pagina_concurso() -> bool:
	return pagina_actual == PAGINA_MOV_CONCURSO

## Prepara el panel de movimientos para MOV. COMBATE o MOV. CONCURSO: fondo del panel y de
## la caja, iconos de tipo o de categoría y potencia/precisión o EXHIB./INHIB.
func aplicar_vista_movimientos() -> void:
	var concurso := es_pagina_concurso()
	pantalla_pag3.texture = TEXTURA_PANEL_CONCURSO if concurso else TEXTURA_PANEL_COMBATE
	pantalla_pag3_extra.texture = TEXTURA_CAJA_CONCURSO if concurso else TEXTURA_CAJA_COMBATE
	mov_potencia.visible = not concurso
	mov_precision.visible = not concurso
	etiqueta_exhib.visible = concurso
	etiqueta_inhib.visible = concurso
	corazones.visible = concurso
	actualizar_tipos_movimientos()
	actualizar_categorias_movimientos()

func animar_pagina(pagina: Node, mostrar: bool) -> void:
	var pos_visible = Vector2(80, 16)
	var pos_oculta = Vector2(240, 16)
	var tween = create_tween()
	if mostrar:
		pagina.position = pos_oculta
		pagina.visible = true
		tween.tween_property(pagina, "position", pos_visible, 0.1)
	else:
		tween.tween_property(pagina, "position", pos_oculta, 0.1)
		tween.tween_callback(Callable(pagina, "hide"))

# --- NAVEGACIÓN ENTRE POKÉMON ---

func pokemon_siguiente() -> void:
	"""Cambia al siguiente Pokémon en la lista."""
	if lista_pokemon.size() <= 1:
		return  # No hay más Pokémon para navegar

	_reproducir_se(SONIDO_SELECCION)
	var estado_visible_anterior = (lista_pokemon[indice_pokemon_actual].estado != Singleton.ProblemaEstado.NORMAL or lista_pokemon[indice_pokemon_actual].estad_ps_actual <= 0 or lista_pokemon[indice_pokemon_actual].infectado)
	var indice_anterior = indice_pokemon_actual
	indice_pokemon_actual = (indice_pokemon_actual + 1) % lista_pokemon.size()

	print("⬇️ [PANTALLA_INFO] Navegando: %d → %d (%s → %s)" % [
		indice_anterior, indice_pokemon_actual,
		lista_pokemon[indice_anterior].nombre_interno if indice_anterior < lista_pokemon.size() else "???",
		lista_pokemon[indice_pokemon_actual].nombre_interno
	])

	# Evaluar cambio de visibilidad del Pantalla-info-estado
	var estado_visible_actual = (lista_pokemon[indice_pokemon_actual].estado != Singleton.ProblemaEstado.NORMAL or lista_pokemon[indice_pokemon_actual].estad_ps_actual <= 0 or lista_pokemon[indice_pokemon_actual].infectado)
	if estado_visible_anterior != estado_visible_actual:
		actualizar_estado_pantalla_info_animado(estado_visible_actual)

	cargar_pokemon_actual()

func pokemon_anterior() -> void:
	"""Cambia al Pokémon anterior en la lista."""
	if lista_pokemon.size() <= 1:
		return  # No hay más Pokémon para navegar

	_reproducir_se(SONIDO_SELECCION)
	var estado_visible_anterior = (lista_pokemon[indice_pokemon_actual].estado != Singleton.ProblemaEstado.NORMAL or lista_pokemon[indice_pokemon_actual].estad_ps_actual <= 0 or lista_pokemon[indice_pokemon_actual].infectado)
	var indice_anterior = indice_pokemon_actual
	indice_pokemon_actual = (indice_pokemon_actual - 1 + lista_pokemon.size()) % lista_pokemon.size()

	print("⬆️ [PANTALLA_INFO] Navegando: %d → %d (%s → %s)" % [
		indice_anterior, indice_pokemon_actual,
		lista_pokemon[indice_anterior].nombre_interno if indice_anterior < lista_pokemon.size() else "???",
		lista_pokemon[indice_pokemon_actual].nombre_interno
	])

	# Evaluar cambio de visibilidad del Pantalla-info-estado
	var estado_visible_actual = (lista_pokemon[indice_pokemon_actual].estado != Singleton.ProblemaEstado.NORMAL or lista_pokemon[indice_pokemon_actual].estad_ps_actual <= 0 or lista_pokemon[indice_pokemon_actual].infectado)
	if estado_visible_anterior != estado_visible_actual:
		actualizar_estado_pantalla_info_animado(estado_visible_actual)

	cargar_pokemon_actual()

func ir_a_pokemon(indice: int) -> void:
	"""
	Va directamente a un Pokémon específico por índice.
	Útil para saltos directos desde menús externos.
	"""
	if indice < 0 or indice >= lista_pokemon.size():
		print("❌ [PANTALLA_INFO] Índice inválido para ir_a_pokemon: %d" % indice)
		return

	indice_pokemon_actual = indice
	cargar_pokemon_actual()

# --- NAVEGACIÓN EN MOVIMIENTOS ---

# func movimiento_siguiente() -> void:
# 	"""Selecciona el siguiente movimiento en la página de movimientos."""
# 	if pokemon_actual and pokemon_actual.movimientos.size() > 0:
# 		movimiento_seleccionado = (movimiento_seleccionado + 1) % min(4, pokemon_actual.movimientos.size())
# 		actualizar_info_movimiento()

# func movimiento_anterior() -> void:
# 	"""Selecciona el movimiento anterior en la página de movimientos."""
# 	if pokemon_actual and pokemon_actual.movimientos.size() > 0:
# 		movimiento_seleccionado = (movimiento_seleccionado - 1 + min(4, pokemon_actual.movimientos.size())) % min(4, pokemon_actual.movimientos.size())
# 		actualizar_info_movimiento()

# func actualizar_info_movimiento() -> void:
# 	"""Actualiza la descripción y estadísticas del movimiento seleccionado."""
# 	if not pokemon_actual or pokemon_actual.movimientos.size() == 0:
# 		mov_desc.text = "No hay movimientos disponibles."
# 		mov_potencia.text = "---"
# 		mov_precision.text = "---"
# 		return

# 	if movimiento_seleccionado >= pokemon_actual.movimientos.size():
# 		movimiento_seleccionado = 0

# 	var movimiento = pokemon_actual.movimientos[movimiento_seleccionado]

# 	# Actualizar descripción
# 	mov_desc.text = movimiento.get_descripcion()

# 	# Actualizar potencia y precisión usando los getters de la clase
# 	print("❌ [MOVIMIENTOS] Potencia: %d - Precisión: %d" % [movimiento.get_potencia(), movimiento.get_precision()])
# 	var potencia = movimiento.get_potencia()
# 	if potencia == 0:
# 		mov_potencia.text = "---"
# 	else:
# 		mov_potencia.text = str(potencia)

# 	var precision = movimiento.get_precision()
# 	if precision == 0:
# 		mov_precision.text = "---"
# 	else:
# 		mov_precision.text = str(precision)

# --- LLENADO DE DATOS ---

func llenar_pagina_info_basica() -> void:
	"""Llena los datos de la página de información básica."""
	if not pokemon_actual:
		return

	if pokemon_actual.huevo:
		llenar_pagina_info_huevo()
		return

	# Restaura lo que llenar_pagina_info_huevo() cambia.
	num_dex.visible = true
	nombre_interno.visible = true
	nivel.visible = true
	sexo.visible = true
	habilidad.visible = true
	mote.position = Vector2(8, 96)
	habilidad_descripcion.position.y = 88
	if pokemon_sprite:
		pokemon_sprite.flip_h = true

	# Número de la Pokédex
	num_dex.text = "%03d" % pokemon_actual.numero_nacional

	# Indicador de Pokémon variocolor
	actualizar_indicador_variocolor()

	# Mote o, si no tiene, nombre de la especie
	mote.text = pokemon_actual.get_nombre_mostrar()

	# Nombre de la especie
	nombre_interno.text = "/" + pokemon_actual.nombre.to_upper()

	# Nivel
	nivel.text = "Nv" + str(pokemon_actual.nivel)

	# Sexo
	match pokemon_actual.sexo:
		"M":
			sexo.text = "♂"
			sexo.modulate = Color(0.175, 0.68, 0.84, 1) # Azul
		"F":
			sexo.text = "♀"
			sexo.modulate = Color(1, 0.611765, 0.576471, 1)        # Rosa
		_:
			sexo.text = ""

	# Marcas del Pokémon (4 labels individuales)
	actualizar_marcas_pokemon()

	# Tipos del Pokémon
	actualizar_tipos_pokemon()

	# Entrenador original: azul si es varón, rojo si es mujer
	# (SummaryScreen_SetTextColor 9/10 de pokeruby).
	eo_nombre.text = pokemon_actual.entrenador_original.to_upper()
	eo_nombre.label_settings = TEXTO_EO_MUJER if pokemon_actual.entrenador_sexo == "F" else TEXTO_EO_VARON

	# ID del entrenador (usando función de formateo segura)
	eo_id.text = pokemon_actual.get_entrenador_id_formateado()

	# Habilidad
	habilidad.text = pokemon_actual.get_nombre_habilidad().to_upper()
	habilidad_descripcion.text = pokemon_actual.get_descripcion_habilidad()

	# Pokéball - Mostrar la ball correcta basada en encuentro_bola
	if pokeball_sprite:
		var nombre_ball = PokeballSprite.obtener_pokeball_de_objeto(pokemon_actual.encuentro_bola)
		pokeball_sprite.mostrar_estado_estatico(nombre_ball)
		print("🥎 [PANTALLA_INFO] Mostrando Pokéball: %s (de %s)" % [nombre_ball, pokemon_actual.encuentro_bola])

	# Sprite del Pokémon - Mostrar sprite frontal basado en nombre_interno
	if pokemon_sprite:
		var es_shiny = pokemon_actual.es_shiny() if pokemon_actual.has_method("es_shiny") else false
		# La personalidad decide las manchas de SPINDA.
		pokemon_sprite.configurar_pokemon(pokemon_actual.nombre_interno, PokemonSprite.TipoSprite.FRENTE, es_shiny, pokemon_actual.personalidad)
		print("🎨 [PANTALLA_INFO] Mostrando sprite: %s %s" % [pokemon_actual.nombre_interno, "(Shiny)" if es_shiny else "(Normal)"])

	# Notas (naturaleza, lugar de encuentro, etc.)
	# encuentro_lugar es una clave de lugar ("RUTA_113"): se muestra traducida
	# (las traducciones LUGAR_* ya van en mayúsculas; sin to_upper para no
	# convertir "POKéMON" en "POKÉMON").
	var texto_notas := texto_notas_encuentro(
		pokemon_actual.naturaleza,
		pokemon_actual.encuentro_nivel,
		Lugares.nombre_lugar(pokemon_actual.encuentro_lugar),
		pokemon_actual.encuentro_fatidico)
	notas.text = texto_notas

	# Estado y Pokerus
	actualizar_estado_pantalla_info()

# --- FUNCIONES DE UTILIDAD ---
func actualizar_estado_pantalla_info() -> void:
	# Lógica para mostrar el estado y pokerus en la UI
	if not pantalla_info_estado or not pantalla_info_estado_icono or not pokemon_actual:
		print("❌ [PANTALLA_INFO] No se puede actualizar estado: pantalla_info_estado o pokemon_actual no están definidos.")
		return

	var estado = pokemon_actual.estado
	# GetMonStatusAndPokerus: con 0 PS es «DEB» antes que cualquier problema de estado.
	if pokemon_actual.estad_ps_actual <= 0:
		estado = Singleton.ProblemaEstado.DEBILITADO
	var tiene_pokerus = pokemon_actual.infectado and not pokemon_actual.curado

	if estado != null and int(estado) >= 0 and int(estado) <= 5:
		pantalla_info_estado.visible = true
		pantalla_info_estado_icono.frame = int(estado)
	elif tiene_pokerus:
		pantalla_info_estado.visible = true
		pantalla_info_estado_icono.frame = Singleton.ProblemaEstado.POKERUS
	else:
		if !tween_estado or !tween_estado.is_running():
			pantalla_info_estado.visible = false

	curado.visible = pokemon_actual.curado

	# Imprimir banderas infectado, curado, dias restantes, ultimo conteo
	print("🔧 [PANTALLA_INFO] Estado de infectado: %s" % [pokemon_actual.infectado])
	print("🔧 [PANTALLA_INFO] Estado de curado: %s" % [pokemon_actual.curado])
	print("🔧 [PANTALLA_INFO] Días restantes de Pokérus: %d" % [pokemon_actual.pokerus_dias_restantes])
	print("🔧 [PANTALLA_INFO] Último conteo de Pokérus: %d" % [pokemon_actual.pokerus_fecha_ultimo_conteo])

func actualizar_estado_pantalla_info_animado(hacer_visible: bool) -> void:
	if tween_estado:
		tween_estado.kill()
	var pos_normal = Vector2(0, 144)
	var pos_izquierda = Vector2(-80, 144)
	if hacer_visible:
		pantalla_info_estado.position = pos_izquierda
		pantalla_info_estado.visible = true
		tween_estado = create_tween()
		tween_estado.tween_property(pantalla_info_estado, "position", pos_normal, 0.1)
	else:
		tween_estado = create_tween()
		tween_estado.tween_property(pantalla_info_estado, "position", pos_izquierda, 0.1)
		tween_estado.tween_callback(Callable(pantalla_info_estado, "hide"))

func get_pokemon_actual() -> BasePokemon:
	"""Devuelve el Pokémon actualmente mostrado."""
	return pokemon_actual

func get_indice_actual() -> int:
	"""Devuelve el índice del Pokémon actual en la lista."""
	return indice_pokemon_actual

func get_total_pokemon() -> int:
	"""Devuelve el total de Pokémon en la lista."""
	return lista_pokemon.size()

func get_info_navegacion() -> Dictionary:
	"""
	Devuelve información útil sobre el estado de navegación.
	Útil para mostrar indicadores como "3/6" en la UI.
	"""
	return {
		"actual": indice_pokemon_actual + 1,  # Base 1 para mostrar al usuario
		"total": lista_pokemon.size(),
		"puede_navegar": lista_pokemon.size() > 1,
		"es_primero": indice_pokemon_actual == 0,
		"es_ultimo": indice_pokemon_actual == lista_pokemon.size() - 1,
		"pokemon_actual": pokemon_actual.nombre_interno if pokemon_actual else ""
	}

func llenar_pagina_estadisticas() -> void:
	"""Llena los datos de la página de estadísticas."""
	if not pokemon_actual:
		return

	# Objeto
	if pokemon_actual.objeto != "" and pokemon_actual.objeto != "NONE":
		# BasePokemon.objeto guarda el nombre_interno: mostrar el nombre de la BD.
		objeto.text = ObjetosLlevados.nombre_objeto(pokemon_actual.objeto)
	else:
		objeto.text = "NO TIENE"

	# Cintas (placeholder por ahora)
	if pokemon_actual.cintas.size() > 0:
		cintas.text = "TIENE " + str(pokemon_actual.cintas.size())
	else:
		cintas.text = "NO TIENE"

	# Estadísticas
	ps.text = "%3s/%3s" % [str(pokemon_actual.estad_ps_actual), str(pokemon_actual.estad_ps)]
	ataque.text = str(pokemon_actual.estad_ataque)
	defensa.text = str(pokemon_actual.estad_defensa)
	at_esp.text = str(pokemon_actual.estad_ataque_especial)
	def_esp.text = str(pokemon_actual.estad_defensa_especial)
	veloc.text = str(pokemon_actual.estad_velocidad)

	# Experiencia
	puntos_exp.text = str(pokemon_actual.experiencia)

	# Experiencia al siguiente nivel
	if pokemon_actual.exp_sig_nivel > 0:
		var exp_restante = pokemon_actual.exp_sig_nivel - pokemon_actual.experiencia
		sig_nivel.text = str(exp_restante)
	else:
		sig_nivel.text = "MAX"

	# Actualizar barra de experiencia
	actualizar_barra_experiencia()

func llenar_pagina_movimientos() -> void:
	"""Llena los datos de la página de movimientos."""
	if not pokemon_actual:
		return

	# Labels de movimientos
	var labels_movimientos = [mov1, mov2, mov3, mov4]
	var labels_pp = [pp1, pp2, pp3, pp4]

	# Limpiar todos los movimientos
	for i in range(4):
		labels_movimientos[i].text = ""
		labels_pp[i].text = ""

	# Llenar con los movimientos disponibles
	for i in range(4):
		if i < pokemon_actual.movimientos.size():
			var movimiento = pokemon_actual.movimientos[i]
			labels_movimientos[i].text = movimiento.nombre.to_upper()
			labels_pp[i].text = "%2s/%2s" % [str(movimiento.pp_act), str(movimiento.pp_tot)]
		else:
			labels_movimientos[i].text = "-"
			labels_pp[i].text = "--"

	# Actualizar los iconos de tipo (combate) o de categoría (concurso)
	actualizar_tipos_movimientos()
	actualizar_categorias_movimientos()

	if mov_desc:
		mov_desc.text = ""

func actualizar_tipos_movimientos() -> void:
	"""Actualiza los sprites de tipos de los movimientos usando los AnimatedSprite2D."""
	if not pokemon_actual:
		return

	# Referencias a los nodos de tipo de movimiento
	var sprites_tipo_mov = [tipo_mov1, tipo_mov2, tipo_mov3, tipo_mov4]

	# Limpiar todos los sprites primero
	for i in range(4):
		if sprites_tipo_mov[i]:
			sprites_tipo_mov[i].visible = false
	if es_pagina_concurso():
		return

	# Actualizar sprites según los movimientos disponibles
	for i in range(min(4, pokemon_actual.movimientos.size())):
		var movimiento = pokemon_actual.movimientos[i]
		var sprite_tipo = sprites_tipo_mov[i]

		if sprite_tipo and movimiento:
			var tipo_movimiento = movimiento.get_tipo()
			if tipo_movimiento and tipo_movimiento != "":
				# Obtener el ID del tipo por nombre
				var id_tipo = Singleton.obtener_id_tipo_por_nombre(tipo_movimiento)
				if id_tipo > 0:
					var frame_tipo = Singleton.obtener_frame_tipo(id_tipo)
					if frame_tipo >= 0:
						sprite_tipo.frame = frame_tipo
						sprite_tipo.visible = true
						print("🎨 [MOVIMIENTOS] Mov%d tipo: %s (frame %d)" % [i+1, tipo_movimiento, frame_tipo])
					else:
						sprite_tipo.visible = false
						print("⚠️ [MOVIMIENTOS] Mov%d tipo inválido: %s" % [i+1, tipo_movimiento])
				else:
					sprite_tipo.visible = false
					print("⚠️ [MOVIMIENTOS] Mov%d tipo no encontrado: %s" % [i+1, tipo_movimiento])
			else:
				sprite_tipo.visible = false

## Iconos de categoría de concurso (solo en MOV. CONCURSO).
func actualizar_categorias_movimientos() -> void:
	var concurso := es_pagina_concurso()
	for i in range(categorias_mov.size()):
		var tiene := pokemon_actual != null and i < pokemon_actual.movimientos.size()
		categorias_mov[i].visible = concurso and tiene
		if concurso and tiene:
			DibujoConcurso.asignar_icono_categoria(categorias_mov[i], pokemon_actual.movimientos[i])

# === SISTEMA DE MARCAS ===

func actualizar_marcas_pokemon() -> void:
	"""
	Actualiza la visibilidad de las 4 marcas individuales según el estado del Pokémon actual.
	Cada marca se muestra/oculta independientemente según su flag correspondiente.
	"""
	if not pokemon_actual:
		# Si no hay Pokémon, ocultar todas las marcas
		ocultar_todas_las_marcas()
		return

	# Obtener el estado de cada marca desde el Pokémon
	var marca_circulo_activa = pokemon_actual.get_marca("circulo")
	var marca_cuadrado_activa = pokemon_actual.get_marca("cuadrado")
	var marca_triangulo_activa = pokemon_actual.get_marca("triangulo")
	var marca_corazon_activa = pokemon_actual.get_marca("corazon")

	# Actualizar visibilidad de cada marca individual
	if marca_circulo:
		marca_circulo.visible = marca_circulo_activa
		if marca_circulo_activa:
			marca_circulo.text = "●"  # Círculo relleno

	if marca_cuadrado:
		marca_cuadrado.visible = marca_cuadrado_activa
		if marca_cuadrado_activa:
			marca_cuadrado.text = "■"  # Cuadrado relleno

	if marca_triangulo:
		marca_triangulo.visible = marca_triangulo_activa
		if marca_triangulo_activa:
			marca_triangulo.text = "▲"  # Triángulo

	if marca_corazon:
		marca_corazon.visible = marca_corazon_activa
		if marca_corazon_activa:
			marca_corazon.text = "♥"  # Corazón

	# Debug: mostrar estado de las marcas
	var marcas_activas = []
	if marca_circulo_activa: marcas_activas.append("●")
	if marca_cuadrado_activa: marcas_activas.append("■")
	if marca_triangulo_activa: marcas_activas.append("▲")
	if marca_corazon_activa: marcas_activas.append("♥")

	print("🏷️ [PANTALLA_INFO] Marcas activas para %s: [%s]" % [
		pokemon_actual.get_nombre_mostrar(),
		", ".join(marcas_activas) if marcas_activas.size() > 0 else "ninguna"
	])

func ocultar_todas_las_marcas() -> void:
	"""Oculta todas las marcas cuando no hay Pokémon seleccionado."""
	if marca_circulo: marca_circulo.visible = false
	if marca_cuadrado: marca_cuadrado.visible = false
	if marca_triangulo: marca_triangulo.visible = false
	if marca_corazon: marca_corazon.visible = false
	print("🏷️ [PANTALLA_INFO] Todas las marcas ocultas")

func actualizar_tipos_pokemon() -> void:
	"""Actualiza los sprites de tipos del Pokémon usando los AnimatedSprite2D."""
	if not pokemon_actual:
		# Si no hay Pokémon, ocultar tipos
		if tipo1: tipo1.visible = false
		if tipo2: tipo2.visible = false
		return

	# Obtener los tipos del Pokémon (desde la base de datos)
	var tipos_pokemon = pokemon_actual.obtener_tipos_desde_bd()

	# Actualizar tipo1 (siempre debe existir)
	if tipo1 and tipos_pokemon.size() > 0:
		var id_tipo1 = tipos_pokemon[0]
		var frame_tipo1 = Singleton.obtener_frame_tipo(id_tipo1)
		if frame_tipo1 >= 0:
			tipo1.frame = frame_tipo1
			tipo1.visible = true
			var nombre_tipo1 = Singleton.obtener_nombre_tipo_por_id(id_tipo1)
			print("🎨 [PANTALLA_INFO] Tipo1: %s (frame %d, ID BD: %d)" % [nombre_tipo1, frame_tipo1, id_tipo1])
		else:
			tipo1.visible = false
			print("⚠️ [PANTALLA_INFO] Tipo1 inválido: ID %d" % id_tipo1)
	else:
		tipo1.visible = false

	# Actualizar tipo2 (puede no existir)
	if tipo2 and tipos_pokemon.size() > 1:
		var id_tipo2 = tipos_pokemon[1]
		var frame_tipo2 = Singleton.obtener_frame_tipo(id_tipo2)
		if frame_tipo2 >= 0:
			tipo2.frame = frame_tipo2
			tipo2.visible = true
			var nombre_tipo2 = Singleton.obtener_nombre_tipo_por_id(id_tipo2)
			print("🎨 [PANTALLA_INFO] Tipo2: %s (frame %d, ID BD: %d)" % [nombre_tipo2, frame_tipo2, id_tipo2])
		else:
			tipo2.visible = false
			print("⚠️ [PANTALLA_INFO] Tipo2 inválido: ID %d" % id_tipo2)
	else:
		# No hay segundo tipo, ocultar
		tipo2.visible = false
		print("🎨 [PANTALLA_INFO] Solo un tipo, tipo2 oculto")

func actualizar_indicador_variocolor() -> void:
	"""Actualiza el indicador visual de Pokémon variocolor (shiny)."""
	if not pokemon_actual:
		# Si no hay Pokémon, ocultar indicador
		if variocolor: variocolor.visible = false
		if num_dex: num_dex.modulate = Color.WHITE  # Color normal
		return

	# Verificar si el Pokémon es variocolor
	var es_shiny = pokemon_actual.es_shiny()

	# Actualizar label de estrella variocolor
	if variocolor:
		variocolor.visible = es_shiny
		if es_shiny:
			variocolor.text = "★"  # Estrella dorada #e8e8a8
			variocolor.modulate = Color(0.909, 0.909, 0.659, 1.0)
			print("✨ [PANTALLA_INFO] %s es VARIOCOLOR - mostrando estrella" % pokemon_actual.get_nombre_mostrar())

	# Actualizar color del número de pokédex
	if num_dex:
		if es_shiny:
			# Color dorado claro para número de pokédex shiny (Hex: #e8e8a8)
			num_dex.modulate = Color(0.909, 0.909, 0.659, 1.0)
			print("🔢 [PANTALLA_INFO] Número pokédex en color dorado para variocolor")
		else:
			# Color normal (blanco) #f8f8f8
			num_dex.modulate = Color(0.973, 0.973, 0.973, 1.0)

	if es_shiny:
		print("🌟 [PANTALLA_INFO] Pokémon variocolor detectado: %s" % pokemon_actual.get_nombre_mostrar())

# func detectar_pokemon_variocolor() -> bool:
# 	"""Detecta si el Pokémon actual es variocolor (shiny)."""
# 	if not pokemon_actual:
# 		return false

# 	# Método 1: Verificar si BasePokemon tiene función es_shiny
# 	if pokemon_actual.has_method("es_shiny"):
# 		return pokemon_actual.es_shiny()

# 	# Método 2: Verificar si tiene propiedad shiny
# 	if "shiny" in pokemon_actual:
# 		return pokemon_actual.shiny

# 	# Método 3: Verificar si tiene propiedad variocolor
# 	if "variocolor" in pokemon_actual:
# 		return pokemon_actual.variocolor

# 	# Método 4: Detectar por ID personalizado (opcional)
# 	# Pokémon con ID específicos pueden ser considerados shiny para pruebas
# 	if pokemon_actual.pid != null:
# 		# Ejemplo: Los últimos 2 dígitos del PID determinan si es shiny
# 		# (esto es solo para demo, la lógica real sería más compleja)
# 		var ultimo_digito = pokemon_actual.pid % 10
# 		return ultimo_digito == 7  # 10% probabilidad para pruebas

# 	# Por defecto, no es shiny
# 	return false

func debug_marcas_ui() -> void:
	"""Función de debug para verificar el estado de los nodos de marcas en la UI."""
	print("=== DEBUG MARCAS UI ===")
	print("Nodo marca_circulo: %s (visible: %s)" % [marca_circulo != null, marca_circulo.visible if marca_circulo else "N/A"])
	print("Nodo marca_cuadrado: %s (visible: %s)" % [marca_cuadrado != null, marca_cuadrado.visible if marca_cuadrado else "N/A"])
	print("Nodo marca_triangulo: %s (visible: %s)" % [marca_triangulo != null, marca_triangulo.visible if marca_triangulo else "N/A"])
	print("Nodo marca_corazon: %s (visible: %s)" % [marca_corazon != null, marca_corazon.visible if marca_corazon else "N/A"])
	print("======================")

func actualizar_barra_experiencia() -> void:
	if not barra_exp or not pokemon_actual:
		return

	var nuevo_ancho = 64.0 * pokemon_actual.porcentaje_experiencia
	barra_exp.size.x = nuevo_ancho
