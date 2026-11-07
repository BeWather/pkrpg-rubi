extends Node2D
class_name MochilaUI

signal mochila_cerrada
signal objeto_seleccionado_venta(objeto_datos: Dictionary)
## Emitida en modo_selector al confirmar un objeto (distinto de CERRAR).
signal objeto_seleccionado_selector(objeto_datos: Dictionary)
## Emitida en modo_batalla cuando el jugador confirma USAR sobre un objeto usable.
signal objeto_listo_para_usar(item: Dictionary)

# Referencias a nodos de la escena (se cargarán selectivamente en _ready)
@onready var nd_marcador = $"marcador"
@onready var nd_pokeball = $"Pokeball"
@onready var lb_descripcion = $descripcion
@onready var nd_bolsillos = $"clipper/Bolsillos"
@onready var nd_lista = $"fondo-lista"
@onready var nd_flecha_izquierda = $"flecha-izquierda"
@onready var nd_flecha_derecha = $"flecha-derecha"
@onready var nd_flecha_arriba = $"flecha-arriba"
@onready var nd_flecha_abajo = $"flecha-abajo"
@onready var nd_cursor = $"cursor"
@onready var nd_lista_mostrada = $"fondo-lista" # Tiene de hijo los 8 RichTextLabels para los objetos

 # Sistema de navegación
var bolsillo_actual: int = 0  # 0 = Objetos, 1 = Poké Balls, 2 = MT/MO, 3 = Bayas, 4 = Obj. Clave
var item_actual: Dictionary = Singleton.mochila_item_actual  # Diccionario: bolsillo -> índice seleccionado
var offset_lista: Dictionary = Singleton.mochila_offset_lista # Diccionario: bolsillo -> offset scroll
var posicion_cursor_base = Vector2(0, 0) # (111, 15)
var posicion_marcador = Vector2(0, 0) # (42, 75)
var posicion_mochila = Vector2(0, 0)
var posicion_cinta_nombres = Vector2(0, 0)
var salto_cursor = 16
var disenio_chica: bool = true

# Variables para modo venta
var modo_venta: bool = false
var controlador_venta: Node = null
var input_bloqueado: bool = false  # Para bloquear input cuando se selecciona cantidad en venta

# Variables para modo selector (abrir la mochila para elegir un objeto)
var modo_selector: bool = false
var bolsillo_selector: int = -1  # Índice del bolsillo inicial. -1 = libre
var modo_selector_bolsillo_fijo: bool = false  # true = no se puede cambiar de bolsillo
var modo_selector_solo_llevables: bool = false  # true = rechaza objetos clave y MO (DAR desde el equipo)
## DEJAR OBJETO del PC (OnItemSelect_PC): la cantidad y el resultado se
## resuelven dentro de la mochila, que sigue abierta hasta pulsar B.
var modo_depositar_pc: bool = false

# Variables para modo batalla
var modo_batalla: bool = false
var _func_oscurecer: Callable = Callable()

# Submenú contextual del objeto (batalla: USAR/SALIR; campo: rejilla por bolsillo).
# Las opciones se colocan por columnas de `submenu_filas` filas; "" es un hueco
# vacío que no se dibuja ni se puede seleccionar (ITEM_ACTION_NONE de pokeruby).
var submenu: NinePatchRect = null
var submenu_opciones: Array[String] = []
var submenu_filas: int = 1
var submenu_indice: int = 0
var submenu_item_activo: Dictionary = {}
var _submenu_celdas: Array[Rect2] = []  # Rect del cursor de cada opción (relativo al marco)
## true mientras la caja de diálogo muestra un mensaje de uso en el campo: la
## mochila no consume el input para que lo reciba la caja.
var _esperando_mensaje_campo: bool = false
## Acción que debe ejecutarse en el mapa tras cerrar la mochila y el menú de
## pausa (USAR sobre una parcela de bayas: ItemUseOnFieldCB_* de pokeruby).
## La lee menu_pausa.gd al recibir mochila_cerrada.
var accion_campo_pendiente: Callable = Callable()

## Resaltado del objeto del que sale el menú contextual (pokeruby
## sub_80A425C: gTasks[taskId].data[10] → fila impresa con TEXT_COLOR_RED):
## mientras está activo la fila seleccionada se dibuja en rojo y el cursor
## rectangular de la lista se oculta.
var _resaltado_activo: bool = false
## Índice del objeto marcado con SELECT para cambiarlo de sitio (-1 = ninguno).
## Se dibuja en rojo como el resaltado, pero el cursor de la lista sigue visible.
var _indice_intercambio: int = -1
## Rojo del texto resaltado (GBA 0xF86058, mismo que el cursor) y su sombra.
const COLOR_TEXTO_RESALTADO: Color = Color(0.973, 0.376, 0.345)
const COLOR_SOMBRA_RESALTADO: Color = Color(0.973, 0.722, 0.690)
## Mismo estilo que TEXTO_NORMAL_NEGRO en rojo (para la cantidad de la fila).
const TEXTO_NORMAL_ROJO: LabelSettings = preload("res://UI/texto_normal_rojo.tres")

## Sub-flujos del menú contextual del campo que ocurren dentro de la mochila.
enum Flujo {
	NINGUNO,
	TIRAR_CANTIDAD,   ## Eligiendo cuántos tirar (ventana ×NN).
	TIRAR_CONFIRMAR,  ## SÍ/NO de "¿Seguro que quieres tirar...?".
	TIRAR_HECHO,      ## "Has tirado..." esperando A o B.
	DEPOSITAR_CANTIDAD, ## PC: eligiendo cuántos dejar (ventana ×NN).
	DEPOSITAR_HECHO,  ## PC: resultado de dejar esperando A o B.
	DAR_EQUIPO,       ## Pantalla de equipo abierta en modo DAR_OBJETO.
	USAR_EQUIPO,      ## Pantalla de equipo abierta en modo USAR_OBJETO (medicina).
	VER_FICHA,        ## Ficha de la baya abierta (VER FICHA).
	ESTUCHE_POKECUBOS, ## CAJA POKéCUBOS abierta (PantallaEstuchePokecubos).
	CARTA,            ## CARTA abierta (PantallaCarta).
}
var flujo: Flujo = Flujo.NINGUNO
var _item_flujo: Dictionary = {}
## Cantidad elegida en la ventana de TIRAR.
var cantidad_tirar: int = 1
var _ventana_cantidad: NinePatchRect = null
var _lb_cantidad_tirar: Label = null
var _pantalla_equipo: PantallaEquipoControlador = null
## Activación de una MT/MO (ItemUseOutOfBattle_TMHM) en curso, con su sesión.
var _dialogo_maquina: DialogoBaseSecreta
var _partida_maquina: EstructuraGuardado
var _sesion_maquina: int = 0
var _contexto_activacion_maquina: Dictionary = {}
const PAUSA_ACTIVACION_MAQUINA: StringName = &"activacion_maquina"
var _ficha_baya: FichaBaya = null
var _estuche_pokecubos: PantallaEstuchePokecubos = null
var _pantalla_carta: PantallaCarta = null
var _icono_sel: Sprite2D = null
## Ventana de cantidad de TIRAR: sub_80A4DD8(7, 9, 6, 3) → marco de 7x4 tiles
## en el tile (7,9); en Bayas (6, 9, 7, 3) → 8x4 tiles en el tile (6,9).
const RECT_VENTANA_CANTIDAD: Rect2 = Rect2(56, 72, 56, 32)
const RECT_VENTANA_CANTIDAD_BAYAS: Rect2 = Rect2(48, 72, 64, 32)
## El número se imprime en el tile (b+2, c+1) → 2 tiles a la derecha y 1 abajo.
const POS_TEXTO_CANTIDAD: Vector2 = Vector2(16, 8)
## SÍ/NO de TIRAR: DisplayYesNoMenu(7, 7) → marco de 7x6 tiles en el tile (7,7).
const POS_SI_NO_TIRAR: Vector2 = Vector2(56, 56)
const RUTA_PANTALLA_EQUIPO: String = "res://UI/equipo/pantalla-equipo.tscn"
const RUTA_FICHA_BAYA: String = "res://UI/ficha-baya/ficha_baya.tscn"
const RUTA_ESTUCHE_POKECUBOS: String = "res://UI/pokecubos/pantalla_estuche_pokecubos.tscn"
const RUTA_PANTALLA_CARTA: String = "res://UI/cartas/pantalla_carta.tscn"
## Icono SEL del objeto registrado (pokeruby bag_screen.png, tiles 0x5A-0x6C).
const ICONO_SEL: Texture2D = preload("res://UI/mochila/icono_sel.png")
## Posición del icono en la 1.ª fila (tile (26,2) de BG2); cada fila baja 16 px.
const POS_ICONO_SEL: Vector2 = Vector2(208, 16)

const SUBMENU_LINEA_H: int = 16
## Estilo estándar de texto de 15 px (fuente pokemon-rs, gris oscuro).
const TEXTO_NORMAL_NEGRO: LabelSettings = preload("res://UI/texto_normal_negro.tres")
## Tamaño de tile del marco (menu_box_N.png es de 24x24 → márgenes de 8 px).
const SUBMENU_TILE: int = 8
## Ancho de cada columna del menú de campo (6 tiles, como en Ruby).
const SUBMENU_COLUMNA_W: int = 48
## Desplazamiento del texto respecto al origen de su celda (el cursor
## rectangular ocupa la celda completa, 1 px por fuera del texto).
const SUBMENU_TEXTO_OFFSET: Vector2 = Vector2(1, 1)
const OPC_USAR: String = "USAR"
const OPC_TIRAR: String = "TIRAR"
const OPC_DAR: String = "DAR"
const OPC_SALIR: String = "SALIR"
const OPC_REGISTRAR: String = "ASIGNAR"
const OPC_VER_ETIQ: String = "VER FICHA"
## Opciones del menú contextual fuera de combate por bolsillo (0-based), en el
## mismo orden que sItemPopupMenuChoicesTable de pokeruby (src/item_menu.c).
## Con 4 opciones hay 2 filas por columna; con 6, 3 filas.
const OPCIONES_CAMPO_POR_BOLSILLO: Array = [
	[OPC_USAR, OPC_TIRAR, OPC_DAR, OPC_SALIR],                  # 0 Objetos
	[OPC_DAR, OPC_TIRAR, "", OPC_SALIR],                        # 1 Poké Balls
	[OPC_USAR, "", OPC_DAR, OPC_SALIR],                         # 2 MT/MO
	[OPC_VER_ETIQ, OPC_USAR, OPC_TIRAR, "", OPC_DAR, OPC_SALIR],  # 3 Bayas
	[OPC_USAR, "", OPC_REGISTRAR, OPC_SALIR],                   # 4 Obj. clave
]

# (Cooldown eliminado: el bloqueo se maneja desde vender.gd)

var fondo: Sprite2D = null  # Referencia al fondo de la mochila
var mochila: AnimatedSprite2D = null  # Referencia a la mochila animada
var pokeball_tween: Tween = null
var animando_cambio_bolsillo: bool = false

