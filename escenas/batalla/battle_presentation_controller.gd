extends RefCounted
class_name BattlePresentationController
## Etapa 4 del cambio SDD `2026-09-14-battle-architecture-split`: dueño de
## los menús, la caja de texto y la mochila de batalla — lo que antes
## `batalla.gd` instanciaba y tocaba directamente para mostrar/ocultar UI.
## Mismo patrón pragmático de las etapas 1-3: mantiene una referencia de
## vuelta a `batalla` (composition root) para lo que las etapas siguientes
## todavía no extrajeron (`add_child`, `fase_input()`, estado de combate).
##
## Alcance de esta etapa (ver tasks.md): menú principal, menú de
## movimientos, pantalla de equipo, caja de texto, mochila. La coordinación
## fina de los cuadros de PS (barra de EXP, animación de subida de nivel —
## `cuadro_ps_jugador.set_experiencia()`/`animar_experiencia()`/etc.) queda
## fuera a propósito: está entrelazada con la lógica de experiencia/subida
## de nivel (más territorio de `BattleResultController`, Etapa 5) y
## `BattleSlot` ya la encapsula razonablemente; moverla ahora habría forzado
## un rediseño más grande del que se propone esta etapa.

var _b: BattleSceneController  # batalla.gd — composition root (ver nota de cabecera)

var menu1
var menu_movs
var pantalla_equipo
var caja_texto: CajaTextoBatalla
var mochila_batalla: MochilaUI = null

var _telon: ColorRect = null

const SCN_ENTRADA_NOMBRE: PackedScene = preload("res://escenas/entrada_nombre/entrada_nombre.tscn")
## Ventana SÍ/NO de batalla: a la derecha, justo encima de la caja de texto.
const POSICION_MENU_SI_NO := Vector2(184, 64)
## Máximo de caracteres de un mote (pokeruby POKEMON_NAME_LENGTH).
const MAX_CARACTERES_MOTE := 10
## entrada_nombre.gd TipoObjetivo.POKEMON / SexoPokemon.
const ENTRADA_NOMBRE_POKEMON := 2
const ENTRADA_NOMBRE_SEXO := {"M": 1, "F": 2}

## Emitida por los handlers de la pantalla de nombre (ver pedir_mote()).
signal _nombre_introducido(nombre: String)


func _init(batalla: BattleSceneController) -> void:
	_b = batalla


## Instancia menú principal, menú de movimientos y pantalla de equipo, y los
## agrega como hijos de `batalla`. `caja_texto`/`cursor` son nodos de la
## escena de `batalla.tscn` (`@onready` en `batalla.gd`); esta función solo
## los conecta, no los crea.
func inicializar(caja_texto_: CajaTextoBatalla, cursor: AnimatedSprite2D, scn_menu1: PackedScene, scn_menu_movs: PackedScene, scn_pantalla_equipo: PackedScene) -> void:
	if scn_pantalla_equipo == null or not scn_pantalla_equipo.can_instantiate():
		push_error("Battle team scene is not constructible: res://UI/equipo/pantalla-equipo.tscn")
		return
	caja_texto = caja_texto_
	caja_texto.set_cursor(cursor)

	menu1 = scn_menu1.instantiate()
	menu1.visible = false
	menu1.z_index += 1
	_b.add_child(menu1)

	menu_movs = scn_menu_movs.instantiate()
	menu_movs.visible = false
	menu_movs.z_index += 1
	_b.add_child(menu_movs)

	pantalla_equipo = scn_pantalla_equipo.instantiate()
	pantalla_equipo.visible = false
	pantalla_equipo.z_index += 1
	_b.add_child(pantalla_equipo)

	if SistemaGuardado and SistemaGuardado.datos_vivos and SistemaGuardado.datos_vivos.opciones:
		var tipo: int = SistemaGuardado.datos_vivos.opciones.imagen_tipo
		var menu_box_manager = preload("res://scripts/clases/MenuBoxManager.gd")
		menu_box_manager.apply_texture_to_ninepatch(menu1, tipo)
		menu_box_manager.apply_texture_to_ninepatch(menu_movs, tipo)
		menu_box_manager.apply_texture_to_ninepatch(menu_movs.get_node("CuadroPPs"), tipo)

	var canvas_telon := CanvasLayer.new()
	canvas_telon.layer = 100
	_b.add_child(canvas_telon)
	_telon = ColorRect.new()
	_telon.color = Color.BLACK
	_telon.modulate.a = 0.0
	_telon.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Sin esto el telón (capa 100) se come los toques y el TouchGamepad (capa 20)
	# deja de responder durante toda la batalla.
	_telon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_telon.add_child(_telon)


