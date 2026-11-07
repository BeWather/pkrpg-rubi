extends ColorRect

signal cerrada

# Estructa inicial de la escena
# ColorRect
# |-- CuadroTitulo (NinePatchRect)
# |   |-- Titulo (Label)
# |-- NinePatchRect
#     |-- Fondo (ColorRect) (gris)
#         |-- Cursor (ColorRect) (blanco)
#         |-- VBoxContainer
#             |-- HBoxContainer
#             |   |-- velocidadTexto (Label)
#             |   |-- HBoxContainer
#             |   |   |-- RichTextLabel (text = 'Lenta')
#             |   |   |-- RichTextLabel2 (text = 'Media')
#             |   |   |-- RichTextLabel3 (text = 'Rápida')
#             |-- HBoxContainer2
#             |   |-- animacionCombate (Label)
#             |   |-- HBoxContainer
#             |   |   |-- RichTextLabel (text = 'Si')
#             |   |   |-- RichTextLabel2 (text = 'No')
# Colores de fuente de opciones disponibles, seleccionado: primario f88880, sombra f83018
#                                          , no seleccionado: primario 484848, sombra d0d0c8

enum opciones { VELOCIDAD, ANIMACION, TIPO_COMBATE, SONIDO, CONTROLES, MARCO, SALIR }
enum opciones_sonido { NO, BAJO, NORMAL}

var cantidad_opciones_totales = 7
var cantidad_opciones_pantalla = 6
var primera_opcion_pantalla = 0
var opcion_seleccionada: int = 0
var opcion_sonido_seleccionada: int = 1

@onready var cursor = $"./PanelOpciones/FondoOpciones/CursorSelector"
@onready var vboxOpciones = $"./PanelOpciones/FondoOpciones/OpcionesVBox"
# @onready var titulo_cuadro = $"./CuadroTitulo/Label_Titulo"

var en_transicion = false
var opciones_guardadas: Opciones = Opciones.new()
var velocidad_actual: int = 2
var animacion_actual: bool = true
var tipo_combate_actual: int = 0
var controles_actual: int = 0
var imagen_tipo_actual: int = 1

func _ready() -> void:
	#self.visible = false
	cursor.position.y = ((opcion_seleccionada - primera_opcion_pantalla) % cantidad_opciones_totales) * 19

	# Las opciones siempre pertenecen a la sesión activa; este diálogo no carga disco.
	var sg = get_tree().root.get_node_or_null("SistemaGuardado")
	if sg and sg.datos_vivos:
		opciones_guardadas = sg.datos_vivos.opciones
		# Log: origen de datos
		print("[VENTANA OPCIONES] usando datos de SistemaGuardado en memoria; fecha_guardado= %s, version= %s" % [str(sg.datos_vivos.fecha_guardado), str(sg.datos_vivos.version)])
		# Mostrar summary de opciones actuales
		if opciones_guardadas:
			print("[VENTANA OPCIONES] opciones (in-memory): %s" % str(opciones_guardadas.to_dict()))
		# Inicializar algunos estados locales según la instancia
		velocidad_actual = int(opciones_guardadas.velocidad_texto)
		animacion_actual = bool(opciones_guardadas.animacion_combate)
		tipo_combate_actual = int(opciones_guardadas.tipo_combate)
		controles_actual = int(opciones_guardadas.controles)
		imagen_tipo_actual = int(opciones_guardadas.imagen_tipo)
		opcion_sonido_seleccionada = int(opciones_guardadas.nivel_audio)
		# Aplicar audio preset inmediato si existe
		Singleton.emit_signal("configurar_audio", int(opciones_guardadas.nivel_audio))

	# Recolectar nodos descriptivos y preparar referencias a etiquetas/choices
	_recolectar_nodos_opciones()
	# Actualizar valores dinámicos (ej: imagen_tipo_actual -> Imagen_Numero)
	_update_dynamic_choice_values()
	# Pintar estado inicial
	_update_visuals()
	# Actualizar texturas de NinePatchRect según imagen_tipo_actual
	_update_menu_box_textures()


var line_labels: Array = []
var line_choices: Array = []

const COLOR_SELECTED = Color(0.973, 0.533, 0.502)
const COLOR_SELECTED_SHADOW = Color(0.973, 0.188, 0.094)
const COLOR_NORMAL = Color(0.282, 0.282, 0.282)
const COLOR_NORMAL_SHADOW = Color(0.816, 0.816, 0.784)


