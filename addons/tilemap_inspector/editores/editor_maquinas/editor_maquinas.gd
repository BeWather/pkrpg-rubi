@tool
## Editor de MT/MO: asigna el movimiento que enseña cada máquina (tabla
## MaquinasMovimientos) y edita su descripción de la mochila (Objetos.descripcion).
## Abre su propia conexión SQLite a res://BaseDatos/poke.db (en contexto @tool no
## hay autoloads), pero solo mientras carga o guarda: una conexión de escritura
## abierta impide en Windows que otras herramientas abran la BD con
## read_only = true (el VFS de godot-sqlite usa FileAccess, que en el editor
## abre con _SH_DENYWR por el «safe save»).
## Punto de entrada: abrir()
## Nota: la compatibilidad por especie (PokemonMovimientos, método «machine»)
## va por movimiento, no por objeto; este editor no la modifica.
extends Window

signal maquinas_guardadas

const RUTA_BASE_DATOS := "res://BaseDatos/poke.db"
const METODO_APRENDIZAJE_MAQUINA := 2
## Bolsillos.id de «MT / MO». Se filtra por bolsillo y no por nombre_interno
## porque parte de las MT aún usan el formato antiguo («tm24»).
const BOLSILLO_MAQUINAS := 3
## Ancho aproximado de línea de las descripciones de objetos existentes.
const ANCHO_LINEA_DESCRIPCION := 19
const NOMBRES_CATEGORIA := {"physical": "Físico", "special": "Especial", "status": "Estado"}

## Ruta de la BD; los tests pueden apuntarla a una copia.
var ruta_base_datos := RUTA_BASE_DATOS

## [{ "objeto_id": int, "nombre_interno": String, "nombre": String, "movimiento_id": int (0 = ninguno), "descripcion": String }]
var _maquinas: Array[Dictionary] = []
var _originales: Dictionary = {}          # objeto_id -> { "movimiento_id": int, "descripcion": String }
var _movimientos: Dictionary = {}         # movimiento_id -> fila de Movimientos + tipo/categoría
var _ids_movimientos: Array[int] = []     # ordenados por nombre
var _compatibles: Dictionary = {}         # movimiento_id -> nº de especies que lo aprenden por MT/MO
var _indice_actual := -1
var _actualizando_ui := false
var _accion_pendiente: Callable = Callable()

var _filtro_maquinas: LineEdit = null
var _lista_maquinas: ItemList = null
var _titulo: Label = null
var _lbl_movimiento: Label = null
var _lbl_tipo: Label = null
var _lbl_categoria: Label = null
var _lbl_poder: Label = null
var _lbl_precision: Label = null
var _lbl_pp: Label = null
var _lbl_compatibles: Label = null
var _lbl_desc_movimiento: Label = null
var _filtro_movimientos: LineEdit = null
var _lista_movimientos: ItemList = null
var _txt_descripcion: TextEdit = null
var _lbl_info_descripcion: Label = null
var _btn_copiar: Button = null
var _status: Label = null
var _dialogo_confirmar: ConfirmationDialog = null

func _ready() -> void:
	title = "Editor de MT/MO — MaquinasMovimientos"
	size = Vector2i(1100, 760)
	min_size = Vector2i(860, 600)
	close_requested.connect(_on_cerrar)
	_construir_ui()

# ─── Punto de entrada público ──────────────────────────────────────────────────

func abrir() -> void:
	if not _hay_cambios():
		_recargar()
	popup_centered()
	grab_focus()

# ─── Conexión y carga de datos ────────────────────────────────────────────────

## Abre una conexión nueva; quien la pide debe cerrarla con close_db().
func _abrir_db() -> SQLite:
	var db := SQLite.new()
	db.path = ruta_base_datos
	if not db.open_db():
		_set_status("No se pudo abrir %s" % ruta_base_datos, true)
		return null
	# Si otra conexión está escribiendo, esperar en vez de fallar al instante.
	db.query("PRAGMA busy_timeout = 3000")
	return db