func mostrar_menu_principal() -> void:
	caja_texto.descartar_lectura_pendiente()
	menu1.visible = true
	menu1.activo = true


func ocultar_menu_principal() -> void:
	menu1.activo = false
	menu1.visible = false


func mostrar_menu_movimientos() -> void:
	caja_texto.descartar_lectura_pendiente()
	menu_movs.visible = true
	menu_movs.activo = true


## Muestra texto con la animación de tipeo configurada. Awaiteable: espera a
## que termine de escribirse (no a que el jugador confirme — eso es
## esperar_confirmacion()).
func mostrar_texto(mensaje: String = "", instantaneo: bool = true, callback: Callable = Callable()) -> void:
	await caja_texto.mostrar_texto(mensaje, instantaneo, callback)


## Pausa de lectura diferida (waitmessage 64): espera lo que falte para que
## el último mensaje haya estado 64 frames a la vista.
func tiene_lectura_pendiente() -> bool:
	return caja_texto != null and caja_texto.tiene_lectura_pendiente()


func esperar_lectura_pendiente() -> void:
	await caja_texto.esperar_lectura_pendiente()


## Espera a que el jugador confirme (sin callback propio del widget).
func esperar_confirmacion(mostrar_cursor: bool = true) -> void:
	await caja_texto.esperar_input_continuar(Callable(), mostrar_cursor)


## Arranca la espera de confirmación con un callback del widget (fire and
## forget — el propio caja_texto invoca `callback` cuando el jugador
## confirma).
func esperar_confirmacion_con_callback(callback: Callable, mostrar_cursor: bool = true) -> void:
	caja_texto.esperar_input_continuar(callback, mostrar_cursor)


## Fija el texto de golpe, sin animación de tipeo (mensajes de resultado
## instantáneos: huida, derrota, cambio de Pokémon, etc.).
func set_texto_instantaneo(texto: String) -> void:
	caja_texto.text = texto


func limpiar_texto() -> void:
	if caja_texto.has_method("limpiar"):
		caja_texto.limpiar()
	else:
		caja_texto.text = ""
		caja_texto.visible_ratio = 0.0


func oscurecer(duracion: float = 0.4) -> void:
	if _telon == null:
		return
	var tw := _b.create_tween()
	tw.tween_property(_telon, "modulate:a", 1.0, duracion)
	await tw.finished


func aclarar(duracion: float = 0.4) -> void:
	if _telon == null:
		return
	var tw := _b.create_tween()
	tw.tween_property(_telon, "modulate:a", 0.0, duracion)
	await tw.finished


## Instancia la mochila de batalla y activa el modo batalla.
## on_cerrada: llamado cuando el jugador elige "CERRAR LA MOCHILA" sin objeto.
## on_objeto_listo: llamado con el item cuando el jugador confirma USAR.
## oscurecer_antes = false si la pantalla ya está en negro (vuelta desde la
## pantalla de equipo tras usar un objeto sin efecto o cancelar).
func abrir_mochila(on_cerrada: Callable, on_objeto_listo: Callable, oscurecer_antes: bool = true) -> void:
	_garantizar_items_prueba_en_mochila()
	if oscurecer_antes:
		await oscurecer()
	mochila_batalla = preload("res://UI/mochila/mochila.tscn").instantiate() as MochilaUI
	_b.add_child(mochila_batalla)
	# La mochila debe tapar toda la UI de batalla (CajaDialogo y menús viven
	# en z_index 1); sin esto el cuadro de diálogo queda dibujado encima.
	mochila_batalla.z_index = 5
	mochila_batalla.mochila_cerrada.connect(on_cerrada)
	mochila_batalla.objeto_listo_para_usar.connect(on_objeto_listo)
	mochila_batalla.activar_modo_batalla(Callable(self, "oscurecer"))
	await aclarar()


