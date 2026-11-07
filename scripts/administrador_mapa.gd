extends Node2D

const CONTEXTO_PRECARGA_MUSICA_MAPA: String = "mapa_activo"
## Grupo cuyos nodos reciben al_entrar_por_warp() (ver _notificar_entrada_por_warp).
const GRUPO_ENTRADA_POR_WARP: StringName = &"entrada_por_warp"

## Un huevo del equipo (índice en SistemaGuardado.get_equipo()) va a eclosionar.
signal huevo_eclosiona(indice: int)
## Callback del cuadro de diálogo en la secuencia de eclosión.
signal _eclosion_mensaje_terminado
## Callback del cuadro de diálogo en los mensajes del veneno en el campo.
signal _mensaje_veneno_terminado
## Algún Pokémon se debilita por el veneno en el campo (tras el paso 4 del ciclo).
signal veneno_debilita(pokemon: Array)
signal warp_perfil_preparado
signal warp_perfil_finalizado(exito: bool)

## Superposición de la eclosión (pokeruby egg_hatch.c).
const SCN_ECLOSION_HUEVO: PackedScene = preload("res://escenas/crianza/eclosion_huevo.tscn")
## S_EggHatch: mensaje previo a la eclosión ("Huh?" en el decomp).
const TEXTO_ECLOSION_PREVIO: String = "¿Y esto?"
const MOTIVO_PAUSA_ECLOSION: StringName = &"eclosion_huevo"
## fieldPoisonText_PokemonFainted y UnknownString_81A1141 (event_scripts.s), con
## el texto de la ROM española oficial. `{mon}` = apodo del Pokémon.
const TEXTO_VENENO_DEBILITADO: String = "CAMPO_VENENO_DEBILITADO"
const TEXTO_VENENO_SIN_POKEMON: String = "CAMPO_VENENO_SIN_POKEMON"
const MOTIVO_PAUSA_VENENO: StringName = &"veneno_campo"
## BUSCAOBJETOS: bloquea al jugador durante los pitidos y los giros.
const MOTIVO_PAUSA_BUSCAOBJETOS: StringName = &"buscaobjetos"
## Frames que dura cada giro en el sitio (PlayerTurnInPlace).
const FRAMES_GIRO_BUSCAOBJETOS: int = 8
## nombre_interno de la RUTA 113: BattleSetup_GetTerrain da ARENA (ceniza) en
## cualquier celda sin hierba ni agua de ese mapa.
const NOMBRE_INTERNO_RUTA_113: String = "ruta_113"
# const SCN_MAPA_CAMION: PackedScene = preload("res://escenas/partida_nueva/camion.tscn")

## Activa los menús debug del overworld (cartel de la guardería, árbol de
## bayas). Solo en builds de depuración; ver `debug_activo()`.
@export var iniciar_debug: bool = false

## Guarda/carga la partida en res://partida/ dentro del proyecto (junto al
## codigo) en vez de user://; util para debug e inspeccion del JSON. Sin
## efecto en exportaciones: res:// no es escribible ahi.
@export var guardar_en_partida_debug: bool = false

## Usa la tabla de encuentros salvajes alternativa
## (BaseDatos/config_encuentros_alternativo.json): especies de las 3 generaciones,
## sin slots repetidos, en rutas, cuevas, bosques, pesca y rocas. Se regenera con
## herramientas/generar_encuentros_alternativos.py.
@export var tabla_encuentros_alternativa: bool = false:
	set(valor):
		tabla_encuentros_alternativa = valor
		DatabaseManager.usar_tabla_alternativa = valor

var overworld_scene = preload("res://escenas/Overworld.tscn")
var ventana_opciones_scene = preload("res://UI/ventana_opciones.tscn")
var nodo_overworld: Node2D = null  ## Instancia de Overworld.tscn con todos los mapas exteriores

var mapa_actual_key: String
## Clave del mapa del que se viene (gLastUsedWarp): el origen del último warp o del último
## cruce de borde. Vacío al iniciar o cargar una partida.
var mapa_anterior_key: String = ""
var pos_ini: Vector2
var mapa_actual: MapaConfiguracion
var mapa_actual_offset: Vector2
var enExterior: bool = true
var mapas_activos: Array[MapaConfiguracion] = []  ## Mapas del Overworld actualmente en viewport
## Regiones (RegionOverworld) cargadas desde su InstancePlaceholder del Overworld:
## placeholder → región. Se liberan al dejar sus mapas.
var _regiones_cargadas: Dictionary = {}
## Claves de mapa de la escena de cada placeholder de región (ruta → claves normalizadas).
var _claves_region: Dictionary = {}
## Mapas sueltos del Overworld ocultados al entrar en una región, para volver a mostrarlos.
var _mapas_ocultos_por_region: Array[MapaConfiguracion] = []
# var scn_jugador = preload("res://escenas/avatares/CB2_Aura.tscn")
var _scn_jugador_chica = preload("res://escenas/character/girl.tscn")
var _scn_jugador_varon = preload("res://escenas/character/boy.tscn")
var scn_jugador: PackedScene  ## Se asigna en _ready() según el sexo del jugador
var jugador: Node2D
var jugador_offset: Vector2 = Vector2(8, 14)  # Offset del personaje respecto a la posición en píxeles (centro inferior)

@onready var cam = $Camera2D
@onready var capa_interfaz = $"./Menu"
@onready var telon = $"./Menu/Telon"
## Sin posición (AudioStreamPlayer, no 2D): con un reproductor 2D en el origen del
## mundo los sonidos de menú se atenuaban por la distancia de la cámara.
@onready var sfx_player: AudioStreamPlayer = $ReproductorSFX
@onready var cuadro_dialogo: NinePatchRect = $"./Menu/CuadroDialogo"
@onready var musica_player: NuevoAudioStreamPlayer = $AudioStreamPlayer
@onready var intro_menu: Control = $Menu/IntroMenu
@onready var controlador_clima: ControladorClimaOverworld = $ControladorClimaOverworld
@onready var dialogo_bases: Node = get_node_or_null("Menu/DialogoBasesSecretas")

# Pasa conexiones de puertas
var coneccion: int = 0
var coneccion_destino: String
var coneccion_posicion: Vector2
var coneccion_direccion: Vector2
var coneccion_dar_paso: bool
var _contexto_destino_warp: Dictionary = {}
var _capa_destino_warp: int = -1  # -1 conserva el comportamiento de warps ordinarios.
var _warp_cueva: int = 0  # 0 normal, 1 entrar, -1 salir (gMapTypeFadePairs).
var _warp_animando_cueva: bool = false
var _warp_perfil := false
## Warp de BUCEO en curso (conectar_buceo): al llegar se decide si se emerge surfeando.
var _warp_por_buceo := false

## FLAG_HIDE_MAP_NAME_POPUP: mientras está activa no se muestra el cartel del lugar
## (el guion de la Ruta 101 lo pone al entrar la primera vez y lo quita al terminar).
const BANDERA_OCULTAR_CARTEL_LUGAR: String = "ocultar_cartel_lugar"
## FLAG_DONT_TRANSITION_MUSIC: los warps no cambian el tema (ventanillas del S.S. MAREA).
var conservar_musica_warp: bool = false
## Banderas FLAG_LANDMARK_* (mapa de región del PokéNav) y qué mapa activa cada una.
const BANDERAS_LANDMARK = preload("res://scripts/mapas/banderas_landmark.gd")
## Cartel de nombre de lugar (UI, superior izquierda).
var _cartel_lugar: CartelNombreLugar = null
## Último lugar anunciado en el cartel (para no repetir el aviso).
var _nombre_lugar_anunciado: String = ""
## true si el warp en curso partió de un mapa interior.
var _warp_origen_interior: bool = false
## Nombre del lugar desde el que parte el warp en curso.
var _warp_nombre_origen: String = ""

var imprimiendo: bool = false

## ¿Hay un diálogo/ventana bloqueando el juego? Alias de SOLO LECTURA derivado de
## los motivos de pausa, que conservan los lectores antiguos.
## Para pausar/reanudar usa Singleton.mantener_pausa()/pausar(): escribir aquí ya
## no compila (el compilador te avisa si lo intentas).
var en_dialogo: bool:
	get:
		return Singleton.esta_pausado()
var debe_soltar_tecla_accion: bool = false  # Evita re-abrir cartel inmediatamente tras cerrarlo
var input_habilitado: bool = false

var battle_manager: Node  ## Gestor de batallas (encuentros + entrenadores)
var _rng_revanchas := RandomNumberGenerator.new()  ## Sorteo del 31 % de las revanchas
var inicio_en_progreso: bool = false
var juego_iniciado: bool = false
var ventana_opciones_intro: Control = null
var dialogo_cartel_activo: bool = false

## Cooldown (frames) tras iniciar el juego antes de aceptar input del
## overworld; absorbe ecos de tecla/dobles toques residuales del menu de
## inicio para que no abran el menu de pausa nada mas arrancar.
const COOLDOWN_INICIO_FRAMES: int = 20
var _cooldown_input_inicio: int = 0

## Costuras de prueba para verificar el flujo coordinado sin inicializar el mundo completo.
var cargar_partida_para_inicio: Callable
var crear_partida_nueva_para_inicio: Callable
var estado_inicio_resuelto: Callable
var iniciar_juego_para_inicio: Callable
var validar_mapa_para_inicio: Callable


func _enter_tree() -> void:
	# Debe correr antes del _ready de los hijos: el menu de inicio consulta
	# SistemaGuardado.has_partida_guardada() al prepararse y ya debe leer la
	# ruta redirigida. Solo activo en debug; en exportaciones res:// no es
	# escribible y la bandera se ignora.
	if guardar_en_partida_debug and OS.is_debug_build():
		SistemaGuardado.usar_partida_local_para_debug()
	_marcar_omitir_intro_si_arranque_debug()


## El arranque debug entra directo al overworld: avisa a IntroMenu (hija de
## esta escena) para que no arranque su secuencia ni su música. Su _ready corre
## después de este _enter_tree, así que la marca llega a tiempo; si no, la intro
## seguiría sonando y reiniciándose por detrás aunque esté oculta.
func _marcar_omitir_intro_si_arranque_debug() -> void:
	var arranque := get_node_or_null("/root/DebugArranque")
	if arranque == null or not arranque.has_method("marcar_omitir_intro"):
		return
	var hay_pendiente := (
		arranque.has_method("tiene_arranque_pendiente")
		and bool(arranque.call("tiene_arranque_pendiente"))
	)
	if hay_pendiente:
		arranque.call("marcar_omitir_intro")
		print("⏭️ [ADMIN] Arranque debug directo: se omitirá la pantalla de inicio")


func _ready() -> void:
	capa_interfaz.visible = true
	# Cartel de nombre de lugar (superior izquierda de la capa de UI).
	_cartel_lugar = CartelNombreLugar.new()
	capa_interfaz.add_child(_cartel_lugar)
	intro_menu.continuar_solicitado.connect(_on_continuar_solicitado)
	intro_menu.partida_nueva_confirmada.connect(_on_partida_nueva_confirmada)
	intro_menu.opciones_solicitadas.connect(_on_opciones_solicitadas)
	intro_menu.salir_solicitado.connect(_on_salir_solicitado)
	call_deferred("_intentar_inicio_debug")


func _on_continuar_solicitado() -> void:
	if inicio_en_progreso or juego_iniciado:
		return
	if not _cargar_partida_para_inicio():
		intro_menu.mostrar_error("No se pudo cargar la partida")
		return
	if not _iniciar_juego_desde_estado(_resolver_estado_inicio()):
		intro_menu.mostrar_error("No se pudo iniciar la partida")
		return
	# Al continuar una partida guardada se anuncia siempre dónde está el jugador.
	_anunciar_lugar(_nombre_lugar_actual_resuelto())


func _on_partida_nueva_confirmada(sexo: String, nombre: String) -> void:
	if inicio_en_progreso or juego_iniciado:
		return
	var plantilla := SistemaGuardado.preparar_plantilla_partida_nueva(sexo, nombre)
	if not _crear_partida_nueva_para_inicio(plantilla):
		intro_menu.mostrar_error("No se pudo guardar la nueva partida")
		return
	if not _iniciar_juego_desde_estado(_resolver_estado_inicio()):
		intro_menu.mostrar_error("No se pudo iniciar la nueva partida")


func _on_opciones_solicitadas() -> void:
	if ventana_opciones_intro != null or juego_iniciado:
		return
	# Ocultar el menu de inicio mientras las opciones estan abiertas: ademas
	# de la capa visual, desactiva su input y el boton M del gamepad tactil.
	ventana_opciones_intro = ventana_opciones_scene.instantiate() as Control
	capa_interfaz.add_child(ventana_opciones_intro)
	intro_menu.ocultar_menu()
	ventana_opciones_intro.cerrada.connect(_on_opciones_intro_cerradas)


func _on_opciones_intro_cerradas() -> void:
	# Guarda: la senal cerrada puede llegar mas de una vez (cerrar_ventana no
	# es idempotente desde _input); sin esto restaurariamos el menu dos veces.
	if ventana_opciones_intro == null:
		return
	ventana_opciones_intro.queue_free()
	ventana_opciones_intro = null
	intro_menu.restaurar_menu()


func _on_salir_solicitado() -> void:
	get_tree().quit()


func _intentar_inicio_debug() -> void:
	# Solo arranca si hay un arranque pendiente de F6 (DebugArranque).
	_intentar_arranque_debug_pendiente()

## Consume el arranque pendiente de DebugArranque (F6 sobre una escena de
## mapa): carga la partida guardada y entra directo al mapa y tile indicados,
## sin pasar por la intro. Si no hay guardado, arranca con la plantilla de
## partida nueva. Devuelve true solo si había un arranque pendiente.
func _intentar_arranque_debug_pendiente() -> bool:
	var debug_arranque := get_node_or_null("/root/DebugArranque")
	if debug_arranque == null or not debug_arranque.has_method("tiene_arranque_pendiente"):
		return false
	if not debug_arranque.tiene_arranque_pendiente():
		return false

	var estado: Dictionary = debug_arranque.tomar_arranque_pendiente()
	if not _cargar_partida_para_inicio():
		var plantilla := SistemaGuardado.preparar_plantilla_partida_nueva("M", "")
		if not _crear_partida_nueva_para_inicio(plantilla):
			intro_menu.mostrar_error("Sin partida guardada y no se pudo crear la plantilla")
			return true

	estado["sexo"] = str(SistemaGuardado.datos_vivos.jugador.sexo)
	if _iniciar_juego_desde_estado(estado):
		intro_menu.hide()
	else:
		intro_menu.mostrar_error("No se pudo iniciar el arranque directo de debug")
	return true


func _cargar_partida_para_inicio() -> bool:
	return bool(cargar_partida_para_inicio.call()) if cargar_partida_para_inicio.is_valid() else SistemaGuardado.cargar_partida()


func _crear_partida_nueva_para_inicio(plantilla: Dictionary = {}) -> bool:
	if crear_partida_nueva_para_inicio.is_valid():
		return bool(crear_partida_nueva_para_inicio.call(plantilla))
	return SistemaGuardado.aplicar_plantilla_partida_nueva(plantilla)


func _resolver_estado_inicio() -> Dictionary:
	if estado_inicio_resuelto.is_valid():
		var estado: Variant = estado_inicio_resuelto.call()
		return estado if estado is Dictionary else {}
	return _estado_desde_guardado()


func _iniciar_juego_desde_estado(estado_inicio: Dictionary) -> bool:
	return bool(iniciar_juego_para_inicio.call(estado_inicio)) if iniciar_juego_para_inicio.is_valid() else iniciar_juego(estado_inicio)


func _validar_mapa_para_inicio(mapa_key: String) -> bool:
	return bool(validar_mapa_para_inicio.call(mapa_key)) if validar_mapa_para_inicio.is_valid() else _mapa_existe(mapa_key)


func _estado_desde_guardado() -> Dictionary:
	var posicion: Dictionary = SistemaGuardado.get_posicion_guardada()
	return {
		"mapa_actual": posicion.get("mapa_actual", ""),
		"cx": int(posicion.get("cx", 0)),
		"cy": int(posicion.get("cy", 0)),
		"capa_datos": int(posicion.get("capa_datos", 0)),
		"sexo": SistemaGuardado.datos_vivos.jugador.sexo,
		# Solo al continuar: dirección, bici/surf y objetos del mapa guardados.
		"restaurar_estado_guardado": true,
	}


