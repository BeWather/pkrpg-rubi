## npc_abuela_guarderia.gd
## Abuela de la GUARDERÍA POKéMON de la Ruta 117 (pokeruby
## Route117_PokemonDayCare_EventScript_1B2327, data/scripts/day_care.inc).
##
## Según `Guarderia.obtener_estado()`:
## - 0 (vacía): ofrece criar; flujo de depositar (equipo en modo GUARDERIA).
## - 1 (huevo pendiente): "Mi marido te estaba buscando."
## - 2 (uno): saludo, niveles, "¿Otro más?" y, si no, "¿Te llevas tu POKéMON?".
## - 3 (dos): saludo, niveles de los dos y "¿Te llevas tu POKéMON?".
## La lógica vive en `Guarderia`; aquí solo el guion, los menús y los sonidos.
##
## Está detrás del mostrador: el jugador le habla desde la celda de enfrente,
## así que se activa con Singleton.buscar_evento_accion como la enfermera
## (celda_interaccion_relativa). Diálogos encadenados en un solo cuadro y SÍ/NO
## como npc_artesano_vidrio.gd. Textos: claves GUARDERIA_* de dialogos.csv.
@tool
extends "res://scripts/npc/npc_base.gd"

const MOTIVO_PAUSA: StringName = &"abuela_guarderia"
const ESTILO_TEXTO: LabelSettings = preload("res://UI/texto_normal_negro.tres")
const ESCENA_EQUIPO: String = "res://UI/equipo/pantalla-equipo.tscn"
## Ruta de los gritos (batalla.gd CRY_BASE_PATH + "%03dCry.ogg").
const RUTA_GRITO: String = "res://Audio/SE/Cries/%03dCry.ogg"
## SE_REGI no existe en el proyecto: aproximación con la moneda del casino.
const SE_CAJA: AudioStream = preload("res://Audio/SE/SlotsCoin.wav")
const TAMANO_EQUIPO_MAXIMO: int = 6
const OPCION_CANCELAR: String = "CANCELAR"
## ShowDaycareLevelMenu: ventana (15,6)-(29,13) en tiles de 8 px, algo más
## ancha para que quepan mote, sexo y nivel con la fuente del proyecto.
const POSICION_MENU_NIVEL: Vector2 = Vector2(104, 48)
const ANCHO_MENU_NIVEL: float = 136.0
## Route117_PokemonDayCare_Movement_1B2543, en frames de GBA (delay_16).
const FPS_GBA: float = 60.0
const FRAMES_PAUSA: int = 16

## Celda (relativa a la Abuela) que el jugador acciona para hablarle: el
## mostrador de delante.
@export var celda_interaccion_relativa: Vector2i = Vector2i(0, 1)

## Guardería usada por el guion; null = SistemaGuardado.get_guarderia().
var guarderia: Guarderia = null
## Si es válido sustituye a la pantalla de equipo: devuelve el índice elegido
## o -1 (tests).
var selector_equipo: Callable = Callable()
## Si es válido sustituye al menú de nivel: devuelve 0, 1 o -1 (tests).
var selector_nivel: Callable = Callable()
## false omite la animación de ida y vuelta al retirar (tests).
var animar_retirada: bool = true

signal _mensaje_terminado
signal _menu_elegido(indice: int)
signal _equipo_cerrado

var _secuencia_activa: bool = false
var _menu: NinePatchRect = null
var _cursor: PkSelectorSimple = null
var _indice_menu: int = 0
var _opciones_menu: int = 0
## Texto de la última pregunta SÍ/NO (se deja a la vista bajo el menú de nivel).
var _ultima_pregunta: String = ""


func _ready() -> void:
	super._ready()
	set_process_input(false)
	if Engine.is_editor_hint():
		return
	if not Singleton.buscar_evento_accion.is_connected(_on_buscar_evento_accion):
		Singleton.buscar_evento_accion.connect(_on_buscar_evento_accion)


func _exit_tree() -> void:
	_cerrar_menu()
	if _secuencia_activa and not Engine.is_editor_hint():
		Singleton.mantener_pausa(MOTIVO_PAUSA, false)


func _obtener_guarderia() -> Guarderia:
	return guarderia if guarderia != null else SistemaGuardado.get_guarderia()


## A través del mostrador (patrón enfermera_cp.gd): solo el mapa actual y la
## celda de delante de la Abuela.
func _on_buscar_evento_accion(celda_accionada: Vector2i, mapa_origen: Node) -> void:
	if _secuencia_activa or nodo_administrador == null:
		return
	var mapa_propietario: Node = get_parent().get_parent() if get_parent() else null
	if nodo_administrador.get("mapa_actual") != mapa_origen or mapa_propietario != mapa_origen:
		return
	if celda_accionada == coord_celda + celda_interaccion_relativa:
		evento_accion()


