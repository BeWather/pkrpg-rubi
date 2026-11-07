@tool
extends Control
## UI del editor para configurar y lanzar una batalla de prueba. La raiz es un
## Control anclado a toda la ventana; plugin.gd la monta dentro de una Window
## nativa redimensionable (mismo patron que el Editor de Instancia de Pokemon).
## La UI esta declarada por completo en ventana_debug_batalla.tscn (incluidas
## las conexiones de senales); este script solo aporta la logica: recolectar la
## configuracion, guardar el Resource y lanzar la instancia de juego.
##
## Flujo: UI (proceso editor) -> guarda ConfiguracionDebugBatalla (.tres en
## res://BaseDatos/temp) -> EditorInterface.play_custom_scene(lanzador) ->
## el lanzador (proceso juego) lee el Resource y arranca batalla.tscn.

const SingletonScript := preload("res://scripts/singleton.gd")
const ScriptConfiguracion := preload("res://escenas/batalla/debug/configuracion_debug_batalla.gd")

const RUTA_CONFIG_GUARDADA := "res://BaseDatos/temp/configuracion_debug_batalla.tres"
const RUTA_ESCENA_BOOT := "res://escenas/batalla/debug/lanzador_debug_batalla.tscn"
const RUTA_ENTRENADORES_JSON := "res://BaseDatos/lista_entrenadores.json"
const RUTA_TEMAS_MUSICALES := "res://BaseDatos/temas_musicales.json"
const RUTA_PARTIDA_DEBUG := "res://partida/partida_guardada.json"
const CARPETA_TEMP := "res://BaseDatos/temp"

## Pide a plugin.gd abrir el Editor de Instancia de Pokemon. Los `datos` del
## slot se cargan SIEMPRE en el formulario tal cual (esten o no en la BBDD);
## pokemon_id es solo informativo y deja esa fila preseleccionada en la lista.
## Los datos vuelven por recibir_datos_pokemon() al pulsar alli "Seleccionar".
signal solicitar_editor_instancia(pokemon_id: int, datos: Dictionary)

## Pide a plugin.gd abrir el Editor de Entrenadores (edita el JSON; al volver,
## usar el boton Releer para refrescar la lista de esta ventana).
signal solicitar_editor_entrenadores

## La preview y la batalla usan el escenario elegido (EscenarioBatalla.rutas);
## los temas gráficos legados (Singleton.TemaBatalla) solo se leen para migrar
## configuraciones guardadas antes de existir `escenario`.

## Escenario por defecto (y el que se elige si no hay configuración guardada).
const ESCENARIO_POR_DEFECTO := "hierba_alta"