func iniciar_juego(estado_inicio: Dictionary) -> bool:
	if inicio_en_progreso or juego_iniciado:
		return false
	var mapa_inicio := str(estado_inicio.get("mapa_actual", ""))
	if not _mapa_existe(mapa_inicio):
		push_error("[ADMIN] Mapa inicial inválido: %s" % mapa_inicio)
		return false

	inicio_en_progreso = true
	input_habilitado = false
	var clave_anterior: String = mapa_actual_key
	mapa_anterior_key = ""
	mapa_actual_key = mapa_inicio
	var coord_ini := Vector2i(int(estado_inicio.get("cx", 0)), int(estado_inicio.get("cy", 0)))
	var capa_datos_inicial := int(estado_inicio.get("capa_datos", 0))
	var sexo := str(estado_inicio.get("sexo", ""))
	scn_jugador = _scn_jugador_varon if sexo == "M" else _scn_jugador_chica

	var contexto: Dictionary = ContextoBaseSecreta.desde_guardado(mapa_inicio,
		SistemaGuardado.get_bases_secretas())
	if not iniciar_escenario(contexto, estado_inicio):
		mapa_actual_key = clave_anterior
		inicio_en_progreso = false
		return false
	coord_ini = _normalizar_coord_guardada(coord_ini)
	Singleton.set_tile_map_con_capa(mapa_actual, capa_datos_inicial)
	pos_ini = mapa_actual.posicion_en_mundo() + Vector2(coord_ini.x * Singleton.TILE_SIZE, coord_ini.y * Singleton.TILE_SIZE) + jugador_offset

	jugador = scn_jugador.instantiate()
	var nodo_npcs_ini := _obtener_o_crear_nodo_npcs(mapa_actual)
	if nodo_npcs_ini != null:
		nodo_npcs_ini.add_child(jugador)
	else:
		add_child(jugador)
	jugador.global_position = pos_ini
	# Cargar sobre un warp (escalera, cueva) no debe dispararlo.
	if jugador.has_method("marcar_celda_de_llegada_warp"):
		jugador.call("marcar_celda_de_llegada_warp")
	# actualizar_escenario() ya aplicó el clima sin jugador: con la celda guardada,
	# el clima por zona de entrada del mapa (si tiene selector) puede ser otro.
	_reaplicar_clima_entrada_en_celda(coord_ini)
	jugador.visible = true
	jugador.z_index = 10
	var sprite_jugador := jugador.get_node_or_null("basico") as AnimatedSprite2D
	if sprite_jugador != null:
		sprite_jugador.visible = true
		sprite_jugador.z_index = 0
		sprite_jugador.stop()
		sprite_jugador.frame = 0
	if cam != null:
		cam.global_position = jugador.global_position - cam.centrar
		cam.make_current()
	if bool(estado_inicio.get("restaurar_estado_guardado", false)):
		_restaurar_estado_guardado_mapa()
	# MAP_TYPE_UNDERWATER: al cargar (o arrancar con F6) en un mapa submarino se bucea.
	if mapa_actual.mapa_submarino and jugador.has_method("aplicar_estado_llegada_mapa"):
		jugador.call("aplicar_estado_llegada_mapa", true, false)
	if mapa_actual.has_method("iniciar_presentacion"):
		mapa_actual.iniciar_presentacion(cam, jugador)
	Singleton.set_foco_camara(jugador)
	if not Singleton.play_sound.is_connected(_on_play_sound):
		Singleton.play_sound.connect(_on_play_sound)

	battle_manager = preload("res://scripts/OverworldBattleManager.gd").new()
	add_child(battle_manager)
	actualizar_opciones_menu()
	_validar_spawns_en_mapa()
	juego_iniciado = true
	_cooldown_input_inicio = COOLDOWN_INICIO_FRAMES
	intro_menu.hide()
	call_deferred("_habilitar_input")
	return true


func _mapa_existe(mapa_key: String) -> bool:
	if mapa_key.to_lower() == "camion":
		return true
	return not mapa_key.is_empty() and not Singleton._buscar_ruta_mapa_por_nombre("res://escenas/mapas/", mapa_key).is_empty()

func _habilitar_input() -> void:
	input_habilitado = true


## ===== CONSULTA CENTRALIZADA DE "¿SE PUEDE ACTUAR?" =====
## Punto único para saber si el juego está pausado o si un actor puede actuar.
## Los motivos globales (menú, batalla, diálogo, transición) viven en Singleton;
## el bloqueo local del mapa actual lo aporta el propio mapa.
## `en_dialogo` es un alias derivado de los motivos; `jugador.no_control` sigue
## siendo un bloqueo local del actor (animaciones, empujones, guiones).

## ¿El juego está pausado ahora mismo?
func esta_pausado() -> bool:
	return Singleton.esta_pausado() or (mapa_actual != null and mapa_actual.control_bloqueado())


## ¿Están activos los menús debug del overworld?
func debug_activo() -> bool:
	return iniciar_debug and OS.is_debug_build()


## ¿Puede el jugador moverse/interactuar?
func puede_actuar_jugador() -> bool:
	return jugador != null and not jugador.no_control and not en_dialogo and not esta_pausado()


## ¿Pueden actuar los NPCs del overworld?
## No mira `no_control`: es un bloqueo local del jugador (animación de paso,
## empujón, bicicleta) y no significa que el juego esté en pausa.
func puede_actuar_npc() -> bool:
	return not en_dialogo and not esta_pausado() and not transicion_centro_activa()

func transicion_centro_activa() -> bool:
	var controlador := get_node_or_null("TransicionCentro")
	return controlador != null and controlador.activa

func iniciar_transicion_centro(warp: Warp, preparar_servicio: Callable = Callable()) -> bool:
	var controlador := get_node_or_null("TransicionCentro")
	return controlador != null and controlador.iniciar(warp, preparar_servicio)

func destino_warp_valido(destino: String, celda: Vector2 = Vector2(INF, INF)) -> bool:
	if destino.is_empty():
		return false
	var mapa_exterior := _buscar_mapa_en_overworld(destino)
	if mapa_exterior != null:
		return not celda.is_finite() or mapa_exterior.obtener_rect_util().has_point(celda * Singleton.TILE_SIZE)
	var escena: PackedScene = Singleton._buscar_mapa_por_nombre(destino)
	if escena == null:
		return false
	if not celda.is_finite():
		return true
	var nodo := escena.instantiate()
	var valido: bool = nodo is MapaConfiguracion and nodo.obtener_rect_util().has_point(celda * Singleton.TILE_SIZE)
	nodo.free()
	return valido

func conectar_warp_perfil(destino: String, posicion: Vector2, direccion: Vector2) -> void:
	_warp_perfil = true
	conectar_escalera(destino, posicion, direccion)

func _process(_delta: float) -> void:
	if dialogo_cartel_activo and is_instance_valid(cuadro_dialogo) and not cuadro_dialogo.esta_activo:
		dialogo_cartel_activo = false
		Singleton.mantener_pausa(&"dialogo_cartel", false)
		if not esta_pausado():
			jugador.no_control = false

	# Guard: si el jugador aún no fue instanciado (escena cargando),
	# no procesar input para evitar crashes de null pointer.
	if jugador == null or not input_habilitado:
		return

	# Absorbe pulsaciones residuales del menu de inicio (eco de tecla o doble
	# toque) durante la transicion al overworld; sin esto, la misma tecla con
	# que se confirmo CONTINUAR abre el menu de pausa nada mas arrancar.
	if _cooldown_input_inicio > 0:
		_cooldown_input_inicio -= 1
		return
	# Bloqueo duro del mapa actual (intro del camión...): no procesar input.
	# Se consulta aparte de esta_pausado() a propósito: las fases de transición
	# de escalera que corren al final de _process deben seguir avanzando.
	if coneccion == 0 and mapa_actual != null and mapa_actual.control_bloqueado():
		return

	if en_dialogo == false and not jugador.no_control and not esta_pausado():
		# No procesar input mientras el jugador está en estado de pesca
		if jugador.get("en_pesca") == true:
			return

		# Si se mostró un cartel recientemente, esperar a que se suelte la tecla de acción
		if debe_soltar_tecla_accion and not Input.is_action_pressed("btn_accion"):
			debe_soltar_tecla_accion = false

		var input_dir = Vector2.ZERO
		if Input.is_action_pressed("btn_abajo") or Input.is_action_just_pressed("btn_abajo"):
			input_dir = Vector2(0, 1)
		elif Input.is_action_pressed("btn_arriba") or Input.is_action_just_pressed("btn_arriba"):
			input_dir = Vector2(0, -1)
		elif Input.is_action_pressed("btn_derecha") or Input.is_action_just_pressed("btn_derecha"):
			input_dir = Vector2(1, 0)
		elif Input.is_action_pressed("btn_izquierda") or Input.is_action_just_pressed("btn_izquierda"):
			input_dir = Vector2(-1, 0)
		elif Input.is_action_just_pressed("btn_menu"):
			abrir_menu()
		elif Input.is_action_just_pressed("btn_accion"):
			# Evitar re-procesar la acción si acabamos de abrir un cartel y la tecla sigue presionada
			if not debe_soltar_tecla_accion:
				accionar_evento()
			else:
				# Ignorar este evento hasta que el jugador suelte la tecla
				pass
		elif Input.is_action_just_pressed("btn_foco_cam"):
			if cam.en_foco == false:
				cam.inmediato = true
		# elif Input.is_action_just_pressed("ui_accept"):  # TEMP: tecla Enter para debug menú
		# 	print("Tecla Enter presionada - ejecutando debug menú")
		# 	debug_menu_estado()
		# elif Input.is_action_just_pressed("ui_select"):  # TEMP: tecla Espacio para forzar menú
		# 	print("Tecla Espacio presionada - forzando menú")
		# 	test_menu_manual()
		# elif Input.is_action_just_pressed("ui_cancel"):  # TEMP: tecla Escape para prueba equipo
		# 	print("Tecla Escape presionada - probando equipo directo")
		# 	test_equipo_directo()
		elif Input.is_action_just_pressed("ui_page_up"):  # TEMP: tecla PageUp para probar curación
			print("🧪 PRUEBA DE CURACIÓN INICIADA")
			test_sistema_curacion()

		var is_running = false
		if Input.is_action_pressed("btn_cancelar"):
			is_running = true

		if input_dir != Vector2.ZERO:
			#print(" bandera control: ", jugador.no_control)
			if !jugador.no_control:
				jugador.move_to_next_tile(input_dir, is_running)
		else:
			jugador.move_to_next_tile(input_dir, false)

	# Controla las fases de transicion al cruzar una escalera: ya caminó hasta el tile de la escalera
	# en 0 oscurecer; en 30 cambiar mapa; en 40 aclarar y avanzar un paso si corresponde
	if coneccion > 0 and not _warp_animando_cueva:
		conectar_escalera(coneccion_destino, coneccion_posicion, coneccion_direccion, coneccion_dar_paso)

## `ocultar_jugador`: solo para puertas, donde el jugador "entra" y desaparece al
## cerrarse. En escaleras, salidas y demás warps sigue visible durante el fundido:
## el telón lo cubre antes de cambiar de mapa.
func conectar_escalera(destino: String, posicion: Vector2, direccion: Vector2 = Vector2.DOWN, dar_paso: bool = false, ocultar_jugador: bool = false, contexto: Dictionary = {}, capa_destino: int = -1) -> void:
	if coneccion == 0:
		_contexto_destino_warp = contexto.duplicate(true)
		_capa_destino_warp = capa_destino
		if ocultar_jugador:
			jugador.visible = false
		_warp_cueva = _resolver_transicion_cueva(destino)
		Singleton.mantener_pausa(&"warp_cueva", _warp_cueva != 0)
		telon.oscurecer(0.3, _warp_cueva == 1)
		# El cartel del lugar que se deja no debe seguir visible tras el fundido.
		if _cartel_lugar != null:
			_cartel_lugar.ocultar()
		# Recuerda si el warp parte de un interior y el nombre de origen (cartel de
		# cambio de lugar).
		_warp_origen_interior = mapa_actual != null and mapa_actual.esInterior
		_warp_nombre_origen = _nombre_lugar_actual_resuelto()
		mapa_anterior_key = mapa_actual_key
		coneccion_destino = destino
		coneccion_posicion = posicion
		coneccion_direccion = direccion
		coneccion_dar_paso = dar_paso
		#await get_tree().create_timer(3).timeout
		coneccion = 30 if _warp_perfil else coneccion + 1
	elif coneccion == 30:
		# Nunca intercambiar mapas antes de que el fundido cubra la pantalla.
		if telon.en_transicion:
			return
		for node in get_tree().get_nodes_in_group("FlechaSalida"):
			node.queue_free()

		# Determinar si el destino es un mapa exterior (en el Overworld) o un interior
		# Con la pantalla ya en negro: si el destino es de una región aún no
		# cargada (placeholder), se carga aquí.
		var mapa_en_overworld = _buscar_mapa_en_overworld(coneccion_destino, true) if nodo_overworld else null
		var nuevo_interior: MapaConfiguracion = null
		var reutilizar_interior := _warp_perfil and coneccion_destino == mapa_actual_key and mapa_actual != null and not _es_hijo_de_overworld(mapa_actual)
		if mapa_en_overworld == null and not reutilizar_interior:
			# Preparar ANTES de ocultar/liberar origen o añadir el destino al árbol.
			# Un contexto roto no debe destruir el mapa donde aún vive el jugador.
			nuevo_interior = _instanciar_mapa_por_nombre(coneccion_destino, _contexto_destino_warp)
			if nuevo_interior == null:
				push_warning("[ADMIN] Destino/contexto inválido: '%s'" % coneccion_destino)
				jugador.visible = true
				jugador.no_control = false
				telon.aclarar()
				Singleton.mantener_pausa(&"warp_cueva", false)
				_warp_cueva = 0
				coneccion = 0
				_contexto_destino_warp.clear()
				_capa_destino_warp = -1
				_warp_origen_interior = false
				_warp_nombre_origen = ""
				_warp_por_buceo = false
				if _warp_perfil:
					_warp_perfil = false
					warp_perfil_finalizado.emit(false)
				return

		if _warp_cueva != 0:
			_warp_animando_cueva = true
			await telon.transicion_cueva(_warp_cueva == 1)
			_warp_animando_cueva = false

		# El destino puede necesitar el origen antes de liberar/reparentar al jugador
		# (el ascensor debe regresar a la planta desde la que se entró).
		if nuevo_interior != null and nuevo_interior.has_method("preparar_origen_warp"):
			var celda_origen := Vector2i(((jugador.global_position - jugador_offset - mapa_actual.global_position) / Singleton.TILE_SIZE).floor())
			nuevo_interior.call("preparar_origen_warp", mapa_actual_key, celda_origen)

		# ClearTempFieldEventData (sub_8053994, en todo warp): las FLAG_TEMP_* se
		# borran antes de que nazca el destino, así sus árboles y su hierba cortables
		# vuelven a salir (los del Overworld lo hacen al recibir la señal).
		SistemaGuardado.limpiar_temporales()

		if mapa_en_overworld:
			# Destino exterior: no liberar nada del Overworld
			if mapa_actual and not _es_hijo_de_overworld(mapa_actual):
				# Venimos de un interior: liberar el mapa interior
				mapa_actual.queue_free()
			if nodo_overworld:
				nodo_overworld.visible = true
			mapa_actual = mapa_en_overworld
			mapa_actual.visible = true
			mapa_actual.foco = true
			mapa_actual_offset = mapa_actual.posicion_en_mundo()
		elif not reutilizar_interior:
			# Destino interior: instanciar como antes
			if mapa_actual and _es_hijo_de_overworld(mapa_actual):
				# Venimos de un exterior: ocultar Overworld
				if nodo_overworld:
					nodo_overworld.visible = false
			elif mapa_actual:
				# Interior → interior: liberar el interior previo
				mapa_actual.queue_free()
			mapa_actual = nuevo_interior
			mapa_actual.visible = false
			mapa_actual_offset = Vector2.ZERO
			add_child(mapa_actual)
			move_child(mapa_actual, 0)

		# IMPORTANTE: Actualizar la clave del mapa actual para que el sistema de conexiones funcione
		mapa_actual_key = coneccion_destino

		var capa_origen := Singleton.capa_activa
		Singleton.set_tile_map_con_capa(mapa_actual, capa_origen if _capa_destino_warp < 0 else _capa_destino_warp)
		# Reparentar jugador al nodo NPCs del nuevo mapa (para y_sort)
		if jugador != null:
			_reparentar_personaje_a_mapa(jugador, mapa_actual)
		# Con el jugador ya fuera del mapa de origen: mostrar solo la región del
		# destino y liberar la que se deja.
		_actualizar_regiones()
		# Con la pantalla en negro y antes de resolver la música del destino.
		_aplicar_avatar_llegada_warp(Vector2i(coneccion_posicion.floor()))
		cam.inmediato = true
		cam.en_foco = false
		coneccion = 40 if _warp_perfil else coneccion + 1

		_entrar_destino_warp(Vector2i(coneccion_posicion.floor()))
		procesar_revanchas_mapa_actual()
		_al_cambiar_de_mapa(false)
		mapa_actual.notificar_mapa_activado(true)
		_notificar_entrada_por_warp()
		_registrar_visita_mapa_actual()

	elif coneccion == 40:
		# Convertir coordenadas de tile a píxeles, sumando offset del personaje y del mapa (si está en Overworld)
		var posicion_pixeles = Vector2(coneccion_posicion.x*16, coneccion_posicion.y*16) + jugador_offset + mapa_actual_offset
		var incluir_jugador_en_spawn := not coneccion_dar_paso
		if _warp_perfil:
			jugador.teletransporte(posicion_pixeles, coneccion_direccion, false, false)
		else:
			jugador.teletransporte(posicion_pixeles, coneccion_direccion, coneccion_dar_paso)
		coneccion = 0
		# Con el jugador ya en el destino: climas persistentes con zona de llegada.
		# Va antes del poll de los disparadores de este mismo frame (son hijos del
		# administrador), que consumiría la llegada pendiente.
		_evaluar_llegada_climas_persistentes()
		coneccion_dar_paso = false	# Por si acaso, porque se queda caminando luego del debuger
		mapa_actual.visible = true
		jugador.visible = true
		jugador.no_control = false
		# El bloqueo por derrota dura exactamente la pantalla negra del warp.
		Singleton.mantener_pausa(&"derrota", false)
		if _warp_perfil:
			warp_perfil_preparado.emit()
		telon.aclarar()
		if _warp_cueva != 0 or _warp_perfil:
			await telon.pantalla_aclarada
		if _warp_cueva != 0:
			Singleton.mantener_pausa(&"warp_cueva", false)
			_warp_cueva = 0
		_programar_validacion_spawns_en_mapa(incluir_jugador_en_spawn)
		_anunciar_lugar_tras_warp()
		_warp_origen_interior = false
		_warp_nombre_origen = ""
		_contexto_destino_warp.clear()
		_capa_destino_warp = -1
		if mapa_actual is InteriorBaseSecreta and dialogo_bases != null:
			(mapa_actual as InteriorBaseSecreta).presentar_vista_previa(self)
		if _warp_perfil:
			_warp_perfil = false
			warp_perfil_finalizado.emit(true)
	else:
		coneccion += 1
	print("conex ", coneccion)