func _procesar_interaccion() -> void:
	interrupcion_pendiente = false
	if _secuencia_activa:
		return
	if nodo_administrador == null or nodo_administrador.cuadro_dialogo == null:
		if jugador and jugador.has_method("esperar_dialogo"):
			jugador.esperar_dialogo(false)
		cambiar_estado(EstadoNPC.IDLE)
		return
	_ejecutar_secuencia()


func _ejecutar_secuencia() -> void:
	_secuencia_activa = true
	cambiar_estado(EstadoNPC.INTERACTING)
	mirar_jugador()  # faceplayer
	_bloquear_jugador(true)

	var dc := _obtener_guarderia()
	match dc.obtener_estado():
		Guarderia.Estado.HUEVO_PENDIENTE:
			await _mensaje("GUARDERIA_ABUELA_MARIDO")
		Guarderia.Estado.UNO:
			await _estado_uno(dc)
		Guarderia.Estado.DOS:
			await _estado_dos(dc)
		_:
			if await _preguntar("GUARDERIA_ABUELA_PRESENTACION"):
				await _flujo_depositar(dc)
			else:
				await _mensaje("GUARDERIA_ABUELA_NO_CRIAR")
	_finalizar()


## Route117_PokemonDayCare_EventScript_1B242B.
func _estado_uno(dc: Guarderia) -> void:
	await _mensaje("GUARDERIA_ABUELA_SALUDO")
	await _mensaje_niveles(dc, 0)
	if await _preguntar("GUARDERIA_ABUELA_OTRO_MAS"):
		await _flujo_depositar(dc)
		return
	if await _preguntar("GUARDERIA_ABUELA_LLEVAR"):
		await _flujo_retirar(dc)
		return
	await _mensaje("GUARDERIA_ABUELA_VUELVE")


## Route117_PokemonDayCare_EventScript_1B2558.
func _estado_dos(dc: Guarderia) -> void:
	await _mensaje("GUARDERIA_ABUELA_SALUDO")
	await _mensaje_niveles(dc, 0)
	await _mensaje_niveles(dc, 1)
	if await _preguntar("GUARDERIA_ABUELA_LLEVAR"):
		await _flujo_retirar(dc)
		return
	await _mensaje("GUARDERIA_ABUELA_VUELVE")


## Route117_PokemonDayCare_EventScript_1B241A: solo si ha subido algún nivel.
func _mensaje_niveles(dc: Guarderia, i: int) -> void:
	var poke := dc.obtener_pokemon(i)
	var niveles := dc.niveles_ganados(i)
	if poke == null or niveles == 0:
		return
	await _mensaje("GUARDERIA_ABUELA_NIVELES", {"{mon}": poke.get_nombre_mostrar(), "{n}": str(niveles)})


## Route117_PokemonDayCare_EventScript_1B236C (y el bucle de "¿Otro más?").
func _flujo_depositar(dc: Guarderia) -> void:
	while true:
		var equipo: Array = SistemaGuardado.get_equipo()
		if contar_validos(equipo) < 2:  # GetNumValidDaycarePartyMons
			await _mensaje("GUARDERIA_ABUELA_SOLO_UNO")
			return
		await _mensaje("GUARDERIA_ABUELA_CUAL")
		var indice: int = await _elegir_del_equipo()
		if indice < 0 or indice >= equipo.size():
			await _mensaje("GUARDERIA_ABUELA_VUELVE")
			return
		if contar_vivos_excepto(equipo, indice) == 0:  # CountAlivePartyMonsExceptSelectedOne
			await _mensaje("GUARDERIA_ABUELA_CON_QUE_LUCHARAS")
			return
		var poke: BasePokemon = equipo[indice]
		if poke.huevo:
			return  # la pantalla no ofrece DEJAR con un huevo
		_reproducir_grito(poke)
		await _mensaje("GUARDERIA_ABUELA_DEPOSITADO", {"{mon}": poke.get_nombre_mostrar()})
		if not dc.depositar(poke):
			push_warning("[AbuelaGuarderia] No se pudo depositar %s" % poke.get_nombre_mostrar())
			return
		equipo.remove_at(indice)  # el equipo queda compactado
		if dc.obtener_estado() != Guarderia.Estado.UNO:
			return
		if not await _preguntar("GUARDERIA_ABUELA_OTRO_MAS"):
			await _mensaje("GUARDERIA_ABUELA_VUELVE")
			return


