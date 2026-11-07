@tool
## Editor visual de la matriz de efectividad de tipos (tabla TiposEficacia).
## Abre su propia conexión SQLite a res://BaseDatos/poke.db (mismo patrón que
## editor_entrenadores.gd, porque en contexto @tool no hay autoloads).
## Punto de entrada: abrir()
## Señal de salida: tabla_guardada(matriz) — { "ATACANTE": { "DEFENSOR": factor_float } }
extends Window

signal tabla_guardada(matriz: Dictionary)

const RUTA_BASE_DATOS := "res://BaseDatos/poke.db"
const RUTA_SEED_SQL := "res://addons/tilemap_inspector/editores/editor_tabla_tipos/seed_tipos_eficacia.sql"

## Ciclo de valores al hacer clic izquierdo (porcentajes: 100 = x1).
const FACTOR_CICLO: Array[int] = [100, 200, 50, 0]
## Valores aceptados al guardar. El x4 (400) solo se pone vía menú contextual.
const FACTORES_VALIDOS: Array[int] = [0, 50, 100, 200, 400]

const COLOR_X0 := Color(0.16, 0.16, 0.18)
const COLOR_X05 := Color(0.30, 0.62, 0.31)
const COLOR_X1 := Color(0.28, 0.28, 0.32)
const COLOR_X2 := Color(0.78, 0.34, 0.30)
const COLOR_X4 := Color(0.92, 0.22, 0.16)
const COLOR_HEADER := Color(0.22, 0.22, 0.25)

var db = null  # conexión directa a SQLite (igual que editor_entrenadores.gd)

var _tipos: Array[Dictionary] = []      # [{ "id": int, "nombre": String, "color_hex": String }]
var _nombres: Array[String] = []
var _matriz: Dictionary = {}            # nombre_atq -> { nombre_def -> factor int (%) }
var _matriz_original: Dictionary = {}   # copia para detectar cambios sin guardar
var _celdas: Dictionary = {}            # Vector2i(idx_atq, idx_def) -> Button

var _grid: GridContainer = null
var _status: Label = null
var _menu_celda: PopupMenu = null
var _celda_menu_actual := Vector2i(-1, -1)
var _confirmar_restaurar: ConfirmationDialog = null
var _confirmar_cerrar: ConfirmationDialog = null
var _probador_atq: OptionButton = null
var _probador_def1: OptionButton = null
var _probador_def2: OptionButton = null
var _probador_resultado: Label = null

func _ready() -> void:
	title = "Editor de Tabla de Tipos — TiposEficacia"
	size = Vector2i(1120, 760)
	min_size = Vector2i(900, 600)
	close_requested.connect(_on_cerrar)
	_construir_ui()

# ─── Punto de entrada público ──────────────────────────────────────────────────

func abrir() -> void:
	if _conectar_db():
		_cargar_datos()
		_refrescar_grid()
		_refrescar_probador()
		if _matriz.is_empty():
			_set_status("La tabla TiposEficacia está vacía. Usa «Restaurar por defecto» para sembrarla.", true)
	popup_centered()

# ─── Conexión y carga de datos ────────────────────────────────────────────────

func _conectar_db() -> bool:
	if db != null:
		return true
	db = SQLite.new()
	db.path = RUTA_BASE_DATOS
	if db.open_db():
		return true
	_set_status("No se pudo abrir %s" % RUTA_BASE_DATOS, true)
	db = null
	return false

func _cargar_datos() -> void:
	_tipos.clear()
	_nombres.clear()
	_matriz = {}
	db.query("SELECT id, nombre, color_hex FROM Tipos ORDER BY id")
	for fila in db.query_result:
		_tipos.append({"id": int(fila["id"]), "nombre": String(fila["nombre"]), "color_hex": String(fila["color_hex"])})
		_nombres.append(String(fila["nombre"]))

	var consulta := "SELECT ta.nombre AS atacante, td.nombre AS defensor, e.damage_factor AS factor "
	consulta += "FROM TiposEficacia e "
	consulta += "JOIN Tipos ta ON e.damage_type_id = ta.id "
	consulta += "JOIN Tipos td ON e.target_type_id = td.id"
	if db.query(consulta):
		for fila in db.query_result:
			var atacante := String(fila["atacante"])
			if not _matriz.has(atacante):
				_matriz[atacante] = {}
			_matriz[atacante][String(fila["defensor"])] = int(fila["factor"])
	_matriz_original = _matriz.duplicate(true)