## es_cueva representa MAP_TYPE_UNDERGROUND, no esInterior ni la necesidad de FLASH.
## Leer el estado de la escena evita instanciar dos veces el destino y sus eventos.
func _resolver_transicion_cueva(destino: String) -> int:
	if mapa_actual == null:
		return 0
	var mapa_exterior := _buscar_mapa_en_overworld(destino) if nodo_overworld else null
	var destino_cueva := false
	if mapa_exterior != null:
		destino_cueva = mapa_exterior.es_cueva
	else:
		var escena: PackedScene = Singleton._buscar_mapa_por_nombre(destino)
		if escena == null:
			return 0
		destino_cueva = _escena_es_cueva(escena)
	if mapa_actual.es_cueva == destino_cueva:
		return 0
	return 1 if destino_cueva else -1


static func _escena_es_cueva(escena: PackedScene) -> bool:
	return _propiedad_raiz_escena(escena, &"es_cueva")


## ¿El mapa `destino` prohíbe la bici (solo_caminar, Overworld_IsBikingAllowed() == FALSE)?
## Se lee de la escena sin instanciarla, como `es_cueva`.
func destino_solo_caminar(destino: String) -> bool:
	var mapa_exterior := _buscar_mapa_en_overworld(destino) if nodo_overworld else null
	if mapa_exterior != null:
		return mapa_exterior.solo_caminar
	var escena: PackedScene = Singleton._buscar_mapa_por_nombre(destino)
	return escena != null and _propiedad_raiz_escena(escena, &"solo_caminar")


## Valor booleano de `propiedad` en el nodo raíz de `escena` (o de su escena base).
static func _propiedad_raiz_escena(escena: PackedScene, propiedad: StringName) -> bool:
	var estado := escena.get_state()
	for i in range(estado.get_node_property_count(0)):
		if estado.get_node_property_name(0, i) == propiedad:
			return bool(estado.get_node_property_value(0, i))
	var base := estado.get_base_scene_state()
	while base != null:
		for i in range(base.get_node_property_count(0)):
			if base.get_node_property_name(0, i) == propiedad:
				return bool(base.get_node_property_value(0, i))
		base = base.get_base_scene_state()
	return false

## Fase 30 de un warp (telón en negro, el jugador aún no se ha teletransportado):
## el destino recibe su clima antes de que el telón se aclare, resolviendo el
## clima por zona de entrada (SelectorClimaEntrada) con `celda_destino`, como la
## MAP_SCRIPT_ON_TRANSITION del GBA, y validarInterior() ajusta visibilidad,
## música y lugar SIN volver a aplicarlo: el clima se aplica una sola vez por
## warp. Una segunda aplicación en la misma transición vería el mapa previo ya
## igual al actual, conservaría los climas persistentes recién reiniciados y
## borraría su llegada pendiente, que se evalúa en la fase 40 tras el
## teletransporte (`_evaluar_llegada_climas_persistentes`).
func _entrar_destino_warp(celda_destino: Vector2i) -> void:
	_aplicar_clima_mapa_actual_inmediato(celda_destino)
	validarInterior(celda_destino, false)


## dive_warp (field_control_avatar.c): BUCEO lleva a `destino` en `celda` con el
## fundido de un warp, conservando la dirección del jugador. false si ya hay un
## warp en curso o el destino no existe en el proyecto.
func conectar_buceo(destino: String, celda: Vector2i) -> bool:
	if jugador == null or coneccion != 0 or not destino_warp_valido(destino, Vector2(celda)):
		return false
	_warp_por_buceo = true
	jugador.no_control = true
	conectar_escalera(destino, Vector2(celda), jugador.facing_direction, false)
	return true


## Avatar al cargar el mapa de llegada de un warp (GetAdjustedInitialTransitionFlags):
## en un mapa submarino el jugador bucea; al dejarlo vuelve a pie, salvo si emerge
## con BUCEO al agua, que queda haciendo surf (Buceo.llega_surfeando).
func _aplicar_avatar_llegada_warp(celda: Vector2i) -> void:
	var por_buceo := _warp_por_buceo
	_warp_por_buceo = false
	if jugador == null or mapa_actual == null or not jugador.has_method("aplicar_estado_llegada_mapa"):
		return
	var surfear := por_buceo and Buceo.llega_surfeando(mapa_actual, mapa_actual.get_capa_resuelta(Singleton.capa_activa), celda)
	jugador.call("aplicar_estado_llegada_mapa", mapa_actual.mapa_submarino, surfear, mapa_actual.solo_caminar)


func teletransportar_a_punto_curacion() -> bool:
	if jugador == null or not has_node("/root/SistemaGuardado"):
		return false
	var punto: Dictionary = EstructuraGuardado.PUNTO_CURACION_POR_DEFECTO.duplicate(true)
	var punto_guardado: Variant = SistemaGuardado.get_punto_curacion() if SistemaGuardado.has_method("get_punto_curacion") else {}
	if punto_guardado is Dictionary:
		for clave in punto_guardado.keys():
			punto[clave] = punto_guardado[clave]
	var mapa_destino := str(punto.get("mapa_actual", ""))
	if mapa_destino.is_empty() or not _mapa_existe(mapa_destino):
		push_error("[ADMIN] Punto de curacion invalido: %s" % mapa_destino)
		return false
	jugador.no_control = true
	conectar_escalera(
		mapa_destino,
		Vector2(float(punto.get("cx", 0)), float(punto.get("cy", 0))),
		Vector2.DOWN,
		false
	)
	return true

## ===== Entrada exterior (warp4 de pokeruby, sub_80535C4) =====
## Al empezar un paso hacia un warp que lleva de un mapa del Overworld a uno que
## no está en él (interior), se guarda la celda de salida del paso (la de delante
## de la entrada). La usan CUERDA HUIDA, EXCAVAR y la enfermera del Centro.

## Grupos en los que se apuntan los warps (Warp.GRUPOS).
const GRUPOS_WARP: Array[StringName] = [&"Escaleras", &"Salidas", &"Puertas", &"Huecos", &"Geiseres"]

## Warp de `mapa` en `celda` (celdas locales del mapa, como pos_celda_act), o null.
func warp_en_celda(mapa: MapaConfiguracion, celda: Vector2i) -> Warp:
	if mapa == null or not mapa.is_inside_tree():
		return null
	for grupo: StringName in GRUPOS_WARP:
		for nodo: Node in mapa.get_tree().get_nodes_in_group(grupo):
			var warp := nodo as Warp
			if warp != null and mapa.is_ancestor_of(warp) and mapa.global_to_map_cell(warp.global_position) == celda:
				return warp
	return null

## ¿`warp` (de `mapa`) lleva de un mapa del Overworld a uno que no está en él?
## false si el destino no se puede resolver.
func warp_lleva_de_exterior_a_interior(mapa: MapaConfiguracion, warp: Warp) -> bool:
	if mapa == null or warp == null or not _es_hijo_de_overworld(mapa):
		return false
	var destino := warp.ruta_mapa_destino
	if destino.is_empty() or not _mapa_existe(destino):
		return false
	return not es_mapa_del_overworld(destino)

## Gancho de inicio de paso del jugador (character.gd, celdas locales del mapa
## actual). Devuelve true si se guardó una entrada nueva. Un paso que sale de otro
## warp (p. ej. a lo largo de un felpudo de SALIDAS) conserva la anterior: llegar
## con CUERDA HUIDA encima de una salida la volvería a activar.
func registrar_entrada_exterior(celda_origen: Vector2i, celda_destino: Vector2i) -> bool:
	var warp := warp_en_celda(mapa_actual, celda_destino)
	if warp == null or not warp_lleva_de_exterior_a_interior(mapa_actual, warp):
		return false
	if warp_en_celda(mapa_actual, celda_origen) != null:
		return false
	SistemaGuardado.set_entrada_exterior({
		"mapa_actual": _clave_de_mapa(mapa_actual),
		"cx": celda_origen.x,
		"cy": celda_origen.y,
		"capa_datos": Singleton.capa_activa,
		"nombre_lugar": mapa_actual.obtener_seccion_efectiva(),
	})
	return true

## setescapewarp (MAP_SCRIPT_ON_RESUME de la cabecera): si `mapa` tiene `mapa_huida`,
## esa pasa a ser la entrada exterior. Los interiores a los que se pasa desde él no
## la tocan (registrar_entrada_exterior solo guarda al entrar desde el Overworld), así
## que vale también para las salas siguientes. true si se cambió.
static func aplicar_entrada_huida_del_mapa(mapa: MapaConfiguracion) -> bool:
	if mapa == null or mapa.mapa_huida.is_empty():
		return false
	SistemaGuardado.set_entrada_exterior({
		"mapa_actual": mapa.mapa_huida,
		"cx": mapa.celda_huida.x,
		"cy": mapa.celda_huida.y,
		"capa_datos": 0,
		"nombre_lugar": mapa.obtener_seccion_efectiva(),
	})
	return true

## Clave con la que conectar_escalera encuentra `mapa` (nombre de su escena).
func _clave_de_mapa(mapa: MapaConfiguracion) -> String:
	var clave := mapa.scene_file_path.get_file().get_basename()
	return clave if not clave.is_empty() else String(mapa.name)

## CUERDA HUIDA y EXCAVAR (sub_8053678 + WarpIntoMap): warp a la entrada
## exterior guardada, mirando al sur (GetAdjustedInitialDirection). false si no
## hay entrada o su mapa no existe.
func teletransportar_a_entrada_exterior() -> bool:
	if jugador == null:
		return false
	var entrada: Dictionary = SistemaGuardado.get_entrada_exterior()
	var mapa_destino := str(entrada.get("mapa_actual", ""))
	if mapa_destino.is_empty() or not _mapa_existe(mapa_destino):
		push_warning("[ADMIN] Entrada exterior inválida: '%s'" % mapa_destino)
		return false
	jugador.no_control = true
	conectar_escalera(
		mapa_destino,
		Vector2(float(entrada.get("cx", 0)), float(entrada.get("cy", 0))),
		Vector2.DOWN,
		false
	)
	return true

func _on_play_sound(sound_name: String) -> void:
	if sound_name in Singleton.se:
		sfx_player.stream = Singleton.se[sound_name]
		sfx_player.play()
	else:
		print("Sonido no encontrado en el diccionario: ", sound_name)

func abrir_menu() -> void:
	if mapa_actual != null and mapa_actual.bloquea_menu():
		return
	# No abrir menú si estamos en diálogo o el jugador no tiene control
	if en_dialogo or jugador.no_control:
		_logear("❌ No se puede abrir menú: en_dialogo=%s, no_control=%s" % [en_dialogo, jugador.no_control])
		return

	_logear("Abriendo menú")
	# El equipo puede haber cambiado desde el arranque (primera captura).
	actualizar_opciones_menu()
	# Nodo en .Menu/MenuPausa
	var menu_pausa = get_node("./Menu/MenuPausa")
	if menu_pausa:
		# menu_pausa.show()
		# menu_pausa.focused = true
		menu_pausa.configurar_menu_dinamico()
		menu_pausa.visible = true
		menu_pausa.ventana_activa = 1  # V_MENU
		Singleton.mantener_pausa(&"menu", true)
	else:
		_logear("❌ No se encontró MenuPausa")

func imprime():
	imprimiendo = true
	print("Lista de children: ")
	for child in get_children(true):
		print(child.name, " pos: ", child.position)
	print("--- mapa_actual: ", mapa_actual.get_viewport().size)
	await get_tree().create_timer(1).timeout
	imprimiendo = false


## Ajusta la visibilidad al cambiar de mapa. `enExterior` significa "el
## Overworld está activo": un exterior suelto (isla que no está en el
## Overworld) se comporta como un interior a estos efectos, porque el Overworld
## se dibuja encima y lo taparía.
## `celda_entrada_clima`: celda de destino del warp para el clima por zona de
## entrada al llegar a un exterior (el jugador aún no se ha teletransportado).
## `aplicar_clima`: false si el clima del mapa ya se aplicó en esta misma entrada
## (fase 30 de un warp, ver `_entrar_destino_warp`).
func validarInterior(celda_entrada_clima: Variant = null, aplicar_clima: bool = true) -> void:
	var en_overworld := _mapa_actual_en_overworld()
	if en_overworld:
		if not enExterior:
			enExterior = true
			print("Paso a exterior (Overworld)")
			if nodo_overworld:
				nodo_overworld.visible = true
			mapa_actual.visible = true
			mapa_actual.foco = true
			actualizar_escenario(celda_entrada_clima, aplicar_clima)
		else:
			# Warp exterior → exterior (p. ej. VUELO): música, clave de lugar y
			# cartel del nuevo mapa. reproducir_tema ignora el tema que ya suena.
			print("Se mantiene en exterior")
			actualizar_escenario(celda_entrada_clima, aplicar_clima)
	else:
		if enExterior:
			enExterior = false
			print("Paso a interior o exterior suelto")
			if nodo_overworld:
				nodo_overworld.visible = false
		else:
			print("Se mantiene en interior")
		# Actualiza música del mapa (interiores y exteriores sueltos), también entre
		# ellos: de ARRECÍPOLIS (exterior suelto) a su cueva o de un interior a otro.
		# Interiores sin tema propio heredan el del mapa exterior asociado.
		# reproducir_tema ignora el tema que ya suena.
		var tema_mapa := obtener_musica_lugar_actual()
		if tema_mapa != "":
			print("🎵 Reproduciendo música del mapa: ", tema_mapa)
			musica_player.reproducir_tema(tema_mapa, 2)
		else:
			_detener_musica_si_mapa_sin_musica()

## Busca un MapaConfiguracion dentro del Overworld cuyo archivo de escena coincida con mapa_key.
## `cargar_region`: si el mapa es de una región aún no cargada, la carga.
func _buscar_mapa_en_overworld(mapa_key: String, cargar_region: bool = false) -> MapaConfiguracion:
	return _buscar_mapa_en_mundo(nodo_overworld, mapa_key, cargar_region)


func _buscar_mapa_en_mundo(mundo: Node, mapa_key: String, cargar_region: bool = false) -> MapaConfiguracion:
	if mundo == null:
		return null
	var key_norm := _normalizar_clave_mapa(mapa_key)
	var mapa := _buscar_mapa_en_lista(_mapas_del_mundo(mundo), key_norm)
	if mapa != null or not cargar_region:
		return mapa
	var placeholder := _placeholder_de_mapa(mundo, key_norm)
	if placeholder == null:
		return null
	var region := _cargar_region(placeholder)
	return _buscar_mapa_en_lista(region.mapas(), key_norm) if region != null else null


func _buscar_mapa_en_lista(mapas: Array[MapaConfiguracion], key_norm: String) -> MapaConfiguracion:
	for mapa: MapaConfiguracion in mapas:
		var scene_basename := _normalizar_clave_mapa(mapa.scene_file_path.get_file().get_basename())
		var node_name := _normalizar_clave_mapa(mapa.name)
		var internal_name := _normalizar_clave_mapa(mapa.nombre_interno)
		if scene_basename == key_norm or node_name == key_norm or internal_name == key_norm:
			return mapa
	return null

func _normalizar_clave_mapa(valor: String) -> String:
	return valor.to_lower().replace("_", "").replace("-", "").replace(" ", "")

## Mapas cargados del Overworld `mundo`: los sueltos y los de sus regiones cargadas.
func _mapas_del_mundo(mundo: Node) -> Array[MapaConfiguracion]:
	var mapas: Array[MapaConfiguracion] = []
	if mundo == null:
		return mapas
	for hijo: Node in mundo.get_children():
		if hijo is MapaConfiguracion:
			mapas.append(hijo as MapaConfiguracion)
		elif hijo is RegionOverworld:
			mapas.append_array((hijo as RegionOverworld).mapas())
	return mapas

## ¿`mapa_key` es un mapa del Overworld, cargado o dentro de una región sin cargar?
func es_mapa_del_overworld(mapa_key: String) -> bool:
	if _buscar_mapa_en_overworld(mapa_key) != null:
		return true
	return _placeholder_de_mapa(nodo_overworld, _normalizar_clave_mapa(mapa_key)) != null

## Placeholder de región de `mundo` cuya escena contiene el mapa `key_norm`
## (clave normalizada), o null.
func _placeholder_de_mapa(mundo: Node, key_norm: String) -> InstancePlaceholder:
	if mundo == null:
		return null
	for hijo: Node in mundo.get_children():
		var placeholder := hijo as InstancePlaceholder
		if placeholder != null and _claves_de_placeholder(placeholder).has(key_norm):
			return placeholder
	return null