var nav_vertical_timer: Timer = null
var nav_vertical_direccion: int = 0
var nav_vertical_phase: int = 0 # 0: nada, 1: delay inicial, 2: repetición
const NAV_VERTICAL_INTERVAL := 0.2
const NAV_VERTICAL_INITIAL_DELAY := 0.35
const NAV_VERTICAL_REPEAT_INTERVAL := 0.08
const TXT_CERRAR: String = "CERRAR LA MOCHILA"
const COLOR_CHICA = Color(0.408, 0.69, 0.816)
const COLOR_CHICO = Color(0.973, 0.376, 0.345)
const DURACION_CAMBIO_BOLSILLO : float = 0.12
const DURACION_ROTACION : float = 0.4

# Crear transición de pantalla negra a transparente
var transicion_opacidad := 1.0
var transicion_activa := false
var transicion_velocidad := 1.5 # segundos para aclarar

# Diccionario para las listas de objetos de los bolsillos
var bolsillos_datos = {}
var nombres_bolsillos

func _ready():
	# Crear timer para navegación vertical continua
	nav_vertical_timer = Timer.new()
	nav_vertical_timer.wait_time = NAV_VERTICAL_INITIAL_DELAY
	nav_vertical_timer.one_shot = true
	nav_vertical_timer.autostart = false
	add_child(nav_vertical_timer)
	nav_vertical_timer.connect("timeout", Callable(self, "_on_nav_vertical_timeout"))

	# (Timer de cooldown eliminado)

	# Si la escena se está ejecutando como escena principal (no instanciada), escalar x4
	# Esto detecta si este nodo es la escena actual cargada en el SceneTree.
	if get_tree() != null and get_tree().get_current_scene() == self:
		scale = Vector2(4, 4)

	posicion_cursor_base = nd_cursor.position
	posicion_marcador = nd_marcador.position
	posicion_cinta_nombres = nd_bolsillos.position

	# Abrir en el último bolsillo visto (memoria compartida en runtime entre
	# batalla y fuera de batalla). activar_modo_selector() lo sobreescribe si
	# el contexto exige un bolsillo específico (tienda, bayas, etc.).
	bolsillo_actual = Singleton.mochila_ultimo_bolsillo
	nd_bolsillos.position = posicion_cinta_nombres + Vector2(bolsillo_actual * -76, 0)

	inicializar_mochila()

	mochila.frame = 0
	actualizar_contenido_bolsillo(false)
	actualizar_posicion_cursor()
	actualizar_descripcion()
	Singleton.transicion("aclarar")

func inicializar_mochila():
	# Cargar datos desde el sistema de guardado
	cargar_datos_desde_guardado()

	# Configurar los nombres de los bolsillos
	nombres_bolsillos = DatabaseManager.obtener_nombres_bolsillos()

	# Asignar de forma segura los nombres a los nodos hijos (puede haber menos nodos)
	for i in range(nombres_bolsillos.size()):
		if i >= nd_bolsillos.get_child_count():
			break
		nd_bolsillos.get_child(i).text = nombres_bolsillos[i].nombre

	# Cargar los nodos de fondo y mochila correspondientes al género
	var sexo = SistemaGuardado.datos_vivos.jugador.sexo
	if sexo and sexo == "F":
		disenio_chica = true
		if has_node("Fe-fondo"):
			fondo = get_node("Fe-fondo")
		if has_node("mochila-chica"):
			mochila = get_node("mochila-chica")
	else:
		disenio_chica = false
		if has_node("Ma-fondo"):
			fondo = get_node("Ma-fondo")
		if has_node("mochila-chico"):
			mochila = get_node("mochila-chico")
	posicion_mochila = mochila.position

	fondo.visible = true
	mochila.visible = true

	# Configurar el marcador y el cursor
	nd_marcador.position = posicion_marcador
	if disenio_chica:
		nd_marcador.color = COLOR_CHICA
	else:
		nd_marcador.color = COLOR_CHICO
	nd_marcador.visible = true
	nd_cursor.position = posicion_cursor_base

	# Inicializar la animación de las 4 flechas y posicionarlas en el frame 0
	nd_flecha_abajo.frame = 0
	nd_flecha_arriba.frame = 0
	nd_flecha_izquierda.frame = 0
	nd_flecha_derecha.frame = 0
	nd_flecha_abajo.play("default")
	nd_flecha_arriba.play("default")
	nd_flecha_izquierda.play("default")
	nd_flecha_derecha.play("default")
	nd_flecha_abajo.visible = true
	nd_flecha_arriba.visible = true
	nd_flecha_izquierda.visible = true
	nd_flecha_derecha.visible = true

## Carga los datos de la mochila desde el sistema de guardado
func cargar_datos_desde_guardado():
	print("[MOCHILA] 🔄 Cargando datos desde sistema de guardado...")

	if SistemaGuardado:
		# Ruby ordena MT/MO y Bayas cada vez que se abre la mochila.
		SistemaGuardado.ordenar_bolsillos_automaticos()
		var inventario = SistemaGuardado.get_inventario()
		print("[MOCHILA] 📦 Inventario cargado con %d bolsillos" % inventario.get("bolsillos", {}).size())

		# Cargar los bolsillos
		if inventario.has("bolsillos"):
			for bolsillo_key in inventario.bolsillos.keys():
				var bolsillo_int = int(bolsillo_key)
				var bolsillo_datos = inventario.bolsillos[bolsillo_key]

				# Actualizar la estructura de bolsillos_datos
				if not bolsillos_datos.has(bolsillo_int):
					bolsillos_datos[bolsillo_int] = {"items": []}

				# Copiar los items del guardado
				var items_cargados = []
				for item in bolsillo_datos.items:
					items_cargados.append(item.duplicate())

				# Añadir el item de "CERRAR LA MOCHILA" al final
				items_cargados.append({
					"nombre": "CERRAR LA MOCHILA",
					"icono": "",
					"descripcion": "Volver al juego.",
					"cantidad": 0
				})

				bolsillos_datos[bolsillo_int].items = items_cargados

		print("[MOCHILA] ✅ Datos cargados exitosamente")
	else:
		print("[MOCHILA] ⚠️ SistemaGuardado no disponible, usando datos por defecto")

## Activa el modo selector: fija el bolsillo indicado y bloquea el cambio de bolsillo.
## Al seleccionar un objeto (que no sea CERRAR) se emite objeto_seleccionado_selector y se cierra.
## descripcion_cerrar: descripción contextual del ítem "CERRAR LA MOCHILA" (varía
## según desde dónde se abre: batalla, pausa, etc.).
## bolsillo_fijo: si true, el jugador no puede cambiar de bolsillo (útil en tiendas/bayas).
##               Si false (default), puede navegar libremente entre bolsillos.
func activar_modo_selector(bolsillo: int, descripcion_cerrar: String = "Cerrar.", bolsillo_fijo: bool = false) -> void:
	modo_selector = true
	modo_selector_bolsillo_fijo = bolsillo_fijo
	bolsillo_selector = bolsillo
	bolsillo_actual = bolsillo
	# Posicionar la cinta de nombres al bolsillo correcto sin animación.
	nd_bolsillos.position = posicion_cinta_nombres + Vector2(bolsillo_actual * -76, 0)
	# Solo ocultar las flechas de navegación cuando el bolsillo está fijo.
	nd_flecha_izquierda.visible = not bolsillo_fijo
	nd_flecha_derecha.visible = not bolsillo_fijo
	# Actualizar la descripción de CERRAR LA MOCHILA en todos los bolsillos.
	for b_key in bolsillos_datos.keys():
		for item in bolsillos_datos[b_key].items:
			if item.get("nombre", "") == TXT_CERRAR:
				item["descripcion"] = descripcion_cerrar
				break
	actualizar_contenido_bolsillo(false)
	actualizar_posicion_cursor()
	actualizar_descripcion()

## Abre la mochila desde OBJETO > DAR de la pantalla de equipo
## (OnItemSelect_PkmnList de item_menu.c): bolsillos libres; un objeto que no
## se puede llevar muestra "no se puede llevar" y la mochila sigue abierta.
func activar_modo_dar_equipo() -> void:
	modo_selector_solo_llevables = true
	activar_modo_selector(Singleton.mochila_ultimo_bolsillo,
		FormateadorLigaduras.formatear(tr("EQUIPO_MOCHILA_CERRAR")))

## Abre la mochila en contexto de batalla: navegación libre de bolsillos, submenu
## contextual por objeto (USAR/SALIR o solo SALIR), y señal objeto_listo_para_usar.
func activar_modo_batalla(func_oscurecer: Callable = Callable()) -> void:
	modo_batalla = true
	_func_oscurecer = func_oscurecer
	activar_modo_selector(Singleton.mochila_ultimo_bolsillo, "Volver al\ncombate.")

## Configura la mochila para modo venta
func configurar_modo_venta(activar: bool, controlador: Node = null):
	print("[MOCHILA] 🔄 Configurando modo venta: %s" % activar)

	modo_venta = activar
	controlador_venta = controlador

	if modo_venta:
		print("[MOCHILA] 💰 Modo venta activado")
		# Cambiar descripción del texto de cerrar
		_actualizar_textos_modo_venta()
	else:
		print("[MOCHILA] 🎒 Modo normal activado")

## Actualiza los textos cuando está en modo venta
func _actualizar_textos_modo_venta():
	# Cambiar el texto de "CERRAR LA MOCHILA" por algo más apropiado para venta
	for bolsillo_key in bolsillos_datos.keys():
		var items = bolsillos_datos[bolsillo_key].items
		for item in items:
			if item.nombre == "CERRAR LA MOCHILA":
				# item.nombre = "CERRAR LA MOCHILA"
				item.descripcion = "Volver\\la la tienda."
				break

func _formatear_cantidad(cant: int, width: int) -> String:
	# width: 0 = no mostrar, else cantidad de posiciones a reservar (ej: 2,3)
	match width:
		0:
			return ""
		1:
			return "x%01s" % cant
		2:
			return "x%02s" % cant
		3:
			return "x%03s" % cant
		_:
			return "x%04s" % cant
	# TODO: Definitivamente nos falta la fuente del Pokémon Rubí en formato monospace