func _recolectar_nodos_opciones() -> void:
	"""Construye `line_labels` y `line_choices` buscando dentro de `vboxOpciones`.
	Asume que cada hijo de vboxOpciones es un HBoxContainer con Label en índice 0 y
	opcionalmente un contenedor de choices en índice 1."""
	line_labels.clear()
	line_choices.clear()
	for hijo in vboxOpciones.get_children():
		# Esperamos HBoxContainer
		if hijo.get_child_count() == 0:
			continue
		var label = hijo.get_child(0)
		line_labels.append(label)
		if hijo.get_child_count() > 1:
			var cont = hijo.get_child(1)
			# Si el segundo hijo es un contenedor con múltiples children, colectarlos
			if cont and cont.get_child_count() > 0:
				line_choices.append(cont.get_children())
			else:
				line_choices.append([])
		else:
			line_choices.append([])


func _update_visuals() -> void:
	"""Actualiza colores de todas las líneas y sus choices según la selección actual.
	El texto de la línea seleccionada se pinta rojo; las choices muestran su opción activa en rojo."""
	# Normalizar todas las lineas y choices a color normal
	for i in range(line_labels.size()):
		var lbl = line_labels[i]
		if lbl:
			lbl.add_theme_color_override("default_color", COLOR_NORMAL)
			lbl.add_theme_color_override("font_shadow_color", COLOR_NORMAL_SHADOW)
		var choices = line_choices[i]
		for c in choices:
			c.add_theme_color_override("default_color", COLOR_NORMAL)
			c.add_theme_color_override("font_shadow_color", COLOR_NORMAL_SHADOW)

	# Resaltar la choice activa en cada línea (si existe)
	for i in range(line_choices.size()):
		var choices = line_choices[i]
		if choices and choices.size() > 0:
			var active_idx = _get_active_choice_index(i)
			if active_idx >= 0 and active_idx < choices.size():
				var active_choice = choices[active_idx]
				active_choice.add_theme_color_override("default_color", COLOR_SELECTED)
				active_choice.add_theme_color_override("font_shadow_color", COLOR_SELECTED_SHADOW)

	# Resaltar la línea con el cursor (label) en rojo
	if opcion_seleccionada >= 0 and opcion_seleccionada < line_labels.size():
		var lbl_sel = line_labels[opcion_seleccionada]
		if lbl_sel:
			lbl_sel.add_theme_color_override("default_color", COLOR_SELECTED)
			lbl_sel.add_theme_color_override("font_shadow_color", COLOR_SELECTED_SHADOW)


func _get_active_choice_index(line_idx: int) -> int:
	"""Devuelve el índice de choice activo para la línea indicada, o -1 si no aplica."""
	match line_idx:
		opciones.VELOCIDAD:
			# velocidad_actual es 1..3 -> index 0..2
			return int(velocidad_actual) - 1
		opciones.ANIMACION:
			# animacion_actual: true -> índice 0 (SÍ), false -> 1 (NO)
			return 0 if animacion_actual else 1
		opciones.TIPO_COMBATE:
			return int(tipo_combate_actual)
		opciones.SONIDO:
			return int(opcion_sonido_seleccionada)
		opciones.CONTROLES:
			return int(controles_actual)
		opciones.MARCO:
			# Mostrar el número de imagen (segunda choice) como activa
			return 1 if line_choices[line_idx].size() > 1 else -1
		_:
			return -1