# ─── Cierre ────────────────────────────────────────────────────────────────────

func _on_cerrar() -> void:
	if _matriz != _matriz_original:
		_celda_menu_actual = Vector2i(-1, -1)
		_confirmar_cerrar.dialog_text = "Hay cambios sin guardar en la matriz de tipos.\n¿Cerrar y descartarlos?"
		_confirmar_cerrar.popup_centered()
		return
	hide()

func _cerrar_definitivo() -> void:
	if db != null:
		db.close_db()
		db = null
	queue_free()

# ─── Construcción de la UI ────────────────────────────────────────────────────

func _construir_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# ── Matriz 18x18 ───────────────────────────────────────────────────────────
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	vbox.add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = 20  # se recalcula en _refrescar_grid
	_grid.add_theme_constant_override("h_separation", 2)
	_grid.add_theme_constant_override("v_separation", 2)
	scroll.add_child(_grid)

	# ── Leyenda ────────────────────────────────────────────────────────────────
	vbox.add_child(_crear_leyenda())

	# ── Probador de efectividad ────────────────────────────────────────────────
	vbox.add_child(_crear_probador())

	# ── Barra inferior ─────────────────────────────────────────────────────────
	var barra := HBoxContainer.new()
	barra.add_theme_constant_override("separation", 8)
	vbox.add_child(barra)

	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 11)
	barra.add_child(_status)

	var btn_recargar := Button.new()
	btn_recargar.text = "↻ Recargar"
	btn_recargar.tooltip_text = "Descartar cambios y volver a leer la BBDD"
	btn_recargar.pressed.connect(func():
		if _conectar_db():
			_cargar_datos()
			_refrescar_grid()
			_set_status("Matriz recargada desde la BBDD."))
	barra.add_child(btn_recargar)

	var btn_restaurar := Button.new()
	btn_restaurar.text = "↺ Restaurar por defecto"
	btn_restaurar.tooltip_text = "Reejecuta el seed generado desde el diccionario hardcodeado de singleton.gd"
	btn_restaurar.pressed.connect(func(): _confirmar_restaurar.popup_centered())
	barra.add_child(btn_restaurar)

	var btn_guardar := Button.new()
	btn_guardar.text = "💾 Guardar en la BBDD"
	btn_guardar.tooltip_text = "Escribe la matriz en TiposEficacia (los cambios en el juego se aplican al reiniciarlo)"
	btn_guardar.pressed.connect(_guardar)
	barra.add_child(btn_guardar)

	# ── Menú contextual de celda ───────────────────────────────────────────────
	_menu_celda = PopupMenu.new()
	for par in [["×4", 400], ["×2", 200], ["×1", 100], ["×½", 50], ["×0", 0]]:
		_menu_celda.add_item(par[0], par[1])
	_menu_celda.id_pressed.connect(func(id: int): _poner_factor(_celda_menu_actual, id))
	add_child(_menu_celda)

	# ── Diálogos ───────────────────────────────────────────────────────────────
	_confirmar_restaurar = ConfirmationDialog.new()
	_confirmar_restaurar.dialog_text = "¿Restaurar TODA la matriz a los valores por defecto?\nSe sobrescribirá TiposEficacia con el seed (singleton.gd)."
	_confirmar_restaurar.ok_button_text = "Restaurar"
	_confirmar_restaurar.confirmed.connect(_restaurar_por_defecto)
	add_child(_confirmar_restaurar)

	_confirmar_cerrar = ConfirmationDialog.new()
	_confirmar_cerrar.dialog_text = "Hay cambios sin guardar. ¿Cerrar y descartarlos?"
	_confirmar_cerrar.ok_button_text = "Descartar y cerrar"
	_confirmar_cerrar.cancel_button_text = "Seguir editando"
	_confirmar_cerrar.confirmed.connect(_cerrar_definitivo)
	add_child(_confirmar_cerrar)

