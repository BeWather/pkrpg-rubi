@tool
extends Control

const RUTA_JSON := "res://BaseDatos/lista_entrenadores.json"
const RUTA_TRAINERS_FRAMES := "res://graficos/trainers64/entrenadores_64.tres"
const RUTA_ICONOS_POKEMON := "res://graficos/Icons/"
const RUTA_BASE_DATOS := "res://BaseDatos/poke.db"
const TiposEntrenadorData := preload("res://BaseDatos/tipos_entrenador.gd")
const ListaEntrenadoresJson := preload("res://addons/tilemap_inspector/entrenadores/lista_entrenadores_json.gd")
const ValidadorEntrenador := preload("res://addons/tilemap_inspector/entrenadores/validador_entrenador.gd")
const UsosEntrenador := preload("res://addons/tilemap_inspector/entrenadores/usos_entrenador.gd")
## Nombres oficiales de la ROM española (ayuda de desarrollo; opcional).
const RUTA_NOMBRES_OFICIALES := "B:/github/decomp/mirubi/extracted/trainer_records.csv"
## Caja de texto de batalla (batalla.tscn › UI/CajaDialogo/RichTextLabel).
const FUENTE_BATALLA := "res://fuentes/pokemon-rs.ttf"
const TAMANO_FUENTE_BATALLA := 15
const ANCHO_CAJA_BATALLA := 208.0
const COLOR_MOV_FIJO := Color(0.55, 0.85, 1.0)
const COLOR_MOV_NIVEL := Color(0.6, 0.62, 0.66)
const COLOR_AVISO := Color(1.0, 0.72, 0.3)

## El título de la ventana debe reflejar si hay cambios sin guardar (plugin.gd).
signal titulo_cambiado(hay_cambios: bool)
## El usuario confirmó cerrar (guardando, descartando o sin cambios).
signal cierre_confirmado

var entrenadores: Array[Dictionary] = []
var entrenador_index: int = -1
var pokemon_index: int = -1
## Mientras se rellena el formulario desde los datos, las señales de los campos no
## escriben en el diccionario ni marcan cambios.
var _cargando: bool = false
## {entrenador_id: ["ruta_117 › Isaac", …]} (UsosEntrenador).
var _usos: Dictionary = {}
## {entrenador_id: "NOMBRE OFICIAL"} si existe RUTA_NOMBRES_OFICIALES.
var _nombres_oficiales: Dictionary = {}
## Índices de TablaRevanchas plegados en la lista.
var _grupos_plegados: Dictionary = {}
var _fuente_batalla: Font = null
## Caché de nombres presentables de mapas: {escena: "RUTA 117"} y filas de dialogos.csv.
var _nombres_lugar: Dictionary = {}
var _filas_dialogos: Dictionary = {}
var _dialogo_cierre: ConfirmationDialog = null

# Referencias UI (usamos rutas explícitas porque los nodos no están marcados como 'Unique Name')
@onready var filtro_clase: LineEdit = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelLista/MarginLista/VBoxLista/PanelFiltros/MarginFiltros/VBoxFiltros/HBoxBuscar/FiltroClase")
@onready var filtro_nombre: LineEdit = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelLista/MarginLista/VBoxLista/PanelFiltros/MarginFiltros/VBoxFiltros/HBoxBuscar2/FiltroNombre")
@onready var vbox_cards: VBoxContainer = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelLista/MarginLista/VBoxLista/ScrollLista/VBoxCards")
@onready var card_template: Control = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelLista/MarginLista/VBoxLista/ScrollLista/VBoxCards/CardTemplate")
@onready var scroll_lista: ScrollContainer = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelLista/MarginLista/VBoxLista/ScrollLista")
@onready var clase: LineEdit = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelDetalle/MarginDetalle/VBoxDetalle/Scroll/Form/PanelPerfil/MarginPerfil/VBoxPerfil/HBoxTop/GridTopLeft/HBoxClase/Clase")
@onready var nombre: LineEdit = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelDetalle/MarginDetalle/VBoxDetalle/Scroll/Form/PanelPerfil/MarginPerfil/VBoxPerfil/HBoxTop/GridTopLeft/Nombre")
@onready var frase_derrota: TextEdit = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelDetalle/MarginDetalle/VBoxDetalle/Scroll/Form/PanelPerfil/MarginPerfil/VBoxPerfil/HBoxTop/GridTopLeft/FraseDerrota")
@onready var sexo: OptionButton = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelDetalle/MarginDetalle/VBoxDetalle/Scroll/Form/PanelPerfil/MarginPerfil/VBoxPerfil/HBoxTop/GridTopLeft/Sexo")
@onready var tipo_batalla_selector: OptionButton = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelDetalle/MarginDetalle/VBoxDetalle/Scroll/Form/PanelPerfil/MarginPerfil/VBoxPerfil/HBoxTop/GridTopLeft/TipoBatalla")
@onready var num_sprite: SpinBox = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelDetalle/MarginDetalle/VBoxDetalle/Scroll/Form/PanelPerfil/MarginPerfil/VBoxPerfil/HBoxTop/PanelSprite/MarginSprite/VBoxSprite/HBoxNumSprite/NumSprite")
@onready var ratio_dinero: SpinBox = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelDetalle/MarginDetalle/VBoxDetalle/Scroll/Form/PanelPerfil/MarginPerfil/VBoxPerfil/HBoxTop/GridTopLeft/RatioDinero")
@onready var musica_option: OptionButton = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelDetalle/MarginDetalle/VBoxDetalle/Scroll/Form/PanelPerfil/MarginPerfil/VBoxPerfil/HBoxTop/GridTopLeft/HBoxMusica/MusicaOption")
@onready var objeto_slot_1: LineEdit = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelDetalle/MarginDetalle/VBoxDetalle/Scroll/Form/FilaSecundaria/PanelObjetos/MarginObjetos/VBoxObjetos/ObjetosGrid/Objeto1")
@onready var objeto_slot_2: LineEdit = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelDetalle/MarginDetalle/VBoxDetalle/Scroll/Form/FilaSecundaria/PanelObjetos/MarginObjetos/VBoxObjetos/ObjetosGrid/Objeto2")
@onready var objeto_slot_3: LineEdit = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelDetalle/MarginDetalle/VBoxDetalle/Scroll/Form/FilaSecundaria/PanelObjetos/MarginObjetos/VBoxObjetos/ObjetosGrid/Objeto3")
@onready var objeto_slot_4: LineEdit = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelDetalle/MarginDetalle/VBoxDetalle/Scroll/Form/FilaSecundaria/PanelObjetos/MarginObjetos/VBoxObjetos/ObjetosGrid/Objeto4")
@onready var objeto_slot_5: LineEdit = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelDetalle/MarginDetalle/VBoxDetalle/Scroll/Form/FilaSecundaria/PanelObjetos/MarginObjetos/VBoxObjetos/ObjetosGrid/Objeto5")
@onready var objeto_slot_6: LineEdit = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelDetalle/MarginDetalle/VBoxDetalle/Scroll/Form/FilaSecundaria/PanelObjetos/MarginObjetos/VBoxObjetos/ObjetosGrid/Objeto6")
@onready var equipo_slots: HBoxContainer = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelDetalle/MarginDetalle/VBoxDetalle/Scroll/Form/PanelEquipo/MarginEquipo/VBoxEquipo/VBoxPokemonLista/EquipoSlots")
@onready var p_nombre: LineEdit = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelDetalle/MarginDetalle/VBoxDetalle/Scroll/Form/FilaSecundaria/PanelPokemonDetalle/MarginPokemonDetalle/VBoxPokemonDetalle/PokemonDetalle/PNombre")
@onready var p_nivel: SpinBox = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelDetalle/MarginDetalle/VBoxDetalle/Scroll/Form/FilaSecundaria/PanelPokemonDetalle/MarginPokemonDetalle/VBoxPokemonDetalle/PokemonDetalle/PNivel")
@onready var p_objeto: LineEdit = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelDetalle/MarginDetalle/VBoxDetalle/Scroll/Form/FilaSecundaria/PanelPokemonDetalle/MarginPokemonDetalle/VBoxPokemonDetalle/PokemonDetalle/PObjeto")
@onready var p_movs_grid: GridContainer = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelDetalle/MarginDetalle/VBoxDetalle/Scroll/Form/FilaSecundaria/PanelPokemonDetalle/MarginPokemonDetalle/VBoxPokemonDetalle/PokemonDetalle/PMovs")
@onready var en_combate_grid: GridContainer = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelDetalle/MarginDetalle/VBoxDetalle/Scroll/Form/FilaSecundaria/PanelPokemonDetalle/MarginPokemonDetalle/VBoxPokemonDetalle/PokemonDetalle/EnCombate")
@onready var preview_frase: VBoxContainer = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelDetalle/MarginDetalle/VBoxDetalle/Scroll/Form/PanelPerfil/MarginPerfil/VBoxPerfil/HBoxTop/GridTopLeft/PreviewFrase")
@onready var lbl_revancha: Label = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelDetalle/MarginDetalle/VBoxDetalle/Scroll/Form/FilaSecundaria/PanelInfo/MarginInfo/VBoxInfo/HBoxRevancha/LblRevancha")
@onready var tiers_revancha: HFlowContainer = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelDetalle/MarginDetalle/VBoxDetalle/Scroll/Form/FilaSecundaria/PanelInfo/MarginInfo/VBoxInfo/HBoxRevancha/TiersRevancha")
@onready var lbl_usado_en: Label = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelDetalle/MarginDetalle/VBoxDetalle/Scroll/Form/FilaSecundaria/PanelInfo/MarginInfo/VBoxInfo/LblUsadoEn")
@onready var lbl_premio: Label = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelDetalle/MarginDetalle/VBoxDetalle/Scroll/Form/FilaSecundaria/PanelInfo/MarginInfo/VBoxInfo/LblPremio")
@onready var lbl_nombre_oficial: Label = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelDetalle/MarginDetalle/VBoxDetalle/Scroll/Form/FilaSecundaria/PanelInfo/MarginInfo/VBoxInfo/LblNombreOficial")
@onready var lbl_avisos: Label = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelDetalle/MarginDetalle/VBoxDetalle/Scroll/Form/FilaSecundaria/PanelInfo/MarginInfo/VBoxInfo/LblAvisos")
@onready var estado: Label = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelDetalle/MarginDetalle/VBoxDetalle/FooterDetalle/MarginFooter/HBoxAcciones/Estado")
@onready var preview_trainer: TextureRect = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelDetalle/MarginDetalle/VBoxDetalle/Scroll/Form/PanelPerfil/MarginPerfil/VBoxPerfil/HBoxTop/PanelSprite/MarginSprite/VBoxSprite/PreviewTrainer")
@onready var label_sprite_count: Label = null  # eliminado del tscn; el rango se controla por trainer_total_frames
@onready var campo_id: LineEdit = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelDetalle/MarginDetalle/VBoxDetalle/Scroll/Form/PanelPerfil/MarginPerfil/VBoxPerfil/HBoxTop/GridTopLeft/Id")

