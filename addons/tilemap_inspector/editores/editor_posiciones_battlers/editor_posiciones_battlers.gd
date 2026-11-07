@tool
extends Control
class_name EditorPosicionesBattlers
## Editor visual de los offsets de sprite por especie y lado
## (`escenas/batalla/battle_positions.json`). Es un Control (no una Window) para
## que `plugin.gd` lo monte dentro de una Window propia, igual que el Editor de
## Diálogos; sin Window también se puede instanciar en pruebas headless.
## Punto de entrada: abrir(clave_inicial: String = "")
##
## Estructura: lista filtrable de especies a la izquierda; a la derecha el lienzo
## (`LienzoBattlers`, vista previa fiel a la batalla), los controles X/Y de cada
## lado y las acciones. La lógica de datos vive en `PosicionesBattlersJSON`.
##
## Se puede trabajar solo con teclado (mapa completo en `_procesar_tecla` y en la
## spec "Flujo de trabajo solo con teclado"): RePág/AvPág cambian de especie (también
## con el foco en el filtro), flechas mueven el lado activo, Tab/1/2 eligen lado,
## R/Shift+R restablecen/descartan, Ctrl+D copia de la especie anterior (offsets y
## sombra), O activa/desactiva la sombra de la especie, G/S/T/Z alternan
## guías/shiny/tema/zoom, Ctrl+S guarda. Arrastrar un sprite en el
## lienzo lo hace lado activo.

const LADO_ENEMIGO := PosicionesBattlersJSON.LADO_ENEMIGO
const LADO_JUGADOR := PosicionesBattlersJSON.LADO_JUGADOR

const RUTA_SPRITES_FRENTE := "res://graficos/pokemon/front/"
const AJUSTE_TEMA := "rubi4/editor_posiciones_battlers/tema"
const AJUSTE_ZOOM := "rubi4/editor_posiciones_battlers/zoom"
const AJUSTE_ORDEN := "rubi4/editor_posiciones_battlers/orden_alfabetico"
## Escenario de batalla (EscenarioBatalla) de fondo por defecto.
const TEMA_DEFECTO := "edificio"
## Factores de zoom elegibles (el primero es el de por defecto).
const ZOOMS: Array[int] = [3, 4]
const PASO_FINO := 1
const PASO_GRUESO := 8
const PASO_SALTO := 10
const LIMITE_OFFSET := 1024

## Línea de ayuda permanente (teclas principales; el mapa completo está en la spec).
const AYUDA_TECLAS := "RePág/AvPág: especie (Shift ±10) · Inicio/Fin · Tab/1/2: lado · ←↑↓→: mover (Shift ×8) · R: restablecer lado · Shift+R: descartar · Ctrl+D: copiar de la anterior · O sombra · G guías · S shiny · T tema · Z zoom · / filtrar · Ctrl+S guardar. El juego lee el JSON al iniciar la batalla: relánzala para ver los cambios."

const COLOR_MODIFICADA := Color(1.0, 0.85, 0.30)
const COLOR_ERROR := Color(1.0, 0.40, 0.35)
const COLOR_AVISO := Color(1.0, 0.75, 0.30)

## Ruta del JSON que se edita (configurable para pruebas que no deben tocar el real).
var ruta_json: String = PosicionesBattlersJSON.RUTA_POSICIONES

## Lienzo de vista previa (creado en `_ready`).
var lienzo: LienzoBattlers = null

var _datos := PosicionesBattlersJSON.new()
var _indice_dex: Dictionary = {}
var _claves_dex: Array[String] = []     # lista completa en orden dex
var _claves_todas: Array[String] = []   # lista completa en el orden elegido
var _orden_alfabetico: bool = false
var _claves_visibles: Array[String] = [] # tras aplicar el filtro
var _clave_actual: String = ""
var _cargado_alguna_vez: bool = false
var _editable: bool = true
var _actualizando_ui: bool = false
var _mensaje: String = ""
var _mensaje_es_error: bool = false
var _aviso_sprites: String = ""
var _al_cierre_confirmado: Callable = Callable()

# Controles
var _filtro_edit: LineEdit = null
var _opcion_orden: OptionButton = null
var _lista: ItemList = null
var _conteo_label: Label = null
var _titulo_label: Label = null
var _btn_anterior: Button = null
var _btn_siguiente: Button = null
var _check_guias: CheckBox = null
var _check_shiny: CheckBox = null
var _check_sombra: CheckBox = null
var _opcion_tema: OptionButton = null
var _opcion_zoom: OptionButton = null
var _margen_raiz: MarginContainer = null
var _radio_lado: Dictionary = {}     # lado -> CheckBox
var _spin_x: Dictionary = {}         # lado -> SpinBox
var _spin_y: Dictionary = {}         # lado -> SpinBox
var _final_label: Dictionary = {}    # lado -> Label
var _btn_restablecer: Dictionary = {}  # lado -> Button
var _btn_descartar: Button = null
var _btn_guardar: Button = null
var _estado_label: Label = null
var _confirmar_cierre: ConfirmationDialog = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_construir_ui()
	_aplicar_zoom(_zoom_guardado(), false)


# ─── Punto de entrada público ──────────────────────────────────────────────────