func _claves_de_placeholder(placeholder: InstancePlaceholder) -> PackedStringArray:
	var ruta := placeholder.get_instance_path()
	if not _claves_region.has(ruta):
		var claves := PackedStringArray()
		for clave: String in RegionOverworld.claves_de_escena(ruta):
			claves.append(_normalizar_clave_mapa(clave))
		_claves_region[ruta] = claves
	return _claves_region[ruta]

## Instancia la región de `placeholder` junto a él (con la posición que tiene en
## Overworld.tscn), oculta hasta que _actualizar_regiones la muestre.
func _cargar_region(placeholder: InstancePlaceholder) -> RegionOverworld:
	var cargada: Variant = _regiones_cargadas.get(placeholder)
	if is_instance_valid(cargada):
		return cargada as RegionOverworld
	var region := RegionOverworld.instanciar_desde(placeholder)
	if region == null:
		push_error("[ADMIN] La escena de región '%s' no tiene RegionOverworld en la raíz." % placeholder.get_instance_path())
		return null
	region.visible = false
	_regiones_cargadas[placeholder] = region
	print("🗺️ [ADMIN] Región cargada: %s" % placeholder.name)
	# Al iniciar, el Overworld aún no está en el árbol: iniciar_escenario y
	# _configurar_mapa_inicial_activo cubren estos pasos para todos los mapas.
	if region.is_inside_tree():
		for mapa: MapaConfiguracion in region.mapas():
			_conectar_notificador_mapa(mapa)
		HierbaCortableMapa.restaurar_guardado(region.mapas())
	return region

## Región del Overworld a la que pertenece `mapa`; null si es un mapa suelto del
## Overworld o no está en él.
func _region_de_mapa(mapa: Node) -> RegionOverworld:
	if mapa == null or not _es_hijo_de_overworld(mapa):
		return null
	return mapa.get_parent() as RegionOverworld

## Solo se ve la región del mapa actual; dentro de una región se ocultan los
## mapas sueltos del Overworld (puede estar solapada con ellos). Libera las
## regiones cargadas que ya no contienen el mapa actual.
func _actualizar_regiones() -> void:
	if nodo_overworld == null:
		return
	var region_actual := _region_de_mapa(mapa_actual)
	for hijo: Node in nodo_overworld.get_children():
		if hijo is RegionOverworld:
			(hijo as RegionOverworld).visible = hijo == region_actual
	if region_actual != null:
		for hijo: Node in nodo_overworld.get_children():
			var suelto := hijo as MapaConfiguracion
			if suelto != null and suelto.visible:
				suelto.visible = false
				_mapas_ocultos_por_region.append(suelto)
	else:
		for suelto: MapaConfiguracion in _mapas_ocultos_por_region:
			if is_instance_valid(suelto):
				suelto.visible = true
		_mapas_ocultos_por_region.clear()
	for placeholder: Variant in _regiones_cargadas.keys():
		var region: Variant = _regiones_cargadas[placeholder]
		if is_instance_valid(region) and region == region_actual:
			continue
		_regiones_cargadas.erase(placeholder)
		if is_instance_valid(region):
			for mapa: MapaConfiguracion in (region as RegionOverworld).mapas():
				mapas_activos.erase(mapa)
			print("🗺️ [ADMIN] Región liberada: %s" % (region as RegionOverworld).name)
			# Fuera del árbol ya: el resto del warp no debe encontrar sus mapas.
			var nodo_region := region as RegionOverworld
			if nodo_region.get_parent() != null:
				nodo_region.get_parent().remove_child(nodo_region)
			nodo_region.queue_free()

## ¿`mapa` es del Overworld (suelto o dentro de una de sus regiones)?
func _es_hijo_de_overworld(mapa: Node) -> bool:
	if nodo_overworld == null or mapa == null:
		return false
	var padre := mapa.get_parent()
	return padre == nodo_overworld or (padre is RegionOverworld and padre.get_parent() == nodo_overworld)

## ¿El mapa actual forma parte del Overworld (mundo contiguo)?[br]
## Los exteriores sueltos (islas fuera del Overworld, p. ej. Frente Batalla) no
## lo son y deben mostrarse solos: el Overworld se añade después en el árbol y
## se dibuja encima, así que si no se oculta se ve otro mapa (Villa Raíz está
## en el mismo (0, 0)).
func _mapa_actual_en_overworld() -> bool:
	return mapa_actual != null and _es_hijo_de_overworld(mapa_actual)

func _instanciar_mapa_por_nombre(mapa_key: String, contexto: Dictionary = {}) -> MapaConfiguracion:
	# if mapa_key.to_lower() == "camion":
	# 	return SCN_MAPA_CAMION.instantiate() as MapaConfiguracion
	var mapa_scene := Singleton._buscar_mapa_por_nombre(mapa_key)
	if mapa_scene == null:
		return null
	var nodo: Node = mapa_scene.instantiate()
	if not nodo is MapaConfiguracion:
		nodo.free()
		return null
	var mapa: MapaConfiguracion = nodo as MapaConfiguracion
	if not mapa.preparar_entrada(contexto):
		mapa.free()
		return null
	return mapa


## Entrada confirmada o vista previa. Solo agenda navegación, sin mutar propiedad.
func entrar_base_secreta(entrada_id: int, retorno: Dictionary, vista_previa: bool = false) -> bool:
	if jugador == null or mapa_actual == null or coneccion != 0:
		return false
	var contexto: Dictionary = ContextoBaseSecreta.crear(entrada_id, retorno, vista_previa,
		SistemaGuardado.get_bases_secretas())
	if contexto.is_empty() or _clave_de_mapa(mapa_actual) != str(contexto["retorno"]["mapa_actual"]):
		return false
	var regreso: Dictionary = contexto["retorno"]
	if mapa_actual.get_capa_por_id(int(regreso["capa_datos"])) == null \
		or not _coord_esta_dentro_del_mapa(mapa_actual, Vector2i(regreso["cx"], regreso["cy"])):
		return false
	var entrada: Dictionary = DatosBasesSecretas.entrada(entrada_id)
	var interior: Dictionary = DatosBasesSecretas.interior(int(entrada["interior_id"]))
	var celda: Array = interior["entrada_original"]
	jugador.no_control = true
	conectar_escalera(str(interior["nombre_interno"]), Vector2(celda[0], celda[1]),
		Vector2.UP, false, false, contexto, 0)
	return true


func salir_base_secreta(interior: InteriorBaseSecreta, retorno: Dictionary) -> bool:
	if jugador == null or mapa_actual != interior or coneccion != 0:
		return false
	var normalizado: Dictionary = SistemaBasesSecretas.normalizar_retorno(retorno)
	if normalizado.is_empty() or not _mapa_existe(str(normalizado["mapa_actual"])):
		return false
	jugador.no_control = true
	var dir: Array = normalizado["direccion"]
	conectar_escalera(str(normalizado["mapa_actual"]), Vector2(normalizado["cx"], normalizado["cy"]),
		Vector2(dir[0], dir[1]), false, false, {}, int(normalizado["capa_datos"]))
	return true


func confirmar_base_secreta(interior: InteriorBaseSecreta) -> bool:
	if mapa_actual != interior or jugador == null or coneccion != 0 or not interior.es_vista_previa():
		return false
	if not interior.aceptar_vista_previa(SistemaGuardado.datos_vivos.jugador):
		return false
	actualizar_entradas_bases_secretas()
	var original: Dictionary = DatosBasesSecretas.interior(interior.interior_id)
	var inicio: Array = original["inicio_confirmado_original"]
	jugador.no_control = true
	conectar_escalera(str(original["nombre_interno"]), Vector2(inicio[0], inicio[1]),
		Vector2.UP, false, false, interior.obtener_contexto(), 0)
	return true


## Cerrar también entradas de rutas cargadas pero ocultas/inactivas en Overworld.
func actualizar_entradas_bases_secretas() -> void:
	for entrada: Node in get_tree().get_nodes_in_group("entradas_bases_secretas"):
		if entrada is EntradaBaseSecreta:
			(entrada as EntradaBaseSecreta).actualizar_propiedad()


func desmontar_base_para_traslado(entrada: EntradaBaseSecreta, anterior: int) -> bool:
	var sistema: SistemaBasesSecretas = SistemaGuardado.get_bases_secretas()
	if entrada == null or mapa_actual != entrada._mapa_padre() or coneccion != 0 \
		or not entrada._activa or not sistema.es_compatible() or sistema.id_base() != anterior or anterior == 0:
		return false
	await telon.oscurecer()
	# Revalidar tras el await: no borrar una propiedad sustituida durante el diálogo.
	if not is_instance_valid(entrada) or mapa_actual != entrada._mapa_padre() or coneccion != 0 \
		or SistemaGuardado.get_bases_secretas() != sistema or sistema.id_base() != anterior:
		await telon.aclarar()
		return false
	sistema.recoger_base()
	sistema.limpiar_retorno()  # Exterior: no hay interior pendiente de abandonar.
	actualizar_entradas_bases_secretas()
	await telon.aclarar()
	return true


## Operación que llamará RECOGER BASE del PC (menú declarativo en 5.3).
func recoger_base_secreta(interior: InteriorBaseSecreta) -> bool:
	var sistema: SistemaBasesSecretas = SistemaGuardado.get_bases_secretas()
	if mapa_actual != interior or interior == null or interior.es_vista_previa() or coneccion != 0 \
		or not interior._recogida_activa or interior.sistema != sistema \
		or not sistema.es_compatible() or sistema.id_base() != int(interior.obtener_contexto().get("entrada_id", 0)) \
		or not sistema.tiene_base():
		return false
	# Primero asegurar que se puede agendar salida; no desmontar ante un origen inválido.
	if not interior.solicitar_salida(self):
		return false
	sistema.recoger_base()
	sistema.limpiar_retorno()  # La transición conserva el retorno volátil del interior.
	actualizar_entradas_bases_secretas()
	return true

func _configurar_mapa_inicial_activo() -> void:
	if mapa_actual == null:
		return

	mapa_actual.visible = true
	mapa_actual.foco = true

	enExterior = _mapa_actual_en_overworld()
	if enExterior:
		mapa_actual_offset = mapa_actual.posicion_en_mundo()
	else:
		mapa_actual_offset = Vector2.ZERO
	if nodo_overworld:
		nodo_overworld.visible = enExterior
	_actualizar_regiones()
	var motivo := ""
	if not enExterior:
		motivo = " (interior)" if mapa_actual.esInterior else " (exterior suelto)"
	print("🗺️ [ADMIN] Mapa inicial '%s' → Overworld %s%s" % [
		mapa_actual_key, "visible" if enExterior else "oculto", motivo,
	])

	# Punto de partida para comparar cambios de lugar. Continuar una partida
	# guardada anuncia el lugar aparte (_on_continuar_solicitado).
	_nombre_lugar_anunciado = _nombre_lugar_actual_resuelto()
	procesar_revanchas_mapa_actual()
	# Cargar la partida no limpia las FLAG_TEMP_* (viajan en el guardado): la
	# hierba cortada se vuelve a aplicar en los mapas que la tengan.
	var mapas_cargados: Array = _mapas_del_mundo(nodo_overworld)
	mapas_cargados.append(mapa_actual)
	HierbaCortableMapa.restaurar_guardado(mapas_cargados)
	_al_cambiar_de_mapa(false)
	mapa_actual.notificar_mapa_activado(false)
	actualizar_escenario()

func _coord_esta_dentro_del_mapa(mapa: MapaConfiguracion, coord_tile: Vector2i) -> bool:
	if mapa == null:
		return true
	var rect: Rect2 = mapa.obtener_rect_util()
	return rect == Rect2() or rect.has_point(Vector2(coord_tile) * Singleton.TILE_SIZE)

func _normalizar_coord_guardada(coord_tile: Vector2i) -> Vector2i:
	if mapa_actual == null or _coord_esta_dentro_del_mapa(mapa_actual, coord_tile):
		return coord_tile
	if not _es_hijo_de_overworld(mapa_actual):
		push_warning("[ADMIN] Coordenada guardada fuera de rango para %s: %s" % [mapa_actual_key, coord_tile])
		return coord_tile

	var offset_tiles := Vector2i(
		floor(mapa_actual.posicion_en_mundo().x / Singleton.TILE_SIZE),
		floor(mapa_actual.posicion_en_mundo().y / Singleton.TILE_SIZE)
	)
	var coord_legada := coord_tile + offset_tiles
	if _coord_esta_dentro_del_mapa(mapa_actual, coord_legada):
		print("📍 [ADMIN] Coordenada guardada corregida para %s: %s -> %s" % [mapa_actual_key, coord_tile, coord_legada])
		if has_node("/root/SistemaGuardado"):
			var sistema_guardado = get_node("/root/SistemaGuardado")
			if sistema_guardado.datos_vivos and sistema_guardado.datos_vivos.posicion:
				sistema_guardado.datos_vivos.posicion.cx = coord_legada.x
				sistema_guardado.datos_vivos.posicion.cy = coord_legada.y
		return coord_legada

	push_warning("[ADMIN] Coordenada guardada fuera de rango para %s y sin corrección compatible: %s" % [mapa_actual_key, coord_tile])
	return coord_tile

func iniciar_escenario(contexto: Dictionary = {}, estado_inicio: Dictionary = {}) -> bool:
	# Preparar el mundo/destino fuera del árbol: un guardado roto no activa rutas
	# ni reemplaza referencias anteriores. La decoración ya existe al llegar a _ready.
	var mundo: Node2D = overworld_scene.instantiate() as Node2D
	_regiones_cargadas.clear()
	_mapas_ocultos_por_region.clear()
	var destino: MapaConfiguracion = _buscar_mapa_en_mundo(mundo, mapa_actual_key, true)
	var independiente: bool = destino == null
	if independiente:
		destino = _instanciar_mapa_por_nombre(mapa_actual_key, contexto)
		if destino == null:
			mundo.free()
			push_error("[ADMIN] Mapa '%s' no encontrado ni en Overworld ni como escena independiente." % mapa_actual_key)
			return false
	if destino is InteriorBaseSecreta:
		var retorno: Dictionary = (destino as InteriorBaseSecreta).obtener_contexto().get("retorno", {})
		var exterior: MapaConfiguracion = _buscar_mapa_en_mundo(mundo, str(retorno.get("mapa_actual", "")))
		var celda: Vector2i = Vector2i(int(estado_inicio.get("cx", -1)), int(estado_inicio.get("cy", -1)))
		if exterior == null or exterior.get_capa_por_id(int(retorno.get("capa_datos", -1))) == null \
			or not _coord_esta_dentro_del_mapa(exterior, Vector2i(retorno.get("cx", -1), retorno.get("cy", -1))) \
			or destino.get_capa_por_id(int(estado_inicio.get("capa_datos", 0))) == null \
			or not _coord_esta_dentro_del_mapa(destino, celda):
			destino.free()
			mundo.free()
			push_warning("[ADMIN] Posición/retorno de base inválido al iniciar: '%s'" % mapa_actual_key)
			return false
	nodo_overworld = mundo
	mapa_actual = destino
	add_child(nodo_overworld)
	move_child(nodo_overworld, 0)
	nodo_overworld.visible = true
	_conectar_notificadores_viewport()
	if independiente:
		add_child(destino)
		move_child(destino, 0)

	_configurar_mapa_inicial_activo()
	return true

## Cambia el mapa actual a `nuevo_mapa` (debe ser hijo del Overworld).
## Actualiza todas las referencias: foco, key, offset, TileMap y llama a actualizar_escenario.
## `celda_entrada` (Vector2i, celda local de `nuevo_mapa`) es la celda a la que
## llega el jugador al cruzar el borde; el clima por zona de entrada la usa porque
## el jugador aún está en la celda de salida del mapa anterior.
func set_mapa_actual(nuevo_mapa: MapaConfiguracion, celda_entrada: Variant = null) -> void:
	if mapa_actual == nuevo_mapa:
		return
	# LoadMapFromCameraTransition: cruzar el borde también ejecuta
	# ClearTempFieldEventData antes de la transición de mapa.
	SistemaGuardado.limpiar_temporales()
	var capa_origen := Singleton.capa_activa
	mapa_actual.foco = false
	mapa_anterior_key = mapa_actual_key
	mapa_actual = nuevo_mapa
	mapa_actual_key = nuevo_mapa.scene_file_path.get_file().get_basename()
	mapa_actual_offset = nuevo_mapa.posicion_en_mundo()
	mapa_actual.foco = true
	Singleton.set_tile_map_con_capa(mapa_actual, capa_origen)
	if jugador != null:
		_reparentar_personaje_a_mapa(jugador, mapa_actual)
	procesar_revanchas_mapa_actual()
	_al_cambiar_de_mapa(true)
	mapa_actual.notificar_mapa_activado(false)
	actualizar_escenario(celda_entrada)
	_programar_validacion_spawns_en_mapa(false)

func _obtener_tp_para_nodo(node: Node) -> TPTileDataMap:
	if node != null and node.has_method("obtener_tp_capa_actual"):
		return node.obtener_tp_capa_actual()
	if mapa_actual != null:
		return mapa_actual.get_capa_resuelta(Singleton.capa_activa)
	return null