@onready var btn_limpiar_filtro_clase: Button = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelLista/MarginLista/VBoxLista/PanelFiltros/MarginFiltros/VBoxFiltros/HBoxBuscar/BtnLimpiarFiltroClase")
@onready var btn_limpiar_filtro: Button = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelLista/MarginLista/VBoxLista/PanelFiltros/MarginFiltros/VBoxFiltros/HBoxBuscar2/BtnLimpiarFiltro")
@onready var filtro_pokemon: LineEdit = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelLista/MarginLista/VBoxLista/PanelFiltros/MarginFiltros/VBoxFiltros/HBoxBuscar3/FiltroPokemon")
@onready var btn_limpiar_filtro_pokemon: Button = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelLista/MarginLista/VBoxLista/PanelFiltros/MarginFiltros/VBoxFiltros/HBoxBuscar3/BtnLimpiarFiltroPokemon")
@onready var btn_nuevo: Button = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelLista/MarginLista/VBoxLista/HBoxListaBtns/BtnNuevo")
@onready var btn_duplicar: Button = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelLista/MarginLista/VBoxLista/HBoxListaBtns/BtnDuplicar")
@onready var btn_borrar: Button = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelLista/MarginLista/VBoxLista/HBoxListaBtns/BtnBorrar")
@onready var btn_test_batalla: Button = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelLista/MarginLista/VBoxLista/HBoxListaBtns/BtnTestBatalla")
@onready var btn_add_pokemon: Button = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelDetalle/MarginDetalle/VBoxDetalle/Scroll/Form/PanelEquipo/MarginEquipo/VBoxEquipo/VBoxPokemonLista/HBoxPokemonBtns/BtnAddPokemon")
@onready var btn_eliminar_pokemon: Button = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelDetalle/MarginDetalle/VBoxDetalle/Scroll/Form/FilaSecundaria/PanelPokemonDetalle/MarginPokemonDetalle/VBoxPokemonDetalle/HBoxPokemonAcciones/BtnEliminarPokemon")
@onready var btn_guardar: Button = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelDetalle/MarginDetalle/VBoxDetalle/FooterDetalle/MarginFooter/HBoxAcciones/BtnGuardar")
@onready var btn_revertir: Button = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelDetalle/MarginDetalle/VBoxDetalle/FooterDetalle/MarginFooter/HBoxAcciones/BtnRevertir")
@onready var btn_clase_config: Button = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelDetalle/MarginDetalle/VBoxDetalle/Scroll/Form/PanelPerfil/MarginPerfil/VBoxPerfil/HBoxTop/GridTopLeft/HBoxClase/BtnClaseConfig")
@onready var btn_sprite_config: Button = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelDetalle/MarginDetalle/VBoxDetalle/Scroll/Form/PanelPerfil/MarginPerfil/VBoxPerfil/HBoxTop/PanelSprite/MarginSprite/VBoxSprite/HBoxNumSprite/BtnSpriteConfig")
@onready var musica_batalla_option: OptionButton = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelDetalle/MarginDetalle/VBoxDetalle/Scroll/Form/PanelPerfil/MarginPerfil/VBoxPerfil/HBoxTop/GridTopLeft/HBoxMusicaBatalla/MusicaBatallaOption")
@onready var btn_play_musica_batalla: Button = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelDetalle/MarginDetalle/VBoxDetalle/Scroll/Form/PanelPerfil/MarginPerfil/VBoxPerfil/HBoxTop/GridTopLeft/HBoxMusicaBatalla/BtnPlayMusicaBatalla")
@onready var btn_config_musica_batalla: Button = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelDetalle/MarginDetalle/VBoxDetalle/Scroll/Form/PanelPerfil/MarginPerfil/VBoxPerfil/HBoxTop/GridTopLeft/HBoxMusicaBatalla/BtnConfigMusicaBatalla")
@onready var btn_play_musica: Button = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelDetalle/MarginDetalle/VBoxDetalle/Scroll/Form/PanelPerfil/MarginPerfil/VBoxPerfil/HBoxTop/GridTopLeft/HBoxMusica/BtnPlayMusica")
@onready var btn_config_musica: Button = get_node_or_null("MarginOuter/PanelBox/HSplit/PanelDetalle/MarginDetalle/VBoxDetalle/Scroll/Form/PanelPerfil/MarginPerfil/VBoxPerfil/HBoxTop/GridTopLeft/HBoxMusica/BtnConfigMusica")

var trainer_frames: SpriteFrames = null
var trainer_total_frames: int = 0
var icon_cache: Dictionary = {}
var _frame_cache: Dictionary = {}  # "nombre:frame" -> Texture2D (AtlasTexture)
var next_id_cache: int = 0
var pokemon_cache: Dictionary = {}
var movimiento_cache: Dictionary = {}
var cards_visibles: Array[Control] = []  # Para navegación con teclado
var db = null  # conexión directa a SQLite para el plugin
var card_seleccionada_idx: int = -1
var animation_timer: Timer = null  # Timer para animación de iconos
var current_frame: int = 0  # Frame actual de animación (0 o 1)

# ─── Autocompletado ────────────────────────────────────────────────────────────
var _ac_lista_pokemon: Array = []       # [{nombre_interno, nombre}]
var _ac_lista_objetos: Array = []       # [nombre_interno]
var _ac_lista_movimientos: Array = []   # [nombre_interno]
var _ac_panel: Panel = null          # overlay (no Popup → no roba el foco)
var _ac_item_list: ItemList = null
var _ac_target: LineEdit = null
var _ac_multi: bool = false           # true = modo coma-separado
var _ac_suppressing: bool = false     # evita reabrir al asignar texto por código

# ─── Música ────────────────────────────────────────────────────────────────────
const TEMAS_JSON_PATH := "res://BaseDatos/temas_musicales.json"
const MusicaRubiScript = preload("res://scripts/musica/MusicaRubi.gd")
const AUDIO_BASE_PATH := "res://Audio/emerald/"
const _EDITOR_TEMAS_ESCENA := "res://addons/tilemap_inspector/editores/editor_temas_musicales/editor_temas_musicales.tscn"
var _temas_registrados: Dictionary = {}
var _audio_player: AudioStreamPlayer = null
var _tema_reproduciendo: String = ""

# ─── Ventanas auxiliares ───────────────────────────────────────────────────────
var _editor_temas: Window = null

var _ventana_clases: Window = null
var _vc_filtro: LineEdit = null
var _vc_vbox: VBoxContainer = null
var _vc_modo_seleccion: String = "clase"  # "clase" o "sprite"

const CLAVE_TIPO_BATALLA_SIMPLE := "SIMPLE"
const CLAVE_TIPO_BATALLA_DOBLE := "DOBLE"


func _ready():
	if Engine.is_editor_hint():
		_cargar_trainer_frames()
		_conectar_base_datos()  # Conectar ANTES de cargar JSON
		_cargar_temas_json()
		_crear_audio_player()
		# Listas, usos, nombres y fuente antes de pintar la lista: las tarjetas
		# validan objetos y el panel de información los usa.
		_cargar_listas_autocomplete()
		_usos = UsosEntrenador.escanear()
		_cargar_nombres_oficiales()
		if ResourceLoader.exists(FUENTE_BATALLA):
			_fuente_batalla = load(FUENTE_BATALLA)
		_cargar_json()
		_conectar_seniales()
		_inicializar_animacion()  # Inicializar animación de iconos
		_crear_popup_autocomplete()
		_conectar_campos_autocomplete()
		_limpiar_formulario()
		if estado:
			estado.text = "Editor listo"
		if scroll_lista:
			scroll_lista.gui_input.connect(_manejar_input_teclado)

func _conectar_seniales():
	if filtro_nombre: filtro_nombre.text_changed.connect(_aplicar_filtro)
	if filtro_clase: filtro_clase.text_changed.connect(_aplicar_filtro)
	if filtro_pokemon: filtro_pokemon.text_changed.connect(_aplicar_filtro)
	if btn_limpiar_filtro: btn_limpiar_filtro.pressed.connect(func(): if filtro_nombre: filtro_nombre.text = ""; _aplicar_filtro(""))
	if btn_limpiar_filtro_clase: btn_limpiar_filtro_clase.pressed.connect(func(): if filtro_clase: filtro_clase.text = ""; _aplicar_filtro(""))
	if btn_limpiar_filtro_pokemon: btn_limpiar_filtro_pokemon.pressed.connect(func(): if filtro_pokemon: filtro_pokemon.text = ""; _aplicar_filtro(""))
	if btn_nuevo: btn_nuevo.pressed.connect(_nuevo_entrenador)
	if btn_duplicar: btn_duplicar.pressed.connect(_duplicar_entrenador)
	if btn_borrar: btn_borrar.pressed.connect(_borrar_entrenador)
	if btn_test_batalla: btn_test_batalla.pressed.connect(_on_debug_batalla_presionado)
	# ItemList ya no se usa; manejamos clicks sobre cards
	if btn_add_pokemon: btn_add_pokemon.pressed.connect(_agregar_pokemon)
	if btn_eliminar_pokemon: btn_eliminar_pokemon.pressed.connect(_eliminar_pokemon)
	if btn_guardar: btn_guardar.pressed.connect(_guardar_json)
	if btn_revertir: btn_revertir.pressed.connect(_revertir)
	# Botones de config de clase y sprite
	if btn_clase_config: btn_clase_config.pressed.connect(func(): _abrir_ventana_clases("clase"))
	if btn_sprite_config: btn_sprite_config.pressed.connect(func(): _abrir_ventana_clases("sprite"))
	# Botones de música
	if btn_play_musica: btn_play_musica.pressed.connect(_on_play_musica_presionado)
	if btn_config_musica: btn_config_musica.pressed.connect(_on_config_musica_presionado)
	if btn_play_musica_batalla: btn_play_musica_batalla.pressed.connect(_on_play_musica_batalla_presionado)
	if btn_config_musica_batalla: btn_config_musica_batalla.pressed.connect(_on_config_musica_batalla_presionado)
	# Edición en vivo: cada campo escribe en el diccionario del entrenador (o del
	# Pokémon) seleccionado; nada se pierde al cambiar de tarjeta.
	if nombre: nombre.text_changed.connect(func(t: String): _editar_perfil("nombre", t.strip_edges()))
	if clase: clase.text_changed.connect(func(t: String): _editar_perfil("clase_entrenador", t.strip_edges()))
	if frase_derrota: frase_derrota.text_changed.connect(func(): _editar_perfil("frase_derrota", frase_derrota.text))
	if sexo: sexo.item_selected.connect(func(i: int): _editar_perfil("sexo", sexo.get_item_text(i)))
	if tipo_batalla_selector: tipo_batalla_selector.item_selected.connect(func(_i): _editar_perfil("tipo_batalla", _obtener_tipo_batalla_guardada_desde_ui()))
	if num_sprite: num_sprite.value_changed.connect(func(v: float): _editar_perfil("num_sprite", int(v)))
	if ratio_dinero: ratio_dinero.value_changed.connect(func(v: float): _editar_perfil("ratio_dinero", int(v)))
	if musica_option:
		# Jingle de encuentro: índice 0-13 de TRAINER_ENCOUNTER_MUSIC_* (MusicaRubi).
		musica_option.item_selected.connect(func(i: int): _editar_perfil("jingle_id", i))
	if musica_batalla_option:
		# Tema de batalla: clave del registro; vacío = el que sale de la clase.
		musica_batalla_option.item_selected.connect(func(i: int): _editar_perfil("musica_id", "" if i <= 0 else musica_batalla_option.get_item_text(i)))
	for campo in _campos_objetos_entrenador():
		if campo:
			campo.text_changed.connect(func(_t): _editar_perfil("objetos", _obtener_objetos_desde_slots()))
	if p_nombre: p_nombre.text_changed.connect(func(t: String): _editar_pokemon("nombre_interno", t.strip_edges().to_upper()))
	if p_nivel: p_nivel.value_changed.connect(func(v: float): _editar_pokemon("nivel", int(v)))
	if p_objeto: p_objeto.text_changed.connect(func(t: String): _editar_pokemon("objeto", t.strip_edges().to_upper()))
	for campo in _campos_movimientos():
		campo.text_changed.connect(func(_t): _editar_pokemon("movimientos", _obtener_movimientos_desde_campos()))
	if num_sprite:
		num_sprite.value_changed.connect(func(_v): _actualizar_preview_trainer())

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.ctrl_pressed and event.keycode == KEY_S:
		if is_visible_in_tree():
			_guardar_json()
			get_viewport().set_input_as_handled()
			return
	if not is_instance_valid(_ac_panel) or not _ac_panel.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_ocultar_autocomplete()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not _ac_panel.get_global_rect().has_point(event.global_position):
			_ocultar_autocomplete()
			# No consumimos el evento: el click llega normalmente al control que corresponda

func _exit_tree():	# Cerrar conexión de base de datos al salir
	if db:
		db.close_db()
		print("🔌 [EditorEntrenadores] Conexión de base de datos cerrada")
	# Detener audio si está sonando
	if _audio_player and _audio_player.playing:
		_audio_player.stop()
	# Cerrar ventanas auxiliares
	if is_instance_valid(_editor_temas):
		_editor_temas.queue_free()
	if is_instance_valid(_ventana_clases):
		_ventana_clases.queue_free()
	# Limpiar timer de animación
	if animation_timer:
		animation_timer.queue_free()

func _inicializar_animacion():
	print("🎬 [EditorEntrenadores] Inicializando sistema de animación de iconos")
	animation_timer = Timer.new()
	animation_timer.timeout.connect(_animar_iconos_pokemon)
	animation_timer.wait_time = 0.3  # Cambiar frame cada segundo
	animation_timer.autostart = true
	add_child(animation_timer)