# Actualiza el contenido de los RichTextLabel con los items del bolsillo actual
func actualizar_contenido_bolsillo(animado: bool = false):
	limpiar_lista()
	nd_marcador.position = posicion_marcador + Vector2(bolsillo_actual * 8, 0)
	if animado:
		nd_lista.scale.y = 0.0

	var bolsillo = bolsillos_datos[bolsillo_actual]
	var etiquetas = []
	for i in range(nd_lista.get_child_count()):
		etiquetas.append(nd_lista.get_child(i))

	var slots_disponibles = min(8, etiquetas.size())

	# Inicializar si no existe
	if not item_actual.has(bolsillo_actual):
		item_actual[bolsillo_actual] = 0
	if not offset_lista.has(bolsillo_actual):
		offset_lista[bolsillo_actual] = 0

	# Limitar valores: la memoria puede venir de una lista más larga (sub_80A362C)
	_ajustar_cursor_bolsillo(bolsillo_actual)

	for i in range(slots_disponibles):
		var slot = etiquetas[i]
		if not (slot is RichTextLabel):
			continue

		var item_index = offset_lista[bolsillo_actual] + i
		if item_index < bolsillo.items.size():
			var item = bolsillo.items[item_index]
			var nombre = item["nombre"]
			var cantidad = item["cantidad"] if item.has("cantidad") else 0
			var icono_texto = ""
			if item.has("icono"):
				icono_texto = str(item["icono"])

			# Para MO/MT en el bolsillo MT/MO (bolsillo 2), usar la función del database_manager
			var texto_mostrar = nombre
			var es_mo = false

			if bolsillo_actual == 2:
				# Verificar si tiene nombre_interno para usar obtener_info_maquina
				if item.has("nombre_interno"):
					var nombre_interno = item["nombre_interno"]
					var info_maquina = DatabaseManager.obtener_info_maquina(nombre_interno)
					if info_maquina != "":
						texto_mostrar = info_maquina
						# Si contiene la imagen MO, es un MO
						if info_maquina.contains("txt_mo.png"):
							es_mo = true
					else:
						# Si no se pudo obtener info de la máquina, usar el nombre normal
						texto_mostrar = icono_texto + nombre
				else:
					# Fallback: Si ya tiene el icono MO, es un MO
					if icono_texto.contains("txt_mo.png"):
						es_mo = true
						texto_mostrar = icono_texto + nombre
					else:
						texto_mostrar = icono_texto + nombre
			else:
				# Para otros bolsillos, usar el formato normal
				texto_mostrar = icono_texto + nombre

			slot.text = FormateadorLigaduras.formatear(texto_mostrar)
			slot.visible = true

			# Obtener cifras desde Singleton.MOCHILA_CONFIG
			var cifras = 0
			if bolsillo_actual < nombres_bolsillos.size():
				cifras = int(nombres_bolsillos[bolsillo_actual].cifras)

			if slot.has_node("cantidad"):
				var nd_cant = slot.get_node("cantidad")
				if nd_cant is Label:
					var es_opcion_especial: bool = nombre in [TXT_CERRAR, "CANCELAR VENTA"]
					if not es_opcion_especial and cifras > 0 and not es_mo:
						nd_cant.text = _formatear_cantidad(cantidad, cifras)
						nd_cant.visible = true
					else:
						nd_cant.visible = false

	# Las filas se reescriben: volver a aplicar (o limpiar) el resaltado rojo.
	_aplicar_resaltado()

	_actualizar_icono_sel()

	# Animación de la expansión de la lista
	if animado:
		animacion_listado()
		animacion_cinta_nombre()

func limpiar_lista():
	for slot in nd_lista.get_children():
		if slot is RichTextLabel:
			slot.text = ""
			slot.visible = false
			if slot.has_node("cantidad"):
				var nd_cant = slot.get_node("cantidad")
				if nd_cant is Label:
					nd_cant.text = ""
					nd_cant.visible = false