## Route117_PokemonDayCare_EventScript_1B2469 (y "¿Te llevas también el otro?").
func _flujo_retirar(dc: Guarderia) -> void:
	while true:
		var equipo: Array = SistemaGuardado.get_equipo()
		if equipo.size() >= TAMANO_EQUIPO_MAXIMO:
			await _mensaje("GUARDERIA_ABUELA_EQUIPO_LLENO")
			return
		var indice := 0
		if dc.obtener_estado() != Guarderia.Estado.UNO:
			indice = await _elegir_de_guarderia(dc)
			if indice < 0:
				await _mensaje("GUARDERIA_ABUELA_VUELVE")
				return
		var poke := dc.obtener_pokemon(indice)
		if poke == null:
			return
		var coste := dc.coste(indice)
		if not await _preguntar("GUARDERIA_ABUELA_COSTE", {"{mon}": poke.get_nombre_mostrar(), "{n}": str(coste)}):
			await _mensaje("GUARDERIA_ABUELA_VUELVE")
			return
		if SistemaGuardado.get_dinero_jugador() < coste:  # HasEnoughMoneyFor
			await _mensaje("GUARDERIA_ABUELA_SIN_DINERO")
			return
		await _animar_ida_y_vuelta()
		var retirado := dc.retirar(indice)  # TakePokemonFromDaycare
		if retirado == null:
			return
		equipo.append(retirado)
		SistemaGuardado.quitar_dinero_jugador(coste)  # PayMoneyFor
		_reproducir_se(SE_CAJA)
		await _mensaje("GUARDERIA_ABUELA_PERFECTO")
		_reproducir_grito(retirado)
		await _mensaje("GUARDERIA_ABUELA_RECUPERO", {"{mon}": retirado.get_nombre_mostrar()})
		if dc.obtener_estado() != Guarderia.Estado.UNO:
			await _mensaje("GUARDERIA_ABUELA_VUELVE")
			return
		if not await _preguntar("GUARDERIA_ABUELA_TAMBIEN_OTRO"):
			await _mensaje("GUARDERIA_ABUELA_VUELVE")
			return


## GetNumValidDaycarePartyMons: Pokémon del equipo que no son huevo.
static func contar_validos(equipo: Array) -> int:
	var total := 0
	for poke in equipo:
		if poke is BasePokemon and not (poke as BasePokemon).huevo:
			total += 1
	return total


## CountAlivePartyMonsExceptSelectedOne: aptos (no huevo, PS > 0) sin contar `excepto`.
static func contar_vivos_excepto(equipo: Array, excepto: int) -> int:
	var total := 0
	for i in range(equipo.size()):
		var poke := equipo[i] as BasePokemon
		if i != excepto and poke != null and poke.puede_combatir():
			total += 1
	return total


func _finalizar() -> void:
	_cerrar_menu()
	if nodo_administrador and is_instance_valid(nodo_administrador.cuadro_dialogo):
		nodo_administrador.cuadro_dialogo.cerrar()
	_bloquear_jugador(false)
	_volver_a_direccion_base()
	_secuencia_activa = false
	cambiar_estado(EstadoNPC.IDLE)


func _bloquear_jugador(activo: bool) -> void:
	Singleton.mantener_pausa(MOTIVO_PAUSA, activo)
	if jugador == null:
		return
	if activo:
		jugador.start_dialog()
	else:
		jugador.end_dialog()
	jugador.no_control = activo


# ==============================================
# DIÁLOGOS
# ==============================================

## Texto de la clave `clave` con las sustituciones {mon}, {mon2}, {n}.
static func texto(clave: String, sustituciones: Dictionary = {}) -> String:
	var resultado := TranslationServer.translate(clave)
	for marca in sustituciones:
		resultado = resultado.replace(str(marca), str(sustituciones[marca]))
	return resultado


## Espera el botón y deja el cuadro abierto para el siguiente mensaje.
func _mensaje(clave: String, sustituciones: Dictionary = {}) -> void:
	continuar_dialogo(texto(clave, sustituciones), true, _mensaje_terminado.emit)
	await _mensaje_terminado


func _preguntar(clave: String, sustituciones: Dictionary = {}) -> bool:
	var dialogo = nodo_administrador.cuadro_dialogo
	# preguntaSiNo() exige IDLE: cerrar() y reabrir en el mismo frame no se ve.
	var continua: bool = dialogo.esta_activo
	dialogo.cerrar()
	dialogo.omitir_siguiente_sonido_inicio = continua
	_ultima_pregunta = texto(clave, sustituciones)
	dialogo.preguntaSiNo(_ultima_pregunta)
	while true:
		var datos: Array = await dialogo.comando_ejecutado
		if datos.size() >= 2 and str(datos[0]) == "respuesta_confirmacion":
			var parametros: Array = datos[1]
			return not parametros.is_empty() and str(parametros[0]) == "Y"
	return false