func _animar_iconos_pokemon():
	# Alternar entre frame 0 y 1
	current_frame = 1 - current_frame
	# Actualizar todos los iconos visibles en las cards
	for card in cards_visibles:
		_actualizar_iconos_animados_en_card(card)
	# Actualizar iconos en el ItemList del equipo del entrenador seleccionado
	_actualizar_iconos_pokemon()

func _actualizar_iconos_animados_en_card(card: Control):
	var entrenador_idx = card.get_meta("entrenador_idx", -1)
	if entrenador_idx < 0 or entrenador_idx >= entrenadores.size():
		return

	var entrenador = entrenadores[entrenador_idx]
	var pokemon_list = entrenador.get("pokemon", [])

	# Actualizar iconos de los 6 slots
	for i in range(6):
		var slot_path = "HMain/VInfo/HPokemon/Slot%d/Icon" % (i + 1)
		var icon_node = card.get_node_or_null(slot_path)
		if icon_node and i < pokemon_list.size():
			var pokemon_data = pokemon_list[i]
			var nombre_interno = pokemon_data.get("nombre_interno", "")
			if nombre_interno != "":
				var nueva_texture = _icono_pokemon_anim_frame(nombre_interno, current_frame)
				if nueva_texture:
					icon_node.texture = nueva_texture

var dirty: bool = false

func _campos_objetos_entrenador() -> Array:
	return [
		objeto_slot_1,
		objeto_slot_2,
		objeto_slot_3,
		objeto_slot_4,
		objeto_slot_5,
		objeto_slot_6,
	]

func _limpiar_slots_objetos() -> void:
	for campo in _campos_objetos_entrenador():
		if campo:
			campo.text = ""

func _cargar_slots_objetos(objetos_guardados: Array) -> void:
	_limpiar_slots_objetos()
	var campos := _campos_objetos_entrenador()
	for i in range(min(objetos_guardados.size(), campos.size())):
		var campo: LineEdit = campos[i]
		if campo:
			campo.text = str(objetos_guardados[i])

func _obtener_objetos_desde_slots() -> Array:
	var objetos_guardados: Array = []
	for campo_raw in _campos_objetos_entrenador():
		var campo := campo_raw as LineEdit
		if campo == null:
			continue
		var valor: String = campo.text.strip_edges()
		if valor != "":
			objetos_guardados.append(valor)
	return objetos_guardados

func _normalizar_tipo_batalla_guardada(valor: Variant) -> String:
	var clave := str(valor).strip_edges().to_upper()
	if clave == CLAVE_TIPO_BATALLA_DOBLE:
		return CLAVE_TIPO_BATALLA_DOBLE
	return CLAVE_TIPO_BATALLA_SIMPLE

func _seleccionar_tipo_batalla_guardada(valor: Variant) -> void:
	if not tipo_batalla_selector:
		return
	var clave := _normalizar_tipo_batalla_guardada(valor)
	var indice := Singleton.TipoBatallaEntrenador.SIMPLE
	if clave == CLAVE_TIPO_BATALLA_DOBLE:
		indice = Singleton.TipoBatallaEntrenador.DOBLE
	tipo_batalla_selector.select(indice)

func _obtener_tipo_batalla_guardada_desde_ui() -> String:
	if not tipo_batalla_selector:
		return CLAVE_TIPO_BATALLA_SIMPLE
	if tipo_batalla_selector.get_selected_id() == Singleton.TipoBatallaEntrenador.DOBLE:
		return CLAVE_TIPO_BATALLA_DOBLE
	return CLAVE_TIPO_BATALLA_SIMPLE

func _campos_movimientos() -> Array[LineEdit]:
	var campos: Array[LineEdit] = []
	if p_movs_grid:
		for i in range(1, 5):
			var campo := p_movs_grid.get_node_or_null("PMov%d" % i) as LineEdit
			if campo:
				campos.append(campo)
	return campos

## Movimientos fijos del Pokémon (sin vacíos, en orden).
func _obtener_movimientos_desde_campos() -> Array:
	var movs: Array = []
	for campo in _campos_movimientos():
		var valor := campo.text.strip_edges().to_upper()
		if valor != "":
			movs.append(valor)
	return movs

## Escribe una clave del entrenador seleccionado y refresca lo que depende de ella.
func _editar_perfil(clave: String, valor: Variant) -> void:
	if _cargando or entrenador_index < 0 or entrenador_index >= entrenadores.size():
		return
	var d := entrenadores[entrenador_index]
	if d.get(clave) == valor:
		return
	d[clave] = valor
	_marcar_dirty()
	match clave:
		"frase_derrota":
			_actualizar_preview_frase()
		"ratio_dinero", "tipo_batalla":
			_actualizar_panel_info()
	_actualizar_card_entrenador(entrenador_index)

## Escribe una clave del Pokémon seleccionado del equipo.
func _editar_pokemon(clave: String, valor: Variant) -> void:
	if _cargando or entrenador_index < 0 or entrenador_index >= entrenadores.size():
		return
	var lista: Array = entrenadores[entrenador_index].get("pokemon", [])
	if pokemon_index < 0 or pokemon_index >= lista.size():
		return
	var p: Dictionary = lista[pokemon_index]
	if p.get(clave) == valor:
		return
	p[clave] = valor
	_marcar_dirty()
	_rellenar_slot(pokemon_index)
	_actualizar_en_combate()
	_actualizar_panel_info()
	_actualizar_card_entrenador(entrenador_index)

func _normalizar_entrenador_data(d: Dictionary) -> void:
	d["tipo_batalla"] = _normalizar_tipo_batalla_guardada(d.get("tipo_batalla", CLAVE_TIPO_BATALLA_SIMPLE))
	if not d.has("ratio_dinero"):
		d["ratio_dinero"] = TiposEntrenadorData.obtener_ratio_dinero(str(d.get("clase_entrenador", "ENTRENADOR")))
	if not d.has("frase_derrota"):
		d["frase_derrota"] = "..."
	if not d.has("objetos") or not (d["objetos"] is Array):
		d["objetos"] = []
	if not d.has("pokemon") or not (d["pokemon"] is Array):
		d["pokemon"] = []

func _marcar_dirty():
	_fijar_dirty(true)
	if estado:
		estado.text = "* Cambios sin guardar"

func _fijar_dirty(valor: bool) -> void:
	var cambia := dirty != valor
	dirty = valor
	if cambia:
		titulo_cambiado.emit(dirty)

func _cargar_json():
	entrenadores.clear()
	var content := _leer_archivo(RUTA_JSON)
	if content == "":
		print("❌ [EditorEntrenadores] No se pudo leer JSON")
		estado.text = "No se pudo leer JSON"
		return
	# ListaEntrenadoresJson conserva el orden de claves y convierte los números
	# enteros a int, así guardar sin cambios deja el archivo idéntico.
	var data := ListaEntrenadoresJson.cargar(content)
	if not data.is_empty():
		for d in data:
			if typeof(d) == TYPE_DICTIONARY:
				# Asegurar campo id entero secuencial
				if not d.has("id") or typeof(d["id"]) != TYPE_INT:
					d["id"] = _generar_siguiente_id_temporal()
				else:
					if d["id"] > next_id_cache:
						next_id_cache = d["id"]
				_normalizar_entrenador_data(d)
				entrenadores.append(d)
		# Ajustar next para nuevas altas
		next_id_cache += 1
		_refrescar_lista()
		estado.text = "Cargados %d entrenadores" % entrenadores.size()
	else:
		print("❌ [EditorEntrenadores] Formato JSON inválido")
		estado.text = "Formato JSON inválido"