@onready var etiqueta_estado: Label = $MainLayout/Header/Contenido/Estado
@onready var boton_salvaje: Button = $MainLayout/Contenido/PanelConfiguracion/Margen/Configuracion/Encuentro/Salvaje
@onready var boton_entrenador: Button = $MainLayout/Contenido/PanelConfiguracion/Margen/Configuracion/Encuentro/Entrenador
@onready var boton_simple: Button = $MainLayout/Contenido/PanelConfiguracion/Margen/Configuracion/Formato/Simple
@onready var boton_doble: Button = $MainLayout/Contenido/PanelConfiguracion/Margen/Configuracion/Formato/Doble
@onready var regla_combate: OptionButton = $MainLayout/Contenido/PanelConfiguracion/Margen/Configuracion/Estilo/Valor
## Escenario de batalla (EscenarioBatalla.ids_escenarios(); el texto del item es
## el id) y terreno de la animación de entrada (id = EscenarioBatalla.Terreno,
## -1 automático). Los dos se pueblan en _poblar_escenarios().
@onready var opcion_escenario: OptionButton = $MainLayout/Contenido/PanelPresentacion/Margen/Caja/Escenario
@onready var opcion_terreno: OptionButton = $MainLayout/Contenido/PanelPresentacion/Margen/Caja/Terreno
@onready var opcion_musica: OptionButton = $MainLayout/Contenido/PanelPresentacion/Margen/Caja/Musica
@onready var etiqueta_resumen: Label = $MainLayout/Contenido/PanelConfiguracion/Margen/Configuracion/Resumen/Texto
@onready var panel_salvaje: PanelContainer = $MainLayout/Contenido/PanelRival/Margen/Desplazamiento/Contenido/PanelSalvaje
@onready var panel_entrenador: PanelContainer = $MainLayout/Contenido/PanelRival/Margen/Desplazamiento/Contenido/PanelEntrenador
@onready var slot_salvaje: PokeSlotHorizontal = $MainLayout/Contenido/PanelRival/Margen/Desplazamiento/Contenido/PanelSalvaje/Editor/SlotSalvaje
@onready var campo_ubicacion: LineEdit = $MainLayout/Contenido/PanelRival/Margen/Desplazamiento/Contenido/PanelSalvaje/Editor/Ubicacion/Valor
@onready var etiqueta_entrenador: Label = $MainLayout/Contenido/PanelRival/Margen/Desplazamiento/Contenido/PanelEntrenador/Editor/EntrenadorSeleccionado
@onready var lista_entrenadores: ItemList = $MainLayout/Contenido/PanelRival/Margen/Desplazamiento/Contenido/PanelEntrenador/Editor/Lista
@onready var boton_editor_entrenadores: Button = $MainLayout/Contenido/PanelRival/Margen/Desplazamiento/Contenido/PanelEntrenador/Editor/AccionesEntrenador/AbrirEditor
@onready var boton_releer_entrenadores: Button = $MainLayout/Contenido/PanelRival/Margen/Desplazamiento/Contenido/PanelEntrenador/Editor/AccionesEntrenador/Releer
@onready var boton_preparar: Button = $MainLayout/FilaInferior/ColumnaDerecha/Pie/Preparar
@onready var selector: Window = $SelectorPokemon
@onready var opcion_clima: OptionButton = $MainLayout/Contenido/PanelConfiguracion/Margen/Configuracion/Clima/Valor
@onready var borde_menu_preview: NinePatchRect = $MainLayout/Contenido/PanelPresentacion/Margen/Caja/PanelPreview/Margen/Caja/BordeMenu
@onready var main_layout: VBoxContainer = $MainLayout
@onready var tab_origenes: TabContainer = $MainLayout/Contenido/PanelJugador/Margen/Equipo/Origenes
@onready var campo_nombre_jugador: LineEdit = $MainLayout/Contenido/PanelJugador/Margen/Equipo/Jugador/NombreJugador
@onready var opcion_sexo_jugador: OptionButton = $MainLayout/Contenido/PanelJugador/Margen/Equipo/Jugador/SexoJugador
@onready var campo_entrenador_nombre: LineEdit = $MainLayout/Contenido/PanelRival/Margen/Desplazamiento/Contenido/PanelEntrenador/Editor/Nombre/Valor
@onready var campo_entrenador_clase: LineEdit = $MainLayout/Contenido/PanelRival/Margen/Desplazamiento/Contenido/PanelEntrenador/Editor/Clase/Valor
@onready var campo_entrenador_sprite: SpinBox = $MainLayout/Contenido/PanelRival/Margen/Desplazamiento/Contenido/PanelEntrenador/Editor/Sprite/Valor
@onready var campo_entrenador_musica: LineEdit = $MainLayout/Contenido/PanelRival/Margen/Desplazamiento/Contenido/PanelEntrenador/Editor/Musica/Valor
@onready var textura_fondo: TextureRect = $MainLayout/Contenido/PanelPresentacion/Margen/Caja/PanelPreview/Margen/Caja/Marco/Escena/Fondo
@onready var suelo_arriba: TextureRect = $MainLayout/Contenido/PanelPresentacion/Margen/Caja/PanelPreview/Margen/Caja/Marco/Escena/SueloArriba
@onready var suelo_abajo: TextureRect = $MainLayout/Contenido/PanelPresentacion/Margen/Caja/PanelPreview/Margen/Caja/Marco/Escena/SueloAbajo
@onready var poke_rival: TextureRect = $MainLayout/Contenido/PanelPresentacion/Margen/Caja/PanelPreview/Margen/Caja/Marco/Escena/PokeRival
@onready var poke_jugador: TextureRect = $MainLayout/Contenido/PanelPresentacion/Margen/Caja/PanelPreview/Margen/Caja/Marco/Escena/PokeJugador
@onready var trainer_rival: TextureRect = $MainLayout/Contenido/PanelPresentacion/Margen/Caja/PanelPreview/Margen/Caja/Marco/Escena/TrainerRival
@onready var trainer_jugador: TextureRect = $MainLayout/Contenido/PanelPresentacion/Margen/Caja/PanelPreview/Margen/Caja/Marco/Escena/TrainerJugador
@onready var opcion_vel_texto: OptionButton = $MainLayout/Contenido/PanelConfiguracion/Margen/Configuracion/OpcionesGrid/OpVelTexto
@onready var campo_borde_menus: SpinBox = $MainLayout/Contenido/PanelConfiguracion/Margen/Configuracion/OpcionesGrid/OpBorde
@onready var opcion_tipo_combate: OptionButton = $MainLayout/Contenido/PanelConfiguracion/Margen/Configuracion/OpcionesGrid/OpTipoCombate
@onready var check_animaciones: CheckButton = $MainLayout/Contenido/PanelConfiguracion/Margen/Configuracion/OpcionesGrid/OpAnimaciones
@onready var opcion_audio: OptionButton = $MainLayout/Contenido/PanelConfiguracion/Margen/Configuracion/OpcionesGrid/OpAudio
@onready var opcion_controles: OptionButton = $MainLayout/Contenido/PanelConfiguracion/Margen/Configuracion/OpcionesGrid/OpControles

var _datos_entrenadores: Array = []
var _datos_partida: Dictionary = {}
var _slots_equipos: Array = [[], []]
var _slots_entrenador: Array = []
var _entrenador_editado: Dictionary = {}
var _entrenador_registro: Dictionary = {}
var _solicitante = null
var _identidad_inicializada := false


func _ready() -> void:
	_recoger_slots()
	_configurar_controles_jugador()
	_cargar_entrenadores()
	_cargar_temas_musicales()
	_poblar_escenarios()
	_cargar_resumen_partida()
	_restaurar_configuracion_guardada()
	if slot_salvaje.esta_vacio():
		slot_salvaje.establecer({"nombre_interno": "WURMPLE", "nivel": 5})
	_refrescar_slot_salvaje()
	_actualizar_modo_encuentro()
	_set_estado("Interfaz lista.")


# ----------------------------------------------------------------------------
# HANDLERS (conectados desde los bloques [connection] del .tscn)
# ----------------------------------------------------------------------------

func _on_cerrar_presionado() -> void:
	var ventana := get_window()
	if ventana == get_tree().root:
		# Ejecucion directa (F6): cerrar termina la depuracion.
		get_tree().quit()
		return
	ventana.hide()


func _actualizar_modo_encuentro() -> void:
	var es_salvaje := boton_salvaje.button_pressed
	panel_salvaje.visible = es_salvaje
	panel_entrenador.visible = not es_salvaje
	# Salvaje + Doble no está soportado; se deshabilita el botón y se fuerza SIMPLE.
	if es_salvaje:
		if boton_doble.button_pressed:
			boton_doble.set_pressed_no_signal(false)
			boton_simple.set_pressed_no_signal(true)
		boton_doble.disabled = true
		_set_estado("Encuentro salvaje (solo SIMPLE soportado): configura un unico slot rival.")
	else:
		boton_doble.disabled = false
		_set_estado("Encuentro contra entrenador: selecciona un rival de la lista.")
	_actualizar_resumen()


func _actualizar_resumen(_indice: int = -1) -> void:
	var config := _recolectar_configuracion()
	if config == null:
		etiqueta_resumen.text = "Configuracion incompleta: selecciona un entrenador."
		_actualizar_preview()
		return
	etiqueta_resumen.text = "%s\nJugador: equipo editable (pendiente)\nRival: %s" % [
		config.resumen(),
		"slot salvaje" if config.es_salvaje() else "entrenador seleccionado",
	]
	_actualizar_preview()


