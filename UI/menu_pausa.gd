extends NinePatchRect

@onready var select_box = $cursor

# Gestor central de texturas para cuadros de menú (menu_box_1..20)
var menu_box_manager_res = preload("res://scripts/clases/MenuBoxManager.gd")

enum VentanaActiva { NINGUNA, V_MENU, V_EQUIPO, V_OPCIONES, V_GUARDAR, V_MAPA_REGION, V_POKEDEX, V_POKENAV }
var ventana_activa = VentanaActiva.NINGUNA

var opcion_menu_seleccionada: int = 0
var nodo_raiz: Node2D = null
var nodo_jugador: Node2D = null
var v_opc_ok: bool = false
var en_transicion: bool = false
# Cooldown para evitar cierre inmediato del menú pausa tras guardado
var cooldown_input_menu: int = 0

# Variables para opciones dinámicas
var opciones_visibles: Array = []
var etiquetas_opciones: Array = []

# Variables para la pantalla de equipo
var pantalla_equipo_instancia = null
var scn_pantalla_equipo = preload("res://UI/equipo/pantalla-equipo.tscn")
var scn_ficha_entrenador = preload("res://UI/ficha-entrenador/ficha_entrenador.tscn")
var nodo_ficha_entrenador: Node2D = null
var instancia_mochila: Node2D = null
var nodo_menu: Node = null
var nodo_confirmacion_guardado: Node = null
var instancia_mapa_region: Control = null
## Sin tipo: se configuran propiedades del script de la Pokédex.
var instancia_pokedex = null
var instancia_pokenav: MenuPokenav = null
## Pokémon que usa VUELO mientras se elige el destino en el mapa de región.
var _pokemon_vuelo: BasePokemon = null
## Índice en el equipo de ese Pokémon: al cancelar el mapa (B) se vuelve a la
## pantalla de equipo con el cursor sobre él, como en GBA.
var _indice_vuelo: int = 0

func _ready() -> void:
	self.visible = false
	self.position = Vector2(176,0)

	# Obtener todas las etiquetas de opciones del menú
	recopilar_etiquetas_opciones()

	# Configurar menú dinámicamente
	configurar_menu_dinamico()

	# Aplicar textura del menu_box seleccionada en las opciones (si está disponible)
	var img_type = _get_saved_image_type()
	MenuBoxManager.apply_texture_to_ninepatch(self, img_type)

	# Conectar para recibir actualizaciones cuando las opciones cambien
	var singleton = get_tree().root.get_node_or_null("Singleton")
	if singleton and singleton.has_signal("opciones_cambiadas") and not singleton.is_connected("opciones_cambiadas", Callable(self, "_on_opciones_cambiadas")):
		singleton.connect("opciones_cambiadas", Callable(self, "_on_opciones_cambiadas"))

	# Conectar a SistemaGuardado.partida_cargada para aplicar textura si la partida se carga más tarde
	var sg = get_tree().root.get_node_or_null("SistemaGuardado")
	if sg and sg.has_signal("partida_cargada") and not sg.is_connected("partida_cargada", Callable(self, "_on_partida_cargada")):
		sg.connect("partida_cargada", Callable(self, "_on_partida_cargada"))


func _get_saved_image_type() -> int:
	# Leer de forma segura la opción imagen_tipo desde SistemaGuardado
	var sg = get_tree().root.get_node_or_null("SistemaGuardado")
	if sg and sg.datos_vivos and sg.datos_vivos.opciones:
		return int(sg.datos_vivos.opciones.imagen_tipo)
	# Fallback a variable global
	if typeof(SistemaGuardado) != TYPE_NIL and SistemaGuardado.datos_vivos and SistemaGuardado.datos_vivos.opciones:
		return int(SistemaGuardado.datos_vivos.opciones.imagen_tipo)
	return 1


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		MenuBoxManager.apply_texture_to_ninepatch(self, _get_saved_image_type())


func _on_opciones_cambiadas() -> void:
	# Aplicar la textura nueva cuando cambien las opciones
	var img_type = _get_saved_image_type()
	# Usar la clase MenuBoxManager desde el resource preload
	menu_box_manager_res.apply_texture_to_ninepatch(self, img_type)


func _on_partida_cargada() -> void:
	# Cuando la partida termina de cargarse, asegurarse de aplicar la textura definida en las opciones
	print("[MENU PAUSA] Partida cargada - actualizando textura del menu.")
	var img_type = _get_saved_image_type()
	menu_box_manager_res.apply_texture_to_ninepatch(self, img_type)

## Recopila todas las etiquetas de opciones del menú
## para poder mostrarlas/ocultarlas dinámicamente
## según las opciones visibles definidas en el singleton
func recopilar_etiquetas_opciones():
	etiquetas_opciones = []
	# Las etiquetas están hardcodeadas en el tscn, las obtenemos dinámicamente
	var hijos = get_children()
	for hijo in hijos:
		if hijo is Label and hijo.name != "cursor":
			etiquetas_opciones.append(hijo)

## Esta función configura el menú basándose en las opciones visibles del singleton,
## mostrando solo las opciones que deben ser visibles
func configurar_menu_dinamico():
	if Singleton == null or not Singleton.has_method("obtener_opciones_menu_visibles"):
		push_warning("[MENU] Singleton no listo, saltando configurar_menu_dinamico")
		return
	var result = Singleton.obtener_opciones_menu_visibles()
	if result == null:
		result = []
	opciones_visibles = result

	# Ocultar todas las etiquetas primero
	for etiqueta in etiquetas_opciones:
		etiqueta.visible = false

	# Mostrar solo las opciones visibles y ajustar posiciones
	var y_offset = 8  # Posición inicial
	for i in range(opciones_visibles.size()):
		if i < etiquetas_opciones.size():
			var etiqueta = etiquetas_opciones[i]
			etiqueta.text = opciones_visibles[i].nombre
			etiqueta.visible = true
			etiqueta.position.y = y_offset
			y_offset += 16  # Espaciado entre opciones

	# Ajustar el tamaño del menú basándose en el número de opciones visibles
	var altura_menu = max(48, (opciones_visibles.size() * 16) + 16)  # Mínimo 48, 16 pixels por opción + padding
	self.size.y = altura_menu

	# Resetear selección si es necesario
	if opcion_menu_seleccionada >= opciones_visibles.size():
		opcion_menu_seleccionada = 0

	# Actualizar posición del cursor
	actualizar_posicion_cursor()