func _leer_archivo(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f = FileAccess.open(path, FileAccess.READ)
	if f:
		var t = f.get_as_text()
		f.close()
		return t
	return ""

func _conectar_base_datos():
	print("🔌 [EditorEntrenadores] Conectando a base de datos...")
	if not FileAccess.file_exists(RUTA_BASE_DATOS):
		print("❌ [EditorEntrenadores] Base de datos no encontrada: %s" % RUTA_BASE_DATOS)
		return

	# Crear conexión directa usando SQLite
	db = SQLite.new()
	db.path = RUTA_BASE_DATOS

	if db.open_db():
		print("✅ [EditorEntrenadores] Base de datos conectada exitosamente")
	else:
		print("❌ [EditorEntrenadores] Error al conectar a la base de datos")
		db = null

func _obtener_datos_pokemon_desde_db(nombre_interno: String) -> Dictionary:
	if not db:
		print("❌ [EditorEntrenadores] No hay conexión a base de datos")
		return {}

	return _datos_pokemon(nombre_interno)

func _escribir_archivo(path: String, texto: String) -> bool:
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(texto)
		f.close()
		return true
	return false

func _refrescar_lista():
	if not vbox_cards:
		return
	for c in vbox_cards.get_children():
		if c != card_template:
			c.queue_free()
	cards_visibles.clear()
	card_seleccionada_idx = -1
	var texto_nombre := filtro_nombre.text.strip_edges().to_lower() if filtro_nombre else ""
	var texto_clase := filtro_clase.text.strip_edges().to_lower() if filtro_clase else ""
	var texto_pokemon := filtro_pokemon.text.strip_edges().to_lower() if filtro_pokemon else ""
	var repetidos := ValidadorEntrenador.ids_repetidos(entrenadores)
	# Los tiers de una misma revancha se agrupan bajo su entrada de TablaRevanchas;
	# grupos y entrenadores sueltos se ordenan por el ID del tier 1 / su ID.
	var grupos := {}  # índice de entrada -> [[tier, idx_real], ...]
	var elementos: Array = []  # [orden, "grupo"/"suelto", índice de entrada o idx_real]
	for i in entrenadores.size():
		var d := entrenadores[i]
		if not _coincide_filtros(d, texto_nombre, texto_clase, texto_pokemon):
			continue
		var id := int(d.get("id", 0))
		var entrada := TablaRevanchas.indice_por_cualquier_id(id)
		if entrada < 0:
			elementos.append([id, "suelto", i])
			continue
		if not grupos.has(entrada):
			grupos[entrada] = []
			elementos.append([int(TablaRevanchas.entradas()[entrada]["ids"][0]), "grupo", entrada])
		grupos[entrada].append([_tier_de(entrada, id), i])
	elementos.sort_custom(func(a, b): return a[0] < b[0])
	for elemento in elementos:
		if elemento[1] == "suelto":
			_anadir_card(elemento[2], 0, repetidos)
			continue
		var entrada: int = elemento[2]
		var miembros: Array = grupos[entrada]
		miembros.sort_custom(func(a, b): return a[0] < b[0])
		vbox_cards.add_child(_crear_cabecera_grupo(entrada, miembros.size()))
		if not _grupos_plegados.has(entrada):
			for m in miembros:
				_anadir_card(m[1], m[0], repetidos)
	var card := _card_de_indice(entrenador_index)
	if card:
		_resaltar_card(card)
	elif entrenador_index < 0:
		_limpiar_formulario()

func _coincide_filtros(d: Dictionary, texto_nombre: String, texto_clase: String, texto_pokemon: String) -> bool:
	if texto_nombre != "" and str(d.get("nombre", "")).to_lower().find(texto_nombre) == -1:
		return false
	if texto_clase != "" and str(d.get("clase_entrenador", "")).to_lower().find(texto_clase) == -1:
		return false
	if texto_pokemon == "":
		return true
	for pk in d.get("pokemon", []):
		if str(pk.get("nombre_interno", "")).to_lower().find(texto_pokemon) != -1:
			return true
	return false

## Tier (1..5) de `id` dentro de la entrada de revancha.
func _tier_de(entrada: int, id: int) -> int:
	return TablaRevanchas.entradas()[entrada]["ids"].find(id) + 1

func _anadir_card(idx_real: int, tier: int, repetidos: Dictionary) -> void:
	var card := _crear_card_entrenador_desde_template(entrenadores[idx_real], idx_real, tier, repetidos)
	if card:
		vbox_cards.add_child(card)
		cards_visibles.append(card)

func _crear_cabecera_grupo(entrada: int, visibles: int) -> Button:
	var e: Dictionary = TablaRevanchas.entradas()[entrada]
	var total := 0
	for tid in e["ids"]:
		if int(tid) != 0:
			total += 1
	var cabecera := Button.new()
	cabecera.flat = true
	cabecera.alignment = HORIZONTAL_ALIGNMENT_LEFT
	cabecera.text = "%s %s · %s · revancha (%d/%d tiers)" % [
		"▸" if _grupos_plegados.has(entrada) else "▾", _nombre_grupo(entrada), _lugar_grupo(entrada), visibles, total]
	cabecera.tooltip_text = "Entrada %d de la tabla de revanchas (gTrainerEyeTrainers)." % entrada
	cabecera.pressed.connect(func():
		if _grupos_plegados.has(entrada):
			_grupos_plegados.erase(entrada)
		else:
			_grupos_plegados[entrada] = true
		_refrescar_lista()
	)
	return cabecera

## Nombre visible de una entrada de revancha: el del registro del tier 1 en
## lista_entrenadores.json (nombre oficial, p. ej. LIDIA); si no existe, el de la
## constante del decomp que guarda tabla_revanchas.json (LYDIA).
func _nombre_grupo(entrada: int) -> String:
	var e: Dictionary = TablaRevanchas.entradas()[entrada]
	var idx := _indice_por_id(int(e["ids"][0]))
	var nombre_json := str(entrenadores[idx].get("nombre", "")).strip_edges() if idx >= 0 else ""
	return nombre_json if not nombre_json.is_empty() else str(e["nombre"])

## Lugar de una entrada: el nombre presentable del mapa del NPC que usa el tier 1
## (p. ej. RUTA 117); si ninguno lo usa todavía, el mapa del decomp (ROUTE117).
func _lugar_grupo(entrada: int) -> String:
	var e: Dictionary = TablaRevanchas.entradas()[entrada]
	var usos: Array = _usos.get(int(e["ids"][0]), [])
	return _nombre_escena_presentable(str(usos[0]).get_slice(" › ", 0)) if not usos.is_empty() else str(e["mapa"])

## Nombre presentable de una escena de mapa, como el cartel de lugar del juego:
## `seccion` del mapa (Lugares.seccion_de_escena) → `LUGAR_<seccion>` en
## dialogos.csv. Se lee el CSV directamente porque en el editor TranslationServer no
## tiene por qué tener cargadas las traducciones del proyecto. Si falta la sección o la
## traducción, devuelve el nombre interno de la escena (ruta_117).
func _nombre_escena_presentable(escena: String) -> String:
	if _nombres_lugar.has(escena):
		return _nombres_lugar[escena]
	var nombre := escena
	var seccion := Lugares.seccion_de_escena(escena)
	if not seccion.is_empty():
		if _filas_dialogos.is_empty():
			_filas_dialogos = DialogosCSV.cargar()["filas"]
		var fila: Dictionary = _filas_dialogos.get(Lugares.PREFIJO_TRADUCCION + seccion, {})
		var traducido := str(fila.get("es", "")).strip_edges()
		if not traducido.is_empty():
			nombre = traducido
	_nombres_lugar[escena] = nombre
	return nombre

func _card_de_indice(idx: int) -> Control:
	if idx < 0:
		return null
	for card in cards_visibles:
		if int(card.get_meta("entrenador_idx", -1)) == idx:
			return card
	return null

## Selecciona un entrenador por índice (despliega su grupo si hace falta).
func _seleccionar_por_indice(idx: int) -> void:
	if idx < 0 or idx >= entrenadores.size():
		return
	entrenador_index = idx
	var entrada := TablaRevanchas.indice_por_cualquier_id(int(entrenadores[idx].get("id", 0)))
	if _grupos_plegados.has(entrada) or _card_de_indice(idx) == null:
		_grupos_plegados.erase(entrada)
		_refrescar_lista()
	_cargar_entrenador(entrenadores[idx])
	var card := _card_de_indice(idx)
	if card:
		_seleccionar_card_por_control(card)
		_scroll_a_card(card)

## Selecciona el registro con ese ID (lo pide el inspector de un NPC entrenador).
## Si los filtros lo ocultan, se limpian. Devuelve false si el ID no existe.
func seleccionar_entrenador_id(id: int) -> bool:
	var idx := _indice_por_id(id)
	if idx < 0:
		if estado:
			estado.text = "El ID %d no está en lista_entrenadores.json." % id
		return false
	var d := entrenadores[idx]
	if not _coincide_filtros(d,
			filtro_nombre.text.strip_edges().to_lower() if filtro_nombre else "",
			filtro_clase.text.strip_edges().to_lower() if filtro_clase else "",
			filtro_pokemon.text.strip_edges().to_lower() if filtro_pokemon else ""):
		for filtro in [filtro_nombre, filtro_clase, filtro_pokemon]:
			if filtro:
				filtro.text = ""
		_refrescar_lista()
	_seleccionar_por_indice(idx)
	if estado and not dirty:
		estado.text = "Abierto desde el inspector: ID %d" % id
	return true

func _aplicar_filtro(_t=""):
	_refrescar_lista()

func _limpiar_formulario():
	_cargando = true
	clase.text = ""
	nombre.text = ""
	if frase_derrota:
		frase_derrota.text = ""
	if campo_id:
		campo_id.text = ""
	sexo.select(0)
	_seleccionar_tipo_batalla_guardada(CLAVE_TIPO_BATALLA_SIMPLE)
	num_sprite.value = 1
	ratio_dinero.value = TiposEntrenadorData.obtener_ratio_dinero("ENTRENADOR")
	if musica_option: musica_option.select(0)
	if musica_batalla_option: musica_batalla_option.select(0)
	_limpiar_slots_objetos()
	_limpiar_campos_pokemon()
	_cargando = false
	_reconstruir_equipo()
	_actualizar_preview_frase()
	_actualizar_panel_info()
	_actualizar_en_combate()

func _limpiar_campos_pokemon() -> void:
	p_nombre.text = ""
	p_nivel.value = 1
	p_objeto.text = ""
	for campo in _campos_movimientos():
		campo.text = ""
	pokemon_index = -1

func _seleccionar_entrenador(idx: int):
	# Mapear índice visible a índice real (sin filtro simple se alinean; para robustez recalcular)
	# Ya no se usa directamente porque cada card tiene su propio handler
	pass

func _cargar_entrenador(d: Dictionary):
	_cargando = true
	clase.text = str(d.get("clase_entrenador", ""))
	nombre.text = str(d.get("nombre", ""))
	if frase_derrota:
		frase_derrota.text = str(d.get("frase_derrota", "..."))
	sexo.select(0 if str(d.get("sexo","M")) == "M" else 1)
	_seleccionar_tipo_batalla_guardada(d.get("tipo_batalla", CLAVE_TIPO_BATALLA_SIMPLE))
	num_sprite.value = int(d.get("num_sprite", 1))
	ratio_dinero.value = int(d.get(
		"ratio_dinero",
		TiposEntrenadorData.obtener_ratio_dinero(str(d.get("clase_entrenador", "ENTRENADOR")))
	))
	# Jingle de encuentro (índice) y tema de batalla (clave del registro).
	if musica_option and musica_option.item_count > 0:
		musica_option.select(clampi(int(d.get("jingle_id", 0)), 0, musica_option.item_count - 1))
	var mid = str(d.get("musica_id", ""))
	if musica_batalla_option:
		var idx_music := 0
		for i in range(1, musica_batalla_option.item_count):
			if musica_batalla_option.get_item_text(i) == mid:
				idx_music = i
				break
		musica_batalla_option.select(idx_music)
	_cargar_slots_objetos(d.get("objetos", []))
	if campo_id:
		campo_id.text = str(d.get("id", 0))
	_limpiar_campos_pokemon()
	_cargando = false
	_reconstruir_equipo()
	# Cambiar de entrenador nunca descarta ni "limpia" cambios pendientes.
	if estado and not dirty:
		estado.text = "Entrenador cargado"
	_actualizar_preview_trainer()
	_actualizar_iconos_pokemon()
	_actualizar_tooltips_pokemon()
	_actualizar_estado_btn_add()
	_actualizar_preview_frase()
	_actualizar_panel_info()
	_actualizar_en_combate()

func _actualizar_estado_btn_add() -> void:
	if not btn_add_pokemon:
		return
	if entrenador_index < 0 or entrenador_index >= entrenadores.size():
		btn_add_pokemon.disabled = true
		return
	var count: int = entrenadores[entrenador_index].get("pokemon", []).size()
	btn_add_pokemon.disabled = (count >= 6)

func _obtener_nombre_mostrable_pokemon(nombre_interno: String) -> String:
	var datos = _datos_pokemon(nombre_interno)
	if datos.size() > 0 and datos.has("nombre"):
		return str(datos.get("nombre", nombre_interno))
	return nombre_interno

func _obtener_nombre_mostrable_movimiento(nombre_interno: String) -> String:
	var datos = _datos_movimiento(nombre_interno)
	if datos.size() > 0 and datos.has("nombre"):
		return str(datos.get("nombre", nombre_interno))
	return nombre_interno

func _obtener_nombre_mostrable_objeto(nombre_interno: String) -> String:
	var filas := _consultar_db("SELECT nombre FROM Objetos WHERE nombre_interno = ?", [nombre_interno])
	return str(filas[0].get("nombre", nombre_interno)) if not filas.is_empty() else nombre_interno

func _nuevo_entrenador():
	var d = {
		"id": _generar_siguiente_id_temporal(),
		"clase_entrenador": "ENTRENADOR",
		"ratio_dinero": TiposEntrenadorData.obtener_ratio_dinero("ENTRENADOR"),
		"num_sprite": 1,
		"nombre": "NUEVO",
		"frase_derrota": "...",
		"sexo": "M",
		"tipo_batalla": CLAVE_TIPO_BATALLA_SIMPLE,
		"musica_id": "BATALLA_ENTRENADOR",
		"jingle_id": 0,
		"objetos": [],
		"pokemon": []
	}
	entrenadores.append(d)
	_marcar_dirty()
	_seleccionar_por_indice(entrenadores.size() - 1)
	estado.text = "Creado nuevo entrenador"

func _duplicar_entrenador():
	if entrenador_index < 0:
		return
	var copia = entrenadores[entrenador_index].duplicate(true)
	copia["nombre"] = str(copia.get("nombre","")) + "_COPY"
	copia["id"] = _generar_siguiente_id_temporal()
	entrenadores.append(copia)
	_marcar_dirty()
	_seleccionar_por_indice(entrenadores.size() - 1)
	estado.text = "Entrenador duplicado"

func _borrar_entrenador():
	if entrenador_index < 0:
		return
	entrenadores.remove_at(entrenador_index)
	entrenador_index = -1
	_marcar_dirty()
	_refrescar_lista()
	estado.text = "Entrenador eliminado"

## Pide a plugin.gd abrir la ventana nativa de prueba de batallas con este
## entrenador preseleccionado. plugin.gd conecta esta señal en _abrir_editor_entrenadores_ventana.
signal solicitar_debug_batalla(registro: Dictionary)

## Abre la ventana nativa de prueba de batallas con el entrenador activo.
func _on_debug_batalla_presionado() -> void:
	if entrenador_index < 0 or entrenador_index >= entrenadores.size():
		estado.text = "Selecciona un entrenador antes de abrir Debug Batalla."
		return
	estado.text = "Abriendo Debug Batalla con %s..." % str(entrenadores[entrenador_index].get("nombre", "?"))
	solicitar_debug_batalla.emit(entrenadores[entrenador_index].duplicate(true))

func _agregar_pokemon():
	if entrenador_index < 0:
		return
	var p = {"movimientos": [], "nivel": 5, "nombre_interno": "TREECKO", "objeto": ""}
	entrenadores[entrenador_index]["pokemon"].append(p)
	_marcar_dirty()
	_cargar_entrenador(entrenadores[entrenador_index])
	var nuevo: int = entrenadores[entrenador_index]["pokemon"].size() - 1
	_seleccionar_pokemon(nuevo)
	_actualizar_card_entrenador(entrenador_index)
	estado.text = "Pokémon agregado"

func _seleccionar_pokemon(idx: int):
	pokemon_index = idx
	var lista = entrenadores[entrenador_index].get("pokemon", [])
	if idx < 0 or idx >= lista.size():
		return
	var p = lista[idx]
	_cargando = true
	p_nombre.text = str(p.get("nombre_interno",""))
	p_nivel.value = int(p.get("nivel",1))
	p_objeto.text = str(p.get("objeto",""))
	var fijos: Array = p.get("movimientos", [])
	var campos := _campos_movimientos()
	for i in campos.size():
		campos[i].text = str(fijos[i]) if i < fijos.size() else ""
	_cargando = false
	_resaltar_slot()
	_actualizar_en_combate()

func _eliminar_pokemon():
	if entrenador_index < 0 or pokemon_index < 0:
		return
	var lista = entrenadores[entrenador_index].get("pokemon", [])
	if pokemon_index >= lista.size():
		return
	lista.remove_at(pokemon_index)
	_marcar_dirty()
	_cargar_entrenador(entrenadores[entrenador_index])
	_actualizar_card_entrenador(entrenador_index)
	estado.text = "Pokémon eliminado"

func _guardar_json():
	if not dirty:
		estado.text = "Nada que guardar"
		return
	# Los formularios ya escriben en vivo en `entrenadores`; solo queda serializar.
	var ok = _escribir_archivo(RUTA_JSON, ListaEntrenadoresJson.serializar(entrenadores))
	if ok:
		_fijar_dirty(false)
		if estado:
			estado.text = "Guardado OK (%d entrenadores)" % entrenadores.size()
		_refrescar_lista()
	else:
		if estado:
			estado.text = "Error al guardar"
	_recalcular_next_id()

func _revertir():
	entrenador_index = -1
	_usos = UsosEntrenador.escanear()
	_nombres_lugar.clear()
	_filas_dialogos.clear()
	_cargar_json()
	_fijar_dirty(false)
	if estado:
		estado.text = "Revertido"
	_recalcular_next_id()

# ═══════════════════════════════════════════════════════════════════════════════
# INFORMACIÓN DERIVADA: revancha, usos, premio, nombre oficial, avisos
# ═══════════════════════════════════════════════════════════════════════════════

func _avisos_de(d: Dictionary, repetidos: Dictionary) -> PackedStringArray:
	return ValidadorEntrenador.validar(d, _existe_especie, _existe_movimiento, _existe_objeto, repetidos)

func _indice_por_id(id: int) -> int:
	for i in entrenadores.size():
		if int(entrenadores[i].get("id", 0)) == id:
			return i
	return -1

func _rango_niveles(d: Dictionary) -> String:
	var niveles: Array = []
	for p in d.get("pokemon", []):
		niveles.append(int(p.get("nivel", 1)))
	if niveles.is_empty():
		return "—"
	var minimo: int = niveles.min()
	var maximo: int = niveles.max()
	return str(minimo) if minimo == maximo else "%d–%d" % [minimo, maximo]

## Fórmula de BattleResultController.calcular_premio_entrenador.
func _premio(d: Dictionary) -> int:
	var equipo: Array = d.get("pokemon", [])
	if equipo.is_empty():
		return 0
	var doble := str(d.get("tipo_batalla", "")) == CLAVE_TIPO_BATALLA_DOBLE
	return maxi(int(d.get("ratio_dinero", 0)), 0) * 4 * maxi(int(equipo[-1].get("nivel", 0)), 0) * (2 if doble else 1)

func _actualizar_panel_info() -> void:
	if tiers_revancha:
		for c in tiers_revancha.get_children():
			c.queue_free()
	if entrenador_index < 0 or entrenador_index >= entrenadores.size():
		if lbl_revancha: lbl_revancha.text = "Selecciona un entrenador"
		if lbl_usado_en: lbl_usado_en.text = "Usado en: —"
		if lbl_premio: lbl_premio.text = "Premio: —"
		if lbl_nombre_oficial: lbl_nombre_oficial.visible = false
		if lbl_avisos: lbl_avisos.visible = false
		return
	var d := entrenadores[entrenador_index]
	var id := int(d.get("id", 0))
	# Cadena de revancha: un botón por tier; los que faltan, deshabilitados.
	var entrada := TablaRevanchas.indice_por_cualquier_id(id)
	var ids_uso: Array = [id]
	if lbl_revancha:
		lbl_revancha.text = "Sin revancha"
	if entrada >= 0 and tiers_revancha:
		var e: Dictionary = TablaRevanchas.entradas()[entrada]
		ids_uso = [int(e["ids"][0])]
		lbl_revancha.text = "Revancha %s (%s):" % [_nombre_grupo(entrada), _lugar_grupo(entrada)]
		for t in e["ids"].size():
			var tid := int(e["ids"][t])
			if tid == 0:
				continue
			var boton := Button.new()
			boton.text = "T%d · %d" % [t + 1, tid]
			boton.toggle_mode = true
			boton.button_pressed = tid == id
			var idx := _indice_por_id(tid)
			if idx < 0:
				boton.disabled = true
				boton.tooltip_text = "El ID %d no está en lista_entrenadores.json." % tid
			else:
				boton.tooltip_text = "Nv %s" % _rango_niveles(entrenadores[idx])
				boton.pressed.connect(func(): _seleccionar_por_indice(idx))
			tiers_revancha.add_child(boton)
	# Usado en: los tiers 2-5 los usa el NPC del tier 1.
	if lbl_usado_en:
		var usos: Array = _usos.get(ids_uso[0], [])
		var sufijo := "" if ids_uso[0] == id else " (vía el tier 1)"
		lbl_usado_en.text = "Usado en: %s%s" % [", ".join(usos) if not usos.is_empty() else "ningún NPC", sufijo if not usos.is_empty() else ""]
	if lbl_premio:
		var equipo: Array = d.get("pokemon", [])
		var nivel_ultimo := int(equipo[-1].get("nivel", 0)) if not equipo.is_empty() else 0
		lbl_premio.text = "Premio: %d$  (ratio %d × 4 × Nv %d del último%s)" % [
			_premio(d), int(d.get("ratio_dinero", 0)), nivel_ultimo,
			" × 2 por DOBLE" if str(d.get("tipo_batalla", "")) == CLAVE_TIPO_BATALLA_DOBLE else ""]
	if lbl_nombre_oficial:
		var oficial := str(_nombres_oficiales.get(id, ""))
		lbl_nombre_oficial.visible = oficial != "" and oficial != str(d.get("nombre", ""))
		lbl_nombre_oficial.text = "Nombre oficial (ROM española): %s" % oficial
	if lbl_avisos:
		var avisos := _avisos_de(d, ValidadorEntrenador.ids_repetidos(entrenadores))
		lbl_avisos.visible = not avisos.is_empty()
		lbl_avisos.text = "⚠ " + "\n⚠ ".join(avisos)

## Los 4 movimientos con los que entra en combate el Pokémon seleccionado:
## fijos en color de acento, de nivel en gris.
func _actualizar_en_combate() -> void:
	if not en_combate_grid:
		return
	for c in en_combate_grid.get_children():
		c.queue_free()
	if entrenador_index < 0 or pokemon_index < 0:
		return
	var lista: Array = entrenadores[entrenador_index].get("pokemon", [])
	if pokemon_index >= lista.size():
		return
	var p: Dictionary = lista[pokemon_index]
	var fijos: Array = []
	for mov in p.get("movimientos", []):
		fijos.append(str(mov).strip_edges().to_upper())
	var movs := _movimientos_en_combate(p)
	if movs.is_empty():
		var vacio := Label.new()
		vacio.text = "(sin movimientos)"
		en_combate_grid.add_child(vacio)
		return
	for mov in movs:
		var lbl := Label.new()
		lbl.text = _obtener_nombre_mostrable_movimiento(mov)
		lbl.add_theme_color_override("font_color", COLOR_MOV_FIJO if fijos.has(mov) else COLOR_MOV_NIVEL)
		var dm := _datos_movimiento(mov)
		lbl.tooltip_text = "%s · %s · Pot %s · Prec %s" % [
			"Fijo" if fijos.has(mov) else "Por nivel", str(dm.get("tipo_nombre", "?")),
			str(dm.get("poder", "-")), str(dm.get("precision", "-"))]
		lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		en_combate_grid.add_child(lbl)

## Líneas de la frase tal como las parte la caja de texto (\n, \l, \p).
func _lineas_frase(texto: String) -> PackedStringArray:
	var normalizado := texto.replace("\\n", "\n").replace("\\l", "\n").replace("\\p", "\n")
	return normalizado.split("\n")

func _actualizar_preview_frase() -> void:
	if not preview_frase:
		return
	for c in preview_frase.get_children():
		c.queue_free()
	var texto := frase_derrota.text if frase_derrota else ""
	var desborda := false
	for linea in _lineas_frase(texto):
		var lbl := Label.new()
		lbl.text = linea
		lbl.custom_minimum_size.x = ANCHO_CAJA_BATALLA
		lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		var ancho := 0.0
		if _fuente_batalla:
			lbl.add_theme_font_override("font", _fuente_batalla)
			lbl.add_theme_font_size_override("font_size", TAMANO_FUENTE_BATALLA)
			ancho = _fuente_batalla.get_string_size(linea, HORIZONTAL_ALIGNMENT_LEFT, -1, TAMANO_FUENTE_BATALLA).x
		if ancho > ANCHO_CAJA_BATALLA:
			lbl.add_theme_color_override("font_color", COLOR_AVISO)
			desborda = true
		lbl.tooltip_text = "%d / %d px" % [int(ancho), int(ANCHO_CAJA_BATALLA)]
		preview_frase.add_child(lbl)
	if desborda:
		var aviso := Label.new()
		aviso.text = "⚠ Alguna línea no cabe en la caja de batalla (%d px)." % int(ANCHO_CAJA_BATALLA)
		aviso.add_theme_color_override("font_color", COLOR_AVISO)
		preview_frase.add_child(aviso)

func _cargar_nombres_oficiales() -> void:
	_nombres_oficiales.clear()
	if not FileAccess.file_exists(RUTA_NOMBRES_OFICIALES):
		return
	var f := FileAccess.open(RUTA_NOMBRES_OFICIALES, FileAccess.READ)
	if f == null:
		return
	var cabecera := f.get_csv_line()
	var col_id := cabecera.find("trainer_id")
	var col_nombre := cabecera.find("official_name")
	if col_id < 0 or col_nombre < 0:
		return
	while not f.eof_reached():
		var fila := f.get_csv_line()
		if fila.size() > maxi(col_id, col_nombre) and fila[col_id].is_valid_int():
			_nombres_oficiales[int(fila[col_id])] = fila[col_nombre]

# ═══════════════════════════════════════════════════════════════════════════════
# CIERRE DE LA VENTANA
# ═══════════════════════════════════════════════════════════════════════════════

## Lo llama plugin.gd al pedir cerrar la ventana. Con cambios pendientes pregunta
## Guardar / Descartar / Cancelar; emite `cierre_confirmado` si se puede cerrar.
func solicitar_cierre() -> void:
	if not dirty:
		cierre_confirmado.emit()
		return
	if not is_instance_valid(_dialogo_cierre):
		_dialogo_cierre = ConfirmationDialog.new()
		_dialogo_cierre.title = "Cambios sin guardar"
		_dialogo_cierre.dialog_text = "Hay cambios sin guardar en lista_entrenadores.json."
		_dialogo_cierre.ok_button_text = "Guardar"
		_dialogo_cierre.cancel_button_text = "Cancelar"
		_dialogo_cierre.add_button("Descartar", true, "descartar")
		_dialogo_cierre.confirmed.connect(func():
			_guardar_json()
			if not dirty:
				cierre_confirmado.emit()
		)
		_dialogo_cierre.custom_action.connect(func(accion: StringName):
			if accion == &"descartar":
				_dialogo_cierre.hide()
				_fijar_dirty(false)
				cierre_confirmado.emit()
		)
		add_child(_dialogo_cierre)
	_dialogo_cierre.popup_centered()

func _generar_siguiente_id_temporal() -> int:
	if next_id_cache <= 0:
		# Calcular si no está seteado
		_recalcular_next_id()
	var res = next_id_cache
	next_id_cache += 1
	return res

func _recalcular_next_id():
	var max_id := 0
	for d in entrenadores:
		if d.has("id") and typeof(d["id"]) == TYPE_INT:
			if d["id"] > max_id:
				max_id = d["id"]
	next_id_cache = max_id + 1

func _id_en_uso(id_val: int) -> bool:
	for d in entrenadores:
		if d.get("id", -1) == id_val:
			return true
	return false

func _cargar_trainer_frames():
	if ResourceLoader.exists(RUTA_TRAINERS_FRAMES):
		trainer_frames = load(RUTA_TRAINERS_FRAMES)
		if trainer_frames and trainer_frames is SpriteFrames:
			var anim = "default"
			if trainer_frames.has_animation(anim):
				trainer_total_frames = trainer_frames.get_frame_count(anim)
			if label_sprite_count:
				label_sprite_count.text = str(trainer_total_frames) + " frames"
	else:
		print("⚠️ [EditorEntrenadores] No se encontró spritesheet de entrenadores")

func _actualizar_preview_trainer():
	if not preview_trainer:
		return
	if not trainer_frames:
		preview_trainer.texture = null
		return
	var frame_index = int(num_sprite.value) if num_sprite else 0
	if frame_index < 0:
		frame_index = 0
	if trainer_total_frames > 0 and frame_index >= trainer_total_frames:
		frame_index = trainer_total_frames - 1
	var tex: Texture2D = null
	if trainer_frames.has_animation("default"):
		tex = trainer_frames.get_frame_texture("default", frame_index)
	preview_trainer.texture = tex
	preview_trainer.tooltip_text = "Frame: %d" % frame_index

func _icono_para_nombre_interno(nombre_interno: String) -> Texture2D:
	var datos := _datos_pokemon(nombre_interno)
	if not datos.has("numero_nacional"):
		return null
	var ruta := RUTA_ICONOS_POKEMON + "icon%03d.png" % int(datos["numero_nacional"])
	if icon_cache.has(ruta):
		return icon_cache[ruta]
	var tex: Texture2D = load(ruta) if ResourceLoader.exists(ruta) else null
	icon_cache[ruta] = tex
	return tex

func _actualizar_iconos_pokemon():
	if not equipo_slots or entrenador_index < 0 or entrenador_index >= entrenadores.size():
		return
	var poke_list: Array = entrenadores[entrenador_index].get("pokemon", [])
	for i in mini(poke_list.size(), equipo_slots.get_child_count()):
		var icono := equipo_slots.get_child(i).find_child("Icono", true, false) as TextureRect
		if icono:
			icono.texture = _icono_pokemon_anim_frame(str(poke_list[i].get("nombre_interno", "")), current_frame)

# ═══════════════════════════════════════════════════════════════════════════════
# EQUIPO: una tarjeta por Pokémon (icono arriba, detalles en vertical debajo)
# ═══════════════════════════════════════════════════════════════════════════════

func _reconstruir_equipo() -> void:
	if not equipo_slots:
		return
	# free() inmediato: las tarjetas nunca se reconstruyen desde su propia señal.
	for c in equipo_slots.get_children():
		c.free()
	if entrenador_index < 0 or entrenador_index >= entrenadores.size():
		return
	var lista: Array = entrenadores[entrenador_index].get("pokemon", [])
	for i in lista.size():
		equipo_slots.add_child(_crear_slot_pokemon(i))
		_rellenar_slot(i)
	_resaltar_slot()

func _crear_slot_pokemon(i: int) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(112, 0)
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.105882, 0.12549, 0.160784)
	estilo.set_border_width_all(1)
	estilo.border_color = Color(0.223529, 0.266667, 0.341176)
	estilo.set_corner_radius_all(10)
	estilo.set_content_margin_all(6)
	slot.add_theme_stylebox_override("panel", estilo)
	slot.set_meta("estilo", estilo)
	slot.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_seleccionar_pokemon(i)
	)
	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 2)
	slot.add_child(vbox)
	var icono := TextureRect.new()
	icono.name = "Icono"
	icono.custom_minimum_size = Vector2(48, 48)
	icono.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icono.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(icono)
	for nombre_lbl in ["Nombre", "Info"]:
		var lbl := Label.new()
		lbl.name = nombre_lbl
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		lbl.custom_minimum_size.x = 1
		if nombre_lbl == "Info":
			lbl.add_theme_font_size_override("font_size", 12)
			lbl.add_theme_color_override("font_color", COLOR_MOV_NIVEL)
		vbox.add_child(lbl)
	vbox.add_child(HSeparator.new())
	var movs := VBoxContainer.new()
	movs.name = "Movs"
	movs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	movs.add_theme_constant_override("separation", 0)
	vbox.add_child(movs)
	return slot