func _actualizar_fuente_salvaje(indice: int) -> void:
	if indice == 0:
		_set_estado("El salvaje se reconstruira desde especie, nivel y ubicacion.")
	else:
		_set_estado("Pendiente: usar instancia existente (por ahora se reconstruye desde datos basicos).")


# ----------------------------------------------------------------------------
# PARTIDA GUARDADA (lectura informativa del JSON debug del proyecto)
# ----------------------------------------------------------------------------

## Lee res://partida/partida_guardada.json (el mismo archivo que carga el boot)
## y muestra nombre, sexo, velocidad de texto, borde de menus, tipo de combate,
## animaciones, audio, controles y equipo.
func _cargar_resumen_partida() -> void:
	if not FileAccess.file_exists(RUTA_PARTIDA_DEBUG):
		_set_estado("No se encontro %s. El boot usara valores por defecto (sin equipo)." % RUTA_PARTIDA_DEBUG)
		return
	var archivo := FileAccess.open(RUTA_PARTIDA_DEBUG, FileAccess.READ)
	if archivo == null:
		_set_estado("No se pudo abrir %s" % RUTA_PARTIDA_DEBUG)
		return
	var datos = JSON.parse_string(archivo.get_as_text())
	archivo.close()
	if not (datos is Dictionary):
		_set_estado("JSON de partida invalido en %s" % RUTA_PARTIDA_DEBUG)
		return
	_datos_partida = datos

	var jugador: Dictionary = datos.get("jugador", {})
	var opciones: Dictionary = datos.get("opciones", {})
	var equipo: Array = datos.get("equipo_pokemon", [])

	# Solo la primera lectura inicializa los controles (el nombre puede venir
	# ya horneado en el .tscn si el editor re-guardo la escena con estado).
	if not _identidad_inicializada:
		_identidad_inicializada = true
		if campo_nombre_jugador.text.strip_edges().is_empty():
			campo_nombre_jugador.text = str(jugador.get("nombre", ""))
		opcion_sexo_jugador.select(1 if str(jugador.get("sexo", "M")) == "F" else 0)
		_seleccionar_por_id(opcion_vel_texto, int(opciones.get("velocidad_texto", 2)))
		campo_borde_menus.value = float(clampi(int(opciones.get("imagen_tipo", 1)), 1, 20))
		_seleccionar_por_id(opcion_tipo_combate, int(opciones.get("tipo_combate", 0)))
		check_animaciones.button_pressed = bool(opciones.get("animacion_combate", true))
		_seleccionar_por_id(opcion_audio, int(opciones.get("nivel_audio", 1)))
		_seleccionar_por_id(opcion_controles, int(opciones.get("controles", 0)))

	_set_estado("Partida leida: %s (%s), equipo %d/6." % [str(jugador.get("nombre", "?")), str(jugador.get("sexo", "?")), equipo.size()])
	_actualizar_preview()


func _al_seleccionar_entrenador(_indice: int) -> void:
	var seleccion := lista_entrenadores.get_selected_items()
	if seleccion.is_empty():
		return
	_cargar_entrenador_en_editor(lista_entrenadores.get_item_metadata(seleccion[0]))
	_actualizar_resumen()


func _on_origenes_tab_cambiado(_tab: int = 0) -> void:
	_actualizar_resumen()


func _on_restaurar_partida_presionado() -> void:
	_restaurar_equipo_partida()
	_actualizar_resumen()
	_set_estado("Equipo A restaurado desde la partida (copia en memoria; la partida no se modifica).")


func _on_guardar_prueba_presionado() -> void:
	var config := _recolectar_configuracion()
	if config == null:
		config = ScriptConfiguracion.new()
		config.escenario = _escenario_actual()
		config.terreno = opcion_terreno.get_selected_id()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CARPETA_TEMP))
	var resultado := ResourceSaver.save(config, RUTA_CONFIG_GUARDADA)
	if resultado != OK:
		_set_estado("Error al guardar la memoria de prueba (codigo %d)." % resultado)
		return
	_set_estado("Memoria de prueba guardada (equipo B: %d pokemon)." % _equipo_limpio(_slots_equipos[1]).size())


func _on_abrir_creador_presionado() -> void:
	solicitar_editor_instancia.emit(-1, {})
	_set_estado("Editor de instancias solicitado: pulsa alli 'Seleccionar' para traer los datos al primer slot libre del equipo activo.")


# ----------------------------------------------------------------------------
# DATOS DE LA UI -> RESOURCE
# ----------------------------------------------------------------------------

func _recolectar_configuracion() -> ScriptConfiguracion:
	var config := ScriptConfiguracion.new()
	config.tipo = SingletonScript.TipoBatalla.SALVAJE if boton_salvaje.button_pressed else SingletonScript.TipoBatalla.ENTRENADOR
	config.formato = SingletonScript.FormatoBatalla.DOBLE if boton_doble.button_pressed else SingletonScript.FormatoBatalla.SIMPLE
	config.ruleset = regla_combate.get_selected_id()
	config.escenario = _escenario_actual()
	config.terreno = opcion_terreno.get_selected_id()
	config.musica_id = "" if opcion_musica.selected == 0 else opcion_musica.get_item_text(opcion_musica.selected)
	config.ubicacion = campo_ubicacion.text.strip_edges()
	config.comentario = "Lanzado desde ventana nativa"
	config.origen_equipo = tab_origenes.current_tab
	config.equipo_partida_memoria = _equipo_limpio(_slots_equipos[0])
	config.equipo_prueba = _equipo_limpio(_slots_equipos[1])

	config.jugador_nombre = campo_nombre_jugador.text.strip_edges().to_upper()
	config.jugador_sexo = _sexo_jugador_actual()
	config.clima = opcion_clima.get_selected_id()
	config.opciones = {
		"velocidad_texto": opcion_vel_texto.get_selected_id(),
		"imagen_tipo": int(campo_borde_menus.value),
		"tipo_combate": opcion_tipo_combate.get_selected_id(),
		"animacion_combate": check_animaciones.button_pressed,
		"nivel_audio": opcion_audio.get_selected_id(),
		"controles": opcion_controles.get_selected_id(),
	}
	if config.es_salvaje():
		var salvaje: Dictionary = slot_salvaje.entrada()
		config.especie_salvaje = str(salvaje.get("nombre_interno", "")).strip_edges().to_upper()
		config.nivel_salvaje = maxi(int(salvaje.get("nivel", 5)), 1)
		config.salvaje_datos = salvaje
		return config

	# Modo entrenador: usa los datos editados en memoria; si no hay, la lista.
	var seleccion := lista_entrenadores.get_selected_items()
	if seleccion.is_empty() and _entrenador_editado.is_empty():
		return null
	if _entrenador_editado.is_empty():
		_entrenador_editado = lista_entrenadores.get_item_metadata(seleccion[0]).duplicate(true)
		_cargar_entrenador_en_editor(_entrenador_editado)
	config.entrenador_nombre = str(_entrenador_editado.get("nombre", ""))
	config.entrenador_clase = str(_entrenador_editado.get("clase_entrenador", ""))
	config.entrenador_datos = _entrenador_editado.duplicate(true)
	return config