func _obtener_o_crear_nodo_npcs(mapa: MapaConfiguracion) -> Node2D:
	if mapa == null:
		return null
	var nodo_npcs := mapa.get_node_or_null("NPCs")
	if nodo_npcs is Node2D:
		if nodo_npcs.z_index != 1:
			print("⚠️ [ADMIN] Nodo NPCs en mapa %s tenía z_index=%d; ajustado a 1" % [mapa.name, nodo_npcs.z_index])
			nodo_npcs.z_index = 1
		if not nodo_npcs.is_y_sort_enabled():
			print("⚠️ [ADMIN] Nodo NPCs en mapa %s tenía Y-Sort desactivado; activado" % mapa.name)
			nodo_npcs.set_y_sort_enabled(true)
		return nodo_npcs
	if nodo_npcs == null:
		nodo_npcs = Node2D.new()
		nodo_npcs.name = "NPCs"
		nodo_npcs.z_index = 1
		nodo_npcs.set_y_sort_enabled(true)
		mapa.add_child(nodo_npcs)
		print("⚠️ [ADMIN] Faltaba el nodo NPCs en mapa %s; creado con z_index=1 y Y-Sort activo" % mapa.name)
		return nodo_npcs
	push_warning("[ADMIN] El nodo NPCs en mapa %s existe pero no es Node2D; no se pudo normalizar" % mapa.name)
	return nodo_npcs as Node2D

func _reparentar_personaje_a_mapa(node: Node2D, mapa: MapaConfiguracion) -> void:
	if node == null or mapa == null:
		return
	var nodo_npcs := _obtener_o_crear_nodo_npcs(mapa)
	if nodo_npcs == null:
		if node.get_parent() != self:
			node.reparent(self, true)
		return
	if node.get_parent() == null:
		nodo_npcs.add_child(node)
	elif node.get_parent() != nodo_npcs:
		node.reparent(nodo_npcs, true)

## Busca qué MapaConfiguracion del Overworld contiene la posición mundo dada (píxeles).
## Usa mapa_rect_px (cacheado desde VisibleOnScreenEnabler2D) para una comprobación rápida
## de punto-dentro-de-rect sin necesidad de acceder a datos de tiles.[br]
## Solo se buscan mapas de la misma región que el mapa actual (o solo los sueltos
## si no está en una región): los bordes no cruzan entre regiones.
func encontrar_mapa_en_posicion_mundo(pos_px: Vector2) -> MapaConfiguracion:
	if nodo_overworld == null:
		return null
	var region := _region_de_mapa(mapa_actual)
	# Prefiltrar por mapas activos en viewport; fallback a todos si aún no hay datos
	var lista: Array[MapaConfiguracion] = []
	for activo: MapaConfiguracion in mapas_activos:
		if is_instance_valid(activo) and _es_hijo_de_overworld(activo) and _region_de_mapa(activo) == region:
			lista.append(activo)
	if lista.is_empty():
		if region != null:
			lista = region.mapas()
		else:
			for h: Node in nodo_overworld.get_children():
				if h is MapaConfiguracion:
					lista.append(h as MapaConfiguracion)
	for hijo: MapaConfiguracion in lista:
		if hijo.mapa_rect_px == Rect2():
			continue  # Sin rect configurado, omitir
		# Transformar pos_px a coordenadas locales del mapa y comprobar contención
		var local_px: Vector2 = pos_px - hijo.posicion_en_mundo()
		if hijo.mapa_rect_px.has_point(local_px):
			return hijo
	return null

## Conecta las señales screen_entered/screen_exited del VisibleOnScreenEnabler2D
## que ya existe en cada MapaConfiguracion, para mantener mapas_activos actualizado.
func _conectar_notificadores_viewport() -> void:
	for mapa: MapaConfiguracion in _mapas_del_mundo(nodo_overworld):
		_conectar_notificador_mapa(mapa)

func _conectar_notificador_mapa(mapa: MapaConfiguracion) -> void:
	var enabler := mapa.get_node_or_null("VisibleOnScreenEnabler2D") as VisibleOnScreenNotifier2D
	if enabler == null:
		# Fallback: crear notificador si la escena no tiene uno
		enabler = VisibleOnScreenNotifier2D.new()
		mapa.add_child(enabler)
	if not enabler.screen_entered.is_connected(_on_mapa_entra_viewport.bind(mapa)):
		enabler.screen_entered.connect(_on_mapa_entra_viewport.bind(mapa))
		enabler.screen_exited.connect(_on_mapa_sale_viewport.bind(mapa))

func _on_mapa_entra_viewport(mapa: MapaConfiguracion) -> void:
	if not mapas_activos.has(mapa):
		mapas_activos.append(mapa)

func _on_mapa_sale_viewport(mapa: MapaConfiguracion) -> void:
	mapas_activos.erase(mapa)

func _es_tema_registrado(nombre_tema: String) -> bool:
	return not nombre_tema.is_empty() and Singleton.TEMAS_REGISTRADOS.has(nombre_tema)

func _obtener_temas_precarga_mapa_actual() -> Array[String]:
	var temas: Array[String] = []
	if mapa_actual == null:
		return temas
	var tema_mapa := mapa_actual.obtener_musica_mapa_efectiva()
	if _es_tema_registrado(tema_mapa):
		temas.append(tema_mapa)
	# Temas de eventos de clima del mapa (p. ej. el desierto), para que el cambio
	# al pisar la zona de activación no espere a cargar el audio.
	for tema_evento: String in _obtener_servicio_clima().obtener_temas_musica_persistentes(mapa_actual):
		if _es_tema_registrado(tema_evento) and not temas.has(tema_evento):
			temas.append(tema_evento)
	if _es_tema_registrado(mapa_actual.musica_batalla) and not temas.has(mapa_actual.musica_batalla):
		temas.append(mapa_actual.musica_batalla)
	return temas

func actualizar_precarga_musica_contexto(contexto: String, temas: Array[String]) -> void:
	if musica_player == null:
		return
	musica_player.actualizar_precarga_contexto(contexto, temas)

func liberar_precarga_musica_contexto(contexto: String) -> void:
	if musica_player == null:
		return
	musica_player.liberar_precarga_contexto(contexto)

func _actualizar_precarga_musica_mapa_actual() -> void:
	actualizar_precarga_musica_contexto(CONTEXTO_PRECARGA_MUSICA_MAPA, _obtener_temas_precarga_mapa_actual())

## Tema del lugar donde está el jugador: el de un evento de clima persistente
## activo del mapa actual (p. ej. RUTA_111_DESIERTO con la tormenta de arena) o,
## si no hay ninguno, el del mapa.
## Tema del lugar actual. Surfeando es SURF (MUS_NAMINORI), como en
## Overworld_PlaySpecialMapMusic: así se conserva al cruzar bordes, tras una
## batalla o al continuar la partida.
func obtener_musica_lugar_actual() -> String:
	if mapa_actual == null:
		return ""
	if _jugador_surfeando() and _es_tema_registrado(TEMA_SURF):
		return TEMA_SURF
	var tema_evento := _obtener_servicio_clima().obtener_tema_musica_activo(mapa_actual)
	if not tema_evento.is_empty():
		return tema_evento
	return mapa_actual.obtener_musica_mapa_efectiva()


## Reproduce el tema del lugar tras activarse o desactivarse un evento de clima.
## Sustituye también al tema BICICLETA, igual que un cambio de mapa.
func actualizar_musica_lugar(tipo_transicion: int = 2) -> void:
	restaurar_musica_mapa_actual(tipo_transicion)


const TEMA_SURF := "SURF"


## FldEff_UseSurf: el tema SURF empieza al usar el movimiento, antes del salto.
func reproducir_musica_surf() -> void:
	if musica_player != null and _es_tema_registrado(TEMA_SURF):
		musica_player.reproducir_tema(TEMA_SURF, 2)


func _jugador_surfeando() -> bool:
	return jugador != null and bool(jugador.get("en_surf"))


## Sin tema aplicable: un mapa marcado NINGUNA detiene la música en curso; el
## resto deja sonar la que hubiera.
func _detener_musica_si_mapa_sin_musica() -> void:
	if mapa_actual != null and mapa_actual.es_sin_musica():
		print("🎵 El mapa actual está configurado sin música (NINGUNA)")
		if musica_player != null:
			musica_player.detener_reproduccion_actual()
	else:
		print("🎵 El mapa actual no tiene música asignada")


func restaurar_musica_mapa_actual(tipo_transicion: int = 0) -> void:
	if musica_player == null:
		return
	var tema_mapa: String = obtener_musica_lugar_actual()
	if _es_tema_registrado(tema_mapa):
		musica_player.reproducir_tema(tema_mapa, tipo_transicion)
	else:
		musica_player.detener_reproduccion_actual()

## Al inicio y a cada cambio de mapa exterior, se pasa por aquí.
## Actualiza música y datos de guardado. Los mapas vecinos ya están en el Overworld.
## `celda_entrada_clima` (Vector2i local del mapa actual) es la celda con la que se
## resuelve el clima por zona de entrada cuando el jugador aún no está en ella
## (destino de un warp, llegada por un borde); null = la celda del jugador.
## `aplicar_clima`: false si el clima ya se aplicó en esta misma entrada (warp).
func actualizar_escenario(celda_entrada_clima: Variant = null, aplicar_clima: bool = true) -> void:
	print("actualizar_escenario con mapa_actual_key: ", mapa_actual_key)
	if aplicar_clima:
		_aplicar_clima_mapa_actual_inmediato(celda_entrada_clima)
	_actualizar_precarga_musica_mapa_actual()

	# Interiores sin tema propio heredan el del mapa exterior asociado; un evento
	# de clima activo (desierto) impone su tema.
	var tema_mapa := obtener_musica_lugar_actual()
	if conservar_musica_warp:
		pass
	elif tema_mapa != "":
		print("🎵 Reproduciendo música del mapa: ", tema_mapa)
		musica_player.reproducir_tema(tema_mapa, 2)
	else:
		_detener_musica_si_mapa_sin_musica()

	# Actualizar la clave del lugar en el sistema de guardado
	# (`posicion.nombre_lugar` guarda la clave, p. ej. "RUTA_113").
	if SistemaGuardado and SistemaGuardado.datos_vivos:
		var datos_vivos = SistemaGuardado.datos_vivos
		if datos_vivos.posicion != null and datos_vivos.posicion.nombre_lugar != null:
			var clave_lugar := obtener_seccion_lugar_actual()
			datos_vivos.posicion.nombre_lugar = clave_lugar
			print("📍 [ADMIN] Actualizando lugar a: ", clave_lugar if clave_lugar != "" else "???")

	# Cartel de nombre de lugar: exterior→exterior (caminando por el Overworld)
	# con nombre distinto al último anunciado. La salida de un interior al
	# exterior se anuncia siempre en el fin del warp (conectar_escalera).
	_mostrar_cartel_si_cambia(_nombre_lugar_actual_resuelto())
	_registrar_visita_mapa_actual()


## FLAG_VISITED_<PUEBLO> de pokeruby: marca como visitado el mapa actual si es
## destino de VUELO. Se llama al iniciar/cargar y al cambiar de exterior
## caminando (actualizar_escenario) y en cada warp (conectar_escalera), así que
## cubre también el VUELO de exterior a exterior. Un interior cuenta como su
## `mapa_exterior_asociado` (en el GBA solo lo marca el exterior, pero a un
## interior solo se llega pasando por él; así también cubre cargar una partida
## antigua guardada dentro del Centro Pokémon).
## También activa la FLAG_LANDMARK_* asociada al mapa actual (BanderasLandmark).
func _registrar_visita_mapa_actual() -> void:
	var clave := mapa_actual_key
	if mapa_actual != null and mapa_actual.esInterior and not mapa_actual.mapa_exterior_asociado.is_empty():
		clave = mapa_actual.mapa_exterior_asociado
	if SistemaGuardado.es_destino_vuelo(clave):
		SistemaGuardado.marcar_lugar_visitado(clave)
	# setflag FLAG_LANDMARK_* del MAP_SCRIPT_ON_TRANSITION del propio mapa (no del
	# exterior asociado): el panel del PokéNav solo lista los landmarks conocidos.
	BANDERAS_LANDMARK.activar_por_mapa(mapa_actual_key)


## Mapa donde se aplicó el clima por última vez ("" antes del primero, es decir,
## al cargar la partida) y su exterior asociado si era un interior. Deciden si se
## conservan los climas persistentes y si se regenera el estado volátil del mapa.
var _clave_mapa_clima_previo: String = ""
var _exterior_mapa_clima_previo: String = ""

## Clima del mapa actual (ver ServicioClimaMapa). Se crea a demanda: los tests
## usan el administrador sin meterlo en el árbol.
var _servicio_clima: ServicioClimaMapa = null


## Servicio de clima enlazado al controlador y al jugador actuales (pueden
## cambiar en ejecución: el jugador nace en iniciar_juego y los tests inyectan
## el controlador).
func _obtener_servicio_clima() -> ServicioClimaMapa:
	if _servicio_clima == null:
		_servicio_clima = ServicioClimaMapa.new()
	var jugador_valido: Node2D = jugador if is_instance_valid(jugador) else null
	return _servicio_clima.enlazar(controlador_clima, jugador_valido, jugador_offset)


## Aplica el preset autoritativo del mapa sin arrastrar transiciones del mapa
## anterior. `null` se normaliza a NINGUNO dentro del controlador. `celda_entrada`
## (Vector2i local del mapa actual) es la celda con la que se resuelve el clima por
## zona de entrada mientras el jugador aún no está en ella; null = la del jugador.
## También regenera el estado volátil del mapa (hierba con ceniza...) cuando el
## mapa pasa a ser el actual desde otro mapa o al cargar la partida; eso no
## depende del controlador de clima.
func _aplicar_clima_mapa_actual_inmediato(celda_entrada: Variant = null) -> void:
	var servicio := _obtener_servicio_clima()
	if mapa_actual == null:
		servicio.limpiar()
		return
	var conservar_persistentes := ServicioClimaMapa.conserva_persistentes_al_entrar(
		_clave_mapa_clima_previo, _exterior_mapa_clima_previo, mapa_actual_key
	)
	# FlagClear(FLAG_SYS_USE_FLASH) al cargar un mapa exterior (sub_805308C de
	# pokeruby). Va antes del clima: una cueva oscura arranca con el radio de la
	# bandera, así que entre salas de la cueva (interiores) se conserva.
	if not mapa_actual.esInterior:
		EfectoOscuridadCueva.apagar_destello()
	# FlagClear(FLAG_SYS_USE_STRENGTH) al cambiar de mapa (ClearTempFieldEventData).
	if _clave_mapa_clima_previo != mapa_actual_key:
		ControladorRocaFuerza.desactivar_fuerza()
	servicio.aplicar_clima_entrada(mapa_actual, celda_entrada, conservar_persistentes)
	# Sin clave previa es la carga de la partida: el estado volátil restaura el área
	# visible guardada (hierba con ceniza limpia).
	var desde_carga := _clave_mapa_clima_previo.is_empty()
	if _clave_mapa_clima_previo != mapa_actual_key:
		_regenerar_estado_volatil_mapa_actual(desde_carga)
	_clave_mapa_clima_previo = mapa_actual_key
	_exterior_mapa_clima_previo = mapa_actual.mapa_exterior_asociado if mapa_actual.esInterior else ""


## Reaplica el clima del mapa actual evaluando el selector de entrada en `celda`
## (celda guardada al cargar la partida). Solo hace algo si el mapa tiene
## SelectorClimaEntrada (si no, el clima ya aplicado no depende de la celda).
func _reaplicar_clima_entrada_en_celda(celda: Vector2i) -> void:
	if mapa_actual == null or mapa_actual.obtener_selector_clima_entrada() == null:
		return
	_aplicar_clima_mapa_actual_inmediato(celda)


## Estado del mapa que solo vive mientras el jugador sigue en él (hierba con
## ceniza limpiada...). Se restaura al llegar desde otro mapa, al volver de un
## interior o al cargar la partida; no al reaplicar el mismo mapa (batalla).
## `desde_carga` solo es true al cargar la partida.
func _regenerar_estado_volatil_mapa_actual(desde_carga: bool = false) -> void:
	for nodo: Node in _nodos_grupo_mapa_actual(&"estado_mapa_volatil"):
		if nodo.has_method("regenerar_estado_volatil"):
			nodo.call("regenerar_estado_volatil", desde_carga)


## Llamado por SistemaGuardado al guardar (SaveEventObjects de Gen 3): estado
## de cada NPC del mapa actual, indexado por su ruta relativa al mapa.
func capturar_estado_objetos_mapa_actual() -> Dictionary:
	var objetos := {}
	for nodo: Node in _nodos_grupo_mapa_actual(&"NPC"):
		if nodo.has_method("exportar_estado_guardado"):
			objetos[String(mapa_actual.get_path_to(nodo))] = nodo.call("exportar_estado_guardado")
	return objetos


## Al continuar la partida (LoadEventObjects de Gen 3): el jugador recupera su
## dirección y bici/surf, y los NPCs del mapa guardado su celda y dirección.
func _restaurar_estado_guardado_mapa() -> void:
	var posicion: Dictionary = SistemaGuardado.get_posicion_guardada()
	if jugador != null and jugador.has_method("restaurar_estado_guardado"):
		var dir_guardada: Variant = posicion.get("direccion", [])
		var dir := Vector2.DOWN
		if dir_guardada is Array and dir_guardada.size() == 2:
			dir = Vector2(float(dir_guardada[0]), float(dir_guardada[1]))
		jugador.call("restaurar_estado_guardado", dir,
			bool(posicion.get("en_bicicleta", false)), bool(posicion.get("en_surf", false)),
			str(posicion.get("tipo_bici", "CARRERA")))
		if _jugador_surfeando():
			restaurar_musica_mapa_actual()

	var estado: Dictionary = SistemaGuardado.datos_vivos.estado_mapa
	if str(estado.get("mapa", "")) != mapa_actual_key:
		return
	var objetos: Variant = estado.get("objetos", {})
	if not (objetos is Dictionary):
		return
	for ruta: String in objetos:
		var nodo := mapa_actual.get_node_or_null(NodePath(ruta))
		if nodo != null and nodo.has_method("restaurar_estado_guardado") and objetos[ruta] is Dictionary:
			nodo.call("restaurar_estado_guardado", objetos[ruta])