## Carga (o recarga) el JSON y muestra `clave_inicial` (o la primera especie). Si ya
## hay cambios sin guardar no se recarga desde disco: solo se cambia de especie.
func abrir(clave_inicial: String = "") -> void:
	# Si aún no entró en el árbol (la UI se construye en _ready), espera a estarlo.
	if not is_node_ready():
		await ready
	if _cargado_alguna_vez and _datos.hay_modificadas():
		if not clave_inicial.is_empty() and _claves_todas.has(clave_inicial):
			seleccionar(clave_inicial)
		return
	_cargar_datos()
	_reconstruir_lista()
	var destino := clave_inicial if _claves_todas.has(clave_inicial) else ""
	if destino.is_empty() and not _claves_todas.is_empty():
		destino = _clave_actual if _claves_todas.has(_clave_actual) else _claves_todas[0]
	if not destino.is_empty():
		seleccionar(destino)
	_actualizar_estado()
	lienzo.grab_focus.call_deferred()


## true si alguna especie tiene cambios sin guardar.
func hay_cambios_pendientes() -> bool:
	return _datos.hay_modificadas()


## Lista completa de especies (sin filtro) en el orden elegido (dex por defecto).
func claves_listadas() -> Array[String]:
	return _claves_todas.duplicate()


func clave_actual() -> String:
	return _clave_actual


func obtener_offsets(clave: String) -> Dictionary:
	return _datos.obtener(clave)


func especies_modificadas() -> Array[String]:
	return _datos.modificadas()


## Selecciona una especie de la lista (la muestra en el lienzo).
func seleccionar(clave: String) -> void:
	if not _claves_todas.has(clave):
		return
	_clave_actual = clave
	_sincronizar_lista()
	_refrescar_lienzo()
	_refrescar_controles()
	_actualizar_estado()


func siguiente() -> void:
	_navegar(1)


func anterior() -> void:
	_navegar(-1)


## Guarda todas las especies modificadas en el JSON (escritura atómica).
func guardar() -> void:
	if not _datos.puede_guardar():
		_set_mensaje("No se puede guardar: %s" % _datos.ultimo_error, true)
		return
	var cantidad := _datos.modificadas().size()
	if cantidad == 0:
		_set_mensaje("No hay cambios que guardar.", false)
		return
	var error := _datos.guardar(ruta_json)
	if error != OK:
		_set_mensaje("Error al guardar: %s" % _datos.ultimo_error, true)
		return
	for clave in _claves_visibles:
		_refrescar_item(clave)
	_set_mensaje("Guardado: %d especie(s). Relanza la batalla para ver los cambios." % cantidad, false)


## Devuelve el offset de `lado` de la especie actual restablecido a (0,0).
func restablecer_lado(lado: StringName) -> void:
	if _clave_actual.is_empty() or not _editable:
		return
	_aplicar_offset(lado, Vector2i.ZERO, true)


## Descarta los cambios pendientes de la especie actual.
func descartar_especie() -> void:
	if _clave_actual.is_empty() or not _editable:
		return
	_datos.descartar(_clave_actual)
	_refrescar_lienzo()
	_refrescar_controles()
	_refrescar_item(_clave_actual)
	_set_mensaje("Cambios de %s descartados." % _clave_actual, false)


## Para la ventana contenedora: si hay cambios sin guardar pide confirmación y solo
## entonces llama a `al_confirmar`; si no, la llama de inmediato.
func solicitar_cierre(al_confirmar: Callable) -> void:
	if not hay_cambios_pendientes():
		al_confirmar.call()
		return
	_al_cierre_confirmado = al_confirmar
	_confirmar_cierre.dialog_text = "Hay %d especie(s) con cambios sin guardar.\n¿Cerrar y descartarlos?" % _datos.modificadas().size()
	_confirmar_cierre.popup_centered()


# ─── Datos ─────────────────────────────────────────────────────────────────────

func _cargar_datos() -> void:
	_datos = PosicionesBattlersJSON.new()
	var error := _datos.cargar(ruta_json)
	_editable = error == OK
	_cargado_alguna_vez = true
	if error != OK:
		_set_mensaje("%s El archivo no se modificará hasta que se corrija." % _datos.ultimo_error, true)
	else:
		_mensaje = ""
		_mensaje_es_error = false

	if _indice_dex.is_empty():
		_indice_dex = PosicionesBattlersJSON.cargar_indice_dex()
	if _indice_dex.is_empty() and _editable:
		_set_mensaje("No se pudo leer %s: orden alfabético." % PosicionesBattlersJSON.RUTA_ORDEN_DEX, true)

	# Unión de las claves del JSON y de los sprites frontales.
	var union := {}
	for clave in _datos.claves():
		union[clave] = true
	for clave in _claves_de_sprites():
		union[clave] = true
	_claves_dex = PosicionesBattlersJSON.ordenar_especies(union.keys(), _indice_dex)
	_aplicar_orden()

	for lado in [LADO_ENEMIGO, LADO_JUGADOR]:
		_radio_lado[lado].disabled = not _editable
	_actualizar_botones()


func _claves_de_sprites() -> Array[String]:
	var claves: Array[String] = []
	var dir := DirAccess.open(RUTA_SPRITES_FRENTE)
	if dir == null:
		return claves
	for archivo in dir.get_files():
		if archivo.ends_with(".png"):
			claves.append(archivo.get_basename())
	return claves


# ─── Aplicar ediciones ─────────────────────────────────────────────────────────

