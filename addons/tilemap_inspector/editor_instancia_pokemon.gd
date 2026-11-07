@tool
extends Control
## Editor de Instancia de Pokémon (herramienta del menú del editor, no es
## interfaz in-game). Edita filas de la tabla PokemonInstancias (SQLite del
## proyecto).
##
## Estructura: la UI está declarada en editor_instancia_pokemon.tscn; este script
## solo la controla (catálogos, generador, guardado).
##
## Flujo de trabajo: la lista de la izquierda y las pestañas de la derecha son
## independientes. Seleccionar una fila en la lista NO carga sus datos
## automáticamente; hay que pulsar "→ Leer". De igual forma, "Generar" y la
## edición manual de las pestañas no exigen tener nada seleccionado ni
## "congelan" la fila de la lista: el usuario decide después, con los botones
## centrales, si guarda esos datos en la posición seleccionada, como un
## registro nuevo, o no los guarda.
##
## API de reutilización desde otras herramientas:
##   - editor_instancia_pokemon.cargar_instancia(pokemon_id: int) -> bool
##     Carga en el formulario la instancia indicada.
##   - editor_instancia_pokemon.obtener_datos_formulario() -> Dictionary
##     Snapshot de los datos definidos actualmente en las pestañas (guardados
##     o no), incluida la nota libre.
##   - señal `datos_pokemon_solicitados(datos: Dictionary)`: se emite al pulsar
##     el botón "Seleccionar". Pensada para que una UI que necesite una
##     instancia (p. ej. un probador de batallas) escuche esta señal, o llame
##     a `obtener_datos_formulario()` después de pedirle al usuario que pulse
##     ese botón. Por ahora no hay ningún consumidor conectado; queda prevista
##     la comunicación para cuando se integre.
##   - plugin.gd: _abrir_editor_instancia_pokemon_ventana(pokemon_id: int = -1)
##     Abre (o trae al frente) la ventana del editor y precarga la instancia.
##     Para invocarlo desde otra herramienta del editor, emitir una señal propia
##     (patrón `solicitar_editor_encuentros` en config_mapas) y conectarla en plugin.gd.

signal instancia_cargada(pokemon_id: int)
signal datos_pokemon_solicitados(datos: Dictionary)

const SINGLETON_DATA := preload("res://scripts/singleton.gd")
const CalculadoraStats := preload("res://BaseDatos/calculadora_stats.gd")
const RUTA_BASE_DATOS := "res://BaseDatos/poke.db"
const RUTA_PARTIDA_GUARDADO := "res://partida/partida_guardada.json"
const MAX_SUGERENCIAS_ESPECIE := 14
const DEFAULT_MARCAS := {
	"circulo": false,
	"cuadrado": false,
	"triangulo": false,
	"corazon": false,
}
const CONTEST_STAT_FIELDS := [
	{"key": "concurso_carisma", "label": "Carisma"},
	{"key": "concurso_belleza", "label": "Belleza"},
	{"key": "concurso_dulzura", "label": "Dulzura"},
	{"key": "concurso_ingenio", "label": "Ingenio"},
	{"key": "concurso_dureza", "label": "Dureza"},
	{"key": "concurso_brillo", "label": "Brillo"},
]
const ORDEN_STATS := ["ps", "ataque", "defensa", "ataque_especial", "defensa_especial", "velocidad"]
const LABELS_STATS := {
	"ps": "PS",
	"ataque": "Ataque",
	"defensa": "Defensa",
	"ataque_especial": "At. Esp.",
	"defensa_especial": "Def. Esp.",
	"velocidad": "Velocidad",
}
const SEXOS_UI := [
	{"id": "M", "label": "Macho"},
	{"id": "F", "label": "Hembra"},
	{"id": "N", "label": "Sin sexo"},
]
const OT_SEXOS_UI := [
	{"id": "M", "label": "Masculino"},
	{"id": "F", "label": "Femenino"},
]

var db = null
var _dirty := false
var _suppress_form_events := false
var _pokemon_rows: Array = []
var _species_rows: Array = []
var _nature_rows: Array = []
var _ability_rows: Array = []
var _move_rows: Array = []
var _item_rows: Array = []
var _type_rows: Array = []

var _species_by_id: Dictionary = {}
var _nature_by_id: Dictionary = {}
var _ability_by_id: Dictionary = {}
var _ability_name_to_id: Dictionary = {}
var _move_by_id: Dictionary = {}
var _move_by_internal_name: Dictionary = {}
var _item_by_id: Dictionary = {}
var _type_by_id: Dictionary = {}
var _datos_jugador_guardado := {
	"id": 0,
	"nombre": "JUGADOR",
	"sexo": "M",
}

var _current_pokemon_id: int = -1
var _selected_list_id: int = -1
var _especie_generar_id: int = -1
var _pendiente_guardar_en_posicion_id: int = -1
var _pendiente_guardar_en_posicion_data: Dictionary = {}

var _iv_spins: Dictionary = {}
var _ev_spins: Dictionary = {}
var _stat_labels: Dictionary = {}
var _move_slots: Array = []
# Per physical slot: original canonical data never travels to another identity.
var _move_origins: Array = []
var _loaded_move_count: int = 0
const MoveRecord = preload("res://BaseDatos/move_save_record.gd")
var _mark_checks: Dictionary = {}
var _ribbon_checks: Dictionary = {}
var _contest_spins: Dictionary = {}

# --- Referencias a la UI declarada en el .tscn (nombres únicos) ---
@onready var _status_label: Label = %EstadoLabel

@onready var _generador_titulo: Label = %GeneradorTitulo
@onready var _busqueda_especie: LineEdit = %EspecieGenerarEdit
@onready var _sugerencias_panel: PanelContainer = %SugerenciasPanel
@onready var _sugerencias_lista: ItemList = %SugerenciasEspecie
@onready var _confirmar_guardar_dialog: ConfirmationDialog = %ConfirmarGuardarDialog
@onready var _nivel_generar: SpinBox = %NivelGenerarSpin
@onready var _boton_generar: Button = %BotonGenerar
@onready var _info_generador: Label = %InfoGeneradorLabel

@onready var _boton_leer: Button = %BotonLeer
@onready var _boton_guardar_posicion: Button = %BotonGuardarPosicion
@onready var _boton_guardar_nuevo: Button = %BotonGuardarNuevo
@onready var _boton_borrar: Button = %BotonBorrar
@onready var _boton_recargar: Button = %BotonRecargar
@onready var _boton_seleccionar: Button = %BotonSeleccionar
@onready var _sprite_pokemon: TextureRect = %SpritePokemon

@onready var _search_edit: LineEdit = %BusquedaEdit
@onready var _pokemon_list: ItemList = %ListaInstancias

@onready var _tabs: TabContainer = %Tabs
@onready var _notas_edit: TextEdit = %NotasEdit

@onready var _species_option: OptionButton = %EspecieOption
@onready var _species_info_label: Label = %ResumenEspecieLabel
@onready var _nickname_edit: LineEdit = %MoteEdit
@onready var _level_spin: SpinBox = %NivelSpin
@onready var _exp_spin: SpinBox = %ExpSpin
@onready var _nature_option: OptionButton = %NaturalezaOption
@onready var _ability_option: OptionButton = %HabilidadOption
@onready var _item_option: OptionButton = %ObjetoOption
@onready var _friendship_spin: SpinBox = %FelicidadSpin
@onready var _hp_actual_spin: SpinBox = %HPActualSpin
@onready var _egg_check: CheckBox = %HuevoCheck
@onready var _gender_option: OptionButton = %SexoOption
@onready var _shiny_check: CheckBox = %ShinyCheck

@onready var _encounter_place_edit: LineEdit = %LugarEdit
@onready var _encounter_ball_edit: LineEdit = %BolaEdit
@onready var _encounter_level_spin: SpinBox = %NivelEncuentroSpin
@onready var _encounter_fateful_check: CheckBox = %FatidicoCheck

@onready var _types_label: Label = %TiposLabel
@onready var _hidden_power_label: Label = %PoderOcultoLabel
@onready var _total_evs_label: Label = %EVTotalesLabel

@onready var _marcas_box: HBoxContainer = %MarcasBox
@onready var _cintas_grid: GridContainer = %CintasGrid
@onready var _concurso_grid: GridContainer = %ConcursoGrid

@onready var _ot_name_edit: LineEdit = %EONombreEdit
@onready var _ot_id_spin: SpinBox = %EOIdSpin
@onready var _boton_generar_ot_id: Button = %BotonGenerarEOId
@onready var _ot_gender_option: OptionButton = %EOSexoOption
@onready var _status_spin: SpinBox = %EstadoSpin
@onready var _infected_check: CheckBox = %InfectadoCheck
@onready var _cured_check: CheckBox = %CuradoCheck
@onready var _pokerus_days_spin: SpinBox = %PokerusDiasSpin
@onready var _pokerus_timestamp_spin: SpinBox = %PokerusTimestampSpin
@onready var _order_index_spin: SpinBox = %IndiceOrdenSpin


func _to_int(value, default_value: int = 0) -> int:
	if value == null:
		return default_value
	return int(value)


func _ready() -> void:
	_configurar_tabs()
	_registrar_controles_dinamicos()
	_conectar_senales()
	_crear_marcas()
	_crear_cintas()
	_crear_concurso()
	_ocultar_sugerencias()
	_initialize_editor()


func _exit_tree() -> void:
	if db:
		db.close_db()
		db = null


## API pública: carga en el formulario la instancia indicada por su ID.
func cargar_instancia(pokemon_id: int) -> bool:
	if pokemon_id <= 0:
		return false
	if db == null:
		_initialize_editor()
	if db == null:
		_set_status("No se pudo abrir la base de datos.", true)
		return false
	_search_edit.text = ""
	_recargar_lista(pokemon_id, true)
	var cargado: bool = not _buscar_pokemon_por_id(pokemon_id).is_empty()
	if cargado:
		_set_status("Editando #%d (solicitado por otra herramienta)." % pokemon_id)
		instancia_cargada.emit(pokemon_id)
	else:
		_set_status("No existe una instancia con ID %d." % pokemon_id, true)
	return cargado