## Esta función actualiza la posición del cursor basándose en la opción seleccionada
## y el número de opciones visibles
func actualizar_posicion_cursor():
	if opciones_visibles.size() > 0:
		select_box.position.y = 7 + (opcion_menu_seleccionada * 16)

func _process(_delta: float) -> void:
	if nodo_raiz == null:
		nodo_raiz = get_tree().root.get_node_or_null("AdministradorMapa")
	# El jugador puede no existir todavia (pantalla de inicio); reintentar
	# hasta que AdministradorMapa lo instancie al cargar una partida. La
	# version anterior solo intentaba mientras nodo_raiz fuera null, que pasa
	# un unico frame al arrancar, dejando nodo_jugador en Nil para siempre.
	if nodo_jugador == null and nodo_raiz != null and "jugador" in nodo_raiz:
		nodo_jugador = nodo_raiz.jugador
	# Reducir cooldown si está activo
	if cooldown_input_menu > 0:
		cooldown_input_menu -= 1

func _unhandled_input(event: InputEvent) -> void:
	# No bloquear input cuando el menú no es visible - necesitamos detectar btn_menu para activarlo
	if en_transicion:
		return
	# Cooldown para evitar cierre inmediato tras guardado
	if cooldown_input_menu > 0:
		return
	# Usamos just_pressed para evitar repeticiones y necesidad de cooldown manual
	match ventana_activa:
		VentanaActiva.NINGUNA:
			# Verificar múltiples condiciones antes de abrir el menú
			if event.is_action_pressed("btn_menu") and nodo_jugador and not nodo_jugador.paso_en_curso:
				if nodo_raiz != null and nodo_raiz.mapa_actual != null and nodo_raiz.mapa_actual.get("bloquear_menu") == true:
					return
				# Verificar también que no esté en diálogo y que tenga control
				if nodo_raiz.en_dialogo or nodo_jugador.no_control:
					print("🚫 [MENU_PAUSA] Bloqueado: en_dialogo=%s, no_control=%s" % [nodo_raiz.en_dialogo, nodo_jugador.no_control])
					return

				# Esta ruta abre directamente el menú, sin abrir_menu() del
				# administrador. Refrescar equipo/POKéDEX antes de leer opciones.
				nodo_raiz.actualizar_opciones_menu()
				Singleton.emit_signal("play_sound", "menu")
				Singleton.mantener_pausa(&"menu", true)
				# Reconfigurar el menú cada vez que se abre por si han cambiado las opciones
				configurar_menu_dinamico()
				self.visible = true
				ventana_activa = VentanaActiva.V_MENU
		VentanaActiva.V_MENU:
			# Solo procesar input del menú cuando esté visible
			if not visible:
				return
			if event.is_action_pressed("btn_menu") or event.is_action_pressed("btn_cancelar"):
				Singleton.emit_signal("play_sound", "cursor_menu")
				if nodo_raiz != null:
					Singleton.mantener_pausa(&"menu", false)
				_logear("Salir del menu por aqui soltar")
				# Guarda: abrir_menu() del administrador puede mostrar este
				# menu sin que nodo_jugador este resuelto todavia; sin el
				# guard, cerrar crasheaba con 'no_control' sobre Nil.
				if nodo_jugador != null:
					nodo_jugador.no_control = false
				self.visible = false
				ventana_activa = VentanaActiva.NINGUNA
			elif event.is_action_pressed("btn_abajo"):
				Singleton.emit_signal("play_sound", "cursor_menu")
				opcion_menu_seleccionada = (opcion_menu_seleccionada + 1) % opciones_visibles.size()
				actualizar_posicion_cursor()
			elif event.is_action_pressed("btn_arriba"):
				Singleton.emit_signal("play_sound", "cursor_menu")
				if opcion_menu_seleccionada == 0:
					opcion_menu_seleccionada = opciones_visibles.size() - 1
				else:
					opcion_menu_seleccionada -= 1
				actualizar_posicion_cursor()
			elif event.is_action_pressed("btn_accion"):
				Singleton.emit_signal("play_sound", "cursor_menu")
				ejecutar_accion_menu()
		VentanaActiva.V_EQUIPO:
			# La pantalla de equipo maneja su propio input
			pass
		VentanaActiva.V_OPCIONES:
			if v_opc_ok == false:
				v_opc_ok = true
				var ventana = load("res://UI/ventana_opciones.tscn")
				var ventana_opciones = ventana.instantiate()
				var nodo_menu_local = nodo_raiz.get_node_or_null("Menu")
				if nodo_menu_local:
					en_transicion = true
					# var transicion = nodo_raiz.telon
					# transicion.oscurecer()
					# await transicion.pantalla_oscurecida
					await Singleton.transicion("oscurecer")
					nodo_menu_local.add_child(ventana_opciones)
					ventana_opciones.cerrada.connect(_on_salir_ventana_opciones)
					ventana_opciones.visible = true
					ventana_opciones.en_transicion = true
					await get_tree().create_timer(0.4).timeout
					# transicion.aclarar()
					# await transicion.pantalla_aclarada
					await Singleton.transicion("aclarar")
					ventana_opciones.en_transicion = false
					en_transicion = false
				else:
					ventana_activa = VentanaActiva.V_MENU
		VentanaActiva.V_MAPA_REGION:
			# La propia pantalla del mapa consume navegación, zoom y cierre.
			pass
		VentanaActiva.V_POKEDEX:
			# La Pokédex no consume A con la lista activa: no repetir la opción.
			pass
		VentanaActiva.V_POKENAV:
			# El POKéNAV gestiona su propia entrada.
			pass