func _crear_leyenda() -> Control:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 12)
	var lbl := Label.new()
	lbl.text = "Clic: cicla ×1 → ×2 → ×½ → ×0   ·   Clic derecho: menú con ×4"
	lbl.add_theme_font_size_override("font_size", 11)
	fila.add_child(lbl)
	for par in [["×2 Súper eficaz", COLOR_X2], ["×½ Poco eficaz", COLOR_X05], ["×0 Sin efecto", COLOR_X0]]:
		var muestra := Label.new()
		muestra.text = "  %s  " % par[0]
		muestra.add_theme_font_size_override("font_size", 10)
		var sb := StyleBoxFlat.new()
		sb.bg_color = par[1]
		sb.content_margin_left = 4
		sb.content_margin_right = 4
		sb.content_margin_top = 2
		sb.content_margin_bottom = 2
		muestra.add_theme_stylebox_override("normal", sb)
		fila.add_child(muestra)
	return fila

func _crear_probador() -> Control:
	var caja := HBoxContainer.new()
	caja.add_theme_constant_override("separation", 6)

	var lbl := Label.new()
	lbl.text = "Probador:"
	lbl.add_theme_font_size_override("font_size", 11)
	caja.add_child(lbl)

	_probador_atq = OptionButton.new()
	_probador_def1 = OptionButton.new()
	_probador_def2 = OptionButton.new()
	for ob in [_probador_atq, _probador_def1, _probador_def2]:
		ob.add_theme_font_size_override("font_size", 11)
		caja.add_child(ob)
		ob.item_selected.connect(func(_idx: int): _actualizar_probador())

	_probador_resultado = Label.new()
	_probador_resultado.add_theme_font_size_override("font_size", 12)
	_probador_resultado.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja.add_child(_probador_resultado)
	return caja

# ─── Matriz (grid) ─────────────────────────────────────────────────────────────

func _refrescar_grid() -> void:
	for hijo in _grid.get_children():
		hijo.queue_free()
	_celdas.clear()
	_grid.columns = _tipos.size() + 1

	# Esquina
	_grid.add_child(_celda_header("ATACANTE ↓ / DEFENSOR →", Vector2(210, 0)))
	# Cabeceras de columna (defensores)
	for t in _tipos:
		_grid.add_child(_celda_header(t["nombre"], Vector2(0, 0), t["color_hex"], true))

	for i_atq in _tipos.size():
		var t: Dictionary = _tipos[i_atq]
		_grid.add_child(_celda_header(t["nombre"], Vector2(0, 0), t["color_hex"]))
		for i_def in _tipos.size():
			var pos := Vector2i(i_atq, i_def)
			var boton := Button.new()
			boton.custom_minimum_size = Vector2(44, 34)
			boton.add_theme_font_size_override("font_size", 11)
			boton.focus_mode = Control.FOCUS_NONE
			var defensor: String = _nombres[i_def]
			var atacante: String = _nombres[i_atq]
			boton.tooltip_text = "%s → %s" % [atacante, defensor]
			boton.pressed.connect(func(): _ciclar_celda(pos))
			boton.gui_input.connect(func(event: InputEvent):
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
					_celda_menu_actual = pos
					_menu_celda.position = boton.get_screen_position() + Vector2(event.position)
					_menu_celda.popup())
			_celdas[pos] = boton
			_grid.add_child(boton)
			_aplicar_factor_visual(boton, _factor_de(atacante, defensor), atacante, defensor)

func _celda_header(texto: String, _min_size: Vector2, color_hex: String = "", columna := false) -> Control:
	var lbl := Label.new()
	lbl.text = texto if columna else texto
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if columna else HORIZONTAL_ALIGNMENT_LEFT
	lbl.add_theme_font_size_override("font_size", 10)
	var sb := StyleBoxFlat.new()
	if color_hex != "":
		sb.bg_color = Color(color_hex).darkened(0.45)
	else:
		sb.bg_color = COLOR_HEADER
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	lbl.add_theme_stylebox_override("normal", sb)
	return lbl