## API publica: carga en el formulario los datos de una instancia que puede
## NO estar guardada en la BBDD (p. ej. los slots del Debug Batalla). Acepta
## el formato de columnas de la BBDD (especie_id, movimientos_json, ...) y el
## del autogenerador (nombre_interno, naturaleza/habilidad por nombre,
## movimientos como Array). Devuelve false si no resuelve la especie.
func cargar_datos_formulario(datos: Dictionary) -> bool:
	if datos.is_empty():
		return false
	var incoming: Variant = JSON.parse_string(str(datos.movimientos_json)) if datos.has("movimientos_json") else datos.get("movimientos", [])
	if not MoveRecord.valid_form_moves(incoming):
		_set_status("Invalid move fields.", true)
		return false
	if db == null:
		_initialize_editor()
	for move: Variant in incoming:
		if move == null: continue
		var resolved: Variant = _resolver_move_id(move)
		if not _move_by_id.has(resolved) or str(_move_by_id[resolved].nombre_interno).to_upper() != str(move.nombre_interno).to_upper():
			_set_status("Unknown or conflicting move identity.", true)
			return false
	var row := datos.duplicate(true)
	if int(row.get("especie_id", 0)) <= 0:
		var interno := str(row.get("nombre_interno", "")).strip_edges().to_upper()
		for especie_id in _species_by_id.keys():
			if str(_species_by_id[especie_id].get("nombre_interno", "")).to_upper() == interno:
				row["especie_id"] = int(especie_id)
				break
	if int(row.get("especie_id", 0)) <= 0:
		_set_status("No se pudo resolver la especie de los datos recibidos.", true)
		return false
	if not row.has("movimientos_json") and row.get("movimientos") is Array:
		row["movimientos_json"] = JSON.stringify(row["movimientos"])
	if not row.has("naturaleza_id") and row.has("naturaleza"):
		var nombre_naturaleza := str(row["naturaleza"]).strip_edges().to_upper()
		for fila_naturaleza in _nature_rows:
			if str(fila_naturaleza.get("nombre", "")).to_upper() == nombre_naturaleza:
				row["naturaleza_id"] = int(fila_naturaleza.get("id", 0))
				break
	if not row.has("habilidad_id") and row.has("habilidad"):
		row["habilidad_id"] = _ability_name_to_id.get(str(row["habilidad"]).strip_edges().to_upper())
	if not row.has("es_shiny") and row.has("shiny"):
		row["es_shiny"] = row["shiny"]
	if not row.has("entrenador_nombre") and row.has("entrenador_original"):
		row["entrenador_nombre"] = str(row["entrenador_original"])
	row["id"] = int(row.get("id", -1))
	_cargar_pokemon_en_formulario(row)
	if int(row["id"]) > 0:
		# El id es solo informativo: preselecciona esa fila en la lista sin
		# pisar el formulario (que muestra los datos recibidos, no la BBDD).
		_recargar_lista(int(row["id"]), false)
		_set_status("Datos del slot cargados; fila #%d preseleccionada en la lista." % int(row["id"]))
	else:
		_set_status("Datos del slot cargados en el formulario (aun sin guardar en la BBDD).")
	return true


## API pública: ID de la instancia que está siendo editada (-1 si ninguna).
func obtener_instancia_actual() -> int:
	return _current_pokemon_id


## API pública: snapshot de los datos definidos actualmente en las pestañas
## (guardados o no), incluida la nota libre. Pensado para que otra
## herramienta reciba una instancia bajo demanda (ver señal
## `datos_pokemon_solicitados` en la documentación al inicio del script).
func obtener_datos_formulario() -> Dictionary:
	var datos := _colectar_formulario()
	if datos.is_empty(): return {}
	datos["id"] = _current_pokemon_id
	return datos


func _configurar_tabs() -> void:
	var titulos := {
		"Inicio": "Inicio",
		"Encuentro": "Encuentro",
		"Estadisticas": "Estadísticas",
		"Movimientos": "Movimientos",
		"Cosmetica": "Cosmética",
		"EO_Varios": "EO/Varios",
	}
	for idx in range(_tabs.get_child_count()):
		var hijo := _tabs.get_child(idx)
		var nombre := str(hijo.name)
		if titulos.has(nombre):
			_tabs.set_tab_title(idx, titulos[nombre])


func _registrar_controles_dinamicos() -> void:
	_iv_spins = {
		"ps": %IV_PS,
		"ataque": %IV_ATAQUE,
		"defensa": %IV_DEFENSA,
		"ataque_especial": %IV_ATAQUE_ESPECIAL,
		"defensa_especial": %IV_DEFENSA_ESPECIAL,
		"velocidad": %IV_VELOCIDAD,
	}
	_ev_spins = {
		"ps": %EV_PS,
		"ataque": %EV_ATAQUE,
		"defensa": %EV_DEFENSA,
		"ataque_especial": %EV_ATAQUE_ESPECIAL,
		"defensa_especial": %EV_DEFENSA_ESPECIAL,
		"velocidad": %EV_VELOCIDAD,
	}
	_stat_labels = {
		"ps": %STAT_PS,
		"ataque": %STAT_ATAQUE,
		"defensa": %STAT_DEFENSA,
		"ataque_especial": %STAT_ATAQUE_ESPECIAL,
		"defensa_especial": %STAT_DEFENSA_ESPECIAL,
		"velocidad": %STAT_VELOCIDAD,
	}
	_move_slots = []
	for slot_idx in range(4):
		_move_slots.append({
			"option": get_node("%%MOV_OPCION_%d" % (slot_idx + 1)),
			"pp_act": get_node("%%MOV_PP_ACT_%d" % (slot_idx + 1)),
			"pp_extra": get_node("%%MOV_PP_MAS_%d" % (slot_idx + 1)),
			"pp_total_label": get_node("%%MOV_PP_TOTAL_%d" % (slot_idx + 1)),
		})


func _conectar_senales() -> void:
	# Generador
	_busqueda_especie.text_changed.connect(_on_busqueda_especie_text_changed)
	_busqueda_especie.text_submitted.connect(_on_busqueda_especie_text_submitted)
	_busqueda_especie.gui_input.connect(_on_busqueda_especie_gui_input)
	_busqueda_especie.item_rect_changed.connect(_actualizar_posicion_sugerencias)
	_sugerencias_lista.item_clicked.connect(_on_sugerencia_elegida_click)
	_boton_generar.pressed.connect(_on_generar_pressed)

	# Botonera central (transferencia lista <-> pestañas)
	_boton_leer.pressed.connect(_leer_seleccion_lista)
	_boton_guardar_posicion.pressed.connect(_guardar_en_posicion)
	_boton_guardar_nuevo.pressed.connect(_guardar_como_nuevo)
	_boton_borrar.pressed.connect(_borrar_seleccion_lista)
	_boton_recargar.pressed.connect(_recargar_solo_lista)
	_boton_seleccionar.pressed.connect(_on_seleccionar_pressed)
	_boton_generar_ot_id.pressed.connect(_generar_ot_id)
	_confirmar_guardar_dialog.confirmed.connect(_on_confirmar_guardar_en_posicion)
	_confirmar_guardar_dialog.canceled.connect(_on_cancelar_guardar_en_posicion)

	# Lista izquierda
	_search_edit.text_changed.connect(_on_search_text_changed)
	_pokemon_list.item_selected.connect(_on_pokemon_list_item_selected)
	_pokemon_list.item_activated.connect(_on_pokemon_list_item_activated)
	_pokemon_list.gui_input.connect(_on_pokemon_list_gui_input)
	visibility_changed.connect(_ocultar_sugerencias)

	# Notas (siempre visibles, fuera de las pestañas)
	_notas_edit.text_changed.connect(_on_generic_field_changed)

	# Pestaña Inicio
	_species_option.item_selected.connect(_on_species_changed)
	_gender_option.item_selected.connect(_on_generic_field_changed)
	_shiny_check.toggled.connect(_on_generic_field_changed)
	_nickname_edit.text_changed.connect(_on_generic_field_changed)
	_level_spin.value_changed.connect(_on_level_changed)
	_exp_spin.value_changed.connect(_on_generic_field_changed)
	_nature_option.item_selected.connect(_on_nature_changed)
	_ability_option.item_selected.connect(_on_generic_field_changed)
	_item_option.item_selected.connect(_on_generic_field_changed)
	_friendship_spin.value_changed.connect(_on_generic_field_changed)
	_hp_actual_spin.value_changed.connect(_on_generic_field_changed)
	_egg_check.toggled.connect(_on_generic_field_changed)

	# Pestaña Encuentro
	_encounter_place_edit.text_changed.connect(_on_generic_field_changed)
	_encounter_ball_edit.text_changed.connect(_on_generic_field_changed)
	_encounter_level_spin.value_changed.connect(_on_generic_field_changed)
	_encounter_fateful_check.toggled.connect(_on_generic_field_changed)

	# Pestaña Estadísticas
	for stat_key in ORDEN_STATS:
		_iv_spins[stat_key].value_changed.connect(_on_stats_changed)
		_ev_spins[stat_key].value_changed.connect(_on_stats_changed)

	# Pestaña Movimientos
	for slot_idx in range(_move_slots.size()):
		var slot: Dictionary = _move_slots[slot_idx]
		slot["option"].item_selected.connect(_on_move_selected.bind(slot_idx))
		slot["pp_act"].value_changed.connect(_on_move_pp_changed.bind(slot_idx))
		slot["pp_extra"].value_changed.connect(_on_move_pp_changed.bind(slot_idx))

	# Pestaña EO/Varios
	_ot_name_edit.text_changed.connect(_on_generic_field_changed)
	_ot_id_spin.value_changed.connect(_on_generic_field_changed)
	_ot_gender_option.item_selected.connect(_on_generic_field_changed)
	_status_spin.value_changed.connect(_on_generic_field_changed)
	_infected_check.toggled.connect(_on_generic_field_changed)
	_cured_check.toggled.connect(_on_generic_field_changed)
	_pokerus_days_spin.value_changed.connect(_on_generic_field_changed)
	_pokerus_timestamp_spin.value_changed.connect(_on_generic_field_changed)
	_order_index_spin.value_changed.connect(_on_generic_field_changed)


func _crear_marcas() -> void:
	for marca in ["circulo", "cuadrado", "triangulo", "corazon"]:
		var marca_check := CheckBox.new()
		marca_check.text = str(marca).capitalize()
		marca_check.toggled.connect(_on_generic_field_changed)
		_marcas_box.add_child(marca_check)
		_mark_checks[marca] = marca_check


func _crear_cintas() -> void:
	for ribbon_key in _get_cintas_ordenadas():
		var ribbon_data: Dictionary = SINGLETON_DATA.CINTAS_POKEMON.get(ribbon_key, {})
		var ribbon_check := CheckBox.new()
		ribbon_check.text = str(ribbon_data.get("nombre", ribbon_key))
		ribbon_check.tooltip_text = str(ribbon_data.get("descripcion", ""))
		ribbon_check.toggled.connect(_on_generic_field_changed)
		_cintas_grid.add_child(ribbon_check)
		_ribbon_checks[ribbon_key] = ribbon_check


func _crear_concurso() -> void:
	for field in CONTEST_STAT_FIELDS:
		var label := Label.new()
		label.text = str(field["label"])
		_concurso_grid.add_child(label)
		var spin := SpinBox.new()
		spin.min_value = 0
		spin.max_value = 255
		spin.step = 1.0
		spin.rounded = true
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spin.value_changed.connect(_on_generic_field_changed)
		_concurso_grid.add_child(spin)
		_contest_spins[field["key"]] = spin


func _initialize_editor() -> void:
	if not FileAccess.file_exists(RUTA_BASE_DATOS):
		_set_status("No se encontró la base de datos: %s" % RUTA_BASE_DATOS, true)
		return

	if db:
		db.close_db()

	db = SQLite.new()
	db.path = RUTA_BASE_DATOS
	if not db.open_db():
		db = null
		_set_status("No se pudo abrir la base de datos SQLite del proyecto.", true)
		return

	_cargar_datos_jugador_guardado()
	_asegurar_esquema_pokemon_instancias()
	_cargar_catalogos()
	_recargar_lista(-1, true)
	if _pokemon_rows.is_empty():
		_set_status("Sin registros en PokemonInstancias. Usa 'Guardar como nuevo' para crear el primero.")
	else:
		_set_status("Editor listo. %d instancias cargadas desde SQLite." % _pokemon_rows.size())


# =====================================================================
# Generador (Especie + Nivel -> llena los datos de la instancia)
# =====================================================================

func _on_busqueda_especie_text_changed(texto: String) -> void:
	var filtro := texto.strip_edges()
	if filtro.length() < 2:
		_especie_generar_id = -1
		_ocultar_sugerencias()
		return
	_mostrar_sugerencias(filtro)