## Fija el offset de `lado` en los datos y sincroniza lienzo, controles y lista.
func _aplicar_offset(lado: StringName, valor: Vector2i, actualizar_lienzo: bool) -> void:
	if _clave_actual.is_empty() or not _editable:
		return
	_datos.fijar(_clave_actual, lado, valor)
	if actualizar_lienzo:
		lienzo.fijar_offset(lado, valor)
	_refrescar_controles()
	_refrescar_item(_clave_actual)
	_actualizar_estado()


func _on_offset_lienzo(lado: StringName, nuevo: Vector2i) -> void:
	_aplicar_offset(lado, nuevo, false)


func _on_lado_activo_lienzo(lado: StringName) -> void:
	_actualizando_ui = true
	_radio_lado[lado].button_pressed = true
	_actualizando_ui = false


func _on_spin_cambiado(_valor: float, lado: StringName) -> void:
	if _actualizando_ui:
		return
	var nuevo := Vector2i(int(_spin_x[lado].value), int(_spin_y[lado].value))
	_aplicar_offset(lado, nuevo, true)


func _on_radio_lado(marcado: bool, lado: StringName) -> void:
	if _actualizando_ui or not marcado:
		return
	lienzo.set_lado_activo(lado)


# ─── Refrescos ─────────────────────────────────────────────────────────────────

func _refrescar_lienzo() -> void:
	if _clave_actual.is_empty():
		return
	lienzo.mostrar(_clave_actual, _datos.obtener(_clave_actual), _tema_actual(), _check_shiny.button_pressed)
	var faltan := lienzo.lados_sin_sprite()
	if faltan.is_empty():
		_aviso_sprites = ""
	else:
		var rutas: Array[String] = []
		for lado in faltan:
			rutas.append(LienzoBattlers.ruta_sprite(_clave_actual, lado, _check_shiny.button_pressed).trim_prefix("res://graficos/pokemon/"))
		_aviso_sprites = "Sprite faltante: %s (se muestra un placeholder)" % ", ".join(rutas)


func _refrescar_controles() -> void:
	_actualizando_ui = true
	var offsets := _datos.obtener(_clave_actual)
	var lados := {LADO_ENEMIGO: BattleLayout.ancla_rival(), LADO_JUGADOR: BattleLayout.ancla_jugador()}
	for lado in lados:
		var valor: Vector2i = offsets[String(lado)]
		_spin_x[lado].set_value_no_signal(valor.x)
		_spin_y[lado].set_value_no_signal(valor.y)
		var final_pos: Vector2 = lados[lado] + Vector2(valor)
		_final_label[lado].text = "Posición final: (%d, %d)" % [final_pos.x, final_pos.y]
	_radio_lado[lienzo.lado_activo].button_pressed = true
	_check_sombra.set_pressed_no_signal(bool(offsets.get("sombra", false)))

	var numero := _numero_dex(_clave_actual)
	var indice := maxi(_claves_todas.find(_clave_actual), 0) + 1
	_titulo_label.text = "%s%s   (%d / %d)" % [
		_clave_actual, "  #%d" % numero if numero > 0 else "", indice, _claves_todas.size()]
	_actualizando_ui = false
	_actualizar_botones()


func _actualizar_botones() -> void:
	var hay_especie := not _clave_actual.is_empty()
	for lado in _btn_restablecer:
		_btn_restablecer[lado].disabled = not (hay_especie and _editable)
		_spin_x[lado].editable = hay_especie and _editable
		_spin_y[lado].editable = hay_especie and _editable
	_check_sombra.disabled = not (hay_especie and _editable)
	_btn_descartar.disabled = not (hay_especie and _editable and _datos.es_modificada(_clave_actual))
	_btn_guardar.disabled = not (_editable and _datos.puede_guardar() and _datos.hay_modificadas())
	lienzo.editable = _editable
	var hay_lista := not _claves_todas.is_empty()
	_btn_anterior.disabled = not hay_lista
	_btn_siguiente.disabled = not hay_lista


func _actualizar_estado() -> void:
	var partes: Array[String] = []
	var cantidad := _datos.modificadas().size()
	partes.append("%d especie(s) con cambios sin guardar" % cantidad if cantidad > 0 else "Sin cambios pendientes")
	if not _aviso_sprites.is_empty():
		partes.append(_aviso_sprites)
	if not _mensaje.is_empty():
		partes.append(_mensaje)
	_estado_label.text = "  ·  ".join(partes)
	var color := COLOR_ERROR if _mensaje_es_error else (COLOR_AVISO if not _aviso_sprites.is_empty() else Color(1, 1, 1, 0.8))
	_estado_label.add_theme_color_override("font_color", color)
	_actualizar_botones()


func _set_mensaje(texto: String, es_error: bool) -> void:
	_mensaje = texto
	_mensaje_es_error = es_error
	if _estado_label != null:
		_actualizar_estado()


func _numero_dex(clave: String) -> int:
	if _indice_dex.has(clave):
		return int(_indice_dex[clave])
	var corte := clave.rfind("_")
	if corte > 0 and _indice_dex.has(clave.substr(0, corte)):
		return int(_indice_dex[clave.substr(0, corte)])
	return 0


# ─── Lista de especies ─────────────────────────────────────────────────────────

## Recalcula `_claves_todas` a partir del orden dex según el orden elegido.
func _aplicar_orden() -> void:
	_claves_todas = _claves_dex.duplicate()
	if _orden_alfabetico:
		_claves_todas.sort()