## Especie, nivel y tipos, y los 4 movimientos en combate (fijos en color, de
## nivel en gris). Se llama al crear la tarjeta y al editar el Pokémon.
func _rellenar_slot(i: int) -> void:
	if not equipo_slots or i < 0 or i >= equipo_slots.get_child_count():
		return
	var lista: Array = entrenadores[entrenador_index].get("pokemon", [])
	if i >= lista.size():
		return
	var p: Dictionary = lista[i]
	var slot := equipo_slots.get_child(i) as PanelContainer
	var nombre_int := str(p.get("nombre_interno", "")).strip_edges().to_upper()
	var datos := _datos_pokemon(nombre_int)
	slot.tooltip_text = _tooltip_pokemon(p)
	(slot.find_child("Icono", true, false) as TextureRect).texture = _icono_pokemon_anim_frame(nombre_int, current_frame)
	(slot.find_child("Nombre", true, false) as Label).text = _obtener_nombre_mostrable_pokemon(nombre_int)
	(slot.find_child("Info", true, false) as Label).text = "Nv %d · %s" % [
		int(p.get("nivel", 1)), _tipos_de_pokemon(datos) if not datos.is_empty() else "¿especie?"]
	var movs := slot.find_child("Movs", true, false) as VBoxContainer
	for c in movs.get_children():
		c.free()
	var fijos: Array = []
	for mov in p.get("movimientos", []):
		fijos.append(str(mov).strip_edges().to_upper())
	for mov in _movimientos_en_combate(p):
		var lbl := Label.new()
		lbl.text = _obtener_nombre_mostrable_movimiento(mov)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		lbl.custom_minimum_size.x = 1
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", COLOR_MOV_FIJO if fijos.has(mov) else COLOR_MOV_NIVEL)
		movs.add_child(lbl)