func _set_estado(texto: String) -> void:
	etiqueta_estado.text = texto
	print("[DebugBatalla] ", texto)


# ----------------------------------------------------------------------------
# EQUIPOS DEL JUGADOR (A = copia de partida en memoria; B = prueba)
# ----------------------------------------------------------------------------

func _recoger_slots() -> void:
	var tab_partida: GridContainer = get_node("MainLayout/Contenido/PanelJugador/Margen/Equipo/Origenes/TabPartida")
	var tab_prueba: GridContainer = get_node("MainLayout/Contenido/PanelJugador/Margen/Equipo/Origenes/TabPrueba")
	var grid_entrenador: GridContainer = get_node("MainLayout/Contenido/PanelRival/Margen/Desplazamiento/Contenido/PanelEntrenador/Editor/EquipoEntrenador")
	for i in range(6):
		_slots_equipos[0].append(tab_partida.get_node("Slot%d" % (i + 1)))
		_slots_equipos[1].append(tab_prueba.get_node("Slot%d" % (i + 1)))
		_slots_entrenador.append(grid_entrenador.get_node("Slot%d" % (i + 1)))
	for equipo in range(2):
		_conectar_lista(_slots_equipos[equipo], equipo)
	_conectar_lista(_slots_entrenador, 2)
	slot_salvaje.agregar_o_editar_solicitado.connect(_abrir_editor_para.bind(slot_salvaje))
	slot_salvaje.modificado.connect(_refrescar_slot_salvaje)
	boton_editor_entrenadores.pressed.connect(func(): solicitar_editor_entrenadores.emit())
	boton_releer_entrenadores.pressed.connect(_releer_entrenadores)
	tab_origenes.set_tab_title(0, "Equipo Partida")
	tab_origenes.set_tab_title(1, "Equipo Debug")


## Conecta una lista de 6 slots horizontales. lista_id: 0 equipo A del jugador,
## 1 equipo B de prueba, 2 equipo del entrenador rival.
func _conectar_lista(slots: Array, lista_id: int) -> void:
	for i in range(slots.size()):
		var slot = slots[i]
		slot.modificado.connect(_al_cambiar_lista.bind(lista_id))
		slot.agregar_o_editar_solicitado.connect(_abrir_editor_para.bind(slot))
		slot.mover_arriba_solicitado.connect(_mover_en_lista.bind(lista_id, i, -1))
		slot.mover_abajo_solicitado.connect(_mover_en_lista.bind(lista_id, i, 1))


func _slots_de_lista(lista_id: int) -> Array:
	return _slots_entrenador if lista_id == 2 else _slots_equipos[lista_id]


## Tras un borrado o edicion: compacta (sin huecos) y refresca acciones.
func _al_cambiar_lista(lista_id: int) -> void:
	var slots := _slots_de_lista(lista_id)
	_repartir(slots, _entradas_de(slots))
	if lista_id == 2:
		_on_slot_entrenador_modificado(-1)
	else:
		_actualizar_resumen()


func _entradas_de(slots: Array) -> Array:
	var entradas: Array = []
	for slot in slots:
		if not slot.esta_vacio():
			entradas.append(slot.entrada())
	return entradas


## Escribe las entradas en orden (sin huecos) y decide que boton queda activo
## en cada slot: mover solo dentro de la zona ocupada, el boton de agregar en
## los ocupados (editar) y en el primer vacio (agregar); el resto inactivo.
func _repartir(slots: Array, entradas: Array) -> void:
	var n := entradas.size()
	for i in range(slots.size()):
		slots[i].establecer(entradas[i] if i < n else {})
		slots[i].configurar_acciones(i > 0, i < n - 1, i <= n)


## Mueve la entrada del indice dado delta posiciones dentro de la zona
## ocupada. Nunca deja huecos: fuera de rango o hacia un vacio, no hace nada.
func _mover_en_lista(lista_id: int, indice: int, delta: int) -> void:
	var slots := _slots_de_lista(lista_id)
	var entradas := _entradas_de(slots)
	var destino := indice + delta
	if indice >= entradas.size() or destino < 0 or destino >= entradas.size():
		return
	var temporal = entradas[indice]
	entradas[indice] = entradas[destino]
	entradas[destino] = temporal
	_repartir(slots, entradas)
	slots[destino].grab_focus()
	if lista_id == 2:
		_on_slot_entrenador_modificado(-1)
	else:
		_actualizar_resumen()


## Boton de agregar/editar de un slot: abre el Editor de Instancia de Pokemon
## (via plugin.gd). Los datos del slot mandan siempre; el id de BBDD, si lo
## hay, solo preselecciona esa fila en la lista del editor.
func _abrir_editor_para(slot) -> void:
	_solicitante = slot
	var entrada: Dictionary = {} if slot.esta_vacio() else slot.entrada()
	var id := int(entrada.get("id", -1))
	solicitar_editor_instancia.emit(id, entrada)
	_set_estado("Editor de instancias: pulsa alli 'Seleccionar' para %s el slot." % ("editar" if not slot.esta_vacio() else "llenar"))


func _lista_de_slot(slot) -> int:
	if _slots_equipos[0].has(slot):
		return 0
	if _slots_equipos[1].has(slot):
		return 1
	if _slots_entrenador.has(slot):
		return 2
	return -1