## Cambia entre orden por número de la Pokédex nacional y alfabético.
func fijar_orden_alfabetico(alfabetico: bool) -> void:
	_orden_alfabetico = alfabetico
	if _opcion_orden != null and _opcion_orden.selected != int(alfabetico):
		_opcion_orden.select(int(alfabetico))
	if Engine.is_editor_hint():
		EditorInterface.get_editor_settings().set_setting(AJUSTE_ORDEN, alfabetico)
	_aplicar_orden()
	_reconstruir_lista()


func _orden_guardado() -> bool:
	if Engine.is_editor_hint():
		var ajustes = EditorInterface.get_editor_settings()
		if ajustes.has_setting(AJUSTE_ORDEN):
			return bool(ajustes.get_setting(AJUSTE_ORDEN))
	return false


func _on_orden_elegido(indice: int) -> void:
	fijar_orden_alfabetico(indice == 1)
	lienzo.grab_focus.call_deferred()


## true si `clave` casa con el filtro por nombre o por número dex ("25", "#025").
func _coincide_filtro(clave: String, filtro: String) -> bool:
	if filtro.is_empty() or clave.to_lower().contains(filtro):
		return true
	var numero := filtro.trim_prefix("#")
	return numero.is_valid_int() and _numero_dex(clave) == int(numero)


func _reconstruir_lista() -> void:
	var filtro := _filtro_edit.text.strip_edges().to_lower()
	_claves_visibles.clear()
	_lista.clear()
	for clave in _claves_todas:
		if _coincide_filtro(clave, filtro):
			_claves_visibles.append(clave)
			_lista.add_item(_texto_item(clave))
			_pintar_item(_lista.item_count - 1, clave)
	_conteo_label.text = "%d / %d especies" % [_claves_visibles.size(), _claves_todas.size()]
	_sincronizar_lista()


func _texto_item(clave: String) -> String:
	var numero := _numero_dex(clave)
	var prefijo_dex := ("#%03d  " % numero) if numero > 0 else ""
	return ("● " if _datos.es_modificada(clave) else "") + prefijo_dex + clave


func _pintar_item(indice: int, clave: String) -> void:
	_lista.set_item_custom_fg_color(indice, COLOR_MODIFICADA if _datos.es_modificada(clave) else Color(1, 1, 1, 0.9))


func _refrescar_item(clave: String) -> void:
	var indice := _claves_visibles.find(clave)
	if indice < 0:
		return
	_lista.set_item_text(indice, _texto_item(clave))
	_pintar_item(indice, clave)


func _sincronizar_lista() -> void:
	var indice := _claves_visibles.find(_clave_actual)
	if indice >= 0:
		_lista.select(indice)
		_lista.ensure_current_is_visible()
	else:
		_lista.deselect_all()


func _on_filtro_cambiado(_texto: String) -> void:
	_reconstruir_lista()


func _on_lista_seleccionada(indice: int) -> void:
	if indice < 0 or indice >= _claves_visibles.size():
		return
	seleccionar(_claves_visibles[indice])
	# Devuelve el foco al lienzo para que las flechas muevan el sprite, no la lista.
	lienzo.grab_focus.call_deferred()


## Salta `paso` especies (circular) sobre la lista filtrada visible. Si la especie
## actual no está en la lista filtrada, va a la primera (paso > 0) o a la última.
func _navegar(paso: int) -> void:
	if _claves_visibles.is_empty():
		return
	var indice := _claves_visibles.find(_clave_actual)
	if indice < 0:
		indice = 0 if paso > 0 else _claves_visibles.size() - 1
	else:
		indice = posmod(indice + paso, _claves_visibles.size())
	seleccionar(_claves_visibles[indice])


## Primera (`al_final = false`) o última especie de la lista filtrada visible.
func _navegar_a_extremo(al_final: bool) -> void:
	if _claves_visibles.is_empty():
		return
	seleccionar(_claves_visibles[_claves_visibles.size() - 1 if al_final else 0])


## Copia los offsets y la bandera de sombra de la especie anterior de la lista visible
## a la actual (edición normal: la marca como modificada). Sin especie anterior no hace nada.
func copiar_de_anterior() -> void:
	if _clave_actual.is_empty() or not _editable:
		return
	var indice := _claves_visibles.find(_clave_actual)
	if indice <= 0:
		_set_mensaje("No hay una especie anterior en la lista de la que copiar.", false)
		return
	var origen := _claves_visibles[indice - 1]
	var offsets := _datos.obtener(origen)
	_datos.fijar(_clave_actual, LADO_ENEMIGO, offsets["enemy"])
	_datos.fijar(_clave_actual, LADO_JUGADOR, offsets["player"])
	_datos.fijar_sombra(_clave_actual, offsets["sombra"])
	lienzo.fijar_offset(LADO_ENEMIGO, offsets["enemy"])
	lienzo.fijar_offset(LADO_JUGADOR, offsets["player"])
	lienzo.fijar_sombra(offsets["sombra"])
	_refrescar_controles()
	_refrescar_item(_clave_actual)
	_set_mensaje("Offsets y sombra copiados de %s." % origen, false)


## Pone el foco en el filtro con el texto seleccionado (para sustituirlo al escribir).
func enfocar_filtro() -> void:
	_filtro_edit.grab_focus()
	_filtro_edit.select_all()


func _on_filtro_confirmado(_texto: String) -> void:
	# Intro en el filtro: selecciona la primera coincidencia y vuelve al lienzo.
	if not _claves_visibles.is_empty():
		seleccionar(_claves_visibles[0])
	lienzo.grab_focus()