func _factor_de(atacante: String, defensor: String) -> int:
	if _matriz.has(atacante) and _matriz[atacante].has(defensor):
		return int(_matriz[atacante][defensor])
	return 100  # valor neutro por defecto para pares no presentes en la BBDD

func _aplicar_factor_visual(boton: Button, factor: int, atacante: String, defensor: String) -> void:
	var color := COLOR_X1
	var texto := ""
	match factor:
		0: color = COLOR_X0; texto = "0"
		50: color = COLOR_X05; texto = "½"
		200: color = COLOR_X2; texto = "2"
		400: color = COLOR_X4; texto = "4"
		_: color = COLOR_X1; texto = ""
	boton.text = texto
	boton.add_theme_stylebox_override("normal", _estilo_celda(color.darkened(0.55)))
	boton.add_theme_stylebox_override("hover", _estilo_celda(color.darkened(0.35)))
	boton.add_theme_stylebox_override("pressed", _estilo_celda(color))
	var etiqueta := "×%s (%s)" % [str(float(factor) / 100.0).trim_suffix("0").trim_suffix("."), _veredicto(factor)]
	boton.tooltip_text = "%s → %s: %s" % [atacante, defensor, etiqueta]

func _estilo_celda(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 2
	sb.content_margin_right = 2
	return sb

func _veredicto(factor: int) -> String:
	match factor:
		0: return "sin efecto"
		50: return "poco eficaz"
		200: return "súper eficaz"
		400: return "doble súper eficaz"
	return "neutral"

func _ciclar_celda(pos: Vector2i) -> void:
	var factor := _factor_de(_nombres[pos.x], _nombres[pos.y])
	var idx := FACTOR_CICLO.find(factor)
	var nuevo: int = FACTOR_CICLO[0]
	if idx >= 0:
		nuevo = FACTOR_CICLO[(idx + 1) % FACTOR_CICLO.size()]
	else:
		nuevo = FACTOR_CICLO[0]
	_poner_factor(pos, nuevo)

func _poner_factor(pos: Vector2i, factor: int) -> void:
	if pos.x < 0 or pos.y < 0:
		return
	var atacante: String = _nombres[pos.x]
	var defensor: String = _nombres[pos.y]
	if not _matriz.has(atacante):
		_matriz[atacante] = {}
	_matriz[atacante][defensor] = factor
	var boton: Button = _celdas.get(pos)
	if boton is Button:
		_aplicar_factor_visual(boton, factor, atacante, defensor)
	_set_status("%s → %s = %s" % [atacante, defensor, _veredicto(factor)])

# ─── Probador ──────────────────────────────────────────────────────────────────

func _refrescar_probador() -> void:
	for ob in [_probador_atq, _probador_def1, _probador_def2]:
		ob.clear()
	_probador_def2.add_item("(mono-tipo)")
	for nombre in _nombres:
		_probador_atq.add_item(nombre)
		_probador_def1.add_item(nombre)
		_probador_def2.add_item(nombre)
	if _nombres.size() > 0:
		_probador_atq.select(0)
		_probador_def1.select(0)
		_probador_def2.select(0)
	_actualizar_probador()

func _actualizar_probador() -> void:
	if _probador_atq.item_count == 0:
		return
	var atacante: String = _probador_atq.get_item_text(max(_probador_atq.selected, 0))
	var def1: String = _probador_def1.get_item_text(max(_probador_def1.selected, 0))
	var factor := float(_factor_de(atacante, def1)) / 100.0
	var detalle := "×%s" % _fmt(factor)
	var texto_def2: String = _probador_def2.get_item_text(max(_probador_def2.selected, 0))
	if texto_def2 != "(mono-tipo)" and texto_def2 != def1:
		var factor2 := float(_factor_de(atacante, texto_def2)) / 100.0
		factor *= factor2
		detalle += " × ×%s" % _fmt(factor2)
	_probador_resultado.text = "%s vs %s → %s = ×%s" % [atacante, def1, detalle, _fmt(factor)]

func _fmt(valor: float) -> String:
	return str(valor).trim_suffix("0").trim_suffix(".")

# ─── Guardar / restaurar ───────────────────────────────────────────────────────

func _guardar() -> void:
	if not _conectar_db():
		return
	# Validación: matriz completa y valores permitidos
	var errores: Array[String] = []
	for atacante in _nombres:
		if not _matriz.has(atacante):
			errores.append("Falta la fila de %s" % atacante)
			continue
		for defensor in _nombres:
			if not _matriz[atacante].has(defensor):
				errores.append("Falta %s → %s" % [atacante, defensor])
			elif not FACTORES_VALIDOS.has(int(_matriz[atacante][defensor])):
				errores.append("Valor inválido en %s → %s: %s" % [atacante, defensor, _matriz[atacante][defensor]])
	if not errores.is_empty():
		_set_status("No se puede guardar: %d celdas con problemas. Primera: %s" % [errores.size(), errores[0]], true)
		return

	var valores: Array[String] = []
	for i_atq in _tipos.size():
		for i_def in _tipos.size():
			var id_atq: int = _tipos[i_atq]["id"]
			var id_def: int = _tipos[i_def]["id"]
			var factor: int = int(_matriz[_nombres[i_atq]][_nombres[i_def]])
			valores.append("(%d, %d, %d)" % [id_atq, id_def, factor])

	db.query("BEGIN")
	var fallo := ""
	if not db.query("DELETE FROM TiposEficacia"):
		fallo = "DELETE"
	elif not db.query("INSERT INTO TiposEficacia (damage_type_id, target_type_id, damage_factor) VALUES " + ", ".join(valores)):
		fallo = "INSERT"
	if fallo != "":
		db.query("ROLLBACK")
		_set_status("Error al guardar (fallo en %s): no se modificó la BBDD." % fallo, true)
		return
	db.query("COMMIT")
	_matriz_original = _matriz.duplicate(true)
	var matriz_float := _como_matriz_float()
	tabla_guardada.emit(matriz_float)
	_set_status("Guardado: %d relaciones escritas en TiposEficacia. Reinicia el juego para aplicarlo en runtime." % valores.size())

func _restaurar_por_defecto() -> void:
	if not _conectar_db():
		return
	if _ejecutar_archivo_sql(RUTA_SEED_SQL):
		_cargar_datos()
		_refrescar_grid()
		_set_status("Matriz restaurada a los valores por defecto (seed desde singleton.gd). Recuerda guardar no es necesario: ya está escrita.")

## Ejecuta las sentencias de un archivo .sql (comentarios con --, sentencias separadas por ";\n").
func _ejecutar_archivo_sql(ruta: String) -> bool:
	if not FileAccess.file_exists(ruta):
		_set_status("No existe %s" % ruta, true)
		return false
	var texto := FileAccess.open(ruta, FileAccess.READ).get_as_text().replace("\r", "")
	var limpio := ""
	for linea in texto.split("\n"):
		if linea.strip_edges().begins_with("--"):
			continue
		limpio += linea + "\n"
	var ejecutadas := 0
	for sentencia in limpio.split(";\n"):
		sentencia = sentencia.strip_edges()
		if sentencia == "":
			continue
		if not db.query(sentencia):
			_set_status("Error ejecutando: %s..." % sentencia.substr(0, 60), true)
			return false
		ejecutadas += 1
	_set_status("Seed aplicado (%d sentencias)." % ejecutadas)
	return true

func _como_matriz_float() -> Dictionary:
	var salida := {}
	for atacante in _matriz:
		salida[atacante] = {}
		for defensor in _matriz[atacante]:
			salida[atacante][defensor] = float(_matriz[atacante][defensor]) / 100.0
	return salida

func _set_status(texto: String, error := false) -> void:
	if _status == null:
		print("[EDITOR_TABLA_TIPOS] ", texto)
		return
	_status.text = texto
	_status.add_theme_color_override("font_color", Color(0.95, 0.35, 0.30) if error else Color(0.75, 0.85, 0.75))