func _resaltar_slot() -> void:
	if not equipo_slots:
		return
	for i in equipo_slots.get_child_count():
		var estilo := equipo_slots.get_child(i).get_meta("estilo") as StyleBoxFlat
		var sel := i == pokemon_index
		estilo.border_color = COLOR_MOV_FIJO if sel else Color(0.223529, 0.266667, 0.341176)
		estilo.set_border_width_all(2 if sel else 1)
		estilo.bg_color = Color(0.13, 0.19, 0.25) if sel else Color(0.105882, 0.12549, 0.160784)

func _crear_card_entrenador_desde_template(d: Dictionary, idx_real: int, tier: int = 0, repetidos: Dictionary = {}) -> Control:
	if not card_template:
		return _crear_card_entrenador(d, idx_real)
	var card = card_template.duplicate()
	card.name = "CardEntrenador_%d" % idx_real
	card.visible = true
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.set_meta("entrenador_idx", idx_real)
	card.set_meta("tier", tier)
	# Los tiers de una revancha van sangrados bajo la cabecera de su grupo.
	var hmain := card.get_node_or_null("HMain")
	if tier > 0 and hmain:
		var sangria := Control.new()
		sangria.custom_minimum_size = Vector2(14, 0)
		sangria.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hmain.add_child(sangria)
		hmain.move_child(sangria, 0)
	for i in range(1, 7):
		var slot_node = card.get_node_or_null("HMain/VInfo/HPokemon/Slot%d" % i)
		if slot_node:
			slot_node.mouse_filter = Control.MOUSE_FILTER_PASS
	card.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			entrenador_index = idx_real
			_cargar_entrenador(entrenadores[idx_real])
			_seleccionar_card_por_control(card)
	)
	_rellenar_card(card, d, tier, repetidos)
	return card

## Sprite, nombre, línea de datos (tier, ID, niveles, DOBLE), avisos e iconos.
func _rellenar_card(card: Control, d: Dictionary, tier: int, repetidos: Dictionary) -> void:
	var sprite_trainer = card.get_node_or_null("HMain/SpriteTrainer")
	if sprite_trainer:
		var sprite_idx := int(d.get("num_sprite", 1))
		sprite_trainer.texture = _texture_trainer_frame(sprite_idx)
		sprite_trainer.tooltip_text = "Sprite %d" % sprite_idx
	var lbl_clase_nombre = card.get_node_or_null("HMain/VInfo/LblClaseNombre")
	if lbl_clase_nombre:
		lbl_clase_nombre.text = "%s %s" % [str(d.get("clase_entrenador", "?")), str(d.get("nombre", "?"))]
	var lbl_meta = card.get_node_or_null("HMain/VInfo/HMeta/LblMeta")
	if lbl_meta:
		var partes: PackedStringArray = []
		if tier > 0:
			partes.append("T%d" % tier)
		partes.append("ID %d" % int(d.get("id", 0)))
		partes.append("Nv %s" % _rango_niveles(d))
		if str(d.get("tipo_batalla", "")) == CLAVE_TIPO_BATALLA_DOBLE:
			partes.append("DOBLE")
		lbl_meta.text = " · ".join(partes)
	var lbl_aviso = card.get_node_or_null("HMain/VInfo/HMeta/LblAviso")
	if lbl_aviso:
		var avisos := _avisos_de(d, repetidos)
		lbl_aviso.visible = not avisos.is_empty()
		lbl_aviso.text = "⚠ %d" % avisos.size()
		lbl_aviso.tooltip_text = "\n".join(avisos)
	var lista_p = d.get("pokemon", [])
	for s in range(6):
		var icon_node = card.get_node_or_null("HMain/VInfo/HPokemon/Slot%d/Icon" % (s + 1))
		if not icon_node:
			continue
		if s < lista_p.size():
			var pk: Dictionary = lista_p[s]
			var nombre_interno := str(pk.get("nombre_interno", ""))
			icon_node.texture = _icono_pokemon_anim_frame(nombre_interno, current_frame)
			icon_node.tooltip_text = _tooltip_pokemon(pk)
			icon_node.modulate = Color.WHITE
		else:
			icon_node.texture = null
			icon_node.tooltip_text = ""
			icon_node.modulate = Color(0.4, 0.4, 0.4, 0.3)

func _manejar_input_teclado(event: InputEvent):
	if not event is InputEventKey or not event.pressed:
		return

	match event.keycode:
		KEY_UP:
			_navegar_card(-1)
			get_viewport().set_input_as_handled()
		KEY_DOWN:
			_navegar_card(1)
			get_viewport().set_input_as_handled()
		KEY_LEFT:
			_navegar_card(-5)  # RePag
			get_viewport().set_input_as_handled()
		KEY_RIGHT:
			_navegar_card(5)   # AvPag
			get_viewport().set_input_as_handled()

func _navegar_card(delta: int):
	if cards_visibles.size() == 0:
		return

	var nuevo_idx = card_seleccionada_idx + delta
	nuevo_idx = clamp(nuevo_idx, 0, cards_visibles.size() - 1)

	if nuevo_idx != card_seleccionada_idx:
		card_seleccionada_idx = nuevo_idx
		var card = cards_visibles[card_seleccionada_idx]

		# Buscar el entrenador correspondiente
		var card_name = card.name
		if card_name.begins_with("CardEntrenador_"):
			var idx_str = card_name.substr(15)  # Después de "CardEntrenador_"
			if idx_str.is_valid_int():
				var idx_real = int(idx_str)
				if idx_real >= 0 and idx_real < entrenadores.size():
					entrenador_index = idx_real
					_cargar_entrenador(entrenadores[idx_real])
					_resaltar_card(card)
					_scroll_a_card(card)

func _seleccionar_card_por_control(card: Control):
	# Encontrar índice en cards_visibles
	for i in range(cards_visibles.size()):
		if cards_visibles[i] == card:
			card_seleccionada_idx = i
			break
	_resaltar_card(card)
	if scroll_lista:
		scroll_lista.grab_focus()

func _scroll_a_card(card: Control):
	if not scroll_lista or not is_instance_valid(card):
		return
	# Tras reconstruir la lista las tarjetas nuevas aún no tienen posición (el
	# contenedor las ordena en diferido): se espera a que se coloquen.
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(card) and card.is_inside_tree():
		scroll_lista.ensure_control_visible(card)

func _crear_card_entrenador(d: Dictionary, idx_real: int) -> Control:
	# Método fallback por código puro (por si no hay template)
	var card = PanelContainer.new()
	card.name = "CardEntrenador_%d" % idx_real
	card.custom_minimum_size = Vector2(0, 136)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var h = HBoxContainer.new()
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(h)
	# Resto del código simplificado...
	return card