func animacion_listado():
	# Animar la expansión de la lista
	var lista_tween = create_tween()
	lista_tween.tween_property(nd_lista, "scale:y", 1.0, DURACION_CAMBIO_BOLSILLO).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func animacion_cinta_nombre():
	# Animar la cinta de nombres de los bolsillos
	var cinta_tween = create_tween()
	cinta_tween.tween_property(nd_bolsillos, "position", posicion_cinta_nombres + Vector2(bolsillo_actual * -76, 0), DURACION_ROTACION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# Actualiza la posición del cursor basado en la selección actual
func actualizar_posicion_cursor():
	var posicion_visual = item_actual[bolsillo_actual] - offset_lista[bolsillo_actual]
	nd_cursor.position = posicion_cursor_base + Vector2(0, posicion_visual * salto_cursor)
	_aplicar_resaltado()
	if offset_lista[bolsillo_actual] == 0:
		nd_flecha_arriba.visible = false
	else:
		nd_flecha_arriba.visible = true
	if offset_lista[bolsillo_actual] >= bolsillos_datos[bolsillo_actual].items.size() - 8:
		nd_flecha_abajo.visible = false
	else:
		nd_flecha_abajo.visible = true

# Actualiza la descripción del item seleccionado
func actualizar_descripcion():
	if _indice_intercambio >= 0:
		lb_descripcion.text = FormateadorLigaduras.formatear(tr("MOCHILA_CAMBIAR_CON_QUE"))
		return
	var bolsillo = bolsillos_datos[bolsillo_actual]
	if item_actual.has(bolsillo_actual) and item_actual[bolsillo_actual] < bolsillo.items.size():
		var item = bolsillo.items[item_actual[bolsillo_actual]]
		var descripcion: String = ""
		var descripcion_objeto = item.get("descripcion", "")

		# Para MT/MO en el bolsillo MT/MO (bolsillo 2), usar descripción del movimiento
		if bolsillo_actual == 2 and item.has("nombre_interno"):
			var nombre_interno = item["nombre_interno"]
			var descripcion_movimiento = DatabaseManager.obtener_descripcion_maquina(nombre_interno)
			if descripcion_movimiento is String and not descripcion_movimiento.strip_edges().is_empty():
				descripcion = descripcion_movimiento
			elif descripcion_objeto is String and not descripcion_objeto.strip_edges().is_empty():
				# Fallback a la descripción original del objeto
				descripcion = descripcion_objeto
		elif descripcion_objeto is String and not descripcion_objeto.strip_edges().is_empty():
			# Para otros bolsillos o items sin nombre_interno, usar descripción normal
			descripcion = descripcion_objeto

		if descripcion.is_empty():
			var identificador := str(item.get("nombre_interno", item.get("nombre", "este objeto")))
			if bolsillo_actual == 2:
				descripcion = "Falta descripción de %s en la BD (Movimientos / Objetos)." % identificador
			else:
				descripcion = "Falta descripción de %s en la BD (Objetos.descripcion)." % identificador

		lb_descripcion.text = FormateadorLigaduras.formatear(descripcion)
	else:
		lb_descripcion.text = ""

# Manejo de entrada para navegación
func _input(event):
	# Mensaje de uso en el campo abierto: el input es de la caja de diálogo
	# (no marcarlo como manejado o la caja, anterior en el árbol, no lo recibe).
	if _esperando_mensaje_campo:
		return

	# Activación de MT/MO: la caja y el SÍ/NO del diálogo leen el input (la
	# caja es anterior en el árbol), así que la mochila no debe consumirlo.
	if _dialogo_maquina != null:
		return

	# Sub-flujos de TIRAR/DAR. El SÍ/NO (hijo) y la pantalla de equipo (hermano
	# posterior) reciben el evento antes que la mochila y leen Input.
	if flujo != Flujo.NINGUNO:
		_input_flujo(event)
		get_viewport().set_input_as_handled()
		return

	# El submenú contextual captura el input cuando está activo.
	if submenu != null:
		if event.is_action_pressed("btn_arriba"):
			_mover_cursor_submenu(-1, 0)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("btn_abajo"):
			_mover_cursor_submenu(1, 0)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("btn_izquierda"):
			_mover_cursor_submenu(0, -1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("btn_derecha"):
			_mover_cursor_submenu(0, 1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("btn_accion"):
			_confirmar_submenu()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("btn_cancelar"):
			if not modo_batalla:
				Singleton.emit_signal("play_sound", "cursor_menu")
			_destruir_submenu()
			input_bloqueado = false
			_activar_resaltado(false)
			actualizar_descripcion()
			get_viewport().set_input_as_handled()
		return

	if animando_cambio_bolsillo or input_bloqueado:
		# En venta el bloqueo cede el input a vender.gd y al cuadro de diálogo
		# (anteriores en el árbol): selector de cantidad y mensajes.
		if animando_cambio_bolsillo or not modo_venta:
			get_viewport().set_input_as_handled()
		return

	# Navegación vertical continua mejorada
	if event.is_action_pressed("btn_arriba"):
		if nav_vertical_direccion != -1:
			navegar_vertical(-1)
			nav_vertical_direccion = -1
			nav_vertical_phase = 1
			nav_vertical_timer.wait_time = NAV_VERTICAL_INITIAL_DELAY
			nav_vertical_timer.start()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("btn_abajo"):
		if nav_vertical_direccion != 1:
			navegar_vertical(1)
			nav_vertical_direccion = 1
			nav_vertical_phase = 1
			nav_vertical_timer.wait_time = NAV_VERTICAL_INITIAL_DELAY
			nav_vertical_timer.start()
		get_viewport().set_input_as_handled()
	elif event.is_action_released("btn_arriba") and nav_vertical_direccion == -1:
		nav_vertical_timer.stop()
		nav_vertical_direccion = 0
		nav_vertical_phase = 0
		get_viewport().set_input_as_handled()
	elif event.is_action_released("btn_abajo") and nav_vertical_direccion == 1:
		nav_vertical_timer.stop()
		nav_vertical_direccion = 0
		nav_vertical_phase = 0
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("btn_izquierda"):
		# Mientras se cambia un objeto de sitio no se cambia de bolsillo.
		if _indice_intercambio < 0:
			cambiar_bolsillo(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("btn_derecha"):
		if _indice_intercambio < 0:
			cambiar_bolsillo(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("btn_select"):
		_pulsar_select()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("btn_accion"):
		if _indice_intercambio >= 0:
			_confirmar_intercambio()
		else:
			seleccionar_item()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("btn_cancelar"):
		if _indice_intercambio >= 0:
			_cancelar_intercambio()
		else:
			cerrar_mochila()
		get_viewport().set_input_as_handled()

func _on_nav_vertical_timeout():
	# Con el submenú o un sub-flujo abiertos el soltar la tecla no llega a la
	# lista: cortar la repetición para que no se mueva la fila resaltada.
	if input_bloqueado or submenu != null or flujo != Flujo.NINGUNO:
		nav_vertical_timer.stop()
		nav_vertical_direccion = 0
		nav_vertical_phase = 0
		return
	if nav_vertical_direccion != 0:
		navegar_vertical(nav_vertical_direccion)
		if nav_vertical_phase == 1:
			nav_vertical_phase = 2
			nav_vertical_timer.wait_time = NAV_VERTICAL_REPEAT_INTERVAL
		nav_vertical_timer.start()

# (_on_cooldown_timeout eliminado)

# Navegación vertical dentro del bolsillo
func navegar_vertical(direccion: int):
	var bolsillo = bolsillos_datos[bolsillo_actual]
	if not item_actual.has(bolsillo_actual):
		item_actual[bolsillo_actual] = 0
	if not offset_lista.has(bolsillo_actual):
		offset_lista[bolsillo_actual] = 0
	var nuevo_item = item_actual[bolsillo_actual] + direccion
	if nuevo_item < 0:
		return
	elif nuevo_item >= bolsillo.items.size():
		return
	item_actual[bolsillo_actual] = nuevo_item
	var posicion_visual = item_actual[bolsillo_actual] - offset_lista[bolsillo_actual]
	if posicion_visual < 0:
		offset_lista[bolsillo_actual] = item_actual[bolsillo_actual]
	elif posicion_visual >= 8:
		offset_lista[bolsillo_actual] = item_actual[bolsillo_actual] - 7
	Singleton.emit_signal("play_sound", "cursor_menu")
	actualizar_contenido_bolsillo(false)
	actualizar_posicion_cursor()
	actualizar_descripcion()

# Cambio de bolsillo (izquierda/derecha)
func cambiar_bolsillo(direccion: int):
	if modo_selector and modo_selector_bolsillo_fijo:
		return
	var nuevo_bolsillo = bolsillo_actual + direccion
	if nuevo_bolsillo < 0:
		nuevo_bolsillo = bolsillos_datos.size() - 1
	elif nuevo_bolsillo >= bolsillos_datos.size():
		nuevo_bolsillo = 0
	bolsillo_actual = nuevo_bolsillo
	Singleton.mochila_ultimo_bolsillo = bolsillo_actual
	# Inicializar si no existe
	if not item_actual.has(bolsillo_actual):
		item_actual[bolsillo_actual] = 0
	if not offset_lista.has(bolsillo_actual):
		offset_lista[bolsillo_actual] = 0
	Singleton.emit_signal("play_sound", "cursor_menu")
	animar_cambio_bolsillo(nuevo_bolsillo)
	animar_giro_pokeball(direccion)
	actualizar_contenido_bolsillo(true)
	actualizar_posicion_cursor()
	actualizar_descripcion()

var cambio_bolsillo_tween: Tween = null

func animar_cambio_bolsillo(nuevo_bolsillo: int) -> void:
	if animando_cambio_bolsillo:
		return
	animando_cambio_bolsillo = true
	mochila.frame = 5
	mochila.position.y = posicion_mochila.y - 2
	await get_tree().create_timer(DURACION_CAMBIO_BOLSILLO).timeout
	mochila.position.y = posicion_mochila.y
	mochila.frame = nuevo_bolsillo
	animando_cambio_bolsillo = false

func animar_giro_pokeball(sentido: int = 0) -> void:
	if sentido == 0:
		return
	if pokeball_tween != null and pokeball_tween.is_valid():
		pokeball_tween.kill()
	pokeball_tween = create_tween()
	nd_pokeball.rotation_degrees = 0
	var fin: float = deg_to_rad(360) * sentido
	pokeball_tween.tween_property(nd_pokeball, "rotation", fin, DURACION_ROTACION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# Seleccionar item actual
func seleccionar_item():
	var bolsillo = bolsillos_datos[bolsillo_actual]
	var item = bolsillo.items[item_actual[bolsillo_actual]]

	# Si es "CERRAR LA MOCHILA" o "CANCELAR VENTA", cerrar
	if item.nombre == "CERRAR LA MOCHILA" or item.nombre == "CANCELAR VENTA":
		cerrar_mochila()
		return

	# En modo batalla el flujo es distinto (submenu USAR/SALIR)
	if modo_batalla:
		_seleccionar_item_batalla(item)
		return

	if modo_depositar_pc:
		iniciar_depositar(item)
		return

	# Si estamos en modo selector, emitir el objeto y cerrar
	if modo_selector:
		_procesar_seleccion_selector(item)
		return

	# Si estamos en modo venta, procesar venta del objeto
	if modo_venta:
		_procesar_seleccion_venta(item)
		return

	# Modo normal (mochila abierta desde el menú de pausa): menú contextual.
	_abrir_menu_campo(item)

## Procesa la selección de un objeto en modo selector: emite la señal y cierra la mochila.
func _procesar_seleccion_selector(item: Dictionary) -> void:
	if modo_selector_solo_llevables and not ObjetosLlevados.se_puede_llevar(item, bolsillo_actual):
		_mostrar_mensaje_campo(tr("MOCHILA_NO_SE_PUEDE_LLEVAR").replace("{key}", _nombre_item(item)))
		return
	var objeto = item.duplicate()
	objeto["bolsillo_id"] = bolsillo_actual
	emit_signal("objeto_seleccionado_selector", objeto)
	cerrar_mochila()

## Procesa la selección de un objeto para venta
func _procesar_seleccion_venta(item: Dictionary):
	print("[MOCHILA] 💰 Objeto seleccionado para venta: %s" % item.nombre)

	# Agregar información del bolsillo al objeto
	var objeto_venta = item.duplicate()
	objeto_venta["bolsillo_id"] = bolsillo_actual

	# Verificar que el objeto se puede vender y agregar esa información
	if not _puede_venderse(item):
		print("[MOCHILA] ❌ Este objeto no se puede vender")
		objeto_venta["vendible"] = false
	else:
		objeto_venta["vendible"] = true

	# Siempre emitir señal - que vender.gd decida qué hacer
	emit_signal("objeto_seleccionado_venta", objeto_venta)

## Verifica si un objeto se puede vender
func _puede_venderse(item: Dictionary) -> bool:
	# No se pueden vender objetos clave (bolsillo 4)
	if bolsillo_actual == 4:
		return false

	# No se pueden vender objetos especiales o únicos
	var nombre = item.get("nombre", "")
	var objetos_no_vendibles = [
		"CERRAR LA MOCHILA",
		"CANCELAR VENTA"
	]

	if nombre in objetos_no_vendibles:
		return false

	# Verificar que tenga cantidad > 0
	var cantidad = item.get("cantidad", 0)
	if cantidad <= 0:
		return false

	return true

# Cerrar la mochila
func cerrar_mochila():
	animando_cambio_bolsillo = true  # Prevenir otras interacciones
	Singleton.emit_signal("play_sound", "cursor_menu")
	if _func_oscurecer.is_valid():
		await _func_oscurecer.call()
	else:
		await Singleton.transicion("oscurecer")
	emit_signal("mochila_cerrada")

# Bloquear/desbloquear input para permitir que otros controladores manejen las teclas
func bloquear_input(bloquear: bool):
	input_bloqueado = bloquear
	if bloquear:
		print("[MOCHILA] ❌ Input bloqueado")
	else:
		print("[MOCHILA] ✅ Input desbloqueado")

# Obtener el bolsillo actual (para validaciones externas)
func get_bolsillo_actual() -> int:
	return bolsillo_actual

# activar_cooldown_input eliminado

# ─── Submenú de batalla (USAR / SALIR) ───────────────────────────────────────

func _seleccionar_item_batalla(item: Dictionary) -> void:
	var usable: bool = item.get("usable_in_battle", false)
	var es_pokeball: bool = item.get("bolsillo_id", -1) == 1
	if usable and es_pokeball:
		# Poké Balls: captura directa, sin submenú ni pantalla de equipo.
		emit_signal("objeto_listo_para_usar", item)
		input_bloqueado = true
	elif usable:
		_crear_submenu_batalla([OPC_USAR, OPC_SALIR])
		submenu_item_activo = item
		_activar_resaltado(true)
	else:
		lb_descripcion.text = "No se puede usar\nen combate."
		_crear_submenu_batalla([OPC_SALIR])
		submenu_item_activo = item
		_activar_resaltado(true)


## Devuelve el control a la lista tras un objeto sin efecto (CleanUpItemMenuMessage).
func volver_a_lista_batalla() -> void:
	_volver_a_lista_campo()


## Lista vertical en la esquina inferior derecha (una sola columna).
func _crear_submenu_batalla(opciones: Array[String]) -> void:
	var panel_w := 72
	var panel_h := SUBMENU_TILE * 2 + opciones.size() * SUBMENU_LINEA_H
	var rect := Rect2(Vector2(240 - panel_w - 2, 160 - panel_h - 2), Vector2(panel_w, panel_h))
	var celdas: Array[Rect2] = []
	for i in range(opciones.size()):
		celdas.append(_celda_submenu(0, i, panel_w - SUBMENU_TILE * 2))
	_crear_submenu(opciones, opciones.size(), rect, celdas)


# ─── Submenú fuera de combate (menú contextual por bolsillo) ─────────────────

## Abre el menú contextual del objeto en el campo. Como en pokeruby
## (sub_80A4BF0) se dibuja sobre la zona izquierda, justo encima de la
## descripción, en columnas de 2 filas (3 filas en Bayas), y la descripción
## pasa a "¿Qué quieres hacer?".
func _abrir_menu_campo(item: Dictionary) -> void:
	var opciones: Array[String] = []
	var bolsillo: int = clampi(bolsillo_actual, 0, OPCIONES_CAMPO_POR_BOLSILLO.size() - 1)
	opciones.assign(OPCIONES_CAMPO_POR_BOLSILLO[bolsillo])
	var filas: int = 2 if opciones.size() <= 4 else 3

	# Rejilla fija: columnas de 6 tiles (48 px), filas de 16 px.
	var celdas: Array[Rect2] = []
	for i in range(opciones.size()):
		var celda: Rect2 = _celda_submenu(i / filas, i % filas, SUBMENU_COLUMNA_W)
		# Una opción que no cabe en su columna (VER FICHA) ocupa también la
		# celda vacía de su derecha, y el cursor abarca las dos columnas.
		var ancho_texto: float = TEXTO_NORMAL_NEGRO.font.get_string_size(
			opciones[i], HORIZONTAL_ALIGNMENT_LEFT, -1, TEXTO_NORMAL_NEGRO.font_size).x
		var derecha: int = i + filas
		if ancho_texto + SUBMENU_TEXTO_OFFSET.x > celda.size.x \
				and derecha < opciones.size() and opciones[derecha] == "":
			celda.size.x += SUBMENU_COLUMNA_W
		celdas.append(celda)
	# Marco de 14x6 tiles (112x48, u 112x64 con 3 filas) con el borde inferior
	# en y=104, justo encima de la descripción.
	var alto: int = SUBMENU_TILE * 2 + filas * SUBMENU_LINEA_H
	var rect := Rect2(Vector2(0, 104 - alto), Vector2(SUBMENU_TILE * 14, alto))

	Singleton.emit_signal("play_sound", "cursor_menu")
	_crear_submenu(opciones, filas, rect, celdas)
	submenu_item_activo = item
	_activar_resaltado(true)
	lb_descripcion.text = FormateadorLigaduras.formatear(tr("MOCHILA_QUE_HACER"))


## Ejecuta la opción elegida en el menú contextual del campo.
func _ejecutar_opcion_campo(opcion: String, item: Dictionary) -> void:
	match opcion:
		OPC_USAR:
			Singleton.emit_signal("play_sound", "cursor_menu")
			_usar_objeto_campo(item)
		OPC_TIRAR:
			Singleton.emit_signal("play_sound", "cursor_menu")
			iniciar_tirar(item)
		OPC_DAR:
			Singleton.emit_signal("play_sound", "cursor_menu")
			iniciar_dar(item)
		OPC_SALIR:
			Singleton.emit_signal("play_sound", "cursor_menu")
			_volver_a_lista_campo()
		OPC_VER_ETIQ:
			Singleton.emit_signal("play_sound", "cursor_menu")
			_abrir_ficha_baya()
		OPC_REGISTRAR:
			# Ruby deja asignar cualquier objeto clave; si luego no se puede
			# usar en el campo, SELECT muestra el Consejo de PAPÁ.
			Singleton.emit_signal("play_sound", "cursor_menu")
			UsoObjetosCampo.alternar_registro(str(item.get("nombre_interno", "")))
			_actualizar_icono_sel()
			_volver_a_lista_campo()


## USAR fuera de combate: la lógica vive en UsoObjetosCampo; aquí sólo se
## gasta el objeto (si procede) y se muestra el mensaje correspondiente.
func _usar_objeto_campo(item: Dictionary) -> void:
	if DatosMaquinas.es_maquina(item):
		_iniciar_maquina(item)
		return
	# Medicina (ItemUseOutOfBattle_Medicine), objetos de PP, piedras evolutivas
	# y CARAMELORARO: se usan sobre un Pokémon del equipo. Las MEDICINA sin
	# efecto implementado siguen como pendientes.
	if EfectosMedicina.se_elige_pokemon_en_campo(item) or UsoObjetosCampo.se_usa_en_pokemon(item):
		_abrir_equipo_usar(item)
		return
	# ItemUseOutOfBattle_PokeblockCase: abre la CAJA POKéCUBOS y vuelve a la mochila.
	if str(item.get("uso_campo", "")) == UsoObjetosCampo.USO_CAJA_POKECUBOS:
		_abrir_estuche_pokecubos()
		return
	var parcela: ControladorBaya = ControladorBaya.parcela_frente_jugador()
	var resultado: UsoObjetosCampo.Resultado = UsoObjetosCampo.usar(item, parcela)
	match resultado:
		UsoObjetosCampo.Resultado.CONSEJO_PAPA:
			_mostrar_mensaje_campo(tr("MOCHILA_CONSEJO_PAPA"))
		UsoObjetosCampo.Resultado.REPELENTE_USADO:
			_gastar_objeto(item, 1)
			var nombre: String = str(item.get("nombre", item.get("nombre_interno", "")))
			_mostrar_mensaje_campo(tr("MOCHILA_USO_OBJETO").replace("{key}", nombre))
		UsoObjetosCampo.Resultado.REPELENTE_ACTIVO:
			_mostrar_mensaje_campo(tr("MOCHILA_REPELENTE_ACTIVO"))
		UsoObjetosCampo.Resultado.PARCELA_REGADA:
			_salir_al_campo(parcela.mostrar_riego_desde_mochila)
		UsoObjetosCampo.Resultado.BAYA_PLANTADA:
			_salir_al_campo(parcela.mostrar_plantada_desde_mochila)
		UsoObjetosCampo.Resultado.BAYA_NO_PLANTABLE:
			_mostrar_mensaje_campo(tr("BAYA_NO_PLANTABLE").replace("{objeto}", _nombre_item(item)))
		UsoObjetosCampo.Resultado.MONEDERO:
			# ItemUseOutOfBattle_CoinCase: «FICHAS: N» y vuelve a la lista.
			_mostrar_mensaje_campo(MonederoFichas.texto_uso())
		UsoObjetosCampo.Resultado.CUERDA_HUIDA:
			# ItemUseOnFieldCB_EscapeRope: el mensaje y la huida siguen en el campo.
			var jugador: Node = _jugador_overworld()
			if jugador == null or not jugador.has_method("usar_cuerda_huida"):
				push_warning("[MOCHILA] Sin jugador: no se puede usar %s" % _nombre_item(item))
				_volver_a_lista_campo()
				return
			_gastar_objeto(item, 1)
			_salir_al_campo(Callable(jugador, &"usar_cuerda_huida").bind(_nombre_item(item)))
		UsoObjetosCampo.Resultado.CANA:
			# ItemUseOnFieldCB_Rod: la caña se lanza ya en el campo.
			var jugador: Node = _jugador_overworld()
			if jugador == null or not jugador.has_method("usar_cana"):
				push_warning("[MOCHILA] Sin jugador: no se puede usar %s" % _nombre_item(item))
				_volver_a_lista_campo()
				return
			_salir_al_campo(Callable(jugador, &"usar_cana").bind(str(item.get("nombre_interno", ""))))
		UsoObjetosCampo.Resultado.BICI:
			# ItemUseOnFieldCB_Bike: se sube (o baja) ya en el campo.
			var jugador: Node = _jugador_overworld()
			if jugador == null or not jugador.has_method("toggle_bicicleta"):
				push_warning("[MOCHILA] Sin jugador: no se puede usar %s" % _nombre_item(item))
				_volver_a_lista_campo()
				return
			_salir_al_campo(Callable(jugador, &"toggle_bicicleta").bind(str(item.get("nombre_interno", ""))))
		UsoObjetosCampo.Resultado.BICI_NO_BAJAR:
			# DisplayCantGetOffBikeItemMessage.
			_mostrar_mensaje_campo(tr("RUTA_110_BICI_NO_BAJAR"))
		UsoObjetosCampo.Resultado.FLAUTA_ATRAE, UsoObjetosCampo.Resultado.FLAUTA_ALEJA:
			# PlayBlackWhiteFluteSound: tras 8 frames, SE_GLASS_FLUTE y el
			# mensaje; la flauta no se gasta.
			input_bloqueado = true
			for i in range(8):
				await get_tree().process_frame
			Singleton.emit_signal("play_sound", "SE_GLASS_FLUTE")
			var clave: String = "FLAUTA_ATRAE" if resultado == UsoObjetosCampo.Resultado.FLAUTA_ATRAE else "FLAUTA_ALEJA"
			_mostrar_mensaje_campo(tr(clave).replace("{key}", _nombre_item(item)))
		UsoObjetosCampo.Resultado.BUSCAOBJETOS:
			# ItemUseOnFieldCB_Itemfinder: la búsqueda sigue en el campo.
			var admin: Node = get_tree().root.get_node_or_null("AdministradorMapa")
			if admin == null or not admin.has_method("usar_buscaobjetos"):
				push_warning("[MOCHILA] Sin mapa: no se puede usar %s" % _nombre_item(item))
				_volver_a_lista_campo()
				return
			_salir_al_campo(Callable(admin, &"usar_buscaobjetos"))
		UsoObjetosCampo.Resultado.CARTA:
			_abrir_carta(item)
		_:
			_mostrar_mensaje_campo(tr("MOCHILA_USO_PENDIENTE"))


## Cierra la mochila (y, desde menu_pausa.gd, el menú de pausa) y deja
## `accion` pendiente para ejecutarla en el mapa: como pokeruby
## (SetUpItemUseOnFieldCallback), el efecto sigue en el campo, no en la mochila.
func _salir_al_campo(accion: Callable) -> void:
	accion_campo_pendiente = accion
	input_bloqueado = true
	_activar_resaltado(false)
	cerrar_mochila()


## Muestra un mensaje en la caja de diálogo sobre la mochila y, al cerrarlo,
## devuelve el control a la lista. La pausa "menu" sigue activa mientras la
## mochila está abierta, así que el jugador no puede moverse aunque la caja
## libere su motivo "dialogo" y su no_control local al cerrarse.
func _mostrar_mensaje_campo(mensaje: String) -> void:
	var cuadro: NinePatchRect = Singleton.get_cuadro_dialogo()
	if cuadro == null:
		push_warning("[MOCHILA] Sin caja de diálogo para mostrar: %s" % mensaje)
		_volver_a_lista_campo()
		return
	input_bloqueado = true
	_esperando_mensaje_campo = true
	cuadro.mostrar(mensaje, true, true, _on_mensaje_campo_cerrado)


func _on_mensaje_campo_cerrado() -> void:
	_esperando_mensaje_campo = false
	_volver_a_lista_campo()


## Cierra cualquier sub-flujo del menú contextual y devuelve el control a la
## lista (quita el resaltado rojo y vuelve a mostrar el cursor).
func _volver_a_lista_campo() -> void:
	_destruir_ventana_cantidad()
	flujo = Flujo.NINGUNO
	_item_flujo = {}
	input_bloqueado = false
	_activar_resaltado(false)
	actualizar_descripcion()


func _nombre_item(item: Dictionary) -> String:
	return str(item.get("nombre", item.get("nombre_interno", "")))


## Jugador del overworld (AdministradorMapa.jugador), o null.
func _jugador_overworld() -> Node:
	var admin: Node = get_tree().root.get_node_or_null("AdministradorMapa")
	return admin.get("jugador") as Node if admin != null else null


# ─── Resaltado rojo de la fila del menú contextual ──────────────────────────

func _activar_resaltado(activo: bool) -> void:
	_resaltado_activo = activo
	_aplicar_resaltado()


## Colorea en rojo la fila seleccionada (si el resaltado está activo) y deja
## el resto con su color normal; oculta el cursor de la lista mientras tanto.
func _aplicar_resaltado() -> void:
	var fila: int = -1
	if _indice_intercambio >= 0 and offset_lista.has(bolsillo_actual):
		fila = _indice_intercambio - int(offset_lista[bolsillo_actual])
	elif _resaltado_activo and item_actual.has(bolsillo_actual) and offset_lista.has(bolsillo_actual):
		fila = int(item_actual[bolsillo_actual]) - int(offset_lista[bolsillo_actual])
	for i in range(nd_lista.get_child_count()):
		var slot: Node = nd_lista.get_child(i)
		if slot is RichTextLabel:
			_colorear_fila(slot as RichTextLabel, i == fila)
	nd_cursor.visible = not _resaltado_activo


## true si la fila de la lista (0-7 visible) está resaltada en rojo.
func fila_resaltada(i: int) -> bool:
	var slot: Node = nd_lista.get_child(i)
	return slot is RichTextLabel and (slot as RichTextLabel).get_theme_color("default_color") == COLOR_TEXTO_RESALTADO


func _colorear_fila(slot: RichTextLabel, rojo: bool) -> void:
	# Guardar los colores de la escena la primera vez para poder restaurarlos.
	if not slot.has_meta(&"color_normal"):
		slot.set_meta(&"color_normal", slot.get_theme_color("default_color"))
		slot.set_meta(&"sombra_normal", slot.get_theme_color("font_shadow_color"))
	if rojo:
		slot.add_theme_color_override("default_color", COLOR_TEXTO_RESALTADO)
		slot.add_theme_color_override("font_shadow_color", COLOR_SOMBRA_RESALTADO)
	else:
		slot.add_theme_color_override("default_color", slot.get_meta(&"color_normal"))
		slot.add_theme_color_override("font_shadow_color", slot.get_meta(&"sombra_normal"))
	var nd_cant: Label = slot.get_node_or_null("cantidad") as Label
	if nd_cant == null:
		return
	if not nd_cant.has_meta(&"ajustes_normal"):
		nd_cant.set_meta(&"ajustes_normal", nd_cant.label_settings)
	nd_cant.label_settings = TEXTO_NORMAL_ROJO if rojo else nd_cant.get_meta(&"ajustes_normal")


# ─── Cambiar objetos de sitio con SELECT (item_menu.c sub_80A50C8) ──────────

## Como Ruby: sólo en el campo y en combate (no en tienda ni en el selector), y
## no en MT/MO ni Bayas, que se ordenan solos (SistemaGuardado.ordenar_bolsillo).
func _puede_intercambiar() -> bool:
	if modo_venta or (modo_selector and not modo_batalla):
		return false
	return not bolsillo_actual in SistemaGuardado.BOLSILLOS_ORDEN_AUTOMATICO


## 1.er SELECT marca el objeto (en rojo); el 2.º SELECT o A lo cambia por el
## del cursor. Sobre CERRAR LA MOCHILA, o con B, se cancela.
func _pulsar_select() -> void:
	if not _puede_intercambiar():
		return
	if _indice_intercambio >= 0:
		_confirmar_intercambio()
		return
	var indice: int = int(item_actual.get(bolsillo_actual, 0))
	if _es_opcion_cerrar(indice):
		return
	Singleton.emit_signal("play_sound", "cursor_menu")
	_indice_intercambio = indice
	_aplicar_resaltado()
	actualizar_descripcion()


func _confirmar_intercambio() -> void:
	var destino: int = int(item_actual.get(bolsillo_actual, 0))
	if _es_opcion_cerrar(destino):
		_cancelar_intercambio()
		return
	Singleton.emit_signal("play_sound", "cursor_menu")
	var origen: int = _indice_intercambio
	_indice_intercambio = -1
	if origen != destino and SistemaGuardado.intercambiar_objetos(bolsillo_actual, origen, destino):
		var items: Array = bolsillos_datos[bolsillo_actual].items
		var temporal = items[origen]
		items[origen] = items[destino]
		items[destino] = temporal
	actualizar_contenido_bolsillo(false)
	actualizar_posicion_cursor()
	actualizar_descripcion()


func _cancelar_intercambio() -> void:
	Singleton.emit_signal("play_sound", "cursor_menu")
	_indice_intercambio = -1
	_aplicar_resaltado()
	actualizar_descripcion()


func _es_opcion_cerrar(indice: int) -> bool:
	var items: Array = bolsillos_datos[bolsillo_actual].items
	if indice < 0 or indice >= items.size():
		return true
	return str(items[indice].get("nombre", "")) in [TXT_CERRAR, "CANCELAR VENTA"]


# ─── TIRAR (HandlePopupMenuAction_Toss, item_menu.c) ────────────────────────

## SellMenu_QuantityRoller: ARRIBA +1 (en el máximo vuelve a 1), ABAJO -1 (en
## 1 va al máximo), DERECHA +10 (tope en el máximo), IZQUIERDA -10 (tope en 1).
static func rodar_cantidad(actual: int, maximo: int, direccion: Vector2i) -> int:
	maximo = maxi(1, maximo)
	if direccion == Vector2i.UP:
		return 1 if actual >= maximo else actual + 1
	if direccion == Vector2i.DOWN:
		return maximo if actual <= 1 else actual - 1
	if direccion == Vector2i.RIGHT:
		return mini(actual + 10, maximo)
	if direccion == Vector2i.LEFT:
		return maxi(actual - 10, 1)
	return actual


## Paso 1: "¿Cuántos quieres tirar?" + ventana ×01 (×001 en Bayas).
func iniciar_tirar(item: Dictionary) -> void:
	_item_flujo = item
	flujo = Flujo.TIRAR_CANTIDAD
	input_bloqueado = true
	cantidad_tirar = 1
	lb_descripcion.text = FormateadorLigaduras.formatear(tr("MOCHILA_TIRAR_CUANTOS"))
	_abrir_ventana_cantidad()


## Ventana ×NN de sub_80A4DD8 (×NNN en Bayas) con la cantidad en 1.
func _abrir_ventana_cantidad() -> void:
	cantidad_tirar = 1
	_destruir_ventana_cantidad()
	var bayas: bool = bolsillo_actual == ObjetosLlevados.BOLSILLO_BAYAS
	_ventana_cantidad = _crear_marco(RECT_VENTANA_CANTIDAD_BAYAS if bayas else RECT_VENTANA_CANTIDAD)
	_lb_cantidad_tirar = Label.new()
	_lb_cantidad_tirar.label_settings = TEXTO_NORMAL_NEGRO
	_lb_cantidad_tirar.position = POS_TEXTO_CANTIDAD
	_ventana_cantidad.add_child(_lb_cantidad_tirar)
	_actualizar_texto_cantidad_tirar()


func texto_cantidad_tirar() -> String:
	var cifras: int = 3 if bolsillo_actual == ObjetosLlevados.BOLSILLO_BAYAS else 2
	return "×" + str(cantidad_tirar).pad_zeros(cifras)


func _actualizar_texto_cantidad_tirar() -> void:
	if is_instance_valid(_lb_cantidad_tirar):
		_lb_cantidad_tirar.text = texto_cantidad_tirar()


## Paso 2: cambia la cantidad con la cruceta (máximo = unidades que hay).
func mover_cantidad_tirar(direccion: Vector2i) -> void:
	var nueva: int = rodar_cantidad(cantidad_tirar, int(_item_flujo.get("cantidad", 1)), direccion)
	if nueva == cantidad_tirar:
		return
	cantidad_tirar = nueva
	Singleton.emit_signal("play_sound", "cursor_menu")
	_actualizar_texto_cantidad_tirar()


## Paso 3: A en la ventana de cantidad → confirmación con SÍ/NO.
func _confirmar_cantidad_tirar() -> void:
	Singleton.emit_signal("play_sound", "cursor_menu")
	_destruir_ventana_cantidad()
	flujo = Flujo.TIRAR_CONFIRMAR
	lb_descripcion.text = FormateadorLigaduras.formatear(tr("MOCHILA_TIRAR_CONFIRMAR") \
		.replace("{n}", str(cantidad_tirar)).replace("{key}", _nombre_item(_item_flujo)))
	var menu := MenuConfirmacion.new()
	menu.z_index = 10
	add_child(menu)
	menu.crear_menu(POS_SI_NO_TIRAR)
	var respuesta: String = await menu.opcion_seleccionada
	menu.queue_free()
	# La respuesta llega dentro del _input del SÍ/NO (hijo): consumir el evento
	# para que la mochila no lo trate como el A/B de "Has tirado...".
	if is_inside_tree():
		get_viewport().set_input_as_handled()
	responder_tirar(respuesta == "Y")


## Paso 4: SÍ → se tiran las unidades y se espera A/B; NO → vuelve a la lista.
func responder_tirar(si: bool) -> void:
	if not si:
		_volver_a_lista_campo()
		return
	var item: Dictionary = _item_flujo
	var n: int = cantidad_tirar
	_gastar_objeto(item, n)
	lb_descripcion.text = FormateadorLigaduras.formatear(tr("MOCHILA_TIRAR_HECHO") \
		.replace("{n}", str(n)).replace("{key}", _nombre_item(item)))
	flujo = Flujo.TIRAR_HECHO


func _destruir_ventana_cantidad() -> void:
	if is_instance_valid(_ventana_cantidad):
		_ventana_cantidad.queue_free()
	_ventana_cantidad = null
	_lb_cantidad_tirar = null


func _input_flujo(event: InputEvent) -> void:
	match flujo:
		Flujo.TIRAR_CANTIDAD:
			# Con repetición (JOY_REPT en Ruby).
			if event.is_action_pressed("btn_arriba", true):
				mover_cantidad_tirar(Vector2i.UP)
			elif event.is_action_pressed("btn_abajo", true):
				mover_cantidad_tirar(Vector2i.DOWN)
			elif event.is_action_pressed("btn_derecha", true):
				mover_cantidad_tirar(Vector2i.RIGHT)
			elif event.is_action_pressed("btn_izquierda", true):
				mover_cantidad_tirar(Vector2i.LEFT)
			elif event.is_action_pressed("btn_accion"):
				_confirmar_cantidad_tirar()
			elif event.is_action_pressed("btn_cancelar"):
				Singleton.emit_signal("play_sound", "cursor_menu")
				_volver_a_lista_campo()
		Flujo.TIRAR_HECHO, Flujo.DEPOSITAR_HECHO:
			if event.is_action_pressed("btn_accion") or event.is_action_pressed("btn_cancelar"):
				Singleton.emit_signal("play_sound", "cursor_menu")
				_volver_a_lista_campo()
		Flujo.DEPOSITAR_CANTIDAD:
			if event.is_action_pressed("btn_arriba", true):
				mover_cantidad_tirar(Vector2i.UP)
			elif event.is_action_pressed("btn_abajo", true):
				mover_cantidad_tirar(Vector2i.DOWN)
			elif event.is_action_pressed("btn_derecha", true):
				mover_cantidad_tirar(Vector2i.RIGHT)
			elif event.is_action_pressed("btn_izquierda", true):
				mover_cantidad_tirar(Vector2i.LEFT)
			elif event.is_action_pressed("btn_accion"):
				Singleton.emit_signal("play_sound", "cursor_menu")
				depositar(cantidad_tirar)
			elif event.is_action_pressed("btn_cancelar"):
				Singleton.emit_signal("play_sound", "cursor_menu")
				_volver_a_lista_campo()
		_:
			# TIRAR_CONFIRMAR / DAR_EQUIPO: el input es del SÍ/NO o de la
			# pantalla de equipo.
			pass


# ─── DEJAR EN EL PC (OnItemSelect_PC, item_menu.c) ──────────────────────────

const TXT_DEPOSITAR_CUANTOS: String = "¿Cuántos quieres\ndejar?"
const TXT_DEPOSITADOS: String = "Has dejado {n}."
const TXT_PC_SIN_ESPACIO: String = "No hay sitio donde\nguardar objetos."
const TXT_NO_SE_PUEDE_GUARDAR: String = "No puedes guardar\nel objeto de alguien\nen el PC."


## Selector del PC de casa/centros: la mochila no se cierra al elegir un objeto.
func activar_modo_depositar_pc() -> void:
	modo_depositar_pc = true
	activar_modo_selector(Singleton.mochila_ultimo_bolsillo, "Volver al PC.")


## Fuera de OBJ. CLAVE se pregunta siempre la cantidad (también con 1 unidad);
## los objetos clave pasan directamente a la comprobación de importancia.
func iniciar_depositar(item: Dictionary) -> void:
	Singleton.emit_signal("play_sound", "cursor_menu")
	_item_flujo = item
	input_bloqueado = true
	_activar_resaltado(true)
	if bolsillo_actual == 4:
		cantidad_tirar = 1
		depositar(1)
		return
	flujo = Flujo.DEPOSITAR_CANTIDAD
	lb_descripcion.text = FormateadorLigaduras.formatear(TXT_DEPOSITAR_CUANTOS)
	_abrir_ventana_cantidad()


## sub_80A6B64: importancia 2 → no se guarda; PC lleno → sin espacio.
func depositar(cantidad: int) -> void:
	_destruir_ventana_cantidad()
	var nombre_interno: String = str(_item_flujo.get("nombre_interno", ""))
	var texto: String
	match AlmacenObjetosPC.depositar(nombre_interno, cantidad):
		AlmacenObjetosPC.Resultado.EXITO:
			texto = TXT_DEPOSITADOS.replace("{key}", _nombre_item(_item_flujo)).replace("{n}", str(cantidad))
			_reflejar_cantidad(nombre_interno)
		AlmacenObjetosPC.Resultado.IMPORTANTE:
			texto = TXT_NO_SE_PUEDE_GUARDAR
		_:
			texto = TXT_PC_SIN_ESPACIO
	lb_descripcion.text = FormateadorLigaduras.formatear(texto)
	flujo = Flujo.DEPOSITAR_HECHO


# ─── DAR (HandlePopupMenuAction_Give, item_menu.c) ──────────────────────────

## Objeto clave / MO → "no se puede llevar"; sin equipo → "No quedan POKéMON";
## si no, abre la pantalla de equipo en modo DAR_OBJETO.
func iniciar_dar(item: Dictionary) -> void:
	if not ObjetosLlevados.se_puede_llevar(item, bolsillo_actual):
		_mostrar_mensaje_campo(tr("MOCHILA_NO_SE_PUEDE_LLEVAR").replace("{key}", _nombre_item(item)))
		return
	if ObjetosLlevados.equipo_vacio():
		_mostrar_mensaje_campo(tr("MOCHILA_SIN_POKEMON"))
		return
	# TODO: en Ruby dar una CARTA abre la pantalla de escribir la carta; de
	# momento se da como un objeto normal.
	_abrir_equipo_dar(item)


func _abrir_equipo_dar(item: Dictionary) -> void:
	flujo = Flujo.DAR_EQUIPO
	_item_flujo = item
	input_bloqueado = true
	await Singleton.transicion("oscurecer")
	var equipo := EquipoPokemon.new()
	for pokemon: BasePokemon in SistemaGuardado.get_equipo():
		equipo.agregar_pokemon(pokemon)
	_pantalla_equipo = (load(RUTA_PANTALLA_EQUIPO) as PackedScene).instantiate() as PantallaEquipoControlador
	_pantalla_equipo.objeto_a_dar = item
	_pantalla_equipo.bolsillo_objeto_a_dar = bolsillo_actual
	# Hermana de la mochila (no hija) para poder ocultar la mochila entera.
	get_parent().add_child(_pantalla_equipo)
	_pantalla_equipo.dar_objeto_terminado.connect(_on_equipo_dar_cerrado)
	_pantalla_equipo.seleccion_cancelada.connect(_on_equipo_dar_cerrado)
	_pantalla_equipo.mostrar_equipo_modo(Singleton.ModoPEquipo.DAR_OBJETO, equipo,
		FormateadorLigaduras.formatear(tr("EQUIPO_DAR_A_QUIEN")))
	visible = false
	await Singleton.transicion("aclarar")


## USAR una medicina (ItemUseOutOfBattle_Medicine): abre la pantalla de equipo
## en modo USAR_OBJETO, igual que DAR. La pantalla aplica el objeto y lo gasta
## si tuvo efecto; con o sin efecto (o con B) se vuelve a la lista con un
## fundido (sub_808B224 de pokemon_menu.c).
func _abrir_equipo_usar(item: Dictionary) -> void:
	flujo = Flujo.USAR_EQUIPO
	_item_flujo = item
	input_bloqueado = true
	await Singleton.transicion("oscurecer")
	var equipo := EquipoPokemon.new()
	for pokemon: BasePokemon in SistemaGuardado.get_equipo():
		equipo.agregar_pokemon(pokemon)
	_pantalla_equipo = (load(RUTA_PANTALLA_EQUIPO) as PackedScene).instantiate() as PantallaEquipoControlador
	_pantalla_equipo.objeto_a_usar = item
	_pantalla_equipo.bolsillo_objeto_a_usar = bolsillo_actual
	# Hermana de la mochila (no hija) para poder ocultar la mochila entera.
	get_parent().add_child(_pantalla_equipo)
	_pantalla_equipo.objeto_usado.connect(func(_indice: int, _tuvo_efecto: bool) -> void: _on_equipo_dar_cerrado())
	_pantalla_equipo.seleccion_cancelada.connect(_on_equipo_dar_cerrado)
	# ITEM_USE_ALL_MONS (CEN. SAGRADA): sin pregunta ni elección, se aplica a
	# todo el equipo en cuanto se ve la pantalla.
	var a_todos: bool = str(item.get("uso_campo", "")) == UsoObjetosCampo.USO_CENIZA_SAGRADA
	var pregunta: String = ""
	if not a_todos:
		pregunta = FormateadorLigaduras.formatear(DatosMaquinas.texto("MAQUINA_ELEGIR_POKEMON") if DatosMaquinas.es_maquina(item) else tr("EQUIPO_USAR_EN_QUIEN"))
	_pantalla_equipo.mostrar_equipo_modo(Singleton.ModoPEquipo.USAR_OBJETO, equipo, pregunta)
	if a_todos:
		_pantalla_equipo.activo = false
	visible = false
	await Singleton.transicion("aclarar")
	if a_todos:
		await _pantalla_equipo.usar_objeto_en_todos()


## `ItemUseOutOfBattle_TMHM`: "MT activada." / "MO activada." (SE_PC_LOGIN), "Ésta
## contiene X. ¿Enseñas X a un POKéMON?" y, con SÍ, el equipo en modo MT/MO
## (StartTeachMonTMHMMove). Con NO se vuelve a la lista.
func _iniciar_maquina(item: Dictionary) -> void:
	var objeto: String = str(item.get("nombre_interno", ""))
	if _dialogo_maquina != null or bolsillo_actual != DatosMaquinas.BOLSILLO \
		or not SistemaGuardado.tiene_objeto(objeto, 1, bolsillo_actual): return
	if ObjetosLlevados.equipo_vacio():
		_mostrar_mensaje_campo(tr("MOCHILA_SIN_POKEMON"))
		return
	var cuadro: NinePatchRect = Singleton.get_cuadro_dialogo()
	if cuadro == null: return
	_sesion_maquina += 1
	var sesion: int = _sesion_maquina
	_partida_maquina = SistemaGuardado.datos_vivos
	var admin: Node = get_node_or_null("/root/AdministradorMapa")
	_contexto_activacion_maquina = {"admin": admin, "mapa": admin.get("mapa_actual") if admin != null else null, "objeto": objeto}
	input_bloqueado = true
	_dialogo_maquina = preload("res://UI/maquinas/dialogo_activacion.tscn").instantiate() as DialogoBaseSecreta
	_dialogo_maquina.cuadro = cuadro
	get_parent().add_child(_dialogo_maquina)
	Singleton.mantener_pausa(PAUSA_ACTIVACION_MAQUINA, true)
	await _dialogo_maquina.mensaje(DatosMaquinas.texto("MAQUINA_MO_ACTIVADA" if DatosMaquinas.es_mo(objeto) else "MAQUINA_MT_ACTIVADA"))
	if sesion != _sesion_maquina: return
	Singleton.emit_signal("play_sound", "SE_PC_LOGIN")
	var acepta: bool = await _dialogo_maquina.preguntar(DatosMaquinas.texto("MAQUINA_CONTIENE", null, DatosMaquinas.nombre_movimiento(objeto)))
	if sesion != _sesion_maquina: return
	var vigente: bool = _activacion_maquina_vigente()
	_cerrar_activacion_maquina()
	if acepta and vigente:
		_abrir_equipo_usar(item)
	else:
		_volver_a_lista_campo()


func _activacion_maquina_vigente() -> bool:
	var admin: Node = _contexto_activacion_maquina.get("admin")
	if admin != null and (not is_instance_valid(admin) or admin.get("mapa_actual") != _contexto_activacion_maquina.get("mapa") or int(admin.get("coneccion")) != 0): return false
	var objeto: String = str(_contexto_activacion_maquina.get("objeto", ""))
	return is_inside_tree() and not is_queued_for_deletion() and _partida_maquina == SistemaGuardado.datos_vivos \
		and not modo_batalla and not modo_selector and not objeto.is_empty() \
		and bolsillo_actual == DatosMaquinas.BOLSILLO and SistemaGuardado.tiene_objeto(objeto, 1, DatosMaquinas.BOLSILLO)


func _cerrar_activacion_maquina() -> void:
	_sesion_maquina += 1
	var dialogo: DialogoBaseSecreta = _dialogo_maquina
	_dialogo_maquina = null
	_partida_maquina = null
	_contexto_activacion_maquina.clear()
	Singleton.mantener_pausa(PAUSA_ACTIVACION_MAQUINA, false)
	if is_instance_valid(dialogo):
		dialogo.cancelar()
		dialogo.queue_free()


func _process(_delta: float) -> void:
	if _dialogo_maquina != null and not _activacion_maquina_vigente():
		_cerrar_activacion_maquina()
		recargar_lista()
		_volver_a_lista_campo()


func _exit_tree() -> void:
	if _dialogo_maquina != null: _cerrar_activacion_maquina()


## Al terminar (o cancelar con B) en la pantalla de equipo (DAR o USAR) se
## vuelve a la mochila en la misma posición, con la lista recargada: la
## cantidad baja, la fila desaparece si llegó a 0 y el objeto recuperado en un
## intercambio aparece en su bolsillo.
func _on_equipo_dar_cerrado() -> void:
	if flujo != Flujo.DAR_EQUIPO and flujo != Flujo.USAR_EQUIPO:
		return
	if is_instance_valid(_pantalla_equipo):
		_pantalla_equipo.activo = false
	await Singleton.transicion("oscurecer")
	if is_instance_valid(_pantalla_equipo):
		_pantalla_equipo.ocultar_pantalla_equipo()
		_pantalla_equipo.queue_free()
	_pantalla_equipo = null
	visible = true
	recargar_lista()
	_volver_a_lista_campo()
	await Singleton.transicion("aclarar")


## Icono SEL junto al objeto registrado, si está a la vista en el bolsillo de
## objetos clave (AddSelectIconToRegisteredItem / RemoveSelectIconFromRegisteredItem).
func _actualizar_icono_sel() -> void:
	if _icono_sel == null:
		_icono_sel = Sprite2D.new()
		_icono_sel.name = "IconoSel"
		_icono_sel.texture = ICONO_SEL
		_icono_sel.centered = false
		add_child(_icono_sel)
	var fila: int = -1
	var registrado: String = UsoObjetosCampo.objeto_registrado()
	if bolsillo_actual == UsoObjetosCampo.BOLSILLO_CLAVE and not registrado.is_empty():
		var items: Array = bolsillos_datos[bolsillo_actual].items
		for i in range(items.size()):
			if str(items[i].get("nombre_interno", "")) == registrado:
				fila = i - int(offset_lista.get(bolsillo_actual, 0))
				break
	_icono_sel.visible = fila >= 0 and fila < 8
	if _icono_sel.visible:
		_icono_sel.position = POS_ICONO_SEL + Vector2(0, fila * salto_cursor)


## VER FICHA: abre la ficha de la baya seleccionada como hermana de la
## mochila (igual que la pantalla de equipo en DAR). En la ficha se puede
## pasar a las otras bayas del bolsillo con ARRIBA/ABAJO.
func _abrir_ficha_baya() -> void:
	flujo = Flujo.VER_FICHA
	input_bloqueado = true
	await Singleton.transicion("oscurecer")
	var bayas: Array = []
	for item: Dictionary in bolsillos_datos[bolsillo_actual].items:
		if item.get("nombre", "") != TXT_CERRAR:
			bayas.append(item)
	_ficha_baya = (load(RUTA_FICHA_BAYA) as PackedScene).instantiate() as FichaBaya
	get_parent().add_child(_ficha_baya)
	_ficha_baya.ficha_cerrada.connect(_on_ficha_baya_cerrada)
	visible = false
	_ficha_baya.abrir(bayas, item_actual.get(bolsillo_actual, 0))


## La ficha se cierra con la pantalla ya oscurecida; el cursor de la lista
## queda sobre la última baya mostrada (como Ruby).
func _on_ficha_baya_cerrada(indice: int) -> void:
	if is_instance_valid(_ficha_baya):
		_ficha_baya.queue_free()
	_ficha_baya = null
	visible = true
	item_actual[bolsillo_actual] = indice
	if indice < offset_lista[bolsillo_actual]:
		offset_lista[bolsillo_actual] = indice
	elif indice >= offset_lista[bolsillo_actual] + 8:
		offset_lista[bolsillo_actual] = indice - 7
	actualizar_contenido_bolsillo(false)
	actualizar_posicion_cursor()
	_volver_a_lista_campo()
	await Singleton.transicion("aclarar")


## USAR la CAJA POKéCUBOS (ItemUseOutOfBattle_PokeblockCase con sub_810BA7C(0)):
## fundido, el estuche como hermano de la mochila y, al cerrarlo, vuelta a la
## lista con otro fundido (sub_80A5B40).
func _abrir_estuche_pokecubos() -> void:
	flujo = Flujo.ESTUCHE_POKECUBOS
	input_bloqueado = true
	await Singleton.transicion("oscurecer")
	_estuche_pokecubos = (load(RUTA_ESTUCHE_POKECUBOS) as PackedScene).instantiate() as PantallaEstuchePokecubos
	get_parent().add_child(_estuche_pokecubos)
	_estuche_pokecubos.estuche_cerrado.connect(_on_estuche_pokecubos_cerrado)
	visible = false
	_estuche_pokecubos.abrir()


## El estuche se cierra con la pantalla ya oscurecida.
func _on_estuche_pokecubos_cerrado() -> void:
	if is_instance_valid(_estuche_pokecubos):
		_estuche_pokecubos.queue_free()
	_estuche_pokecubos = null
	visible = true
	_volver_a_lista_campo()
	await Singleton.transicion("aclarar")


## USAR una CARTA (ItemUseOutOfBattle_Mail → ItemMenu_ReadMail): fundido, la
## carta vacía como hermana de la mochila y, al cerrarla, vuelta a la lista con
## otro fundido (sub_80A5D04).
func _abrir_carta(item: Dictionary) -> void:
	flujo = Flujo.CARTA
	input_bloqueado = true
	await Singleton.transicion("oscurecer")
	_pantalla_carta = (load(RUTA_PANTALLA_CARTA) as PackedScene).instantiate() as PantallaCarta
	get_parent().add_child(_pantalla_carta)
	_pantalla_carta.carta_cerrada.connect(_on_carta_cerrada)
	visible = false
	_pantalla_carta.abrir(DatosCarta.desde_objeto(str(item.get("nombre_interno", ""))))


## La carta se cierra con la pantalla ya oscurecida.
func _on_carta_cerrada() -> void:
	if is_instance_valid(_pantalla_carta):
		_pantalla_carta.queue_free()
	_pantalla_carta = null
	visible = true
	_volver_a_lista_campo()
	await Singleton.transicion("aclarar")


## Recarga todos los bolsillos desde el guardado conservando cursor y
## desplazamiento (ajustados si la lista se ha acortado).
func recargar_lista() -> void:
	cargar_datos_desde_guardado()
	for bolsillo_key in bolsillos_datos.keys():
		_ajustar_cursor_bolsillo(int(bolsillo_key))
	actualizar_contenido_bolsillo(false)
	actualizar_posicion_cursor()
	actualizar_descripcion()


## Mantiene cursor y desplazamiento dentro de la lista del bolsillo (siempre
## queda al menos "CERRAR LA MOCHILA").
func _ajustar_cursor_bolsillo(bolsillo: int) -> void:
	if not bolsillos_datos.has(bolsillo):
		return
	var total: int = bolsillos_datos[bolsillo].items.size()
	var actual: int = clampi(int(item_actual.get(bolsillo, 0)), 0, maxi(0, total - 1))
	var offset: int = clampi(int(offset_lista.get(bolsillo, 0)), 0, maxi(0, total - 8))
	if actual < offset:
		offset = actual
	elif actual >= offset + 8:
		offset = actual - 7
	item_actual[bolsillo] = actual
	offset_lista[bolsillo] = offset


## Quita `cantidad` unidades del objeto del inventario guardado y refleja el
## cambio en la lista visible (misma idea que vender.gd
## _actualizar_mochila_incremental): baja la cantidad o elimina la fila,
## ajustando cursor y desplazamiento.
func _gastar_objeto(item: Dictionary, cantidad: int = 1) -> void:
	var nombre_interno: String = str(item.get("nombre_interno", ""))
	if not SistemaGuardado.quitar_objeto_jugador(nombre_interno, cantidad, bolsillo_actual):
		push_warning("[MOCHILA] No se pudo quitar %d x %s del bolsillo %d" % [cantidad, nombre_interno, bolsillo_actual])
		return
	_reflejar_cantidad(nombre_interno)


## Sincroniza la fila visible de `nombre_interno` con el inventario guardado.
func _reflejar_cantidad(nombre_interno: String) -> void:
	var items: Array = bolsillos_datos[bolsillo_actual].items
	var indice: int = -1
	for i in range(items.size()):
		if str(items[i].get("nombre_interno", "")) == nombre_interno:
			indice = i
			break
	if indice == -1:
		# Desincronizado: recargar todo desde el guardado.
		cargar_datos_desde_guardado()
	else:
		var restante: int = SistemaGuardado.get_cantidad_objeto(nombre_interno, bolsillo_actual)
		if restante > 0:
			items[indice]["cantidad"] = restante
		else:
			items.remove_at(indice)
			# La fila la ocupa ahora otro objeto: no resaltarlo en rojo.
			_resaltado_activo = false

	_ajustar_cursor_bolsillo(bolsillo_actual)

	actualizar_contenido_bolsillo(false)
	actualizar_posicion_cursor()
	actualizar_descripcion()


# ─── Submenú genérico (panel + cursor rectangular) ───────────────────────────

## Celda (rect del cursor) de la opción en `col`/`fila`, relativa al marco.
## Empieza 1 px antes del primer tile interior para que el borde del cursor
## quede por fuera del texto, igual que el cursor de la lista.
func _celda_submenu(col: int, fila: int, ancho: int) -> Rect2:
	var origen := Vector2(SUBMENU_TILE - 1 + col * ancho, SUBMENU_TILE - 1 + fila * SUBMENU_LINEA_H)
	return Rect2(origen, Vector2(ancho, SUBMENU_LINEA_H + 1))


## Crea (como hijo) un marco NinePatchRect del estilo de ventana elegido en
## las opciones, en `rect` (múltiplos de SUBMENU_TILE), por encima de la lista.
func _crear_marco(rect: Rect2) -> NinePatchRect:
	var ninepatch := NinePatchRect.new()
	ninepatch.position = rect.position
	ninepatch.size = rect.size
	ninepatch.z_index = 10
	var menu_box_manager = preload("res://scripts/clases/MenuBoxManager.gd")
	var tipo := 1
	if SistemaGuardado and SistemaGuardado.datos_vivos and SistemaGuardado.datos_vivos.opciones:
		tipo = int(SistemaGuardado.datos_vivos.opciones.imagen_tipo)
	menu_box_manager.apply_texture_to_ninepatch(ninepatch, tipo)
	# Tiles de 8 px repetidos sin estirar (como menu_pausa.tscn).
	ninepatch.patch_margin_left = SUBMENU_TILE
	ninepatch.patch_margin_top = SUBMENU_TILE
	ninepatch.patch_margin_right = SUBMENU_TILE
	ninepatch.patch_margin_bottom = SUBMENU_TILE
	ninepatch.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
	ninepatch.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
	add_child(ninepatch)
	return ninepatch


## Crea el panel del submenú. `rect`: posición y tamaño del marco (múltiplos
## de SUBMENU_TILE). `celdas`: rect del cursor de cada opción; el texto se
## dibuja en celda.position + SUBMENU_TEXTO_OFFSET. Las opciones se ordenan
## por columnas de `filas` filas.
func _crear_submenu(opciones: Array[String], filas: int, rect: Rect2, celdas: Array[Rect2]) -> void:
	_destruir_submenu()
	submenu_opciones = opciones
	submenu_filas = maxi(1, filas)
	_submenu_celdas = celdas
	submenu_indice = 0
	input_bloqueado = true

	var ninepatch := _crear_marco(rect)
	submenu = ninepatch

	for i in range(opciones.size()):
		if opciones[i] == "":
			continue
		var lbl := Label.new()
		lbl.text = opciones[i]
		lbl.label_settings = TEXTO_NORMAL_NEGRO
		lbl.position = celdas[i].position + SUBMENU_TEXTO_OFFSET
		ninepatch.add_child(lbl)

	# Cursor: rectángulo de 1 px con esquinas redondeadas, igual que el de la lista.
	var cursor := PkSelectorSimple.new()
	cursor.name = "CursorSubmenu"
	cursor.ancho_borde = 1
	cursor.color = nd_cursor.color
	cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ninepatch.add_child(cursor)
	_actualizar_cursor_submenu()


## Mueve el cursor por la rejilla. Como en pokeruby, no se sale de la columna
## al moverse en vertical ni se puede caer en un hueco vacío.
func _mover_cursor_submenu(d_fila: int, d_col: int) -> void:
	var destino: int = -1
	if d_fila != 0:
		var fila: int = submenu_indice % submenu_filas
		var nueva_fila: int = fila + d_fila
		if nueva_fila >= 0 and nueva_fila < submenu_filas:
			destino = submenu_indice + d_fila
	elif d_col != 0:
		destino = submenu_indice + d_col * submenu_filas
	if destino < 0 or destino >= submenu_opciones.size() or submenu_opciones[destino] == "":
		return
	submenu_indice = destino
	if not modo_batalla:
		Singleton.emit_signal("play_sound", "cursor_menu")
	_actualizar_cursor_submenu()


func _actualizar_cursor_submenu() -> void:
	if submenu == null:
		return
	var cursor: Control = submenu.get_node_or_null("CursorSubmenu")
	if cursor and submenu_indice < _submenu_celdas.size():
		var celda: Rect2 = _submenu_celdas[submenu_indice]
		cursor.position = celda.position
		cursor.size = celda.size


func _confirmar_submenu() -> void:
	var opcion := submenu_opciones[submenu_indice]
	# Capturar el objeto ANTES de destruir el submenú (que lo limpia).
	var item: Dictionary = submenu_item_activo
	_destruir_submenu()
	if modo_batalla:
		if opcion == OPC_USAR:
			input_bloqueado = true
			emit_signal("objeto_listo_para_usar", item)
		else:
			input_bloqueado = false
			_activar_resaltado(false)
			actualizar_descripcion()
		return
	_ejecutar_opcion_campo(opcion, item)


func _destruir_submenu() -> void:
	if is_instance_valid(submenu):
		submenu.queue_free()
	submenu = null
	submenu_item_activo = {}