func _recargar() -> void:
	var nombre_previo := ""
	if _indice_actual >= 0 and _indice_actual < _maquinas.size():
		nombre_previo = String(_maquinas[_indice_actual]["nombre_interno"])
	var db := _abrir_db()
	if db == null:
		return
	_cargar_datos(db)
	db.close_db()
	_indice_actual = -1
	for i in _maquinas.size():
		if String(_maquinas[i]["nombre_interno"]) == nombre_previo:
			_indice_actual = i
	if _indice_actual < 0 and not _maquinas.is_empty():
		_indice_actual = 0
	_refrescar_lista_maquinas()
	_mostrar_detalle()
	_set_status("%d máquinas cargadas." % _maquinas.size())

func _cargar_datos(db: SQLite) -> void:
	_maquinas.clear()
	_originales.clear()
	_movimientos.clear()
	_ids_movimientos.clear()
	_compatibles.clear()

	var consulta := "SELECT m.id, m.nombre, m.poder, m.precision, m.pp, m.descripcion, "
	consulta += "t.nombre AS tipo, t.color_hex, c.nombre AS categoria "
	consulta += "FROM Movimientos m "
	consulta += "LEFT JOIN Tipos t ON t.id = m.tipo_id "
	consulta += "LEFT JOIN CategoriasDano c ON c.id = m.categoria_dano_id "
	consulta += "ORDER BY m.nombre"
	if db.query(consulta):
		for fila in db.query_result:
			var id := int(fila["id"])
			_movimientos[id] = fila.duplicate()
			_ids_movimientos.append(id)

	consulta = "SELECT o.id AS objeto_id, o.nombre_interno, o.nombre, o.descripcion, mm.movimiento_id "
	consulta += "FROM Objetos o "
	consulta += "LEFT JOIN MaquinasMovimientos mm ON mm.objeto_id = o.id "
	consulta += "WHERE o.bolsillo_id = %d " % BOLSILLO_MAQUINAS
	consulta += "ORDER BY CASE WHEN upper(o.nombre) GLOB 'MT*' THEN 0 ELSE 1 END, o.nombre"
	if db.query(consulta):
		for fila in db.query_result:
			var maquina := {
				"objeto_id": int(fila["objeto_id"]),
				"nombre_interno": String(fila["nombre_interno"]),
				"nombre": String(fila["nombre"]),
				"movimiento_id": int(fila["movimiento_id"]) if fila["movimiento_id"] != null else 0,
				"descripcion": String(fila["descripcion"]) if fila["descripcion"] != null else "",
			}
			_maquinas.append(maquina)
			_originales[maquina["objeto_id"]] = {
				"movimiento_id": maquina["movimiento_id"],
				"descripcion": maquina["descripcion"],
			}

	consulta = "SELECT movimiento_id, COUNT(DISTINCT pokemon_numero) AS total "
	consulta += "FROM PokemonMovimientos WHERE metodo_aprendizaje_id = %d " % METODO_APRENDIZAJE_MAQUINA
	consulta += "GROUP BY movimiento_id"
	if db.query(consulta):
		for fila in db.query_result:
			_compatibles[int(fila["movimiento_id"])] = int(fila["total"])

# ─── Estado de cambios ────────────────────────────────────────────────────────

func _esta_modificada(maquina: Dictionary) -> bool:
	var original: Dictionary = _originales.get(maquina["objeto_id"], {})
	if original.is_empty():
		return true
	return int(original["movimiento_id"]) != int(maquina["movimiento_id"]) \
		or String(original["descripcion"]) != String(maquina["descripcion"])

func _hay_cambios() -> bool:
	for maquina in _maquinas:
		if _esta_modificada(maquina):
			return true
	return false

func _indice_maquina_con_movimiento(movimiento_id: int) -> int:
	for i in _maquinas.size():
		if int(_maquinas[i]["movimiento_id"]) == movimiento_id:
			return i
	return -1