func _resaltar_card(card: Control):
	for c in cards_visibles:
		c.self_modulate = Color(0.75, 0.9, 1.3) if c == card else Color.WHITE

func _texture_trainer_frame(idx: int) -> Texture2D:
	if not trainer_frames:
		return null
	if idx < 0:
		idx = 0
	if trainer_total_frames > 0 and idx >= trainer_total_frames:
		idx = trainer_total_frames - 1
	if trainer_frames.has_animation("default"):
		return trainer_frames.get_frame_texture("default", idx)
	return null

func _icono_pokemon_anim_frame(nombre_interno: String, frame: int) -> Texture2D:
	var cache_key := nombre_interno + ":" + str(frame)
	if _frame_cache.has(cache_key):
		return _frame_cache[cache_key]

	var base_tex := _icono_para_nombre_interno(nombre_interno)
	if base_tex == null:
		return null

	var w := base_tex.get_width()
	var h := base_tex.get_height()
	var result: Texture2D

	if w == 64 and h == 32:
		# Dos frames lado a lado: frame 0 = izquierda, frame 1 = derecha
		var atlas := AtlasTexture.new()
		atlas.atlas = base_tex
		atlas.region = Rect2(frame * 32, 0, 32, 32)
		atlas.filter_clip = true
		result = atlas
	elif w == 32 and h == 64:
		# Dos frames apilados: frame 0 = arriba, frame 1 = abajo
		var atlas := AtlasTexture.new()
		atlas.atlas = base_tex
		atlas.region = Rect2(0, frame * 32, 32, 32)
		atlas.filter_clip = true
		result = atlas
	else:
		result = base_tex

	_frame_cache[cache_key] = result
	return result

func _actualizar_tooltips_pokemon():
	if not equipo_slots or entrenador_index < 0 or entrenador_index >= entrenadores.size():
		return
	var poke_list: Array = entrenadores[entrenador_index].get("pokemon", [])
	for i in mini(poke_list.size(), equipo_slots.get_child_count()):
		equipo_slots.get_child(i).tooltip_text = _tooltip_pokemon(poke_list[i])

func _tooltip_pokemon(p: Dictionary) -> String:
	var nombre_int = str(p.get("nombre_interno","?"))
	var nivel = int(p.get("nivel",1))
	var datos_pk = _datos_pokemon(nombre_int)
	var linea_pk = nombre_int
	if datos_pk.size() > 0:
		var nombre_mostrar = str(datos_pk.get("nombre", nombre_int))
		var num = datos_pk.get("numero_nacional", "?")
		var tipos_txt = _tipos_de_pokemon(datos_pk)
		linea_pk = "#%s %s (%s) Nv%d" % [str(num), nombre_mostrar, tipos_txt, nivel]
	else:
		linea_pk = "%s Nv%d" % [nombre_int, nivel]
	# Movimientos con los que entra en combate (nivel + fijos, MovimientosEntrenador).
	var movs: Array = _movimientos_en_combate(p)
	var movs_lineas: Array[String] = []
	for m in movs:
		var dm = _datos_movimiento(str(m))
		if dm.size() > 0:
			var tipo_nom = dm.get("tipo_nombre", dm.get("tipo_id", "?"))
			var poder = dm.get("poder", "-")
			var precision = dm.get("precision", "-")
			var nombre_mov_mostrable = str(dm.get("nombre", m))
			movs_lineas.append("• %s (%s) Pow:%s Acc:%s" % [nombre_mov_mostrable, str(tipo_nom), str(poder), str(precision)])
		else:
			movs_lineas.append("• %s" % str(m))
	if movs_lineas.size() == 0:
		movs_lineas.append("(Sin movimientos)")
	if p.get("objeto", "") != "":
		var obj_mostrable = _obtener_nombre_mostrable_objeto(str(p.get("objeto")))
		movs_lineas.append("Objeto: %s" % obj_mostrable)
	return linea_pk + "\n" + "\n".join(movs_lineas)

## Consulta con parámetros sobre la conexión SQLite propia del plugin (aquí no
## existen los autoloads como DatabaseManager).
func _consultar_db(consulta: String, parametros: Array) -> Array:
	if not db or not db.query_with_bindings(consulta, parametros):
		return []
	return db.query_result.duplicate()

func _datos_pokemon(nombre_interno: String) -> Dictionary:
	if pokemon_cache.has(nombre_interno):
		return pokemon_cache[nombre_interno]
	var filas := _consultar_db("""
		SELECT p.numero_nacional, p.nombre, t1.nombre AS tipo_1, t2.nombre AS tipo_2
		FROM Pokemon p
		LEFT JOIN Tipos t1 ON t1.id = p.tipo_1_id
		LEFT JOIN Tipos t2 ON t2.id = p.tipo_2_id
		WHERE p.nombre_interno = ?""", [nombre_interno])
	var datos: Dictionary = filas[0] if not filas.is_empty() else {}
	pokemon_cache[nombre_interno] = datos
	return datos

func _datos_movimiento(nombre_interno: String) -> Dictionary:
	if movimiento_cache.has(nombre_interno):
		return movimiento_cache[nombre_interno]
	var filas := _consultar_db("""
		SELECT m.nombre, m.poder, m.precision, t.nombre AS tipo_nombre
		FROM Movimientos m LEFT JOIN Tipos t ON t.id = m.tipo_id
		WHERE m.nombre_interno = ?""", [nombre_interno])
	var datos: Dictionary = filas[0] if not filas.is_empty() else {}
	movimiento_cache[nombre_interno] = datos
	return datos

func _existe_especie(nombre_interno: String) -> bool:
	return not _datos_pokemon(nombre_interno).is_empty()

func _existe_movimiento(nombre_interno: String) -> bool:
	return not _datos_movimiento(nombre_interno).is_empty()

func _existe_objeto(nombre_interno: String) -> bool:
	return _ac_lista_objetos.has(nombre_interno)

## Learnset por nivel (misma consulta que DatosCrianza, versión ruby-sapphire).
var _learnset_cache: Dictionary = {}
func _learnset(especie: String) -> Array:
	if _learnset_cache.has(especie):
		return _learnset_cache[especie]
	var resultado: Array = []
	for fila in _consultar_db(DatosCrianza.SQL_MOVIMIENTOS_NIVEL, [especie, DatosCrianza.METODO_NIVEL, DatosCrianza.VERSION_GRUPO]):
		var nivel = fila.get("nivel")
		resultado.append({"nivel": 0 if nivel == null else int(nivel), "mov": str(fila.get("nombre_interno", ""))})
	_learnset_cache[especie] = resultado
	return resultado

## Movimientos con los que el Pokémon entra en combate (MovimientosEntrenador).
func _movimientos_en_combate(p: Dictionary) -> Array[String]:
	var especie := str(p.get("nombre_interno", "")).strip_edges().to_upper()
	return MovimientosEntrenador.resolver(_learnset(especie), int(p.get("nivel", 1)), p.get("movimientos", []))

func _tipos_de_pokemon(datos_pk: Dictionary) -> String:
	var t1 := str(datos_pk.get("tipo_1", "")) if datos_pk.get("tipo_1") != null else ""
	var t2 := str(datos_pk.get("tipo_2", "")) if datos_pk.get("tipo_2") != null else ""
	if t2 != "" and t2 != t1:
		return t1 + "/" + t2
	return t1 if t1 != "" else "?"

# ═══════════════════════════════════════════════════════════════════════════════
# SISTEMA DE MÚSICA
# ═══════════════════════════════════════════════════════════════════════════════

func _cargar_temas_json() -> void:
	var content := _leer_archivo(TEMAS_JSON_PATH)
	if content == "":
		return
	var data = JSON.parse_string(content)
	if typeof(data) == TYPE_DICTIONARY and data.has("temas"):
		_temas_registrados = data["temas"]
	# Poblar option después de que los @onready estén listos (se llama desde _ready)

func _poblar_opciones_musica() -> void:
	_poblar_opciones_jingle()
	_poblar_opciones_musica_batalla()


## Jingles de encuentro de la ROM: la posición en la lista es el `jingle_id`.
func _poblar_opciones_jingle() -> void:
	if not musica_option:
		return
	var seleccion_actual := musica_option.selected
	musica_option.clear()
	var tabla: Dictionary = MusicaRubiScript.JINGLE_POR_INDICE
	for indice in range(tabla.size()):
		musica_option.add_item(str(tabla.get(indice, "")))
	musica_option.select(clampi(seleccion_actual, 0, maxi(musica_option.item_count - 1, 0)))


func _poblar_opciones_musica_batalla() -> void:
	if not musica_batalla_option:
		return
	var seleccion_actual := musica_batalla_option.get_item_text(musica_batalla_option.selected) if musica_batalla_option.selected > 0 else ""
	musica_batalla_option.clear()
	musica_batalla_option.add_item("(automática)")
	var claves: Array = _temas_registrados.keys()
	claves.sort()
	var idx_seleccionado := 0
	for i in claves.size():
		var clave: String = claves[i]
		musica_batalla_option.add_item(clave)
		if clave == seleccion_actual:
			idx_seleccionado = i + 1
	musica_batalla_option.select(idx_seleccionado)

func _crear_audio_player() -> void:
	_audio_player = AudioStreamPlayer.new()
	add_child(_audio_player)
	_audio_player.finished.connect(_on_musica_terminada)
	# Poblar la lista ahora que los nodos están listos
	_poblar_opciones_musica()

func _on_play_musica_presionado() -> void:
	if not musica_option:
		return
	_toggle_reproduccion_musica(musica_option.get_item_text(musica_option.selected))


func _on_play_musica_batalla_presionado() -> void:
	if not musica_batalla_option:
		return
	var idx := musica_batalla_option.selected
	_toggle_reproduccion_musica("" if idx <= 0 else musica_batalla_option.get_item_text(idx))


## Un único reproductor: el texto ▶/■ se actualiza en los dos botones.
func _texto_botones_play(texto: String) -> void:
	if btn_play_musica: btn_play_musica.text = texto
	if btn_play_musica_batalla: btn_play_musica_batalla.text = texto

func _toggle_reproduccion_musica(clave: String) -> void:
	if not _audio_player:
		return
	if _audio_player.playing and _tema_reproduciendo == clave:
		_audio_player.stop()
		_texto_botones_play("▶")
		_tema_reproduciendo = ""
		return
	if _audio_player.playing:
		_audio_player.stop()
		_texto_botones_play("▶")
		_tema_reproduciendo = ""
	if clave == "" or not _temas_registrados.has(clave):
		return
	var datos: Dictionary = _temas_registrados[clave]
	var ruta_audio: String = str(datos.get("ruta", AUDIO_BASE_PATH + str(datos.get("archivo", ""))))
	if not ResourceLoader.exists(ruta_audio):
		push_warning("[EditorEntrenadores] No se encontró audio: %s" % ruta_audio)
		return
	var stream := load(ruta_audio) as AudioStream
	if not stream:
		return
	_audio_player.stream = stream
	_audio_player.volume_db = linear_to_db(float(datos.get("volumen", 1.0)))
	_audio_player.play()
	_tema_reproduciendo = clave
	_texto_botones_play("■")

func _on_musica_terminada() -> void:
	_tema_reproduciendo = ""
	_texto_botones_play("▶")

func _on_config_musica_presionado() -> void:
	var clave := ""
	if musica_option and musica_option.item_count > 0:
		clave = musica_option.get_item_text(musica_option.selected)
	_abrir_editor_musica(clave)


func _on_config_musica_batalla_presionado() -> void:
	var clave := ""
	if musica_batalla_option and musica_batalla_option.selected > 0:
		clave = musica_batalla_option.get_item_text(musica_batalla_option.selected)
	_abrir_editor_musica(clave)

func _abrir_editor_musica(clave_inicial: String) -> void:
	if not is_instance_valid(_editor_temas):
		var escena = load(_EDITOR_TEMAS_ESCENA)
		if not escena:
			push_error("[EditorEntrenadores] No se pudo cargar %s" % _EDITOR_TEMAS_ESCENA)
			return
		_editor_temas = escena.instantiate()
		add_child(_editor_temas)
		_editor_temas.temas_guardados.connect(func(temas: Dictionary):
			_temas_registrados = temas
			_poblar_opciones_musica())
	_editor_temas.abrir(clave_inicial)