## Llamado por SistemaGuardado al guardar: cada nodo de estado volátil del mapa
## actual guarda la parte visible alrededor de `celda_jugador` (SaveMapView).
func guardar_estado_visible_mapa_actual(celda_jugador: Vector2i) -> void:
	for nodo: Node in _nodos_grupo_mapa_actual(&"estado_mapa_volatil"):
		if nodo.has_method("guardar_estado_visible"):
			nodo.call("guardar_estado_visible", celda_jugador)


## Tras el teletransporte de un warp: los climas persistentes reiniciados deciden
## si arrancan activos según la celda de llegada del jugador. Los cruces de borde
## no pasan por aquí.
func _evaluar_llegada_climas_persistentes() -> void:
	_obtener_servicio_clima().evaluar_llegada_persistentes(mapa_actual)


## Equivalente a MAP_SCRIPT_ON_TRANSITION de Gen 3: avisa a los nodos del mapa
## de destino, aún en negro, que se entró por un warp. Cargar partida no pasa
## por aquí, así que el estado que dependa de "volver a entrar" no avanza.
func _notificar_entrada_por_warp() -> void:
	for nodo: Node in _nodos_grupo_mapa_actual(GRUPO_ENTRADA_POR_WARP):
		if nodo.has_method("al_entrar_por_warp"):
			nodo.call("al_entrar_por_warp")


## Nodos de `grupo` que pertenecen al mapa actual (los exteriores siguen todos
## instanciados en el Overworld).
func _nodos_grupo_mapa_actual(grupo: StringName) -> Array[Node]:
	var nodos: Array[Node] = []
	if mapa_actual == null or not mapa_actual.is_inside_tree():
		return nodos
	for nodo: Node in mapa_actual.get_tree().get_nodes_in_group(grupo):
		if mapa_actual.is_ancestor_of(nodo):
			nodos.append(nodo)
	return nodos


## Fachada para eventos narrativos, DisparadorClimaPorTiles y los climas
## persistentes. Si el evento declara mapa de origen, solo se acepta mientras ese
## mapa sea el actual.
func cambiar_clima_overworld(
	definicion: DefinicionClima,
	duracion: float = 1.0,
	mapa_origen: MapaConfiguracion = null,
	intensidad: float = -1.0
) -> bool:
	return _obtener_servicio_clima().cambiar_clima(mapa_actual, definicion, duracion, mapa_origen, intensidad)


## Vuelve al clima declarado por el mapa actual. Es una transición porque se usa
## principalmente al salir de zonas/eventos temporales.
## Si el mapa tiene SelectorClimaEntrada, el "clima del mapa" es el de la zona
## que contiene la celda actual del jugador.
func restaurar_clima_mapa(duracion: float = 1.0) -> bool:
	return _obtener_servicio_clima().restaurar_clima(mapa_actual, duracion)

## ===== CARTEL DE NOMBRE DE LUGAR =====

## Todo el cartel trabaja con claves de lugar (`MapaConfiguracion.seccion`); el
## texto se resuelve solo al mostrarlo (`Lugares.nombre_lugar`).

## Sección PROPIA del mapa actual para el cartel, "" si no está definida: un
## interior sin sección propia no se anuncia (aunque herede la del exterior
## para guardar y encuentros).
func _nombre_lugar_actual_resuelto() -> String:
	if mapa_actual == null:
		return ""
	return mapa_actual.seccion.strip_edges()

## Clave de lugar donde está el jugador (posición guardada, encuentros): la
## sección efectiva del mapa actual (un interior sin sección propia toma la de
## su `mapa_exterior_asociado`). "" si no hay ninguna.
func obtener_seccion_lugar_actual() -> String:
	if mapa_actual == null:
		return ""
	var propia := mapa_actual.seccion.strip_edges()
	if not propia.is_empty():
		return propia
	if mapa_actual.esInterior and not mapa_actual.mapa_exterior_asociado.is_empty():
		var exterior := _buscar_mapa_en_overworld(mapa_actual.mapa_exterior_asociado)
		if exterior != null:
			return exterior.obtener_seccion_efectiva()
	return mapa_actual.obtener_seccion_efectiva()

## Tamaño en celdas (16 px) del mapa del Overworld `mapa_key`; Vector2i.ZERO si
## no está cargado o no tiene rectángulo útil. Lo usa el mapa de región para
## situar al jugador dentro de su sección (InitializeCursorPosition).
func obtener_tamano_celdas_mapa(mapa_key: String) -> Vector2i:
	var mapa := _buscar_mapa_en_overworld(mapa_key)
	if mapa == null or mapa.mapa_rect_px == Rect2():
		return Vector2i.ZERO
	return Vector2i(mapa.mapa_rect_px.size / Singleton.TILE_SIZE)

## Texto legible del lugar donde está el jugador (pantalla de guardado).
## "" si no hay lugar resoluble.
func obtener_nombre_lugar_actual() -> String:
	if mapa_actual is InteriorBaseSecreta:
		return mapa_actual.obtener_nombre_lugar()
	return Lugares.nombre_lugar(obtener_seccion_lugar_actual())

## Muestra el cartel si `nombre` (clave de lugar) difiere del último lugar
## anunciado (o del lugar de origen `previo` cuando se indica).
func _mostrar_cartel_si_cambia(nombre: String, previo: String = "") -> void:
	# actualizar_escenario también prepara el exterior en la fase 30 del warp.
	# No animar detrás del telón: _anunciar_lugar_tras_warp lo anunciará una
	# única vez al llegar. La revelación de cueva espera con coneccion == 0.
	if coneccion != 0 or _warp_cueva != 0:
		return
	if nombre.is_empty():
		return
	var referencia := previo if not previo.is_empty() else _nombre_lugar_anunciado
	if nombre == referencia:
		return
	_anunciar_lugar(nombre)

## Cartel de un mapa del Overworld que se atraviesa sin pasar a él (la barca del
## SR. ARENQUE cruza las RUTAS 105 y 106 con el jugador oculto): se anuncia si su
## nombre difiere del último anunciado. No cambia el mapa actual ni la música.
func anunciar_lugar_de_mapa(mapa: MapaConfiguracion) -> void:
	if mapa != null:
		_mostrar_cartel_si_cambia(mapa.seccion.strip_edges())

## Cartel al terminar un warp:
## - de interior a exterior: siempre, aunque el nombre no cambie;
## - de interior a interior: si el nombre cambia, o si el destino tiene
##   `mostrar_nombre_al_entrar` aunque el nombre sea el mismo;
## - de exterior a un mapa con `mostrar_nombre_al_entrar` (cuevas, ruinas): solo
##   si su nombre difiere del mapa de origen.
func _anunciar_lugar_tras_warp() -> void:
	if mapa_actual == null:
		return
	var nombre := _nombre_lugar_actual_resuelto()
	var cambia_nombre := nombre != _warp_nombre_origen
	if _warp_origen_interior and not mapa_actual.esInterior:
		_anunciar_lugar(nombre)
	elif _warp_origen_interior:
		if cambia_nombre or mapa_actual.mostrar_nombre_al_entrar:
			_anunciar_lugar(nombre)
	elif mapa_actual.mostrar_nombre_al_entrar and cambia_nombre:
		_anunciar_lugar(nombre)

## Muestra el cartel sin comparaciones previas (forzado). `nombre` es la clave
## de lugar; el cartel recibe su texto traducido.
func _anunciar_lugar(nombre: String) -> void:
	if nombre.is_empty():
		return
	_nombre_lugar_anunciado = nombre
	if SistemaGuardado.get_flag(BANDERA_OCULTAR_CARTEL_LUGAR):
		return
	if _cartel_lugar != null:
		var texto: String = mapa_actual.obtener_nombre_lugar() if mapa_actual is InteriorBaseSecreta \
			and nombre == mapa_actual.seccion else Lugares.nombre_lugar(nombre)
		_cartel_lugar.mostrar(texto)

## Lógica de interacción del jugador con el mapa.[br]
## Esta función se llama cuando el jugador intenta interactuar con el entorno, como leer carteles o activar eventos.
func accionar_evento() -> void:
	# Con un warp en curso (fundido a negro) el jugador ya no actúa: un guion que
	# suelta el control justo antes de teletransportar (devolución de las PIEZAS DEVON)
	# arrancaba otra vez con el NPC que quedaba delante y se colgaba al cambiar de mapa.
	if coneccion != 0 or not puede_actuar_jugador():
		return
	# Buscar nodos "Cartel"
	var carteles: Array = []
	# CartelesPuertas: puertas cerradas por un guion (Arrecípolis); cada una solo está en el grupo mientras lo está.
	for contenedor: String in ["Carteles", "CartelesPuertas"]:
		var nodo_carteles = mapa_actual.get_node_or_null(contenedor)
		if nodo_carteles:
			for nodo in nodo_carteles.get_children():
				if nodo.is_in_group("Cartel") and (not nodo.has_method("esta_activo") or nodo.esta_activo()):
					carteles.append(nodo)

	var cartel = null
	var tile_accion := celda_frente_jugador()
	for nodo in carteles:
		if tile_accion == nodo.coord_tile:
			# Filtro de capa: -1 = cualquier capa, >=0 = solo esa capa
			var nodo_capa: int = nodo.get("capa_datos") if "capa_datos" in nodo else -1
			if nodo_capa >= 0 and nodo_capa != Singleton.capa_activa:
				continue
			if nodo.direccion == Singleton.enum_dir_cartel.TODAS_DIRECCIONES:
				cartel = nodo
			elif nodo.direccion == Singleton.enum_dir_cartel.ABAJO and jugador.facing_direction == Vector2.UP:
				cartel = nodo
			else:
				continue
			break

	if cartel:

		# # Verificar si es el cartel especial del mapa de región
		# if cartel.id_texto == "CARTEL_MAPA_REGION_CENTRO_PKM" and cartel.has_method("abrir_mapa_region"):
		# 	# Mostrar el texto y luego abrir el mapa de región
		# 	var texto_cartel = tr(cartel.id_texto)
		# 	# Fallback si la traducción no está disponible
		# 	if texto_cartel == cartel.id_texto or texto_cartel.is_empty():
		# 		var nombre_jugador = "JUGADOR"  # Fallback por defecto
		# 		if SistemaGuardado and SistemaGuardado.has_method("get_nombre_jugador"):
		# 			var nombre = SistemaGuardado.get_nombre_jugador()
		# 			if nombre and not nombre.is_empty():
		# 				nombre_jugador = nombre
		# 		texto_cartel = nombre_jugador + " miró más de cerca el mapa de la región de HOENN."
		# 	cuadro_dialogo.mostrar(texto_cartel, true, true, cartel.abrir_mapa_region)
		# elif cartel.id_texto == "ACCESO_PC":
		# 	# Cartel especial para acceso a PC
		# 	cuadro_dialogo.mostrar(tr(cartel.id_texto), true, true, Callable(Singleton, "abrir_pc"))
		# else:
		# 	# Cartel normal
		# 	cuadro_dialogo.cartel(tr(cartel.id_texto))
		if cartel.has_method("accionar_cartel"):
			if cartel is EventoPCCasa:
				# El PC posee su sesión/pausa; no heredar un bloqueo local de cartel
				# que se capturaría como estado previo y quedaría pegado al cerrar.
				cartel.administrador = self
				cartel.accionar_cartel()
			else:
				Singleton.mantener_pausa(&"dialogo_cartel", true)
				dialogo_cartel_activo = true
				jugador.no_control = true
				cuadro_dialogo.nodo_raiz = self
				cuadro_dialogo.nodo_jugador = jugador
				jugador.animated_sprite.frame = 0  # Asegurar que el sprite quede en frame 0 (de pie)
				cartel.accionar_cartel()
		else:
			print("⚠️ [ADMIN] El cartel en celda %s no tiene método 'accionar_cartel'" % str(cartel.coord_tile))

		# Evitar reabrir el mismo cartel inmediatamente si la tecla sigue presionada
		debe_soltar_tecla_accion = true
		return

	# Buscar nodos "NPC"
	var npc = npc_para_interaccion(tile_accion, Vector2i(jugador.facing_direction))
	if npc and npc.has_method("evento_accion"):
		print("accionar npc")
		jugador.animated_sprite.frame = 0
		npc.evento_accion()
		debe_soltar_tecla_accion = true
		return

	# TrySetupDiveDownScript: después de carteles y NPC (TryStartInteractionScript).
	if jugador.has_method("intentar_bucear") and jugador.call("intentar_bucear"):
		debe_soltar_tecla_accion = true
		return

	# Si no se encontró cartel ni NPC, enviar señal para buscar eventos adicionales
	print("🔍 No hay cartel ni NPC - enviando señal buscar_evento_accion para celda: ", tile_accion)
	Singleton.buscar_evento_accion.emit(tile_accion, mapa_actual)
	debe_soltar_tecla_accion = true

## Celda (coordenadas del mapa actual) a la que mira el jugador: la que se
## acciona con el botón A (GetObjectEventScriptPointerPlayerFacing de pokeruby).
func celda_frente_jugador() -> Vector2i:
	return Vector2i(((jugador.global_position - jugador_offset - mapa_actual.global_position) / Singleton.TILE_SIZE).floor()) + Vector2i(jugador.facing_direction)

## Ruby GetInteractedObjectEventScript: un mostrador extiende el alcance una celda.
## Usa next_to_npc (no ocupante_bloqueante): los objetos ocultos se encuentran
## mirándolos aunque no bloqueen el paso. No encadenar mesas.
func npc_para_interaccion(celda_frente: Vector2i, direccion: Vector2i) -> Node2D:
	var npc := next_to_npc(celda_frente)
	if npc != null:
		return npc
	if direccion not in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		return null
	var datos := _obtener_tp_para_nodo(jugador)
	if datos != null and datos.has_flag(celda_frente, TPTileDataMap.Flags.MOSTRADOR):
		return next_to_npc(celda_frente + direccion)
	return null

## Buscar NPC en la coordenada indicada.
## Se usa para 'accionar' (también encuentra los objetos ocultos) y para las rocas
## de FUERZA; las colisiones usan ocupante_bloqueante.
func next_to_npc(se_busca: Vector2i) -> Node2D:
	return _nodo_en_celda(se_busca, false)

## Como next_to_npc, pero ignora los nodos que no impiden el paso (los que exponen
## bloquea_paso() y devuelven false: objetos ocultos, bg_hidden_item_event en
## pokeruby). Es lo que consultan el jugador y el resto de colisiones.
func ocupante_bloqueante(celda: Vector2i) -> Node2D:
	return _nodo_en_celda(celda, true)

## Un nodo no bloqueante cede ante cualquier objeto que comparta su celda (en
## pokeruby los objetos tienen prioridad sobre los eventos de fondo): una roca
## empujada sobre un objeto oculto sigue siendo la que se encuentra.
func _nodo_en_celda(se_busca: Vector2i, solo_bloqueantes: bool) -> Node2D:
	var nodo_npcs = mapa_actual.get_node_or_null("NPCs") # Este nodo no es 'Node' sino 'Node2D'
	var no_bloqueante: Node2D = null
	if nodo_npcs:
		for npc in nodo_npcs.get_children():
			if not npc.visible:
				continue
			# Filtro de capa: -1 = cualquier capa, >=0 = solo esa capa
			var npc_capa: int = npc.get("capa_datos") if "capa_datos" in npc else -1
			if npc_capa >= 0 and npc_capa != Singleton.capa_activa:
				continue
			if "coord_celda" in npc:
				if npc.coord_celda == se_busca:
					if npc.has_method("bloquea_paso") and not npc.bloquea_paso():
						if no_bloqueante == null:
							no_bloqueante = npc
						continue
					return npc
			# elif "coord" in npc and npc.coord == se_busca: # Esta es la posición inicial, omitir por ahora
			# 	return npc
	return null if solo_bloqueantes else no_bloqueante

## Actualiza las opciones disponibles del menú de pausa según el estado del juego
func actualizar_opciones_menu():

	# Verificar si el jugador tiene Pokémon en su equipo
	if has_node("/root/SistemaGuardado"):
		var sistema_guardado = get_node("/root/SistemaGuardado")
		var equipo = sistema_guardado.get_equipo()

		# Activar opción de Pokémon si el jugador tiene al menos uno
		var tiene_pokemon = not equipo.is_empty()
		Singleton.establecer_opcion_menu_visible("pokemon", tiene_pokemon)

		print("🎮 [ADMIN] Actualizando opciones de menú - Pokémon visible: %s" % tiene_pokemon)

	# Actualizar el nombre del jugador en el menú
	Singleton.actualizar_nombre_jugador_menu()

	# FLAG_SYS_POKEDEX_GET. Siempre explícito: la visibilidad vive en el
	# Singleton y sobreviviría a una partida nueva en la misma sesión.
	Singleton.establecer_opcion_menu_visible("pokedex", PokedexPartida.obtenida())

	Singleton.establecer_opcion_menu_visible("pokenav", SistemaGuardado.get_flag(Singleton.BANDERA_POKENAV))

	# En la ZONA SAFARI el menú cambia GUARDAR por RETIRARSE (SafariZoneRetirePrompt).
	Singleton.establecer_nombre_opcion_menu("guardar", "RETIRARSE" if SesionSafari.activa() else "GUARDAR")