## Función para ejecutar la acción correspondiente a la opción seleccionada en el menú
func ejecutar_accion_menu():
	if opcion_menu_seleccionada < opciones_visibles.size():
		var accion = opciones_visibles[opcion_menu_seleccionada].accion
		match accion:
			"pokedex":
				abrir_pokedex()
			"pokemon":
				mostrar_pantalla_equipo()
			"mochila":
				abrir_mochila()
			"pokenav":
				abrir_pokenav()
			"jugador":
				abrir_ficha_entrenador()
			"guardar":
				if SesionSafari.activa():
					retirarse_de_safari()
				else:
					confirmar_guardado()
			"opciones":
				ventana_activa = VentanaActiva.V_OPCIONES
			"salir":
				_logear("Salir del menu")
				if nodo_jugador != null:
					nodo_jugador.no_control = false
				if nodo_raiz != null:
					Singleton.mantener_pausa(&"menu", false)
				self.visible = false
				ventana_activa = VentanaActiva.NINGUNA

## RETIRARSE (StartMenu en la ZONA SAFARI): cierra el menú y lanza el aviso de salir.
## Si el jugador dice NO, la partida SAFARI sigue como estaba.
func retirarse_de_safari() -> void:
	if nodo_raiz == null or not nodo_raiz.has_method("finalizar_safari"):
		return
	Singleton.mantener_pausa(&"menu", false)
	self.visible = false
	ventana_activa = VentanaActiva.NINGUNA
	nodo_raiz.finalizar_safari(SesionSafari.Motivo.RETIRADA)

## Pokédex con los datos de la partida (PokedexPartida). Como el PokéNav,
## oculta el menú mientras está abierta y lo recupera al cerrarla.
func abrir_pokedex() -> void:
	if instancia_pokedex != null or en_transicion:
		return
	if nodo_menu == null:
		nodo_menu = get_tree().root.get_node_or_null("AdministradorMapa/Menu")
	if nodo_menu == null:
		push_warning("[MENU PAUSA] No se encontró la capa Menu para abrir la Pokédex")
		return

	en_transicion = true
	await Singleton.transicion("oscurecer")
	instancia_pokedex = load("res://UI/pokedex/pokedex.tscn").instantiate()
	instancia_pokedex.usar_datos_prueba = false
	instancia_pokedex.fundir_al_cerrar = true
	instancia_pokedex.es_chica = str(SistemaGuardado.datos_vivos.jugador.get("sexo", "M")) == "F"
	instancia_pokedex.dex_nacional_disponible = PokedexPartida.nacional_disponible()
	instancia_pokedex.modo_dex = PokedexPartida.modo()
	instancia_pokedex.orden_dex = PokedexPartida.orden()
	# Modo y orden antes de cargar: cargar_datos ordena con ellos.
	instancia_pokedex.cargar_datos(PokedexPartida.crear_registros())
	instancia_pokedex.pokedex_cerrada.connect(_on_pokedex_cerrada)
	nodo_menu.add_child(instancia_pokedex)
	self.visible = false
	ventana_activa = VentanaActiva.V_POKEDEX
	await Singleton.transicion("aclarar")
	en_transicion = false

## La Pokédex ya fundió a negro: el telón la cubre al instante y se aclara
## sobre el menú. Modo y orden solo cambian con CAMBIO → VALE del buscador.
func _on_pokedex_cerrada() -> void:
	en_transicion = true
	PokedexPartida.guardar_vista(instancia_pokedex.modo_dex, instancia_pokedex.orden_dex)
	await Singleton.transicion("oscurecer", 0.0)
	instancia_pokedex.queue_free()
	instancia_pokedex = null
	self.visible = true
	ventana_activa = VentanaActiva.V_MENU
	await Singleton.transicion("aclarar")
	en_transicion = false

## POKéNAV: la escena hace su propio fundido de arranque desde negro y funde al apagarse.
func abrir_pokenav() -> void:
	if instancia_pokenav != null or en_transicion:
		return
	if nodo_menu == null:
		nodo_menu = get_tree().root.get_node_or_null("AdministradorMapa/Menu")
	if nodo_menu == null:
		push_warning("[MENU PAUSA] No se encontró la capa Menu para abrir el PokéNav")
		return

	en_transicion = true
	await Singleton.transicion("oscurecer")
	instancia_pokenav = load("res://UI/pokenav/menu_pokenav.tscn").instantiate()
	if nodo_raiz != null:
		instancia_pokenav.mapa_actual = nodo_raiz.mapa_actual
	instancia_pokenav.cerrado.connect(_on_pokenav_cerrado)
	nodo_menu.add_child(instancia_pokenav)
	self.visible = false
	ventana_activa = VentanaActiva.V_POKENAV
	await Singleton.transicion("aclarar", 0.0)
	en_transicion = false
	instancia_pokenav.arrancar()

## El POKéNAV ya fundió a negro: el telón lo cubre al instante y se aclara sobre el menú.
func _on_pokenav_cerrado() -> void:
	en_transicion = true
	await Singleton.transicion("oscurecer", 0.0)
	instancia_pokenav.queue_free()
	instancia_pokenav = null
	self.visible = true
	ventana_activa = VentanaActiva.V_MENU
	await Singleton.transicion("aclarar")
	en_transicion = false