func _refrescar_slot_salvaje() -> void:
	slot_salvaje.configurar_acciones(false, false, true)
	_actualizar_resumen()


func _releer_entrenadores() -> void:
	_cargar_entrenadores()
	_set_estado("Lista de entrenadores releida desde el JSON.")


## Controles de identidad del jugador (solo para la prueba; la partida no se
## escribe). El sexo cambia el sprite de espalda en la batalla y la preview.
func _configurar_controles_jugador() -> void:
	opcion_sexo_jugador.clear()
	opcion_sexo_jugador.add_item("M", 0)
	opcion_sexo_jugador.add_item("F", 1)
	campo_nombre_jugador.text_changed.connect(func(_texto): _actualizar_resumen())
	opcion_sexo_jugador.item_selected.connect(func(_indice): _actualizar_resumen())
	_configurar_controles_opciones()


## Opciones de batalla de la partida, editables SOLO para la prueba. Los ids
## replican los enums de singleton.gd (VelocidadTexto, TipoCombate, Sonido,
## Controles); el borde de menus admite 1..20 (UI/menu_box_%d.png).
func _configurar_controles_opciones() -> void:
	opcion_vel_texto.clear()
	opcion_vel_texto.add_item("LENTA", 1)
	opcion_vel_texto.add_item("MEDIA", 2)
	opcion_vel_texto.add_item("RAPIDA", 3)
	opcion_tipo_combate.clear()
	opcion_tipo_combate.add_item("CAMBIAR", 0)
	opcion_tipo_combate.add_item("MANTENER", 1)
	opcion_audio.clear()
	opcion_audio.add_item("NO", 0)
	opcion_audio.add_item("BAJO", 1)
	opcion_audio.add_item("NORMAL", 2)
	opcion_controles.clear()
	opcion_controles.add_item("NORMAL", 0)
	opcion_controles.add_item("LR", 1)
	opcion_controles.add_item("L=A", 2)
	opcion_clima.clear()
	opcion_clima.add_item("NINGUNO", 0)
	opcion_clima.add_item("SOLEADO", 1)
	opcion_clima.add_item("LLUVIA", 2)
	opcion_clima.add_item("TORMENTA DE ARENA", 3)
	opcion_clima.add_item("GRANIZO", 4)
	opcion_clima.select(0)
	opcion_clima.item_selected.connect(func(_indice): _actualizar_resumen())
	campo_borde_menus.value_changed.connect(func(_valor): _actualizar_resumen())


func _seleccionar_por_id(opcion: OptionButton, id: int) -> void:
	for i in range(opcion.item_count):
		if opcion.get_item_id(i) == id:
			opcion.select(i)
			return


func _sexo_jugador_actual() -> String:
	return "F" if opcion_sexo_jugador.selected == 1 else "M"


func _slots_equipo_activo() -> Array:
	return _slots_equipos[1] if tab_origenes.current_tab == 1 else _slots_equipos[0]


## Reconstruye el equipo A (copia en memoria) desde la partida.
func _restaurar_equipo_partida() -> void:
	var entradas: Array = _datos_partida.get("equipo_pokemon", [])
	_repartir(_slots_equipos[0], entradas.duplicate(true))


## Restaura el estado completo de la ventana desde el Resource guardado la ultima
## vez que se lanzo o guardo una prueba. Si no existe, cae al fallback de la partida.
func _restaurar_configuracion_guardada() -> void:
	if not ResourceLoader.exists(RUTA_CONFIG_GUARDADA):
		_restaurar_equipo_partida()
		return
	var config := load(RUTA_CONFIG_GUARDADA) as ScriptConfiguracion
	if config == null:
		_restaurar_equipo_partida()
		return

	# Tipo de encuentro y formato (set_pressed_no_signal evita disparar callbacks
	# antes de que toda la UI este lista; _actualizar_modo_encuentro() se llama
	# al final de _ready() para hacer el sync final de visibilidad y disabled).
	boton_salvaje.set_pressed_no_signal(config.es_salvaje())
	boton_entrenador.set_pressed_no_signal(config.es_entrenador())
	boton_simple.set_pressed_no_signal(config.formato != SingletonScript.FormatoBatalla.DOBLE)
	boton_doble.set_pressed_no_signal(config.formato == SingletonScript.FormatoBatalla.DOBLE)

	# Ruleset, escenario, terreno, clima. Una configuración antigua (sin
	# escenario) se migra desde su tema gráfico legado.
	_seleccionar_por_id(regla_combate, config.ruleset)
	var escenario := config.escenario
	if escenario.is_empty():
		escenario = ScriptConfiguracion.escenario_desde_tema(config.tema_grafico)
	_seleccionar_escenario(escenario)
	_seleccionar_por_id(opcion_terreno, config.terreno)
	_seleccionar_por_id(opcion_clima, config.clima)

	# Musica: el OptionButton usa texto como clave, no un id numerico.
	var idx_musica := 0
	if not config.musica_id.is_empty():
		for i in range(opcion_musica.item_count):
			if opcion_musica.get_item_text(i) == config.musica_id:
				idx_musica = i
				break
	opcion_musica.select(idx_musica)

	# Opciones de partida editables para la prueba
	if not config.opciones.is_empty():
		_seleccionar_por_id(opcion_vel_texto, int(config.opciones.get("velocidad_texto", 2)))
		campo_borde_menus.value = float(clampi(int(config.opciones.get("imagen_tipo", 1)), 1, 20))
		_seleccionar_por_id(opcion_tipo_combate, int(config.opciones.get("tipo_combate", 0)))
		check_animaciones.button_pressed = bool(config.opciones.get("animacion_combate", true))
		_seleccionar_por_id(opcion_audio, int(config.opciones.get("nivel_audio", 1)))
		_seleccionar_por_id(opcion_controles, int(config.opciones.get("controles", 0)))

	# Identidad del jugador (sobrescribe lo que puso _cargar_resumen_partida)
	if not config.jugador_nombre.is_empty():
		campo_nombre_jugador.text = config.jugador_nombre
	if config.jugador_sexo == "M" or config.jugador_sexo == "F":
		opcion_sexo_jugador.select(1 if config.jugador_sexo == "F" else 0)

	# Equipos: A desde el config si tenia datos, si no desde la partida (primera vez)
	if not config.equipo_partida_memoria.is_empty():
		_repartir(_slots_equipos[0], config.equipo_partida_memoria.duplicate())
	else:
		_restaurar_equipo_partida()
	_repartir(_slots_equipos[1], config.equipo_prueba.duplicate())
	tab_origenes.current_tab = config.origen_equipo

	# Slot salvaje: primero el snapshot completo, si no, solo especie+nivel
	if not config.salvaje_datos.is_empty():
		slot_salvaje.establecer(config.salvaje_datos)
	elif not config.especie_salvaje.is_empty():
		slot_salvaje.establecer({"nombre_interno": config.especie_salvaje, "nivel": config.nivel_salvaje})
	campo_ubicacion.text = config.ubicacion

	# Entrenador rival: preseleccionar en lista y cargar campos editables
	if not config.entrenador_datos.is_empty():
		var nombre_b := config.entrenador_nombre.strip_edges().to_upper()
		for i in range(lista_entrenadores.item_count):
			var meta: Dictionary = lista_entrenadores.get_item_metadata(i)
			if str(meta.get("nombre", "")).strip_edges().to_upper() == nombre_b:
				lista_entrenadores.select(i)
				lista_entrenadores.ensure_current_is_visible()
				break
		_cargar_entrenador_en_editor(config.entrenador_datos)

	_set_estado("Configuracion restaurada desde la ultima prueba.")