func _logear(tag: String) -> void:
	print("⚙️ [ADMIN MAPAS] → %s" % tag)

## Llamado por character.gd en cada paso completado del jugador (cualquier
## terreno), antes de intentar el encuentro salvaje. Descuenta un paso del
## repelente (UpdateRepelCounter de pokeruby). Devuelve true si el efecto se
## acaba justo en este paso: se muestra el aviso y ese paso no tiene encuentro.
## SELECT en el campo: usa el objeto registrado en la mochila (pokeruby
## item_menu.c UseRegisteredKeyItem). Sin objeto registrado, o si ya no está
## en la mochila, explica cómo asignarlo. Si el objeto no se puede usar aquí
## sale el Consejo de PAPÁ, como al usarlo desde la mochila.
func usar_objeto_registrado() -> void:
	var item: Dictionary = UsoObjetosCampo.datos_objeto_registrado()
	if item.is_empty():
		mostrar_dialogo("MOCHILA_SIN_REGISTRADO")
		return
	match str(item.get("uso_campo", "")):
		"BICI":
			var en_bici_antes: bool = jugador.en_bicicleta
			# DisplayCantGetOffBikeItemMessage: texto propio en el CAMINO de BICIS.
			var texto_no_bajar: String = jugador.texto_no_puede_bajar_de_bici()
			jugador.toggle_bicicleta(str(item.get("nombre_interno", "")))
			if jugador.en_bicicleta == en_bici_antes:
				mostrar_dialogo(texto_no_bajar if texto_no_bajar != "" else "MOCHILA_CONSEJO_PAPA")
			return
		"CANA":
			jugador._intentar_pescar(str(item.get("nombre_interno", "")))
			if not jugador.en_pesca:
				mostrar_dialogo("MOCHILA_CONSEJO_PAPA")
			return
	var parcela: ControladorBaya = ControladorBaya.parcela_frente_jugador()
	match UsoObjetosCampo.usar(item, parcela):
		UsoObjetosCampo.Resultado.PARCELA_REGADA:
			parcela.mostrar_riego_desde_mochila()
		UsoObjetosCampo.Resultado.CONSEJO_PAPA:
			mostrar_dialogo("MOCHILA_CONSEJO_PAPA")
		UsoObjetosCampo.Resultado.MONEDERO:
			mostrar_dialogo(MonederoFichas.texto_uso())
		UsoObjetosCampo.Resultado.BUSCAOBJETOS:
			usar_buscaobjetos()
		_:
			mostrar_dialogo("MOCHILA_USO_PENDIENTE")

## ItemUseOnFieldCB_Itemfinder: busca los objetos ocultos sin recoger del mapa
## actual y de los visibles (las conexiones) al alcance, suena SE_ITEMFINDER 4
## veces y gira al jugador hacia el más cercano; si está bajo los pies da 4
## giros en el sitio. Sin ninguno, "Mmm... ¡Nada!". Desde SELECT o la mochila.
func usar_buscaobjetos() -> void:
	if jugador == null or mapa_actual == null:
		return
	var distancia: Variant = BuscaObjetos.objetivo(_distancias_objetos_ocultos())
	if distancia == null:
		mostrar_dialogo(BuscaObjetos.CLAVE_NADA)
		return
	Singleton.mantener_pausa(MOTIVO_PAUSA_BUSCAOBJETOS, true)
	for i in range(BuscaObjetos.PITIDOS):
		Singleton.emit_signal("play_sound", "SE_ITEMFINDER")
		await _esperar_frames(BuscaObjetos.FRAMES_ENTRE_PITIDOS)
	var direccion: Vector2i = BuscaObjetos.direccion(distancia as Vector2i)
	var clave: String = BuscaObjetos.CLAVE_REACCIONA
	if direccion != Vector2i.ZERO:
		jugador.girar_en_el_sitio(Vector2(direccion))
		await _esperar_frames(FRAMES_GIRO_BUSCAOBJETOS)
	else:
		clave = BuscaObjetos.CLAVE_DEBAJO
		for giro: Vector2i in BuscaObjetos.giros_debajo(Vector2i(jugador.facing_direction)):
			jugador.girar_en_el_sitio(Vector2(giro))
			await _esperar_frames(FRAMES_GIRO_BUSCAOBJETOS)
	# El diálogo toma su propia pausa antes de soltar la nuestra.
	mostrar_dialogo(clave)
	Singleton.mantener_pausa(MOTIVO_PAUSA_BUSCAOBJETOS, false)

## Distancias (objeto - jugador, en celdas) a los objetos ocultos sin recoger de
## los mapas cargados: ItemOverworld con `oculto` y visible (si ya se recogió o
## su bandera lo esconde, no está visible).
func _distancias_objetos_ocultos() -> Array[Vector2i]:
	var celda_jugador := Vector2i(((jugador.global_position - jugador_offset) / Singleton.TILE_SIZE).floor())
	var mapas: Array[MapaConfiguracion] = [mapa_actual]
	for mapa: MapaConfiguracion in mapas_activos:
		if mapa != null and not mapas.has(mapa):
			mapas.append(mapa)
	var distancias: Array[Vector2i] = []
	for mapa: MapaConfiguracion in mapas:
		var npcs: Node = mapa.get_node_or_null("NPCs")
		if npcs == null:
			continue
		var origen := Vector2i((mapa.global_position / Singleton.TILE_SIZE).floor())
		for nodo: Node in npcs.get_children():
			if not (nodo is Node2D) or not (nodo as Node2D).visible \
					or not nodo.has_method("recoger_item") or not bool(nodo.get("oculto")):
				continue
			distancias.append(origen + (nodo.get("coord_celda") as Vector2i) - celda_jugador)
	return distancias

func _esperar_frames(frames: int) -> void:
	for i in range(frames):
		await get_tree().process_frame

## Gancho de pasos de las revanchas (IncrementRematchStepCounter): con 5 medallas
## o más, cada paso suma al contador (tope 255). Llamado por character.gd antes
## de la guardería; nunca corta el paso.
func procesar_paso_revancha() -> void:
	SistemaGuardado.get_revanchas().procesar_paso(SistemaGuardado.contar_medallas())

## Gancho de pasos de la amistad (UpdateHappinessStep): cada 128 pasos el equipo
## puede ganar amistad. Llamado por character.gd tras las revanchas, como en
## TryStartStepCountScript; nunca corta el paso.
func procesar_paso_amistad() -> void:
	Amistad.procesar_paso(SistemaGuardado.get_equipo())

## Gancho de pasos del veneno en el campo (TryStartStepCountScript →
## UpdatePoisonStepCounter). Llamado por character.gd tras la amistad y antes de
## la guardería. Cada 4 pasos los envenenados pierden 1 PS (sonido y mosaico, sin
## detener al jugador); en una base secreta no se cuenta. Devuelve true si algún
## Pokémon se debilita: ese paso termina aquí (guardería, repelente y encuentro
## no corren) y el jugador queda bloqueado durante los mensajes.
func procesar_paso_veneno() -> bool:
	var en_base_secreta: bool = mapa_actual is InteriorBaseSecreta
	var resultado := VenenoCampo.procesar_paso(SistemaGuardado.get_equipo(), en_base_secreta)
	if resultado.hay_efecto() and is_inside_tree():
		EfectoVenenoCampo.iniciar(self)
	if not resultado.se_debilita_alguno():
		return false
	veneno_debilita.emit(resultado.debilitados)
	_iniciar_desmayo_veneno(resultado.debilitados)
	return true

## Bloquea al jugador en el mismo paso y lanza la secuencia en diferido, como
## `_iniciar_eclosion`.
func _iniciar_desmayo_veneno(debilitados: Array[BasePokemon]) -> void:
	if is_instance_valid(jugador):
		jugador.no_control = true
	_secuencia_desmayo_veneno.call_deferred(debilitados)

## Script gUnknown_081A14B8 (event_scripts.s) con Task_WhiteOut (field_poison.c):
## por cada Pokémon debilitado, amistad, fin del veneno y "{mon} se debilitó...".
## Si todo el equipo ha caído, "no le quedan POKéMON" y vuelta al punto de curación;
## si no, se devuelve el control.
func _secuencia_desmayo_veneno(debilitados: Array[BasePokemon]) -> void:
	_bloquear_jugador_campo(MOTIVO_PAUSA_VENENO, true)
	for pokemon in debilitados:
		VenenoCampo.debilitar(pokemon)
		await _mostrar_mensaje_veneno(tr(TEXTO_VENENO_DEBILITADO).replace("{mon}", pokemon.get_nombre_mostrar()))
	var sin_pokemon: bool = VenenoCampo.todos_debilitados(SistemaGuardado.get_equipo())
	if sin_pokemon:
		await _mostrar_mensaje_veneno(tr(TEXTO_VENENO_SIN_POKEMON))
	if cuadro_dialogo != null:
		cuadro_dialogo.cerrar()
	if sin_pokemon:
		# El warp al punto de curación bloquea al jugador por su cuenta (motivo
		# "derrota"): se suelta el nuestro y se encadena sin esperar ningún fotograma.
		_bloquear_jugador_campo(MOTIVO_PAUSA_VENENO, false)
		if is_instance_valid(battle_manager) and battle_manager.has_method("recuperar_derrota_estandar"):
			battle_manager.recuperar_derrota_estandar()
		return
	_bloquear_jugador_campo(MOTIVO_PAUSA_VENENO, false)

## Un mensaje con espera de botón. El cuadro queda abierto (como en
## EventoGuionizado.mensaje): cerrarlo aquí antes del siguiente mensaje dejaría
## el cierre automático del anterior pendiente sobre el nuevo.
func _mostrar_mensaje_veneno(texto: String) -> void:
	if cuadro_dialogo == null:
		return
	cuadro_dialogo.mostrar(texto, true, false, _mensaje_veneno_terminado.emit)
	await _mensaje_veneno_terminado

## Sorteo de revanchas al activar el mapa actual (TryUpdateRandomTrainerRematches,
## llamado en pokeruby al cruzar un borde y al cargar un mapa por warp o partida).
## Los candidatos son los entrenadores vencidos del mapa que abren una entrada de
## la tabla; dos NPC de la misma pareja cuentan una sola vez.
func procesar_revanchas_mapa_actual() -> void:
	var candidatos: Array[int] = []
	for nodo: Node in _nodos_grupo_mapa_actual(&"NPC"):
		if not nodo.has_method("indice_revancha_candidato"):
			continue
		var indice: int = nodo.indice_revancha_candidato()
		if indice >= 0 and not candidatos.has(indice):
			candidatos.append(indice)
	if candidatos.is_empty():
		return
	SistemaGuardado.get_revanchas().sortear_mapa(candidatos, SistemaGuardado.contar_medallas(), _rng_revanchas)

## Gancho de pasos de la guardería (TryStartStepCountScript → ShouldEggHatch).
## Llamado por character.gd en cada paso, antes del repelente. Devuelve true si
## un huevo eclosiona: ese paso no procesa repelente ni encuentro salvaje.
func procesar_paso_guarderia() -> bool:
	var indice := SistemaGuardado.get_guarderia().procesar_paso(SistemaGuardado.get_equipo())
	if indice < 0:
		return false
	_iniciar_eclosion(indice)
	return true

## Gancho de pasos de la ZONA SAFARI (TryStartStepCountScript → SafariZoneTakeStep),
## justo después de la guardería y antes del repelente. Cuenta el paso solo con la
## partida SAFARI activa; devuelve true si era el último (500): ese paso termina
## aquí, sin repelente ni encuentro, y arranca el final de la partida.
func procesar_paso_safari() -> bool:
	return SesionSafari.procesar_paso(self)

## Final de la partida SAFARI: pasos agotados, BALLS agotadas (las llamará el combate
## SAFARI cuando exista, ver SesionSafari) o RETIRARSE del menú. Lanza el guion
## FinSafari, que avisa, cierra la sesión y lleva al jugador a la ENTRADA.
func finalizar_safari(motivo: int) -> void:
	var fin := FinSafari.new()
	add_child(fin)
	fin.finalizado.connect(fin.queue_free)
	fin.iniciar(self, motivo)

## Bloquea al jugador en el mismo paso y lanza la secuencia en diferido para
## no detener _finalizar_paso() de character.gd.
func _iniciar_eclosion(indice: int) -> void:
	huevo_eclosiona.emit(indice)
	# Bloqueo local inmediato (el siguiente paso no debe empezar); la pausa
	# global se pone ya en la secuencia diferida.
	if is_instance_valid(jugador):
		jugador.no_control = true
	_secuencia_eclosion.call_deferred(indice)

## S_EggHatch (data/scripts/day_care.inc): "¿Y esto?", fundido y EclosionHuevo
## como superposición en Menu (patrón de evento_pc_centro.gd).
func _secuencia_eclosion(indice: int) -> void:
	var equipo: Array = SistemaGuardado.get_equipo()
	var huevo: BasePokemon = equipo[indice] if indice >= 0 and indice < equipo.size() else null
	var capa: Node = Singleton.obtener_nodo("Menu") if is_inside_tree() else null
	if capa == null:
		capa = capa_interfaz
	if huevo == null or not huevo.huevo or capa == null:
		_bloquear_jugador_eclosion(false)
		return
	_bloquear_jugador_eclosion(true)
	if cuadro_dialogo != null:
		cuadro_dialogo.mostrar(TEXTO_ECLOSION_PREVIO, true, true, _eclosion_mensaje_terminado.emit)
		await _eclosion_mensaje_terminado
		cuadro_dialogo.cerrar()
	await Singleton.transicion("oscurecer")
	var eclosion := SCN_ECLOSION_HUEVO.instantiate() as EclosionHuevo
	capa.add_child(eclosion)
	eclosion.iniciar(huevo, SistemaGuardado.get_guarderia(), _seccion_actual())
	await Singleton.transicion("aclarar")
	if not eclosion.esta_terminada():
		await eclosion.terminado
	# Tras la pantalla de nombre ya está en negro: no se vuelve a mostrar la eclosión.
	if not eclosion.pantalla_en_negro:
		await Singleton.transicion("oscurecer")
	eclosion.queue_free()
	await Singleton.transicion("aclarar")
	_bloquear_jugador_eclosion(false)

func _bloquear_jugador_eclosion(activo: bool) -> void:
	_bloquear_jugador_campo(MOTIVO_PAUSA_ECLOSION, activo)

## Pausa global con `motivo` y control del jugador en escenas de campo
## (eclosión, desmayo por veneno).
func _bloquear_jugador_campo(motivo: StringName, activo: bool) -> void:
	Singleton.mantener_pausa(motivo, activo)
	if not is_instance_valid(jugador):
		return
	jugador.no_control = activo
	if activo:
		jugador.start_dialog()
	else:
		jugador.end_dialog()

## Al pasar a otro mapa, antes de sus scripts: DoTimeBasedEvents (programas de TV
## por días), el REPORTERO de los CONCURSOS (VAR_LINK_CONTEST_ROOM_STATE), la
## liquidación de la AZOTEA de CALAGUA y
## UpdateLocationHistoryForRoamer + RoamerMove al cruzar un borde o
## RoamerMoveToOtherLocationSet al llegar por un warp o cargar la partida.
func _al_cambiar_de_mapa(cruce_de_borde: bool) -> void:
	aplicar_entrada_huida_del_mapa(mapa_actual)
	ProgramacionTV.actualizar_por_dias()
	ProgramasTV.al_cambiar_de_mapa(mapa_actual_key)
	NoticiasPokemon.al_cambiar_de_mapa()
	PokemonErrante.al_entrar_en_mapa(mapa_actual_key, cruce_de_borde)

## Clave de Lugares de la sección del mapa actual (como
## BattleSceneController._resolver_lugar_encuentro).
func _seccion_actual() -> String:
	if mapa_actual != null:
		var seccion := mapa_actual.obtener_seccion_efectiva()
		if not seccion.is_empty():
			return seccion
	var guardado := Lugares.normalizar_clave(str(SistemaGuardado.datos_vivos.posicion.get("nombre_lugar", "")))
	return guardado if not guardado.is_empty() else Lugares.DESCONOCIDO

func procesar_paso_repelente() -> bool:
	if not UsoObjetosCampo.descontar_paso_repelente():
		return false
	mostrar_dialogo("REPELENTE_AGOTADO")
	return true