func abrir_mochila() -> void:
	if nodo_menu == null:
		nodo_menu = get_tree().root.get_node("AdministradorMapa/Menu")
		if nodo_menu == null:
			print("❌ [MENU] No se pudo encontrar el nodo Menu")
			return

	Singleton.emit_signal("play_sound", "cursor_menu")
	await Singleton.transicion("oscurecer")
	en_transicion = true

	var mochila = load("res://UI/mochila/mochila.tscn")
	instancia_mochila = mochila.instantiate()
	nodo_menu.add_child(instancia_mochila)
	instancia_mochila.connect("mochila_cerrada", Callable(self, "_on_mochila_cerrada"))

## Callback para cuando se cierra la mochila
func _on_mochila_cerrada():
	print("[MENU PAUSA] Cerrando mochila...")
	# USAR con efecto en el mapa (p. ej. CUBO WAILMER frente a una parcela):
	# se cierra también el menú de pausa y la acción sigue en el campo.
	var accion_campo: Callable = Callable()
	if instancia_mochila is MochilaUI:
		accion_campo = (instancia_mochila as MochilaUI).accion_campo_pendiente
	nodo_menu.remove_child(instancia_mochila)
	instancia_mochila.queue_free()
	if accion_campo.is_valid():
		self.visible = false
	await Singleton.transicion("aclarar")
	en_transicion = false
	if accion_campo.is_valid():
		_cerrar_menu_para_accion_campo()
		accion_campo.call()

## Cierra el menú de pausa como "SALIR"; la acción de campo que se ejecuta
## justo después (mismo frame) vuelve a bloquear al jugador mientras dura.
func _cerrar_menu_para_accion_campo() -> void:
	self.visible = false
	ventana_activa = VentanaActiva.NINGUNA
	Singleton.mantener_pausa(&"menu", false)
	if nodo_jugador != null:
		nodo_jugador.no_control = false

func abrir_ficha_entrenador() -> void:
	if nodo_menu == null:
		nodo_menu = get_tree().root.get_node("AdministradorMapa/Menu")
		if nodo_menu == null:
			print("❌ [MENU] No se pudo encontrar la cámara")
			return

	Singleton.emit_signal("play_sound", "cursor_menu")
	await Singleton.transicion("oscurecer")
	en_transicion = true

	# Crear y configurar la ficha mientras está oscuro
	nodo_ficha_entrenador = scn_ficha_entrenador.instantiate()
	nodo_menu.add_child(nodo_ficha_entrenador)
	nodo_ficha_entrenador.connect("ficha_cerrada", Callable(self, "_on_ficha_cerrada"))
	nodo_ficha_entrenador.inicializar_con_datos()

## Callback para cuando se cierra la ficha del entrenador
func _on_ficha_cerrada():
	nodo_menu.remove_child(nodo_ficha_entrenador)
	nodo_ficha_entrenador.queue_free()
	await Singleton.transicion("aclarar")
	en_transicion = false

func _on_salir_ventana_opciones() -> void:
	en_transicion = true
	# var transicion = nodo_raiz.telon
	# transicion.aclarar()
	# await transicion.pantalla_aclarada
	await Singleton.transicion("aclarar")
	v_opc_ok = false
	ventana_activa = VentanaActiva.V_MENU
	en_transicion = false
	var nodo_opciones = nodo_raiz.get_node("Menu/VentanaOpciones")
	if nodo_opciones:
		nodo_opciones.queue_free()

# DEBUG: Función para verificar el estado del menú
# func debug_estado_menu():
# 	# Solo hacer debug en los primeros 10 segundos del juego
# 	if Engine.get_process_frames() < 600:  # 10 segundos * 60 FPS
# 		print("DEBUG MenuPausa - Visible: ", visible, " Estado: ", ventana_activa, " NodoRaiz: ", nodo_raiz != null, " NodoJugador: ", nodo_jugador != null)
# 		if nodo_jugador:
# 			print("  Jugador moving: ", nodo_jugador.get("moving") if nodo_jugador.has_method("get") else "no tiene get")
# 		if nodo_raiz:
# 			print("  En dialogo: ", nodo_raiz.en_dialogo)

# FUNCIONES PARA PANTALLA DE EQUIPO
## `indice_cursor`: caja donde arranca el cursor (al volver del mapa de VUELO).
func mostrar_pantalla_equipo(indice_cursor: int = 0):
	print("📱 [MENU] Abriendo pantalla de equipo desde menú pausa")

	# Obtener el equipo directamente del Singleton de guardado
	var equipo_jugador = SistemaGuardado.get_equipo()
	if equipo_jugador.is_empty():
		print("❌ [MENU] No se pudo obtener el equipo del jugador desde SistemaGuardado")
		return

	# Crear un wrapper EquipoPokemon para compatibilidad con el controlador
	var equipo_wrapper = EquipoPokemon.new()
	for pokemon in equipo_jugador:
		equipo_wrapper.agregar_pokemon(pokemon)

	# Crear instancia de la pantalla de equipo
	pantalla_equipo_instancia = scn_pantalla_equipo.instantiate()

	# Conectar señales
	pantalla_equipo_instancia.connect("pokemon_elegido", Callable(self, "_on_pokemon_seleccionado_menu"))
	pantalla_equipo_instancia.connect("pantalla_cerrada", Callable(self, "_on_pantalla_equipo_cerrada"))
	pantalla_equipo_instancia.movimiento_campo_elegido.connect(_on_movimiento_campo_elegido)

	# Añadir a la escena
	var nodo_menu_local = nodo_raiz.get_node_or_null("Menu")
	if nodo_menu_local:
		en_transicion = true
		# var transicion = nodo_raiz.telon
		# transicion.oscurecer()
		# await transicion.pantalla_oscurecida
		await Singleton.transicion("oscurecer")

		nodo_menu_local.add_child(pantalla_equipo_instancia)
		# pantalla_equipo_instancia.mostrar_equipo_desde("menu_pausa", equipo_wrapper, "Elegir un POKéMON.")
		pantalla_equipo_instancia.mostrar_equipo_modo(Singleton.ModoPEquipo.NORMAL, equipo_wrapper, "Elegir un POKéMON.")
		if indice_cursor > 0:
			pantalla_equipo_instancia.establecer_cursor(indice_cursor)

		ventana_activa = VentanaActiva.V_EQUIPO
		await get_tree().create_timer(0.4).timeout
		# transicion.aclarar()
		# await transicion.pantalla_aclarada
		await Singleton.transicion("aclarar")
		en_transicion = false
	else:
		print("❌ [MENU] No se encontró el nodo Menu")