# ═══════════════════════════════════════════════════════════════════════════════
# ACTUALIZAR CARD EN LISTA
# ═══════════════════════════════════════════════════════════════════════════════

func _actualizar_card_entrenador(idx: int) -> void:
	if idx < 0 or idx >= entrenadores.size():
		return
	var card := _card_de_indice(idx)
	if card:
		_rellenar_card(card, entrenadores[idx], int(card.get_meta("tier", 0)), ValidadorEntrenador.ids_repetidos(entrenadores))

# ═══════════════════════════════════════════════════════════════════════════════
# VENTANA CLASES DE ENTRENADORES
# ═══════════════════════════════════════════════════════════════════════════════

func _abrir_ventana_clases(modo: String) -> void:
	_vc_modo_seleccion = modo
	if not is_instance_valid(_ventana_clases):
		_construir_ventana_clases()
	_vc_refrescar_cards()
	_ventana_clases.title = "Clases de Entrenadores — Seleccionar %s" % ("Clase" if modo == "clase" else "Sprite")
	_ventana_clases.popup_centered()

func _construir_ventana_clases() -> void:
	_ventana_clases = Window.new()
	_ventana_clases.title = "Clases de Entrenadores"
	_ventana_clases.size = Vector2i(520, 500)
	_ventana_clases.min_size = Vector2i(400, 360)
	_ventana_clases.close_requested.connect(func(): _ventana_clases.hide())
	add_child(_ventana_clases)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	_ventana_clases.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var lbl_fuente := Label.new()
	lbl_fuente.text = "Fuente de metadatos: res://BaseDatos/tipos_entrenador.gd."
	lbl_fuente.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_fuente.add_theme_font_size_override("font_size", 11)
	lbl_fuente.modulate = Color(0.92, 0.92, 0.92)
	vbox.add_child(lbl_fuente)

	# Campo de filtro
	_vc_filtro = LineEdit.new()
	_vc_filtro.placeholder_text = "Filtrar por nombre de clase..."
	_vc_filtro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vc_filtro.text_changed.connect(func(_t): _vc_refrescar_cards())
	vbox.add_child(_vc_filtro)

	# Scroll con las tarjetas
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_vc_vbox = VBoxContainer.new()
	_vc_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vc_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(_vc_vbox)

func _vc_refrescar_cards() -> void:
	if not is_instance_valid(_vc_vbox):
		return
	for c in _vc_vbox.get_children():
		c.queue_free()

	var filtro_txt := _vc_filtro.text.strip_edges().to_lower() if is_instance_valid(_vc_filtro) else ""
	var total := trainer_total_frames if trainer_total_frames > 0 else TiposEntrenadorData.obtener_cantidad_sprites_configurados()

	for frame_idx in range(total):
		var nombre_clase: String = TiposEntrenadorData.obtener_clase_por_sprite(frame_idx)
		if filtro_txt != "" and nombre_clase.to_lower().find(filtro_txt) == -1 \
				and str(frame_idx).find(filtro_txt) == -1:
			continue
		var info := {"num_sprite": frame_idx, "clase": nombre_clase}
		_vc_vbox.add_child(_vc_crear_card(info))

func _vc_crear_card(info: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	card.add_child(hbox)

	# Sprite del entrenador
	var sprite_rect := TextureRect.new()
	sprite_rect.custom_minimum_size = Vector2(64, 64)
	sprite_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite_rect.texture = _texture_trainer_frame(info.get("num_sprite", 0))
	hbox.add_child(sprite_rect)

	# Columna con nombre + botones
	var vinfo := VBoxContainer.new()
	vinfo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vinfo.add_theme_constant_override("separation", 4)
	hbox.add_child(vinfo)

	var clase_val: String = info.get("clase", "")
	var sprite_val: int = info.get("num_sprite", 0)
	var ratio_clase := TiposEntrenadorData.obtener_ratio_dinero(clase_val)

	var lbl_clase := Label.new()
	lbl_clase.text = info.get("clase", "")
	lbl_clase.add_theme_font_size_override("font_size", 13)
	vinfo.add_child(lbl_clase)

	var lbl_ratio := Label.new()
	lbl_ratio.text = "Ratio dinero por defecto: %d" % ratio_clase
	lbl_ratio.add_theme_font_size_override("font_size", 11)
	vinfo.add_child(lbl_ratio)

	var lbl_sprite := Label.new()
	lbl_sprite.text = "Frame: %d" % info.get("num_sprite", 0)
	lbl_sprite.add_theme_font_size_override("font_size", 10)
	vinfo.add_child(lbl_sprite)

	var hbtns := HBoxContainer.new()
	hbtns.add_theme_constant_override("separation", 4)
	vinfo.add_child(hbtns)

	var btn_sel_clase := Button.new()
	btn_sel_clase.text = "Clase"
	btn_sel_clase.tooltip_text = "Aplicar clase y ratio dinero por defecto (%d)" % ratio_clase
	btn_sel_clase.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_sel_clase.pressed.connect(func():
		if clase:
			clase.text = clase_val
		if ratio_dinero:
			ratio_dinero.value = ratio_clase
		_marcar_dirty()
		if is_instance_valid(_ventana_clases):
			_ventana_clases.hide())
	hbtns.add_child(btn_sel_clase)

	var btn_sel_sprite := Button.new()
	btn_sel_sprite.text = "Sprite"
	btn_sel_sprite.tooltip_text = "Aplicar solo el número de sprite"
	btn_sel_sprite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_sel_sprite.pressed.connect(func():
		if num_sprite:
			num_sprite.value = sprite_val
			_marcar_dirty()
		if is_instance_valid(_ventana_clases):
			_ventana_clases.hide())
	hbtns.add_child(btn_sel_sprite)

	var btn_ambos := Button.new()
	btn_ambos.text = "Ambos"
	btn_ambos.tooltip_text = "Aplicar clase y sprite a la vez"
	btn_ambos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_ambos.pressed.connect(func():
		if clase:
			clase.text = clase_val
		if ratio_dinero:
			ratio_dinero.value = ratio_clase
		if num_sprite:
			num_sprite.value = sprite_val
		_marcar_dirty()
		if is_instance_valid(_ventana_clases):
			_ventana_clases.hide())
	hbtns.add_child(btn_ambos)

	return card

# ═══════════════════════════════════════════════════════════════════════════════
# AUTOCOMPLETADO
# ═══════════════════════════════════════════════════════════════════════════════

func _cargar_listas_autocomplete() -> void:
	# Pokémon
	if db:
		db.query("SELECT nombre_interno FROM pokemon ORDER BY nombre_interno")
		for row in db.query_result:
			var ni = str(row.get("nombre_interno", ""))
			if ni != "":
				_ac_lista_pokemon.append(ni)
	# Si la tabla se llama de otra forma, intento con DatabaseManager
	if _ac_lista_pokemon.is_empty():
		if has_node("/root/DatabaseManager"):
			var dm = get_node("/root/DatabaseManager")
			if dm.has_method("obtener_lista_pokemon"):
				var lista = dm.obtener_lista_pokemon()
				for item in lista:
					var ni = str(item.get("nombre_interno", ""))
					if ni != "":
						_ac_lista_pokemon.append(ni)
	# Objetos
	if db:
		db.query("SELECT nombre_interno FROM Objetos ORDER BY nombre_interno")
		for row in db.query_result:
			var ni = str(row.get("nombre_interno", ""))
			if ni != "":
				_ac_lista_objetos.append(ni)
	# Movimientos
	if db:
		db.query("SELECT nombre_interno FROM Movimientos ORDER BY nombre_interno")
		for row in db.query_result:
			var ni = str(row.get("nombre_interno", ""))
			if ni != "":
				_ac_lista_movimientos.append(ni)

func _crear_popup_autocomplete() -> void:
	# Usamos un Panel normal con top_level=true en lugar de PopupPanel.
	# Ventajas: mismas coordenadas globales que el canvas (posición correcta)
	# y no crea una ventana OS (no roba el foco del teclado).
	_ac_panel = Panel.new()
	_ac_panel.top_level = true   # ignora transformada del padre, usa coordenadas globales
	_ac_panel.hide()
	_ac_panel.z_index = 100
	_ac_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_ac_item_list = ItemList.new()
	_ac_item_list.focus_mode = Control.FOCUS_NONE  # nunca roba el foco del campo de texto
	_ac_item_list.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ac_item_list.gui_input.connect(_on_ac_list_gui_input)
	_ac_panel.add_child(_ac_item_list)
	add_child(_ac_panel)

func _on_ac_list_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var idx := _ac_item_list.get_item_at_position(event.position, true)
		if idx >= 0:
			_on_ac_item_selected(idx)

func _mostrar_autocomplete(field: LineEdit, lista: Array, multi: bool) -> void:
	if _ac_suppressing or not is_instance_valid(_ac_panel):
		return
	_ac_target = field
	_ac_multi = multi
	var query_str: String
	if multi:
		var partes := field.text.split(",")
		query_str = partes[-1].strip_edges().to_lower()
	else:
		query_str = field.text.strip_edges().to_lower()

	_ac_item_list.clear()
	var count := 0
	for item in lista:
		if query_str == "" or item.to_lower().find(query_str) != -1:
			_ac_item_list.add_item(item)
			count += 1
			if count >= 30:
				break

	if count == 0:
		_ac_panel.hide()
		return

	# Posicionar debajo del campo.
	# get_global_rect() devuelve coordenadas del canvas, igual que set_global_position().
	# Como _ac_panel tiene top_level=true ambas usan el mismo espacio → posición exacta.
	var field_rect := field.get_global_rect()
	var panel_w := maxf(field_rect.size.x, 220.0)
	const PANEL_H := 160.0
	var pos_x := field_rect.position.x
	var pos_y := field_rect.position.y + field_rect.size.y
	var vp_size := get_viewport_rect().size
	if pos_y + PANEL_H > vp_size.y:
		pos_y = field_rect.position.y - PANEL_H
	if pos_x + panel_w > vp_size.x:
		pos_x = vp_size.x - panel_w
	_ac_panel.set_global_position(Vector2(pos_x, pos_y))
	_ac_panel.custom_minimum_size = Vector2(panel_w, PANEL_H)
	_ac_panel.size = Vector2(panel_w, PANEL_H)
	_ac_panel.show()

func _ocultar_autocomplete() -> void:
	if is_instance_valid(_ac_panel):
		_ac_panel.hide()
	_ac_target = null

func _on_ac_item_selected(idx: int) -> void:
	if not is_instance_valid(_ac_target):
		_ocultar_autocomplete()
		return
	var selected_text: String = _ac_item_list.get_item_text(idx)
	var target := _ac_target  # guardar antes de que _ocultar_autocomplete() limpie _ac_target
	_ocultar_autocomplete()
	# Usamos _ac_suppressing para que asignar .text no reabra el panel
	_ac_suppressing = true
	if _ac_multi:
		var partes: Array = Array(target.text.split(","))
		if partes.size() > 0:
			partes[-1] = selected_text
		else:
			partes = [selected_text]
		target.text = ",".join(partes)
		target.caret_column = target.text.length()
	else:
		target.text = selected_text
		target.caret_column = selected_text.length()
	# Asignar .text por código no emite text_changed: se emite a mano para que la
	# edición en vivo escriba el valor elegido en el diccionario.
	target.text_changed.emit(target.text)
	_ac_suppressing = false
	target.grab_focus()

func _conectar_campos_autocomplete() -> void:
	if p_nombre:
		_conectar_autocomplete_field(p_nombre, _ac_lista_pokemon, false)
	if p_objeto:
		_conectar_autocomplete_field(p_objeto, _ac_lista_objetos, false)
	for campo in _campos_objetos_entrenador():
		if campo:
			_conectar_autocomplete_field(campo, _ac_lista_objetos, false)
	for campo in _campos_movimientos():
		_conectar_autocomplete_field(campo, _ac_lista_movimientos, false)

func _conectar_autocomplete_field(field: LineEdit, lista: Array, multi: bool) -> void:
	field.text_changed.connect(func(_t: String): _mostrar_autocomplete(field, lista, multi))
	# El panel no roba el foco, así que focus_exited sólo se dispara cuando el usuario
	# realmente navega a otro control → cerramos inmediatamente, sin timer.
	field.focus_exited.connect(_ocultar_autocomplete)