## Copia sin slots vacios, lista para el Resource/batalla.
func _equipo_limpio(slots: Array) -> Array[Dictionary]:
	var limpio: Array[Dictionary] = []
	for slot in slots:
		var entrada: Dictionary = slot.entrada()
		if not entrada.is_empty():
			limpio.append(entrada)
	return limpio


# ----------------------------------------------------------------------------
# SELECTOR DE POKEMON (autogenerador reutilizable)
# ----------------------------------------------------------------------------

## Abre el selector vinculado al slot que pidio agregar.
func _abrir_selector_para(slot) -> void:
	_solicitante = slot
	selector.popup_centered()


## Recibe la entrada autogenerada por el selector y la coloca en el slot
## solicitante (equipo A, B o del entrenador), refrescando lo que dependa.
func _on_pokemon_elegido(entrada: Dictionary) -> void:
	if not is_instance_valid(_solicitante) or entrada.is_empty():
		return
	var destino = _solicitante
	destino.establecer(entrada)
	var lista_id := _lista_de_slot(destino)
	if lista_id >= 0:
		var slots := _slots_de_lista(lista_id)
		# Posicion donde quedara la entrada tras compactar: cantidad de slots
		# ocupados por delante del destino.
		var indice_final := 0
		for slot in slots:
			if slot == destino:
				break
			if not slot.esta_vacio():
				indice_final += 1
		_al_cambiar_lista(lista_id)
		# El solicitante se CONSERVA apuntando al slot donde quedo la entrada:
		# un segundo 'Seleccionar' reescribe el mismo poke y los datos nunca
		# caen en otro slot. Cada nuevo '+' o selector lo reapunta.
		_solicitante = slots[indice_final]
	elif destino == slot_salvaje:
		_refrescar_slot_salvaje()
	else:
		_actualizar_resumen()


## API publica: recibe el snapshot completo del Editor de Instancia de Pokemon
## (senal datos_pokemon_solicitados, conectada por plugin.gd). La instancia
## puede no estar guardada en la BBDD: viajan todos los datos del formulario.
## Destino: el slot que pidio agregar, o el primer slot libre del equipo activo.
func recibir_datos_pokemon(datos: Dictionary) -> void:
	if datos.is_empty() or str(datos.get("nombre_interno", "")).strip_edges().is_empty():
		_set_estado("El editor envio datos sin especie; ningun slot modificado.")
		return
	var destino = _solicitante if is_instance_valid(_solicitante) else _primer_slot_vacio()
	if destino == null:
		_set_estado("Sin slots libres en el equipo activo para recibir la instancia.")
		return
	_solicitante = destino
	_on_pokemon_elegido(datos)
	_set_estado("Instancia %s Nv.%d recibida del editor." % [str(datos.get("nombre_interno", "?")), int(datos.get("nivel", 0))])


## Primer slot vacio del equipo activo (pestana visible), o null si esta lleno.
func _primer_slot_vacio():
	for slot in _slots_equipo_activo():
		if slot.esta_vacio():
			return slot
	return null


# ----------------------------------------------------------------------------
# ENTRENADOR RIVAL EDITABLE (copia en memoria del registro de la lista)
# ----------------------------------------------------------------------------

## Carga el registro resumido de la lista en el editor (campos + equipo).
## Conserva el registro original aparte para poder Restaurar de la lista
## aunque se hayan editado los campos.
func _cargar_entrenador_en_editor(registro: Dictionary) -> void:
	_entrenador_registro = registro
	_entrenador_editado = registro.duplicate(true)
	campo_entrenador_nombre.text = str(_entrenador_editado.get("nombre", ""))
	campo_entrenador_clase.text = str(_entrenador_editado.get("clase_entrenador", ""))
	campo_entrenador_sprite.value = float(int(_entrenador_editado.get("num_sprite", 1)))
	campo_entrenador_musica.text = str(_entrenador_editado.get("musica_id", ""))
	_refrescar_slots_entrenador()
	etiqueta_entrenador.text = "%s  /  %s  /  %d POKEMON" % [
		str(_entrenador_editado.get("nombre", "?")),
		str(_entrenador_editado.get("clase_entrenador", "?")),
		_entrenador_editado.get("pokemon", []).size(),
	]


func _refrescar_slots_entrenador() -> void:
	var pokemons: Array = _entrenador_editado.get("pokemon", [])
	_repartir(_slots_entrenador, pokemons.duplicate(true))