func _on_pokemon_seleccionado_menu(indice: int):
	print("✅ [MENU] Pokémon seleccionado en índice: %d" % indice)
	# Aquí se puede añadir lógica específica para cuando se selecciona un Pokémon desde el menú
	# Por ejemplo, mostrar información detallada del Pokémon, etc.
	_on_pantalla_equipo_cerrada()

func _on_pantalla_equipo_cerrada():
	print("🔙 [MENU] Cerrando pantalla de equipo, volviendo al menú")
	en_transicion = true
	# var transicion = nodo_raiz.telon
	# transicion.oscurecer()
	# await transicion.pantalla_oscurecida
	await Singleton.transicion("oscurecer")

	_sincronizar_y_liberar_pantalla_equipo()

	ventana_activa = VentanaActiva.V_MENU
	await get_tree().create_timer(0.4).timeout
	# transicion.aclarar()
	# await transicion.pantalla_aclarada
	await Singleton.transicion("aclarar")
	en_transicion = false

## Sincroniza en SistemaGuardado el orden del equipo (pudo cambiar con CAMBIO)
## y libera la pantalla de equipo. Se llama con la pantalla ya en negro.
func _sincronizar_y_liberar_pantalla_equipo() -> void:
	# Sincronizar el orden del equipo en memoria antes de destruir la instancia
	if pantalla_equipo_instancia and pantalla_equipo_instancia.equipo_actual:
		var sistema_guardado = get_tree().root.get_node_or_null("SistemaGuardado")
		if sistema_guardado:
			var pokemones_actualizados: Array[BasePokemon] = []
			for pokemon in pantalla_equipo_instancia.equipo_actual.pokemones:
				pokemones_actualizados.append(pokemon)
			sistema_guardado.datos_vivos.equipo_pokemon = pokemones_actualizados
			print("🔄 [MENU] Orden del equipo sincronizado en memoria: %d Pokémon" % pokemones_actualizados.size())

	# Limpiar la instancia de la pantalla de equipo
	if pantalla_equipo_instancia:
		pantalla_equipo_instancia.ocultar_pantalla_equipo()
		pantalla_equipo_instancia.queue_free()
		pantalla_equipo_instancia = null

# --- VUELO: equipo → mapa de región → destino ---

## Movimiento de campo elegido en el menú del Pokémon. VUELO cambia la
## pantalla de equipo por el mapa de región en modo vuelo.
func _on_movimiento_campo_elegido(indice: int, movimiento: String) -> void:
	if pantalla_equipo_instancia == null:
		return
	if nodo_menu == null:
		nodo_menu = get_tree().root.get_node_or_null("AdministradorMapa/Menu")
	var puzle := PuzleBraille.para_movimiento(movimiento)
	if puzle != null and not en_transicion:
		_usar_puzle_braille_desde_equipo(indice, puzle)
		return
	if movimiento == "SURF" and not en_transicion:
		_usar_surf_desde_equipo(indice)
		return
	if movimiento == "DESTELLO" and not en_transicion:
		_usar_destello_desde_equipo(indice)
		return
	if movimiento == "FUERZA" and not en_transicion:
		_usar_fuerza_desde_equipo(indice)
		return
	if movimiento == "GOLPEROCA" and not en_transicion:
		_usar_golpe_roca_desde_equipo(indice)
		return
	if movimiento == "CORTE" and not en_transicion:
		_usar_corte_desde_equipo(indice)
		return
	if movimiento == "CASCADA" and not en_transicion:
		_usar_cascada_desde_equipo(indice)
		return
	if movimiento == "BUCEO" and not en_transicion:
		_usar_buceo_desde_equipo(indice)
		return
	if movimiento == "DANOSECRETO" and not en_transicion:
		_usar_dano_secreto_desde_equipo(indice)
		return
	if movimiento == "TELETRANSP" and not en_transicion:
		_usar_teletransporte_desde_equipo(indice)
		return
	if movimiento == "EXCAVAR" and not en_transicion:
		_usar_excavar_desde_equipo(indice)
		return
	if movimiento != "VUELO" or en_transicion or nodo_menu == null:
		if nodo_menu == null:
			push_warning("[MENU PAUSA] No se encontró la capa Menu para abrir el mapa de VUELO")
		# La pantalla se desactivó al emitir; sin VUELO se sigue en la lista.
		pantalla_equipo_instancia.activo = true
		return

	en_transicion = true
	var pokemones: Array = pantalla_equipo_instancia.equipo_actual.pokemones
	_pokemon_vuelo = pokemones[indice] if indice >= 0 and indice < pokemones.size() else null
	_indice_vuelo = indice
	await Singleton.transicion("oscurecer")
	_sincronizar_y_liberar_pantalla_equipo()

	var escena := preload("res://UI/mapa_region/region_hoenn.tscn")
	instancia_mapa_region = escena.instantiate()
	instancia_mapa_region.configurar_como_vuelo()
	instancia_mapa_region.mapa_cerrado.connect(_on_mapa_region_vuelo_cerrado)
	instancia_mapa_region.destino_vuelo_elegido.connect(_on_destino_vuelo_elegido)
	nodo_menu.add_child(instancia_mapa_region)
	self.visible = false
	ventana_activa = VentanaActiva.V_MAPA_REGION
	await Singleton.transicion("aclarar")
	en_transicion = false
	if is_instance_valid(instancia_mapa_region):
		instancia_mapa_region.habilitar_input()