func _on_busqueda_especie_text_submitted(_texto: String) -> void:
	if _sugerencias_panel.visible and _sugerencias_lista.item_count > 0:
		var seleccionados := _sugerencias_lista.get_selected_items()
		_on_sugerencia_elegida(seleccionados[0] if seleccionados.size() > 0 else 0)


func _on_busqueda_especie_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_ocultar_sugerencias()


func _mostrar_sugerencias(filtro: String) -> void:
	var filtro_upper := filtro.to_upper()
	var filtro_num := filtro.trim_prefix("#").strip_edges()
	_sugerencias_lista.clear()
	for row in _species_rows:
		var nombre := str(row.get("nombre", ""))
		var interno := str(row.get("nombre_interno", "")).to_upper()
		var numero := str(int(row.get("numero_nacional", 0)))
		var coincide := nombre.to_upper().find(filtro_upper) != -1 or interno.find(filtro_upper) != -1
		if not coincide and filtro_num != "":
			coincide = numero.find(filtro_num) != -1
		if not coincide:
			continue
		_sugerencias_lista.add_item("#%03d %s" % [int(row.get("numero_nacional", 0)), nombre])
		_sugerencias_lista.set_item_metadata(_sugerencias_lista.item_count - 1, int(row.get("id", 0)))
		if _sugerencias_lista.item_count >= MAX_SUGERENCIAS_ESPECIE:
			break

	if _sugerencias_lista.item_count == 0:
		_especie_generar_id = -1
		_ocultar_sugerencias()
		return
	_sugerencias_lista.select(0)
	_sugerencias_panel.show()
	_actualizar_posicion_sugerencias()
	_info_generador.text = "%d coincidencia(s) para \"%s\". Elige una de la lista o pulsa Enter." % [_sugerencias_lista.item_count, filtro]


func _actualizar_posicion_sugerencias() -> void:
	if not _sugerencias_panel.visible:
		return
	var rect := _busqueda_especie.get_global_rect()
	var ancho := maxf(rect.size.x, 320.0)
	_sugerencias_lista.custom_minimum_size = Vector2(ancho, 224)
	_sugerencias_panel.reset_size()
	_sugerencias_panel.position = rect.position + Vector2(0.0, rect.size.y + 2.0)


func _ocultar_sugerencias() -> void:
	if _sugerencias_panel:
		_sugerencias_panel.hide()