func _on_campo_confirmado(_texto: String) -> void:
	# Intro en un SpinBox (el valor ya lo aplicó el propio SpinBox): vuelve al lienzo.
	lienzo.grab_focus()


# ─── Tema de fondo/suelo ───────────────────────────────────────────────────────

## Un item por escenario de batalla (EscenarioBatalla.ids_escenarios()); el texto
## es el id. Un ajuste guardado con un nombre de tema legado (p. ej. "EDIFICIO_1")
## no coincide con ningún id y deja el escenario por defecto.
func _poblar_temas() -> void:
	_opcion_tema.clear()
	var ids := EscenarioBatalla.ids_escenarios()
	for id in ids:
		_opcion_tema.add_item(id)
		var rutas := EscenarioBatalla.rutas(id)
		_opcion_tema.set_item_tooltip(_opcion_tema.item_count - 1,
			"%s + %s" % [String(rutas["fondo"]).get_file(), String(rutas["suelo"]).get_file()])
	var seleccion := ids.find(_tema_guardado())
	if seleccion < 0:
		seleccion = maxi(ids.find(TEMA_DEFECTO), 0)
	_opcion_tema.select(seleccion)


## {"fondo", "suelo", "entrada"} del escenario elegido.
func _tema_actual() -> Dictionary:
	if _opcion_tema.selected < 0:
		return {}
	return EscenarioBatalla.rutas(_opcion_tema.get_item_text(_opcion_tema.selected))


func _tema_guardado() -> String:
	if Engine.is_editor_hint():
		var ajustes = EditorInterface.get_editor_settings()
		if ajustes.has_setting(AJUSTE_TEMA):
			return String(ajustes.get_setting(AJUSTE_TEMA))
	return TEMA_DEFECTO


func _guardar_tema_elegido() -> void:
	if Engine.is_editor_hint():
		var ajustes = EditorInterface.get_editor_settings()
		ajustes.set_setting(AJUSTE_TEMA, _opcion_tema.get_item_text(_opcion_tema.selected))


func _on_tema_elegido(_indice: int) -> void:
	_guardar_tema_elegido()
	_refrescar_lienzo()
	_actualizar_estado()


## Activa/desactiva la sombra de la especie actual (aplica a ambos lados). La marca
## como modificada; "Restablecer lado" no la toca y "Descartar" la restaura.
func alternar_sombra() -> void:
	if _clave_actual.is_empty() or not _editable:
		return
	_check_sombra.button_pressed = not _check_sombra.button_pressed


func _on_sombra_toggle(activa: bool) -> void:
	if _actualizando_ui or _clave_actual.is_empty() or not _editable:
		return
	_datos.fijar_sombra(_clave_actual, activa)
	lienzo.fijar_sombra(activa)
	_refrescar_item(_clave_actual)
	_actualizar_estado()


## Pasa al tema siguiente (`paso = 1`) o anterior (`paso = -1`), circular.
func cambiar_tema(paso: int) -> void:
	var cantidad := _opcion_tema.item_count
	if cantidad == 0:
		return
	_opcion_tema.select(posmod(_opcion_tema.selected + paso, cantidad))
	_on_tema_elegido(_opcion_tema.selected)


# ─── Zoom ×3 / ×4 ──────────────────────────────────────────────────────────────

func zoom_actual() -> int:
	return lienzo.zoom


func alternar_zoom() -> void:
	_aplicar_zoom(ZOOMS[(ZOOMS.find(lienzo.zoom) + 1) % ZOOMS.size()], true)


func _on_zoom_elegido(indice: int) -> void:
	_aplicar_zoom(ZOOMS[indice], true)


## Cambia el factor de zoom (solo el tamaño en pantalla del lienzo: ninguna coordenada
## lógica ni offset cambia), ajusta la ventana y, si `persistir`, lo recuerda.
func _aplicar_zoom(factor: int, persistir: bool) -> void:
	if not ZOOMS.has(factor):
		factor = ZOOMS[0]
	lienzo.zoom = factor
	_opcion_zoom.select(ZOOMS.find(factor))
	if persistir:
		_guardar_zoom()
	_ajustar_tamano_ventana.call_deferred()


func _zoom_guardado() -> int:
	if Engine.is_editor_hint():
		var ajustes = EditorInterface.get_editor_settings()
		if ajustes.has_setting(AJUSTE_ZOOM):
			return int(ajustes.get_setting(AJUSTE_ZOOM))
	return ZOOMS[0]


func _guardar_zoom() -> void:
	if Engine.is_editor_hint():
		EditorInterface.get_editor_settings().set_setting(AJUSTE_ZOOM, lienzo.zoom)


## Tamaño mínimo que necesita la UI con el zoom actual. Si el editor vive en una
## Window (plugin.gd), le fija ese `min_size` y la agranda si ya no cabe (p. ej. al
## pasar a ×4). Nunca hay scroll sobre el lienzo.
func _ajustar_tamano_ventana() -> void:
	if not is_inside_tree() or _margen_raiz == null:
		return
	var minimo := Vector2i(_margen_raiz.get_combined_minimum_size().ceil())
	custom_minimum_size = Vector2(minimo)
	var ventana := get_window()
	if ventana != null and ventana != get_tree().root:
		ventana.min_size = minimo
		ventana.size = ventana.size.max(minimo)


func _on_guias_toggle(activo: bool) -> void:
	lienzo.guias_visibles = activo


func _on_shiny_toggle(_activo: bool) -> void:
	_refrescar_lienzo()
	_actualizar_estado()