func _input(event: InputEvent) -> void:
	if visible and en_transicion == false:
		if event.is_action_pressed("btn_cancelar"):
			get_viewport().set_input_as_handled()
			cerrar_ventana()

		elif event.is_action_pressed("btn_abajo"):
			Singleton.emit_signal("play_sound", "cursor_menu")
			if opcion_seleccionada - primera_opcion_pantalla < cantidad_opciones_pantalla - 1:
				opcion_seleccionada += 1
				cursor.position.y = ((opcion_seleccionada - primera_opcion_pantalla) % cantidad_opciones_totales) * 19
				_update_visuals()
			else:
				if opcion_seleccionada < cantidad_opciones_totales - 1:
					primera_opcion_pantalla += 1
					vboxOpciones.position.y -= 19
					opcion_seleccionada += 1
					_update_visuals()
				elif opcion_seleccionada == cantidad_opciones_totales - 1:
					primera_opcion_pantalla = 0
					opcion_seleccionada = 0
					cursor.position.y = ((opcion_seleccionada - primera_opcion_pantalla) % cantidad_opciones_totales) * 19
					vboxOpciones.position.y = 0
					_update_visuals()

		elif event.is_action_pressed("btn_arriba"):
			Singleton.emit_signal("play_sound", "cursor_menu")
			if opcion_seleccionada - primera_opcion_pantalla > 0:
				opcion_seleccionada -= 1
				cursor.position.y = ((opcion_seleccionada - primera_opcion_pantalla) % cantidad_opciones_totales) * 19
				_update_visuals()
			else:
				if opcion_seleccionada > 0:
					primera_opcion_pantalla -= 1
					vboxOpciones.position.y += 19
					opcion_seleccionada -= 1
					_update_visuals()
				elif opcion_seleccionada == 0:
					primera_opcion_pantalla = cantidad_opciones_totales - cantidad_opciones_pantalla
					opcion_seleccionada = cantidad_opciones_totales - 1
					cursor.position.y = ((opcion_seleccionada - primera_opcion_pantalla) % cantidad_opciones_totales) * 19
					vboxOpciones.position.y = -19 * (cantidad_opciones_totales - cantidad_opciones_pantalla)
					_update_visuals()

		elif event.is_action_pressed("btn_accion") and opcion_seleccionada == opciones.SALIR:
			get_viewport().set_input_as_handled()
			cerrar_ventana()
		elif event.is_action_pressed("btn_derecha"):
			Singleton.emit_signal("play_sound", "cursor_menu")
			match opcion_seleccionada:
				opciones.VELOCIDAD:
					# Cambiar velocidad de texto circular (Lenta=1, Media=2, Rápida=3)
					velocidad_actual += 1
					if velocidad_actual > Singleton.VelocidadTexto.RAPIDA:
						velocidad_actual = Singleton.VelocidadTexto.LENTA
					opciones_guardadas.velocidad_texto = int(velocidad_actual)
					_update_visuals()
					_guardar_opciones()
				opciones.ANIMACION:
					# Alternar animación combate (bool)
					animacion_actual = not animacion_actual
					opciones_guardadas.animacion_combate = animacion_actual
					_update_visuals()
					_guardar_opciones()
				opciones.TIPO_COMBATE:
					# Ciclar tipo combate
					tipo_combate_actual = (tipo_combate_actual + 1) % 2
					opciones_guardadas.tipo_combate = int(tipo_combate_actual)
					_update_visuals()
					_guardar_opciones()
				opciones.SONIDO:
					var etiquetas_opciones = vboxOpciones.get_children()
					var etiquetas_linea_sonido = etiquetas_opciones[opciones.SONIDO].get_children()
					var etiquetas_opciones_sonido = etiquetas_linea_sonido[1].get_children()
					var etiqueta_actual = etiquetas_opciones_sonido[opcion_sonido_seleccionada]
					etiqueta_actual.add_theme_color_override("default_color", Color(0.282, 0.282, 0.282))
					etiqueta_actual.add_theme_color_override("font_shadow_color", Color(0.816, 0.816, 0.784))
					opcion_sonido_seleccionada = (opcion_sonido_seleccionada + 1) % etiquetas_opciones_sonido.size()
					etiqueta_actual = etiquetas_opciones_sonido[opcion_sonido_seleccionada]
					etiqueta_actual.add_theme_color_override("default_color", Color(0.973, 0.533, 0.502))
					etiqueta_actual.add_theme_color_override("font_shadow_color", Color(0.973, 0.188, 0.094))
					Singleton.emit_signal("configurar_audio", opcion_sonido_seleccionada)
					opciones_guardadas.nivel_audio = int(opcion_sonido_seleccionada)
					_update_visuals()
					_guardar_opciones()
				opciones.CONTROLES:
					# Ciclar controles: NORMAL, LR, L=A (circular)
					controles_actual = (controles_actual + 1) % 3
					opciones_guardadas.controles = int(controles_actual)
					_update_visuals()
					_guardar_opciones()
				opciones.MARCO:
					# Incrementar imagen_tipo (1..20) con wrap circular
					imagen_tipo_actual += 1
					if imagen_tipo_actual > 20:
						imagen_tipo_actual = 1
					opciones_guardadas.imagen_tipo = int(imagen_tipo_actual)
					# Actualizar representación textual de imagen_tipo en la UI
					_update_dynamic_choice_values()
					_update_visuals()
					_update_menu_box_textures()
					_guardar_opciones()
		elif event.is_action_pressed("btn_izquierda"):
			Singleton.emit_signal("play_sound", "cursor_menu")
			match opcion_seleccionada:
				opciones.VELOCIDAD:
					# Cambiar velocidad circular hacia la izquierda
					velocidad_actual -= 1
					if velocidad_actual < Singleton.VelocidadTexto.LENTA:
						velocidad_actual = Singleton.VelocidadTexto.RAPIDA
					opciones_guardadas.velocidad_texto = int(velocidad_actual)
					_update_visuals()
					_guardar_opciones()
				opciones.ANIMACION:
					# Alternar animación combate (izquierda también alterna)
					animacion_actual = not animacion_actual
					opciones_guardadas.animacion_combate = animacion_actual
					_update_visuals()
					_guardar_opciones()
				opciones.TIPO_COMBATE:
					# Ciclar tipo combate hacia atrás
					tipo_combate_actual -= 1
					if tipo_combate_actual < 0:
						tipo_combate_actual = 1
					opciones_guardadas.tipo_combate = int(tipo_combate_actual)
					_update_visuals()
					_guardar_opciones()
				opciones.SONIDO:
					var etiquetas_opciones = vboxOpciones.get_children()
					var etiquetas_linea_sonido = etiquetas_opciones[opciones.SONIDO].get_children()
					var etiquetas_opciones_sonido = etiquetas_linea_sonido[1].get_children()
					var etiqueta_actual = etiquetas_opciones_sonido[opcion_sonido_seleccionada]
					etiqueta_actual.add_theme_color_override("default_color", Color(0.282, 0.282, 0.282))
					etiqueta_actual.add_theme_color_override("font_shadow_color", Color(0.816, 0.816, 0.784))
					if opcion_sonido_seleccionada == 0:
						opcion_sonido_seleccionada = etiquetas_opciones_sonido.size() - 1
					else:
						opcion_sonido_seleccionada -= 1
					etiqueta_actual = etiquetas_opciones_sonido[opcion_sonido_seleccionada]
					etiqueta_actual.add_theme_color_override("default_color", Color(0.973, 0.533, 0.502))
					etiqueta_actual.add_theme_color_override("font_shadow_color", Color(0.973, 0.188, 0.094))
					Singleton.emit_signal("configurar_audio", opcion_sonido_seleccionada)
					opciones_guardadas.nivel_audio = int(opcion_sonido_seleccionada)
					_update_visuals()
					_guardar_opciones()
				opciones.CONTROLES:
					# Ciclar controles hacia la izquierda (circular)
					controles_actual = (controles_actual - 1) % 3
					opciones_guardadas.controles = int(controles_actual)
					_update_visuals()
					_guardar_opciones()
				opciones.MARCO:
					# Decrementar imagen_tipo con wrap circular
					imagen_tipo_actual -= 1
					if imagen_tipo_actual < 1:
						imagen_tipo_actual = 20
					opciones_guardadas.imagen_tipo = int(imagen_tipo_actual)
					# Actualizar representación textual de imagen_tipo en la UI
					_update_dynamic_choice_values()
					_update_visuals()
					_update_menu_box_textures()
					_guardar_opciones()