## FUERZA, VUELO o EXCAVAR sobre un puzle en braille (FieldCallback_PrepareFadeInFromMenu +
## DoBrailleStrengthEffect / DoBrailleFlyEffect / DoBrailleDigEffect): se vuelve al campo, sale el
## Pokémon y se abre la cámara, sin mensaje ni el uso normal del movimiento.
func _usar_puzle_braille_desde_equipo(indice: int, puzle: PuzleBraille) -> void:
	en_transicion = true
	var pokemones: Array = pantalla_equipo_instancia.equipo_actual.pokemones
	var pokemon: BasePokemon = pokemones[indice] if indice >= 0 and indice < pokemones.size() else null
	await Singleton.transicion("oscurecer")
	_sincronizar_y_liberar_pantalla_equipo()
	self.visible = false
	await Singleton.transicion("aclarar")
	en_transicion = false
	_cerrar_menu_para_accion_campo()
	if is_instance_valid(puzle):
		await puzle.ejecutar(pokemon, nodo_jugador)

## SURF desde el menú del Pokémon (FieldCallback_Surf): se vuelve al campo y
## el Pokémon elegido hace SURF directamente, sin pregunta ni mensaje.
func _usar_surf_desde_equipo(indice: int) -> void:
	en_transicion = true
	var pokemones: Array = pantalla_equipo_instancia.equipo_actual.pokemones
	var pokemon: BasePokemon = pokemones[indice] if indice >= 0 and indice < pokemones.size() else null
	await Singleton.transicion("oscurecer")
	_sincronizar_y_liberar_pantalla_equipo()
	self.visible = false
	await Singleton.transicion("aclarar")
	en_transicion = false
	_cerrar_menu_para_accion_campo()
	if nodo_jugador == null:
		push_warning("[MENU PAUSA] Sin jugador: no se puede usar SURF")
		return
	nodo_jugador.usar_surf(pokemon)

## DESTELLO desde el menú del Pokémon (FieldCallback_PrepareFadeInFromMenu): se
## vuelve al campo y el Pokémon elegido ilumina la cueva, sin mensaje.
func _usar_destello_desde_equipo(indice: int) -> void:
	en_transicion = true
	var pokemones: Array = pantalla_equipo_instancia.equipo_actual.pokemones
	var pokemon: BasePokemon = pokemones[indice] if indice >= 0 and indice < pokemones.size() else null
	await Singleton.transicion("oscurecer")
	_sincronizar_y_liberar_pantalla_equipo()
	self.visible = false
	await Singleton.transicion("aclarar")
	en_transicion = false
	_cerrar_menu_para_accion_campo()
	if nodo_jugador == null:
		push_warning("[MENU PAUSA] Sin jugador: no se puede usar DESTELLO")
		return
	nodo_jugador.usar_destello(pokemon)

## FUERZA desde el menú del Pokémon (FieldCallback_PrepareFadeInFromMenu +
## S_UseStrength): se vuelve al campo, el Pokémon elegido sale, FUERZA queda activa
## y se muestra su mensaje. Simplificación: no se exige tener una roca delante.
func _usar_fuerza_desde_equipo(indice: int) -> void:
	en_transicion = true
	var pokemones: Array = pantalla_equipo_instancia.equipo_actual.pokemones
	var pokemon: BasePokemon = pokemones[indice] if indice >= 0 and indice < pokemones.size() else null
	await Singleton.transicion("oscurecer")
	_sincronizar_y_liberar_pantalla_equipo()
	self.visible = false
	await Singleton.transicion("aclarar")
	en_transicion = false
	_cerrar_menu_para_accion_campo()
	if nodo_jugador == null:
		push_warning("[MENU PAUSA] Sin jugador: no se puede usar FUERZA")
		return
	nodo_jugador.usar_fuerza(pokemon)

## GOLPE ROCA desde el menú del Pokémon (SetUpFieldMove_RockSmash): el menú ya
## comprobó que hay una roca rompible delante. Se vuelve al campo y se rompe esa
## roca directamente (S_UseRockSmash), sin pregunta ni mensaje.
func _usar_golpe_roca_desde_equipo(indice: int) -> void:
	en_transicion = true
	var pokemones: Array = pantalla_equipo_instancia.equipo_actual.pokemones
	var pokemon: BasePokemon = pokemones[indice] if indice >= 0 and indice < pokemones.size() else null
	await Singleton.transicion("oscurecer")
	_sincronizar_y_liberar_pantalla_equipo()
	self.visible = false
	await Singleton.transicion("aclarar")
	en_transicion = false
	_cerrar_menu_para_accion_campo()
	if nodo_jugador == null:
		push_warning("[MENU PAUSA] Sin jugador: no se puede usar GOLPE ROCA")
		return
	var roca := ControladorRocaRomper.roca_frente_jugador()
	if roca == null:
		return
	nodo_jugador.usar_golpe_roca(pokemon, roca, false)