# ─── Teclado ───────────────────────────────────────────────────────────────────

func _input(evento: InputEvent) -> void:
	var tecla := evento as InputEventKey
	if tecla == null or not tecla.pressed or not is_visible_in_tree():
		return
	if _procesar_tecla(tecla):
		get_viewport().set_input_as_handled()


## Procesa una pulsación y devuelve true si la consume. Se hace en `_input` (antes que
## la GUI) para que ItemList/SpinBox/Tab no se queden las teclas. Tres grupos:
##  - globales (actúan con cualquier foco, también en un campo de texto): RePág/AvPág
##    (Shift = ±10), Ctrl+←/→, Ctrl+S, Ctrl+D, Ctrl+F;
##  - de edición (se ignoran con el foco en LineEdit/TextEdit, incluido el del
##    SpinBox, porque compiten con la escritura): flechas, Inicio/Fin, Tab, 1/2, R,
##    Shift+R, O, G, S, T, Shift+T, Z, "/";
##  - Esc con el foco en un campo de este editor: devuelve el foco al lienzo.
func _procesar_tecla(tecla: InputEventKey) -> bool:
	if _confirmar_cierre.visible or _opcion_tema.get_popup().visible or _opcion_zoom.get_popup().visible:
		return false
	if tecla.alt_pressed:
		return false
	var codigo: Key = tecla.keycode if tecla.keycode != KEY_NONE else tecla.physical_keycode
	var ctrl := tecla.is_command_or_control_pressed()
	var shift := tecla.shift_pressed
	var eco := tecla.echo

	# Esc en un campo de texto o SpinBox de este editor.
	if codigo == KEY_ESCAPE and not ctrl and not shift:
		var foco := get_viewport().gui_get_focus_owner()
		if foco != null and _foco_en_campo_de_texto() and is_ancestor_of(foco):
			lienzo.grab_focus()
			return true
		return false

	# Grupo global con Ctrl.
	if ctrl:
		match codigo:
			KEY_S:
				if not eco:
					guardar()
				return true
			KEY_LEFT:
				anterior()
				return true
			KEY_RIGHT:
				siguiente()
				return true
			KEY_D:
				if not eco:
					copiar_de_anterior()
				return true
			KEY_F:
				if not eco:
					enfocar_filtro()
				return true
		return false

	# Grupo global: RePág / AvPág (Shift = ±10).
	if codigo == KEY_PAGEUP or codigo == KEY_PAGEDOWN:
		var salto := PASO_SALTO if shift else 1
		_navegar(salto if codigo == KEY_PAGEDOWN else -salto)
		return true

	# Grupo de edición: no compite con la escritura en un campo de texto.
	if _foco_en_campo_de_texto():
		return false

	# "/" enfoca el filtro (en algunos teclados requiere Shift: se mira el carácter).
	if tecla.unicode == 47 or codigo == KEY_SLASH:
		if not eco:
			enfocar_filtro()
		return true

	match codigo:
		KEY_LEFT:
			_mover_lado_activo(Vector2i.LEFT, shift)
			return true
		KEY_RIGHT:
			_mover_lado_activo(Vector2i.RIGHT, shift)
			return true
		KEY_UP:
			_mover_lado_activo(Vector2i.UP, shift)
			return true
		KEY_DOWN:
			_mover_lado_activo(Vector2i.DOWN, shift)
			return true
		KEY_HOME:
			if not eco:
				_navegar_a_extremo(false)
			return true
		KEY_END:
			if not eco:
				_navegar_a_extremo(true)
			return true
		KEY_TAB:
			# Se consume para que no mueva el foco de la GUI; alterna el lado activo.
			if not eco:
				lienzo.set_lado_activo(LADO_JUGADOR if lienzo.lado_activo == LADO_ENEMIGO else LADO_ENEMIGO)
			return true
		KEY_1, KEY_KP_1:
			if not shift and not eco:
				lienzo.set_lado_activo(LADO_ENEMIGO)
			return not shift
		KEY_2, KEY_KP_2:
			if not shift and not eco:
				lienzo.set_lado_activo(LADO_JUGADOR)
			return not shift
		KEY_R:
			if not eco:
				if shift:
					descartar_especie()
				else:
					restablecer_lado(lienzo.lado_activo)
			return true
		KEY_O:
			if not shift and not eco:
				alternar_sombra()
			return not shift
		KEY_G:
			if not shift and not eco:
				_check_guias.button_pressed = not _check_guias.button_pressed
			return not shift
		KEY_S:
			if not shift and not eco:
				_check_shiny.button_pressed = not _check_shiny.button_pressed
			return not shift
		KEY_T:
			if not eco:
				cambiar_tema(-1 if shift else 1)
			return true
		KEY_Z:
			if not shift and not eco:
				alternar_zoom()
			return not shift
	return false


func _mover_lado_activo(direccion: Vector2i, grueso: bool) -> void:
	if _editable and not _clave_actual.is_empty():
		lienzo.mover_activo(direccion * (PASO_GRUESO if grueso else PASO_FINO))


## true si el foco está en un LineEdit/TextEdit (incluido el LineEdit interno de un
## SpinBox) o en un SpinBox.
func _foco_en_campo_de_texto() -> bool:
	var foco := get_viewport().gui_get_focus_owner()
	return foco is LineEdit or foco is TextEdit or foco is SpinBox


func _on_cierre_confirmado() -> void:
	if _al_cierre_confirmado.is_valid():
		_al_cierre_confirmado.call()