## Los campos editados solo tocan la copia en memoria (nunca el JSON de la lista).
func _on_entrenador_campo_cambiado(_valor: Variant = null) -> void:
	if _entrenador_editado.is_empty():
		return
	_entrenador_editado["nombre"] = campo_entrenador_nombre.text.strip_edges().to_upper()
	_entrenador_editado["clase_entrenador"] = campo_entrenador_clase.text.strip_edges().to_upper()
	_entrenador_editado["num_sprite"] = int(campo_entrenador_sprite.value)
	_entrenador_editado["musica_id"] = campo_entrenador_musica.text.strip_edges().to_upper()
	_actualizar_resumen()


## Recompone el equipo del entrenador desde los slots, conservando las claves
## extra de cada entrada (objeto, movimientos, ...).
func _on_slot_entrenador_modificado(_indice: int) -> void:
	if _entrenador_editado.is_empty():
		return
	var pokemons: Array = []
	for slot in _slots_entrenador:
		var entrada: Dictionary = slot.entrada()
		if not entrada.is_empty():
			pokemons.append(entrada)
	_entrenador_editado["pokemon"] = pokemons
	_actualizar_resumen()


func _on_entrenador_restaurar_presionado() -> void:
	if _entrenador_registro.is_empty():
		_set_estado("Selecciona un entrenador de la lista primero.")
		return
	_cargar_entrenador_en_editor(_entrenador_registro)
	_actualizar_resumen()
	_set_estado("Datos del entrenador restaurados desde la lista.")


## API pública: recibe el registro de un entrenador desde el Editor de Entrenadores,
## cambia al modo entrenador y lo precarga listo para probar.
func cargar_entrenador_para_prueba(registro: Dictionary) -> void:
	boton_salvaje.set_pressed_no_signal(false)
	boton_entrenador.set_pressed_no_signal(true)
	_actualizar_modo_encuentro()

	# Intentar preseleccionar la fila en lista_entrenadores (por id o nombre).
	var id_buscado := str(registro.get("id", ""))
	var nombre_buscado := str(registro.get("nombre", "")).strip_edges().to_upper()
	for i in range(lista_entrenadores.item_count):
		var meta: Dictionary = lista_entrenadores.get_item_metadata(i)
		var coincide_id := not id_buscado.is_empty() and str(meta.get("id", "")) == id_buscado
		var coincide_nombre := str(meta.get("nombre", "")).strip_edges().to_upper() == nombre_buscado
		if coincide_id or coincide_nombre:
			lista_entrenadores.select(i)
			lista_entrenadores.ensure_current_is_visible()
			break

	_cargar_entrenador_en_editor(registro)
	_actualizar_resumen()
	_set_estado("Entrenador '%s' (%s) cargado desde el Editor de Entrenadores." % [
		str(registro.get("nombre", "?")),
		str(registro.get("clase_entrenador", "?")),
	])


# ----------------------------------------------------------------------------
# PREVIEW ESTATICA DE LA ESCENA DE BATALLA
# ----------------------------------------------------------------------------

## Refresca fondo/suelo segun el tema y los sprites (rival frente o entrenador,
## jugador de espalda con el primer pokemon del equipo, o el jugador si no hay).
func _actualizar_preview() -> void:
	var config := _recolectar_configuracion()
	if config == null:
		config = ScriptConfiguracion.new()
		config.escenario = _escenario_actual()

	var texturas: Dictionary = EscenarioBatalla.rutas(config.escenario)
	borde_menu_preview.texture = MenuBoxManager.get_menu_box_texture(int(campo_borde_menus.value))
	textura_fondo.texture = _textura_segura(str(texturas.get("fondo", "")))
	var textura_suelo := _textura_segura(str(texturas.get("suelo", "")))
	suelo_arriba.texture = textura_suelo
	suelo_abajo.texture = textura_suelo

	# Zona rival: entrenador (frame num_sprite) + su primer pokemon, o el salvaje
	var pokemons_rival: Array = []
	if config.es_entrenador():
		trainer_rival.visible = true
		trainer_rival.texture = _textura_entrenador_rival(config)
		pokemons_rival = config.entrenador_datos.get("pokemon", [])
	else:
		trainer_rival.visible = false
	if pokemons_rival.size() > 0:
		poke_rival.visible = true
		poke_rival.texture = _textura_pokemon(str(pokemons_rival[0].get("nombre_interno", "")), true)
	else:
		poke_rival.visible = config.es_salvaje()
		poke_rival.texture = _textura_pokemon(config.especie_salvaje, true)

	# Zona jugador: pokemon de espalda del equipo activo (pestaña visible); si no hay, el jugador
	var equipo: Array = []
	for slot in _slots_equipo_activo():
		var entrada: Dictionary = slot.entrada()
		if not entrada.is_empty():
			equipo.append(entrada)
	# Jugador: entrenador SIEMPRE visible junto a su primer poke, espejo del
	# lado rival (entrenador + poke).
	trainer_jugador.visible = true
	trainer_jugador.texture = _textura_jugador(_sexo_jugador_actual())
	if equipo.is_empty():
		poke_jugador.visible = false
	else:
		poke_jugador.visible = true
		poke_jugador.texture = _textura_pokemon(str(equipo[0].get("nombre_interno", "")), false)


func _textura_segura(ruta: String) -> Texture2D:
	if ruta.is_empty() or not ResourceLoader.exists(ruta):
		return null
	return load(ruta) as Texture2D


func _textura_pokemon(nombre_interno: String, es_frente: bool) -> Texture2D:
	var nombre := nombre_interno.strip_edges().to_upper()
	var carpeta := "front" if es_frente else "back"
	var textura := _textura_segura("res://graficos/pokemon/%s/%s.png" % [carpeta, nombre])
	if textura == null:
		textura = _placeholder_pokemon(es_frente)
	return textura


## Placeholder 64x64 igual al de batalla.gd (magenta frente / cian espalda).
func _placeholder_pokemon(es_frente: bool) -> Texture2D:
	var imagen := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	imagen.fill(Color.MAGENTA if es_frente else Color.CYAN)
	for i in range(20):
		var offset := 22 + i
		if offset < 64:
			imagen.set_pixel(offset, offset, Color.WHITE)
			imagen.set_pixel(63 - offset, offset, Color.WHITE)
	return ImageTexture.create_from_image(imagen)