## CORTE desde el menú del Pokémon (SetUpFieldMove_Cut + FieldCallback_CutTree /
## FieldCallback_CutGrass): el menú ya comprobó que hay un árbol cortable delante
## o hierba cortable en el cuadrado 3x3 del jugador. Se vuelve al campo y se corta
## ese árbol (DoCutFieldEffectScript) o la hierba (FLDEFF_USE_CUT_ON_GRASS)
## directamente, sin pregunta ni mensaje. El árbol tiene prioridad.
func _usar_corte_desde_equipo(indice: int) -> void:
	en_transicion = true
	var pokemones: Array = pantalla_equipo_instancia.equipo_actual.pokemones
	var pokemon: BasePokemon = pokemones[indice] if indice >= 0 and indice < pokemones.size() else null
	await Singleton.transicion("oscurecer")
	_sincronizar_y_liberar_pantalla_equipo()
	self.visible = false
	await Singleton.transicion("aclarar")
	en_transicion = false
	_cerrar_menu_para_accion_campo()
	if nodo_jugador == null:
		push_warning("[MENU PAUSA] Sin jugador: no se puede usar CORTE")
		return
	var arbol := ControladorArbolCortable.arbol_frente_jugador()
	if arbol != null:
		nodo_jugador.usar_corte(pokemon, arbol, false)
	elif HierbaCortableMapa.hierba_cortable_junto_al_jugador():
		nodo_jugador.usar_corte_hierba(pokemon, false)

## CASCADA desde el menú del Pokémon (SetUpFieldMove_Waterfall +
## FieldCallback_Waterfall): el menú ya comprobó que se surfea mirando al norte una
## cascada. Se vuelve al campo y el Pokémon elegido sube la cascada directamente,
## sin pregunta ni mensaje.
func _usar_cascada_desde_equipo(indice: int) -> void:
	en_transicion = true
	var pokemones: Array = pantalla_equipo_instancia.equipo_actual.pokemones
	var pokemon: BasePokemon = pokemones[indice] if indice >= 0 and indice < pokemones.size() else null
	await Singleton.transicion("oscurecer")
	_sincronizar_y_liberar_pantalla_equipo()
	self.visible = false
	await Singleton.transicion("aclarar")
	en_transicion = false
	_cerrar_menu_para_accion_campo()
	if nodo_jugador == null:
		push_warning("[MENU PAUSA] Sin jugador: no se puede usar CASCADA")
		return
	if not nodo_jugador.puede_usar_cascada():
		return
	nodo_jugador.usar_cascada(pokemon, false)

## BUCEO desde el menú del Pokémon (SetUpFieldMove_Dive + sub_808ADAC): se vuelve
## al campo y el Pokémon elegido bucea o emerge directamente, sin pregunta ni mensaje.
func _usar_buceo_desde_equipo(indice: int) -> void:
	en_transicion = true
	var pokemones: Array = pantalla_equipo_instancia.equipo_actual.pokemones
	var pokemon: BasePokemon = pokemones[indice] if indice >= 0 and indice < pokemones.size() else null
	await Singleton.transicion("oscurecer")
	_sincronizar_y_liberar_pantalla_equipo()
	self.visible = false
	await Singleton.transicion("aclarar")
	en_transicion = false
	_cerrar_menu_para_accion_campo()
	if nodo_jugador == null:
		push_warning("[MENU PAUSA] Sin jugador: no se puede usar BUCEO")
		return
	if not nodo_jugador.puede_usar_buceo():
		return
	nodo_jugador.usar_buceo(pokemon)

## DoSecretBase*FieldEffectScript: apertura directa con el Pokémon elegido,
## sin pregunta de uso ni UsedCutRockSmashText. Revalidar después de los fundidos.
func _usar_dano_secreto_desde_equipo(indice: int) -> void:
	var pokemones: Array = pantalla_equipo_instancia.equipo_actual.pokemones
	var pokemon: BasePokemon = pokemones[indice] if indice >= 0 and indice < pokemones.size() else null
	var entrada: EntradaBaseSecreta = AccesoDanoSecreto.entrada_frente(nodo_raiz)
	if entrada == null or not AccesoDanoSecreto.puede_usar(pokemon, nodo_raiz):
		pantalla_equipo_instancia.activo = true
		return
	var datos: EstructuraGuardado = SistemaGuardado.datos_vivos
	var sistema: SistemaBasesSecretas = SistemaGuardado.get_bases_secretas()
	var equipo_origen: Array = SistemaGuardado.get_equipo().duplicate()
	var mapa: MapaConfiguracion = nodo_raiz.get("mapa_actual") as MapaConfiguracion
	var jugador: Node2D = nodo_jugador
	var celda: Vector2i = mapa.global_to_map_cell(jugador.global_position)
	en_transicion = true
	await Singleton.transicion("oscurecer")
	# No resucitar un equipo reemplazado durante el fundido con la copia del menú.
	if SistemaGuardado.datos_vivos == datos and SistemaGuardado.get_equipo() == equipo_origen:
		_sincronizar_y_liberar_pantalla_equipo()
	else:
		pantalla_equipo_instancia.queue_free()
		pantalla_equipo_instancia = null
	self.visible = false
	await Singleton.transicion("aclarar")
	en_transicion = false
	ventana_activa = VentanaActiva.NINGUNA
	Singleton.mantener_pausa(&"menu", false)
	if is_instance_valid(jugador) and is_instance_valid(nodo_raiz) and int(nodo_raiz.get("coneccion")) == 0:
		jugador.set("no_control", false)
	if is_instance_valid(entrada) and is_instance_valid(mapa) and is_instance_valid(jugador) \
		and SistemaGuardado.datos_vivos == datos and SistemaGuardado.get_bases_secretas() == sistema \
		and nodo_raiz.get("mapa_actual") == mapa and nodo_raiz.get("jugador") == jugador \
		and mapa.global_to_map_cell(jugador.global_position) == celda:
		entrada.usar_desde_equipo(pokemon, nodo_raiz)