func _nombre_movimiento(movimiento_id: int) -> String:
	if not _movimientos.has(movimiento_id):
		return "(sin movimiento)"
	return String(_movimientos[movimiento_id]["nombre"])

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

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(split)

	# ── Columna izquierda: lista de máquinas ──────────────────────────────────
	var izquierda := VBoxContainer.new()
	izquierda.custom_minimum_size = Vector2(280, 0)
	split.add_child(izquierda)

	var lbl_maquinas := Label.new()
	lbl_maquinas.text = "Máquinas"
	izquierda.add_child(lbl_maquinas)

	_filtro_maquinas = LineEdit.new()
	_filtro_maquinas.placeholder_text = "Filtrar (MT05, SURF...)"
	_filtro_maquinas.clear_button_enabled = true
	_filtro_maquinas.text_changed.connect(func(_t: String): _refrescar_lista_maquinas())
	izquierda.add_child(_filtro_maquinas)

	_lista_maquinas = ItemList.new()
	_lista_maquinas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lista_maquinas.item_selected.connect(_on_maquina_seleccionada)
	izquierda.add_child(_lista_maquinas)

	# ── Columna derecha: detalle ──────────────────────────────────────────────
	var derecha := VBoxContainer.new()
	derecha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	derecha.add_theme_constant_override("separation", 6)
	split.add_child(derecha)

	_titulo = Label.new()
	_titulo.add_theme_font_size_override("font_size", 22)
	derecha.add_child(_titulo)

	var fila_mov := HBoxContainer.new()
	derecha.add_child(fila_mov)
	var lbl_asignado := Label.new()
	lbl_asignado.text = "Movimiento asignado:"
	fila_mov.add_child(lbl_asignado)
	_lbl_movimiento = Label.new()
	_lbl_movimiento.add_theme_font_size_override("font_size", 18)
	fila_mov.add_child(_lbl_movimiento)

	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 12)
	derecha.add_child(grid)
	_lbl_tipo = _agregar_dato(grid, "Tipo:")
	_lbl_categoria = _agregar_dato(grid, "Categoría:")
	_lbl_poder = _agregar_dato(grid, "Poder:")
	_lbl_precision = _agregar_dato(grid, "Precisión:")
	_lbl_pp = _agregar_dato(grid, "PP:")
	_lbl_compatibles = _agregar_dato(grid, "Especies (MT/MO):")

	_lbl_desc_movimiento = Label.new()
	_lbl_desc_movimiento.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_desc_movimiento.modulate = Color(0.8, 0.8, 0.85)
	derecha.add_child(_lbl_desc_movimiento)

	derecha.add_child(HSeparator.new())

	var lbl_cambiar := Label.new()
	lbl_cambiar.text = "Cambiar movimiento (si otra máquina ya lo enseña, se intercambian)"
	derecha.add_child(lbl_cambiar)

	_filtro_movimientos = LineEdit.new()
	_filtro_movimientos.placeholder_text = "Buscar movimiento por nombre o tipo..."
	_filtro_movimientos.clear_button_enabled = true
	_filtro_movimientos.text_changed.connect(func(_t: String): _refrescar_lista_movimientos())
	derecha.add_child(_filtro_movimientos)

	_lista_movimientos = ItemList.new()
	_lista_movimientos.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lista_movimientos.custom_minimum_size = Vector2(0, 180)
	_lista_movimientos.item_selected.connect(_on_movimiento_seleccionado)
	derecha.add_child(_lista_movimientos)

	derecha.add_child(HSeparator.new())

	var fila_desc := HBoxContainer.new()
	derecha.add_child(fila_desc)
	var lbl_desc := Label.new()
	lbl_desc.text = "Descripción en la mochila (Objetos.descripcion)"
	lbl_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila_desc.add_child(lbl_desc)
	_btn_copiar = Button.new()
	_btn_copiar.text = "Usar descripción del movimiento"
	_btn_copiar.tooltip_text = "Copia Movimientos.descripcion ajustada a ~%d caracteres por línea." % ANCHO_LINEA_DESCRIPCION
	_btn_copiar.pressed.connect(_on_copiar_descripcion)
	fila_desc.add_child(_btn_copiar)

	_txt_descripcion = TextEdit.new()
	_txt_descripcion.custom_minimum_size = Vector2(0, 90)
	_txt_descripcion.text_changed.connect(_on_descripcion_cambiada)
	derecha.add_child(_txt_descripcion)

	_lbl_info_descripcion = Label.new()
	_lbl_info_descripcion.modulate = Color(0.7, 0.7, 0.75)
	derecha.add_child(_lbl_info_descripcion)

	# ── Barra inferior ────────────────────────────────────────────────────────
	var barra := HBoxContainer.new()
	vbox.add_child(barra)

	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	barra.add_child(_status)

	var btn_recargar := Button.new()
	btn_recargar.text = "Recargar"
	btn_recargar.pressed.connect(_on_recargar)
	barra.add_child(btn_recargar)

	var btn_guardar := Button.new()
	btn_guardar.text = "Guardar cambios"
	btn_guardar.pressed.connect(_guardar)
	barra.add_child(btn_guardar)

	_dialogo_confirmar = ConfirmationDialog.new()
	_dialogo_confirmar.confirmed.connect(func():
		if _accion_pendiente.is_valid():
			_accion_pendiente.call()
		_accion_pendiente = Callable()
	)
	add_child(_dialogo_confirmar)