func cerrar_ventana() -> void:
	en_transicion = true
	_guardar_opciones()
	# Emision diferida: si se emite dentro de _input, el receptor restaura el
	# menu de inicio en el mismo ciclo y ese mismo evento fisico residual
	# termina llegando al menu recien reactivado (ej: cancelar => salir del
	# juego). Diferido garantiza que nadie procese la senal durante la
	# propagacion del evento actual.
	call_deferred("_emitir_cerrada")


## Separada de cerrar_ventana para poder invocarla con call_deferred.
func _emitir_cerrada() -> void:
	cerrada.emit()


func _update_menu_box_textures() -> void:
	"""Actualiza las texturas de los NinePatchRect usando MenuBoxManager"""
	var menu_box_manager = preload("res://scripts/clases/MenuBoxManager.gd")

	# Actualizar CuadroTitulo
	var cuadro_titulo = $"./CuadroTitulo"
	if cuadro_titulo:
		menu_box_manager.apply_texture_to_ninepatch(cuadro_titulo, imagen_tipo_actual)

	# Actualizar PanelOpciones
	var panel_opciones = $"./PanelOpciones"
	if panel_opciones:
		menu_box_manager.apply_texture_to_ninepatch(panel_opciones, imagen_tipo_actual)


func _update_dynamic_choice_values() -> void:
	"""Actualiza valores dinámicos que se muestran en las choices, por ejemplo
	la segunda choice de la línea MARCO llamada 'Imagen_Numero' con el valor
	de `imagen_tipo_actual`."""
	# Asegurarnos de haber recolectado nodos
	if line_choices.size() == 0:
		_recolectar_nodos_opciones()

	# Línea MARCO -> obtener el container de choices
	if opciones.MARCO < line_choices.size():
		var choices = line_choices[opciones.MARCO]
		if choices and choices.size() > 1:
			# Asumimos que la segunda choice es un Label o RichTextLabel llamado Imagen_Numero
			var imagen_num_node = choices[1]
			if imagen_num_node and imagen_num_node.has_method("set_text"):
				imagen_num_node.set_text(str(imagen_tipo_actual))
			elif imagen_num_node and imagen_num_node is Label:
				imagen_num_node.text = str(imagen_tipo_actual)
			elif imagen_num_node and imagen_num_node is RichTextLabel:
				imagen_num_node.clear()
				imagen_num_node.append_bbcode(str(imagen_tipo_actual))
			else:
				# Intentar escribir via property 'text' si existe
				if imagen_num_node and "text" in imagen_num_node:
					imagen_num_node.text = str(imagen_tipo_actual)
				else:
					print("[VENTANA OPCIONES] advertencia: no se pudo asignar Imagen_Numero en la linea MARCO; nodo: %s" % str(imagen_num_node))
		else:
			# No hay segunda choice
			pass
	else:
		# La línea MARCO no existe en la estructura recolectada
		print("[VENTANA OPCIONES] advertencia: linea MARCO no encontrada en line_choices")