## Llamado por character.gd desde _finalizar_paso().[br]
## Intenta disparar un encuentro salvaje cuando el jugador termina un paso en hierba alta.
func intentar_encuentro_salvaje(tipo: String) -> void:
	if battle_manager == null or battle_manager.batalla_activa:
		return
	if jugador == null or jugador.no_control:
		return
	if mapa_actual == null or mapa_actual.probabilidad_encuentros <= 0.0:
		return

	# Tirada de probabilidad por paso
	#if randf() > mapa_actual.probabilidad_encuentros:
	# HEDOR / ILUMINACION del primer Pokémon del equipo (DoWildEncounterTest).
	var probabilidad := EfectosHabilidad.ajustar_probabilidad_encuentro(
		SistemaGuardado.get_equipo(),
		DatabaseManager.obtener_probabilidad_encuentro(mapa_actual_key, tipo),
		tipo == "pesca")
	# FL. BLANCA / FLAUTA NEGRA y AMULETO (ApplyFluteEncounterRateMod y
	# ApplyCleanseTagEncounterRateMod).
	if tipo != "pesca":
		probabilidad = UsoObjetosCampo.ajustar_probabilidad_por_flauta(probabilidad)
		probabilidad = UsoObjetosCampo.ajustar_probabilidad_por_amuleto(SistemaGuardado.get_equipo(), probabilidad)
	if randf() > probabilidad:
		return

	# TryStartRoamerEncounter: el errante, si vaga por este mapa, 1 de cada 4 veces;
	# si el REPELENTE lo bloquea no hay combate.
	if PokemonErrante.intentar_encuentro(mapa_actual_key):
		if not UsoObjetosCampo.repelente_bloquea(SistemaGuardado.get_contador(PokemonErrante.C_NIVEL)):
			await _combatir_errante()
		return
	# DoMassOutbreakEncounterTest + SetUpMassOutbreakEncounter (solo en tierra): el
	# Pokémon del brote anunciado en la tele; si el REPELENTE lo bloquea, la tabla.
	if tipo == "hierba":
		var brote := ProgramasTV.pokemon_de_brote(mapa_actual_key)
		if brote != null and not UsoObjetosCampo.repelente_bloquea(brote.nivel):
			await _combatir_pokemon_salvaje(brote)
			return

	# Seleccionar Pokémon de la tabla de encuentros
	var pokemon := DatabaseManager.seleccionar_pokemon_salvaje(mapa_actual_key, tipo)
	if pokemon.is_empty() or pokemon.get("nombre_interno", "") == "":
		return

	# Repelente activo: los salvajes de nivel inferior al primer Pokémon sano
	# del equipo no aparecen (IsWildLevelAllowedByRepel de pokeruby).
	if UsoObjetosCampo.repelente_bloquea(int(pokemon.nivel)):
		print("🌿 [ADMIN] Encuentro de %s Nv.%d repelido" % [pokemon.nombre_interno, pokemon.nivel])
		return

	# Encuentro decidido: iniciar batalla
	print("🌿 [ADMIN] ¡Encuentro salvaje! %s Nv.%d en %s" % [
		pokemon.nombre_interno, pokemon.nivel, mapa_actual_key])
	await _combatir_encuentro_salvaje(pokemon)

## DoesCurrentMapHaveFishingMons: el mapa actual tiene tabla de pesca.
func mapa_tiene_pesca() -> bool:
	return _mapa_tiene_encuentros("pesca")

## El mapa actual tiene tabla de encuentros de `tipo` en el JSON activo.
func _mapa_tiene_encuentros(tipo: String) -> bool:
	var tabla: Dictionary = DatabaseManager.obtener_tabla_encuentros_activa()
	var zona: Dictionary = tabla.get(mapa_actual_key.to_lower(), {})
	var datos: Dictionary = zona.get(tipo, {})
	return not (datos.get("encuentros", []) as Array).is_empty()

## ScrSpecial_RockSmashWildEncounter: tras romper una roca, tirada con la tasa
## "roca" del mapa y combate. Sin tabla (rockSmashMonsInfo NULL) no pasa nada, como
## en el TÚNEL FERVERGAL. DoWildEncounterTest(rate, ignoreAbility = TRUE): sin
## HEDOR / ILUMINACION, con bici ×0,8, flautas y AMULETO; GenerateWildMon comprueba
## el REPELENTE.
func intentar_encuentro_golpe_roca() -> void:
	if battle_manager == null or battle_manager.batalla_activa or mapa_actual == null:
		return
	if not _mapa_tiene_encuentros("roca"):
		return
	var probabilidad := DatabaseManager.obtener_probabilidad_encuentro(mapa_actual_key, "roca")
	if jugador != null and jugador.get("en_bicicleta") == true:
		probabilidad *= 0.8
	probabilidad = UsoObjetosCampo.ajustar_probabilidad_por_flauta(probabilidad)
	probabilidad = UsoObjetosCampo.ajustar_probabilidad_por_amuleto(SistemaGuardado.get_equipo(), probabilidad)
	if randf() > probabilidad:
		return
	var pokemon := DatabaseManager.seleccionar_pokemon_salvaje(mapa_actual_key, "roca")
	if pokemon.is_empty() or pokemon.get("nombre_interno", "") == "":
		return
	if UsoObjetosCampo.repelente_bloquea(int(pokemon.nivel)):
		return
	print("🪨 [ADMIN] ¡Encuentro al romper una roca! %s Nv.%d en %s" % [
		pokemon.nombre_interno, pokemon.nivel, mapa_actual_key])
	await _combatir_encuentro_salvaje(pokemon)

## FishingWildEncounter: combate con un Pokémon de la tabla de pesca de la
## caña `cana` ("vieja" | "buena" | "super"). Sin tirada de probabilidad ni
## repelente (pokeruby no los aplica al pescar).
func iniciar_encuentro_pesca(cana: String) -> void:
	if battle_manager == null or battle_manager.batalla_activa:
		return
	var pokemon := DatabaseManager.seleccionar_pokemon_salvaje(mapa_actual_key, "pesca", cana)
	if pokemon.is_empty() or pokemon.get("nombre_interno", "") == "":
		push_warning("[ADMIN] Sin Pokémon de pesca (%s) en %s" % [cana, mapa_actual_key])
		return
	print("🎣 [ADMIN] ¡Encuentro pescando! %s Nv.%d en %s" % [
		pokemon.nombre_interno, pokemon.nivel, mapa_actual_key])
	await _combatir_encuentro_salvaje(pokemon)

## Combate salvaje ya decidido ({nombre_interno, nivel}) y vuelta al mapa.
func _combatir_encuentro_salvaje(pokemon: Dictionary) -> void:
	var ejecucion: ResultadoEjecucionBatalla = await battle_manager.combatir_salvaje(
		pokemon.nombre_interno,
		pokemon.nivel,
		_lugar_encuentro_actual()
	)
	_tras_encuentro_salvaje(ejecucion)

## BattleSetup_StartRoamerBattle y, al acabar, UpdateRoamerHPStatus / SetRoamerInactive.
func _combatir_errante() -> void:
	var errante := PokemonErrante.crear_instancia()
	var ejecucion: ResultadoEjecucionBatalla = await battle_manager.combatir_pokemon_salvaje(
		errante, _lugar_encuentro_actual(), true)
	if ejecucion.fue_completada():
		PokemonErrante.tras_combate(errante, ejecucion.resultado)
	_tras_encuentro_salvaje(ejecucion)

## Combate salvaje contra un Pokémon ya construido (brote masivo).
func _combatir_pokemon_salvaje(pokemon: BasePokemon) -> void:
	var ejecucion: ResultadoEjecucionBatalla = await battle_manager.combatir_pokemon_salvaje(
		pokemon, _lugar_encuentro_actual())
	_tras_encuentro_salvaje(ejecucion)

## El lugar del encuentro es la clave de zona (sección), no la de escena.
func _lugar_encuentro_actual() -> String:
	var lugar_encuentro := obtener_seccion_lugar_actual()
	return lugar_encuentro if not lugar_encuentro.is_empty() else Lugares.normalizar_clave(mapa_actual_key)

## Vuelta al mapa tras un combate salvaje: política de derrota o fin de la SAFARI.
func _tras_encuentro_salvaje(ejecucion: ResultadoEjecucionBatalla) -> void:
	if ejecucion.fue_rechazada():
		push_warning("[ADMIN] Encuentro rechazado (%s): %s" % [ejecucion.codigo_error, ejecucion.mensaje_error])
		return
	# Victoria, huida y CAPTURA vuelven al mapa sin la política de derrota.
	if ResultadoBatalla.es_derrota_jugador(ejecucion.resultado):
		battle_manager.recuperar_derrota_estandar()
	else:
		call_deferred("_revalidar_efecto_terreno_jugador_post_batalla")
		# sub_80C824C: sin SAFARI BALLS la partida termina al volver al mapa.
		SesionSafari.procesar_fin_de_combate(self)
	print("🏁 [ADMIN] Encuentro salvaje terminado: %s" % ResultadoBatalla.Valor.keys()[ejecucion.resultado])

func _revalidar_efecto_terreno_jugador_post_batalla() -> void:
	if jugador and jugador.has_method("actualizar_efecto_terreno_actual"):
		jugador.actualizar_efecto_terreno_actual()
## Valida la celda bajo el jugador y NPCs recién instanciados y dispara
## animaciones (por ejemplo pasto_pisado) si la etiqueta del terreno lo requiere.
func _programar_validacion_spawns_en_mapa(incluir_jugador: bool = true) -> void:
	var mapa_objetivo := mapa_actual
	call_deferred("_validar_spawns_mapa_si_sigue_activo", mapa_objetivo, incluir_jugador)

func _validar_spawns_mapa_si_sigue_activo(mapa_objetivo: MapaConfiguracion, incluir_jugador: bool = true) -> void:
	if mapa_objetivo == null or mapa_actual != mapa_objetivo:
		return
	_validar_spawns_en_mapa(incluir_jugador)

## Valida la celda bajo el jugador y NPCs recién instanciados y dispara
## animaciones (por ejemplo pasto_pisado) si la etiqueta del terreno lo requiere.
func _validar_spawns_en_mapa(incluir_jugador: bool = true) -> void:
	# Validar al jugador
	if incluir_jugador and jugador != null:
		_spawn_pasto_si_corresponde(jugador)

	# Validar NPCs del mapa actual (hijos del nodo "NPCs" del MapaConfiguracion)
	if mapa_actual != null:
		var nodo_npcs = mapa_actual.get_node_or_null("NPCs")
		if nodo_npcs != null:
			for nodo in nodo_npcs.get_children():
				if nodo is Node2D and nodo != jugador:
					# Un objeto oculto no pisa la hierba: no es un objeto del mapa.
					if nodo.has_method("bloquea_paso") and not nodo.bloquea_paso():
						continue
					_spawn_pasto_si_corresponde(nodo)

func _ya_hay_animacion_pasto_en_celda(cell: Vector2i) -> bool:
	if mapa_actual == null:
		return false
	for nodo in get_tree().get_nodes_in_group("PastoAlto1"):
		if not (nodo is Node2D):
			continue
		var animacion := nodo as Node2D
		if not mapa_actual.is_ancestor_of(animacion):
			continue
		if mapa_actual.global_to_map_cell(animacion.global_position) == cell:
			return true
	return false

## Comprueba la celda bajo `node` y si la celda tiene 'Etiqueta Terreno' == 2,
## instancia la animación `Singleton.animacion_pisar_pasto` en la posición adecuada.
func _spawn_pasto_si_corresponde(node: Node2D) -> void:
	if node == null or mapa_actual == null:
		return
	var cell := mapa_actual.global_to_map_cell(node.global_position - jugador_offset)
	if node.has_method("actualizar_efecto_terreno_actual"):
		node.actualizar_efecto_terreno_actual()
	var tp := _obtener_tp_para_nodo(node)
	if tp != null:
		if tp.has_flag(Vector2(cell), TPTileDataMap.Flags.HIERBA_MAS_ALTA):
			if node.has_method("_reproducir_animacion_hierba_muy_alta"):
				node.call("_reproducir_animacion_hierba_muy_alta", cell)
			return
		if tp.has_flag(Vector2(cell), TPTileDataMap.Flags.HIERBA_ALTA):
			if _ya_hay_animacion_pasto_en_celda(cell):
				return
			var anim = Singleton.animacion_pisar_pasto.instantiate()
			anim.set_y_sort_enabled(true)
			var posicion_celda := Vector2(cell) * Singleton.TILE_SIZE
			var nodo_npcs_anim = mapa_actual.get_node_or_null("NPCs")
			if nodo_npcs_anim:
				anim.position = posicion_celda + Vector2(8.0, 15.0)
				nodo_npcs_anim.add_child(anim)
			else:
				anim.position = posicion_celda + mapa_actual.global_position + Vector2(8.0, 15.0)
				add_child(anim)
			print("🟢 [ADMIN] Pisar pasto spawn: animación creada en celda %s" % str(cell))

## Obtiene referencia al jugador
func get_jugador():
	return jugador

## Obtiene la clave del mapa actual
func get_mapa_actual_key() -> String:
	return mapa_actual_key

## Id del escenario de batalla (EscenarioBatalla) para un combate que empieza
## ahora: terreno bajo el jugador (BattleSetup_GetTerrain) y escena del mapa o
## clase del entrenador (DrawMainBattleBackground). "" si no hay mapa actual.
func obtener_escenario_batalla(clase_entrenador: String = "") -> String:
	var terreno := obtener_terreno_batalla()
	if terreno < 0:
		return ""
	return EscenarioBatalla.resolver_escenario(terreno as EscenarioBatalla.Terreno, mapa_actual.escena_batalla, clase_entrenador)

## gBattleTerrain (EscenarioBatalla.Terreno) para un combate que empieza ahora,
## según la celda del jugador y el mapa (BattleSetup_GetTerrain). -1
## (DatosInicioBatalla.TERRENO_NINGUNO) si no hay mapa actual.
func obtener_terreno_batalla() -> int:
	if mapa_actual == null:
		return DatosInicioBatalla.TERRENO_NINGUNO
	var flags := 0
	var surfea := false
	if jugador != null:
		surfea = jugador.get("en_surf") == true
		var cell := Vector2(((jugador.global_position - jugador_offset - mapa_actual.global_position) / Singleton.TILE_SIZE).floor())
		var tp := _obtener_tp_para_nodo(jugador)
		if tp != null:
			flags = tp.get_flags(cell)
		# Surfeando bajo un puente: las PUENTE_* están en la capa de datos elevada.
		if surfea:
			var capa_puente := mapa_actual.get_capa_por_id(1)
			if capa_puente != null and capa_puente != tp:
				flags |= capa_puente.get_flags(cell) & TPTileDataMap.MASCARA_PUENTE
	var es_ruta_113 := mapa_actual.nombre_interno.to_lower() == NOMBRE_INTERNO_RUTA_113
	# GetSav1Weather() == WEATHER_SANDSTORM.
	var tormenta_arena := is_instance_valid(controlador_clima) \
			and controlador_clima.obtener_clima_objetivo_id() == &"TORMENTA_ARENA"
	return EscenarioBatalla.resolver_terreno(flags, surfea, mapa_actual.obtener_tipo_mapa_batalla(), es_ruta_113, tormenta_arena)


## Clima del overworld que pasa a la batalla (ABILITYEFFECT_ON_SWITCHIN con
## gLastUsedAbility 0xFF): solo lluvia, tormenta de arena y sequía, siempre
## como clima permanente.
func obtener_clima_batalla() -> int:
	if not is_instance_valid(controlador_clima):
		return Singleton.ClimaBatalla.NINGUNO
	return clima_batalla_de_overworld(controlador_clima.obtener_clima_objetivo_id())


static func clima_batalla_de_overworld(id_clima: StringName) -> int:
	match id_clima:
		&"LLUVIA", &"TORMENTA":
			return Singleton.ClimaBatalla.LLUVIA
		&"TORMENTA_ARENA":
			return Singleton.ClimaBatalla.TORMENTA_ARENA
		&"SOL_FUERTE":
			return Singleton.ClimaBatalla.SOLEADO
	return Singleton.ClimaBatalla.NINGUNO

## Muestra un diálogo al jugador
func mostrar_dialogo(mensaje: String):
	if cuadro_dialogo and cuadro_dialogo.has_method("cartel"):
		# Sistema de diálogo: él mismo libera el motivo al cerrarse (IDLE).
		# La pausa ya bloquea al jugador (no_control incluye esta_pausado());
		# no tocar jugador.no_control: la caja no siempre tiene referencia al
		# jugador y ese bloqueo local se quedaría puesto al cerrarse.
		Singleton.mantener_pausa(&"dialogo", true)
		cuadro_dialogo.cartel(tr(mensaje))
		print("💬 [ADMIN] Diálogo mostrado: %s" % mensaje)

# FUNCIÓN DE PRUEBA TEMPORAL
func test_sistema_curacion():
	"""Prueba completa del sistema de curación del Centro Pokémon"""
	print("\n🧪 === INICIANDO PRUEBA DEL SISTEMA DE CURACIÓN ===")

	# Mostrar equipo actual
	mostrar_estado_equipo("INICIAL")

	# Probar curación
	print("\n💊 Curando equipo completo...")
	SistemaGuardado.curar_equipo_completo()

	# Mostrar equipo después de curación
	mostrar_estado_equipo("DESPUÉS DE CURACIÓN")

	# Guardar partida para persistir cambios
	print("\n💾 Guardando partida...")
	SistemaGuardado.guardar_partida()

	print("\n✅ === PRUEBA COMPLETADA ===")

func mostrar_estado_equipo(momento: String):
	"""Muestra el estado detallado del equipo"""
	print("\n📋 === ESTADO DEL EQUIPO - %s ===" % momento)
	var equipo = SistemaGuardado.get_equipo()

	if equipo.is_empty():
		print("❌ Equipo vacío")
		return

	for i in range(equipo.size()):
		var pokemon = equipo[i]
		if pokemon is BasePokemon:
			print("🔹 %d. %s Nv.%d - PS: %d/%d - Estado: %d (%s)" % [
				i + 1,
				pokemon.nombre_interno,
				pokemon.nivel,
				pokemon.estad_ps_actual,
				pokemon.estad_ps,
				pokemon.estado,
				Singleton.problema_estado_a_string(pokemon.estado)
			])

			# Mostrar PP de movimientos
			for j in range(pokemon.movimientos.size()):
				var mov = pokemon.movimientos[j]
				if mov is Movimiento:
					print("   • %s: %d/%d PP" % [mov.nombre, mov.pp_act, mov.pp_tot])