func _agregar_dato(grid: GridContainer, etiqueta: String) -> Label:
	var lbl := Label.new()
	lbl.text = etiqueta
	lbl.modulate = Color(0.7, 0.7, 0.75)
	grid.add_child(lbl)
	var valor := Label.new()
	valor.custom_minimum_size = Vector2(70, 0)
	grid.add_child(valor)
	return valor

# ─── Refresco de la UI ────────────────────────────────────────────────────────

func _texto_maquina(maquina: Dictionary) -> String:
	var marca := " *" if _esta_modificada(maquina) else ""
	return "%s — %s%s" % [maquina["nombre"], _nombre_movimiento(int(maquina["movimiento_id"])), marca]

func _refrescar_lista_maquinas() -> void:
	_lista_maquinas.clear()
	var filtro := _filtro_maquinas.text.strip_edges().to_lower()
	for i in _maquinas.size():
		var texto := _texto_maquina(_maquinas[i])
		if not filtro.is_empty() and not texto.to_lower().contains(filtro):
			continue
		var idx := _lista_maquinas.add_item(texto)
		_lista_maquinas.set_item_metadata(idx, i)
		if i == _indice_actual:
			_lista_maquinas.select(idx)
	_lista_maquinas.ensure_current_is_visible()

func _refrescar_item_maquina(indice: int) -> void:
	for idx in _lista_maquinas.item_count:
		if int(_lista_maquinas.get_item_metadata(idx)) == indice:
			_lista_maquinas.set_item_text(idx, _texto_maquina(_maquinas[indice]))
			return

func _refrescar_lista_movimientos() -> void:
	_lista_movimientos.clear()
	if _indice_actual < 0:
		return
	var actual := int(_maquinas[_indice_actual]["movimiento_id"])
	var filtro := _filtro_movimientos.text.strip_edges().to_lower()

	var asignados := {}  # movimiento_id -> nombre visible de la máquina
	for maquina in _maquinas:
		if int(maquina["movimiento_id"]) > 0:
			asignados[int(maquina["movimiento_id"])] = maquina["nombre"]

	if filtro.is_empty():
		var idx_ninguno := _lista_movimientos.add_item("— Sin movimiento —")
		_lista_movimientos.set_item_metadata(idx_ninguno, 0)
		if actual == 0:
			_lista_movimientos.select(idx_ninguno)

	for id in _ids_movimientos:
		var mov: Dictionary = _movimientos[id]
		var texto := "%s  (%s)" % [mov["nombre"], mov["tipo"] if mov["tipo"] != null else "?"]
		if not filtro.is_empty() and not texto.to_lower().contains(filtro):
			continue
		if asignados.has(id):
			texto += "  [%s]" % asignados[id]
		var idx := _lista_movimientos.add_item(texto)
		_lista_movimientos.set_item_metadata(idx, id)
		if asignados.has(id) and id != actual:
			_lista_movimientos.set_item_custom_fg_color(idx, Color(0.6, 0.6, 0.65))
		if id == actual:
			_lista_movimientos.select(idx)
	_lista_movimientos.ensure_current_is_visible()