# ─── Construcción de la UI ─────────────────────────────────────────────────────

func _construir_ui() -> void:
	var margen := MarginContainer.new()
	margen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "right", "top", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 8)
	add_child(margen)
	_margen_raiz = margen

	var raiz := VBoxContainer.new()
	raiz.add_theme_constant_override("separation", 6)
	margen.add_child(raiz)

	var principal := HBoxContainer.new()
	principal.size_flags_vertical = Control.SIZE_EXPAND_FILL
	principal.add_theme_constant_override("separation", 10)
	raiz.add_child(principal)

	principal.add_child(_construir_panel_lista())
	principal.add_child(VSeparator.new())
	principal.add_child(_construir_panel_edicion())

	_estado_label = Label.new()
	_estado_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_estado_label.custom_minimum_size = Vector2(0, 36)
	raiz.add_child(_estado_label)

	var ayuda := Label.new()
	ayuda.text = AYUDA_TECLAS
	ayuda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ayuda.add_theme_font_size_override("font_size", 12)
	ayuda.modulate = Color(1, 1, 1, 0.75)
	raiz.add_child(ayuda)

	_confirmar_cierre = ConfirmationDialog.new()
	_confirmar_cierre.title = "Cambios sin guardar"
	_confirmar_cierre.ok_button_text = "Descartar y cerrar"
	_confirmar_cierre.cancel_button_text = "Volver"
	_confirmar_cierre.confirmed.connect(_on_cierre_confirmado)
	add_child(_confirmar_cierre)

	_poblar_temas()


func _construir_panel_lista() -> Control:
	var caja := VBoxContainer.new()
	caja.custom_minimum_size = Vector2(230, 0)
	caja.add_theme_constant_override("separation", 4)

	_filtro_edit = LineEdit.new()
	_filtro_edit.placeholder_text = "Filtrar por nombre o nº...  ( / o Ctrl+F )"
	_filtro_edit.tooltip_text = "Intro: selecciona la primera coincidencia y vuelve al lienzo. Esc: vuelve al lienzo.\nRePág/AvPág siguen cambiando de especie mientras escribes."
	_filtro_edit.clear_button_enabled = true
	_filtro_edit.text_changed.connect(_on_filtro_cambiado)
	_filtro_edit.text_submitted.connect(_on_filtro_confirmado)
	caja.add_child(_filtro_edit)

	var fila_orden := HBoxContainer.new()
	var etiqueta_orden := Label.new()
	etiqueta_orden.text = "Orden:"
	fila_orden.add_child(etiqueta_orden)
	_opcion_orden = OptionButton.new()
	_opcion_orden.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_opcion_orden.focus_mode = Control.FOCUS_NONE
	_opcion_orden.add_item("Nº Pokédex nacional")
	_opcion_orden.add_item("Alfabético")
	_orden_alfabetico = _orden_guardado()
	_opcion_orden.select(int(_orden_alfabetico))
	_opcion_orden.item_selected.connect(_on_orden_elegido)
	fila_orden.add_child(_opcion_orden)
	caja.add_child(fila_orden)

	_lista = ItemList.new()
	_lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lista.select_mode = ItemList.SELECT_SINGLE
	_lista.item_selected.connect(_on_lista_seleccionada)
	caja.add_child(_lista)

	_conteo_label = Label.new()
	caja.add_child(_conteo_label)
	return caja