## ItemList.item_selected no se emite al hacer click sobre el ítem que ya
## estaba preseleccionado (el índice 0, tras _mostrar_sugerencias): por eso el
## primer resultado parecía "no responder" al click. item_clicked sí se
## emite siempre, cambie o no la selección.
func _on_sugerencia_elegida_click(index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	_on_sugerencia_elegida(index)


func _on_sugerencia_elegida(index: int) -> void:
	_especie_generar_id = _to_int(_sugerencias_lista.get_item_metadata(index), -1)
	_busqueda_especie.text = _sugerencias_lista.get_item_text(index)
	_ocultar_sugerencias()
	_info_generador.text = "Especie del generador: %s" % _busqueda_especie.text


## Resuelve el ID de especie elegido en el generador (sugerencia clicada o
## coincidencia exacta por nombre/nombre interno). Devuelve -1 si no hay.
func _resolver_especie_generadora() -> int:
	if _especie_generar_id > 0 and _species_by_id.has(_especie_generar_id):
		return _especie_generar_id
	var texto := _busqueda_especie.text.strip_edges()
	if texto == "":
		return -1
	var filtro_upper := texto.to_upper()
	for row in _species_rows:
		if str(row.get("nombre", "")).to_upper() == filtro_upper:
			return int(row.get("id", 0))
		if str(row.get("nombre_interno", "")).to_upper() == filtro_upper:
			return int(row.get("id", 0))
	return -1


func _sincronizar_generador_con_especie(species_row: Dictionary) -> void:
	if species_row.is_empty():
		_especie_generar_id = -1
		return
	_especie_generar_id = _to_int(species_row.get("id", 0))
	_busqueda_especie.text = "#%03d %s" % [_to_int(species_row.get("numero_nacional", 0)), str(species_row.get("nombre", "?"))]


func _actualizar_generador_objetivo() -> void:
	if _current_pokemon_id > 0:
		_generador_titulo.text = "Generador de instancia (especie + nivel) — editando #%d" % _current_pokemon_id
	else:
		_generador_titulo.text = "Generador de instancia (especie + nivel) — sin guardar"


func _on_generar_pressed() -> void:
	if db == null or _species_rows.is_empty():
		_set_status("No hay catálogo de especies cargado; no puedo generar datos.", true)
		return

	var species_id := _resolver_especie_generadora()
	if species_id <= 0:
		_set_status("Escribe al menos 2 letras de la especie y elige una sugerencia de la lista.", true)
		return

	var nivel := clampi(int(_nivel_generar.value), 1, 100)
	var species_row: Dictionary = _species_by_id.get(species_id, {})
	var data := _build_default_pokemon_data(species_id, nivel)

	# Conservar los campos que identifican al ejemplar actual.
	var actual := _colectar_formulario()
	data["mote"] = actual["mote"]
	data["entrenador_nombre"] = actual["entrenador_nombre"]
	data["entrenador_id"] = actual["entrenador_id"]
	data["entrenador_sexo"] = actual["entrenador_sexo"]
	data["es_shiny"] = actual["es_shiny"]
	data["encuentro_lugar"] = actual["encuentro_lugar"]
	data["encuentro_bola"] = actual["encuentro_bola"]
	data["notas"] = actual["notas"]

	_aplicar_datos_generados(data, species_row)
	_set_status("Datos generados para %s Nv.%d. Usa los botones centrales para guardarlos si quieres conservarlos." % [
		str(species_row.get("nombre", "?")),
		nivel,
	])


## Vuelca un diccionario con formato de persistencia en los controles del formulario.
func _aplicar_datos_generados(data: Dictionary, species_row: Dictionary) -> void:
	_suppress_form_events = true

	_set_selected_metadata(_species_option, int(data["especie_id"]))
	_rellenar_habilidades_para_especie(species_row, data["habilidad_id"])
	_set_selected_metadata(_nature_option, int(data["naturaleza_id"]))
	_set_selected_metadata(_item_option, data["objeto_id"])
	_set_selected_metadata(_gender_option, str(data["sexo"]))

	_level_spin.value = int(data["nivel"])
	_exp_spin.value = int(data["experiencia"])
	_friendship_spin.value = int(data["felicidad"])
	_egg_check.button_pressed = false
	_notas_edit.text = str(data.get("notas", ""))

	for stat_key in ORDEN_STATS:
		_iv_spins[stat_key].value = int(data[_nombre_columna_iv(stat_key)])
		_ev_spins[stat_key].value = int(data[_nombre_columna_ev(stat_key)])

	var max_hp := _calcular_stat_ps(species_row, int(data["nivel"]), _to_int(data["iv_ps"]), _to_int(data["ev_ps"]))
	_hp_actual_spin.max_value = max_hp
	_hp_actual_spin.value = clampi(_to_int(data["ps_actuales"]), 0, max_hp)

	_encounter_level_spin.value = int(data["encuentro_nivel"])
	_status_spin.value = _to_int(data["estado_primario"])
	_infected_check.button_pressed = false
	_cured_check.button_pressed = false
	_pokerus_days_spin.value = 0
	_pokerus_timestamp_spin.value = 0

	for marca in _mark_checks.keys():
		_mark_checks[marca].button_pressed = false
	for ribbon_key in _ribbon_checks.keys():
		_ribbon_checks[ribbon_key].button_pressed = false
	for contest_field in CONTEST_STAT_FIELDS:
		_contest_spins[str(contest_field["key"])].value = 0

	var movimientos := _parsear_array_json(data["movimientos_json"])
	if movimientos.is_empty():
		movimientos = _build_default_moves(species_row, int(data["nivel"]))
	_cargar_movimientos_en_formulario(movimientos)

	_species_info_label.text = _build_species_info_text(species_row)
	_actualizar_sprite_especie(species_row)
	_sincronizar_generador_con_especie(species_row)

	_suppress_form_events = false
	_update_stats_preview(species_row)
	_actualizar_generador_objetivo()
	_dirty = true


# =====================================================================
# Base de datos y catálogos
# =====================================================================

func _asegurar_esquema_pokemon_instancias() -> void:
	var columnas := _obtener_columnas_tabla("PokemonInstancias")
	if columnas.is_empty():
		_set_status("No se pudieron inspeccionar las columnas de PokemonInstancias.", true)
		return

	var columnas_requeridas := [
		{"nombre": "entrenador_id", "definicion": "INTEGER DEFAULT 0"},
		{"nombre": "entrenador_sexo", "definicion": "TEXT DEFAULT 'M'"},
		{"nombre": "habilidad_id", "definicion": "INTEGER"},
		{"nombre": "objeto_id", "definicion": "INTEGER"},
		{"nombre": "felicidad", "definicion": "INTEGER DEFAULT 70"},
		{"nombre": "huevo", "definicion": "BOOLEAN DEFAULT FALSE"},
		{"nombre": "infectado", "definicion": "BOOLEAN DEFAULT FALSE"},
		{"nombre": "curado", "definicion": "BOOLEAN DEFAULT FALSE"},
		{"nombre": "pokerus_dias_restantes", "definicion": "INTEGER DEFAULT 0"},
		{"nombre": "pokerus_fecha_ultimo_conteo", "definicion": "INTEGER DEFAULT 0"},
		{"nombre": "encuentro_lugar", "definicion": "TEXT DEFAULT ''"},
		{"nombre": "encuentro_bola", "definicion": "TEXT DEFAULT 'POKEBALL'"},
		{"nombre": "encuentro_nivel", "definicion": "INTEGER DEFAULT 1"},
		{"nombre": "encuentro_fatidico", "definicion": "BOOLEAN DEFAULT FALSE"},
		{"nombre": "movimientos_json", "definicion": "TEXT DEFAULT '[]'"},
		{"nombre": "marcas_json", "definicion": "TEXT DEFAULT '{\"circulo\":false,\"cuadrado\":false,\"triangulo\":false,\"corazon\":false}'"},
		{"nombre": "cintas_json", "definicion": "TEXT DEFAULT '[]'"},
		{"nombre": "concurso_carisma", "definicion": "INTEGER DEFAULT 0"},
		{"nombre": "concurso_belleza", "definicion": "INTEGER DEFAULT 0"},
		{"nombre": "concurso_dulzura", "definicion": "INTEGER DEFAULT 0"},
		{"nombre": "concurso_ingenio", "definicion": "INTEGER DEFAULT 0"},
		{"nombre": "concurso_dureza", "definicion": "INTEGER DEFAULT 0"},
		{"nombre": "concurso_brillo", "definicion": "INTEGER DEFAULT 0"},
		{"nombre": "estado_primario", "definicion": "INTEGER DEFAULT 0"},
		{"nombre": "indice_orden_original", "definicion": "INTEGER DEFAULT -1"},
		{"nombre": "notas", "definicion": "TEXT DEFAULT ''"},
	]

	for columna in columnas_requeridas:
		var nombre_columna = columna["nombre"]
		if columnas.has(nombre_columna):
			continue
		var sql = "ALTER TABLE PokemonInstancias ADD COLUMN %s %s" % [nombre_columna, columna["definicion"]]
		_ejecutar_sql(sql)

	_ejecutar_sql("UPDATE PokemonInstancias SET encuentro_nivel = nivel WHERE encuentro_nivel IS NULL OR encuentro_nivel <= 0")
	_ejecutar_sql("UPDATE PokemonInstancias SET felicidad = 70 WHERE felicidad IS NULL")
	_ejecutar_sql("UPDATE PokemonInstancias SET movimientos_json = '[]' WHERE movimientos_json IS NULL")
	_ejecutar_sql("UPDATE PokemonInstancias SET marcas_json = '{\"circulo\":false,\"cuadrado\":false,\"triangulo\":false,\"corazon\":false}' WHERE marcas_json IS NULL")
	_ejecutar_sql("UPDATE PokemonInstancias SET cintas_json = '[]' WHERE cintas_json IS NULL")
	_ejecutar_sql("UPDATE PokemonInstancias SET notas = '' WHERE notas IS NULL")
	for field in CONTEST_STAT_FIELDS:
		var column_name = str(field["key"])
		_ejecutar_sql("UPDATE PokemonInstancias SET %s = 0 WHERE %s IS NULL" % [column_name, column_name])


func _cargar_catalogos() -> void:
	_species_rows = _consulta("""
		SELECT id, numero_nacional, nombre_interno, nombre, tipo_1_id, tipo_2_id,
			base_ps, base_atq, base_def, base_atq_esp, base_def_esp, base_vel,
			prob_sexo, ratio_crecimiento, base_felicidad,
			habilidad_1, habilidad_2, habilidad_oculta,
			habilidad_1_id, habilidad_2_id, habilidad_oculta_id
		FROM Pokemon
		ORDER BY numero_nacional
	""")
	_nature_rows = _consulta("SELECT id, nombre, stat_aumentada, stat_disminuida, multiplicador_aumento, multiplicador_disminucion FROM Naturalezas ORDER BY nombre")
	_ability_rows = _consulta("SELECT id, nombre_interno, nombre FROM Habilidades ORDER BY nombre")
	_move_rows = _consulta("SELECT id, nombre_interno, nombre, pp, poder, precision, prioridad, tipo_id, descripcion FROM Movimientos ORDER BY nombre")
	_item_rows = _consulta("SELECT id, nombre_interno, nombre FROM Objetos ORDER BY nombre")
	_type_rows = _consulta("SELECT id, nombre FROM Tipos ORDER BY id")

	_species_by_id.clear()
	for row in _species_rows:
		_species_by_id[int(row.get("id", 0))] = row

	_nature_by_id.clear()
	for row in _nature_rows:
		_nature_by_id[int(row.get("id", 0))] = row

	_ability_by_id.clear()
	_ability_name_to_id.clear()
	for row in _ability_rows:
		var ability_id = int(row.get("id", 0))
		_ability_by_id[ability_id] = row
		_ability_name_to_id[str(row.get("nombre_interno", "")).to_upper()] = ability_id

	_move_by_id.clear()
	_move_by_internal_name.clear()
	for row in _move_rows:
		var move_id = int(row.get("id", 0))
		_move_by_id[move_id] = row
		_move_by_internal_name[str(row.get("nombre_interno", "")).to_upper()] = row

	_item_by_id.clear()
	for row in _item_rows:
		_item_by_id[int(row.get("id", 0))] = row

	_type_by_id.clear()
	for row in _type_rows:
		_type_by_id[int(row.get("id", 0))] = str(row.get("nombre", ""))

	_rellenar_opciones_catalogo()


func _rellenar_opciones_catalogo() -> void:
	_suppress_form_events = true

	_species_option.clear()
	for row in _species_rows:
		_species_option.add_item("#%03d %s" % [int(row.get("numero_nacional", 0)), str(row.get("nombre", "?"))])
		_species_option.set_item_metadata(_species_option.item_count - 1, int(row.get("id", 0)))

	_nature_option.clear()
	for row in _nature_rows:
		_nature_option.add_item(str(row.get("nombre", "")))
		_nature_option.set_item_metadata(_nature_option.item_count - 1, int(row.get("id", 0)))

	_ability_option.clear()
	_ability_option.add_item("(Sin habilidad)")
	_ability_option.set_item_metadata(0, null)

	_item_option.clear()
	_item_option.add_item("(Sin objeto)")
	_item_option.set_item_metadata(0, null)
	for row in _item_rows:
		_item_option.add_item(str(row.get("nombre", "")))
		_item_option.set_item_metadata(_item_option.item_count - 1, int(row.get("id", 0)))

	_gender_option.clear()
	for sexo in SEXOS_UI:
		_gender_option.add_item(sexo["label"])
		_gender_option.set_item_metadata(_gender_option.item_count - 1, sexo["id"])

	_ot_gender_option.clear()
	for sexo in OT_SEXOS_UI:
		_ot_gender_option.add_item(sexo["label"])
		_ot_gender_option.set_item_metadata(_ot_gender_option.item_count - 1, sexo["id"])

	for slot in _move_slots:
		var option: OptionButton = slot["option"]
		option.clear()
		option.add_item("(Vacío)")
		option.set_item_metadata(0, null)
		for row in _move_rows:
			option.add_item(str(row.get("nombre", "")))
			option.set_item_metadata(option.item_count - 1, int(row.get("id", 0)))

	var first_species_id = _get_selected_metadata(_species_option)
	var first_species_row: Dictionary = _species_by_id.get(_to_int(first_species_id, 0), {})
	_rellenar_habilidades_para_especie(first_species_row)

	_suppress_form_events = false


func _rellenar_habilidades_para_especie(species_row: Dictionary, selected_id = null) -> void:
	var previous_suppress = _suppress_form_events
	_suppress_form_events = true
	_ability_option.clear()
	var abilities_added: Dictionary = {}
	var ability_specs = [
		{"id_field": "habilidad_1_id", "name_field": "habilidad_1", "suffix": ""},
		{"id_field": "habilidad_2_id", "name_field": "habilidad_2", "suffix": ""},
		{"id_field": "habilidad_oculta_id", "name_field": "habilidad_oculta", "suffix": " (Oculta)"},
	]
	for ability_spec in ability_specs:
		var ability_id = species_row.get(ability_spec["id_field"])
		if ability_id == null:
			var ability_internal = str(species_row.get(ability_spec["name_field"], "")).to_upper()
			if ability_internal != "" and _ability_name_to_id.has(ability_internal):
				ability_id = _ability_name_to_id[ability_internal]
		if ability_id == null:
			continue
		ability_id = _to_int(ability_id, 0)
		if ability_id <= 0 or abilities_added.has(ability_id):
			continue
		var ability_row: Dictionary = _ability_by_id.get(ability_id, {})
		var ability_name = str(ability_row.get("nombre", species_row.get(ability_spec["name_field"], "")))
		if ability_name == "":
			continue
		_ability_option.add_item("%s%s" % [ability_name, str(ability_spec["suffix"])])
		_ability_option.set_item_metadata(_ability_option.item_count - 1, ability_id)
		abilities_added[ability_id] = true
	if _ability_option.item_count == 0:
		_ability_option.add_item("(Sin habilidad)")
		_ability_option.set_item_metadata(0, null)
	var ability_id_to_select = selected_id
	if ability_id_to_select == null:
		ability_id_to_select = _get_default_ability_id(species_row)
	_set_selected_metadata(_ability_option, ability_id_to_select)
	_suppress_form_events = previous_suppress


func _cargar_datos_jugador_guardado() -> void:
	var defaults := {
		"id": randi_range(10000, 99999),
		"nombre": "JUGADOR",
		"sexo": "M",
	}
	if not FileAccess.file_exists(RUTA_PARTIDA_GUARDADO):
		_datos_jugador_guardado = defaults
		return
	var file = FileAccess.open(RUTA_PARTIDA_GUARDADO, FileAccess.READ)
	if file == null:
		_datos_jugador_guardado = defaults
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		_datos_jugador_guardado = defaults
		return
	var jugador = parsed.get("jugador", {})
	if typeof(jugador) != TYPE_DICTIONARY:
		_datos_jugador_guardado = defaults
		return
	var player_name = str(jugador.get("nombre", "")).strip_edges()
	var player_id = _to_int(jugador.get("id", defaults["id"]), defaults["id"])
	if player_id <= 0:
		player_id = defaults["id"]
	_datos_jugador_guardado = {
		"id": player_id,
		"nombre": player_name if player_name != "" else defaults["nombre"],
		"sexo": _normalizar_sexo_ot(jugador.get("sexo", defaults["sexo"])),
	}


func _obtener_ot_por_defecto() -> Dictionary:
	return _datos_jugador_guardado.duplicate(true)


func _get_cintas_ordenadas() -> Array:
	var ribbon_keys: Array = SINGLETON_DATA.CINTAS_POKEMON.keys()
	ribbon_keys.sort_custom(func(a, b):
		return _to_int(SINGLETON_DATA.CINTAS_POKEMON[a].get("orden", 0), 0) < _to_int(SINGLETON_DATA.CINTAS_POKEMON[b].get("orden", 0), 0)
	)
	return ribbon_keys


func _resolver_cinta_key(value: Variant) -> String:
	var raw_value = str(value).strip_edges()
	if raw_value == "":
		return ""
	var upper_value = raw_value.to_upper()
	if SINGLETON_DATA.CINTAS_POKEMON.has(upper_value):
		return upper_value
	for ribbon_key in SINGLETON_DATA.CINTAS_POKEMON.keys():
		var ribbon_data: Dictionary = SINGLETON_DATA.CINTAS_POKEMON[ribbon_key]
		if str(ribbon_data.get("nombre", "")).to_upper() == upper_value:
			return ribbon_key
	return ""


func _calcular_pp_total_movimiento(pp_base: int, pp_up_usados: int) -> int:
	var usos = clamp(pp_up_usados, 0, 3)
	return pp_base + int(floor(float(pp_base) * float(usos) / 5.0))


# =====================================================================
# Lista de instancias
# =====================================================================

## Refresca la lista de instancias desde SQLite y actualiza el resaltado.
## No toca las pestañas salvo que se pida explícitamente con
## [param cargar_en_formulario] (usado al abrir el editor, al pedir una
## instancia desde afuera, o justo después de guardar/crear un registro).
## Seleccionar una fila en la lista por el usuario NUNCA vuelca datos en las
## pestañas por sí solo: para eso está el botón "Leer".
func _recargar_lista(select_id: int = -1, cargar_en_formulario: bool = false) -> void:
	var objetivo := select_id
	if objetivo <= 0:
		objetivo = _selected_list_id

	_pokemon_rows = _consulta("""
		SELECT pi.*, p.numero_nacional, p.nombre AS especie_nombre, p.nombre_interno AS especie_interna,
			n.nombre AS naturaleza_nombre, h.nombre AS habilidad_nombre, o.nombre AS objeto_nombre
		FROM PokemonInstancias pi
		JOIN Pokemon p ON p.id = pi.especie_id
		LEFT JOIN Naturalezas n ON n.id = pi.naturaleza_id
		LEFT JOIN Habilidades h ON h.id = pi.habilidad_id
		LEFT JOIN Objetos o ON o.id = pi.objeto_id
		ORDER BY pi.id
	""")

	var filtro := _search_edit.text.strip_edges().to_lower()
	_pokemon_list.clear()
	for row in _pokemon_rows:
		if not _coincide_filtro(row, filtro):
			continue
		var label := _formatear_label_lista(row)
		_pokemon_list.add_item(label)
		_pokemon_list.set_item_metadata(_pokemon_list.item_count - 1, int(row.get("id", -1)))

	if _pokemon_list.item_count == 0:
		_selected_list_id = -1
		if cargar_en_formulario:
			_current_pokemon_id = -1
			_clear_form()
		return

	var indice_objetivo := _buscar_indice_lista_por_id(objetivo)
	if indice_objetivo < 0:
		indice_objetivo = 0

	_pokemon_list.select(indice_objetivo)
	_selected_list_id = int(_pokemon_list.get_item_metadata(indice_objetivo))

	if cargar_en_formulario:
		_cargar_pokemon_en_formulario(_buscar_pokemon_por_id(_selected_list_id))


func _coincide_filtro(row: Dictionary, filtro: String) -> bool:
	if filtro == "":
		return true
	var piezas := [
		str(row.get("id", "")),
		str(row.get("especie_nombre", "")),
		str(row.get("especie_interna", "")),
		str(row.get("mote", "")),
		str(row.get("entrenador_nombre", "")),
	]
	for pieza in piezas:
		if pieza.to_lower().find(filtro) != -1:
			return true
	return false


func _formatear_label_lista(row: Dictionary) -> String:
	var especie = str(row.get("especie_nombre", "?"))
	var mote = str(row.get("mote", "")).strip_edges()
	var display = especie if mote == "" else "%s (%s)" % [mote, especie]
	return "#%d  Nv.%d  %s" % [int(row.get("id", 0)), int(row.get("nivel", 1)), display]


func _buscar_indice_lista_por_id(pokemon_id: int) -> int:
	for idx in range(_pokemon_list.item_count):
		if int(_pokemon_list.get_item_metadata(idx)) == pokemon_id:
			return idx
	return -1


func _buscar_pokemon_por_id(pokemon_id: int) -> Dictionary:
	for row in _pokemon_rows:
		if int(row.get("id", -1)) == pokemon_id:
			return row
	return {}


func _cargar_pokemon_en_formulario(row: Dictionary) -> void:
	if row.is_empty():
		return

	_suppress_form_events = true
	_current_pokemon_id = int(row.get("id", -1))
	var defaults_ot := _obtener_ot_por_defecto()

	var species_id = int(row.get("especie_id", 0))
	var level = int(row.get("nivel", 1))
	var species_row: Dictionary = _species_by_id.get(species_id, {})
	var naturaleza_id = int(row.get("naturaleza_id", _get_nature_id_neutral()))
	var habilidad_id = row.get("habilidad_id")
	if habilidad_id == null:
		habilidad_id = _get_default_ability_id(species_row)

	_set_selected_metadata(_species_option, species_id)
	_set_selected_metadata(_nature_option, naturaleza_id)
	_rellenar_habilidades_para_especie(species_row, habilidad_id)
	_set_selected_metadata(_item_option, row.get("objeto_id"))
	_set_selected_metadata(_gender_option, _normalizar_sexo(row.get("sexo", _default_sexo_for_species(species_row))))
	_set_selected_metadata(_ot_gender_option, _normalizar_sexo_ot(row.get("entrenador_sexo", defaults_ot["sexo"])))

	# Las filas creadas con la curva antigua (n^3 para todas las especies) se
	# muestran ajustadas al rango del nivel, igual que al cargar una partida.
	var ratio_especie := str(species_row.get("ratio_crecimiento", "NORMAL"))
	var exp_fila := int(row.get("experiencia", _calcular_experiencia_nivel(ratio_especie, level)))
	_exp_spin.value = CalculadoraStats.ajustar_experiencia_a_nivel(exp_fila, level, ratio_especie)

	_nickname_edit.text = str(row.get("mote", ""))
	_notas_edit.text = str(row.get("notas", ""))
	_level_spin.value = level
	_friendship_spin.value = int(row.get("felicidad", species_row.get("base_felicidad", 70)))
	_egg_check.button_pressed = _as_bool(row.get("huevo", false))
	_shiny_check.button_pressed = _as_bool(row.get("es_shiny", false))

	_encounter_place_edit.text = str(row.get("encuentro_lugar", ""))
	_encounter_ball_edit.text = str(row.get("encuentro_bola", "POKEBALL"))
	_encounter_level_spin.value = int(row.get("encuentro_nivel", level))
	_encounter_fateful_check.button_pressed = _as_bool(row.get("encuentro_fatidico", false))

	for stat_key in ORDEN_STATS:
		_iv_spins[stat_key].value = int(row.get(_nombre_columna_iv(stat_key), 0))
		_ev_spins[stat_key].value = int(row.get(_nombre_columna_ev(stat_key), 0))

	var entrenador_nombre = str(row.get("entrenador_nombre", "")).strip_edges()
	_ot_name_edit.text = entrenador_nombre if entrenador_nombre != "" else defaults_ot["nombre"]
	var entrenador_id = int(row.get("entrenador_id", 0))
	_ot_id_spin.value = entrenador_id if entrenador_id > 0 else defaults_ot["id"]
	_status_spin.value = int(row.get("estado_primario", 0))
	_infected_check.button_pressed = _as_bool(row.get("infectado", false))
	_cured_check.button_pressed = _as_bool(row.get("curado", false))
	_pokerus_days_spin.value = int(row.get("pokerus_dias_restantes", 0))
	_pokerus_timestamp_spin.value = int(row.get("pokerus_fecha_ultimo_conteo", 0))
	_order_index_spin.value = int(row.get("indice_orden_original", -1))

	var marcas = _parsear_marcas(row.get("marcas_json", ""))
	for marca in _mark_checks.keys():
		_mark_checks[marca].button_pressed = bool(marcas.get(marca, false))

	var cintas = _parsear_array_json(row.get("cintas_json", "[]"))
	for ribbon_key in _ribbon_checks.keys():
		_ribbon_checks[ribbon_key].button_pressed = false
	for cinta in cintas:
		var ribbon_key = _resolver_cinta_key(cinta)
		if ribbon_key != "" and _ribbon_checks.has(ribbon_key):
			_ribbon_checks[ribbon_key].button_pressed = true

	for contest_field in CONTEST_STAT_FIELDS:
		var field_key = str(contest_field["key"])
		_contest_spins[field_key].value = int(row.get(field_key, 0))

	var movimientos = _parsear_array_json(row.get("movimientos_json", "[]"))
	if movimientos.is_empty() and not row.has("movimientos_json"):
		movimientos = _build_default_moves(species_row, level)
	_cargar_movimientos_en_formulario(movimientos)

	_species_info_label.text = _build_species_info_text(species_row)
	_actualizar_sprite_especie(species_row)
	_sincronizar_generador_con_especie(species_row)
	_actualizar_generador_objetivo()
	_update_stats_preview(species_row)
	_hp_actual_spin.value = int(row.get("ps_actuales", _calcular_stat_ps(species_row, level, _iv_valor("ps"), _ev_valor("ps"))))

	_suppress_form_events = false
	_dirty = false
	_set_status("Editando #%d" % _current_pokemon_id)


func _build_species_info_text(species_row: Dictionary) -> String:
	if species_row.is_empty():
		return ""
	var tipo_1 = _type_by_id.get(_to_int(species_row.get("tipo_1_id", 0)), "")
	var tipo_2 = _type_by_id.get(_to_int(species_row.get("tipo_2_id", 0)), "")
	var tipos = tipo_1 if tipo_2 == "" else "%s / %s" % [tipo_1, tipo_2]
	return "#%03d  %s  |  Interno: %s  |  Tipos: %s" % [
		_to_int(species_row.get("numero_nacional", 0)),
		str(species_row.get("nombre", "?")),
		str(species_row.get("nombre_interno", "?")),
		tipos,
	]


## Actualiza el sprite frontal (64x64) que se muestra debajo de "Seleccionar",
## usando PokemonSpriteManager (res://graficos/pokemon/front/<NOMBRE_INTERNO>.png).
func _actualizar_sprite_especie(species_row: Dictionary) -> void:
	var nombre_interno := str(species_row.get("nombre_interno", ""))
	if nombre_interno == "":
		_sprite_pokemon.texture = null
		return
	_sprite_pokemon.texture = PokemonSpriteManager.cargar_sprite_frente(nombre_interno)


func _cargar_movimientos_en_formulario(movimientos: Array) -> void:
	_move_origins = movimientos.duplicate(true)
	_loaded_move_count = movimientos.size()
	for slot_idx in range(_move_slots.size()):
		var slot: Dictionary = _move_slots[slot_idx]
		var move_data: Dictionary = movimientos[slot_idx] if slot_idx < movimientos.size() and movimientos[slot_idx] is Dictionary else {}
		_set_selected_metadata(slot["option"], _resolver_move_id(move_data))
		slot["pp_extra"].value = clampi(int(move_data.get("pp_mas", 0)), 0, 3)
		# Set custom bounds before current, so widgets never clamp against DB PP.
		_actualizar_pp_slot(slot_idx, null, false)
		if move_data.has("pp_act"):
			slot["pp_act"].value = int(move_data.pp_act)
			_actualizar_pp_slot(slot_idx)


func _base_pp_slot(slot_idx: int, row: Dictionary) -> int:
	if slot_idx < _move_origins.size():
		var original: Variant = _move_origins[slot_idx]
		if original is Dictionary and original.has("move_record") and MoveRecord.valid(original.move_record) and _resolver_move_id(original) == row.get("id"):
			return int(original.move_record.data.max_pp)
	return int(row.get("pp", 0))


func _resolver_move_id(move_data: Dictionary):
	if move_data.is_empty():
		return null
	if move_data.has("movimiento_id") and move_data["movimiento_id"] != null:
		return int(move_data["movimiento_id"])
	var nombre_interno = str(move_data.get("nombre_interno", "")).to_upper()
	if _move_by_internal_name.has(nombre_interno):
		return int(_move_by_internal_name[nombre_interno].get("id", 0))
	return null


# =====================================================================
# Botonera central (Leer / Guardar en posición / Guardar como nuevo /
# Borrar / Recargar lista / Seleccionar)
# =====================================================================

## → Leer: carga en las pestañas los datos del Pokémon resaltado en la lista.
func _leer_seleccion_lista() -> void:
	if _selected_list_id <= 0:
		_set_status("Selecciona un Pokémon en la lista antes de leerlo.", true)
		return
	var row := _buscar_pokemon_por_id(_selected_list_id)
	if row.is_empty():
		_set_status("No se encontró el Pokémon #%d en la lista." % _selected_list_id, true)
		return
	_cargar_pokemon_en_formulario(row)
	_set_status("Leído #%d hacia las pestañas." % _selected_list_id)


## ← Guardar: sobrescribe en la base de datos la fila resaltada en la lista
## con los datos actuales de las pestañas (sin importar si esa fila es la que
## originalmente se leyó). Si la especie de las pestañas difiere de la
## especie que ya tiene esa posición en la lista, pide confirmación antes de
## sobrescribir.
func _guardar_en_posicion() -> void:
	if _selected_list_id <= 0:
		_set_status("Selecciona una posición de la lista antes de guardar.", true)
		return
	var id_objetivo := _selected_list_id
	var data := _colectar_formulario()
	var fila_lista := _buscar_pokemon_por_id(id_objetivo)
	var especie_lista_id := int(fila_lista.get("especie_id", -1))
	var especie_nueva_id := int(data.get("especie_id", -1))

	if not fila_lista.is_empty() and especie_lista_id > 0 and especie_lista_id != especie_nueva_id:
		var nombre_lista := str(fila_lista.get("especie_nombre", "?"))
		var nombre_nuevo := str(_species_by_id.get(especie_nueva_id, {}).get("nombre", "?"))
		_pendiente_guardar_en_posicion_id = id_objetivo
		_pendiente_guardar_en_posicion_data = data
		_confirmar_guardar_dialog.dialog_text = "La posición #%d en la lista tiene %s, pero las pestañas tienen %s.\n¿Deseas sobrescribirla de todas formas?" % [id_objetivo, nombre_lista, nombre_nuevo]
		_confirmar_guardar_dialog.popup_centered()
		return

	_ejecutar_guardar_en_posicion(id_objetivo, data)


func _on_confirmar_guardar_en_posicion() -> void:
	if _pendiente_guardar_en_posicion_id <= 0:
		return
	_ejecutar_guardar_en_posicion(_pendiente_guardar_en_posicion_id, _pendiente_guardar_en_posicion_data)
	_pendiente_guardar_en_posicion_id = -1
	_pendiente_guardar_en_posicion_data = {}


func _on_cancelar_guardar_en_posicion() -> void:
	if _pendiente_guardar_en_posicion_id > 0:
		_set_status("Guardado en la posición #%d cancelado (especie distinta)." % _pendiente_guardar_en_posicion_id)
	_pendiente_guardar_en_posicion_id = -1
	_pendiente_guardar_en_posicion_data = {}


func _ejecutar_guardar_en_posicion(id_objetivo: int, data: Dictionary) -> void:
	var columnas := _columnas_persistencia()
	var sets: Array = []
	var bindings: Array = []
	for columna in columnas:
		sets.append("%s = ?" % columna)
		bindings.append(data.get(columna))
	bindings.append(id_objetivo)
	var sql := "UPDATE PokemonInstancias SET %s WHERE id = ?" % ", ".join(sets)
	if not _ejecutar_sql_con_bindings(sql, bindings):
		_set_status("No se pudo guardar en la posición #%d." % id_objetivo, true)
		return
	_set_status("Guardado en la posición #%d." % id_objetivo)
	_recargar_lista(id_objetivo, true)


## Guardar como nuevo: inserta los datos actuales de las pestañas como una
## fila nueva, sin tocar la posición seleccionada en la lista.
func _guardar_como_nuevo() -> void:
	var data := _colectar_formulario()
	var new_id := _insertar_pokemon(data)
	if new_id > 0:
		_set_status("Pokémon guardado como nuevo con ID %d." % new_id)
		_recargar_lista(new_id, true)


## Borra de la base de datos la fila resaltada en la lista (no la que esté
## cargada en las pestañas, si difiere).
func _borrar_seleccion_lista() -> void:
	if _selected_list_id <= 0:
		_set_status("Selecciona un Pokémon en la lista antes de borrarlo.", true)
		return
	var id_a_borrar := _selected_list_id
	if not _ejecutar_sql_con_bindings("DELETE FROM PokemonInstancias WHERE id = ?", [id_a_borrar]):
		_set_status("No se pudo borrar el Pokémon #%d." % id_a_borrar, true)
		return
	if _current_pokemon_id == id_a_borrar:
		_current_pokemon_id = -1
	_set_status("Pokémon #%d borrado." % id_a_borrar)
	_recargar_lista(-1, false)


## Refresca la lista desde SQLite sin tocar las pestañas.
func _recargar_solo_lista() -> void:
	_recargar_lista(_selected_list_id, false)
	_set_status("Lista recargada desde SQLite (%d instancias)." % _pokemon_rows.size())


## Seleccionar: transmite un snapshot de los datos actuales de las pestañas a
## quien esté escuchando (ver documentación de la señal al inicio del script).
func _on_seleccionar_pressed() -> void:
	var datos := obtener_datos_formulario()
	if datos.is_empty(): return
	datos_pokemon_solicitados.emit(datos)
	_set_status("Datos de las pestañas transmitidos (señal 'datos_pokemon_solicitados').")


func _generar_ot_id() -> void:
	_ot_id_spin.value = randi_range(10000, 99999)
	_mark_dirty()


func _insertar_pokemon(data: Dictionary) -> int:
	var columnas = _columnas_persistencia()
	var placeholders: Array = []
	var bindings: Array = []
	for columna in columnas:
		placeholders.append("?")
		bindings.append(data.get(columna))
	var sql = "INSERT INTO PokemonInstancias (%s) VALUES (%s)" % [", ".join(columnas), ", ".join(placeholders)]
	if not _ejecutar_sql_con_bindings(sql, bindings):
		_set_status("No se pudo insertar el nuevo Pokémon en la base de datos.", true)
		return -1
	var last_rows = _consulta("SELECT last_insert_rowid() AS id")
	if last_rows.is_empty():
		return -1
	return int(last_rows[0].get("id", -1))


func _columnas_persistencia() -> Array:
	return [
		"especie_id",
		"entrenador_nombre",
		"entrenador_id",
		"entrenador_sexo",
		"mote",
		"notas",
		"nivel",
		"experiencia",
		"iv_ps",
		"iv_ataque",
		"iv_defensa",
		"iv_ataque_especial",
		"iv_defensa_especial",
		"iv_velocidad",
		"ev_ps",
		"ev_ataque",
		"ev_defensa",
		"ev_ataque_especial",
		"ev_defensa_especial",
		"ev_velocidad",
		"ps_actuales",
		"naturaleza_id",
		"habilidad_id",
		"objeto_id",
		"sexo",
		"es_shiny",
		"felicidad",
		"huevo",
		"infectado",
		"curado",
		"pokerus_dias_restantes",
		"pokerus_fecha_ultimo_conteo",
		"encuentro_lugar",
		"encuentro_bola",
		"encuentro_nivel",
		"encuentro_fatidico",
		"movimientos_json",
		"marcas_json",
		"cintas_json",
		"concurso_carisma",
		"concurso_belleza",
		"concurso_dulzura",
		"concurso_ingenio",
		"concurso_dureza",
		"concurso_brillo",
		"estado_primario",
		"indice_orden_original",
	]


func _build_default_pokemon_data(species_id: int, level: int = 5) -> Dictionary:
	var species_row: Dictionary = _species_by_id.get(species_id, {})
	var trainer_defaults := _obtener_ot_por_defecto()
	var nivel := clampi(level, 1, 100)
	var naturaleza_id := _get_nature_id_neutral()
	var data := {
		"especie_id": species_id,
		"entrenador_nombre": trainer_defaults["nombre"],
		"entrenador_id": trainer_defaults["id"],
		"entrenador_sexo": trainer_defaults["sexo"],
		"mote": "",
		"notas": "",
		"nivel": nivel,
		"experiencia": _calcular_experiencia_nivel(str(species_row.get("ratio_crecimiento", "NORMAL")), nivel),
		"iv_ps": randi_range(0, 31),
		"iv_ataque": randi_range(0, 31),
		"iv_defensa": randi_range(0, 31),
		"iv_ataque_especial": randi_range(0, 31),
		"iv_defensa_especial": randi_range(0, 31),
		"iv_velocidad": randi_range(0, 31),
		"ev_ps": 0,
		"ev_ataque": 0,
		"ev_defensa": 0,
		"ev_ataque_especial": 0,
		"ev_defensa_especial": 0,
		"ev_velocidad": 0,
		"naturaleza_id": naturaleza_id,
		"habilidad_id": _get_default_ability_id(species_row),
		"objeto_id": null,
		"sexo": _default_sexo_for_species(species_row),
		"es_shiny": 0,
		"felicidad": int(species_row.get("base_felicidad", 70)),
		"huevo": 0,
		"infectado": 0,
		"curado": 0,
		"pokerus_dias_restantes": 0,
		"pokerus_fecha_ultimo_conteo": 0,
		"encuentro_lugar": "",
		"encuentro_bola": "POKEBALL",
		"encuentro_nivel": nivel,
		"encuentro_fatidico": 0,
		"movimientos_json": JSON.stringify(_build_default_moves(species_row, nivel)),
		"marcas_json": JSON.stringify(DEFAULT_MARCAS),
		"cintas_json": JSON.stringify([]),
		"concurso_carisma": 0,
		"concurso_belleza": 0,
		"concurso_dulzura": 0,
		"concurso_ingenio": 0,
		"concurso_dureza": 0,
		"concurso_brillo": 0,
		"estado_primario": 0,
		"indice_orden_original": -1,
	}
	data["ps_actuales"] = _calcular_stat_ps(species_row, nivel, data["iv_ps"], data["ev_ps"])
	return data


func _colectar_formulario() -> Dictionary:
	var species_id = _get_selected_metadata(_species_option)
	var species_row: Dictionary = _species_by_id.get(int(species_id), {})
	var level = int(_level_spin.value)
	var naturaleza_id = _get_selected_metadata(_nature_option)
	if naturaleza_id == null:
		naturaleza_id = _get_nature_id_neutral()

	var movements: Array = []
	for slot_idx: int in _move_slots.size():
		var slot: Dictionary = _move_slots[slot_idx]
		var move_id = _get_selected_metadata(slot["option"])
		if move_id == null:
			movements.append(null); continue
		var move_row: Dictionary = _move_by_id.get(int(move_id), {})
		if move_row.is_empty(): return {}
		var origin: Variant = _move_origins[slot_idx] if slot_idx < _move_origins.size() else null
		if origin is Dictionary and origin.has("move_record") and not MoveRecord.valid(origin.move_record): return {}
		var pp_extra: int = clampi(int(slot["pp_extra"].value), 0, 3)
		var pp_total: int = _calcular_pp_total_movimiento(_base_pp_slot(slot_idx, move_row), pp_extra)
		var movement: Dictionary = {
			"movimiento_id":int(move_row.id),"nombre_interno":str(move_row.nombre_interno),"nombre":str(move_row.nombre),
			"pp_act":clampi(int(slot["pp_act"].value), 0, pp_total),"pp_mas":pp_extra,"pp_tot":pp_total}
		if origin is Dictionary and origin.has("move_record") and _resolver_move_id(origin) == move_id:
			movement["move_record"] = origin.move_record.duplicate(true)
		else:
			# Form-only provenance: A->B->A must not recover a discarded A origin.
			movement["reset_move_origin"] = true
		movements.append(movement)
	while movements.size() > _loaded_move_count and movements.back() == null:
		movements.pop_back()

	var cintas: Array = []
	for ribbon_key in _get_cintas_ordenadas():
		if _ribbon_checks.has(ribbon_key) and _ribbon_checks[ribbon_key].button_pressed:
			cintas.append(ribbon_key)

	var marcas := DEFAULT_MARCAS.duplicate(true)
	for marca in _mark_checks.keys():
		marcas[marca] = _mark_checks[marca].button_pressed

	var data := {
		"especie_id": int(species_id),
		"entrenador_nombre": _ot_name_edit.text.strip_edges() if _ot_name_edit.text.strip_edges() != "" else "JUGADOR",
		"entrenador_id": int(_ot_id_spin.value),
		"entrenador_sexo": _normalizar_sexo_ot(_get_selected_metadata(_ot_gender_option)),
		"mote": _nickname_edit.text.strip_edges(),
		"notas": _notas_edit.text,
		"nivel": level,
		"experiencia": int(_exp_spin.value),
		"iv_ps": _iv_valor("ps"),
		"iv_ataque": _iv_valor("ataque"),
		"iv_defensa": _iv_valor("defensa"),
		"iv_ataque_especial": _iv_valor("ataque_especial"),
		"iv_defensa_especial": _iv_valor("defensa_especial"),
		"iv_velocidad": _iv_valor("velocidad"),
		"ev_ps": _ev_valor("ps"),
		"ev_ataque": _ev_valor("ataque"),
		"ev_defensa": _ev_valor("defensa"),
		"ev_ataque_especial": _ev_valor("ataque_especial"),
		"ev_defensa_especial": _ev_valor("defensa_especial"),
		"ev_velocidad": _ev_valor("velocidad"),
		"ps_actuales": int(_hp_actual_spin.value),
		"naturaleza_id": int(naturaleza_id),
		"habilidad_id": _get_selected_metadata(_ability_option),
		"objeto_id": _get_selected_metadata(_item_option),
		"sexo": _normalizar_sexo(_get_selected_metadata(_gender_option)),
		"es_shiny": _bool_to_int(_shiny_check.button_pressed),
		"felicidad": int(_friendship_spin.value),
		"huevo": _bool_to_int(_egg_check.button_pressed),
		"infectado": _bool_to_int(_infected_check.button_pressed),
		"curado": _bool_to_int(_cured_check.button_pressed),
		"pokerus_dias_restantes": int(_pokerus_days_spin.value),
		"pokerus_fecha_ultimo_conteo": int(_pokerus_timestamp_spin.value),
		# Clave de lugar (Lugares): "Ruta 101" → "RUTA_101", "ruta_113" → sección.
		"encuentro_lugar": Lugares.normalizar_clave(_encounter_place_edit.text),
		"encuentro_bola": _encounter_ball_edit.text.strip_edges() if _encounter_ball_edit.text.strip_edges() != "" else "POKEBALL",
		"encuentro_nivel": int(_encounter_level_spin.value),
		"encuentro_fatidico": _bool_to_int(_encounter_fateful_check.button_pressed),
		"movimientos_json": JSON.stringify(movements),
		"marcas_json": JSON.stringify(marcas),
		"cintas_json": JSON.stringify(cintas),
		"concurso_carisma": int(_contest_spins["concurso_carisma"].value),
		"concurso_belleza": int(_contest_spins["concurso_belleza"].value),
		"concurso_dulzura": int(_contest_spins["concurso_dulzura"].value),
		"concurso_ingenio": int(_contest_spins["concurso_ingenio"].value),
		"concurso_dureza": int(_contest_spins["concurso_dureza"].value),
		"concurso_brillo": int(_contest_spins["concurso_brillo"].value),
		"estado_primario": int(_status_spin.value),
		"indice_orden_original": int(_order_index_spin.value),
		"nombre_interno": str(species_row.get("nombre_interno", "")).to_upper(),
		"numero_nacional": int(species_row.get("numero_nacional", 0)),
		"nombre": str(species_row.get("nombre", "")),
	}

	var max_hp = _calcular_stat_ps(species_row, level, data["iv_ps"], data["ev_ps"])
	data["ps_actuales"] = clamp(data["ps_actuales"], 0, max_hp)
	data["ps_max"] = max_hp
	if data["habilidad_id"] == null:
		data["habilidad_id"] = _get_default_ability_id(species_row)
	return data


func _build_default_moves(species_row: Dictionary, level: int) -> Array:
	if species_row.is_empty():
		return []
	var numero_nacional = int(species_row.get("numero_nacional", 0))
	if numero_nacional <= 0:
		return []
	var rows = _consulta_con_bindings("""
		SELECT mc.id, mc.nombre_interno, mc.nombre, mc.pp, mc.poder, mc.precision, mc.prioridad, t.nombre AS tipo_nombre, mc.descripcion
		FROM PokemonMovimientos pm
		JOIN Movimientos mc ON mc.id = pm.movimiento_id
		JOIN MetodosAprendizaje ma ON ma.id = pm.metodo_aprendizaje_id
		LEFT JOIN Tipos t ON t.id = mc.tipo_id
		WHERE pm.pokemon_numero = ?
			AND ma.nombre = 'level-up'
	""" + MovimientosIniciales.SQL_ORDEN_RUBI % level, [numero_nacional])
	var movimientos: Array = []
	for row in MovimientosIniciales.seleccionar(rows):
		var pp = int(row.get("pp", 0))
		movimientos.append({
			"movimiento_id": int(row.get("id", 0)),
			"nombre_interno": str(row.get("nombre_interno", "")),
			"nombre": str(row.get("nombre", "")),
			"pp_act": pp,
			"pp_mas": 0,
			"pp_tot": pp,
		})
	return movimientos


# =====================================================================
# Vista previa de estadísticas
# =====================================================================

func _update_stats_preview(species_row: Dictionary) -> void:
	if species_row.is_empty():
		return
	var level = int(_level_spin.value)
	var nature_row: Dictionary = _nature_by_id.get(int(_get_selected_metadata(_nature_option)), {})
	var total_evs = 0
	for stat_key in ORDEN_STATS:
		total_evs += _ev_valor(stat_key)

	_types_label.text = _build_types_text(species_row)
	_hidden_power_label.text = _calcular_poder_oculto_texto()
	_total_evs_label.text = "%d / 510" % total_evs
	_total_evs_label.modulate = Color(1, 0.45, 0.45, 1.0) if total_evs > 510 else Color(1, 1, 1, 1)

	_stat_labels["ps"].text = str(_calcular_stat_ps(species_row, level, _iv_valor("ps"), _ev_valor("ps")))
	_stat_labels["ataque"].text = str(_calcular_stat_general(species_row, nature_row, "ataque", level, _iv_valor("ataque"), _ev_valor("ataque")))
	_stat_labels["defensa"].text = str(_calcular_stat_general(species_row, nature_row, "defensa", level, _iv_valor("defensa"), _ev_valor("defensa")))
	_stat_labels["ataque_especial"].text = str(_calcular_stat_general(species_row, nature_row, "ataque_especial", level, _iv_valor("ataque_especial"), _ev_valor("ataque_especial")))
	_stat_labels["defensa_especial"].text = str(_calcular_stat_general(species_row, nature_row, "defensa_especial", level, _iv_valor("defensa_especial"), _ev_valor("defensa_especial")))
	_stat_labels["velocidad"].text = str(_calcular_stat_general(species_row, nature_row, "velocidad", level, _iv_valor("velocidad"), _ev_valor("velocidad")))

	var max_hp = int(_stat_labels["ps"].text)
	_hp_actual_spin.max_value = max_hp
	if int(_hp_actual_spin.value) > max_hp:
		_hp_actual_spin.value = max_hp


func _build_types_text(species_row: Dictionary) -> String:
	var tipo_1 = _type_by_id.get(_to_int(species_row.get("tipo_1_id", 0)), "")
	var tipo_2 = _type_by_id.get(_to_int(species_row.get("tipo_2_id", 0)), "")
	if tipo_2 == "":
		return tipo_1
	return "%s / %s" % [tipo_1, tipo_2]


## Delegan en CalculadoraStatsPokemon (fuente unica compartida con BasePokemon).
func _calcular_stat_ps(species_row: Dictionary, level: int, iv: int, ev: int) -> int:
	return CalculadoraStats.stat_ps(int(species_row.get("base_ps", 1)), iv, ev, level)


func _calcular_stat_general(species_row: Dictionary, nature_row: Dictionary, stat_key: String, level: int, iv: int, ev: int) -> int:
	var base_value = int(species_row.get(_nombre_columna_base(stat_key), 1))
	return CalculadoraStats.stat_general(base_value, iv, ev, level, _naturaleza_multiplicador(nature_row, stat_key))


func _nombre_columna_base(stat_key: String) -> String:
	match stat_key:
		"ps":
			return "base_ps"
		"ataque":
			return "base_atq"
		"defensa":
			return "base_def"
		"ataque_especial":
			return "base_atq_esp"
		"defensa_especial":
			return "base_def_esp"
		"velocidad":
			return "base_vel"
	return ""


func _nombre_columna_iv(stat_key: String) -> String:
	match stat_key:
		"ps":
			return "iv_ps"
		"ataque":
			return "iv_ataque"
		"defensa":
			return "iv_defensa"
		"ataque_especial":
			return "iv_ataque_especial"
		"defensa_especial":
			return "iv_defensa_especial"
		"velocidad":
			return "iv_velocidad"
	return ""


func _nombre_columna_ev(stat_key: String) -> String:
	match stat_key:
		"ps":
			return "ev_ps"
		"ataque":
			return "ev_ataque"
		"defensa":
			return "ev_defensa"
		"ataque_especial":
			return "ev_ataque_especial"
		"defensa_especial":
			return "ev_defensa_especial"
		"velocidad":
			return "ev_velocidad"
	return ""


func _naturaleza_multiplicador(nature_row: Dictionary, stat_key: String) -> float:
	if nature_row.is_empty():
		return 1.0
	var aumentada = _normalizar_stat_naturaleza(str(nature_row.get("stat_aumentada", "")))
	var disminuida = _normalizar_stat_naturaleza(str(nature_row.get("stat_disminuida", "")))
	if aumentada == stat_key and stat_key != "ps":
		return float(nature_row.get("multiplicador_aumento", 1.1))
	if disminuida == stat_key and stat_key != "ps":
		return float(nature_row.get("multiplicador_disminucion", 0.9))
	return 1.0


func _normalizar_stat_naturaleza(texto: String) -> String:
	var valor = texto.to_lower().strip_edges().replace("á", "a").replace("é", "e").replace("í", "i").replace("ó", "o").replace("ú", "u")
	valor = valor.replace(" ", "_")
	match valor:
		"ataque":
			return "ataque"
		"defensa":
			return "defensa"
		"ataque_especial", "at_esp", "ataque_esp", "ataqueespecial":
			return "ataque_especial"
		"defensa_especial", "def_esp", "defensa_esp", "defensaespecial":
			return "defensa_especial"
		"velocidad":
			return "velocidad"
	return ""


func _calcular_poder_oculto_texto() -> String:
	var ivs = [_iv_valor("ps"), _iv_valor("ataque"), _iv_valor("defensa"), _iv_valor("velocidad"), _iv_valor("ataque_especial"), _iv_valor("defensa_especial")]
	var tipo = 0
	for i in range(6):
		if ivs[i] % 2 == 1:
			tipo += 2 ** i
	tipo = tipo % 16
	match tipo:
		0:
			return "LUCHA"
		1:
			return "VOLADOR"
		2:
			return "VENENO"
		3:
			return "TIERRA"
		4:
			return "ROCA"
		5:
			return "BICHO"
		6:
			return "FANTASMA"
		7:
			return "ACERO"
		8:
			return "FUEGO"
		9:
			return "AGUA"
		10:
			return "PLANTA"
		11:
			return "ELECTRICO"
		12:
			return "PSIQUICO"
		13:
			return "HIELO"
		14:
			return "DRAGON"
		15:
			return "SINIESTRO"
	return "NORMAL"


## Delega en CalculadoraStatsPokemon: misma curva que el juego.
func _calcular_experiencia_nivel(ratio_crecimiento: String, nivel: int) -> int:
	return CalculadoraStats.experiencia_nivel(nivel, ratio_crecimiento)


func _get_nature_id_neutral() -> int:
	for row in _nature_rows:
		if str(row.get("nombre", "")).to_upper() == "SERIA":
			return int(row.get("id", 0))
	return int(_nature_rows[0].get("id", 0)) if not _nature_rows.is_empty() else 1


func _get_default_ability_id(species_row: Dictionary):
	if species_row.is_empty():
		return null
	if species_row.get("habilidad_1_id") != null:
		return int(species_row.get("habilidad_1_id"))
	var habilidad_1 = str(species_row.get("habilidad_1", "")).to_upper()
	if _ability_name_to_id.has(habilidad_1):
		return int(_ability_name_to_id[habilidad_1])
	return null


func _default_gender_for_species(species_row: Dictionary) -> String:
	if species_row.is_empty() or species_row.get("prob_sexo") == null:
		return "N"
	var prob_sexo = int(species_row.get("prob_sexo", 0))
	if prob_sexo <= 0:
		return "M"
	if prob_sexo >= 100:
		return "F"
	return "F" if prob_sexo >= 50 else "M"


func _default_sexo_for_species(species_row: Dictionary) -> String:
	return _default_gender_for_species(species_row)


func _iv_valor(stat_key: String) -> int:
	return int(_iv_spins[stat_key].value)


func _ev_valor(stat_key: String) -> int:
	return int(_ev_spins[stat_key].value)


func _actualizar_pp_slot(slot_idx: int, pp_actual_sugerido: Variant = null, preserve_current: bool = true) -> void:
	if slot_idx < 0 or slot_idx >= _move_slots.size():
		return
	var slot: Dictionary = _move_slots[slot_idx]
	var move_id = _get_selected_metadata(slot["option"])
	var move_row: Dictionary = _move_by_id.get(int(move_id), {}) if move_id != null else {}
	var pp_base: int = _base_pp_slot(slot_idx, move_row)
	var pp_extra = clamp(int(slot["pp_extra"].value), 0, 3)
	slot["pp_extra"].value = pp_extra
	var pp_total = _calcular_pp_total_movimiento(pp_base, pp_extra)
	slot["pp_total_label"].text = "PP total: %d" % pp_total
	slot["pp_act"].max_value = pp_total
	if move_row.is_empty():
		slot["pp_act"].value = 0
		return
	if preserve_current:
		slot["pp_act"].value = clamp(int(slot["pp_act"].value), 0, pp_total)
	else:
		var nuevo_pp = pp_total if pp_actual_sugerido == null else int(pp_actual_sugerido)
		slot["pp_act"].value = clamp(nuevo_pp, 0, pp_total)


func _set_selected_metadata(option: OptionButton, target_meta) -> void:
	for idx in range(option.item_count):
		if option.get_item_metadata(idx) == target_meta:
			option.select(idx)
			return
	if option.item_count > 0:
		option.select(0)


func _get_selected_metadata(option: OptionButton):
	if option.item_count == 0:
		return null
	return option.get_item_metadata(option.selected)


func _parsear_array_json(valor) -> Array:
	if valor == null:
		return []
	var parsed = JSON.parse_string(str(valor))
	return parsed if typeof(parsed) == TYPE_ARRAY else []


func _parsear_marcas(valor) -> Dictionary:
	var parsed = JSON.parse_string(str(valor))
	if typeof(parsed) == TYPE_DICTIONARY:
		var marcas := DEFAULT_MARCAS.duplicate(true)
		for clave in marcas.keys():
			marcas[clave] = bool(parsed.get(clave, false))
		return marcas
	return DEFAULT_MARCAS.duplicate(true)


func _normalizar_sexo(valor) -> String:
	var texto = str(valor).to_upper().strip_edges()
	if texto in ["F", "FEMENINO", "HEMBRA"]:
		return "F"
	if texto in ["N", "SIN_SEXO", "NONE"]:
		return "N"
	return "M"


func _normalizar_sexo_ot(valor) -> String:
	var texto = str(valor).to_upper().strip_edges()
	if texto in ["F", "FEMENINO", "HEMBRA"]:
		return "F"
	return "M"


func _obtener_columnas_tabla(nombre_tabla: String) -> Dictionary:
	var columnas: Dictionary = {}
	var rows = _consulta("PRAGMA table_info(%s)" % nombre_tabla)
	for row in rows:
		columnas[str(row.get("name", ""))] = true
	return columnas


func _consulta(sql: String) -> Array:
	if db == null:
		return []
	if not db.query(sql):
		return []
	return db.query_result


func _consulta_con_bindings(sql: String, bindings: Array) -> Array:
	if db == null:
		return []
	if not db.query_with_bindings(sql, bindings):
		return []
	return db.query_result


func _ejecutar_sql(sql: String) -> bool:
	if db == null:
		return false
	return db.query(sql)


func _ejecutar_sql_con_bindings(sql: String, bindings: Array) -> bool:
	if db == null:
		return false
	return db.query_with_bindings(sql, bindings)


func _clear_form() -> void:
	_move_origins.clear()
	_loaded_move_count = 0
	_suppress_form_events = true
	_current_pokemon_id = -1
	var defaults_ot := _obtener_ot_por_defecto()
	if _species_option.item_count > 0:
		_species_option.select(0)
	if _nature_option.item_count > 0:
		_nature_option.select(0)
	if _ability_option.item_count > 0:
		_ability_option.select(0)
	if _item_option.item_count > 0:
		_item_option.select(0)
	if _gender_option.item_count > 0:
		_gender_option.select(0)
	if _ot_gender_option.item_count > 0:
		_ot_gender_option.select(0)
	_nickname_edit.text = ""
	_notas_edit.text = ""
	_species_info_label.text = ""
	_level_spin.value = 1
	_exp_spin.value = 0
	_friendship_spin.value = 70
	_hp_actual_spin.value = 0
	_egg_check.button_pressed = false
	_encounter_place_edit.text = ""
	_encounter_ball_edit.text = "POKEBALL"
	_encounter_level_spin.value = 1
	_encounter_fateful_check.button_pressed = false
	for stat_key in ORDEN_STATS:
		_iv_spins[stat_key].value = 0
		_ev_spins[stat_key].value = 0
	_ot_name_edit.text = defaults_ot["nombre"]
	_ot_id_spin.value = defaults_ot["id"]
	_set_selected_metadata(_ot_gender_option, defaults_ot["sexo"])
	_status_spin.value = 0
	_infected_check.button_pressed = false
	_cured_check.button_pressed = false
	_pokerus_days_spin.value = 0
	_pokerus_timestamp_spin.value = 0
	_order_index_spin.value = -1
	_shiny_check.button_pressed = false
	_set_selected_metadata(_gender_option, _default_gender_for_species(_species_by_id.get(_to_int(_get_selected_metadata(_species_option), 0), {})))
	for marca in _mark_checks.keys():
		_mark_checks[marca].button_pressed = false
	for ribbon_key in _ribbon_checks.keys():
		_ribbon_checks[ribbon_key].button_pressed = false
	for contest_field in CONTEST_STAT_FIELDS:
		_contest_spins[str(contest_field["key"])].value = 0
	for slot_idx in range(_move_slots.size()):
		var slot: Dictionary = _move_slots[slot_idx]
		slot["option"].select(0)
		slot["pp_extra"].value = 0
		_actualizar_pp_slot(slot_idx, null, false)
	var default_species_row: Dictionary = _species_by_id.get(_to_int(_get_selected_metadata(_species_option), 0), {})
	_species_info_label.text = _build_species_info_text(default_species_row)
	_actualizar_sprite_especie(default_species_row)
	_rellenar_habilidades_para_especie(default_species_row)
	_sincronizar_generador_con_especie(default_species_row)
	_actualizar_generador_objetivo()
	_update_stats_preview(default_species_row)
	_suppress_form_events = false
	_dirty = false


func _set_status(texto: String, is_error: bool = false) -> void:
	_status_label.text = texto
	_status_label.modulate = Color(1.0, 0.52, 0.52, 1.0) if is_error else Color(0.83, 0.91, 1.0, 1.0)


func _mark_dirty() -> void:
	if _suppress_form_events:
		return
	_dirty = true
	_set_status("Cambios sin guardar en #%d." % _current_pokemon_id if _current_pokemon_id > 0 else "Cambios sin guardar.")


func _bool_to_int(value: bool) -> int:
	return 1 if value else 0


func _as_bool(value) -> bool:
	if typeof(value) == TYPE_BOOL:
		return value
	if typeof(value) == TYPE_INT:
		return int(value) != 0
	return str(value).to_lower() in ["true", "1"]


# =====================================================================
# Handlers de señales
# =====================================================================

func _on_search_text_changed(_value: String) -> void:
	_recargar_lista(_selected_list_id, false)


## Seleccionar una fila en la lista solo cambia el resaltado; no toca las
## pestañas (para eso está el botón "Leer").
func _on_pokemon_list_item_selected(index: int) -> void:
	_selected_list_id = int(_pokemon_list.get_item_metadata(index))


## Doble click o Enter con foco en la lista (ItemList.item_activated cubre
## ambos casos): equivale a pulsar "→ Leer" sobre ese elemento.
func _on_pokemon_list_item_activated(index: int) -> void:
	_selected_list_id = int(_pokemon_list.get_item_metadata(index))
	_leer_seleccion_lista()


## Barra espaciadora con foco en la lista: también equivale a "→ Leer"
## (item_activated ya cubre Enter y doble click, pero no Espacio).
func _on_pokemon_list_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_leer_seleccion_lista()
		accept_event()


func _on_generic_field_changed(_value = null) -> void:
	_mark_dirty()


func _on_species_changed(_index: int) -> void:
	if _suppress_form_events:
		return
	var species_row: Dictionary = _species_by_id.get(int(_get_selected_metadata(_species_option)), {})
	_species_info_label.text = _build_species_info_text(species_row)
	_actualizar_sprite_especie(species_row)
	_rellenar_habilidades_para_especie(species_row, _get_selected_metadata(_ability_option))
	_set_selected_metadata(_gender_option, _default_gender_for_species(species_row))
	_update_stats_preview(species_row)
	_mark_dirty()


func _on_level_changed(_value: float) -> void:
	if _suppress_form_events:
		return
	var species_row: Dictionary = _species_by_id.get(int(_get_selected_metadata(_species_option)), {})
	var ratio = str(species_row.get("ratio_crecimiento", "NORMAL"))
	_exp_spin.value = _calcular_experiencia_nivel(ratio, int(_level_spin.value))
	_encounter_level_spin.value = int(_level_spin.value)
	_update_stats_preview(species_row)
	_mark_dirty()


func _on_nature_changed(_index: int) -> void:
	if _suppress_form_events:
		return
	var species_row: Dictionary = _species_by_id.get(int(_get_selected_metadata(_species_option)), {})
	_update_stats_preview(species_row)
	_mark_dirty()


func _on_stats_changed(_value: float) -> void:
	if _suppress_form_events:
		return
	var species_row: Dictionary = _species_by_id.get(int(_get_selected_metadata(_species_option)), {})
	_update_stats_preview(species_row)
	_mark_dirty()


func _on_move_selected(_selected_index: int, slot_idx: int) -> void:
	if _suppress_form_events: return
	var selected = _get_selected_metadata(_move_slots[slot_idx].option)
	var origin: Variant = _move_origins[slot_idx] if slot_idx < _move_origins.size() else null
	if origin is Dictionary and _resolver_move_id(origin) == selected:
		_actualizar_pp_slot(slot_idx)
	else:
		while _move_origins.size() <= slot_idx: _move_origins.append(null)
		_move_origins[slot_idx] = null
		_move_slots[slot_idx].pp_extra.value = 0
		_actualizar_pp_slot(slot_idx, null, false)
	_mark_dirty()


func _on_move_pp_changed(_value: float, slot_idx: int) -> void:
	if _suppress_form_events:
		return
	_actualizar_pp_slot(slot_idx)
	_mark_dirty()