func _guardar_opciones() -> void:
	"""Sincroniza las opciones locales con el SistemaGuardado y aplica efectos inmediatos.
	Se guarda la partida para persistir la configuración."""
	# Preferir el nodo SistemaGuardado en el árbol (autoload/nodo raíz)
	var sg_node = get_tree().root.get_node_or_null("SistemaGuardado")
	if sg_node:
		print("[VENTANA OPCIONES] sincronizando opciones a SistemaGuardado.datos_vivos (node encontrado).")
		print("[VENTANA OPCIONES] opciones a sincronizar: %s" % str(opciones_guardadas.to_dict()))
		# Actualizar en memoria: asignar la instancia Opciones
		sg_node.datos_vivos.opciones = opciones_guardadas
		# Aplicar audio si corresponde
		Singleton.emit_signal("configurar_audio", int(opciones_guardadas.nivel_audio))
		print("[VENTANA OPCIONES] sincronización completada (node).")
		# Emitir señal para que otros componentes se actualicen
		Singleton.emit_signal("opciones_cambiadas")
		# No persistimos en disco: solo sincronizamos en memoria
		# (El sistema de guardado puede decidir cuándo volcar a disco)
		return

	# Fallback: usar la variable global SistemaGuardado si está disponible (solo memoria)
	if typeof(SistemaGuardado) != TYPE_NIL:
		print("[VENTANA OPCIONES] sincronizando opciones a SistemaGuardado global (fallback).")
		print("[VENTANA OPCIONES] opciones a sincronizar: %s" % str(opciones_guardadas.to_dict()))
		SistemaGuardado.datos_vivos.opciones = opciones_guardadas
		Singleton.emit_signal("configurar_audio", int(opciones_guardadas.nivel_audio))
		print("[VENTANA OPCIONES] sincronización completada (global).")
		# Emitir señal para que otros componentes se actualicen
		Singleton.emit_signal("opciones_cambiadas")
	else:
		print("[VENTANA OPCIONES] no se encontró SistemaGuardado; opciones no sincronizadas: %s" % str(opciones_guardadas.to_dict()))

func _logear(tag: String) -> void:
	print("🔄 [VENTANA OPCIONES] → %s" % tag)