func _construir_panel_edicion() -> Control:
	var caja := VBoxContainer.new()
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja.add_theme_constant_override("separation", 6)

	# Barra superior: título, navegación, toggles y tema.
	var barra := HBoxContainer.new()
	barra.add_theme_constant_override("separation", 8)
	caja.add_child(barra)

	_btn_anterior = Button.new()
	_btn_anterior.text = "◀"
	_btn_anterior.tooltip_text = "Especie anterior (RePág o Ctrl+←)"
	_sin_foco(_btn_anterior)
	_btn_anterior.pressed.connect(anterior)
	barra.add_child(_btn_anterior)

	_titulo_label = Label.new()
	_titulo_label.custom_minimum_size = Vector2(240, 0)
	_titulo_label.add_theme_font_size_override("font_size", 15)
	_titulo_label.text = "(sin especie)"
	barra.add_child(_titulo_label)

	_btn_siguiente = Button.new()
	_btn_siguiente.text = "▶"
	_btn_siguiente.tooltip_text = "Especie siguiente (AvPág o Ctrl+→)"
	_sin_foco(_btn_siguiente)
	_btn_siguiente.pressed.connect(siguiente)
	barra.add_child(_btn_siguiente)

	var relleno := Control.new()
	relleno.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barra.add_child(relleno)

	_check_guias = CheckBox.new()
	_check_guias.text = "Guías"
	_check_guias.tooltip_text = "Mostrar/ocultar las guías de referencia (G)."
	_sin_foco(_check_guias)
	_check_guias.button_pressed = true
	_check_guias.toggled.connect(_on_guias_toggle)
	barra.add_child(_check_guias)

	_check_shiny = CheckBox.new()
	_check_shiny.text = "Shiny"
	_check_shiny.tooltip_text = "Vista shiny (S). Solo vista previa: los offsets son los mismos para la versión shiny."
	_sin_foco(_check_shiny)
	_check_shiny.toggled.connect(_on_shiny_toggle)
	barra.add_child(_check_shiny)

	var etiqueta_tema := Label.new()
	etiqueta_tema.text = "Tema:"
	barra.add_child(etiqueta_tema)
	_opcion_tema = OptionButton.new()
	_opcion_tema.tooltip_text = "Tema de fondo y suelo (T siguiente, Shift+T anterior)."
	_sin_foco(_opcion_tema)
	_opcion_tema.item_selected.connect(_on_tema_elegido)
	barra.add_child(_opcion_tema)

	var etiqueta_zoom := Label.new()
	etiqueta_zoom.text = "Zoom:"
	barra.add_child(etiqueta_zoom)
	_opcion_zoom = OptionButton.new()
	_opcion_zoom.tooltip_text = "Ampliación del lienzo (Z alterna). No cambia ningún offset."
	for factor in ZOOMS:
		_opcion_zoom.add_item("×%d" % factor, factor)
	_sin_foco(_opcion_zoom)
	_opcion_zoom.item_selected.connect(_on_zoom_elegido)
	barra.add_child(_opcion_zoom)

	# Lienzo centrado.
	var centro := CenterContainer.new()
	caja.add_child(centro)
	lienzo = LienzoBattlers.new()
	lienzo.offset_cambiado.connect(_on_offset_lienzo)
	lienzo.lado_activo_cambiado.connect(_on_lado_activo_lienzo)
	centro.add_child(lienzo)

	# Controles por lado.
	var grupo_lado := ButtonGroup.new()
	caja.add_child(_construir_fila_lado(LADO_ENEMIGO, "Rival [1] (enemy_offset)", grupo_lado))
	caja.add_child(_construir_fila_lado(LADO_JUGADOR, "Jugador [2] (player_offset)", grupo_lado))

	# Acciones.
	var acciones := HBoxContainer.new()
	acciones.add_theme_constant_override("separation", 8)
	caja.add_child(acciones)

	_check_sombra = CheckBox.new()
	_check_sombra.text = "Sombra (O)"
	_check_sombra.tooltip_text = "Muestra la sombra bajo la especie en batalla (rival y jugador). Se guarda como \"sombra\": true en el JSON; sin marcar = sin sombra. La sombra no sigue al offset del sprite."
	_sin_foco(_check_sombra)
	_check_sombra.toggled.connect(_on_sombra_toggle)
	acciones.add_child(_check_sombra)

	_btn_descartar = Button.new()
	_btn_descartar.text = "Descartar cambios de la especie (Shift+R)"
	_sin_foco(_btn_descartar)
	_btn_descartar.pressed.connect(descartar_especie)
	acciones.add_child(_btn_descartar)

	var relleno_acciones := Control.new()
	relleno_acciones.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	acciones.add_child(relleno_acciones)

	_btn_guardar = Button.new()
	_btn_guardar.text = "Guardar (Ctrl+S)"
	_sin_foco(_btn_guardar)
	_btn_guardar.pressed.connect(guardar)
	acciones.add_child(_btn_guardar)
	return caja


func _construir_fila_lado(lado: StringName, titulo: String, grupo: ButtonGroup) -> Control:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)

	var radio := CheckBox.new()
	radio.button_group = grupo
	radio.text = titulo
	radio.custom_minimum_size = Vector2(230, 0)
	radio.tooltip_text = "Lado activo: lo mueven las flechas (Tab alterna, %s lo elige). Sprite %s." % [
		"1" if lado == LADO_ENEMIGO else "2", "front/" if lado == LADO_ENEMIGO else "back/"]
	_sin_foco(radio)
	radio.button_pressed = lado == LADO_ENEMIGO
	radio.toggled.connect(_on_radio_lado.bind(lado))
	fila.add_child(radio)
	_radio_lado[lado] = radio

	fila.add_child(_crear_etiqueta("X"))
	var spin_x := _crear_spin()
	spin_x.value_changed.connect(_on_spin_cambiado.bind(lado))
	spin_x.get_line_edit().text_submitted.connect(_on_campo_confirmado)
	fila.add_child(spin_x)
	_spin_x[lado] = spin_x

	fila.add_child(_crear_etiqueta("Y"))
	var spin_y := _crear_spin()
	spin_y.value_changed.connect(_on_spin_cambiado.bind(lado))
	spin_y.get_line_edit().text_submitted.connect(_on_campo_confirmado)
	fila.add_child(spin_y)
	_spin_y[lado] = spin_y

	var final_label := Label.new()
	final_label.custom_minimum_size = Vector2(150, 0)
	final_label.modulate = Color(1, 1, 1, 0.7)
	fila.add_child(final_label)
	_final_label[lado] = final_label

	var boton := Button.new()
	boton.text = "Restablecer lado"
	boton.tooltip_text = "Deja este lado en (0, 0). R restablece el lado activo."
	_sin_foco(boton)
	boton.pressed.connect(restablecer_lado.bind(lado))
	fila.add_child(boton)
	_btn_restablecer[lado] = boton
	return fila


## Los botones, casillas y desplegables no toman el foco: así, tras un clic, el foco
## sigue donde estaba (p. ej. en el lienzo) y las teclas siguen funcionando.
func _sin_foco(control: Control) -> void:
	control.focus_mode = Control.FOCUS_NONE


func _crear_etiqueta(texto: String) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	return etiqueta


func _crear_spin() -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = -LIMITE_OFFSET
	spin.max_value = LIMITE_OFFSET
	spin.step = 1
	spin.rounded = true
	spin.custom_minimum_size = Vector2(90, 0)
	return spin