# ==============================================
# PANTALLA DE EQUIPO (ChooseSendDaycareMon)
# ==============================================

## Abre el equipo en modo GUARDERIA con fundidos (patrón mochila._abrir_equipo_dar).
## Devuelve el índice elegido con DEJAR o -1 si se cancela.
func _elegir_del_equipo() -> int:
	if selector_equipo.is_valid():
		return int(selector_equipo.call())
	var capa := get_tree().root.get_node_or_null("AdministradorMapa/Menu")
	if capa == null:
		return -1
	nodo_administrador.cuadro_dialogo.cerrar()
	await Singleton.transicion("oscurecer")  # fadescreen 1
	var equipo := EquipoPokemon.new()
	for poke: BasePokemon in SistemaGuardado.get_equipo():
		equipo.agregar_pokemon(poke)
	var pantalla := (load(ESCENA_EQUIPO) as PackedScene).instantiate() as PantallaEquipoControlador
	capa.add_child(pantalla)
	var eleccion := {"indice": -1, "lista": false}
	pantalla.pokemon_elegido.connect(func(i: int) -> void:
		eleccion["indice"] = i
		eleccion["lista"] = true
		_equipo_cerrado.emit()
	, CONNECT_ONE_SHOT)
	pantalla.seleccion_cancelada.connect(func() -> void:
		eleccion["lista"] = true
		_equipo_cerrado.emit()
	, CONNECT_ONE_SHOT)
	pantalla.mostrar_equipo_modo(Singleton.ModoPEquipo.GUARDERIA, equipo)
	await Singleton.transicion("aclarar")
	if not bool(eleccion["lista"]):
		await _equipo_cerrado
	pantalla.activo = false
	await Singleton.transicion("oscurecer")
	pantalla.ocultar_pantalla_equipo()
	pantalla.queue_free()
	await Singleton.transicion("aclarar")
	return int(eleccion["indice"])


# ==============================================
# MENÚ DE NIVEL (ShowDaycareLevelMenu)
# ==============================================

## Mote + sexo y "Nv. X" tras los pasos de los dos Pokémon, y CANCELAR.
## Devuelve 0, 1 o -1 (CANCELAR o B).
func _elegir_de_guarderia(dc: Guarderia) -> int:
	if selector_nivel.is_valid():
		return int(selector_nivel.call())
	# Tras el SÍ/NO el cuadro queda vacío: la pregunta sigue a la vista bajo el menú.
	var dialogo = nodo_administrador.cuadro_dialogo
	if not _ultima_pregunta.is_empty() and dialogo.has_method("mostrar_inmediatamente"):
		dialogo.mostrar_inmediatamente(_ultima_pregunta)
	_indice_menu = 0
	_opciones_menu = Guarderia.HUECOS + 1
	_menu = NinePatchRect.new()
	var imagen_tipo := int(SistemaGuardado.datos_vivos.opciones.imagen_tipo)
	preload("res://scripts/clases/MenuBoxManager.gd").apply_texture_to_ninepatch(_menu, imagen_tipo)
	_menu.patch_margin_left = 8
	_menu.patch_margin_top = 8
	_menu.patch_margin_right = 8
	_menu.patch_margin_bottom = 8
	_menu.position = POSICION_MENU_NIVEL
	_menu.size = Vector2(ANCHO_MENU_NIVEL, _opciones_menu * 16 + 16)
	for i in range(Guarderia.HUECOS):
		var poke := dc.obtener_pokemon(i)
		if poke == null:
			continue
		_menu.add_child(_etiqueta(poke.get_nombre_mostrar() + _simbolo_sexo(poke), Vector2(12, 8 + i * 16)))
		var nivel := _etiqueta("Nv. %d" % dc.nivel_tras_pasos(i), Vector2(ANCHO_MENU_NIVEL - 56, 8 + i * 16))
		nivel.size = Vector2(44, 16)
		nivel.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_menu.add_child(nivel)
	_menu.add_child(_etiqueta(OPCION_CANCELAR, Vector2(12, 8 + Guarderia.HUECOS * 16)))
	_cursor = PkSelectorSimple.new()
	_cursor.color = Color(239.0 / 255, 110.0 / 255, 96.0 / 255)
	_cursor.ancho_borde = 1
	_cursor.parpadeo = false
	_cursor.size = Vector2(ANCHO_MENU_NIVEL - 14, 17)
	_menu.add_child(_cursor)
	_actualizar_cursor()
	var capa := get_tree().root.get_node_or_null("AdministradorMapa/Menu")
	if capa == null:
		capa = self
	capa.add_child(_menu)
	# No interpretar la misma pulsación que cerró el diálogo anterior.
	await get_tree().process_frame
	set_process_input(true)
	var indice: int = await _menu_elegido
	_cerrar_menu()
	return indice