## Garantiza que SistemaGuardado.datos_vivos tiene la estructura completa de
## mochila (bolsillos 0-4) antes de instanciar la escena. Si datos_vivos es
## null (no debería ocurrir, pero sí puede si ninguna partida fue cargada y
## el autoload tuvo un error de inicialización), se crea uno limpio.
func _garantizar_items_prueba_en_mochila() -> void:
	if not SistemaGuardado:
		return
	if SistemaGuardado.datos_vivos == null:
		SistemaGuardado.datos_vivos = EstructuraGuardado.new()
	SistemaGuardado.inicializar_mochila_estructura()


## DisplayItemMessageOnField: mensaje sobre la mochila abierta hasta pulsar A/B (la caja de batalla, por encima de ella).
func mostrar_mensaje_sobre_mochila(mensaje: String) -> void:
	var caja: Node2D = caja_texto.get_parent() as Node2D
	var z_previo: int = caja.z_index
	caja.z_index = mochila_batalla.z_index + 1
	# \w separa las pantallas de un texto de tres líneas (la caja de batalla tiene dos).
	for pagina: String in mensaje.split("\\w"):
		await mostrar_texto(pagina.trim_prefix("\\l").trim_prefix("\\n"), false)
		await esperar_confirmacion()
	limpiar_texto()
	caja.z_index = z_previo


func cerrar_mochila() -> void:
	if is_instance_valid(mochila_batalla):
		mochila_batalla.queue_free()
	mochila_batalla = null


## Muestra la ventana SÍ/NO (UI/MenuConfirmacion.gd) sobre la caja de texto y
## espera la respuesta. CANCELAR equivale a NO.
func preguntar_si_no(posicion: Vector2 = POSICION_MENU_SI_NO) -> bool:
	caja_texto.descartar_lectura_pendiente()
	var menu := MenuConfirmacion.new()
	menu.z_index = 6
	_b.add_child(menu)
	menu.crear_menu(posicion)
	var respuesta: String = await menu.opcion_seleccionada
	menu.queue_free()
	return respuesta == "Y"


## Abre la pantalla de nombre (escenas/entrada_nombre) en modo POKéMON, como
## partida_nueva.gd con el nombre del jugador, y devuelve el mote escrito:
## "" si se confirma vacío o se cancela. Con `volver_a_batalla` = false la
## pantalla se queda en negro al cerrar la de nombre (fin de captura).
func pedir_mote(pokemon: BasePokemon, volver_a_batalla: bool = true) -> String:
	await oscurecer()
	var entrada := SCN_ENTRADA_NOMBRE.instantiate() as Control
	# Por encima de la mochila (5) y de los menús/caja de texto.
	entrada.z_index = 6
	entrada.set("sexo_pokemon", int(ENTRADA_NOMBRE_SEXO.get(pokemon.sexo, 0)))
	# La respuesta puede llegar durante el fundido: se guarda y se emite.
	var respuesta := {"lista": false, "nombre": ""}
	var al_confirmar := func(nombre: String) -> void:
		respuesta["lista"] = true
		respuesta["nombre"] = nombre
		_nombre_introducido.emit(nombre)
	var al_cancelar := func() -> void:
		respuesta["lista"] = true
		_nombre_introducido.emit("")
	entrada.connect("nombre_confirmado", al_confirmar, CONNECT_ONE_SHOT)
	entrada.connect("cancelado", al_cancelar, CONNECT_ONE_SHOT)
	_b.add_child(entrada)
	entrada.call(
		"configurar",
		"¿Mote de %s?" % pokemon.get_nombre_mostrar(),
		MAX_CARACTERES_MOTE,
		false,
		ENTRADA_NOMBRE_POKEMON,
		maxi(pokemon.numero_nacional, 1)
	)
	await aclarar()
	if not bool(respuesta["lista"]):
		await _nombre_introducido
	await oscurecer()
	entrada.queue_free()
	if volver_a_batalla:
		await aclarar()
	return str(respuesta["nombre"]).strip_edges()