func _mostrar_detalle() -> void:
	_actualizando_ui = true
	if _indice_actual < 0 or _indice_actual >= _maquinas.size():
		_titulo.text = "(sin máquinas)"
		_lbl_movimiento.text = ""
		_txt_descripcion.text = ""
		_actualizando_ui = false
		return

	var maquina: Dictionary = _maquinas[_indice_actual]
	var movimiento_id := int(maquina["movimiento_id"])
	_titulo.text = "%s  (%s)" % [maquina["nombre"], maquina["nombre_interno"]]
	_lbl_movimiento.text = _nombre_movimiento(movimiento_id)

	var mov: Dictionary = _movimientos.get(movimiento_id, {})
	if mov.is_empty():
		for lbl in [_lbl_tipo, _lbl_categoria, _lbl_poder, _lbl_precision, _lbl_pp, _lbl_compatibles]:
			lbl.text = "—"
		_lbl_tipo.remove_theme_color_override("font_color")
		_lbl_desc_movimiento.text = ""
	else:
		_lbl_tipo.text = String(mov["tipo"]) if mov["tipo"] != null else "?"
		if mov["color_hex"] != null and String(mov["color_hex"]).is_valid_html_color():
			_lbl_tipo.add_theme_color_override("font_color", Color.html(String(mov["color_hex"])))
		else:
			_lbl_tipo.remove_theme_color_override("font_color")
		var categoria := String(mov["categoria"]) if mov["categoria"] != null else ""
		_lbl_categoria.text = NOMBRES_CATEGORIA.get(categoria, categoria if not categoria.is_empty() else "—")
		_lbl_poder.text = _valor_o_guion(mov["poder"])
		_lbl_precision.text = _valor_o_guion(mov["precision"])
		_lbl_pp.text = _valor_o_guion(mov["pp"])
		_lbl_compatibles.text = str(_compatibles.get(movimiento_id, 0))
		_lbl_desc_movimiento.text = String(mov["descripcion"]) if mov["descripcion"] != null else ""

	_btn_copiar.disabled = mov.is_empty() or mov["descripcion"] == null
	if _txt_descripcion.text != String(maquina["descripcion"]):
		_txt_descripcion.text = String(maquina["descripcion"])
	_actualizar_info_descripcion()
	_refrescar_lista_movimientos()
	_actualizando_ui = false

func _valor_o_guion(valor) -> String:
	if valor == null or int(valor) <= 0:
		return "—"
	return str(int(valor))

func _actualizar_info_descripcion() -> void:
	var lineas := _txt_descripcion.text.split("\n")
	var maximo := 0
	for linea in lineas:
		maximo = maxi(maximo, linea.length())
	var aviso := "  ⚠ líneas largas" if maximo > ANCHO_LINEA_DESCRIPCION + 1 else ""
	_lbl_info_descripcion.text = "Líneas: %d · máx. %d caracteres por línea%s" % [lineas.size(), maximo, aviso]

# ─── Interacción ──────────────────────────────────────────────────────────────

func _on_maquina_seleccionada(idx: int) -> void:
	_indice_actual = int(_lista_maquinas.get_item_metadata(idx))
	_mostrar_detalle()

func _on_movimiento_seleccionado(idx: int) -> void:
	if _actualizando_ui or _indice_actual < 0:
		return
	_asignar_movimiento(int(_lista_movimientos.get_item_metadata(idx)))

func _asignar_movimiento(movimiento_id: int) -> void:
	var maquina: Dictionary = _maquinas[_indice_actual]
	var anterior := int(maquina["movimiento_id"])
	if movimiento_id == anterior:
		return

	var otra := _indice_maquina_con_movimiento(movimiento_id) if movimiento_id > 0 else -1
	maquina["movimiento_id"] = movimiento_id
	if otra >= 0:
		_maquinas[otra]["movimiento_id"] = anterior
		_refrescar_item_maquina(otra)
		_set_status("%s ya enseñaba %s: intercambiado, ahora enseña %s. Revisa también su descripción." % [
			_maquinas[otra]["nombre"], _nombre_movimiento(movimiento_id), _nombre_movimiento(anterior)])
	else:
		_set_status("%s ahora enseña %s. Recuerda revisar la descripción de la mochila." % [
			maquina["nombre"], _nombre_movimiento(movimiento_id)])
	_refrescar_item_maquina(_indice_actual)
	_mostrar_detalle()

func _on_descripcion_cambiada() -> void:
	_actualizar_info_descripcion()
	if _actualizando_ui or _indice_actual < 0:
		return
	_maquinas[_indice_actual]["descripcion"] = _txt_descripcion.text
	_refrescar_item_maquina(_indice_actual)