## Frame num_sprite del spritesheet de entrenadores (graficos/trainers64).
func _textura_entrenador_rival(config: ScriptConfiguracion) -> Texture2D:
	var frames := load("res://graficos/trainers64/entrenadores_64.tres") as SpriteFrames
	if frames == null or frames.get_frame_count("default") == 0:
		return _placeholder_pokemon(true)
	var num_sprite := int(config.entrenador_datos.get("num_sprite", 1))
	return frames.get_frame_texture("default", clampi(num_sprite, 0, frames.get_frame_count("default") - 1))


## Frame 0 del spritesheet del protagonista segun sexo (jugador_masculino/femenino).
func _textura_jugador(sexo: String) -> Texture2D:
	var ruta := "res://escenas/batalla/jugador_femenino.tres" if sexo == "F" else "res://escenas/batalla/jugador_masculino.tres"
	var frames := load(ruta) as SpriteFrames
	if frames == null or frames.get_frame_count("default") == 0:
		return null
	return frames.get_frame_texture("default", 0)


# ----------------------------------------------------------------------------
# ACCION PRINCIPAL: guardar Resource y lanzar la instancia de juego
# ----------------------------------------------------------------------------

func _preparar_batalla() -> void:
	var config := _recolectar_configuracion()
	if config == null:
		_set_estado("Selecciona un entrenador de la lista antes de preparar la batalla.")
		return

	var errores := _validar_configuracion(config)
	if not errores.is_empty():
		_set_estado("Configuracion invalida: %s" % ", ".join(errores))
		return

	var equipo_activo := config.equipo_prueba if config.origen_equipo == 1 else config.equipo_partida_memoria
	if equipo_activo.is_empty():
		_set_estado("AVISO: el equipo activo esta vacio; la batalla ira sin Pokemon del jugador.")

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CARPETA_TEMP))
	var resultado := ResourceSaver.save(config, RUTA_CONFIG_GUARDADA)
	if resultado != OK:
		_set_estado("Error al guardar el Resource (codigo %d)." % resultado)
		return

	_set_estado("Resource guardado (%s). Lanzando instancia de juego..." % config.resumen())
	# Un frame para que el label se pinte antes de ceder el control.
	await get_tree().process_frame
	if Engine.is_editor_hint():
		# Proceso editor: lanza una instancia de juego con la escena boot.
		EditorInterface.play_custom_scene(RUTA_ESCENA_BOOT)
	else:
		# Ejecucion directa (F6): la boot reemplaza esta escena en el mismo proceso.
		get_tree().change_scene_to_file(RUTA_ESCENA_BOOT)


func _validar_configuracion(config: ScriptConfiguracion) -> PackedStringArray:
	var errores := PackedStringArray()
	if config.es_salvaje() and config.especie_salvaje.is_empty():
		errores.append("especie vacia")
	if config.es_entrenador() and config.entrenador_nombre.is_empty():
		errores.append("entrenador sin seleccionar")
	if config.es_salvaje() and config.formato == SingletonScript.FormatoBatalla.DOBLE:
		errores.append("batalla salvaje DOBLE no soportada; usa SIMPLE")
	return errores


func _cargar_entrenadores() -> void:
	_datos_entrenadores.clear()
	if not FileAccess.file_exists(RUTA_ENTRENADORES_JSON):
		_set_estado("No se encontro %s" % RUTA_ENTRENADORES_JSON)
		return
	var archivo := FileAccess.open(RUTA_ENTRENADORES_JSON, FileAccess.READ)
	if archivo == null:
		return
	var datos = JSON.parse_string(archivo.get_as_text())
	archivo.close()
	if datos is Array:
		_datos_entrenadores = datos

	lista_entrenadores.clear()
	for entrenador in _datos_entrenadores:
		var texto := "%s  |  %s  |  %d POKEMON" % [
			str(entrenador.get("nombre", "SIN NOMBRE")),
			str(entrenador.get("clase_entrenador", "ENTRENADOR")),
			entrenador.get("pokemon", []).size(),
		]
		lista_entrenadores.add_item(texto)
		lista_entrenadores.set_item_metadata(lista_entrenadores.item_count - 1, entrenador)


## Puebla los selectores de escenario (ids de EscenarioBatalla) y terreno
## (AUTOMATICO + EscenarioBatalla.Terreno).
func _poblar_escenarios() -> void:
	opcion_escenario.clear()
	for id in EscenarioBatalla.ids_escenarios():
		opcion_escenario.add_item(id)
	_seleccionar_escenario(ESCENARIO_POR_DEFECTO)
	opcion_terreno.clear()
	opcion_terreno.add_item("AUTOMATICO (SEGUN ESCENARIO)", -1)
	for nombre: String in EscenarioBatalla.Terreno.keys():
		opcion_terreno.add_item(nombre, int(EscenarioBatalla.Terreno[nombre]))
	opcion_terreno.select(0)


## Id de escenario elegido (texto del item).
func _escenario_actual() -> String:
	if opcion_escenario.selected < 0:
		return ESCENARIO_POR_DEFECTO
	return opcion_escenario.get_item_text(opcion_escenario.selected)


func _seleccionar_escenario(id: String) -> void:
	for i in range(opcion_escenario.item_count):
		if opcion_escenario.get_item_text(i) == id:
			opcion_escenario.select(i)
			return


## Puebla el selector de musica con las claves registradas en temas_musicales.json.
## El item 0 "(AUTOMATICA SEGUN RIVAL)" ya viene declarado en el .tscn.
func _cargar_temas_musicales() -> void:
	if not FileAccess.file_exists(RUTA_TEMAS_MUSICALES):
		_set_estado("No se encontro %s" % RUTA_TEMAS_MUSICALES)
		return
	var archivo := FileAccess.open(RUTA_TEMAS_MUSICALES, FileAccess.READ)
	if archivo == null:
		return
	var datos = JSON.parse_string(archivo.get_as_text())
	archivo.close()
	if not (datos is Dictionary):
		return
	var temas: Dictionary = datos.get("temas", {})
	for clave in temas.keys():
		opcion_musica.add_item(str(clave))