## TELETRANSPORTE desde el menú del Pokémon (SetUpFieldMove_Teleport): se vuelve
## al campo y el jugador se teletransporta al último punto de curación.
func _usar_teletransporte_desde_equipo(indice: int) -> void:
	en_transicion = true
	var pokemones: Array = pantalla_equipo_instancia.equipo_actual.pokemones
	var pokemon: BasePokemon = pokemones[indice] if indice >= 0 and indice < pokemones.size() else null
	await Singleton.transicion("oscurecer")
	_sincronizar_y_liberar_pantalla_equipo()
	self.visible = false
	await Singleton.transicion("aclarar")
	en_transicion = false
	_cerrar_menu_para_accion_campo()
	if nodo_jugador == null:
		push_warning("[MENU PAUSA] Sin jugador: no se puede usar TELETRANSPORTE")
		return
	nodo_jugador.usar_teletransporte(pokemon)

## EXCAVAR desde el menú del Pokémon (SetUpFieldMove_Dig): se vuelve al campo y
## el jugador sale de la cueva a la entrada exterior guardada, sin mensaje.
func _usar_excavar_desde_equipo(indice: int) -> void:
	en_transicion = true
	var pokemones: Array = pantalla_equipo_instancia.equipo_actual.pokemones
	var pokemon: BasePokemon = pokemones[indice] if indice >= 0 and indice < pokemones.size() else null
	await Singleton.transicion("oscurecer")
	_sincronizar_y_liberar_pantalla_equipo()
	self.visible = false
	await Singleton.transicion("aclarar")
	en_transicion = false
	_cerrar_menu_para_accion_campo()
	if nodo_jugador == null:
		push_warning("[MENU PAUSA] Sin jugador: no se puede usar EXCAVAR")
		return
	nodo_jugador.usar_excavar(pokemon)

## Destino elegido: se cierra todo y el jugador vuela. La pausa del menú se
## suelta justo antes de volar() (que toma su propia pausa &"vuelo") para que
## el jugador no pueda moverse mientras se aclara la pantalla.
func _on_destino_vuelo_elegido(destino: Dictionary) -> void:
	if en_transicion:
		return
	en_transicion = true
	await Singleton.transicion("oscurecer")
	if is_instance_valid(instancia_mapa_region):
		instancia_mapa_region.queue_free()
	instancia_mapa_region = null
	var pokemon: BasePokemon = _pokemon_vuelo
	_pokemon_vuelo = null
	self.visible = false
	await Singleton.transicion("aclarar")
	en_transicion = false
	_cerrar_menu_para_accion_campo()
	if nodo_jugador == null:
		push_warning("[MENU PAUSA] Sin jugador: no se puede usar VUELO")
		return
	var celda: Vector2 = destino.get("celda", Vector2.ZERO)
	nodo_jugador.volar(pokemon, str(destino.get("mapa", "")), celda)

## B en el mapa de VUELO: como en GBA, se vuelve a la pantalla de equipo con
## el cursor sobre el Pokémon que iba a usar VUELO.
func _on_mapa_region_vuelo_cerrado() -> void:
	if en_transicion:
		return
	en_transicion = true
	_pokemon_vuelo = null
	await Singleton.transicion("oscurecer")
	if is_instance_valid(instancia_mapa_region):
		instancia_mapa_region.queue_free()
	instancia_mapa_region = null
	en_transicion = false
	await mostrar_pantalla_equipo(_indice_vuelo)

# FUNCIÓN PARA EJECUTAR GUARDADO
## Esta función inicia el nuevo sistema de guardado simplificado,
## que muestra un cuadro de diálogo de confirmación en lugar de guardar inmediatamente.
func confirmar_guardado():
	print("💾 [MENU] Iniciando confirmación de guardado con sistema simplificado")

	# Cambiar estado y ocultar menú
	en_transicion = true
	visible = false
	ventana_activa = VentanaActiva.V_GUARDAR

	# Crear instancia del nuevo sistema de guardado
	var guardado_simple = load("res://UI/guardar/confirmacion_guardado.gd")
	var instancia_guardado = guardado_simple.new()

	# Conectar señal de resultado
	instancia_guardado.connect("guardado_completado", Callable(self, "_on_guardado_completado"))

	# Añadir a la escena
	if nodo_menu == null:
		nodo_menu = get_tree().root.get_node("AdministradorMapa/Menu")

	if nodo_menu:
		nodo_menu.add_child(instancia_guardado)
		# Iniciar el flujo de confirmación (muestra el cuadro de diálogo y conecta comandos)
		if instancia_guardado.has_method("iniciar"):
			instancia_guardado.iniciar()
	else:
		print("❌ [MENU] No se encontró el nodo Menu")

## Callback para cuando el sistema de guardado simplificado termina su proceso
func _on_guardado_completado(acepta: bool):
	print("💾 [MENU] Guardado completado. Acepta: ", acepta)


	if acepta:
		# Si guardó: NO volver al menú (estado NINGUNA)
		print("💾 [MENU] Guardado exitoso - cerrando menú completamente")
		ventana_activa = VentanaActiva.NINGUNA
		Singleton.mantener_pausa(&"menu", false)
		en_transicion = false
	else:
		# Si canceló: SI volver al menú pausa
		print("💾 [MENU] Guardado cancelado - volviendo al menú pausa")
		visible = true
		ventana_activa = VentanaActiva.V_MENU
		cooldown_input_menu = 10  # Cooldown para evitar cierre inmediato
		Singleton.mantener_pausa(&"menu", true)
		en_transicion = false

func _logear(tag: String) -> void:
	print("🔄 [MENU PAUSE] → %s" % tag)