func _on_copiar_descripcion() -> void:
	if _indice_actual < 0:
		return
	var mov: Dictionary = _movimientos.get(int(_maquinas[_indice_actual]["movimiento_id"]), {})
	if mov.is_empty() or mov["descripcion"] == null:
		return
	_txt_descripcion.text = _ajustar_lineas(String(mov["descripcion"]), ANCHO_LINEA_DESCRIPCION)
	_on_descripcion_cambiada()

## Reparte el texto en líneas de como mucho `ancho` caracteres, cortando por palabras.
static func _ajustar_lineas(texto: String, ancho: int) -> String:
	var lineas: PackedStringArray = []
	var actual := ""
	for palabra in texto.replace("\n", " ").split(" ", false):
		if actual.is_empty():
			actual = palabra
		elif actual.length() + 1 + palabra.length() <= ancho:
			actual += " " + palabra
		else:
			lineas.append(actual)
			actual = palabra
	if not actual.is_empty():
		lineas.append(actual)
	return "\n".join(lineas)

func _on_recargar() -> void:
	if _hay_cambios():
		_confirmar("Hay cambios sin guardar.\n¿Recargar desde la base de datos y descartarlos?", _recargar)
		return
	_recargar()

func _on_cerrar() -> void:
	if _hay_cambios():
		_confirmar("Hay cambios sin guardar en las MT/MO.\n¿Cerrar y descartarlos?", func():
			_descartar_cambios()
			hide()
		)
		return
	hide()

func _descartar_cambios() -> void:
	for maquina in _maquinas:
		var original: Dictionary = _originales.get(maquina["objeto_id"], {})
		if not original.is_empty():
			maquina["movimiento_id"] = original["movimiento_id"]
			maquina["descripcion"] = original["descripcion"]
	_refrescar_lista_maquinas()
	_mostrar_detalle()

func _confirmar(texto: String, accion: Callable) -> void:
	_accion_pendiente = accion
	_dialogo_confirmar.dialog_text = texto
	_dialogo_confirmar.popup_centered()

# ─── Guardado ─────────────────────────────────────────────────────────────────

func _guardar() -> void:
	var cambiadas: Array[Dictionary] = []
	for maquina in _maquinas:
		if _esta_modificada(maquina):
			cambiadas.append(maquina)
	if cambiadas.is_empty():
		_set_status("No hay cambios que guardar.")
		return

	# Se borran primero todas las filas afectadas para no chocar con el
	# UNIQUE(movimiento_id) al intercambiar movimientos entre máquinas.
	var db := _abrir_db()
	if db == null:
		return
	var ok: bool = db.query("BEGIN TRANSACTION")
	for maquina in cambiadas:
		ok = ok and db.query_with_bindings("DELETE FROM MaquinasMovimientos WHERE objeto_id = ?", [maquina["objeto_id"]])
	for maquina in cambiadas:
		if not ok:
			break
		if int(maquina["movimiento_id"]) > 0:
			ok = db.query_with_bindings("INSERT INTO MaquinasMovimientos (objeto_id, movimiento_id) VALUES (?, ?)",
				[maquina["objeto_id"], maquina["movimiento_id"]])
		var original: Dictionary = _originales.get(maquina["objeto_id"], {})
		if ok and String(original.get("descripcion", "")) != String(maquina["descripcion"]):
			ok = db.query_with_bindings("UPDATE Objetos SET descripcion = ? WHERE id = ?",
				[maquina["descripcion"], maquina["objeto_id"]])
	if ok:
		ok = db.query("COMMIT")
	if ok:
		db.close_db()
	if not ok:
		var error := String(db.error_message)
		db.query("ROLLBACK")
		db.close_db()
		_set_status("Error al guardar (sin cambios en la BD): %s" % error, true)
		return

	for maquina in cambiadas:
		_originales[maquina["objeto_id"]] = {
			"movimiento_id": maquina["movimiento_id"],
			"descripcion": maquina["descripcion"],
		}
	_refrescar_lista_maquinas()
	_set_status("Guardadas %d máquina(s) en poke.db." % cambiadas.size())
	maquinas_guardadas.emit()

func _set_status(texto: String, error := false) -> void:
	if _status == null:
		print("[EDITOR_MAQUINAS] ", texto)
		return
	_status.text = texto
	_status.add_theme_color_override("font_color", Color(0.95, 0.35, 0.30) if error else Color(0.75, 0.85, 0.75))