func _etiqueta(texto_etiqueta: String, posicion: Vector2) -> Label:
	var etiqueta := Label.new()
	etiqueta.label_settings = ESTILO_TEXTO
	etiqueta.text = texto_etiqueta
	etiqueta.position = posicion
	return etiqueta


static func _simbolo_sexo(poke: BasePokemon) -> String:
	match poke.sexo:
		"M":
			return "♂"
		"F":
			return "♀"
	return ""


func _actualizar_cursor() -> void:
	_cursor.position = Vector2(7, 7 + _indice_menu * 16)


func _input(event: InputEvent) -> void:
	if _menu == null:
		return
	if event.is_action_pressed("btn_arriba"):
		_indice_menu = posmod(_indice_menu - 1, _opciones_menu)
		_actualizar_cursor()
	elif event.is_action_pressed("btn_abajo"):
		_indice_menu = (_indice_menu + 1) % _opciones_menu
		_actualizar_cursor()
	elif event.is_action_pressed("btn_accion"):
		_menu_elegido.emit(_indice_menu if _indice_menu < Guarderia.HUECOS else -1)
	elif event.is_action_pressed("btn_cancelar"):
		_menu_elegido.emit(-1)
	else:
		return
	Singleton.play_sound.emit("cursor_menu")
	get_viewport().set_input_as_handled()


func _cerrar_menu() -> void:
	set_process_input(false)
	if is_instance_valid(_menu):
		_menu.queue_free()
	_menu = null
	_cursor = null


# ==============================================
# ANIMACIÓN (Route117_PokemonDayCare_Movement_1B2543)
# ==============================================

## Mira a izquierda y derecha, sube despacio, desaparece, espera, reaparece y baja.
func _animar_ida_y_vuelta() -> void:
	if not animar_retirada:
		return
	await _esperar_frames(FRAMES_PAUSA * 2)
	update_direction(Vector2.LEFT)
	await _esperar_frames(FRAMES_PAUSA * 2)
	update_direction(Vector2.RIGHT)
	await _esperar_frames(FRAMES_PAUSA * 2)
	update_direction(Vector2.UP)
	await _caminar_lento(Vector2.UP)
	_mostrar_sprite(false)
	await _esperar_frames(FRAMES_PAUSA * 5)
	update_direction(Vector2.DOWN)
	_mostrar_sprite(true)
	await _caminar_lento(Vector2.DOWN)


## walk_slow_*: un paso LENTO (32 fotogramas por casilla). Si la celda está
## ocupada, no se mueve. Al acabar restaura su duración de paso y vuelve al estado
## INTERACTING.
func _caminar_lento(direccion: Vector2) -> void:
	var duracion_previa := duracion_paso
	duracion_paso = duracion_para_velocidad(VelocidadPaso.LENTO)
	mover_npc(direccion)
	var espera := 0.0
	while estado_actual == EstadoNPC.MOVING and espera < 3.0:
		await get_tree().process_frame
		espera += get_process_delta_time()
	duracion_paso = duracion_previa
	cambiar_estado(EstadoNPC.INTERACTING)


## set_invisible / set_visible sin ocultar el nodo (su NOTIFICATION_VISIBILITY_CHANGED
## reinicia el estado del NPC).
func _mostrar_sprite(visible_sprite: bool) -> void:
	if animated_sprite:
		animated_sprite.visible = visible_sprite
	if sombra:
		sombra.visible = visible_sprite


func _esperar_frames(frames: int) -> void:
	await get_tree().create_timer(frames / FPS_GBA).timeout


# ==============================================
# SONIDO
# ==============================================

func _reproducir_grito(poke: BasePokemon) -> void:
	if poke == null or poke.numero_nacional <= 0:
		return
	var ruta := RUTA_GRITO % poke.numero_nacional
	if not ResourceLoader.exists(ruta):
		return
	_reproducir_se(load(ruta) as AudioStream)


func _reproducir_se(stream: AudioStream) -> void:
	if stream == null or not is_inside_tree():
		return
	var reproductor := AudioStreamPlayer.new()
	reproductor.stream = stream
	reproductor.finished.connect(reproductor.queue_free)
	add_child(reproductor)
	reproductor.play()
