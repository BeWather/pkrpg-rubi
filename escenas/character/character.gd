#@tool
extends Node2D

## Emitida al empezar cada paso o salto hacia otra celda (no en giros en sitio
## ni pasos bloqueados), con la celda de salida y la de llegada. La escuchan
## los NPC que siguen al jugador (npc_base.seguir_a).
signal paso_iniciado(origen: Vector2i, destino: Vector2i)

const SPEED = 60 # 56
## Suma de z_index mientras se está sobre (o entrando en) una celda PUNTO_ELEVADO.
## No se acumula: pasar de un punto elevado a otro lo mantiene.
const OFFSET_ELEVACION: int = 10
const RUNNING_SPEED = 120  # Velocidad al correr (doble)
## Velocidad de la bici acrobática rodando (sin wheelie): RideWaterCurrent del
## decomp, 6 fotogramas por casilla → 16 px × 60 fps / 6 = 160 px/s.
const CYCLING_SPEED = 160
const NpcBase := preload("res://scripts/npc/npc_base.gd")
const BICI_CARRERA := "CARRERA"
const BICI_ACROBATICA := "ACROBATICA"
## Bici de carrera (gMachBikeSpeeds / PlayerGoSpeed1,2,4): cada paso seguido sube
## el contador (0 a 2) y con él la velocidad: 1x, 2x y 4x la de andar.
const VELOCIDADES_BICI_CARRERA := [SPEED, SPEED * 2, SPEED * 4]
const CONTADOR_BICI_MAX := 2
const WHEELIE_HOP_ACTIVATION_DELAY := 1.0
const WHEELIE_HOP_DURATION := 0.18
const WHEELIE_HOP_HEIGHT := 6.0
const ESPECIAL_SIMULTANEIDAD_FRAMES := 4  # Ventana de frames para detectar btn_cancelar+dirécción simultáneos
const HIERBA_MUY_ALTA_FRAMES = preload("res://escenas/mapas/animaciones/hierba_muy_alta.tres")

# Máquina de estados del jugador
enum PlayerState { IDLE, WALKING, RUNNING, TURNING, JUMPING, TALKING, LOCKED, BLOCKED_STEP, FISHING }
var state: PlayerState = PlayerState.IDLE
var previous_state: PlayerState = PlayerState.IDLE

var is_running = false  # Estado de carrera
## runningState == MOVING a pie (CheckMovementInputNotOnBike): tras un paso, cambiar
## de dirección sin soltar la cruceta encadena el paso nuevo, sin el giro en sitio
## que sí aplica al arrancar desde parado. Se olvida al quedar sin dirección pulsada.
var _venia_en_movimiento: bool = false
var facing_direction = Vector2.DOWN  # Dirección a la que mira el personaje
var animated_sprite = null

# Variables para movimiento manual pixel a pixel (como npc_v3)
var paso_en_curso: bool = false
var origen_paso: Vector2
var destino_paso: Vector2
## Celda de llegada del paso o salto en curso (ver obtener_celda_destino()).
var _celda_destino: Vector2i
var progreso_paso: float = 0.0  # 0..1
var duracion_paso: float
var alterna_animacion: int = 1

## Bloqueo LOCAL del jugador (paso bloqueado, empujón, guion, bicicleta...).
## No leer directamente: usar `no_control`.
var _no_control_local: bool = false
## El coordinador del warp es el único escritor; los timers legacy no lo liberan.
var bloqueo_transicion: bool = false

## ¿El jugador no debe controlarse ahora mismo?
## Es la unión del bloqueo local con la pausa de juego (menú, batalla, diálogo,
## transición...) que consulta el AdministradorMapa, de modo que los escritores
## siguen usando la misma API (asignar true/false) y el jugador queda bloqueado
## aunque la causa de la pausa sea externa al propio jugador.
## OJO: la pausa NO se puede leer con puede_actuar_jugador() (se llamaría a sí
## misma a través de esta propiedad).
var no_control: bool = false:
	get:
		return _no_control_local or bloqueo_transicion or _juego_pausado()
	set(value):
		_no_control_local = value

## ¿El juego está pausado ahora mismo? (menú, batalla, diálogo, transición...)
## Sin AdministradorMapa (escenas sueltas, tests) no hay pausa global.
func _juego_pausado() -> bool:
	if nodo_administrador == null:
		return false
	return nodo_administrador.esta_pausado()

var turn_sequence: int = 0  # Control para giros encadenados
var blocked_step_sequence: int = 0  # Control para pasos bloqueados
var blocked_step_timer: float = 0.0  # Timer para animación de paso bloqueado

# Control de diálogo / interacción
var in_dialog: bool = false

@onready var sombra = $sombra
@onready var salpicadura: AnimatedSprite2D = get_node_or_null("salpicadura")
@onready var bicicleta: AnimatedSprite2D = get_node_or_null("bicicleta")
@onready var pesca: AnimatedSprite2D = get_node_or_null("pesca")
@onready var otras: AnimatedSprite2D = get_node_or_null("otras")
@onready var poke_field: AnimatedSprite2D = get_node_or_null("poke_field")
## Montura de SURF que se queda en el agua cuando poke_field hace de ave (VUELO).
@onready var montura_mov_campo: AnimatedSprite2D = get_node_or_null("montura_mov_campo")
## Animaciones de movimientos de campo (mov_campo_inicio, volar_inicio, vuelo_final).
@onready var animador: AnimationPlayer = get_node_or_null("animador")
## CanvasLayer de mov_campo_inicio: deja la franja y el Pokémon por encima de la
## oscuridad de cueva (ControladorClimaOverworld) y por debajo de Menu/Telon.
@onready var capa_mov_campo: CanvasLayer = get_node_or_null("CapaMovCampo")
## Franja con rayas de fondo de mov_campo_inicio (move_field_particle.gdshader).
@onready var fondo_mov_campo: Sprite2D = get_node_or_null("CapaMovCampo/MoveFieldParticle")
## Sprite 64x64 del Pokémon que cruza la pantalla en mov_campo_inicio.
@onready var poke64: Sprite2D = get_node_or_null("CapaMovCampo/poke64")
## Arena a los pies y huellas sobre tiles de desierto. Se crea en _ready.
var _efectos_arena: EfectosArena = null
## Salpicadura (nodo `salpicadura` de la escena) y ondas sobre AGUA_SALPICA. Se crea en _ready.
var _efectos_agua: EfectosAgua = null
var _tierra_pies: TierraPies = null
var _tierra_pies_solicitada: bool = false
## Agua termal (AGUA_TERMAL): recorta el cuerpo con el shader de `basico`. Se crea en _ready.
var _sumersion_termal: SumersionTermal = null

# Estado de pesca
var en_pesca: bool = false  ## Flag público para que administrador_mapa pueda consultar
var _pesca_cana: int = ReglasPesca.CANA_VIEJA  ## Índice de caña (ReglasPesca) de la pesca en curso.
var _pesca_a_pulsado: bool = false  ## A pulsado durante el minijuego (lo consume _pesca_esperar).
signal _pesca_mensaje_terminado
var _pesca_estado_previo: PlayerState = PlayerState.IDLE
var _pesca_en_bici_previo: bool = false
var _pesca_en_wheelie_previo: bool = false

# Estado previo al surf
var _surf_en_bici_previo: bool = false
var _surf_en_wheelie_previo: bool = false

# Efecto sinusoidal de surf
enum _SurfBobMode { SUAVE }  # Reservado para futuros efectos por mapa
const _SURF_BOB_MODE := _SurfBobMode.SUAVE
const _SURF_BOB_AMPLITUD_ABAJO := 1.0   # px hacia abajo
const _SURF_BOB_AMPLITUD_ARRIBA := 3.0  # px hacia arriba
# field_effect_helpers.c: la dirección del balanceo se invierte cada 16 frames,
# así que un ciclo dura 32 frames (60 / 32 ≈ 1.875 Hz).
const _SURF_BOB_FRECUENCIA := 1.875     # ciclos por segundo
var _surf_bob_tiempo: float = 0.0

var en_bicicleta: bool = false
## Tipo de bici montada (BICI_CARRERA / BICI_ACROBATICA); solo vale con en_bicicleta.
var tipo_bici: String = BICI_CARRERA
## bikeFrameCounter de la bici de carrera: 0 parado o recién arrancado, 2 a máxima velocidad.
var contador_bici: int = 0
## ¿El paso en curso va en bici de carrera a máxima velocidad (GetPlayerSpeed() == 4,
## contador_bici == CONTADOR_BICI_MAX al empezarlo)? Lo usa el suelo agrietado.
var _paso_bici_velocidad_maxima: bool = false
## Celda agrietada que se rompió con el paso en curso a máxima velocidad: al
## terminar ese paso sobre ella no se cae (el jugador ya la ha cruzado). null si no.
var _celda_salvada_por_velocidad: Variant = null
var en_wheelie: bool = false
var en_surf: bool = false
## Buceando en un mapa submarino (PLAYER_AVATAR_FLAG_UNDERWATER): sprite `bucear_*`
## de `otras`, sin Pokémon a la vista, sin bici ni correr. Excluye a en_surf.
var en_buceo: bool = false
var _movimiento_especial_bici_listo: bool = false
var _wheelie_hop_mode: bool = false
var _wheelie_idle_timer: float = 0.0
var _wheelie_hop_seq: int = 0
var _wheelie_trans_seq: int = 0
var _btn_cancelar_prev: bool = false
var _btn_cancelar_just_pressed: bool = false  # true solo el frame del borde de subida de btn_cancelar
var _btn_cancelar_just_released: bool = false  # true solo el frame del borde de bajada de btn_cancelar
var _dir_input_prev: Vector2 = Vector2.ZERO      # Dirección del frame anterior (detección just-pressed)
var _pending_especial_cancelar: int = 0          # Ventana de frames tras just-press de btn_cancelar
var _pending_especial_dir: Vector2 = Vector2.ZERO  # Dirección just-pressed en espera de btn_cancelar
var _pending_especial_dir_frames: int = 0        # Ventana de frames tras just-press de dirección
var animaciones_pisar_pasto = []
var material_hierba_muy_alta: ShaderMaterial = null
var hierba_muy_alta_activa := false

# Modo de transición de shader durante el paso actual
enum TransicionHierba { NINGUNA, ENTRADA_ARRIBA, ENTRADA_ABAJO, ENTRADA_IZQUIERDA, ENTRADA_DERECHA, ACTIVA, SALIDA_ARRIBA, SALIDA_ABAJO, SALIDA_IZQUIERDA, SALIDA_DERECHA }
var transicion_hierba_activa: TransicionHierba = TransicionHierba.NINGUNA

## Duración del salto de saliente en segundos (32 fotogramas, como los NPC). La
## altura sale de NpcBase.ALTURAS_SALTO (tabla del decomp).
var duracion_salto: float = NpcBase.DURACION_SALTO_BORDE

var nodo_administrador

var pos_raiz_px:Vector2
var pos_mapa_px:Vector2
var pos_celda_act:Vector2i
var pos_celda_sig:Vector2i
## Celda global (global_position / 16) en la que el jugador apareció por un
## teletransporte. Como en Rubí, los warps de escalera y puerta solo saltan al
## llegar con un paso: hasta que no termine un paso en otra celda, el warp de la
## celda de llegada no se dispara.
var _celda_llegada_warp: Vector2i
var _en_celda_llegada_warp: bool = false

## NPC al que sigue el jugador (escolta, ver seguir_a); null si no sigue a nadie.
var lider: Node2D = null

func _ready():
	if Engine.is_editor_hint():
		animated_sprite = get_node_or_null("basico")
		_aplicar_efecto_hierba_muy_alta(true)
		return

	add_to_group("Personaje")
	add_to_group("Reflectable")
	nodo_administrador = get_tree().root.get_node_or_null("AdministradorMapa")
	# Detectar si el script está ejecutándose en un AnimatedSprite2D (el script puede estar attached al sprite)
	if get_class() == "AnimatedSprite2D":
		animated_sprite = self
	else:
		animated_sprite = get_node_or_null("basico") # La opción más común
		if animated_sprite == null:
			animated_sprite = get_node_or_null("AnimatedSprite2D")
			if animated_sprite == null:
				animated_sprite = get_node_or_null("AnimatedSprite")

	if animated_sprite:
		material_hierba_muy_alta = animated_sprite.material as ShaderMaterial
	_sumersion_termal = SumersionTermal.new(material_hierba_muy_alta)

	if bicicleta:
		bicicleta.visible = false

	# Excluir poke_field del sistema de reflejos (otras puede reflejarse al hacer surf)
	if poke_field:
		poke_field.set_meta(&"sin_reflejo", true)
	if montura_mov_campo:
		montura_mov_campo.set_meta(&"sin_reflejo", true)

	# Dos ondas por paso separadas 0.5 s (los NPC hacen una).
	_efectos_agua = EfectosAgua.new(_obtener_tp_capa_actual, _obtener_mapa_actual, salpicadura, 2, 0.5)
	add_child(_efectos_agua)

	# Último hijo: la arena de los pies se dibuja sobre el sprite del jugador.
	_efectos_arena = EfectosArena.new()
	add_child(_efectos_arena)
	# La tierra de los pies (DisparadorTierraPies) va encima de la arena.
	_tierra_pies = TierraPies.new()
	add_child(_tierra_pies)

	_get_coord_tile_act()

	call_deferred("actualizar_efecto_terreno_actual")

func _exit_tree() -> void:
	_desactivar_efecto_hierba_muy_alta()
	if _sumersion_termal:
		_sumersion_termal.reiniciar()

# Procesamiento del movimiento pixel a pixel (reemplaza el sistema de Tween)
func _process(delta: float):
	# Actualizar estado derivado de bloqueos externos
	if no_control or in_dialog:
		if state != PlayerState.LOCKED and state != PlayerState.TALKING:
			_change_state(PlayerState.LOCKED)
	elif state == PlayerState.LOCKED:
		_change_state(PlayerState.IDLE)

	# Verificar si se soltó la tecla mientras está en BLOCKED_STEP
	if state == PlayerState.BLOCKED_STEP:
		var current_direction_pressed = _get_current_direction_input()
		if current_direction_pressed != facing_direction:
			# Se soltó la tecla de la dirección actual, volver a IDLE
			if animated_sprite:
				animated_sprite.frame = 0
			_change_state(PlayerState.IDLE)
			return

	if paso_en_curso:
		_procesar_movimiento(delta)
	elif state == PlayerState.BLOCKED_STEP:
		_procesar_paso_bloqueado(delta)
	elif _suelo_forzado_pendiente and not (no_control or in_dialog):
		# Un guion (entrenador, mensaje) interrumpio el deslizamiento: se reanuda.
		_procesar_suelo_forzado()
	_actualizar_movimiento_especial_bici_listo()

	if _es_bici_acrobatica() and not (no_control or in_dialog or esta_siguiendo()):

		# Detectar press/release de btn_cancelar y dirección para movimientos especiales y wheelie.
		# Los efectos (giro en U, salto lateral) solo se disparan cuando AMBOS se acaban de pulsar
		# dentro de una ventana de ESPECIAL_SIMULTANEIDAD_FRAMES frames.
		# Durante esa ventana no se procesa ninguna tecla individualmente.
		var btn_cancelar_presionado := Input.is_action_pressed(&"btn_cancelar")
		var dir_ahora := _get_current_direction_input()
		_btn_cancelar_just_pressed = btn_cancelar_presionado and not _btn_cancelar_prev
		_btn_cancelar_just_released = not btn_cancelar_presionado and _btn_cancelar_prev
		var _dir_just := dir_ahora != Vector2.ZERO and dir_ahora != _dir_input_prev

		# Decrementar ventanas de simultaneidad
		if _pending_especial_cancelar > 0:
			_pending_especial_cancelar -= 1
		if _pending_especial_dir_frames > 0:
			_pending_especial_dir_frames -= 1
		if _pending_especial_dir_frames == 0:
			_pending_especial_dir = Vector2.ZERO

		# Actualizar ventana de dirección recién pulsada (solo si es lateral u opuesta)
		if _dir_just and dir_ahora != Vector2.ZERO and dir_ahora != facing_direction:
			_pending_especial_dir = dir_ahora
			_pending_especial_dir_frames = ESPECIAL_SIMULTANEIDAD_FRAMES

		# Abrir ventana de btn_cancelar recién pulsado
		if _btn_cancelar_just_pressed:
			_pending_especial_cancelar = ESPECIAL_SIMULTANEIDAD_FRAMES

		# Detectar si alguna ventana está activa (estamos en periodo de espera)
		var en_ventana := _pending_especial_cancelar > 0 or _pending_especial_dir_frames > 0

		# Detectar disparo especial: ambos just-pressed dentro de la ventana
		var puede_especial := not paso_en_curso and state == PlayerState.IDLE
		var dir_especial := Vector2.ZERO
		if puede_especial:
			if btn_cancelar_presionado and dir_ahora != Vector2.ZERO and dir_ahora != facing_direction:
				# btn_cancelar + dirección activos al mismo tiempo
				dir_especial = dir_ahora
			elif btn_cancelar_presionado and _pending_especial_dir_frames > 0 \
					and _pending_especial_dir != Vector2.ZERO and _pending_especial_dir != facing_direction:
				# btn_cancelar recién llegó; dirección estaba en ventana
				dir_especial = _pending_especial_dir
			elif dir_ahora != Vector2.ZERO and dir_ahora != facing_direction and _pending_especial_cancelar > 0:
				# Dirección recién llegó; btn_cancelar estaba en ventana
				dir_especial = dir_ahora

		if dir_especial != Vector2.ZERO:
			# Movimiento especial: limpiar ventanas y disparar
			_pending_especial_cancelar = 0
			_pending_especial_dir = Vector2.ZERO
			_pending_especial_dir_frames = 0
			_movimiento_especial_bici_listo = false
			if dir_especial == -facing_direction:
				_realizar_giro_u(true)
			else:
				_realizar_salto_lateral(dir_especial, true)
		elif not en_ventana:
			# Fuera de ventana: procesar teclas individualmente
			# Sobre una PENDIENTE_ACROBATICA el wheelie no depende de B: se levanta al
			# quedar parado encima y no se deshace al soltarla (Bike_HandleBumpySlopeJump).
			var sobre_pendiente := _sobre_pendiente_acrobatica()
			if (btn_cancelar_presionado or (sobre_pendiente and not esta_en_movimiento())) and not en_wheelie:
				_iniciar_transicion_wheelie(true)
			elif not btn_cancelar_presionado and en_wheelie and not sobre_pendiente:
				_iniciar_transicion_wheelie(false)

		_btn_cancelar_prev = btn_cancelar_presionado
		_dir_input_prev = dir_ahora

	# else: en ventana activa → no se hace nada individual, se espera si llega el segundo botón
	else:
		_pending_especial_cancelar = 0
		_pending_especial_dir = Vector2.ZERO
		_pending_especial_dir_frames = 0

	_actualizar_salto_wheelie(delta)

	# Efecto sinusoidal de balanceo durante el surf
	if en_surf:
		if state != PlayerState.JUMPING:
			_surf_bob_tiempo += delta
			_aplicar_efecto_bob_surf()
	elif en_buceo:
		_surf_bob_tiempo += delta
		_aplicar_efecto_bob_buceo()
	elif montura_mov_campo and montura_mov_campo.visible:
		_surf_bob_tiempo += delta
		_aplicar_efecto_bob_montura()
	else:
		_surf_bob_tiempo = 0.0

func _unhandled_input(event: InputEvent) -> void:
	# Escoltado (seguir_a) el jugador no actúa por su cuenta: ni surf ni objetos.
	if no_control or in_dialog or esta_siguiendo():
		return
	if event.is_action_pressed(&"test_pescar"):
		_intentar_pescar()
		get_viewport().set_input_as_handled()
		return
	if en_pesca:
		# Task_Fishing bloquea el campo: solo A cuenta (JOY_NEW en Fishing5/8).
		if event.is_action_pressed(&"btn_accion"):
			_pesca_a_pulsado = true
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"btn_select"):
		# Objeto registrado con ASIGNAR en la mochila (bici, caña, regadera...).
		if not paso_en_curso and nodo_administrador:
			nodo_administrador.usar_objeto_registrado()
		get_viewport().set_input_as_handled()
	# TrySetupDiveEmergeScript: bajo el agua se emerge con B (pressedBButton).
	if event.is_action_pressed(&"btn_cancelar") and en_buceo and not paso_en_curso and state == PlayerState.IDLE:
		if _intentar_emerger():
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(&"btn_accion") and not en_surf and not en_buceo and not paso_en_curso and state == PlayerState.IDLE:
		_intentar_surf()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"btn_accion") and en_surf and not paso_en_curso and state == PlayerState.IDLE \
			and puede_usar_cascada():
		_intentar_cascada()
		get_viewport().set_input_as_handled()

## Obtiene el string de dirección basado en facing_direction
func _get_dir_string() -> String:
	if facing_direction == Vector2(0, -1):
		return "arriba"
	elif facing_direction == Vector2(1, 0):
		return "derecha"
	elif facing_direction == Vector2(-1, 0):
		return "izquierda"
	return "abajo"

## Devuelve true si el tile actual obliga a usar la bicicleta (BICI_DIR_HORIZONTAL o BICI_DIR_VERTICAL).
func _tile_actual_requiere_bici() -> bool:
	var tp := _obtener_tp_capa_actual()
	if tp == null:
		return false
	_get_coord_tile_act()
	var cell := Vector2(pos_celda_act)
	return tp.has_flag(cell, TPTileDataMap.Flags.BICI_DIR_HORIZONTAL) \
		or tp.has_flag(cell, TPTileDataMap.Flags.BICI_DIR_VERTICAL)

## Texto con el que se explica por qué no se puede bajar de la bici ("" si el motivo no es la
## bandera del CAMINO de BICIS ni un carril de bici: gOtherText_CantGetOffBike, el mismo
## texto para FLAG_SYS_CYCLING_ROAD y para los carriles de ItemUseOutOfBattle_Bike).
func texto_no_puede_bajar_de_bici() -> String:
	if en_bicicleta and not paso_en_curso and not en_surf \
			and (CaminoBici.activo() or _tile_actual_requiere_bici()):
		return "RUTA_110_BICI_NO_BAJAR"
	return ""

## true si toggle_bicicleta() cambiaría algo ahora (ItemUseOutOfBattle_Bike:
## Overworld_IsBikingAllowed y poder bajarse). La mochila lo consulta antes de cerrarse.
func puede_alternar_bicicleta() -> bool:
	if paso_en_curso:
		return false
	if en_surf or en_buceo:
		return false
	# El mapa prohíbe la bicicleta (solo_caminar a nivel de mapa)
	var mapa := _obtener_mapa_actual()
	if not en_bicicleta and mapa != null and mapa.solo_caminar:
		return false
	# No se puede bajar de la bici si el tile actual la requiere ni en el CAMINO de BICIS
	# (FLAG_SYS_CYCLING_ROAD: ItemUseOutOfBattle_Bike → DisplayCantGetOffBikeItemMessage)
	return not (en_bicicleta and (_tile_actual_requiere_bici() or CaminoBici.activo()))

## Activa/desactiva el modo bicicleta. Intercambia el sprite activo y oculta/muestra el basico.
func toggle_bicicleta(tipo: String = "") -> void:
	if not puede_alternar_bicicleta():
		return
	en_bicicleta = not en_bicicleta
	contador_bici = 0
	if en_bicicleta and tipo != "":
		tipo_bici = BICI_ACROBATICA if tipo == "BICIACROBAT" else BICI_CARRERA
	_cancelar_modo_salto_wheelie()
	en_wheelie = false
	_wheelie_trans_seq += 1
	if en_bicicleta:
		if animated_sprite:
			animated_sprite.stop()
			animated_sprite.frame = 0
			animated_sprite.visible = false
		if bicicleta:
			bicicleta.visible = true
			animated_sprite = bicicleta
	else:
		_mostrar_sprite_a_pie()
	_actualizar_animacion_idle()
	# Música: tema BICICLETA al subir, tema del lugar al bajar (el del mapa, o el
	# del desierto si la tormenta de arena está activa)
	if nodo_administrador != null and nodo_administrador.musica_player != null:
		if en_bicicleta:
			nodo_administrador.musica_player.reproducir_tema("BICICLETA", 2)
		else:
			var tema_lugar: String = nodo_administrador.obtener_musica_lugar_actual()
			if tema_lugar != "":
				nodo_administrador.musica_player.reproducir_tema(tema_lugar, 2)

## Inicia la transición de entrar/salir del modo wheelie mostrando wheelie_<dir>_0 brevemente.
func _iniciar_transicion_wheelie(entrando: bool) -> void:
	if not en_bicicleta or not bicicleta:
		return
	if entrando:
		_wheelie_idle_timer = 0.0
	else:
		_cancelar_modo_salto_wheelie()
	en_wheelie = entrando
	_wheelie_trans_seq += 1
	var seq := _wheelie_trans_seq
	var dir_str := _get_dir_string()
	var anim_trans := "wheelie_" + dir_str + "_0"
	if bicicleta.sprite_frames.has_animation(anim_trans):
		bicicleta.play(anim_trans)
		bicicleta.stop()
		bicicleta.frame = 0
	if not paso_en_curso:
		await get_tree().create_timer(0.1).timeout
		if seq == _wheelie_trans_seq and en_bicicleta:
			_actualizar_animacion_idle()

## Oculta la bici y vuelve al sprite a pie (`basico`).
func _mostrar_sprite_a_pie() -> void:
	if bicicleta:
		bicicleta.stop()
		bicicleta.frame = 0
		bicicleta.visible = false
	animated_sprite = get_node_or_null("basico")
	if animated_sprite == null:
		animated_sprite = get_node_or_null("AnimatedSprite2D")
	if animated_sprite:
		animated_sprite.visible = true

## Baja de la bici sin cambiar la música, porque la del destino la resuelve el warp:
## frente a la puerta de un interior y al llegar a un mapa donde no se permite
## (GetAdjustedInitialTransitionFlags → PLAYER_AVATAR_FLAG_ON_FOOT).
func bajar_de_bicicleta_sin_musica() -> void:
	if not en_bicicleta:
		return
	en_bicicleta = false
	contador_bici = 0
	_cancelar_modo_salto_wheelie()
	en_wheelie = false
	_wheelie_trans_seq += 1
	_mostrar_sprite_a_pie()
	_actualizar_animacion_idle()

func _actualizar_salto_wheelie(delta: float) -> void:
	if _wheelie_hop_mode:
		if not _puede_mantener_salto_wheelie():
			_cancelar_modo_salto_wheelie()
		return
	if _puede_activar_salto_wheelie():
		_wheelie_idle_timer += delta
		if _wheelie_idle_timer >= WHEELIE_HOP_ACTIVATION_DELAY:
			_wheelie_idle_timer = 0.0
			_wheelie_hop_mode = true
			_wheelie_hop_seq += 1
			_bucle_salto_wheelie(_wheelie_hop_seq)
	else:
		_wheelie_idle_timer = 0.0

## ¿Va en bici de carrera con el contador de velocidad al máximo (4 px/frame)?
func _bici_carrera_a_maxima_velocidad() -> bool:
	return en_bicicleta and tipo_bici == BICI_CARRERA and not en_wheelie \
		and contador_bici >= CONTADOR_BICI_MAX

## Wheelie, saltos y giros en U son solo de la bici acrobática; la de carrera no.
func _es_bici_acrobatica() -> bool:
	return en_bicicleta and tipo_bici == BICI_ACROBATICA

## ¿Hay una PENDIENTE_ACROBATICA (MB_BUMPY_SLOPE) en esa celda?
func _celda_es_pendiente_acrobatica(celda: Vector2i) -> bool:
	var tp := _obtener_tp_capa_actual()
	return tp != null and tp.has_flag(Vector2(celda), TPTileDataMap.Flags.PENDIENTE_ACROBATICA)

## Bici acrobática sobre una PENDIENTE_ACROBATICA, o a punto de aterrizar en una (la celda
## de llegada del salto en curso; si se mide solo la de salida, soltar B en pleno salto
## deshacería el wheelie justo antes de caer encima).
func _sobre_pendiente_acrobatica() -> bool:
	if not _es_bici_acrobatica():
		return false
	if not esta_en_movimiento():
		_get_coord_tile_act()
	return _celda_es_pendiente_acrobatica(obtener_celda_destino())

## Solo se entra en una PENDIENTE_ACROBATICA saltando con la bici acrobática (los saltitos
## del wheelie, _wheelie_hop_mode). A pie, corriendo, en la bici de carrera y rodando en la
## acrobática (con o sin wheelie) la celda es un obstáculo. En surf la bandera no aplica.
## Solo se consulta la celda destino: salir de una pendiente nunca está limitado por ella.
func _puede_entrar_en_pendiente() -> bool:
	return en_surf or (_es_bici_acrobatica() and en_wheelie and _wheelie_hop_mode)

## Sobre una pendiente el wheelie se mantiene sin B, pero los saltitos no: soltar B encima
## los cancela y no se reanudan hasta volver a pulsarla.
func _pendiente_sin_boton_cancelar() -> bool:
	return not Input.is_action_pressed(&"btn_cancelar") and _sobre_pendiente_acrobatica()

func _actualizar_movimiento_especial_bici_listo() -> void:
	if not _es_bici_acrobatica() or no_control or in_dialog or paso_en_curso or state != PlayerState.IDLE:
		_movimiento_especial_bici_listo = false
		return
	if _get_current_direction_input() == Vector2.ZERO:
		_movimiento_especial_bici_listo = true

func _debe_priorizar_movimiento_especial_bici() -> bool:
	return _puede_iniciar_movimiento_especial_bici(_get_current_direction_input())

func _puede_iniciar_movimiento_especial_bici(input_dir: Vector2) -> bool:
	return _es_bici_acrobatica() \
		and _btn_cancelar_just_pressed \
		and Input.is_action_pressed(&"btn_cancelar") \
		and not paso_en_curso \
		and state == PlayerState.IDLE \
		and _movimiento_especial_bici_listo \
		and input_dir != Vector2.ZERO \
		and input_dir != facing_direction

func _puede_activar_salto_wheelie() -> bool:
	return en_bicicleta \
		and en_wheelie \
		and not en_surf \
		and not no_control \
		and not in_dialog \
		and not paso_en_curso \
		and state == PlayerState.IDLE \
		and _get_current_direction_input() == Vector2.ZERO \
		and not _pendiente_sin_boton_cancelar()

func _puede_mantener_salto_wheelie() -> bool:
	return en_bicicleta and en_wheelie and not en_surf and not no_control and not in_dialog \
		and not _pendiente_sin_boton_cancelar()

func _cancelar_modo_salto_wheelie() -> void:
	_wheelie_idle_timer = 0.0
	if _wheelie_hop_mode:
		_wheelie_hop_mode = false
		_wheelie_hop_seq += 1

func _debe_mostrar_sombra_salto(celda_origen: Vector2i, dir_salto: Vector2, distancia_tiles: int) -> bool:
	var direccion_tiles := Vector2i(dir_salto)
	for paso: int in range(distancia_tiles + 1):
		var celda := celda_origen + direccion_tiles * paso
		if _celda_tiene_agua_salpica(Vector2(celda)):
			return false
	return true

func _bucle_salto_wheelie(seq: int) -> void:
	while seq == _wheelie_hop_seq and _wheelie_hop_mode:
		if not _puede_mantener_salto_wheelie():
			break
		var dir_salto := _resolver_direccion_salto_wheelie()
		# Una puerta animada pudo tomar el control entre saltitos: no saltar más.
		if seq != _wheelie_hop_seq or not _wheelie_hop_mode:
			break
		if dir_salto != Vector2.ZERO and _debe_realizar_salto_borde(dir_salto):
			await realizar_salto_parabolico(dir_salto)
		else:
			await _realizar_salto_wheelie(dir_salto)
	if seq == _wheelie_hop_seq:
		_wheelie_hop_mode = false
		_wheelie_idle_timer = 0.0
		if en_bicicleta and en_wheelie and not no_control and not in_dialog:
			_actualizar_animacion_idle()

func _resolver_direccion_salto_wheelie() -> Vector2:
	var input_dir := _get_current_direction_input()
	if input_dir == Vector2.ZERO:
		return Vector2.ZERO
	_get_coord_tile_act()
	if input_dir != facing_direction:
		if _bici_dir_bloquea_giro(input_dir):
			return Vector2.ZERO
		facing_direction = input_dir
		_actualizar_animacion_idle()
		_get_coord_tile_act()
	# Entre saltitos el jugador está centrado en la celda y ProcessPlayerFieldInput
	# corre igual que a pie: mantener ARRIBA frente a una puerta animada la abre
	# (map_warp_consider_2_to_inside); desde otro lado, o en una de servicio, es
	# un obstáculo y se salta en el sitio.
	if _intentar_entrada_puerta(input_dir, _obtener_mapa_actual()):
		if no_control:
			_cancelar_modo_salto_wheelie()
		return Vector2.ZERO
	if can_move(input_dir):
		return input_dir
	return Vector2.ZERO

func _realizar_salto_wheelie(dir_salto: Vector2) -> void:
	_change_state(PlayerState.JUMPING)
	alterna_animacion = 1 if alterna_animacion == 2 else 2
	_actualizar_animacion_idle()
	_get_coord_tile_act()
	var posicion_inicial: Vector2 = position
	var posicion_final: Vector2 = position + dir_salto * Singleton.TILE_SIZE
	var tiempo := 0.0
	var celda_origen := pos_celda_act
	var distancia_salto := 0 if dir_salto == Vector2.ZERO else 1
	_celda_destino = celda_origen + Vector2i(dir_salto) * distancia_salto
	_anunciar_paso()
	var mostrar_sombra := _debe_mostrar_sombra_salto(celda_origen, dir_salto, distancia_salto)
	var offset_inicial := Vector2.ZERO
	if animated_sprite:
		offset_inicial = animated_sprite.offset
	sombra.visible = mostrar_sombra

	while tiempo < WHEELIE_HOP_DURATION:
		tiempo += get_process_delta_time()
		var t := minf(tiempo / WHEELIE_HOP_DURATION, 1.0)
		var y_offset := 4.0 * WHEELIE_HOP_HEIGHT * t * (t - 1.0)
		position = posicion_inicial.lerp(posicion_final, t)
		if animated_sprite:
			animated_sprite.offset.y = offset_inicial.y + y_offset
		await get_tree().create_timer(get_process_delta_time()).timeout

	position = posicion_final
	if animated_sprite:
		animated_sprite.offset = offset_inicial
		animated_sprite.stop()
		animated_sprite.frame = 0
	sombra.visible = false
	_get_coord_tile_act()
	if dir_salto != Vector2.ZERO:
		_verificar_cambio_capa()
	_sincronizar_elevacion_punto()
	actualizar_efecto_terreno_actual()
	_aplicar_efecto_aterrizaje_wheelie()
	_change_state(PlayerState.IDLE)

func _aplicar_efecto_aterrizaje_wheelie() -> void:
	if _celda_tiene_agua_salpica(Vector2(pos_celda_act)):
		_efectos_agua.disparar_salpicadura()
		_intentar_onda_agua()
		return
	levanta_polvo(pos_celda_act)

func _procesar_movimiento(delta: float):
	if duracion_paso <= 0:
		duracion_paso = 0.01

	progreso_paso += delta / duracion_paso
	if progreso_paso > 1.0:
		progreso_paso = 1.0

	# Interpolación lineal de la posición
	position = origen_paso.lerp(destino_paso, progreso_paso)

	# Calcular píxeles avanzados para decidir frame
	var desplazamiento_vector = position - origen_paso
	var pixeles_avanzados = abs(desplazamiento_vector.x + desplazamiento_vector.y)
	_actualizar_frame_paso(pixeles_avanzados)
	_actualizar_shader_hierba_transicion(pixeles_avanzados)
	if _efectos_arena and not en_surf:
		_efectos_arena.actualizar_progreso(pixeles_avanzados)
	if _tierra_pies:
		_tierra_pies.actualizar_progreso(pixeles_avanzados)
		_aplicar_tierra_pies()
	if _efectos_agua and not en_surf:
		_efectos_agua.actualizar_progreso(pixeles_avanzados)

	if progreso_paso >= 1.0:
		_finalizar_paso()

## Duración de un ciclo del paso bloqueado (WalkInPlace del decomp): a pie
## WalkInPlaceSlow = 32 fotogramas, en bici WalkInPlaceNormal = 16 y en wheelie
## (AcroWheelieInPlace) = 8. Es también el ritmo con el que se repite el sonido.
func _duracion_ciclo_paso_bloqueado() -> float:
	if en_wheelie:
		return NpcBase.duracion_para_velocidad(NpcBase.VelocidadPaso.RAPIDO)
	if en_bicicleta:
		return NpcBase.duracion_para_velocidad(NpcBase.VelocidadPaso.NORMAL)
	return NpcBase.duracion_para_velocidad(NpcBase.VelocidadPaso.LENTO)

func _procesar_paso_bloqueado(delta: float):
	# Animación de paso bloqueado a mitad de velocidad
	blocked_step_timer += delta
	var frame_duration := _duracion_ciclo_paso_bloqueado()

	# Alternar entre frame 0 y 1 cada frame_duration/2
	# var cycle_progress = fmod(blocked_step_timer, frame_duration) / frame_duration
	var cycle_progress = blocked_step_timer / frame_duration

	if cycle_progress < 0.5:	# Primer medio ciclo
		animated_sprite.frame = 1
	elif cycle_progress < 1.0:						# Segundo medio ciclo
		animated_sprite.frame = 0
	else:
		alterna_animacion = 1 if alterna_animacion == 2 else 2
		_actualizar_animacion_idle()
		animated_sprite.frame = 1
		blocked_step_timer -= frame_duration  # Resetea timer para ciclo continuo
		if _bloqueo_con_sonido:
			_reproducir_sonido_campo(SONIDO_CHOQUE)

## Detecta qué dirección está siendo presionada actualmente
func _get_current_direction_input() -> Vector2:
	if Input.is_action_pressed("btn_abajo"):
		return Vector2(0, 1)
	elif Input.is_action_pressed("btn_arriba"):
		return Vector2(0, -1)
	elif Input.is_action_pressed("btn_derecha"):
		return Vector2(1, 0)
	elif Input.is_action_pressed("btn_izquierda"):
		return Vector2(-1, 0)
	else:
		return Vector2.ZERO

func _actualizar_frame_paso(pixeles: float):
	if not animated_sprite:
		return
	if _paso_sin_animacion:
		animated_sprite.frame = 1  # disableAnim de ForcedMovement_Slip / _Slide
		return
	var numero_frame = 0
	if pixeles >= 4 and pixeles < 12:
		numero_frame = 1
	else:
		numero_frame = 0
	animated_sprite.frame = numero_frame

## Actualiza la animación a caminar/bici/wheelie según la dirección actual sin movimiento
func _actualizar_animacion_idle():
	if en_buceo:
		_poner_animacion_buceo()
		return
	if en_surf:
		if otras:
			var dir_str := _get_dir_string()
			var anim_name := &"sentar_" + dir_str
			if otras.sprite_frames.has_animation(anim_name):
				if otras.animation != anim_name:
					otras.play(anim_name)
					otras.stop()
				otras.frame = 0
		return
	if en_bicicleta:
		var prefix := "wheelie_" if en_wheelie else "bici_"
		_configurar_animacion_direccion(prefix, 0)
	else:
		_configurar_animacion_direccion("camina_", 0)

## Función helper para configurar animación según dirección actual
func _configurar_animacion_direccion(prefix: String, frame: int):
	if not animated_sprite:
		return

	var dir_str = "abajo"
	if facing_direction == Vector2(0, -1):
		dir_str = "arriba"
	elif facing_direction == Vector2(1, 0):
		dir_str = "derecha"
	elif facing_direction == Vector2(-1, 0):
		dir_str = "izquierda"
	elif facing_direction == Vector2(0, 1):
		dir_str = "abajo"

	var anim_name = prefix + dir_str + "_" + str(alterna_animacion)

	# Validación adicional para evitar reproducción de animación vacía
	if anim_name == "" or anim_name.ends_with("_"):
		print("⚠️ [_CONFIGURAR_ANIMACION] Fallback: anim_name era inválido: '", anim_name, "'")
		anim_name = prefix + "abajo_1"

	if animated_sprite.animation != anim_name:
		animated_sprite.play(anim_name)
		animated_sprite.stop()
	animated_sprite.frame = frame

func _finalizar_paso():
	paso_en_curso = false
	_venia_sin_animacion = _paso_sin_animacion
	_paso_sin_animacion = false
	if animated_sprite:
		animated_sprite.stop()
		animated_sprite.frame = 0
	if _tierra_pies:
		_tierra_pies.reiniciar_frame()
	_change_state(PlayerState.IDLE)
	_get_coord_tile_act()
	if not en_surf and _celda_tiene_agua_salpica(Vector2(pos_celda_act)):
		_efectos_agua.disparar_salpicadura()
	_verificar_cambio_capa()  # pos_celda_act apunta a la celda destino
	_sincronizar_elevacion_punto()
	actualizar_efecto_terreno_actual()
	_intentar_burbujas_alga()
	# TryStartStepBasedScript: el warp y el agujero van antes que los pasos de
	# guardería, repelente y encuentros, y si saltan ninguno de ellos cuenta.
	if _procesar_warp_pisado():
		return
	if _procesar_agujero():
		return
	_verificar_encuentro_salvaje()
	_intentar_onda_agua()
	_procesar_cuesta_barro()
	_procesar_suelo_forzado()

## Cuesta de barro (MB_MUDDY_SLOPE, ForcedMovement_MuddySlope): al quedar sobre una
## celda CUESTA_BARRO, solo se sigue subiendo si se mira al norte en bici de
## carrera a máxima velocidad. Si no, se pierde la velocidad y se resbala una celda
## al sur a velocidad de correr (PlayerGoSpeed2) sin girar al personaje; al llegar
## a otra celda de barro se repite, y se para al salir de la cuesta o al chocar.
func _procesar_cuesta_barro() -> void:
	if no_control or in_dialog or esta_siguiendo() or en_surf or Singleton.esta_pausado():
		return
	var tp := _obtener_tp_capa_actual()
	if tp == null or not tp.has_flag(Vector2(pos_celda_act), TPTileDataMap.Flags.CUESTA_BARRO):
		return
	var sube := facing_direction == Vector2.UP and en_bicicleta 		and tipo_bici == BICI_CARRERA and contador_bici >= CONTADOR_BICI_MAX
	if sube:
		return
	contador_bici = 0
	var mirada: Vector2 = facing_direction
	facing_direction = Vector2.DOWN
	_get_coord_tile_act()
	if can_move(Vector2.DOWN):
		_iniciar_paso_manual(Vector2.DOWN, float(Singleton.TILE_SIZE) / RUNNING_SPEED)
	facing_direction = mirada
	_get_coord_tile_act()

## Suelo de movimiento forzado (TryDoMetatileBehaviorForcedMovement): al terminar
## un paso sobre una celda RESBALADIZO / EMPUJE_* el jugador sigue moviéndose solo
## en la dirección de la celda (ver SueloForzado) hasta que algo le bloquea o sale
## de la zona. Rubí no lo aplica al aparecer por un warp (PLAYER_AVATAR_FLAG_5):
## aquí tampoco, porque solo se evalúa al terminar un paso.
## Si un guion bloquea el control, el movimiento queda pendiente y se reanuda.
## En surf solo cuentan las corrientes (SURF + EMPUJE_<dir>, ForcedMovement_RideCurrent*
## con PlayerRideWaterCurrent): arrastran a velocidad de surf, animado y mirando a la
## corriente, y paran ante algo que no sea agua (en Rubí la orilla tiene otra
## elevación: colisión, no desembarco).
## Devuelve true si empieza un paso forzado.
func _procesar_suelo_forzado() -> bool:
	_suelo_forzado_pendiente = false
	if paso_en_curso or esta_siguiendo() or not is_in_group(&"Personaje"):
		return false
	var tp := _obtener_tp_capa_actual()
	if tp == null:
		return false
	# MB_WATERFALL: ForcedMovement_RideCurrentSouth. Subiendo con el movimiento CASCADA
	# no empuja: sube él mismo.
	if en_surf and not _subiendo_cascada and tp.has_flag(Vector2(pos_celda_act), TPTileDataMap.Flags.CASCADA):
		return _empujar_por_cascada(tp)
	var flags := tp.get_flags(Vector2(pos_celda_act))
	var modo := SueloForzado.modo(flags)
	if modo == SueloForzado.Modo.NINGUNO:
		return false
	if en_surf and modo != SueloForzado.Modo.CAMINA:
		return false
	if no_control or in_dialog or Singleton.esta_pausado():
		_suelo_forzado_pendiente = true
		return false
	var mirada: Vector2 = facing_direction
	# ForcedMovement_Slip sigue movementDirection: tras una cinta deslizante no coincide
	# con la mirada bloqueada.
	var avance: Vector2 = _direccion_sin_animacion if _venia_sin_animacion else mirada
	var direccion := SueloForzado.direccion(flags, avance)
	if direccion == Vector2.ZERO:
		return false
	# can_move() exige mirar hacia donde se va (si no, solo gira): se prueba con
	# la dirección forzada y, si choca, el personaje conserva su mirada.
	facing_direction = direccion
	_get_coord_tile_act()
	if en_surf and not tp.has_flag(Vector2(pos_celda_sig), TPTileDataMap.Flags.SURF) \
			and _celda_esta_dentro_del_mapa(_obtener_mapa_actual(), pos_celda_sig):
		facing_direction = mirada
		_get_coord_tile_act()
		return false
	var mapa_origen := _obtener_mapa_actual()
	if not can_move(direccion):
		facing_direction = mirada
		_get_coord_tile_act()
		return false
	# Pierde el impulso de la bici de carrera, como en la cuesta de barro.
	contador_bici = 0
	var velocidad := SPEED if modo == SueloForzado.Modo.CAMINA and not en_surf else RUNNING_SPEED
	var alterna_previa := alterna_animacion
	_iniciar_paso_manual(direccion, float(Singleton.TILE_SIZE) / velocidad, mapa_origen)
	if modo != SueloForzado.Modo.CAMINA:
		_paso_sin_animacion = true
		_direccion_sin_animacion = direccion
		# sub_805FE28: con la animación pausada no se alterna de pierna entre celdas.
		if _venia_sin_animacion:
			alterna_animacion = alterna_previa
		# facingDirectionLocked: el sprite sigue mirando a donde miraba (en hielo pisado
		# caminando, la mirada ya es la dirección de avance).
		facing_direction = mirada
		_actualizar_animacion_idle()
		if animated_sprite:
			animated_sprite.frame = 1  # disableAnim: pausado en el frame de paso
	return true

## Caída por una cascada surfeando sin el movimiento CASCADA: un paso al sur a la
## velocidad de RideWaterCurrent (CYCLING_SPEED) y, al acabar, se repite mientras la
## celda siga siendo CASCADA. El personaje queda mirando al sur (sin mirada bloqueada).
## Se detiene ante un obstáculo o si debajo no hay agua. Devuelve true si empieza el paso.
func _empujar_por_cascada(tp: TPTileDataMap) -> bool:
	if no_control or in_dialog or Singleton.esta_pausado():
		_suelo_forzado_pendiente = true
		return false
	facing_direction = Vector2.DOWN
	_actualizar_poke_field_dir()
	_get_coord_tile_act()
	if not tp.has_flag(Vector2(pos_celda_sig), TPTileDataMap.Flags.SURF) \
			and _celda_esta_dentro_del_mapa(_obtener_mapa_actual(), pos_celda_sig):
		_actualizar_animacion_idle()
		return false
	var mapa_origen := _obtener_mapa_actual()
	if not can_move(Vector2.DOWN):
		_actualizar_animacion_idle()
		return false
	_iniciar_paso_manual(Vector2.DOWN, float(Singleton.TILE_SIZE) / CYCLING_SPEED, mapa_origen)
	return true

## TryStartWarpEventScript: un warp que salta al pisarlo se evalúa aquí, al terminar el
## paso y antes de leer más entrada. Warp._process no basta: el AdministradorMapa lee la
## cruceta antes de que el warp vea al jugador parado y, con la dirección mantenida,
## el paso siguiente ya ha empezado. Un paso de guion no cuenta (no_control).
## Devuelve true si empieza la transición del warp.
func _procesar_warp_pisado() -> bool:
	if not is_in_group(&"Personaje") or no_control or in_dialog or esta_siguiendo():
		return false
	if nodo_administrador == null or not nodo_administrador.has_method("warp_en_celda"):
		return false
	var mapa := _obtener_mapa_actual()
	if mapa == null or not llego_caminando_a_warp(mapa, pos_celda_act):
		return false
	var warp: Warp = nodo_administrador.warp_en_celda(mapa, pos_celda_act)
	return warp != null and warp.activar_al_pisar(self, nodo_administrador)

## Suelo agrietado (TryStartCrackedFloorHoleScript): al terminar un paso sobre un
## agujero (celda agrietada ya rota o con la bandera AGUJERO) el jugador cae al
## piso de abajo, salvo que la celda se haya roto con este mismo paso en bici de
## carrera a máxima velocidad. Devuelve true si empieza la caída.
func _procesar_agujero() -> bool:
	var mapa_inferior := _comprobar_agujero()
	if mapa_inferior.is_empty():
		return false
	var mapa := _obtener_mapa_actual()
	var suelo: SueloAgrietadoMapa = mapa.obtener_suelo_agrietado() if mapa != null else null
	var celda_llegada := suelo.celda_de_llegada(pos_celda_act) if suelo != null else pos_celda_act
	_caer_por_agujero(mapa_inferior, celda_llegada)
	return true

## Mapa al que se cae desde pos_celda_act al terminar el paso, o "" si no se cae.
## Consume la celda salvada por velocidad del paso que termina.
func _comprobar_agujero() -> String:
	var celda_salvada: Variant = _celda_salvada_por_velocidad
	_celda_salvada_por_velocidad = null
	if not is_in_group(&"Personaje") or _cayendo:
		return ""
	if no_control or in_dialog or esta_siguiendo() or en_surf or Singleton.esta_pausado():
		return ""
	var mapa := _obtener_mapa_actual()
	var suelo: SueloAgrietadoMapa = mapa.obtener_suelo_agrietado() if mapa != null else null
	if suelo == null:
		return ""
	if celda_salvada is Vector2i and celda_salvada == pos_celda_act:
		return ""
	if not suelo.es_agujero(_obtener_tp_capa_actual(), pos_celda_act):
		return ""
	if suelo.mapa_inferior.is_empty() \
			or Singleton._buscar_ruta_mapa_por_nombre("res://escenas/mapas/", suelo.mapa_inferior).is_empty():
		push_warning("[AGUJERO] '%s' no tiene un mapa_inferior válido ('%s'): no se cae" % [mapa.name, suelo.mapa_inferior])
		return ""
	return suelo.mapa_inferior

## true mientras el z_index lleva sumado OFFSET_ELEVACION (PUNTO_ELEVADO).
var elevado_punto: bool = false

## El paso en curso es un deslizamiento forzado (disableAnim): no anima el caminar.
var _paso_sin_animacion: bool = false
## El último paso terminado fue un deslizamiento forzado: el siguiente conserva la pierna.
var _venia_sin_animacion: bool = false
## Dirección del último deslizamiento forzado (movementDirection).
var _direccion_sin_animacion: Vector2 = Vector2.ZERO
## Un guion cortó un movimiento forzado: se reanuda al devolver el control.
var _suelo_forzado_pendiente: bool = false

## z_index extra vigente por PUNTO_ELEVADO. Singleton lo suma al reasignar el
## z_index del foco por capa (cambio de capa, fin de vuelo, etc.).
func get_offset_elevacion() -> int:
	return OFFSET_ELEVACION if elevado_punto else 0

func _celda_es_punto_elevado(celda: Vector2i) -> bool:
	var tp := _obtener_tp_capa_actual()
	return tp != null and tp.has_flag(Vector2(celda), TPTileDataMap.Flags.PUNTO_ELEVADO)

func _fijar_elevacion_punto(activo: bool) -> void:
	if activo == elevado_punto:
		return
	elevado_punto = activo
	z_index += OFFSET_ELEVACION if activo else -OFFSET_ELEVACION

## Al empezar un paso o salto: si la celda destino es PUNTO_ELEVADO se sube de
## inmediato; si no, se conserva el estado hasta que termine el paso.
func _elevar_si_destino_elevado(celda_destino: Vector2i) -> void:
	if _celda_es_punto_elevado(celda_destino):
		_fijar_elevacion_punto(true)

## Al terminar un paso o aparecer en una celda: el offset solo queda activo si
## la celda actual es PUNTO_ELEVADO. Debe llamarse DESPUÉS de _get_coord_tile_act().
func _sincronizar_elevacion_punto() -> void:
	_fijar_elevacion_punto(_celda_es_punto_elevado(pos_celda_act))

## Comprueba si la celda de SALIDA tiene bandera CAPA_SUPERIOR/CAPA_INFERIOR en la celda.
## Debe llamarse DESPUES de _get_coord_tile_act() para que pos_celda_act sea la celda a la que se llega.
func _verificar_cambio_capa() -> void:
	if no_control:
		return
	var tp := _obtener_tp_capa_actual()
	if tp == null:
		return
	var celda := Vector2(pos_celda_act)
	if tp.has_flag(celda, TPTileDataMap.Flags.CAPA_SUPERIOR):
		Singleton.set_capa_activa(Singleton.capa_activa + 1)
	elif tp.has_flag(celda, TPTileDataMap.Flags.CAPA_INFERIOR):
		Singleton.set_capa_activa(Singleton.capa_activa - 1)

## Descuenta el paso del repelente y, si la celda actual admite encuentros,
## delega el intento al AdministradorMapa. Solo se ejecuta para el jugador
## (nodo con control): los pasos de guion (no_control) y los de escolta
## (seguir_a) no cuentan.
func _verificar_encuentro_salvaje() -> void:
	if no_control or in_dialog or esta_siguiendo():
		return
	# Un evento que interrumpe el paso (p. ej. un entrenador que ve al jugador)
	# mantiene la pausa: en pokeruby ProcessPlayerFieldInput no corre con un
	# script activo, así que ese paso no cuenta ni puede dar encuentro.
	if Singleton.esta_pausado():
		return
	# Revanchas: el paso cuenta con 5 medallas o más (IncrementRematchStepCounter,
	# que en pokeruby corre antes que la guardería dentro de TryStartStepCountScript).
	if nodo_administrador != null and nodo_administrador.has_method("procesar_paso_revancha"):
		nodo_administrador.procesar_paso_revancha()
	# Amistad (UpdateHappinessStep): justo después de las revanchas en pokeruby.
	if nodo_administrador != null and nodo_administrador.has_method("procesar_paso_amistad"):
		nodo_administrador.procesar_paso_amistad()
	# Veneno en el campo (UpdatePoisonStepCounter): cada 4 pasos los envenenados
	# pierden 1 PS. Si alguno se debilita, el paso termina aquí, sin guardería,
	# repelente ni encuentro (TryStartStepCountScript de pokeruby).
	var admin_tiene_veneno: bool = nodo_administrador != null and nodo_administrador.has_method("procesar_paso_veneno")
	if admin_tiene_veneno and nodo_administrador.procesar_paso_veneno():
		return
	# Guardería (pasos, huevos y ciclos): si eclosiona un huevo, el paso termina
	# aquí, sin repelente ni encuentro (TryStartStepCountScript de pokeruby).
	var admin_tiene_guarderia: bool = nodo_administrador != null and nodo_administrador.has_method("procesar_paso_guarderia")
	if admin_tiene_guarderia and nodo_administrador.procesar_paso_guarderia():
		return
	# ZONA SAFARI (SafariZoneTakeStep, después de la guardería): con la partida
	# SAFARI activa cada paso cuenta; el último termina el juego y ese paso no
	# tiene repelente ni encuentro.
	var admin_tiene_safari: bool = nodo_administrador != null and nodo_administrador.has_method("procesar_paso_safari")
	if admin_tiene_safari and nodo_administrador.procesar_paso_safari():
		return
	# Cada paso del jugador (en cualquier terreno) gasta repelente. Si se agota
	# en este paso, el aviso sustituye al encuentro (como en pokeruby).
	var admin_tiene_repelente: bool = nodo_administrador != null and nodo_administrador.has_method("procesar_paso_repelente")
	if admin_tiene_repelente and nodo_administrador.procesar_paso_repelente():
		return
	var tipo := _tipo_encuentro_en_celda(Vector2(pos_celda_act))
	if tipo != "" and nodo_administrador and nodo_administrador.has_method("intentar_encuentro_salvaje"):
		nodo_administrador.intentar_encuentro_salvaje(tipo)

## Tabla de encuentros que corresponde a la celda: hierba alta, arena de desierto y
## suelo de interior con encuentros (ENCUENTRO_INTERIOR, MONTE PÍRICO) usan "hierba";
## surf usa "agua". En mapas es_cueva cualquier otra celda usa "hierba" (suelo de
## cueva: encuentros en todas partes, sin banderas).
## "" si la celda no admite encuentros.
func _tipo_encuentro_en_celda(celda: Vector2) -> String:
	if _celda_tiene_animacion_pasto(celda) or _celda_tiene_desierto(celda) 			or _celda_tiene_encuentro_interior(celda):
		return "hierba"
	# Las algas submarinas (MB_SEAWEED) usan la tabla de agua (IsWaterWildEncounter).
	if _celda_tiene_surf(celda) or _celda_tiene_alga(celda):
		return "agua"
	var mapa := _obtener_mapa_actual()
	if mapa != null and mapa.es_cueva and not _celda_excluida_encuentro_cueva(celda):
		return "hierba"
	return ""

## Celdas de cueva que no dan encuentro aunque el mapa sea es_cueva: bloqueos,
## suelo agrietado, agujeros y escaleras (cambio de capa).
func _celda_excluida_encuentro_cueva(celda: Vector2) -> bool:
	var tp := _obtener_tp_capa_actual()
	if tp == null:
		return false
	for bandera in [
		TPTileDataMap.Flags.BLOQUEO,
		TPTileDataMap.Flags.SUELO_AGRIETADO,
		TPTileDataMap.Flags.AGUJERO,
		TPTileDataMap.Flags.CAPA_SUPERIOR,
		TPTileDataMap.Flags.CAPA_INFERIOR,
	]:
		if tp.has_flag(celda, bandera):
			return true
	return false

func _celda_tiene_encuentro_interior(celda: Vector2) -> bool:
	var tp := _obtener_tp_capa_actual()
	return tp != null and tp.has_flag(celda, TPTileDataMap.Flags.ENCUENTRO_INTERIOR)

func _celda_tiene_desierto(celda: Vector2) -> bool:
	var tp := _obtener_tp_capa_actual()
	return tp != null and tp.has_flag(celda, TPTileDataMap.Flags.DESIERTO)

func _celda_tiene_surf(celda: Vector2) -> bool:
	var tp := _obtener_tp_capa_actual()
	return tp != null and tp.has_flag(celda, TPTileDataMap.Flags.SURF)

func _celda_tiene_alga(celda: Vector2) -> bool:
	var tp := _obtener_tp_capa_actual()
	return tp != null and tp.has_flag(celda, TPTileDataMap.Flags.ALGA)

func move_to_next_tile(input_dir: Vector2, running: bool = false):
	if paso_en_curso:
		return

	# Escoltado: los pasos los dicta el líder (_on_lider_paso_iniciado).
	if esta_siguiendo():
		return

	if en_pesca or state in [PlayerState.TURNING, PlayerState.JUMPING, PlayerState.TALKING, PlayerState.FISHING]:
		return

	if _wheelie_hop_mode:
		return

	# El AdministradorMapa procesa la cruceta antes que nuestro _process: en el
	# fotograma en que se libera el control seguimos en LOCKED. Sin sincronizar
	# aquí se saltaría el giro en sitio y pos_celda_sig usaría la dirección vieja,
	# así que un paso hacia una puerta (p. ej. salir de una casa con ARRIBA
	# pulsado) no pasaría por intentar_entrada.
	if state == PlayerState.LOCKED and not (no_control or in_dialog):
		_change_state(PlayerState.IDLE)

	# Bloquear giro en sitio cuando btn_cancelar está presionado en bicicleta.
	# Así facing_direction no cambia antes de que _process evalúe el combo especial.
	# No bloquear el movimiento recto (misma dirección): no hay cambio de facing que proteger.
	if _es_bici_acrobatica() and Input.is_action_pressed(&"btn_cancelar") and input_dir != facing_direction:
		return

	# Si estaba corriendo y ahora no, cambiar animación a caminar sin tiempo de espera
	if is_running and not running and input_dir == Vector2.ZERO:
		is_running = false
		_venia_en_movimiento = false
		_actualizar_animacion_idle()
		_change_state(PlayerState.IDLE)
		return

	is_running = running
	# Sin DEPORTIVAS no se corre (FLAG_SYS_B_DASH): se las da MAMÁ en Villa Raíz.
	if is_running and not HistoriaVillaRaiz.puede_correr():
		is_running = false
	# En modo bicicleta no se usa running; la velocidad la gestiona en_bicicleta
	if en_bicicleta:
		is_running = false
	# En surf no se puede correr ni usar bicicleta; bajo el agua tampoco se corre
	# (PlayerNotOnBikeMoving excluye PLAYER_AVATAR_FLAG_UNDERWATER).
	if en_surf or en_buceo:
		is_running = false
	# SOLO_CAMINAR nivel mapa: bloquear carrera antes de cualquier animación de giro
	if is_running:
		var mapa_solo := _obtener_mapa_actual()
		if mapa_solo != null and (mapa_solo.solo_caminar or mapa_solo.sin_correr):
			is_running = false
	if input_dir == Vector2.ZERO:
		contador_bici = 0
		_venia_en_movimiento = false
		return

	# Paso bloqueado (WalkInPlaceSlow) y se pulsa otra dirección: como sub_8058854,
	# se interrumpe y se resuelve directamente en la nueva (paso o choque), sin giro
	# en sitio. Sin esto, can_move cambiaba facing_direction sin actualizar el
	# sprite (el choque no se reiniciaba por seguir en BLOCKED_STEP) y A hablaba
	# con quien estaba al lado mientras el jugador seguía mirando al obstáculo.
	if state == PlayerState.BLOCKED_STEP and facing_direction != input_dir:
		if _bici_dir_bloquea_giro(input_dir):
			return
		facing_direction = input_dir
		_change_state(PlayerState.IDLE)

	# Detectar cambio de dirección cuando el jugador está parado
	if facing_direction != input_dir and state == PlayerState.IDLE:
		# En BICI_DIR, no se puede girar en la dirección no permitida
		if _bici_dir_bloquea_giro(input_dir):
			return
		# A pie, si veníamos de un paso sin soltar la cruceta no gastamos el giro
		# en sitio (0.15 s de reacción) y encadenamos el paso en la nueva dirección.
		if _venia_en_movimiento and not en_bicicleta:
			facing_direction = input_dir
		elif _bici_carrera_a_maxima_velocidad():
			# Bici de carrera a máxima velocidad: el cambio de dirección encadena
			# el paso sin giro en sitio y conserva la velocidad. Solo se pierde
			# si el paso nuevo está bloqueado (_iniciar_paso_bloqueado).
			facing_direction = input_dir
		else:
			# Animación de giro en sitio cuando está parado
			_animacion_giro_en_sitio(input_dir)
			return

	_get_coord_tile_act()
	var aplica_recorte_hierba_muy_alta := _evaluar_transicion_hierba(input_dir)

	# En hierba muy alta no se puede correr
	if aplica_recorte_hierba_muy_alta and is_running:
		is_running = false
	# SOLO_CAMINAR: la celda destino prohíbe correr (no aplica en bicicleta)
	if is_running and not en_bicicleta:
		var tp_check := _obtener_tp_capa_actual()
		if tp_check != null and tp_check.has_flag(Vector2(pos_celda_sig), TPTileDataMap.Flags.SOLO_CAMINAR):
			is_running = false
	# SOLO_CAMINAR nivel mapa: prohíbe correr en todo el mapa
	if is_running and not en_bicicleta:
		var mapa_check := _obtener_mapa_actual()
		if mapa_check != null and mapa_check.solo_caminar:
			is_running = false
	var mapa_origen := _obtener_mapa_actual()
	if _intentar_entrada_puerta(input_dir, mapa_origen):
		return

	# Mover solo si no hay obstáculo
	if can_move(input_dir):
		# Surf: si el tile destino no es SURF, hacer salto de salida en lugar del paso normal
		if en_surf:
			var tp_surf := _obtener_tp_capa_actual()
			# Si can_move cruzó el borde a otro mapa, la celda destino se expresa en el mapa nuevo.
			var celda_surf := _celda_en_mapa_actual(pos_celda_sig, mapa_origen)
			if tp_surf != null and not tp_surf.has_flag(Vector2(celda_surf), TPTileDataMap.Flags.SURF):
				_realizar_salto_salida_surf(input_dir)
				return
		_aplicar_efecto_hierba_muy_alta(aplica_recorte_hierba_muy_alta)
		# Iniciar movimiento manual según modo
		_iniciar_paso_manual(input_dir, 0.0, mapa_origen)

		if mapa_origen != null and nodo_administrador != null and nodo_administrador.mapa_actual == mapa_origen:
			# Detectar puertas
			buscar_puerta("entrar")
			var tp := _obtener_tp_capa_actual()
			if tp != null:
				var cell_f := Vector2(pos_celda_sig)
				if _intentar_limpiar_ceniza(pos_celda_sig):
					pass  # La hierba con ceniza lanza sus propios efectos con retardo
				elif _celda_tiene_hierba_mas_alta(cell_f):
					_reproducir_animacion_hierba_muy_alta(pos_celda_sig)
				elif _celda_tiene_hierba_alta(cell_f):
					_spawn_animacion_pasto(pos_celda_sig)
				elif _debe_realizar_salto_borde(facing_direction):
					paso_en_curso = false
					realizar_salto_parabolico(facing_direction)
	elif _salida_activada:
		# Una SALIDAS ya inició la transición: no es un choque, así que ni sonido
		# ni pose de paso bloqueado antes del warp.
		_salida_activada = false
	else:
		# Con FUERZA activa, caminar contra una roca la empuja (TryPushBoulder):
		# el jugador hace el paso bloqueado mientras ella se desliza.
		var empujada := _intentar_empujar_roca()
		# Animación de paso bloqueado - cancelable inmediatamente. Suena el
		# choque salvo que la roca se esté deslizando (PlayCollisionSoundIfNotFacingWarp).
		if state != PlayerState.BLOCKED_STEP:
			_iniciar_paso_bloqueado(input_dir, not empujada)

## Las puertas Ruby abren ANTES del paso; las de servicio bloquean el acceso libre.
## true si la puerta de pos_celda_sig consumió el intento (paso o saltito).
func _intentar_entrada_puerta(input_dir: Vector2, mapa_origen: Node) -> bool:
	if nodo_administrador == null or mapa_origen == null or not nodo_administrador.has_method("warp_en_celda"):
		return false
	var warp_entrada: Warp = nodo_administrador.warp_en_celda(mapa_origen, pos_celda_sig)
	return warp_entrada != null and warp_entrada.intentar_entrada(self, nodo_administrador, input_dir)

## Actualiza las coordenadas de las celdas del jugador y de la que tiene al frente
func _get_coord_tile_act():
	if nodo_administrador == null:
		return
	pos_raiz_px = global_position - Vector2(8, 14)  # Offset para centrar mejor el personaje
	if nodo_administrador.enExterior:
		pos_mapa_px = pos_raiz_px - nodo_administrador.mapa_actual_offset
	else:
		pos_mapa_px = pos_raiz_px
	pos_celda_act = Vector2i(floor(pos_mapa_px.x / Singleton.TILE_SIZE), floor(pos_mapa_px.y / Singleton.TILE_SIZE))
	pos_celda_sig = pos_celda_act + Vector2i(facing_direction)
	if _en_celda_llegada_warp and not paso_en_curso and _celda_global() != _celda_llegada_warp:
		_en_celda_llegada_warp = false


## Celda en el mismo sistema que usa Warp para comparar con el jugador.
func _celda_global() -> Vector2i:
	return Vector2i((global_position / Singleton.TILE_SIZE).floor())


## true mientras el jugador sigue en la celda donde apareció por un warp.
## Tratar la celda actual como celda de llegada: un warp bajo el jugador no salta hasta
## que salga y vuelva a entrar (p. ej. al cargar una partida guardada sobre una escalera).
func marcar_celda_de_llegada_warp() -> void:
	_celda_llegada_warp = _celda_global()
	_en_celda_llegada_warp = true
	_ultimo_paso_mapa = null
	_venia_en_movimiento = false  # Al cargar el mapa, runningState = NOT_MOVING

func esta_en_celda_de_llegada_warp() -> bool:
	return _en_celda_llegada_warp and _celda_global() == _celda_llegada_warp

## `duracion_forzada` > 0 impone la duración del paso (escolta: la del líder).
## `mapa_origen`: mapa en el que estaba la entidad al decidir el paso; difiere de
## `mapa_actual` si el paso cruza el borde (pos_celda_act sigue en coordenadas del origen).
func _iniciar_paso_manual(input_dir: Vector2, duracion_forzada: float = 0.0, mapa_origen: MapaConfiguracion = null):
	_paso_sin_animacion = false
	# Determinar estado (correr / caminar / bicicleta)
	var current_speed: float
	_paso_bici_velocidad_maxima = false
	if en_bicicleta:
		_movimiento_especial_bici_listo = false
		current_speed = RUNNING_SPEED if en_wheelie else CYCLING_SPEED
		if tipo_bici == BICI_CARRERA and duracion_forzada <= 0.0:
			_paso_bici_velocidad_maxima = contador_bici == CONTADOR_BICI_MAX
			current_speed = VELOCIDADES_BICI_CARRERA[contador_bici]
			contador_bici = mini(contador_bici + 1, CONTADOR_BICI_MAX)
	elif is_running or en_surf:
		# PlayerGoSpeed2: en Gen 3 el surf avanza a la misma velocidad que correr
		current_speed = RUNNING_SPEED
	else:
		current_speed = SPEED
	_change_state(PlayerState.RUNNING if (is_running or en_bicicleta) else PlayerState.WALKING)
	_venia_en_movimiento = true
	duracion_paso = 1.0 / current_speed * Singleton.TILE_SIZE
	if duracion_forzada > 0.0:
		duracion_paso = duracion_forzada

	# Configurar movimiento
	paso_en_curso = true
	progreso_paso = 0.0
	facing_direction = input_dir
	origen_paso = position
	destino_paso = position + facing_direction * Singleton.TILE_SIZE
	_celda_destino = pos_celda_act + Vector2i(input_dir)

	# Agua termal: solo tapa el cuerpo si la celda de origen y la de destino son termales.
	if _sumersion_termal:
		_sumersion_termal.iniciar_paso(
			_obtener_tp_de_mapa(mapa_origen if mapa_origen != null else _obtener_mapa_actual(), Singleton.capa_activa),
			pos_celda_act,
			_celda_destino
		)

	# Huella en el tile que se abandona y arena de los pies
	if _efectos_arena:
		if en_surf:
			_efectos_arena.ocultar()
		else:
			var mapa_efectos := mapa_origen if mapa_origen != null else _obtener_mapa_actual()
			_efectos_arena.iniciar_paso(
				_obtener_tp_de_mapa(mapa_efectos, Singleton.capa_activa),
				mapa_efectos,
				pos_celda_act,
				pos_celda_act + Vector2i(input_dir),
				input_dir,
				en_bicicleta
			)
	# Tierra de los pies (bandera TIERRA_PIES), con las mismas reglas que la arena.
	if _tierra_pies:
		if en_surf:
			_tierra_pies.ocultar()
		else:
			var mapa_tierra := mapa_origen if mapa_origen != null else _obtener_mapa_actual()
			_tierra_pies.iniciar_paso(
				_obtener_tp_de_mapa(mapa_tierra, Singleton.capa_activa),
				pos_celda_act,
				pos_celda_act + Vector2i(input_dir)
			)
		_aplicar_tierra_pies()

	# Inicializar animación
	alterna_animacion = 1 if alterna_animacion == 2 else 2
	_inicializar_animacion_paso(input_dir)

	# Salpicadura al iniciar paso (desactivada en surf); el charco (AGUA_PIES) dura mientras se pisa
	if _efectos_agua:
		_efectos_agua.iniciar_paso(Vector2(pos_celda_act), Vector2(pos_celda_act + Vector2i(input_dir)), not en_surf)

	_anunciar_paso(mapa_origen)

	# (realizar_paso obsoleto)

func _inicializar_animacion_paso(input_dir: Vector2):
	if en_buceo:
		_poner_animacion_buceo()
		return
	if en_surf:
		if otras:
			var dir_str := _get_dir_string()
			var anim_name := &"sentar_" + dir_str
			if otras.sprite_frames.has_animation(anim_name):
				if otras.animation != anim_name:
					otras.play(anim_name)
					otras.stop()
				otras.frame = 0
		_actualizar_poke_field_dir()
		return
	if not animated_sprite:
		return

	var prefix: String
	if en_bicicleta:
		prefix = "wheelie_" if en_wheelie else "bici_"
	else:
		prefix = "corre_" if is_running else "camina_"
	var direccion = ""

	if input_dir == Vector2(0, 1):
		direccion = "abajo"
	elif input_dir == Vector2(0, -1):
		direccion = "arriba"
	elif input_dir == Vector2(1, 0):
		direccion = "derecha"
	elif input_dir == Vector2(-1, 0):
		direccion = "izquierda"

	if direccion != "":
		var nombre_anim = prefix + direccion + "_" + str(alterna_animacion)
		if animated_sprite.animation != nombre_anim:
			animated_sprite.play(nombre_anim)
			animated_sprite.stop()
		animated_sprite.frame = 0

## Animar giro sin mover
func _animacion_giro_en_sitio(input_dir: Vector2):
	if en_surf or en_buceo:
		facing_direction = input_dir
		_actualizar_animacion_idle()
		_actualizar_poke_field_dir()
		return
	contador_bici = 0
	if en_bicicleta:
		_movimiento_especial_bici_listo = false
	# Giro instantáneo: actualizar dirección y mostrar frame neutro.
	facing_direction = input_dir
	paso_en_curso = false
	# runningState = TURN_DIRECTION: el giro en sitio no cuenta como venir en movimiento.
	_venia_en_movimiento = false
	_change_state(PlayerState.TURNING)

	# Configurar animación de giro con frame 1 para mostrar apoyo de pie
	var prefix: String
	if en_bicicleta:
		prefix = "wheelie_" if en_wheelie else "bici_"
	else:
		prefix = "corre_" if is_running else "camina_"
	_configurar_animacion_direccion(prefix, 1)

	# Programar retorno a IDLE tras 0.15s sólo si no comenzó otra acción
	turn_sequence += 1
	var this_turn = turn_sequence
	await get_tree().create_timer(0.15).timeout
	if state == PlayerState.TURNING and this_turn == turn_sequence:
		if animated_sprite:
			animated_sprite.frame = 0
		_change_state(PlayerState.IDLE)

## Sonido de choque (SE_WALL_HIT) al intentar avanzar contra un obstáculo.
const SONIDO_CHOQUE := "SE_WALL_HIT"
## Sonido al empezar un salto de saliente (PlayerJumpLedge: PlaySE(SE_DANSA)).
const SONIDO_SALTO_BORDE := "SE_DANSA"
## Si el paso bloqueado actual suena al chocar: se repite en cada ciclo de la
## animación mientras se mantenga la dirección contra el obstáculo.
var _bloqueo_con_sonido := false
## can_move() devolvió false porque una SALIDAS se activó (no por un obstáculo).
var _salida_activada := false

func _iniciar_paso_bloqueado(input_dir: Vector2, con_sonido := true):
	# _logger("Iniciando paso bloqueado")
	_bloqueo_con_sonido = con_sonido
	# Bike_CheckCollisionTryAdvanceCollisionCount: cada choque en bici suma al reto del CAMINO de BICIS.
	if en_bicicleta:
		CaminoBici.registrar_choque()
	if con_sonido:
		_reproducir_sonido_campo(SONIDO_CHOQUE)
	contador_bici = 0
	# Animación de paso bloqueado: sin movimiento, animación lenta, cancelable
	if en_bicicleta:
		_movimiento_especial_bici_listo = false
	facing_direction = input_dir
	_change_state(PlayerState.BLOCKED_STEP)
	blocked_step_timer = 0.0

	# Configurar animación según estado actual (correr/caminar/bici)
	if is_running:
		is_running = false
	_venia_en_movimiento = false
	var prefix: String
	if en_bicicleta:
		prefix = "wheelie_" if en_wheelie else "bici_"
	else:
		prefix = "camina_"
	alterna_animacion = 1 if alterna_animacion == 2 else 2
	# _configurar_animacion_para_bloqueo(prefix)
	_configurar_animacion_direccion(prefix, 1)
	# Choque sobre una celda ya rota (cruzada a máxima velocidad): sin paso que
	# cambiar de dirección, el jugador cae como en el original. _caer_por_agujero
	# bloquea el control al instante, así que no hay giro ni paso extra.
	_procesar_agujero()

func _actualizar_animacion_salto_parabolico(dir: Vector2, pixeles_salto: float, alterna_paso_1: int, alterna_paso_2: int) -> void:
	if not animated_sprite:
		return

	var direccion := ""
	match dir:
		Vector2.DOWN:
			direccion = "abajo"
		Vector2.UP:
			direccion = "arriba"
		Vector2.RIGHT:
			direccion = "derecha"
		Vector2.LEFT:
			direccion = "izquierda"
		_:
			return

	var pixeles_totales := clampf(pixeles_salto, 0.0, float(Singleton.TILE_SIZE * 2))
	var alterna_para_tramo := alterna_paso_1
	var pixeles_tramo := pixeles_totales
	if pixeles_totales >= float(Singleton.TILE_SIZE):
		alterna_para_tramo = alterna_paso_2
		pixeles_tramo = pixeles_totales - float(Singleton.TILE_SIZE)

	alterna_animacion = alterna_para_tramo
	var numero_frame := 1 if pixeles_tramo >= 4.0 and pixeles_tramo < 12.0 else 0
	var nombre_anim := "camina_" + direccion + "_" + str(alterna_para_tramo)
	if animated_sprite.animation != nombre_anim:
		animated_sprite.play(nombre_anim)
		animated_sprite.stop()
	animated_sprite.frame = numero_frame

## Salto de saliente (PlayerJumpLedge): dos casillas con sombra y polvo al caer.
## Lo usan el paso normal, el salto lateral y el wheelie contra un desnivel, y en
## el original los tres suenan igual (SE_DANSA). Los saltos de guion, de salida
## de surf y los saltitos de la bici no pasan por aquí.
func realizar_salto_parabolico(dir):
	_reproducir_sonido_campo(SONIDO_SALTO_BORDE)
	_change_state(PlayerState.JUMPING)
	_get_coord_tile_act()
	var tiempo = 0.0
	var posicion_inicial = position
	var posicion_final = position + dir * Singleton.TILE_SIZE * 2
	var alterna_paso_1 := alterna_animacion
	var alterna_paso_2 := 1 if alterna_paso_1 == 2 else 2
	var celda_origen := pos_celda_act
	var celda_aterrizaje := celda_origen + Vector2i(dir) * 2
	_celda_destino = celda_aterrizaje
	# Tras un paso normal ya anunciado desde el mismo origen: los seguidores
	# ignoran el repetido porque ya van hacia esa celda.
	_anunciar_paso()
	var aterriza_en_hierba_muy_alta := _celda_tiene_hierba_mas_alta(Vector2(celda_aterrizaje))
	var mostrar_sombra := _debe_mostrar_sombra_salto(celda_origen, dir, 2)
	var transicion_entrada_hierba := TransicionHierba.NINGUNA
	var efecto_hierba_salto_iniciado := false
	var animacion_hierba_muy_alta_reproducida := false
	var offset_inicial = Vector2.ZERO
	if animated_sprite:
		offset_inicial = animated_sprite.offset
	sombra.visible = mostrar_sombra

	if aterriza_en_hierba_muy_alta:
		match dir:
			Vector2.UP:
				transicion_entrada_hierba = TransicionHierba.ENTRADA_ARRIBA
			Vector2.DOWN:
				transicion_entrada_hierba = TransicionHierba.ENTRADA_ABAJO
			Vector2.LEFT:
				transicion_entrada_hierba = TransicionHierba.ENTRADA_IZQUIERDA
			Vector2.RIGHT:
				transicion_entrada_hierba = TransicionHierba.ENTRADA_DERECHA

	while tiempo < duracion_salto:
		tiempo += get_process_delta_time()
		var t = tiempo / duracion_salto
		var pixeles_salto := clampf(t * float(Singleton.TILE_SIZE * 2), 0.0, float(Singleton.TILE_SIZE * 2))
		var y_offset := float(NpcBase.altura_salto_en_progreso(t))  # Tabla del decomp
		position.x = lerp(posicion_inicial.x, posicion_final.x, t)
		position.y = lerp(posicion_inicial.y, posicion_final.y, t)
		_actualizar_animacion_salto_parabolico(dir, pixeles_salto, alterna_paso_1, alterna_paso_2)
		if aterriza_en_hierba_muy_alta:
			var pixeles_en_celda_aterrizaje := clampf(pixeles_salto - float(Singleton.TILE_SIZE), 0.0, float(Singleton.TILE_SIZE))
			if pixeles_en_celda_aterrizaje > 8.0:
				if not efecto_hierba_salto_iniciado:
					transicion_hierba_activa = transicion_entrada_hierba
					_aplicar_efecto_hierba_muy_alta(true)
					efecto_hierba_salto_iniciado = true
				if not animacion_hierba_muy_alta_reproducida:
					_reproducir_animacion_hierba_muy_alta(celda_aterrizaje)
					animacion_hierba_muy_alta_reproducida = true
				_actualizar_shader_hierba_transicion(pixeles_en_celda_aterrizaje)
		if animated_sprite:
			animated_sprite.offset.y = offset_inicial.y + y_offset
		await get_tree().create_timer(get_process_delta_time()).timeout
	position = posicion_final
	if animated_sprite:
		animated_sprite.offset = offset_inicial
		animated_sprite.stop()
		animated_sprite.frame = 0
	sombra.visible = false
	_get_coord_tile_act()
	transicion_hierba_activa = TransicionHierba.ACTIVA if aterriza_en_hierba_muy_alta else TransicionHierba.NINGUNA
	actualizar_efecto_terreno_actual()
	levanta_polvo(celda_aterrizaje)
	_change_state(PlayerState.IDLE)

## =============================
## Movimientos especiales de bicicleta
## =============================

## ¿Puede el salto lateral (AcroBikeTransition_SideJump) caer en la celda vecina en `dir`?
## No modifica facing_direction ni el estado de juego. En Rubí usa la misma colisión que
## rodar (get_some_collision): agua, cascada, hierba muy alta, solo caminar, pendientes,
## NPCs... y además cualquier colisión, también una saliente, lo deja en un simple giro.
func _celda_lateral_es_accesible(dir: Vector2) -> bool:
	_get_coord_tile_act()
	var celda_dest := pos_celda_act + Vector2i(dir)
	var mapa_actual := _obtener_mapa_actual()
	if not _celda_esta_dentro_del_mapa(mapa_actual, celda_dest):
		return false
	var tp := _obtener_tp_capa_actual()
	if _celda_del_mapa_bloquea(tp, mapa_actual, celda_dest, dir, false):
		return false
	if tp == null:
		return true
	var cell_f := Vector2(celda_dest)
	# COLLISION_LEDGE_JUMP (6) < 10: el salto lateral no salta salientes, solo gira.
	if tp.get_flags(cell_f) & (TPTileDataMap.Flags.BORDE_ABAJO | TPTileDataMap.Flags.BORDE_ARRIBA \
			| TPTileDataMap.Flags.BORDE_IZQUIERDA | TPTileDataMap.Flags.BORDE_DERECHA):
		return false
	# Una puerta animada no se pisa: se entra mirándola con ARRIBA (map_warp_consider_2_to_inside).
	if nodo_administrador != null and mapa_actual != null and nodo_administrador.has_method("warp_en_celda"):
		var warp: Warp = nodo_administrador.warp_en_celda(mapa_actual, celda_dest)
		if warp != null and warp.es_puerta_animada():
			return false
	# Desde un tile BICI_DIR, el salto lateral solo está permitido si el destino tiene el mismo flag
	var flags_origen := tp.get_flags(Vector2(pos_celda_act))
	if flags_origen & TPTileDataMap.Flags.BICI_DIR_HORIZONTAL:
		if not tp.has_flag(cell_f, TPTileDataMap.Flags.BICI_DIR_HORIZONTAL):
			return false
	elif flags_origen & TPTileDataMap.Flags.BICI_DIR_VERTICAL:
		if not tp.has_flag(cell_f, TPTileDataMap.Flags.BICI_DIR_VERTICAL):
			return false
	return true

## Devuelve true si el tile actual tiene una restricción BICI_DIR que bloquea girar a input_dir.
func _bici_dir_bloquea_giro(input_dir: Vector2) -> bool:
	if not en_bicicleta:
		return false
	var tp := _obtener_tp_capa_actual()
	if tp == null:
		return false
	var cell := Vector2(pos_celda_act)
	if tp.has_flag(cell, TPTileDataMap.Flags.BICI_DIR_HORIZONTAL) and input_dir.x == 0:
		return true
	if tp.has_flag(cell, TPTileDataMap.Flags.BICI_DIR_VERTICAL) and input_dir.y == 0:
		return true
	return false

## Giro en U: salto parabólico en sitio, invierte dirección, emite sombra y polvo/onda.
## sin_wheelie=true: usa animación bici_ normal (rueda delantera no sube).
func _realizar_giro_u(sin_wheelie: bool = false) -> void:
	_change_state(PlayerState.JUMPING)
	const DURACION_GIRO_U := 0.30
	const ALTURA_GIRO_U := 10.0
	var prefix_anim := "bici_" if sin_wheelie else "wheelie_"
	var suffix_anim := "_1" if sin_wheelie else "_0"
	var offset_inicial := Vector2.ZERO
	if animated_sprite:
		offset_inicial = animated_sprite.offset
	# Mostrar frame de dirección actual
	var dir_old := _get_dir_string()
	var anim_old := prefix_anim + dir_old + suffix_anim
	if bicicleta and bicicleta.sprite_frames.has_animation(anim_old):
		bicicleta.play(anim_old)
		bicicleta.stop()
		bicicleta.frame = 0
	# Determinar si mostrar sombra (no en agua)
	_get_coord_tile_act()
	_celda_destino = pos_celda_act
	var mostrar_sombra := _debe_mostrar_sombra_salto(pos_celda_act, Vector2.ZERO, 0)
	sombra.visible = mostrar_sombra
	# Arco parabólico: la dirección se invierte en el ápice (t=0.5)
	var tiempo := 0.0
	var flipped := false
	while tiempo < DURACION_GIRO_U:
		tiempo += get_process_delta_time()
		var t := minf(tiempo / DURACION_GIRO_U, 1.0)
		var y_offset := 4.0 * ALTURA_GIRO_U * t * (t - 1.0)
		if animated_sprite:
			animated_sprite.offset.y = offset_inicial.y + y_offset
		# En el ápice del salto, invertir dirección y actualizar frame
		if not flipped and t >= 0.5:
			flipped = true
			facing_direction = -facing_direction
			var dir_new := _get_dir_string()
			var anim_new := prefix_anim + dir_new + suffix_anim
			if bicicleta and bicicleta.sprite_frames.has_animation(anim_new):
				bicicleta.play(anim_new)
				bicicleta.stop()
				bicicleta.frame = 0
		await get_tree().create_timer(get_process_delta_time()).timeout
	if animated_sprite:
		animated_sprite.offset = offset_inicial
	sombra.visible = false
	_get_coord_tile_act()
	# Polvo, salpicadura u onda en aterrizaje
	if _celda_tiene_agua_salpica(Vector2(pos_celda_act)):
		_efectos_agua.disparar_salpicadura()
		_intentar_onda_agua()
	else:
		levanta_polvo(pos_celda_act)
	_change_state(PlayerState.IDLE)
	_actualizar_animacion_idle()

## Salto lateral: avanza un tile en input_dir sin cambiar facing_direction.
## Emite polvo (o salpicadura/onda si cae en AGUA_SALPICA).
## sin_wheelie=true: fuerza animación bici_ normal durante el salto (rueda delantera no sube).
func _realizar_salto_lateral(input_dir: Vector2, sin_wheelie: bool = false) -> void:
	if not _celda_lateral_es_accesible(input_dir):
		# AcroBikeTransition_TurnDirection: con colisión solo se gira hacia ese lado
		# (salvo en un carril que no permite mirar así: CanBikeFaceDirOnMetatile).
		if not _bici_dir_bloquea_giro(input_dir):
			facing_direction = input_dir
			_actualizar_animacion_idle()
			_get_coord_tile_act()
		return
	_change_state(PlayerState.JUMPING)
	# Si se pide sin wheelie, asegurar que el sprite muestre bici_ normal
	if sin_wheelie and animated_sprite:
		_configurar_animacion_direccion("bici_", 0)
	var posicion_inicial := position
	var posicion_final := position + input_dir * Singleton.TILE_SIZE
	_marcar_celda_destino(input_dir)
	const DURACION_HOP := 0.22
	const ALTURA_HOP := 6.0
	var tiempo := 0.0
	var offset_inicial := Vector2.ZERO
	if animated_sprite:
		offset_inicial = animated_sprite.offset

	while tiempo < DURACION_HOP:
		tiempo += get_process_delta_time()
		var t := minf(tiempo / DURACION_HOP, 1.0)
		var y_offset := 4.0 * ALTURA_HOP * t * (t - 1.0)
		position = posicion_inicial.lerp(posicion_final, t)
		if animated_sprite:
			animated_sprite.offset.y = offset_inicial.y + y_offset
		await get_tree().create_timer(get_process_delta_time()).timeout

	position = posicion_final
	if animated_sprite:
		animated_sprite.offset = offset_inicial

	_get_coord_tile_act()
	# Efectos de aterrizaje (facing_direction no cambia)
	if _celda_tiene_agua_salpica(Vector2(pos_celda_act)):
		_efectos_agua.disparar_salpicadura()
		_intentar_onda_agua()
	else:
		levanta_polvo(pos_celda_act)
	_verificar_cambio_capa()
	_sincronizar_elevacion_punto()
	_change_state(PlayerState.IDLE)
	_actualizar_animacion_idle()

## La posición actual en este punto es la posición del tile final
func levanta_polvo(celda_efecto: Vector2i) -> void:
	# Si cae sobre la hierba, disparar animación nueva
	var animacion
	if _intentar_limpiar_ceniza(celda_efecto):
		pass  # La hierba con ceniza lanza sus propios efectos con retardo
	elif _celda_tiene_hierba_mas_alta(Vector2(celda_efecto)):
		pass  # La animación de hierba muy alta ya se disparó durante el salto, tampoco se levanta polvo normal
	elif _celda_tiene_hierba_alta(Vector2(celda_efecto)):
		_spawn_animacion_pasto(celda_efecto)
	else:
		animacion = Singleton.animacion_polvo.instantiate()
		animacion.set_meta(&"sin_reflejo", true)
		animacion.position += Vector2(0, -4)  # Ajuste para que el polvo salga de los pies
		add_child(animacion)

## Verifica si el jugador puede moverse en la dirección dada.
## Retorna true si puede moverse, false si hay un obstáculo.
func can_move(direction: Vector2) -> bool:

	# Cambio de dirección inmediato si ya está en movimiento (no bloquear inercia)
	if facing_direction != direction:
		facing_direction = direction
		# Solo retornar false si está parado - si está en movimiento, continuar con verificación
		if state == PlayerState.IDLE:
			return false

	# Mientras una roca de Fuerza se desliza el jugador espera, aunque la celda
	# que ella deja ya esté libre.
	if ControladorRocaFuerza.empuje_en_curso():
		return false

	# Comprobar salida del área en la celda actual
	_salida_activada = false
	if buscar_salida():
		_salida_activada = true
		return false

	# Sin administrador de mapas (escena standalone) no hay bloqueos de tile
	if nodo_administrador == null:
		return true

	var tp := _obtener_tp_capa_actual()

	# Determinar si la celda destino está dentro del mapa actual usando mapa_rect_px del MapaConfiguracion
	var mapa_actual := _obtener_mapa_actual()
	var dentro_de_mapa := _celda_esta_dentro_del_mapa(mapa_actual, pos_celda_sig)

	if dentro_de_mapa:
		if _celda_del_mapa_bloquea(tp, mapa_actual, pos_celda_sig, direction):
			return false
	else:
		# En interiores no se puede salir a otro mapa por los bordes (la escalera maneja la transición)
		if not nodo_administrador.enExterior:
			return false
		# Exterior: buscar geométricamente el mapa vecino en el Overworld
		var world_px: Vector2 = nodo_administrador.mapa_actual.posicion_en_mundo() + Vector2(pos_celda_sig) * Singleton.TILE_SIZE
		var nuevo_mapa: MapaConfiguracion = nodo_administrador.encontrar_mapa_en_posicion_mundo(world_px)
		if nuevo_mapa == null:
			return false

		# Coordenada local del tile en el mapa encontrado
		var local_tile := Vector2i(
				floor((world_px.x - nuevo_mapa.posicion_en_mundo().x) / Singleton.TILE_SIZE),
				floor((world_px.y - nuevo_mapa.posicion_en_mundo().y) / Singleton.TILE_SIZE))

		var puede_avanzar: bool = _validar_celda_destino_en_mapa(nuevo_mapa, local_tile, direction, Singleton.capa_activa)
		if puede_avanzar:
			# La celda de llegada decide el clima por zona de entrada del mapa nuevo.
			nodo_administrador.set_mapa_actual(nuevo_mapa, local_tile)
			return true
		return false
	return true

## ¿La celda `celda_dest` del mapa actual (vecina de pos_celda_act en `direction`) impide
## entrar con el estado actual? Banderas del TPTileDataMap, NPCs y puertas giratorias; sin
## efectos secundarios. La usan el paso normal (can_move) y el salto lateral de la bici
## acrobática, que en Rubí comparten colisión (get_some_collision). `mirar_carril_origen`:
## el salto lateral tiene su propia regla para salir de un carril BICI_DIR.
func _celda_del_mapa_bloquea(tp: TPTileDataMap, mapa_actual: MapaConfiguracion, celda_dest: Vector2i, direction: Vector2, mirar_carril_origen: bool = true) -> bool:
	var cell_f := Vector2(celda_dest)
	# Una puerta con llave es pared aunque su tile sea transitable.
	if nodo_administrador != null and nodo_administrador.has_method("warp_en_celda"):
		var warp: Warp = nodo_administrador.warp_en_celda(mapa_actual, celda_dest)
		if warp != null and warp.con_llave:
			return true
	# TPTileDataMap es la única fuente de verdad para bloqueos.
	if tp != null:
		var celda_actual := Vector2(pos_celda_act)
		var bloqueo_dir := _obtener_flag_bloqueo_direccional(direction)
		if bloqueo_dir != 0 and tp.has_flag(celda_actual, bloqueo_dir):
			return true
		# Bloqueo declarado solo en el tile de destino (p. ej. BLOQUEO_ABAJO al subir).
		var bloqueo_entrada := _obtener_flag_bloqueo_direccional(-direction)
		if bloqueo_entrada != 0 and tp.has_flag(cell_f, bloqueo_entrada):
			return true
		if tp.has_flag(cell_f, TPTileDataMap.Flags.BLOQUEO):
			return true
		# SURF: solo accesible en estado surf
		if not en_surf and tp.has_flag(cell_f, TPTileDataMap.Flags.SURF):
			return true
		# CASCADA: se entra surfeando (y te empuja hacia abajo); a pie no
		if not en_surf and tp.has_flag(cell_f, TPTileDataMap.Flags.CASCADA):
			return true
		# HIERBA_MAS_ALTA: bloqueada en bicicleta
		if en_bicicleta and tp.has_flag(cell_f, TPTileDataMap.Flags.HIERBA_MAS_ALTA):
			return true
		# SOLO_CAMINAR: bloqueado en bicicleta
		if en_bicicleta and tp.has_flag(cell_f, TPTileDataMap.Flags.SOLO_CAMINAR):
			return true
		# PENDIENTE_ACROBATICA: solo se entra con los saltitos de la bici acrobática
		if tp.has_flag(cell_f, TPTileDataMap.Flags.PENDIENTE_ACROBATICA) and not _puede_entrar_en_pendiente():
			return true
		# BICI_DIR: requiere bicicleta para entrar
		if not en_bicicleta and (tp.has_flag(cell_f, TPTileDataMap.Flags.BICI_DIR_HORIZONTAL) or \
				tp.has_flag(cell_f, TPTileDataMap.Flags.BICI_DIR_VERTICAL)):
			return true
		# Tile actual BICI_DIR: bloquear movimiento en el eje no permitido
		if mirar_carril_origen:
			var flags_actuales := tp.get_flags(celda_actual)
			if (flags_actuales & TPTileDataMap.Flags.BICI_DIR_HORIZONTAL) and direction.x == 0:
				return true
			if (flags_actuales & TPTileDataMap.Flags.BICI_DIR_VERTICAL) and direction.y == 0:
				return true
		# Bordes direccionales: solo permiten paso en su dirección
		const MASK_BORDES := TPTileDataMap.Flags.BORDE_ABAJO | TPTileDataMap.Flags.BORDE_ARRIBA | \
							 TPTileDataMap.Flags.BORDE_IZQUIERDA | TPTileDataMap.Flags.BORDE_DERECHA
		if tp.get_flags(cell_f) & MASK_BORDES:
			var borde_dir := _obtener_flag_borde_direccional(direction)
			if not tp.has_flag(cell_f, borde_dir):
				return true
			# El tile tiene el borde correcto (sería un salto), pero si el tile de
			# aterrizaje (C, 2 tiles) es inaccesible para el estado actual, el
			# tile del borde también debe ser bloqueante.
			if not _debe_realizar_salto_borde(direction):
				return true
	# Validar colisiones con NPCs. Un acompañante que sigue al jugador no
	# bloquea: se intercambian (él entra en la celda que el jugador deja).
	var npc_delante = _ocupante_bloqueante(celda_dest)
	if npc_delante and not _es_acompanante(npc_delante):
		return true
	# Puertas giratorias (CheckForRotatingGatePuzzleCollision): un brazo que
	# no puede girar bloquea el paso a traves de su arista.
	var puertas := mapa_actual.obtener_puertas_giratorias() if mapa_actual != null else null
	if puertas != null and puertas.bloquea_paso(tp, celda_dest, direction):
		return true
	return false

## Valida si la celda destino en el mapa al que se va a cambiar permite el acceso
func _validar_celda_destino_en_mapa(mapa_destino: MapaConfiguracion, celda_destino: Vector2i, direction: Vector2, layer_id: int) -> bool:
	if not mapa_destino:
		return false

	# Verificar bloqueo y bordes con TPTileDataMap
	var tp := _obtener_tp_de_mapa(mapa_destino, layer_id)
	if tp != null:
		var cell_f := Vector2(celda_destino)
		if tp.has_flag(cell_f, TPTileDataMap.Flags.BLOQUEO):
			return false
		# SURF: solo accesible en estado surf (igual que dentro de un mapa)
		if not en_surf and tp.has_flag(cell_f, TPTileDataMap.Flags.SURF):
			return false
		if not en_surf and tp.has_flag(cell_f, TPTileDataMap.Flags.CASCADA):
			return false
		if tp.has_flag(cell_f, TPTileDataMap.Flags.PENDIENTE_ACROBATICA) and not _puede_entrar_en_pendiente():
			return false
		const MASK_BORDES := TPTileDataMap.Flags.BORDE_ABAJO | TPTileDataMap.Flags.BORDE_ARRIBA | \
							 TPTileDataMap.Flags.BORDE_IZQUIERDA | TPTileDataMap.Flags.BORDE_DERECHA
		if tp.get_flags(cell_f) & MASK_BORDES:
			var borde_dir := 0
			match direction:
				Vector2.DOWN:  borde_dir = TPTileDataMap.Flags.BORDE_ABAJO
				Vector2.UP:    borde_dir = TPTileDataMap.Flags.BORDE_ARRIBA
				Vector2.LEFT:  borde_dir = TPTileDataMap.Flags.BORDE_IZQUIERDA
				Vector2.RIGHT: borde_dir = TPTileDataMap.Flags.BORDE_DERECHA
			if not tp.has_flag(cell_f, borde_dir):
				return false
	return true

func _obtener_flag_bloqueo_direccional(direction: Vector2) -> int:
	match direction:
		Vector2.UP:
			return TPTileDataMap.Flags.BLOQUEO_ARRIBA
		Vector2.DOWN:
			return TPTileDataMap.Flags.BLOQUEO_ABAJO
		Vector2.LEFT:
			return TPTileDataMap.Flags.BLOQUEO_IZQUIERDA
		Vector2.RIGHT:
			return TPTileDataMap.Flags.BLOQUEO_DERECHA
		_:
			return 0

func _obtener_flag_borde_direccional(direction: Vector2) -> int:
	match direction:
		Vector2.UP:
			return TPTileDataMap.Flags.BORDE_ARRIBA
		Vector2.DOWN:
			return TPTileDataMap.Flags.BORDE_ABAJO
		Vector2.LEFT:
			return TPTileDataMap.Flags.BORDE_IZQUIERDA
		Vector2.RIGHT:
			return TPTileDataMap.Flags.BORDE_DERECHA
		_:
			return 0

func _debe_realizar_salto_borde(direction: Vector2) -> bool:
	if direction == Vector2.ZERO:
		return false
	var tp := _obtener_tp_capa_actual()
	if tp == null:
		return false
	_get_coord_tile_act()
	var borde_dir := _obtener_flag_borde_direccional(direction)
	if borde_dir == 0:
		return false
	# El tile inmediato (B) debe tener el flag BORDE en la dirección del movimiento
	var celda_borde := Vector2(pos_celda_act + Vector2i(direction))
	if not tp.has_flag(celda_borde, borde_dir):
		return false
	# Validar que el tile de aterrizaje (C, 2 tiles adelante) es accesible con el estado actual
	var celda_aterrizaje := Vector2i(pos_celda_act + Vector2i(direction) * 2)
	var mapa_actual := _obtener_mapa_actual()
	if not _celda_esta_dentro_del_mapa(mapa_actual, celda_aterrizaje):
		return false
	var cell_f := Vector2(celda_aterrizaje)
	if tp.has_flag(cell_f, TPTileDataMap.Flags.BLOQUEO):
		return false
	# Agua profunda: solo accesible con Surf
	if not en_surf and tp.has_flag(cell_f, TPTileDataMap.Flags.SURF):
		return false
	# Una pendiente acrobática solo admite los saltitos del wheelie, no el salto de saliente
	# a pie ni en otra bici (en modo salto sí se puede aterrizar encima)
	if tp.has_flag(cell_f, TPTileDataMap.Flags.PENDIENTE_ACROBATICA) and not _puede_entrar_en_pendiente():
		return false
	# En bicicleta no se puede aterrizar en hierba muy alta ni en zonas solo-caminar
	if en_bicicleta and tp.has_flag(cell_f, TPTileDataMap.Flags.HIERBA_MAS_ALTA):
		return false
	if en_bicicleta and tp.has_flag(cell_f, TPTileDataMap.Flags.SOLO_CAMINAR):
		return false
	# Tiles de carril bici solo son accesibles montando en bici
	if not en_bicicleta and (tp.has_flag(cell_f, TPTileDataMap.Flags.BICI_DIR_HORIZONTAL) \
			or tp.has_flag(cell_f, TPTileDataMap.Flags.BICI_DIR_VERTICAL)):
		return false
	# NPCs y objetos con colisión (rocas, bayas, objetos del suelo): se compara con
	# su coord_celda actual, no con la posición con la que se cargó el mapa, así que
	# un NPC que paseó hasta la celda de aterrizaje también bloquea el salto.
	if nodo_administrador != null:
		var ocupante: Node2D = _ocupante_bloqueante(celda_aterrizaje)
		if ocupante != null and not _es_acompanante(ocupante):
			return false
	return true

## Funciones relacionadas con efectos de terreno (hierba alta, animaciones, etc.)
## Se llama desde:
## 1) _ready (defered): para aplicar el efecto de la celda inicial
## 2) _finalizar_paso: para actualizar según la nueva celda.
## 3) realizar_salto_parabolico: al finalizar el salto para actualizar según la nueva celda.
## 4) teletransporte: para actualizar según la nueva celda.
func actualizar_efecto_terreno_actual() -> void:
	_get_coord_tile_act()
	var tiene_hierba_muy_alta = _celda_tiene_hierba_mas_alta(Vector2(pos_celda_act))
	if tiene_hierba_muy_alta && !hierba_muy_alta_activa:
		transicion_hierba_activa = TransicionHierba.ACTIVA
		_aplicar_efecto_hierba_muy_alta(tiene_hierba_muy_alta)
	elif !tiene_hierba_muy_alta && hierba_muy_alta_activa:
		transicion_hierba_activa = TransicionHierba.NINGUNA
		_desactivar_efecto_hierba_muy_alta()
	if _sumersion_termal:
		_sumersion_termal.actualizar_reposo(_obtener_tp_capa_actual(), pos_celda_act)
	if _efectos_arena:
		if en_surf:
			_efectos_arena.ocultar()
		else:
			_efectos_arena.actualizar_reposo(_obtener_tp_capa_actual(), pos_celda_act)
	if _tierra_pies:
		if en_surf:
			_tierra_pies.ocultar()
		else:
			_tierra_pies.actualizar_reposo(_obtener_tp_capa_actual(), pos_celda_act)
		_aplicar_tierra_pies()
	# Agua de los pies (AGUA_PIES): se repite mientras se esté quieto sobre el charco.
	if _efectos_agua:
		if en_surf or state == PlayerState.JUMPING:
			_efectos_agua.ocultar()
		else:
			_efectos_agua.actualizar_reposo(Vector2(pos_celda_act))

## Llamado por DisparadorTierraPies cuando el jugador entra o sale de su zona
## (quieto sobre ella, o en la mitad del paso que entra o sale). La bandera
## TIERRA_PIES del TPTileDataMap actúa por su cuenta (TierraPies.sobre_bandera).
func mostrar_tierra_pies(mostrar: bool) -> void:
	_tierra_pies_solicitada = mostrar
	_aplicar_tierra_pies()

## Como la arena, la tierra no acompaña al jugador en el aire ni en surf.
func _aplicar_tierra_pies() -> void:
	if _tierra_pies == null:
		return
	_tierra_pies.visible = (_tierra_pies_solicitada or _tierra_pies.sobre_bandera) 		and not en_surf and state != PlayerState.JUMPING

## Salpicadura y ondas solo a ras de agua (EfectosAgua): sobre un puente (capa
## de datos >= 1 o celda con bandera PUENTE_*) nunca se disparan.
func _celda_tiene_agua_salpica(cell: Vector2) -> bool:
	return _efectos_agua != null and _efectos_agua.celda_tiene_agua_salpica(cell)

## Se llama en cada paso: dos ondas (la segunda a los 0.5 s) si la celda actual
## es AGUA_SALPICA; sin capa de datos o sin mapa (transiciones) no hay ondas.
func _intentar_onda_agua() -> void:
	if _efectos_agua:
		_efectos_agua.intentar_ondas(Vector2(pos_celda_act), global_position)

func _celda_tiene_hierba_alta(cell: Vector2) -> bool:
	var tp := _obtener_tp_capa_actual()
	if tp == null:
		return false
	return tp.has_flag(cell, TPTileDataMap.Flags.HIERBA_ALTA)

func _celda_tiene_animacion_pasto(cell: Vector2) -> bool:
	var tp := _obtener_tp_capa_actual()
	if tp == null:
		return false
	return tp.has_flag(cell, TPTileDataMap.Flags.HIERBA_ALTA) \
		or tp.has_flag(cell, TPTileDataMap.Flags.HIERBA_MAS_ALTA)

func _celda_tiene_hierba_mas_alta(cell: Vector2) -> bool:
	var tp := _obtener_tp_capa_actual()
	if tp == null:
		return false
	return tp.has_flag(cell, TPTileDataMap.Flags.HIERBA_MAS_ALTA)

## Hierba con ceniza (Ruta 113): si `celda` la tiene sin limpiar, el componente
## del mapa la limpia y devuelve true. Solo el jugador limpia ceniza.
func _intentar_limpiar_ceniza(celda: Vector2i) -> bool:
	if not is_in_group(&"Personaje"):
		return false
	var mapa := _obtener_mapa_actual()
	if mapa == null:
		return false
	var hierba := mapa.obtener_hierba_ceniza()
	return hierba != null and hierba.intentar_limpiar(celda)

func _spawn_animacion_pasto(cell: Vector2i) -> void:
	if nodo_administrador == null or nodo_administrador.mapa_actual == null:
		return
	var animacion = Singleton.animacion_pisar_pasto.instantiate()
	animaciones_pisar_pasto.append(animacion)
	var nodo_npcs_hierba = nodo_administrador.mapa_actual.get_node_or_null("NPCs")
	if nodo_npcs_hierba:
		animacion.position = Vector2(cell) * Singleton.TILE_SIZE + Vector2(8.0, 15.0)
		nodo_npcs_hierba.add_child(animacion)
	else:
		animacion.position = Vector2(cell) * Singleton.TILE_SIZE + nodo_administrador.mapa_actual.posicion_en_mundo() + Vector2(8.0, 15.0)
		nodo_administrador.add_child(animacion)

## GroundEffect_Seaweed (OnFinishStep): burbujas al acabar un paso sobre ALGA.
func _intentar_burbujas_alga() -> void:
	if nodo_administrador == null or nodo_administrador.mapa_actual == null:
		return
	# Como el pasto pisado: en el nodo NPCs del mapa (o en el mapa si no lo hay),
	# cuyas coordenadas locales son las del mapa.
	var mapa: MapaConfiguracion = nodo_administrador.mapa_actual
	var contenedor: Node = mapa.get_node_or_null("NPCs")
	if contenedor == null:
		contenedor = mapa
	BurbujasAlga.crear_si_alga(_obtener_tp_capa_actual(), pos_celda_act, contenedor)

## Determina el modo de transición de hierba para el paso que va a comenzar.
## Fija transicion_hierba_activa y retorna true si alguna de las dos celdas tiene hierba muy alta.
func _evaluar_transicion_hierba(input_dir: Vector2) -> bool:
	var celda_act := _celda_tiene_hierba_mas_alta(Vector2(pos_celda_act))
	var celda_sig := _celda_tiene_hierba_mas_alta(Vector2(pos_celda_sig))
	if not celda_act and celda_sig:			# Entrando
		match input_dir:
			Vector2.UP:    transicion_hierba_activa = TransicionHierba.ENTRADA_ARRIBA
			Vector2.DOWN:  transicion_hierba_activa = TransicionHierba.ENTRADA_ABAJO
			Vector2.LEFT:  transicion_hierba_activa = TransicionHierba.ENTRADA_IZQUIERDA
			Vector2.RIGHT: transicion_hierba_activa = TransicionHierba.ENTRADA_DERECHA
			_:             transicion_hierba_activa = TransicionHierba.NINGUNA
	elif celda_act and not celda_sig:		# Saliendo
		match input_dir:
			Vector2.UP:    transicion_hierba_activa = TransicionHierba.SALIDA_ARRIBA
			Vector2.DOWN:  transicion_hierba_activa = TransicionHierba.SALIDA_ABAJO
			Vector2.LEFT:  transicion_hierba_activa = TransicionHierba.SALIDA_IZQUIERDA
			Vector2.RIGHT: transicion_hierba_activa = TransicionHierba.SALIDA_DERECHA
			_:             transicion_hierba_activa = TransicionHierba.NINGUNA
	elif celda_act and celda_sig:			# Dentro
		transicion_hierba_activa = TransicionHierba.ACTIVA
	else:
		transicion_hierba_activa = TransicionHierba.NINGUNA
	return celda_act or celda_sig


## (2) Actualiza los parámetros de clip lateral y vertical del shader durante el paso de entrada.
## Se llama cada frame desde _procesar_movimiento (desde _process) con los píxeles avanzados (0..16).
func _actualizar_shader_hierba_transicion(pixeles: float) -> void:
	if material_hierba_muy_alta == null:
		return
	match transicion_hierba_activa:		# Entrado mirando hacia ...
		TransicionHierba.ENTRADA_ARRIBA:
			# El shader se desactiva cuando se avanzan 4 px (quedan 12 para terminar el paso).
			if pixeles >= 4.0:
				material_hierba_muy_alta.set_shader_parameter("recortar_sprite", true)
		TransicionHierba.ENTRADA_ABAJO:
			# El clip_local_y sube progresivamente de 2 a -14 según los px avanzados.
			var t := clampf(pixeles / 16.0, 0.0, 1.0)
			var y_clip := lerpf(2.0, -14.0, t)
			material_hierba_muy_alta.set_shader_parameter("clip_local_y", y_clip)
		TransicionHierba.ENTRADA_IZQUIERDA:
			var t_der := clampf(pixeles / 16.0, 0.0, 1.0)
			var x_der := lerpf(-8.0, 8.0, t_der)
			material_hierba_muy_alta.set_shader_parameter("clip_local_x_der", x_der)
		TransicionHierba.ENTRADA_DERECHA:
			var t_izq := clampf(pixeles / 16.0, 0.0, 1.0)
			var x_izq := lerpf(8.0, -8.0, t_izq)
			material_hierba_muy_alta.set_shader_parameter("clip_local_x_izq", x_izq)
		TransicionHierba.SALIDA_ARRIBA:
			var t := clampf(pixeles / 16.0, 0.0, 1.0)
			var y_clip := lerpf(-14.0, 2.0, t)
			material_hierba_muy_alta.set_shader_parameter("clip_local_y", y_clip)
		TransicionHierba.SALIDA_ABAJO:
			# El shader se desactiva cuando se avanzan 12 px (quedan 4 para terminar el paso).
			if pixeles >= 12.0:
				material_hierba_muy_alta.set_shader_parameter("recortar_sprite", false)
		TransicionHierba.SALIDA_IZQUIERDA:
			var t := clampf(pixeles / 16.0, 0.0, 1.0)
			var x_izq := lerpf(-8.0, 8.0, t)
			material_hierba_muy_alta.set_shader_parameter("clip_local_x_izq", x_izq)
		TransicionHierba.SALIDA_DERECHA:
			var t := clampf(pixeles / 16.0, 0.0, 1.0)
			var x_der := lerpf(8.0, -8.0, t)
			material_hierba_muy_alta.set_shader_parameter("clip_local_x_der", x_der)

## (1) Activa o desactiva el efecto de recorte del shader para hierba muy alta según la celda actual.
func _aplicar_efecto_hierba_muy_alta(activa: bool) -> void:
	hierba_muy_alta_activa = activa
	if material_hierba_muy_alta != null:
		if activa:
			# Configuración inicial del shader para recorte de hierba muy alta (se irá actualizando dinámicamente en _actualizar_shader_hierba_transicion durante el paso de entrada).
			match transicion_hierba_activa:
				TransicionHierba.ENTRADA_ARRIBA:
					# Límites fijos: y=-14, x_izq=-8, x_der=8.
					material_hierba_muy_alta.set_shader_parameter("recortar_sprite", false)
					material_hierba_muy_alta.set_shader_parameter("clip_local_y", -14.0)
					material_hierba_muy_alta.set_shader_parameter("clip_local_x_izq", -8.0)
					material_hierba_muy_alta.set_shader_parameter("clip_local_x_der", 8.0)
				TransicionHierba.ENTRADA_ABAJO:
					# x_izq y x_der son fijos en -8 y 8 desde el primer píxel.
					material_hierba_muy_alta.set_shader_parameter("recortar_sprite", true)
					material_hierba_muy_alta.set_shader_parameter("clip_local_y", 2.0)
					material_hierba_muy_alta.set_shader_parameter("clip_local_x_izq", -8.0)
					material_hierba_muy_alta.set_shader_parameter("clip_local_x_der", 8.0)
				TransicionHierba.ENTRADA_IZQUIERDA:
					material_hierba_muy_alta.set_shader_parameter("recortar_sprite", true)
					material_hierba_muy_alta.set_shader_parameter("clip_local_y", -14.0)
					material_hierba_muy_alta.set_shader_parameter("clip_local_x_izq", -8.0)
					material_hierba_muy_alta.set_shader_parameter("clip_local_x_der", -8.0)
				TransicionHierba.ENTRADA_DERECHA:
					material_hierba_muy_alta.set_shader_parameter("recortar_sprite", true)
					material_hierba_muy_alta.set_shader_parameter("clip_local_y", -14.0)
					material_hierba_muy_alta.set_shader_parameter("clip_local_x_izq", 8.0)
					material_hierba_muy_alta.set_shader_parameter("clip_local_x_der", 8.0)
				TransicionHierba.NINGUNA:
					material_hierba_muy_alta.set_shader_parameter("recortar_sprite", false)
					material_hierba_muy_alta.set_shader_parameter("clip_local_y", 2.0)
				TransicionHierba.ACTIVA:
					material_hierba_muy_alta.set_shader_parameter("recortar_sprite", true)
					material_hierba_muy_alta.set_shader_parameter("clip_local_y", -14.0)
					material_hierba_muy_alta.set_shader_parameter("clip_local_x_izq", -8.0)
					material_hierba_muy_alta.set_shader_parameter("clip_local_x_der", 8.0)
	if not activa:
		_desactivar_efecto_hierba_muy_alta()

## (3) Desactiva el efecto de recorte del shader de hierba muy alta (se llama al salir de la escena o al desactivar el efecto).
func _desactivar_efecto_hierba_muy_alta() -> void:
	hierba_muy_alta_activa = false
	if material_hierba_muy_alta != null:
		material_hierba_muy_alta.set_shader_parameter("recortar_sprite", false)
		# Cuando se vuelva a activar, que no se note el recorte vertical residual del paso anterior, reseteamos clip_local_y al valor por defecto (2.0) para que el sprite se muestre completo.
		material_hierba_muy_alta.set_shader_parameter("clip_local_y", 2.0)

## Animación de hierba muy alta: se instancia un AnimatedSprite2D temporal sobre la celda destino con la animación de pisar hierba.
## La animación se encarga de eliminarse a sí misma al terminar.
func _reproducir_animacion_hierba_muy_alta(cell: Vector2i) -> void:
	if nodo_administrador == null or nodo_administrador.mapa_actual == null:
		return

	var animacion := AnimatedSprite2D.new()
	animacion.name = "HierbaMuyAltaAnim"
	animacion.centered = false
	# animacion.z_index = animated_sprite.z_index + 1 if animated_sprite != null else 1
	animacion.z_index = animated_sprite.z_index if animated_sprite != null else 0
	animacion.sprite_frames = HIERBA_MUY_ALTA_FRAMES
	animacion.animation = &"default"
	animacion.animation_finished.connect(func(): animacion.queue_free(), CONNECT_ONE_SHOT)

	var nodo_npcs_hierba = nodo_administrador.mapa_actual.get_node_or_null("NPCs")
	if nodo_npcs_hierba:
		animacion.position = Vector2(cell) * Singleton.TILE_SIZE
		nodo_npcs_hierba.add_child(animacion)

	animacion.play(&"default")

## Obtiene el nodo TPTileDataMap de un mapa, buscando en sus hijos directos.
func _obtener_mapa_actual() -> MapaConfiguracion:
	if nodo_administrador == null:
		return null
	return nodo_administrador.mapa_actual

func _obtener_tp_de_mapa(mapa: MapaConfiguracion, layer_id: int) -> TPTileDataMap:
	if mapa == null:
		return null
	return mapa.get_capa_resuelta(layer_id)

## Convierte una celda local de `mapa_origen` a coordenadas del mapa actual
## (idéntica si no hubo cambio de mapa).
func _celda_en_mapa_actual(celda: Vector2i, mapa_origen: MapaConfiguracion) -> Vector2i:
	var mapa := _obtener_mapa_actual()
	if mapa == null or mapa_origen == null or mapa == mapa_origen:
		return celda
	return celda + Vector2i(((mapa_origen.posicion_en_mundo() - mapa.posicion_en_mundo()) / float(Singleton.TILE_SIZE)).round())

func _obtener_tp_capa_actual() -> TPTileDataMap:
	return _obtener_tp_de_mapa(_obtener_mapa_actual(), Singleton.capa_activa)

func obtener_tp_capa_actual() -> TPTileDataMap:
	return _obtener_tp_capa_actual()

func _celda_esta_dentro_del_mapa(mapa: MapaConfiguracion, celda: Vector2i) -> bool:
	if mapa == null or mapa.mapa_rect_px == Rect2():
		return mapa != null and mapa.esInterior
	return mapa.mapa_rect_px.has_point(Vector2(celda) * Singleton.TILE_SIZE)

func buscar_salida(_modo:String = "") -> bool:
	var mapa_actual := _obtener_mapa_actual()
	if mapa_actual == null:
		return false
	var salida = null

	for area in get_tree().get_nodes_in_group("Salidas"):
		if not mapa_actual.is_ancestor_of(area):
			continue
		var celda_puerta = mapa_actual.global_to_map_cell(area.global_position)
		if pos_celda_act == celda_puerta:
			salida = area
			break

	if salida:
		print("Salida encontrada")
		if facing_direction == salida.direccion_salida():
			salida.salida()
			return true
	else:
		pass
		# print("No hay salida en la celda actual")
	return false

func buscar_puerta(_modo:String = ""):
	var mapa_actual := _obtener_mapa_actual()
	if mapa_actual == null:
		return
	var puerta = null

	var nodos_puertas = get_tree().get_nodes_in_group("Puertas")
	for area in nodos_puertas:
		if mapa_actual == null or not mapa_actual.is_ancestor_of(area):
			continue
		var celda_puerta = mapa_actual.global_to_map_cell(area.global_position)
		if pos_celda_sig == celda_puerta:
			puerta = area
			break

	if puerta:
		print("Puerta encontrada")
		no_control = true
		puerta.abrir_puerta()
	else:
		pass
		# print("No hay puerta en la celda siguiente")

## `direccion` Vector2.ZERO conserva la dirección actual (escaleras de Rubí).
func teletransporte(posicion:Vector2, direccion:Vector2, dar_paso: bool = false, bloqueo_temporal: bool = true):
	global_position = posicion
	var cambia_direccion: bool = direccion != Vector2.ZERO and direccion != facing_direction
	if direccion != Vector2.ZERO:
		facing_direction = direccion
	_get_coord_tile_act()
	_sincronizar_elevacion_punto()
	# Sin refrescar el sprite, un warp que cambia de dirección (el guion de la barca
	# del SR. ARENQUE deja al jugador de cara a abajo tras subir) lo dejaría mirando
	# a la dirección anterior hasta el siguiente paso.
	if cambia_direccion and not paso_en_curso:
		_actualizar_animacion_idle()
	_celda_llegada_warp = _celda_global()
	_en_celda_llegada_warp = true
	_ultimo_paso_mapa = null  # no hay paso que lleve a la celda de llegada
	actualizar_efecto_terreno_actual()
	_logger("teletransporte a %s direccion %s (dar paso: %s)" % [posicion, direccion, dar_paso])
	if bloqueo_temporal:
		no_controlar(0.5)
	if dar_paso:
		move_to_next_tile(facing_direction)
		_logger("moviendo a la siguiente celda en direccion %s" % [facing_direction])

## Bloquea el control del jugador durante un tiempo
func no_controlar(tiempo:float):
	if no_control == false:
		no_control = true
	await get_tree().create_timer(tiempo).timeout
	no_control = false
	if state == PlayerState.LOCKED:
		_change_state(PlayerState.IDLE)

## =============================
## API Pública
## =============================

## true mientras el jugador está entre dos celdas (paso, salto o giro en bici).
func esta_en_movimiento() -> bool:
	return paso_en_curso or state == PlayerState.JUMPING

## Celda que el jugador ocupa a efectos de lógica (PlayerGetDestCoords de pokeruby):
## desde que empieza un paso o salto es la celda de llegada, mientras que
## pos_celda_act sigue siendo la de salida hasta terminar el movimiento.
func obtener_celda_destino() -> Vector2i:
	return _celda_destino if esta_en_movimiento() else pos_celda_act

func _marcar_celda_destino(direccion: Vector2) -> void:
	_get_coord_tile_act()
	_celda_destino = pos_celda_act + Vector2i(direccion)
	_paso_bici_velocidad_maxima = false  # saltos y giros: nunca a máxima velocidad
	_anunciar_paso()

## Emite paso_iniciado si el movimiento que empieza cambia de celda. Llamar con
## pos_celda_act aún en la celda de salida y _celda_destino ya calculada.
## `mapa_origen`: mapa en el que empezó el paso si pudo cruzar un borde (ver
## _iniciar_paso_manual); null = el mapa actual.
func _anunciar_paso(mapa_origen: MapaConfiguracion = null) -> void:
	_elevar_si_destino_elevado(_celda_en_mapa_actual(_celda_destino, mapa_origen))
	if _celda_destino != pos_celda_act:
		paso_iniciado.emit(pos_celda_act, _celda_destino)
		_procesar_tiles_pisados(pos_celda_act, _celda_destino)
		_registrar_entrada_exterior(pos_celda_act, _celda_destino, mapa_origen)

## Último paso del jugador en celdas locales de `_ultimo_paso_mapa` (respaldo
## de la entrada exterior para Warp.salida()).
var _ultimo_paso_origen := Vector2i.ZERO
var _ultimo_paso_destino := Vector2i.ZERO
var _ultimo_paso_mapa: MapaConfiguracion = null

## Entrada exterior (warp4 de pokeruby): al empezar un paso del jugador hacia un
## warp de un mapa del Overworld que lleva a un interior, el administrador guarda
## la celda de salida del paso. Las celdas pasan a coordenadas del mapa actual
## por si el paso cruzó un borde.
func _registrar_entrada_exterior(origen: Vector2i, destino: Vector2i, mapa_origen: MapaConfiguracion) -> void:
	if not is_in_group(&"Personaje") or nodo_administrador == null:
		return
	var mapa := _obtener_mapa_actual()
	_ultimo_paso_origen = _celda_en_mapa_actual(origen, mapa_origen)
	_ultimo_paso_destino = _celda_en_mapa_actual(destino, mapa_origen)
	_ultimo_paso_mapa = mapa
	if nodo_administrador.has_method("registrar_entrada_exterior"):
		nodo_administrador.registrar_entrada_exterior(_ultimo_paso_origen, _ultimo_paso_destino)

## Respaldo de Warp.salida() (SALIDAS se activan pulsando la dirección encima del
## warp, sin paso): si el último paso del jugador terminó en la celda de `warp`
## dentro del mapa actual, se registra su celda de salida. Si llegó a la celda
## por otro warp no hay paso válido y se conserva la entrada anterior.
func registrar_entrada_exterior_por_salida(warp: Node2D) -> void:
	var mapa := _obtener_mapa_actual()
	if mapa == null or warp == null or _ultimo_paso_mapa != mapa or nodo_administrador == null:
		return
	if mapa.global_to_map_cell(warp.global_position) != _ultimo_paso_destino:
		return
	if nodo_administrador.has_method("registrar_entrada_exterior"):
		nodo_administrador.registrar_entrada_exterior(_ultimo_paso_origen, _ultimo_paso_destino)

## Arranque/F6/CONTINUAR en una escalera no equivale a pisarla. Solo el último
## paso acabado puede activar un perfil automático del Centro Pokémon.
func llego_caminando_a_warp(mapa: Node, celda: Vector2i) -> bool:
	return not paso_en_curso and not _en_celda_llegada_warp and _ultimo_paso_mapa == mapa \
		and _ultimo_paso_destino == celda

## Tiles que reaccionan al pisarlos (PuenteMaderaMapa, CuestaBarroMapa,
## SueloAgrietadoMapa). Solo el jugador.
func _procesar_tiles_pisados(origen: Vector2i, destino: Vector2i) -> void:
	if not is_in_group(&"Personaje"):
		return
	var mapa := _obtener_mapa_actual()
	if mapa == null:
		return
	var tp := _obtener_tp_capa_actual()
	var puente := mapa.obtener_puente_madera()
	if puente != null:
		puente.procesar_paso(tp, origen, destino)
	var cuesta := mapa.obtener_cuesta_barro()
	if cuesta != null:
		cuesta.procesar_paso(tp, destino)
	# Empujar un brazo de una puerta giratoria la hace girar (suena al empezar el paso).
	var puertas := mapa.obtener_puertas_giratorias()
	if puertas != null:
		puertas.procesar_paso(tp, origen, destino, duracion_paso < PuertasGiratoriasMapa.DURACION_PASO_RAPIDO_MAX)
	_celda_salvada_por_velocidad = null
	var suelo := mapa.obtener_suelo_agrietado()
	if suelo != null and suelo.procesar_paso(tp, destino) and _paso_bici_velocidad_maxima:
		_celda_salvada_por_velocidad = destino

## ¿`npc` sigue al jugador (npc_base.seguir_a)?
func _es_acompanante(npc: Node) -> bool:
	return "lider" in npc and npc.lider == self

## Objeto del mapa que impide pisar `celda` (NPC, roca, baya, objeto del suelo).
## Los objetos ocultos (bg_hidden_item_event) no cuentan: se pisan y solo se
## encuentran mirándolos con A, vía next_to_npc.
func _ocupante_bloqueante(celda: Vector2i) -> Node2D:
	if nodo_administrador == null:
		return null
	if nodo_administrador.has_method("ocupante_bloqueante"):
		return nodo_administrador.ocupante_bloqueante(celda)
	return nodo_administrador.next_to_npc(celda)

## ¿El jugador está siendo escoltado por un NPC (seguir_a)?
func esta_siguiendo() -> bool:
	return lider != null and is_instance_valid(lider)

## Escolta: el jugador deja de responder a la cruceta y, en cada paso de
## `lider_npc`, entra en la celda que este deja (como un NPC seguidor).
func seguir_a(lider_npc: Node2D) -> void:
	if lider_npc == null or lider_npc == self:
		return
	dejar_de_seguir()
	if not lider_npc.has_signal("paso_iniciado"):
		push_warning("[JUGADOR] %s no emite paso_iniciado: no se puede seguir" % lider_npc.name)
		return
	lider = lider_npc
	lider.paso_iniciado.connect(_on_lider_paso_iniciado)

func dejar_de_seguir() -> void:
	if lider != null and is_instance_valid(lider) and lider.paso_iniciado.is_connected(_on_lider_paso_iniciado):
		lider.paso_iniciado.disconnect(_on_lider_paso_iniciado)
	lider = null

## Paso automático de escolta: sin cruceta ni colisión con NPCs, a la
## velocidad del líder. Emite su propio paso_iniciado, así que un acompañante
## detrás del jugador sigue la cadena (NPC líder → jugador → NPC seguidor).
func _on_lider_paso_iniciado(origen: Vector2i, _destino: Vector2i) -> void:
	# El líder cambió de mapa (o el jugador): la escolta termina.
	if not esta_siguiendo() or lider.get_parent() != get_parent():
		dejar_de_seguir()
		return
	# Un salto en curso no se puede recortar; el siguiente paso lo recoloca.
	if state == PlayerState.JUMPING:
		return
	var d := origen - obtener_celda_destino()
	if d == Vector2i.ZERO:
		return
	# Terminar el paso anterior de golpe para no acumular desfase con el líder.
	if paso_en_curso:
		position = destino_paso
		progreso_paso = 1.0
		_finalizar_paso()
	if absi(d.x) + absi(d.y) == 1:
		var dir := Vector2(d)
		facing_direction = dir
		is_running = false
		_get_coord_tile_act()
		_aplicar_efecto_hierba_muy_alta(_evaluar_transicion_hierba(dir))
		var duracion_lider = lider.get("duracion_paso")
		_iniciar_paso_manual(dir, duracion_lider if duracion_lider is float else 0.0)
		var cell_f := Vector2(pos_celda_sig)
		if _celda_tiene_hierba_mas_alta(cell_f):
			_reproducir_animacion_hierba_muy_alta(pos_celda_sig)
		elif _celda_tiene_hierba_alta(cell_f):
			_spawn_animacion_pasto(pos_celda_sig)
	else:
		# Lejos del líder (teletransporte, salto...): recolocación directa.
		position = Vector2(origen) * Singleton.TILE_SIZE + Vector2(8, 14)
		var dir_lider = lider.get("facing_direction")
		if dir_lider is Vector2 and dir_lider != Vector2.ZERO:
			facing_direction = dir_lider
		_get_coord_tile_act()
		_actualizar_animacion_idle()
		actualizar_efecto_terreno_actual()

## Detiene el movimiento natural del jugador y lo hace mirar en la dirección dada.
## Usado por los NPCs para forzar al jugador a mirarles.
func detener_movimientos(direccion: Vector2 = Vector2.ZERO):
	no_control = true
	paso_en_curso = false
	if animated_sprite:
		animated_sprite.stop()
		animated_sprite.frame = 0
	if direccion != Vector2.ZERO:
		facing_direction = direccion
	_actualizar_animacion_idle()
	_change_state(PlayerState.IDLE)

## Paso de guion (applymovement walk_* / walk_fast_* sobre el jugador): sin
## cruceta y sin comprobar colisiones, como en Gen 3. `velocidad` (LENTO = 32,
## NORMAL = 16, RAPIDO = 8, MUY_RAPIDO = 4 fotogramas por casilla) es absoluta,
## igual que para los NPC. El llamador bloquea antes al jugador (no_control): así
## el paso no cuenta para encuentros salvajes, repelente ni guardería.
func caminar_guion(direccion: Vector2, velocidad: NpcBase.VelocidadPaso = NpcBase.VelocidadPaso.NORMAL) -> void:
	if paso_en_curso:
		position = destino_paso
		progreso_paso = 1.0
		_finalizar_paso()
	facing_direction = direccion
	is_running = false
	_get_coord_tile_act()
	var duracion: float = NpcBase.duracion_para_velocidad(velocidad)
	var celda_destino := pos_celda_sig
	_iniciar_paso_manual(direccion, duracion)
	_animar_hierba_paso_guion(celda_destino)
	while paso_en_curso:
		await get_tree().process_frame


## La hierba que pisa un paso de guion se anima como en un paso normal (sin
## encuentros: el paso de guion no los cuenta). Si la celda cae fuera del mapa
## actual (un guion que cruza al mapa vecino del Overworld sin cambiar de mapa,
## como el tutorial de BLASCO en la RUTA 102) se mira la hierba del vecino.
func _animar_hierba_paso_guion(celda: Vector2i) -> void:
	var mapa := _obtener_mapa_actual()
	if mapa == null:
		return
	var tp := _obtener_tp_capa_actual()
	var celda_tp := celda
	if not _celda_esta_dentro_del_mapa(mapa, celda) and nodo_administrador.enExterior:
		var mundo: Vector2 = mapa.posicion_en_mundo() + Vector2(celda) * Singleton.TILE_SIZE
		var vecino: MapaConfiguracion = nodo_administrador.encontrar_mapa_en_posicion_mundo(mundo)
		if vecino == null:
			return
		tp = _obtener_tp_de_mapa(vecino, Singleton.capa_activa)
		celda_tp = Vector2i(((mundo - vecino.posicion_en_mundo()) / Singleton.TILE_SIZE).floor())
	if tp == null:
		return
	if tp.has_flag(Vector2(celda_tp), TPTileDataMap.Flags.HIERBA_MAS_ALTA):
		_reproducir_animacion_hierba_muy_alta(celda)
	elif tp.has_flag(Vector2(celda_tp), TPTileDataMap.Flags.HIERBA_ALTA):
		_spawn_animacion_pasto(celda)

## Altura por fotograma de los jump_* de una casilla (pokeruby Unknown_83761BE,
## el tipo 2 de maybe_shadow_1): 16 fotogramas avanzando un píxel por fotograma.
const ALTURAS_SALTO_GUION: Array[int] = [-2, -4, -6, -8, -9, -10, -10, -10, -9, -8, -6, -5, -3, -2, 0, 0]

## Salto de guion (applymovement jump_right/left/up/down sobre el jugador): una
## casilla con sombra y polvo al caer, sin comprobar colisiones, como al bajar del
## camión de la mudanza en VILLA RAÍZ. El llamador bloquea antes al jugador.
func saltar_guion(direccion: Vector2) -> void:
	if paso_en_curso:
		position = destino_paso
		progreso_paso = 1.0
		_finalizar_paso()
	facing_direction = direccion
	is_running = false
	_get_coord_tile_act()
	var posicion_inicial := position
	var posicion_final := position + direccion * Singleton.TILE_SIZE
	var celda_aterrizaje := pos_celda_act + Vector2i(direccion)
	var alterna_paso_1 := alterna_animacion
	var alterna_paso_2 := 1 if alterna_paso_1 == 2 else 2
	var offset_inicial := Vector2.ZERO
	if animated_sprite:
		offset_inicial = animated_sprite.offset
	sombra.visible = _debe_mostrar_sombra_salto(pos_celda_act, direccion, 1)
	var fotogramas := ALTURAS_SALTO_GUION.size()
	var duracion := fotogramas / 60.0
	var tiempo := 0.0
	while tiempo < duracion:
		tiempo += get_process_delta_time()
		var t := minf(tiempo / duracion, 1.0)
		position = posicion_inicial.lerp(posicion_final, t)
		_actualizar_animacion_salto_parabolico(direccion, t * Singleton.TILE_SIZE, alterna_paso_1, alterna_paso_2)
		if animated_sprite:
			var indice := mini(int(t * fotogramas), fotogramas - 1)
			animated_sprite.offset.y = offset_inicial.y + ALTURAS_SALTO_GUION[indice]
		await get_tree().process_frame
	position = posicion_final
	if animated_sprite:
		animated_sprite.offset = offset_inicial
		animated_sprite.stop()
		animated_sprite.frame = 0
	sombra.visible = false
	_get_coord_tile_act()
	actualizar_efecto_terreno_actual()
	levanta_polvo(celda_aterrizaje)
	_actualizar_animacion_idle()

## setobjectxy sobre el jugador: lo coloca en `celda` (coordenadas del mapa) mirando
## a `direccion`, sin animación de entrada.
func colocar_en_celda(celda: Vector2i, direccion: Vector2) -> void:
	paso_en_curso = false
	position = Vector2(celda) * Singleton.TILE_SIZE + Vector2(8, 14)
	facing_direction = direccion
	_get_coord_tile_act()
	_actualizar_animacion_idle()
	actualizar_efecto_terreno_actual()

## Restaura al cargar la partida la dirección y el modo de avatar guardados
## (en Gen 3 viajan en el EventObject del jugador de SaveBlock1). Sin
## animaciones de entrada: el jugador aparece ya sobre la bici o surfeando.
func restaurar_estado_guardado(direccion: Vector2, bici: bool, surf: bool, tipo: String = BICI_CARRERA) -> void:
	if direccion in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		facing_direction = direccion
	var basico := get_node_or_null("basico") as AnimatedSprite2D
	if surf and otras != null and poke_field != null:
		en_surf = true
		en_bicicleta = false
		en_wheelie = false
		_surf_bob_tiempo = 0.0
		if basico:
			basico.visible = false
		if bicicleta:
			bicicleta.visible = false
		otras.remove_meta(&"sin_reflejo")
		otras.visible = true
		animated_sprite = otras
		# La escena guarda poke_field en reposo de vuelo (trayectoria y escala 0.1).
		poke_field.set(&"trayectoria", 0)  # NINGUNA: el nodo queda libre para el surf
		poke_field.position = Vector2.ZERO
		poke_field.scale = Vector2.ONE
		poke_field.rotation = 0.0
		poke_field.visible = true
		_actualizar_poke_field_dir()
	elif bici and bicicleta != null:
		en_bicicleta = true
		tipo_bici = BICI_ACROBATICA if tipo == BICI_ACROBATICA else BICI_CARRERA
		contador_bici = 0
		en_wheelie = false
		if basico:
			basico.stop()
			basico.visible = false
		bicicleta.visible = true
		animated_sprite = bicicleta
	_actualizar_animacion_idle()
	_get_coord_tile_act()

## =============================
## Máquina de Estados - Helpers
## =============================
func _change_state(new_state: PlayerState):
	if state == new_state:
		return
	previous_state = state
	state = new_state
	# La arena de los pies no acompaña al jugador en el aire; al aterrizar se
	# recalcula en actualizar_efecto_terreno_actual().
	if new_state == PlayerState.JUMPING and _efectos_arena:
		_efectos_arena.ocultar()
	# Tampoco el agua de los pies (charcos) acompaña al jugador en el aire.
	if new_state == PlayerState.JUMPING and _efectos_agua:
		_efectos_agua.ocultar()
	if new_state == PlayerState.LOCKED or new_state == PlayerState.TALKING:
		_detener_carrera_al_bloquear()
	_aplicar_tierra_pies()

## Al bloquear al jugador (diálogo, evento, pausa...) parado tras un paso
## corriendo, vuelve a la pose de caminar en lugar de quedarse con la de correr.
## Si el bloqueo llega a mitad de paso, se aplica al terminarlo: _finalizar_paso
## pasa a IDLE y el siguiente _process vuelve a entrar en LOCKED.
func _detener_carrera_al_bloquear() -> void:
	if paso_en_curso or not animated_sprite:
		return
	if not String(animated_sprite.animation).begins_with("corre_"):
		return
	is_running = false
	_venia_en_movimiento = false
	_configurar_animacion_direccion("camina_", 0)
	# Opcional: hook futuro para debug
	# _logger("STATE -> %s" % str(new_state))

func start_dialog():
	in_dialog = true
	_change_state(PlayerState.TALKING)

func end_dialog():
	in_dialog = false
	if state == PlayerState.TALKING:
		_change_state(PlayerState.IDLE)

func esperar_dialogo(bandera: bool):
	no_control = bandera

## =============================
##  Surf
## =============================

## Desplazamiento vertical sinusoidal del balanceo en el instante actual.
func _desplazamiento_bob_surf() -> float:
	# sen(t) ∈ [-1,1]: positivo = cima (sube en pantalla → y negativo en Godot)
	var s := sin(_surf_bob_tiempo * _SURF_BOB_FRECUENCIA * TAU)
	if s >= 0.0:
		return -s * _SURF_BOB_AMPLITUD_ARRIBA
	return -s * _SURF_BOB_AMPLITUD_ABAJO

## Balanceo de la montura que queda en el agua. sub_8088D3C (sub_8127ED0 con 2): el
## jugador se balancea con ella durante la pose; después solo se mueve la montura.
func _aplicar_efecto_bob_montura() -> void:
	var y_off := _desplazamiento_bob_surf()
	montura_mov_campo.offset.y = y_off - 6.0
	if otras:
		var en_pose: bool = animador != null and animador.is_playing() \
			and animador.current_animation in [ANIM_MOV_CAMPO_INICIO, ANIM_MOV_CAMPO_INICIO_INTERIOR]
		otras.offset.y = y_off if en_pose else 0.0

## Calcula y aplica el desplazamiento vertical sinusoidal sobre otras y poke_field.
func _aplicar_efecto_bob_surf() -> void:
	var y_off := _desplazamiento_bob_surf()
	if otras and otras.visible:
		otras.offset.y = y_off
	if pesca and pesca.visible:
		pesca.offset.y = y_off
	if poke_field and poke_field.visible:
		poke_field.offset.y = y_off - 6.0

## Actualiza la animación de poke_field según la dirección actual.
func _actualizar_poke_field_dir() -> void:
	if not en_surf or not poke_field:
		return
	var dir_str := _get_dir_string()
	var anim_name := &"surf_" + dir_str
	if poke_field.sprite_frames.has_animation(anim_name):
		if poke_field.animation != anim_name:
			poke_field.play(anim_name)
			poke_field.stop()
		poke_field.frame = 0

## A frente al agua (GetInteractedWaterScript de Gen 3): si un Pokémon del
## equipo conoce SURF y se tiene la Medalla Equilibrio (FLAG_BADGE05_GET),
## pregunta y lo usa (UseSurfScript). Si no, no pasa nada.
func _intentar_surf() -> void:
	if not SistemaGuardado.tiene_medalla(MEDALLA_SURF) or not puede_usar_surf():
		return
	var pokemon = pokemon_con_surf()
	if pokemon == null:
		return
	_preguntar_y_usar_surf(pokemon)

## IsPlayerFacingSurfableFishableWater: no surfea ya y tiene delante agua
## surfeable sin bloqueo. También lo consulta el menú del Pokémon.
func puede_usar_surf() -> bool:
	if en_surf:
		return false
	_get_coord_tile_act()
	var tp := _obtener_tp_capa_actual()
	if tp == null:
		return false
	var cell_f := Vector2(pos_celda_sig)
	# IsPlayerFacingSurfableFishableWater solo deja saltar al agua desde una celda de
	# elevación 3 (CASCADA METEORO: las plataformas de elevación 4 dan al agua pero no
	# se surfea desde ellas): ahí se marca con el bloqueo direccional hacia el agua, que
	# can_move ya respeta al andar.
	var bloqueo_salto := _obtener_flag_bloqueo_direccional(facing_direction)
	if bloqueo_salto != 0 and tp.has_flag(Vector2(pos_celda_act), bloqueo_salto):
		return false
	# MetatileBehavior_IsSurfableAndNotWaterfall: no se salta al agua de una cascada.
	return tp.has_flag(cell_f, TPTileDataMap.Flags.SURF) and not tp.has_flag(cell_f, TPTileDataMap.Flags.BLOQUEO) \
		and not tp.has_flag(cell_f, TPTileDataMap.Flags.CASCADA)

## A frente a una cascada surfeando (field_control_avatar.c, EventScript_Waterfall):
## con la Medalla Lluvia y un Pokémon del equipo que conoce CASCADA pregunta y lo
## usa; si no, solo describe el rugido del agua.
func _intentar_cascada() -> void:
	var pokemon = pokemon_con_movimiento(MOVIMIENTO_CASCADA) if SistemaGuardado.tiene_medalla(MEDALLA_CASCADA) else null
	await _preguntar_y_usar_cascada(pokemon)

## SetUpFieldMove_Waterfall: surfeando, mirando al norte y con una cascada
## (bandera CASCADA) en la celda de enfrente. También lo consulta el menú del Pokémon.
func puede_usar_cascada() -> bool:
	if not en_surf or facing_direction != Vector2.UP:
		return false
	_get_coord_tile_act()
	var tp := _obtener_tp_capa_actual()
	if tp == null:
		return false
	return tp.has_flag(Vector2(pos_celda_sig), TPTileDataMap.Flags.CASCADA)

## EventScript_Waterfall: sin medalla o Pokémon con CASCADA (`pokemon` null) solo
## sale el texto del rugido; si no, pregunta SÍ/NO y, si acepta, "X usó CASCADA." y sube.
func _preguntar_y_usar_cascada(pokemon) -> void:
	var dialogo = nodo_administrador.cuadro_dialogo if nodo_administrador != null else null
	if dialogo == null:
		return
	Singleton.mantener_pausa(PAUSA_CASCADA, true)
	start_dialog()
	dialogo.cerrar()
	var respuesta := "N"
	if pokemon == null:
		dialogo.mostrar(tr(TEXTO_CASCADA_RUGIDO), true, true, _surf_mensaje_terminado.emit)
		await _surf_mensaje_terminado
	else:
		# preguntaSiNo() exige el cuadro en IDLE o ESPERANDO_REINGRESO.
		dialogo.preguntaSiNo(tr(TEXTO_CASCADA_PREGUNTA))
		respuesta = ""
		while respuesta.is_empty():
			var datos: Array = await dialogo.comando_ejecutado
			if datos.size() >= 2 and str(datos[0]) == "respuesta_confirmacion":
				var parametros: Array = datos[1]
				respuesta = str(parametros[0]) if not parametros.is_empty() else "N"
		if respuesta != "Y":
			dialogo.cerrar()
	end_dialog()
	if respuesta == "Y":
		await usar_cascada(pokemon, true)
	no_control = false
	Singleton.mantener_pausa(PAUSA_CASCADA, false)

## Primer Pokémon del equipo (sin contar huevos) que conoce SURF, o null.
static func pokemon_con_surf():
	return pokemon_con_movimiento(MOVIMIENTO_SURF)

## checkpartymove de pokeruby: primer Pokémon del equipo (sin contar huevos) que
## conoce el movimiento `nombre_interno` (p. ej. "FUERZA"), o null.
static func pokemon_con_movimiento(nombre_interno: String):
	for pokemon in SistemaGuardado.get_equipo():
		if not (pokemon is BasePokemon) or pokemon.huevo:
			continue
		for movimiento in pokemon.movimientos:
			if movimiento == null:
				continue
			if movimiento.get_nombre_interno() == nombre_interno:
				return pokemon
	return null

## UseSurfScript: pregunta SÍ/NO y, si acepta, "¡X ha usado SURF!" y surfea.
func _preguntar_y_usar_surf(pokemon) -> void:
	var dialogo = nodo_administrador.cuadro_dialogo if nodo_administrador != null else null
	if dialogo == null:
		return
	Singleton.mantener_pausa(PAUSA_SURF, true)
	start_dialog()
	# preguntaSiNo() exige el cuadro en IDLE o ESPERANDO_REINGRESO.
	dialogo.cerrar()
	dialogo.preguntaSiNo(tr(TEXTO_SURF_PREGUNTA))
	var respuesta := ""
	while respuesta.is_empty():
		var datos: Array = await dialogo.comando_ejecutado
		if datos.size() >= 2 and str(datos[0]) == "respuesta_confirmacion":
			var parametros: Array = datos[1]
			respuesta = str(parametros[0]) if not parametros.is_empty() else "N"
	if respuesta == "Y":
		var texto := tr(TEXTO_SURF_USADO).replace("{POKEMON}", pokemon.get_nombre_mostrar())
		dialogo.mostrar(texto, true, true, _surf_mensaje_terminado.emit)
		await _surf_mensaje_terminado
	else:
		dialogo.cerrar()
	end_dialog()
	if respuesta == "Y":
		await usar_surf(pokemon)
	no_control = false
	Singleton.mantener_pausa(PAUSA_SURF, false)

## FldEff_UseSurf: suena el tema SURF, el jugador saca la Poké Ball y cruza el
## Pokémon (mov_campo_inicio, compartida con VUELO) y salta a su lomo.
## También lo llama el menú del Pokémon, sin pregunta ni mensaje.
func usar_surf(pokemon) -> void:
	if en_surf:
		return
	Singleton.mantener_pausa(PAUSA_SURF, true)
	no_control = true
	paso_en_curso = false
	if nodo_administrador != null and nodo_administrador.has_method("reproducir_musica_surf"):
		nodo_administrador.reproducir_musica_surf()
	var direccion: Vector2 = facing_direction
	var anim_campo := anim_mov_campo()
	if animador != null and animador.has_animation(anim_campo):
		_preparar_sprites_para_vuelo()
		preparar_pokemon_mov_campo(pokemon)
		animador.play(anim_campo)
		await animador.animation_finished
		_restaurar_nodos_mov_campo()
		_pokemon_mov_campo = null
		facing_direction = direccion
		_actualizar_animacion_idle()
	await _iniciar_surf()
	no_control = false
	Singleton.mantener_pausa(PAUSA_SURF, false)

## Animación de entrada al surf: salta un tile hacia adelante, muestra poke_field y queda en sentar.
func _iniciar_surf() -> void:
	_change_state(PlayerState.JUMPING)
	_marcar_celda_destino(facing_direction)
	var dir_str := _get_dir_string()

	# Spawn inmediato de poke_field en la celda destino
	if poke_field:
		var anim_surf := &"surf_" + dir_str
		if poke_field.sprite_frames.has_animation(anim_surf):
			poke_field.play(anim_surf)
			poke_field.stop()
			poke_field.frame = 0
		poke_field.visible = true

	# Guardar estado de bicicleta y ocultar todos los sprites del jugador
	_surf_en_bici_previo = en_bicicleta
	_surf_en_wheelie_previo = en_wheelie
	if en_bicicleta:
		if bicicleta:
			bicicleta.stop()
			bicicleta.visible = false
		en_bicicleta = false
		en_wheelie = false
	var basico := get_node_or_null("basico") as AnimatedSprite2D
	if basico:
		basico.visible = false
	if otras:
		var anim_saltar := &"saltar_" + dir_str
		if otras.sprite_frames.has_animation(anim_saltar):
			otras.play(anim_saltar)
			otras.stop()
			otras.frame = 0
		otras.visible = true

	# Salto parabólico de 1 tile hacia adelante
	const DURACION := 0.25
	const ALTURA := 8.0
	var posicion_inicial: Vector2 = position
	var posicion_final: Vector2 = position + facing_direction * Singleton.TILE_SIZE
	var tiempo := 0.0
	var offset_otras_base := otras.offset if otras else Vector2.ZERO

	while tiempo < DURACION:
		tiempo += get_process_delta_time()
		var t := minf(tiempo / DURACION, 1.0)
		var y_off := 4.0 * ALTURA * t * (t - 1.0)
		position = posicion_inicial.lerp(posicion_final, t)
		if otras:
			otras.offset.y = offset_otras_base.y + y_off
		if poke_field and poke_field.visible:
			poke_field.position = posicion_final - position
		await get_tree().create_timer(get_process_delta_time()).timeout

	position = posicion_final
	if otras:
		otras.offset = offset_otras_base
	if poke_field:
		poke_field.position = Vector2.ZERO

	# Aterrizado en el agua: activar surf y habilitar reflejo de 'otras'
	en_surf = true
	_surf_bob_tiempo = 0.0
	if otras:
		otras.remove_meta(&"sin_reflejo")  # permitir que reflexiones_agua lo capture
	animated_sprite = otras
	var anim_sentar := &"sentar_" + dir_str
	if otras and otras.sprite_frames.has_animation(anim_sentar):
		otras.play(anim_sentar)
		otras.stop()
		otras.frame = 0

	_get_coord_tile_act()
	_change_state(PlayerState.IDLE)
	# Onda de agua en el tile de aterrizaje
	_intentar_onda_agua()
	# Al caer en una corriente, esta arrastra ya (ForcedMovement_RideCurrent*).
	_procesar_suelo_forzado()

## Animación de salida del surf: salta un tile hacia tierra, restaura sprites normales.
func _realizar_salto_salida_surf(dir: Vector2) -> void:
	_change_state(PlayerState.JUMPING)
	var dir_str := _get_dir_string()

	# Mantener animación saltar durante el salto de salida
	if otras:
		var anim_saltar := &"saltar_" + dir_str
		if otras.sprite_frames.has_animation(anim_saltar):
			otras.play(anim_saltar)
			otras.stop()
			otras.frame = 0

	const DURACION := 0.25
	const ALTURA := 8.0
	var posicion_inicial: Vector2 = position
	var posicion_final: Vector2 = position + dir * Singleton.TILE_SIZE
	_marcar_celda_destino(dir)
	var tiempo := 0.0
	# Resetear offset del bob antes de capturar la base
	if otras:
		otras.offset.y = 0.0
	# Ocultar poke al inicio del salto de salida
	if poke_field:
		poke_field.visible = false
	var offset_otras_base := otras.offset if otras else Vector2.ZERO

	while tiempo < DURACION:
		tiempo += get_process_delta_time()
		var t := minf(tiempo / DURACION, 1.0)
		var y_off := 4.0 * ALTURA * t * (t - 1.0)
		position = posicion_inicial.lerp(posicion_final, t)
		if otras:
			otras.offset.y = offset_otras_base.y + y_off
		await get_tree().create_timer(get_process_delta_time()).timeout

	position = posicion_final
	if otras:
		otras.offset = offset_otras_base
		otras.visible = false

	# Restaurar sprites — siempre al modo caminar, independientemente del estado previo
	en_surf = false
	# Al pisar tierra vuelve el tema del lugar (Overworld_ChangeMusicToDefault).
	if nodo_administrador != null and nodo_administrador.has_method("restaurar_musica_mapa_actual"):
		nodo_administrador.restaurar_musica_mapa_actual(2)
	if otras:
		otras.set_meta(&"sin_reflejo", true)  # volver a excluir del sistema de reflejos
	en_bicicleta = false
	en_wheelie = false
	_surf_en_bici_previo = false
	_surf_en_wheelie_previo = false
	if bicicleta:
		bicicleta.stop()
		bicicleta.visible = false
	var basico := get_node_or_null("basico") as AnimatedSprite2D
	if basico:
		basico.visible = true
		animated_sprite = basico
	else:
		animated_sprite = get_node_or_null("AnimatedSprite2D")

	_get_coord_tile_act()
	_change_state(PlayerState.IDLE)
	_actualizar_animacion_idle()

## =============================
## Movimientos de campo / Vuelo
## =============================

const RUTA_GRITOS := "res://Audio/SE/Cries/"
## FLDEFF_FIELD_MOVE_SHOW_MON con los frames de Rubí de cada variante (la franja
## empieza a 0,45 s en ambas): exterior (sub_8088120) dura 82 frames y la
## interior (sub_808847C) 89. Se elige con anim_mov_campo().
const ANIM_MOV_CAMPO_INICIO := &"mov_campo_inicio"
const ANIM_MOV_CAMPO_INICIO_INTERIOR := &"mov_campo_inicio_interior"
const ANIM_VOLAR_INICIO := &"volar_inicio"
const ANIM_VUELO_FINAL := &"vuelo_final"
## Motivo de pausa que congela el juego durante toda la secuencia de vuelo
## (sobrevive al warp: conectar_escalera devuelve el control local al llegar).
const PAUSA_VUELO := &"vuelo"
## z_index del jugador durante el vuelo: por encima de las capas "SobreTodo"
## (árboles, techos) para que ni él ni el Pokémon (hijo, z -1/+1) queden tapados.
const Z_INDEX_VUELO := 100

## =============================
##  Buceo (MO08)
## =============================

## Motivo de pausa desde la pregunta de BUCEO hasta que empieza el warp.
const PAUSA_BUCEO := &"buceo"
const MOVIMIENTO_BUCEO := "BUCEO"
## Índice de la Medalla Mente en `medallas` (FLAG_BADGE07_GET).
const MEDALLA_BUCEO := 6
## SE_W291 (inventario_se.json: SE_M_DIVE), al empezar el warp de dive_warp.
const SONIDO_BUCEO := "SE_M_DIVE"
## Textos de data/field_move_scripts.inc (claves de BaseDatos/dialogos.csv;
## traducción provisional: no están en los textos extraídos de la ROM española).
const TEXTO_BUCEO_NO_PUEDE := "BUCEO_NO_PUEDE"				# CannotUseDiveText
const TEXTO_BUCEO_PREGUNTA := "BUCEO_PREGUNTA"				# UseDivePromptText
const TEXTO_BUCEO_USADO := "BUCEO_USADO"					# UsedDiveText
const TEXTO_BUCEO_EMERGER_NO_PUEDE := "BUCEO_EMERGER_NO_PUEDE"	# UnderwaterCannotUseDiveText
const TEXTO_BUCEO_EMERGER_PREGUNTA := "BUCEO_EMERGER_PREGUNTA"	# UnderwaterUseDivePromptText
## field_effect_helpers.c (sub_8128174): bajo el agua el sprite baja 1 px cada 4
## fotogramas y la dirección se invierte cada 16 (0 a 4 px, ciclo de 32 fotogramas).
const _BUCEO_BOB_FOTOGRAMAS_PASO := 4
const _BUCEO_BOB_PASOS := 4
signal _buceo_mensaje_terminado


## Destino de BUCEO desde la celda del jugador (TrySetDiveWarp): {"tipo", "mapa",
## "celda"} (ver Buceo.destino), o {} si aquí no se puede bajar ni emerger o el
## mapa de destino no existe en el proyecto. Para bajar hay que estar surfeando.
func destino_buceo_actual() -> Dictionary:
	if esta_en_movimiento() or nodo_administrador == null:
		return {}
	_get_coord_tile_act()
	var destino := Buceo.destino(_obtener_mapa_actual(), _obtener_tp_capa_actual(), pos_celda_act)
	var tipo := int(destino.get("tipo", Buceo.Tipo.NINGUNO))
	if tipo == Buceo.Tipo.NINGUNO:
		return {}
	if tipo == Buceo.Tipo.SUMERGIRSE and not en_surf:
		return {}
	if tipo == Buceo.Tipo.EMERGER and not en_buceo:
		return {}
	if nodo_administrador.has_method("destino_warp_valido") \
			and not nodo_administrador.destino_warp_valido(str(destino["mapa"]), Vector2(destino["celda"])):
		return {}
	return destino


## SetUpFieldMove_Dive: lo consulta el menú del Pokémon.
func puede_usar_buceo() -> bool:
	return not destino_buceo_actual().is_empty()


## TrySetupDiveDownScript (botón A, desde administrador_mapa.accionar_evento):
## surfeando sobre agua buceable y con la Medalla Mente. Sin Pokémon con BUCEO
## solo se describe el agua. Devuelve true si consumió la pulsación.
func intentar_bucear() -> bool:
	if not en_surf or en_buceo or paso_en_curso or state != PlayerState.IDLE:
		return false
	if not SistemaGuardado.tiene_medalla(MEDALLA_BUCEO):
		return false
	var destino := destino_buceo_actual()
	if int(destino.get("tipo", Buceo.Tipo.NINGUNO)) != Buceo.Tipo.SUMERGIRSE:
		return false
	_preguntar_y_usar_buceo(pokemon_con_movimiento(MOVIMIENTO_BUCEO), TEXTO_BUCEO_PREGUNTA, TEXTO_BUCEO_NO_PUEDE)
	return true


## TrySetupDiveEmergeScript (botón B bajo el agua). Devuelve true si consumió la pulsación.
func _intentar_emerger() -> bool:
	if not en_buceo or paso_en_curso or state != PlayerState.IDLE:
		return false
	if not SistemaGuardado.tiene_medalla(MEDALLA_BUCEO):
		return false
	var destino := destino_buceo_actual()
	if int(destino.get("tipo", Buceo.Tipo.NINGUNO)) != Buceo.Tipo.EMERGER:
		return false
	_preguntar_y_usar_buceo(pokemon_con_movimiento(MOVIMIENTO_BUCEO), TEXTO_BUCEO_EMERGER_PREGUNTA, TEXTO_BUCEO_EMERGER_NO_PUEDE)
	return true


## UseDiveScript / S_UseDiveUnderwater: sin Pokémon con BUCEO (`pokemon` null)
## solo sale `texto_sin_pokemon`; si no, pregunta SÍ/NO y, si acepta,
## "X usó BUCEO." y bucea o emerge.
func _preguntar_y_usar_buceo(pokemon, texto_pregunta: String, texto_sin_pokemon: String) -> void:
	var dialogo = nodo_administrador.cuadro_dialogo if nodo_administrador != null else null
	if dialogo == null:
		return
	Singleton.mantener_pausa(PAUSA_BUCEO, true)
	start_dialog()
	dialogo.cerrar()
	var respuesta := "N"
	if pokemon == null:
		dialogo.mostrar(tr(texto_sin_pokemon), true, true, _buceo_mensaje_terminado.emit)
		await _buceo_mensaje_terminado
	else:
		# preguntaSiNo() exige el cuadro en IDLE o ESPERANDO_REINGRESO.
		dialogo.preguntaSiNo(tr(texto_pregunta))
		respuesta = ""
		while respuesta.is_empty():
			var datos: Array = await dialogo.comando_ejecutado
			if datos.size() >= 2 and str(datos[0]) == "respuesta_confirmacion":
				var parametros: Array = datos[1]
				respuesta = str(parametros[0]) if not parametros.is_empty() else "N"
		if respuesta == "Y":
			var texto := tr(TEXTO_BUCEO_USADO).replace("{POKEMON}", pokemon.get_nombre_mostrar())
			dialogo.mostrar(texto, true, true, _buceo_mensaje_terminado.emit)
			await _buceo_mensaje_terminado
		else:
			dialogo.cerrar()
	end_dialog()
	Singleton.mantener_pausa(PAUSA_BUCEO, false)
	if respuesta == "Y":
		await usar_buceo(pokemon)
	else:
		no_control = false


## FldEff_UseDive: pose de movimiento de campo con el Pokémon y dive_warp al
## destino de la celda actual (también desde el menú del Pokémon, sin pregunta).
## El warp devuelve el control al terminar; si no puede empezar, se devuelve aquí.
func usar_buceo(pokemon) -> void:
	var destino := destino_buceo_actual()
	if destino.is_empty():
		return
	Singleton.mantener_pausa(PAUSA_BUCEO, true)
	no_control = true
	paso_en_curso = false
	await _reproducir_mov_campo(pokemon)
	Singleton.mantener_pausa(PAUSA_BUCEO, false)
	var iniciado: bool = nodo_administrador != null and nodo_administrador.has_method("conectar_buceo") \
		and nodo_administrador.conectar_buceo(str(destino["mapa"]), destino["celda"])
	if iniciado:
		_reproducir_sonido_campo(SONIDO_BUCEO)
	else:
		no_control = false


## PlayerAvatarTransition al llegar a un mapa (lo llama el AdministradorMapa con la
## pantalla en negro): en un mapa submarino se bucea; al salir de uno se vuelve a
## pie, o haciendo surf (`surfear`) si se emerge con BUCEO al agua. En un mapa
## `solo_caminar` (interiores: Overworld_IsBikingAllowed() == FALSE) se llega a pie.
func aplicar_estado_llegada_mapa(submarino: bool, surfear: bool = false, solo_caminar: bool = false) -> void:
	if solo_caminar:
		bajar_de_bicicleta_sin_musica()
	if submarino:
		if not en_buceo:
			entrar_estado_buceo()
	elif en_buceo:
		salir_estado_buceo(surfear)


## PlayerAvatarTransition_Underwater: sprite `bucear_*` de `otras`, sin bici,
## surf ni Pokémon a la vista.
func entrar_estado_buceo() -> void:
	en_buceo = true
	en_surf = false
	en_bicicleta = false
	en_wheelie = false
	is_running = false
	_venia_en_movimiento = false
	_surf_en_bici_previo = false
	_surf_en_wheelie_previo = false
	_surf_bob_tiempo = 0.0
	var basico := get_node_or_null("basico") as AnimatedSprite2D
	if basico:
		basico.stop()
		basico.visible = false
	if bicicleta:
		bicicleta.stop()
		bicicleta.visible = false
	if poke_field:
		poke_field.visible = false
		poke_field.position = Vector2.ZERO
	if otras:
		otras.set_meta(&"sin_reflejo", true)  # bajo el agua no hay reflejo
		otras.offset = Vector2.ZERO
		otras.visible = true
		animated_sprite = otras
	_actualizar_animacion_idle()
	actualizar_efecto_terreno_actual()


## Deja de bucear: a pie (`basico`) o, con `surfear`, sobre el Pokémon como al cargar
## una partida guardada surfeando.
func salir_estado_buceo(surfear: bool) -> void:
	en_buceo = false
	_surf_bob_tiempo = 0.0
	if otras:
		otras.offset = Vector2.ZERO
	if surfear and otras != null and poke_field != null:
		restaurar_estado_guardado(facing_direction, false, true)
		return
	if otras:
		otras.visible = false
		otras.position = Vector2(-16, -30)
	var basico := get_node_or_null("basico") as AnimatedSprite2D
	if basico:
		basico.visible = true
		animated_sprite = basico
	_actualizar_animacion_idle()
	actualizar_efecto_terreno_actual()


func _poner_animacion_buceo() -> void:
	if otras == null:
		return
	var anim_name := &"bucear_" + _get_dir_string()
	if otras.sprite_frames.has_animation(anim_name):
		if otras.animation != anim_name:
			otras.play(anim_name)
			otras.stop()
		otras.frame = 0


## Balanceo submarino (sub_8128174): 0-4 px hacia abajo en un ciclo de 32 fotogramas.
func _aplicar_efecto_bob_buceo() -> void:
	if otras == null or not otras.visible:
		return
	otras.offset.y = float(desplazamiento_bob_buceo(int(_surf_bob_tiempo * 60.0)))


## Píxeles hacia abajo del balanceo submarino en el fotograma `fotograma`.
static func desplazamiento_bob_buceo(fotograma: int) -> int:
	var ciclo := _BUCEO_BOB_FOTOGRAMAS_PASO * _BUCEO_BOB_PASOS * 2
	var fase := posmod(fotograma, ciclo)
	var mitad := ciclo / 2
	if fase < mitad:
		return fase / _BUCEO_BOB_FOTOGRAMAS_PASO + 1
	return _BUCEO_BOB_PASOS - ((fase - mitad) / _BUCEO_BOB_FOTOGRAMAS_PASO + 1)


## Motivo de pausa desde la pregunta de SURF hasta quedar sobre el Pokémon.
const PAUSA_SURF := &"surf"
const MOVIMIENTO_SURF := "SURF"
## Índice de la Medalla Equilibrio en `medallas` (FLAG_BADGE05_GET).
const MEDALLA_SURF := 4
## data/text/surf.inc (traducción provisional: el decomp ES lo tiene en inglés).
const TEXTO_SURF_PREGUNTA := "El agua es de un azul intenso...\\l¿Quieres usar SURF?"
const TEXTO_SURF_USADO := "¡{POKEMON} usó SURF!"
signal _surf_mensaje_terminado

## Motivo de pausa mientras se usa CASCADA (pregunta, mensaje, pose y subida).
const PAUSA_CASCADA := &"cascada"
const MOVIMIENTO_CASCADA := "CASCADA"
## Índice de la Medalla Lluvia en `medallas` (FLAG_BADGE08_GET).
const MEDALLA_CASCADA := 7
## PROVISIONAL (no están en los textos extraídos de la ROM española): la pregunta
## y el rugido son traducciones libres; el «usó» sigue el UsedCutRockSmashText.
const TEXTO_CASCADA_PREGUNTA := "Es una enorme cascada.\\l¿Quieres usar CASCADA?"
const TEXTO_CASCADA_RUGIDO := "Una pared de agua cae con\nun rugido atronador."
const TEXTO_CASCADA_USADA := "{POKEMON} usó CASCADA."
## true mientras usar_cascada() sube: la celda CASCADA no empuja hacia abajo.
var _subiendo_cascada: bool = false
## GetWalkSlowMovementAction: la subida va a media velocidad de andar (32 fotogramas por celda).
const VELOCIDAD_SUBIDA_CASCADA: float = SPEED / 2.0

## Pokémon que usa el movimiento de campo en curso (textura de poke64 y grito).
var _pokemon_mov_campo = null
var _reproductor_grito: AudioStreamPlayer = null

## ¿Tiene este personaje las animaciones de vuelo? (girl.tscn aún no las tiene)
func puede_animar_vuelo() -> bool:
	return animador != null and animador.has_animation(anim_mov_campo()) \
		and animador.has_animation(ANIM_VOLAR_INICIO) and animador.has_animation(ANIM_VUELO_FINAL)

## Fondos de FLDEFF_FIELD_MOVE_SHOW_MON (pokeruby field_effect.c): rayas
## blancas sobre negro al aire libre (sub_8088120) y franja celeste con borde
## gris en cuevas y edificios (sub_808847C, darkness_field_move_streaks).
const TEXTURA_MOV_CAMPO_EXTERIOR: Texture2D = preload("res://graficos/character/move_field_particle.png")
const TEXTURA_MOV_CAMPO_INTERIOR: Texture2D = preload("res://graficos/character/move_field_particle_interior.png")

## ¿Usa el mapa la variante interior? Rubí la elige para MAP_TYPE_UNDERGROUND,
## INDOOR y SECRET_BASE (cuevas, edificios, bases); aquí eso es `esInterior`.
## Sin mapa (o al aire libre: ciudades, rutas, rutas marinas) es la exterior.
static func es_mov_campo_interior(mapa: MapaConfiguracion) -> bool:
	return mapa != null and mapa.esInterior

## Animación de la variante: cada una lleva los tiempos de su rama en Rubí.
static func nombre_anim_mov_campo(interior: bool) -> StringName:
	return ANIM_MOV_CAMPO_INICIO_INTERIOR if interior else ANIM_MOV_CAMPO_INICIO

## Único punto que decide qué animación de movimiento de campo se reproduce en
## el mapa actual (el mismo criterio que preparar_pokemon_mov_campo).
func anim_mov_campo() -> StringName:
	return nombre_anim_mov_campo(es_mov_campo_interior(_obtener_mapa_actual()))

## Elige el fondo de la franja y el modo del shader (apertura/cierre) de
## mov_campo_inicio, y alinea CapaMovCampo con el jugador.
func configurar_variante_mov_campo(interior: bool) -> void:
	if fondo_mov_campo:
		fondo_mov_campo.texture = TEXTURA_MOV_CAMPO_INTERIOR if interior else TEXTURA_MOV_CAMPO_EXTERIOR
		var material_fondo := fondo_mov_campo.material as ShaderMaterial
		if material_fondo:
			material_fondo.set_shader_parameter(&"modo_interior", interior)
	alinear_capa_mov_campo()

## Un CanvasLayer no hereda la transformación del padre: con
## follow_viewport_enabled sigue a la cámara y, con la transformación global del
## jugador, las posiciones de la franja y de poke64 (relativas al jugador en las
## pistas de la animación) caen donde caían cuando eran hijos directos.
func alinear_capa_mov_campo() -> void:
	if capa_mov_campo and is_inside_tree():
		capa_mov_campo.transform = get_global_transform()

## Pone en poke64 el sprite frontal del Pokémon que usa el movimiento de campo
## y la variante de la franja según el mapa actual (un único punto para SURF,
## DESTELLO y VUELO).
func preparar_pokemon_mov_campo(pokemon) -> void:
	_pokemon_mov_campo = pokemon
	configurar_variante_mov_campo(es_mov_campo_interior(_obtener_mapa_actual()))
	if poke64 and pokemon:
		# pokeruby field_effect.c: el frente lleva las manchas de SPINDA.
		var textura := PokemonSpriteManager.cargar_sprite_frente(pokemon.nombre_interno, pokemon.es_shiny(), pokemon.personalidad)
		if textura:
			poke64.texture = textura

## Grito del Pokémon del movimiento de campo. Lo llama la pista de método de
## mov_campo_inicio cuando poke64 llega al centro de la pantalla.
func _grito_poke_campo() -> void:
	if _pokemon_mov_campo == null:
		return
	var ruta := "%s%sCry.ogg" % [RUTA_GRITOS, str(_pokemon_mov_campo.numero_nacional).pad_zeros(3)]
	if not ResourceLoader.exists(ruta):
		push_warning("[VUELO] Grito no encontrado: %s" % ruta)
		return
	if not is_instance_valid(_reproductor_grito):
		_reproductor_grito = AudioStreamPlayer.new()
		_reproductor_grito.name = "ReproductorGrito"
		add_child(_reproductor_grito)
	_reproductor_grito.stream = load(ruta) as AudioStream
	_reproductor_grito.play()

## Secuencia completa de VUELO:
## mov_campo_inicio (saca la ball, cruza poke64 con su grito) → volar_inicio
## (sale la sombra y se lleva al jugador) → fundido a negro → warp → aclarar →
## vuelo_final (lo trae, salta, saca la ball, entra la sombra, la guarda) →
## `basico` mirando abajo y control liberado.
## `celda_destino` en tiles locales al mapa destino (igual que conectar_escalera).
func volar(pokemon, mapa_destino: String, celda_destino: Vector2) -> void:
	if nodo_administrador == null:
		push_error("[VUELO] Sin AdministradorMapa: no se puede hacer el warp")
		return
	Singleton.mantener_pausa(PAUSA_VUELO, true)
	no_control = true
	paso_en_curso = false
	_dejar_montura_en_agua()
	_preparar_sprites_para_vuelo()
	if not has_meta(&"z_index_base"):
		set_meta(&"z_index_base", posmod(z_index, Singleton.Z_INDEX_POR_CAPA))  # que Singleton conserve la base al restaurar
	z_index = Z_INDEX_VUELO

	if puede_animar_vuelo():
		preparar_pokemon_mov_campo(pokemon)
		animador.play(anim_mov_campo())
		await animador.animation_finished
		animador.play(ANIM_VOLAR_INICIO)
		await animador.animation_finished
	else:
		push_warning("[VUELO] '%s' no tiene las animaciones de vuelo: solo warp" % name)
	_retirar_montura_del_agua()

	await Singleton.transicion("oscurecer")

	# Con la pantalla en negro se deja aplicado el primer frame de vuelo_final
	# (jugador oculto, colgado de la sombra fuera de pantalla) para que al
	# aclarar no se vea al jugador parado en el destino.
	if puede_animar_vuelo():
		animador.play(ANIM_VUELO_FINAL)
		animador.seek(0.0, true)
		animador.pause()
	else:
		visible = false

	# Overworld_ResetStateAfterFly: con la pantalla ya en negro se apaga Destello y el
	# CAMINO de BICIS (FLAG_SYS_CYCLING_ROAD).
	EfectoOscuridadCueva.apagar_destello()
	CaminoBici.apagar()
	nodo_administrador.conectar_escalera(mapa_destino, celda_destino, Vector2.DOWN, false)
	# conectar_escalera avanza por frames desde el _process del administrador y
	# vuelve a 0 al colocar al jugador y empezar a aclarar.
	while nodo_administrador.coneccion != 0:
		await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout  # duración de telon.aclarar()
	z_index = Z_INDEX_VUELO  # el warp reasigna el z_index del foco según la capa

	if puede_animar_vuelo():
		animador.play(ANIM_VUELO_FINAL)
		await animador.animation_finished
	_terminar_vuelo()

## FldEff_UseFly, teletransporte y excavar no retiran el surf blob al empezar: sigue en
## el agua aunque el jugador pase a pie. Llamar antes de _preparar_sprites_para_vuelo.
func _dejar_montura_en_agua() -> void:
	if not en_surf or poke_field == null or montura_mov_campo == null:
		return
	montura_mov_campo.animation = poke_field.animation
	montura_mov_campo.frame = poke_field.frame
	montura_mov_campo.offset = poke_field.offset
	montura_mov_campo.visible = true

func _retirar_montura_del_agua() -> void:
	if montura_mov_campo:
		montura_mov_campo.visible = false
	if otras:
		otras.offset = Vector2.ZERO

## Deja al jugador a pie antes de la animación (sin bici ni surf).
func _preparar_sprites_para_vuelo() -> void:
	if en_bicicleta:
		en_bicicleta = false
		en_wheelie = false
		if bicicleta:
			bicicleta.stop()
			bicicleta.visible = false
	if en_surf:
		en_surf = false
		if otras:
			otras.offset = Vector2.ZERO
		if poke_field:
			poke_field.offset = Vector2(0, -6)
	var basico := get_node_or_null("basico") as AnimatedSprite2D
	if basico:
		animated_sprite = basico

## Restaura los nodos que usan las animaciones de campo y devuelve el control
## con `basico` mirando hacia abajo.
func _terminar_vuelo() -> void:
	_restaurar_nodos_mov_campo()
	Singleton._aplicar_z_index_foco_por_capa(Singleton.capa_activa)  # base + capa × 10, como al cargar el mapa
	visible = true
	_pokemon_mov_campo = null
	facing_direction = Vector2.DOWN
	_get_coord_tile_act()
	_actualizar_animacion_idle()
	_change_state(PlayerState.IDLE)
	no_control = false
	Singleton.mantener_pausa(PAUSA_VUELO, false)

## Deja en reposo los nodos que mueven las animaciones de campo y vuelve a
## `basico` como sprite activo (tras VUELO o antes del salto de SURF).
func _restaurar_nodos_mov_campo() -> void:
	if animador:
		animador.stop()
	if poke_field:
		poke_field.set(&"llevar_pasajero", false)
		poke_field.set(&"trayectoria", 0)  # NINGUNA: el nodo queda libre para el surf
		poke_field.visible = false
		poke_field.position = Vector2.ZERO
		poke_field.scale = Vector2.ONE
		poke_field.rotation = 0.0
		poke_field.z_index = 0
	if otras:
		otras.visible = false
		otras.position = Vector2(-16, -30)
	if poke64:
		poke64.visible = false
	sombra.visible = false
	var basico := get_node_or_null("basico") as AnimatedSprite2D
	if basico:
		basico.visible = true
		basico.position = Vector2.ZERO
		animated_sprite = basico

## =============================
## Destello
## =============================

## Motivo de pausa mientras se usa DESTELLO (animación y apertura del círculo).
const PAUSA_DESTELLO := &"destello"
const SONIDO_DESTELLO := "SE_M_REFLECT"

## DESTELLO desde el menú del Pokémon (sub_810CBFC / sub_810CC34 de pokeruby): el
## Pokémon sale como en SURF (mov_campo_inicio), suena SE_M_REFLECT, se activa la
## bandera de Destello y la oscuridad de la cueva abre su círculo de 24 a 72 px
## (EfectoOscuridadCueva lo anima solo al ver la bandera). Sin texto. El menú ya
## comprobó medalla, cueva oscura y que no se hubiera usado.
func usar_destello(pokemon) -> void:
	Singleton.mantener_pausa(PAUSA_DESTELLO, true)
	no_control = true
	paso_en_curso = false
	await _reproducir_mov_campo(pokemon)
	_reproducir_sonido_campo(SONIDO_DESTELLO)
	EfectoOscuridadCueva.activar_destello()
	await get_tree().create_timer(EfectoOscuridadCueva.duracion_destello()).timeout
	no_control = false
	Singleton.mantener_pausa(PAUSA_DESTELLO, false)

## Pose de mov_campo_inicio del Pokémon `pokemon` (DESTELLO, FUERZA...): el Pokémon
## sale, el jugador hace la pose y todo vuelve a como estaba (en bici o surfeando
## también). Sin las animaciones (girl.tscn aún no las tiene) no hace nada.
func _reproducir_mov_campo(pokemon, vigente: Callable = Callable()) -> void:
	var anim_campo := anim_mov_campo()
	if (en_surf or en_buceo) and animador != null and animador.has_animation(anim_campo):
		await _animar_mov_campo_surfeando(pokemon, vigente)
	elif not en_surf and not en_buceo and animador != null and animador.has_animation(anim_campo):
		var direccion: Vector2 = facing_direction
		var bici_previa := en_bicicleta
		var tipo_previo := tipo_bici
		_preparar_sprites_para_vuelo()
		preparar_pokemon_mov_campo(pokemon)
		animador.play(anim_campo)
		await _esperar_pose_mov_campo(vigente)
		_restaurar_nodos_mov_campo()
		_pokemon_mov_campo = null
		if bici_previa:
			# El GBA devuelve el avatar a la bici tras la pose de movimiento de campo.
			restaurar_estado_guardado(direccion, true, false, tipo_previo)
		else:
			facing_direction = direccion
			_actualizar_animacion_idle()

## Una sesión cancelable puede cortar su pose sin dejar sprites/animación activos.
## Las llamadas previas sin guarda conservan su espera original por la señal.
func _esperar_pose_mov_campo(vigente: Callable) -> void:
	if not vigente.is_valid():
		await animador.animation_finished
		return
	var pose: StringName = animador.current_animation
	while animador.is_playing() and animador.current_animation == pose and vigente.is_valid() and vigente.call():
		await get_tree().process_frame
	if animador.is_playing() and animador.current_animation == pose:
		animador.stop()


## Motivo de pausa de la pose de un puzle en braille.
const PAUSA_PUZLE_BRAILLE := &"puzle_braille_pose"

## FLDEFF_USE_STRENGTH / FLDEFF_USE_DIG / FLDEFF_USE_FLY_ANCIENT_TOMB sobre un puzle en braille
## (braille_puzzles.c): solo sale el Pokémon; la cámara la abre PuzleBraille al terminar.
func usar_movimiento_braille(pokemon) -> void:
	Singleton.mantener_pausa(PAUSA_PUZLE_BRAILLE, true)
	no_control = true
	paso_en_curso = false
	await _reproducir_mov_campo(pokemon)
	Singleton.mantener_pausa(PAUSA_PUZLE_BRAILLE, false)


## =============================
## Fuerza
## =============================

## Motivo de pausa mientras se usa FUERZA (pose y mensaje).
const PAUSA_FUERZA := &"fuerza"
const MOVIMIENTO_FUERZA := "FUERZA"
## UsedStrengthText de la ROM española oficial (mirubi, FieryPath). {POKEMON} lo
## sustituye el nombre del Pokémon.
const TEXTO_FUERZA_USADA := "{POKEMON} usó FUERZA.\\lLa FUERZA de {POKEMON} logró\ndesplazar la roca a un lado."
signal _fuerza_mensaje_terminado

## UseStrength / UsedStrength de pokeruby (field_move_scripts.inc): el Pokémon
## sale (FLDEFF_USE_STRENGTH), se activa FLAG_SYS_USE_STRENGTH y se muestra el
## texto. Lo llaman la roca (tras aceptar la pregunta) y el menú del Pokémon. La
## comprobación de medalla y Pokémon es de quien llama.
func usar_fuerza(pokemon) -> void:
	Singleton.mantener_pausa(PAUSA_FUERZA, true)
	no_control = true
	paso_en_curso = false
	await _reproducir_mov_campo(pokemon)
	ControladorRocaFuerza.activar_fuerza()
	var dialogo = nodo_administrador.cuadro_dialogo if nodo_administrador != null else null
	if dialogo != null and pokemon != null:
		var texto := TEXTO_FUERZA_USADA.replace("{POKEMON}", pokemon.get_nombre_mostrar())
		start_dialog()
		dialogo.mostrar(texto, true, true, _fuerza_mensaje_terminado.emit)
		await _fuerza_mensaje_terminado
		end_dialog()
	no_control = false
	Singleton.mantener_pausa(PAUSA_FUERZA, false)

## Motivo de pausa mientras se usa GOLPE ROCA (mensaje, pose y rotura).
const PAUSA_GOLPE_ROCA := &"golpe_roca"
## UsedCutRockSmashText de pokeruby en la ROM española oficial.
const TEXTO_GOLPE_ROCA_USADO := "{POKEMON} usó GOLPE ROCA."

## S_BreakableRock / S_UseRockSmash de pokeruby: con `con_mensaje` (A frente a la
## roca) primero "X usó GOLPE ROCA."; después sale el Pokémon (FLDEFF_USE_ROCK_SMASH)
## y la roca se rompe. Desde el menú del Pokémon va sin mensaje. La medalla y el
## Pokémon los comprueba quien llama.
func usar_golpe_roca(pokemon, roca: ControladorRocaRomper, con_mensaje: bool) -> void:
	if not is_instance_valid(roca):
		return
	Singleton.mantener_pausa(PAUSA_GOLPE_ROCA, true)
	no_control = true
	paso_en_curso = false
	var dialogo = nodo_administrador.cuadro_dialogo if nodo_administrador != null else null
	if con_mensaje and dialogo != null and pokemon != null:
		var texto := TEXTO_GOLPE_ROCA_USADO.replace("{POKEMON}", pokemon.get_nombre_mostrar())
		start_dialog()
		dialogo.mostrar(texto, true, true, _fuerza_mensaje_terminado.emit)
		await _fuerza_mensaje_terminado
		end_dialog()
	await _reproducir_mov_campo(pokemon)
	if is_instance_valid(roca):
		await roca.romper()
	if nodo_administrador != null and nodo_administrador.has_method("intentar_encuentro_golpe_roca"):
		await nodo_administrador.intentar_encuentro_golpe_roca()
	no_control = false
	Singleton.mantener_pausa(PAUSA_GOLPE_ROCA, false)

## Motivo de pausa mientras se usa CORTE (mensaje, pose y corte).
const PAUSA_CORTE := &"corte"
## UsedCutRockSmashText de la ROM española oficial ("{FD:02} usó {FD:03}.", texto
## compartido con GOLPE ROCA; el movimiento es CORTE).
const TEXTO_CORTE_USADO := "{POKEMON} usó CORTE."
## GAME_STAT_USED_CUT: FldEff_UseCutOnTree y FldEff_UseCutOnGrass lo incrementan
## al empezar el efecto (SistemaGuardado.datos_persistentes.contadores).
const CONTADOR_CORTES_USADOS := "cortes_usados"

## S_CuttableTree / DoCutFieldEffectScript de pokeruby: con `con_mensaje` (A frente
## al árbol) primero "X usó CORTE."; después sale el Pokémon (FLDEFF_USE_CUT_ON_TREE)
## y el árbol se corta. Desde el menú del Pokémon va sin mensaje. La medalla y el
## Pokémon los comprueba quien llama.
func usar_corte(pokemon, arbol: ControladorArbolCortable, con_mensaje: bool) -> void:
	if not is_instance_valid(arbol):
		return
	Singleton.mantener_pausa(PAUSA_CORTE, true)
	no_control = true
	paso_en_curso = false
	SistemaGuardado.incrementar_contador(CONTADOR_CORTES_USADOS)
	var dialogo = nodo_administrador.cuadro_dialogo if nodo_administrador != null else null
	if con_mensaje and dialogo != null and pokemon != null:
		var texto := TEXTO_CORTE_USADO.replace("{POKEMON}", pokemon.get_nombre_mostrar())
		start_dialog()
		dialogo.mostrar(texto, true, true, _fuerza_mensaje_terminado.emit)
		await _fuerza_mensaje_terminado
		end_dialog()
	await _reproducir_mov_campo(pokemon)
	if is_instance_valid(arbol):
		await arbol.cortar()
	no_control = false
	Singleton.mantener_pausa(PAUSA_CORTE, false)

## FieldCallback_CutGrass / FLDEFF_USE_CUT_ON_GRASS de pokeruby: el Pokémon sale,
## el jugador hace la pose y FldEff_CutGrass corta la hierba del cuadrado 3x3
## centrado en su celda (SE_M_CUT, cambio de tiles y las 8 hojas). Solo se usa
## desde el menú del Pokémon, así que `con_mensaje` es false salvo que se pida
## "X usó CORTE." La medalla y que haya hierba cortable los comprueba quien llama.
func usar_corte_hierba(pokemon, con_mensaje: bool = false) -> void:
	var mapa := _obtener_mapa_actual()
	var hierba := mapa.obtener_hierba_cortable() if mapa != null else null
	if hierba == null:
		return
	Singleton.mantener_pausa(PAUSA_CORTE, true)
	no_control = true
	paso_en_curso = false
	SistemaGuardado.incrementar_contador(CONTADOR_CORTES_USADOS)
	var dialogo = nodo_administrador.cuadro_dialogo if nodo_administrador != null else null
	if con_mensaje and dialogo != null and pokemon != null:
		var texto := TEXTO_CORTE_USADO.replace("{POKEMON}", pokemon.get_nombre_mostrar())
		start_dialog()
		dialogo.mostrar(texto, true, true, _fuerza_mensaje_terminado.emit)
		await _fuerza_mensaje_terminado
		end_dialog()
	await _reproducir_mov_campo(pokemon)
	_get_coord_tile_act()
	# Las hojas salen a la altura de la cintura (oam.y + 20 de un sprite de 32 px).
	await hierba.cortar_alrededor(pos_celda_act, Singleton.capa_activa, global_position + Vector2(0, -10))
	# La celda del jugador pudo dejar de ser hierba muy alta: se apaga su efecto.
	actualizar_efecto_terreno_actual()
	no_control = false
	Singleton.mantener_pausa(PAUSA_CORTE, false)

## FldEff_UseWaterfall de pokeruby: sale el Pokémon (con
## `con_mensaje`, antes "X usó CASCADA."; desde el menú va sin mensaje) y el jugador
## sube al norte a velocidad de caminar mientras la celda en la que está tenga la
## bandera CASCADA. Sigue surfeando al terminar. La medalla y la cascada delante
## las comprueba quien llama.
func usar_cascada(pokemon, con_mensaje: bool = false) -> void:
	if not en_surf:
		return
	Singleton.mantener_pausa(PAUSA_CASCADA, true)
	no_control = true
	paso_en_curso = false
	var dialogo = nodo_administrador.cuadro_dialogo if nodo_administrador != null else null
	if con_mensaje and dialogo != null and pokemon != null:
		var texto := TEXTO_CASCADA_USADA.replace("{POKEMON}", pokemon.get_nombre_mostrar())
		start_dialog()
		dialogo.mostrar(texto, true, true, _fuerza_mensaje_terminado.emit)
		await _fuerza_mensaje_terminado
		end_dialog()
	await _reproducir_mov_campo(pokemon)
	await _subir_cascada()
	no_control = false
	Singleton.mantener_pausa(PAUSA_CASCADA, false)

## Pasos al norte forzados: el primero siempre; los siguientes mientras la celda
## actual sea CASCADA (IsWaterfall). Termina si algo bloquea el paso o el jugador
## sale del árbol. Siempre deja `_subiendo_cascada` en false.
func _subir_cascada() -> void:
	_subiendo_cascada = true
	var guarda := 64
	while guarda > 0 and is_inside_tree():
		guarda -= 1
		facing_direction = Vector2.UP
		_get_coord_tile_act()
		if not can_move(Vector2.UP):
			break
		_iniciar_paso_manual(Vector2.UP, float(Singleton.TILE_SIZE) / VELOCIDAD_SUBIDA_CASCADA)
		while paso_en_curso and is_inside_tree():
			await get_tree().process_frame
		if not is_inside_tree():
			break
		_get_coord_tile_act()
		var tp := _obtener_tp_capa_actual()
		if tp == null or not tp.has_flag(Vector2(pos_celda_act), TPTileDataMap.Flags.CASCADA):
			break
	_subiendo_cascada = false
	if is_inside_tree():
		facing_direction = Vector2.UP
		_actualizar_animacion_idle()
		_actualizar_poke_field_dir()
		# Si la subida se cortó sobre la cascada, esta lo vuelve a empujar abajo.
		_procesar_suelo_forzado()

## TryPushBoulder (sub_8058F6C de pokeruby): con FUERZA activa, la roca de la
## celda a la que se mira se desliza una celda en la dirección del jugador si
## hay sitio. Sin FUERZA o sin roca delante no hace nada. Devuelve true solo si
## la roca empieza a deslizarse (en ese caso no suena el choque).
func _intentar_empujar_roca() -> bool:
	if nodo_administrador == null or not ControladorRocaFuerza.fuerza_activa():
		return false
	var roca = nodo_administrador.next_to_npc(pos_celda_sig)
	if roca is ControladorRocaFuerza:
		return roca.empujar(Vector2i(facing_direction))
	return false

## mov_campo_inicio sin bajarse del Pokémon de SURF: se desactivan las pistas de
## poke_field (esconden el Pokémon de vuelo), así que la montura sigue visible y
## con su balanceo mientras el jugador hace la pose (`otras`). Al terminar el
## jugador vuelve a sentarse mirando como antes. Sigue en surf todo el rato.
func _animar_mov_campo_surfeando(pokemon, vigente: Callable = Callable()) -> void:
	var direccion: Vector2 = facing_direction
	var anim_campo := anim_mov_campo()
	# Bajo el agua (rom6.c, MAP_TYPE_UNDERWATER) no hay pose de sacar la ball: solo
	# FLDEFF_FIELD_MOVE_SHOW_MON_INIT, así que el sprite `bucear_*` se queda tal cual.
	var prefijos := PackedStringArray(["poke_field"])
	if en_buceo:
		prefijos.append_array(["basico", "otras"])
	_activar_pistas_mov_campo(anim_campo, prefijos, false)
	preparar_pokemon_mov_campo(pokemon)
	animador.play(anim_campo)
	await _esperar_pose_mov_campo(vigente)
	_activar_pistas_mov_campo(anim_campo, prefijos, true)
	_pokemon_mov_campo = null
	if poke64:
		poke64.visible = false
	var basico := get_node_or_null("basico") as AnimatedSprite2D
	if basico:
		basico.visible = false
	if otras:
		otras.visible = true
		otras.position = Vector2(-16, -30)
	animated_sprite = otras
	if poke_field:
		# Bajo el agua no hay Pokémon a la vista.
		poke_field.visible = not en_buceo
		poke_field.position = Vector2.ZERO
	facing_direction = direccion
	_actualizar_animacion_idle()
	_actualizar_poke_field_dir()

## Activa o desactiva las pistas de `nombre_anim` cuyos nodos empiezan por algún
## prefijo de `prefijos` (la animación es compartida: hay que volver a activarlas).
func _activar_pistas_mov_campo(nombre_anim: StringName, prefijos: PackedStringArray, activar: bool) -> void:
	var animacion := animador.get_animation(nombre_anim)
	for pista: int in animacion.get_track_count():
		var ruta := str(animacion.track_get_path(pista))
		for prefijo: String in prefijos:
			if ruta.begins_with(prefijo):
				animacion.track_set_enabled(pista, activar)
				break

## Reproductor propio y sin posición para los sonidos de campo (Destello, caída):
## el AudioStreamPlayer2D del administrador atenúa por distancia a su origen.
func _reproducir_sonido_campo(sonido: String) -> void:
	if not is_instance_valid(_reproductor_campo):
		_reproductor_campo = AudioStreamPlayer.new()
		_reproductor_campo.name = "ReproductorCampo"
		add_child(_reproductor_campo)
	_reproductor_campo.stream = Singleton.se[sonido]
	_reproductor_campo.play()

## DoWateringBerryTreeAnim: el jugador riega mirando a su dirección con la pose
## `regar_*` del nodo `otras` durante `duracion` segundos y vuelve a `basico`.
## En surf o bici (o sin la animación) no hay pose: solo espera.
func animar_regar(duracion: float) -> void:
	var basico := get_node_or_null("basico") as AnimatedSprite2D
	var anim_regar := &"regar_" + _get_dir_string()
	if en_surf or en_bicicleta or otras == null or basico == null \
			or not otras.sprite_frames.has_animation(anim_regar):
		await get_tree().create_timer(duracion).timeout
		return
	basico.visible = false
	otras.position = Vector2(-16, -30)
	otras.visible = true
	otras.play(anim_regar)
	await get_tree().create_timer(duracion).timeout
	otras.stop()
	otras.visible = false
	basico.visible = true

## =============================
## Teletransporte
## =============================

## Motivo de pausa de todo TELETRANSPORTE (sobrevive al warp, como PAUSA_VUELO).
const PAUSA_TELETRANSPORTE := &"teletransporte"
const SONIDO_TELETRANSPORTE := "SE_WARP_IN"
## TeleportFieldEffectTask2: gira cada 8 frames y, tras más de 7 giros y de
## nuevo mirando a su dirección inicial, empieza a subir.
const FRAMES_GIRO_TELETRANSPORTE := 8
const GIROS_SALIDA_TELETRANSPORTE := 8
## TeleportFieldEffectTask3 y sub_8087ED8: en el aire gira cada 4 frames.
const FRAMES_GIRO_RAPIDO_TELETRANSPORTE := 4
## TeleportFieldEffectTask3: sube 1 px/frame los 8 primeros frames y luego la
## velocidad se duplica cada 4 frames hasta 8; a 168 px (0xA8) se funde.
const FRAMES_PRIMERA_VELOCIDAD_SUBIDA := 8
const FRAMES_ACELERACION_SUBIDA := 4
const VELOCIDAD_MAX_TELETRANSPORTE := 8
const ALTURA_SALIDA_TELETRANSPORTE := 168
## sub_8087ED8: baja a 8 px/frame y, desde 48 px por encima de su sitio, la
## velocidad baja 1 en cada posición par hasta 1.
const VELOCIDAD_LLEGADA_TELETRANSPORTE := 8
const ALTURA_FRENADA_TELETRANSPORTE := 48
## sub_8087FDC: en el suelo gira cada 8 frames y para tras más de 4 giros
## mirando al norte (Rubí compara con subspriteMode, que vale 2 = DIR_NORTH).
const GIROS_LLEGADA_TELETRANSPORTE := 4
const DIRECCION_FINAL_TELETRANSPORTE := Vector2.UP

## Orden de los giros de TELETRANSPORTE (spinDirections de field_effect.c,
## igual a la ida y a la vuelta): abajo → izquierda → arriba → derecha → abajo.
static func siguiente_giro_teletransporte(direccion: Vector2) -> Vector2:
	if direccion == Vector2.DOWN:
		return Vector2.LEFT
	if direccion == Vector2.LEFT:
		return Vector2.UP
	if direccion == Vector2.UP:
		return Vector2.RIGHT
	return Vector2.DOWN

## Píxeles que sube el sprite en cada frame de TeleportFieldEffectTask3 hasta
## llegar a ALTURA_SALIDA_TELETRANSPORTE.
static func pasos_subida_teletransporte() -> Array[int]:
	var pasos: Array[int] = []
	var velocidad := 1
	var frames_para_acelerar := FRAMES_PRIMERA_VELOCIDAD_SUBIDA
	var subido := 0
	while subido < ALTURA_SALIDA_TELETRANSPORTE:
		pasos.append(velocidad)
		subido += velocidad
		frames_para_acelerar -= 1
		if frames_para_acelerar <= 0:
			frames_para_acelerar = FRAMES_ACELERACION_SUBIDA
			velocidad = mini(velocidad * 2, VELOCIDAD_MAX_TELETRANSPORTE)
	return pasos

## Desplazamiento vertical del sprite (negativo = por encima de su sitio) en
## cada frame de la bajada de sub_8087ED8, desde `inicio` hasta 0.
static func posiciones_llegada_teletransporte(inicio: int) -> Array[int]:
	var posiciones: Array[int] = []
	var y := mini(inicio, 0)
	var velocidad := VELOCIDAD_LLEGADA_TELETRANSPORTE
	while y < 0:
		y += velocidad
		if y >= -ALTURA_FRENADA_TELETRANSPORTE and velocidad > 1 and y % 2 == 0:
			velocidad -= 1
		posiciones.append(mini(y, 0))
	return posiciones

## TELETRANSPORTE desde el menú del Pokémon (FieldCallback_Teleport): a pie y
## sin Destello, el Pokémon sale como en los demás movimientos de campo, el
## jugador gira, suena SE_WARP_IN y sube girando hasta salir de la pantalla;
## warp al último punto de curación y, al aclarar, baja girando desde encima de
## la pantalla (otro SE_WARP_IN) y termina mirando al norte. El menú ya
## comprobó que el mapa no es interior.
func usar_teletransporte(pokemon) -> void:
	if nodo_administrador == null or not nodo_administrador.has_method("teletransportar_a_punto_curacion"):
		push_error("[TELETRANSPORTE] Sin AdministradorMapa: no se puede hacer el warp")
		return
	Singleton.mantener_pausa(PAUSA_TELETRANSPORTE, true)
	no_control = true
	paso_en_curso = false
	contador_bici = 0
	var direccion: Vector2 = facing_direction
	_dejar_montura_en_agua()
	reiniciar_estado_por_teletransporte()
	var anim_campo := anim_mov_campo()
	if animador != null and animador.has_animation(anim_campo):
		preparar_pokemon_mov_campo(pokemon)
		animador.play(anim_campo)
		await animador.animation_finished
	_restaurar_nodos_mov_campo()
	_pokemon_mov_campo = null
	facing_direction = direccion
	_actualizar_animacion_idle()

	var sprite := animated_sprite as AnimatedSprite2D
	var offset_base: Vector2 = sprite.offset if sprite != null else Vector2.ZERO
	if not has_meta(&"z_index_base"):
		set_meta(&"z_index_base", posmod(z_index, Singleton.Z_INDEX_POR_CAPA))  # que Singleton conserve la base al restaurar
	await _teletransporte_salida(sprite, offset_base)
	_retirar_montura_del_agua()

	# Fuera de pantalla durante el warp: conectar_escalera vuelve a hacer
	# visible al jugador al colocarlo, antes de que se aclare.
	if sprite != null:
		sprite.offset.y = offset_base.y - OFFSET_OCULTO_CAIDA
	if not nodo_administrador.teletransportar_a_punto_curacion():
		_terminar_teletransporte(sprite, offset_base)
		return
	while nodo_administrador.coneccion != 0:
		await get_tree().process_frame
	no_control = true
	await get_tree().create_timer(0.3).timeout  # duración de telon.aclarar()
	await _teletransporte_llegada(sprite, offset_base)
	_terminar_teletransporte(sprite, offset_base)

## Overworld_ResetStateAfterTeleport + SetPlayerAvatarTransitionFlags(ON_FOOT):
## el jugador queda a pie (sin bici ni surf) y se apagan Destello y el CAMINO de BICIS.
func reiniciar_estado_por_teletransporte() -> void:
	EfectoOscuridadCueva.apagar_destello()
	CaminoBici.apagar()
	_preparar_sprites_para_vuelo()

## TeleportFieldEffectTask2 y 3: gira en el sitio, suena SE_WARP_IN y sube
## girando y acelerando hasta ALTURA_SALIDA_TELETRANSPORTE.
func _teletransporte_salida(sprite: AnimatedSprite2D, offset_base: Vector2) -> void:
	if not (facing_direction in [Vector2.DOWN, Vector2.LEFT, Vector2.UP, Vector2.RIGHT]):
		facing_direction = Vector2.DOWN
	var direccion_inicial: Vector2 = facing_direction
	var giros := 0
	while true:
		_girar_teletransporte()
		giros += 1
		if giros >= GIROS_SALIDA_TELETRANSPORTE and facing_direction == direccion_inicial:
			break
		await _esperar_ticks_teletransporte(FRAMES_GIRO_TELETRANSPORTE)
	_reproducir_sonido_campo(SONIDO_TELETRANSPORTE)
	z_index = Z_INDEX_VUELO  # por encima de árboles y techos, como en vuelo
	var frames_giro := FRAMES_GIRO_RAPIDO_TELETRANSPORTE
	var subido := 0
	for paso in pasos_subida_teletransporte():
		await _esperar_ticks_teletransporte(1)
		frames_giro -= 1
		if frames_giro <= 0:
			frames_giro = FRAMES_GIRO_RAPIDO_TELETRANSPORTE
			_girar_teletransporte()
		subido += paso
		if sprite != null:
			sprite.offset.y = offset_base.y - subido

## sub_8087E4C y sub_8087ED8: aparece justo por encima de la pantalla, suena
## SE_WARP_IN y baja girando cada 4 frames; sub_8087FDC: ya en el suelo gira
## cada 8 frames hasta haber girado más de 4 veces y mirar al norte.
func _teletransporte_llegada(sprite: AnimatedSprite2D, offset_base: Vector2) -> void:
	z_index = Z_INDEX_VUELO  # el warp reasigna el z_index del foco según la capa
	var inicio := -int(ceilf(_distancia_al_borde_superior()))
	# En el GBA el jugador va centrado y el inicio es par (-88); con un inicio
	# impar y velocidad 8 nunca se pisaría una posición par y no frenaría.
	if inicio % 2 != 0:
		inicio -= 1
	if sprite != null:
		sprite.offset.y = offset_base.y + inicio
	_reproducir_sonido_campo(SONIDO_TELETRANSPORTE)
	var frames_giro := 1
	for y in posiciones_llegada_teletransporte(inicio):
		await _esperar_ticks_teletransporte(1)
		if sprite != null:
			sprite.offset.y = offset_base.y + y
		frames_giro -= 1
		if frames_giro <= 0:
			frames_giro = FRAMES_GIRO_RAPIDO_TELETRANSPORTE
			_girar_teletransporte()
	if sprite != null:
		sprite.offset = offset_base
	var giros := 0
	while true:
		await _esperar_ticks_teletransporte(1)
		_girar_teletransporte()
		giros += 1
		if giros > GIROS_LLEGADA_TELETRANSPORTE and facing_direction == DIRECCION_FINAL_TELETRANSPORTE:
			break
		await _esperar_ticks_teletransporte(FRAMES_GIRO_TELETRANSPORTE - 1)

func _girar_teletransporte() -> void:
	facing_direction = siguiente_giro_teletransporte(facing_direction)
	_actualizar_animacion_idle()

## Espera `ticks` frames de física (60 por segundo, como los del GBA). Un
## temporizador de 1/60 s suele tardar dos frames de dibujo y las secuencias de
## frame a frame irían a la mitad de velocidad.
func _esperar_ticks_teletransporte(ticks: int) -> void:
	for i in range(ticks):
		await get_tree().physics_frame

## Deja el sprite en su sitio, el z_index de la capa y devuelve el control.
func _terminar_teletransporte(sprite: AnimatedSprite2D, offset_base: Vector2) -> void:
	if sprite != null:
		sprite.offset = offset_base
	Singleton._aplicar_z_index_foco_por_capa(Singleton.capa_activa)
	visible = true
	_get_coord_tile_act()
	_actualizar_animacion_idle()
	_change_state(PlayerState.IDLE)
	no_control = false
	Singleton.mantener_pausa(PAUSA_TELETRANSPORTE, false)

## =============================
## Cuerda Huida / Excavar
## =============================

## Motivo de pausa de toda la huida (sobrevive al warp, como PAUSA_TELETRANSPORTE).
const PAUSA_HUIDA := &"huida_cueva"
## EscapeRopeFieldEffect_Step0/1: a los 64 frames empieza el fundido a negro.
const FRAMES_HUIDA_HASTA_FUNDIDO := 64
## EscapeRopeFieldEffect_Step1: tras cada giro espera 8 >> (giros >> 2) frames,
## con el contador de giros topado en 12 (8, 4, 2 y 1 frame).
const GIROS_TOPE_SALIDA_HUIDA := 12
## sub_8087AC8: al llegar espera giros >> 2 frames (mínimo 1) entre giros, con el
## contador topado en 32, y para tras 32 giros mirando como al aparecer (sur).
const GIROS_LLEGADA_HUIDA := 32
## gOtherText_UsedItem ("{PLAYER} usó el {STR_VAR_2}."): el mismo texto que la
## mochila usa para el REPELENTE.
const TEXTO_CUERDA_HUIDA := "MOCHILA_USO_OBJETO"
signal _huida_mensaje_terminado

## Frames hasta el siguiente giro al salir, tras `giros` giros.
static func espera_giro_huida_salida(giros: int) -> int:
	return 8 >> (mini(giros, GIROS_TOPE_SALIDA_HUIDA) >> 2)

## Frames hasta el siguiente giro al llegar, tras `giros` giros.
static func espera_giro_huida_llegada(giros: int) -> int:
	return maxi(1, mini(giros, GIROS_LLEGADA_HUIDA) >> 2)

## CUERDA HUIDA en el campo tras cerrar la mochila (ItemUseOnFieldCB_EscapeRope):
## "{PN} usó {objeto}." y huida a la entrada exterior. La mochila ya comprobó que
## se puede usar (cueva y entrada guardada) y gastó la unidad.
func usar_cuerda_huida(nombre_objeto: String = "CUERDA HUIDA") -> void:
	Singleton.mantener_pausa(PAUSA_HUIDA, true)
	no_control = true
	paso_en_curso = false
	contador_bici = 0
	var dialogo = nodo_administrador.cuadro_dialogo if nodo_administrador != null else null
	if dialogo != null:
		dialogo.mostrar(tr(TEXTO_CUERDA_HUIDA).replace("{key}", nombre_objeto), true, true, _huida_mensaje_terminado.emit)
		await _huida_mensaje_terminado
	await _huir_a_entrada_exterior()

## EXCAVAR desde el menú del Pokémon (FldEff_UseDig): a pie, el Pokémon sale como
## en los demás movimientos de campo (mov_campo_inicio) y sigue la huida de la
## CUERDA HUIDA. Sin texto. El menú ya comprobó cueva y entrada guardada.
func usar_excavar(pokemon) -> void:
	Singleton.mantener_pausa(PAUSA_HUIDA, true)
	no_control = true
	paso_en_curso = false
	contador_bici = 0
	var direccion: Vector2 = facing_direction
	# SetPlayerAvatarTransitionFlags(ON_FOOT); Destello se apaga ya en negro.
	_dejar_montura_en_agua()
	_preparar_sprites_para_vuelo()
	var anim_campo := anim_mov_campo()
	if animador != null and animador.has_animation(anim_campo):
		preparar_pokemon_mov_campo(pokemon)
		animador.play(anim_campo)
		await animador.animation_finished
	_restaurar_nodos_mov_campo()
	_pokemon_mov_campo = null
	facing_direction = direccion
	_actualizar_animacion_idle()
	await _huir_a_entrada_exterior()

## StartEscapeRopeFieldEffect + mapldr_080859D4: gira en el sitio acelerando y a
## los 64 frames empieza el warp con fundido a la entrada exterior; con la
## pantalla en negro se reinicia el estado (Overworld_ResetStateAfterDigEscRope:
## a pie y sin Destello). Al aclarar aparece mirando al sur y gira parpadeando,
## cada vez más despacio, hasta dar 32 giros y volver a mirar al sur. Sin sonido.
func _huir_a_entrada_exterior() -> void:
	if nodo_administrador == null or not nodo_administrador.has_method("teletransportar_a_entrada_exterior"):
		push_error("[HUIDA] Sin AdministradorMapa: no se puede hacer el warp")
		_terminar_huida()
		return
	if not (facing_direction in [Vector2.DOWN, Vector2.LEFT, Vector2.UP, Vector2.RIGHT]):
		facing_direction = Vector2.DOWN
	var direccion_inicial: Vector2 = facing_direction
	var giros := 0
	var espera := 0
	var frame := 0
	var warp_iniciado := false
	while true:
		if frame == FRAMES_HUIDA_HASTA_FUNDIDO:
			if not nodo_administrador.teletransportar_a_entrada_exterior():
				_retirar_montura_del_agua()
				facing_direction = direccion_inicial
				_terminar_huida()
				return
			warp_iniciado = true
		# Fase 30 de conectar_escalera: ya en negro, cambia el mapa.
		if warp_iniciado and (nodo_administrador.coneccion >= 30 or nodo_administrador.coneccion == 0):
			break
		if espera <= 0:
			_girar_teletransporte()
			giros += 1
			espera = espera_giro_huida_salida(giros)
		await _esperar_ticks_teletransporte(1)
		espera -= 1
		frame += 1

	facing_direction = direccion_inicial
	_retirar_montura_del_agua()
	reiniciar_estado_por_teletransporte()
	_restaurar_nodos_mov_campo()
	_pokemon_mov_campo = null
	_actualizar_animacion_idle()
	var sprite := animated_sprite as AnimatedSprite2D
	if sprite != null:
		sprite.visible = false
	while nodo_administrador.coneccion != 0:
		await get_tree().process_frame
	no_control = true
	await get_tree().create_timer(0.3).timeout  # duración de telon.aclarar()
	await _huida_llegada(sprite)
	_terminar_huida()

## sub_8087AC8: gira cada vez más despacio alternando visible/oculto cada frame.
func _huida_llegada(sprite: AnimatedSprite2D) -> void:
	var direccion_llegada: Vector2 = facing_direction
	var giros := 0
	var espera := 0
	while true:
		if espera <= 0:
			if giros >= GIROS_LLEGADA_HUIDA and facing_direction == direccion_llegada:
				break
			_girar_teletransporte()
			giros = mini(giros + 1, GIROS_LLEGADA_HUIDA)
			espera = espera_giro_huida_llegada(giros)
		if sprite != null:
			sprite.visible = not sprite.visible
		await _esperar_ticks_teletransporte(1)
		espera -= 1

## Deja el sprite visible y devuelve el control.
func _terminar_huida() -> void:
	var sprite := animated_sprite as AnimatedSprite2D
	if sprite != null:
		sprite.visible = true
	visible = true
	_get_coord_tile_act()
	_actualizar_animacion_idle()
	_change_state(PlayerState.IDLE)
	no_control = false
	Singleton.mantener_pausa(PAUSA_HUIDA, false)

## =============================
## Caída por agujero
## =============================

## Motivo de pausa de toda la caída (sobrevive al warp, como PAUSA_VUELO).
const PAUSA_CAIDA := &"caida_agujero"
## S_FallDownHole: espera antes de desaparecer y tras el primer SE_FALL_RU_HYUU.
const FRAMES_ANTES_DE_CAER := 20
const FRAMES_TRAS_SONIDO_CAIDA := 60
## Velocidad de la caída en px/frame: empieza en 1 y se duplica hasta 8.
const VELOCIDAD_MAX_CAIDA := 8
const SONIDO_CAIDA := "SE_FALL_RU_HYUU"
const SONIDO_ATERRIZAJE := "SE_M_STRENGTH_ATERRIZAJE"
## Desplazamiento del sprite durante el warp para que, al reaparecer el jugador
## en la fase final de conectar_escalera, quede fuera de pantalla.
const OFFSET_OCULTO_CAIDA := 1000.0

var _reproductor_campo: AudioStreamPlayer = null
var _cayendo: bool = false

## S_FallDownHole + warphole + FieldCB_FallWarpExit: bloquea al jugador, espera
## 20 frames, lo oculta, suena SE_FALL_RU_HYUU, espera 60 frames y hace el warp
## con fundido a `mapa_destino` en la misma `celda`. Allí el sprite cae desde
## encima de la pantalla (1, 2, 4 y luego 8 px por frame, con otro
## SE_FALL_RU_HYUU), suena SE_M_STRENGTH_ATERRIZAJE y la cámara tiembla.
func _caer_por_agujero(mapa_destino: String, celda: Vector2i) -> void:
	if nodo_administrador == null:
		push_error("[AGUJERO] Sin AdministradorMapa: no se puede hacer el warp")
		return
	_cayendo = true
	Singleton.mantener_pausa(PAUSA_CAIDA, true)
	no_control = true
	paso_en_curso = false
	contador_bici = 0
	await _esperar_frames(FRAMES_ANTES_DE_CAER)
	visible = false
	_reproducir_sonido_campo(SONIDO_CAIDA)
	await _esperar_frames(FRAMES_TRAS_SONIDO_CAIDA)

	var sprite := animated_sprite as AnimatedSprite2D
	var offset_base: Vector2 = sprite.offset if sprite != null else Vector2.ZERO
	if sprite != null:
		sprite.offset.y = offset_base.y - OFFSET_OCULTO_CAIDA
	nodo_administrador.conectar_escalera(mapa_destino, Vector2(celda), facing_direction, false)
	# conectar_escalera avanza por frames desde el _process del administrador y
	# vuelve a 0 al colocar al jugador (visible) y empezar a aclarar.
	while nodo_administrador.coneccion != 0:
		await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout  # duración de telon.aclarar()
	visible = true

	await _animar_llegada_caida(sprite, offset_base, false)

	_get_coord_tile_act()
	_actualizar_animacion_idle()
	_change_state(PlayerState.IDLE)
	_cayendo = false
	no_control = false
	Singleton.mantener_pausa(PAUSA_CAIDA, false)

## FieldCB_FallWarpExit (sub_8086870..sub_80869B8), la llegada de toda caída: el sprite
## (pies en el origen) arranca justo por encima del borde superior de la pantalla y cae
## 1, 2, 4 y luego 8 px por frame con SE_FALL_RU_HYUU; al aterrizar suena
## SE_M_STRENGTH_ATERRIZAJE y la cámara tiembla. `con_polvo`: además levanta el polvo del
## salto (landingJump + triggerGroundEffectsOnStop), como al caer desde un saliente.
## `offset_base` es el `offset` del sprite sin desplazar.
func _animar_llegada_caida(sprite: AnimatedSprite2D, offset_base: Vector2, con_polvo: bool) -> void:
	var altura_pantalla := _distancia_al_borde_superior()
	var caida := -altura_pantalla
	if sprite != null:
		sprite.offset.y = offset_base.y + caida
	_reproducir_sonido_campo(SONIDO_CAIDA)
	var velocidad := 1
	while caida < 0.0:
		await _esperar_frames(1)
		caida = minf(caida + velocidad, 0.0)
		velocidad = mini(velocidad * 2, VELOCIDAD_MAX_CAIDA)
		if sprite != null:
			sprite.offset.y = offset_base.y + caida
	if sprite != null:
		sprite.offset = offset_base
	_reproducir_sonido_campo(SONIDO_ATERRIZAJE)
	if con_polvo:
		_get_coord_tile_act()
		levanta_polvo(pos_celda_act)
	var camara: Node = nodo_administrador.get("cam") if nodo_administrador != null else null
	if camara != null and camara.has_method("sacudir_vertical"):
		camara.call("sacudir_vertical")
		await get_tree().create_timer(camara.call("duracion_sacudida")).timeout

## Llegada de la caída al sótano del GIMNASIO de LAVACALDA: el mismo descenso que el
## agujero del suelo agrietado, con polvo al aterrizar. El llamador bloquea al jugador
## y lo deja invisible hasta aquí.
func animar_llegada_caida() -> void:
	var sprite := animated_sprite as AnimatedSprite2D
	var offset_base: Vector2 = sprite.offset if sprite != null else Vector2.ZERO
	if sprite != null:
		sprite.offset.y = offset_base.y - OFFSET_OCULTO_CAIDA
	visible = true
	await _animar_llegada_caida(sprite, offset_base, true)
	_get_coord_tile_act()
	_actualizar_animacion_idle()

## Un paso en el sitio de applymovement walk_in_place_fastest: alterna la pierna y muestra
## el fotograma de zancada la primera mitad de los `fotogramas` (a 60 fps) y el de reposo
## la segunda. No mueve al jugador ni toca su celda.
func caminar_en_sitio_guion(fotogramas: int = 4) -> void:
	alterna_animacion = 1 if alterna_animacion == 2 else 2
	_configurar_animacion_direccion("camina_", 1)
	await _esperar_frames(maxi(1, fotogramas / 2))
	_configurar_animacion_direccion("camina_", 0)
	await _esperar_frames(maxi(1, fotogramas - fotogramas / 2))

## Píxeles de mundo entre el borde superior de la pantalla y el origen del jugador.
func _distancia_al_borde_superior() -> float:
	if not is_inside_tree():
		return 0.0
	var escala := get_viewport().get_canvas_transform().get_scale()
	if is_zero_approx(escala.y):
		return 0.0
	return maxf(0.0, get_global_transform_with_canvas().origin.y / escala.y)

## Espera `frames` frames del GBA (a 60 fps).
func _esperar_frames(frames: int) -> void:
	await get_tree().create_timer(frames / 60.0).timeout

## =============================
## Pesca
## =============================

## Devuelve true si el tile al frente del jugador tiene la bandera SURF.
func _celda_frontal_tiene_surf() -> bool:
	var tp := _obtener_tp_capa_actual()
	if tp == null:
		return false
	_get_coord_tile_act()
	return tp.has_flag(Vector2(pos_celda_sig), TPTileDataMap.Flags.SURF)

## CanFish: true si el jugador puede lanzar la caña ahora (mirando al agua,
## quieto y fuera de un carril de bici). La mochila lo consulta antes de
## cerrarse: con el menú de pausa abierto el jugador está en LOCKED, así que
## ese estado no impide pescar (los demás bloqueos ya filtran el input).
func puede_pescar() -> bool:
	if en_pesca or paso_en_curso or state in [PlayerState.JUMPING, PlayerState.TALKING, PlayerState.FISHING]:
		return false
	# No se puede pescar si el tile actual requiere bicicleta
	if _tile_actual_requiere_bici():
		return false
	return _celda_frontal_tiene_surf()

## Intenta iniciar la pesca con la caña `nombre_cana` (nombre_interno) si las
## condiciones se cumplen.
func _intentar_pescar(nombre_cana: String = "CANAVIEJA") -> void:
	if puede_pescar():
		_iniciar_pesca(ReglasPesca.indice_cana(nombre_cana))

## PlayerTurnInPlace: mira hacia `direccion` sin moverse (BUSCAOBJETOS).
func girar_en_el_sitio(direccion: Vector2) -> void:
	facing_direction = direccion
	_get_coord_tile_act()
	_actualizar_animacion_idle()

## USAR una CAÑA desde la mochila (ItemUseOnFieldCB_Rod): ya en el campo.
func usar_cana(nombre_cana: String = "CANAVIEJA") -> void:
	_intentar_pescar(nombre_cana)

## StartFishing: oculta el sprite activo, muestra `pesca` con lanzar_<dir> y
## arranca el minijuego (Task_Fishing, ver ReglasPesca).
func _iniciar_pesca(cana: int = ReglasPesca.CANA_VIEJA) -> void:
	# Con el menú de pausa recién cerrado el jugador aún está en LOCKED.
	_pesca_estado_previo = state if state != PlayerState.LOCKED else PlayerState.IDLE
	_pesca_en_bici_previo = en_bicicleta
	_pesca_en_wheelie_previo = en_wheelie
	if animated_sprite:
		animated_sprite.visible = false
	_change_state(PlayerState.FISHING)
	en_pesca = true
	_pesca_cana = cana
	_pesca_a_pulsado = false
	if pesca:
		pesca.visible = true
		pesca.animation_finished.connect(_on_pesca_lanzada, CONNECT_ONE_SHOT)
		_pesca_reproducir(&"lanzar_")
	_ejecutar_pesca()

## Tras lanzar, la caña queda en el agua (idle_<dir>).
func _on_pesca_lanzada() -> void:
	if en_pesca and pesca and String(pesca.animation).begins_with("lanzar_"):
		_pesca_reproducir(&"idle_")

func _pesca_reproducir(prefijo: StringName) -> void:
	if pesca:
		pesca.play(StringName(String(prefijo) + _get_dir_string()))

## Task_Fishing (Fishing3..Fishing16): rondas de puntos, pique, tirón y
## resultado. Termina en encuentro salvaje o en "No pican..." / "Se ha escapado...".
func _ejecutar_pesca() -> void:
	var cuadro: Node = nodo_administrador.cuadro_dialogo if nodo_administrador != null else null
	var tiene_pesca: bool = nodo_administrador != null and nodo_administrador.has_method("mapa_tiene_pesca") \
		and bool(nodo_administrador.call("mapa_tiene_pesca"))
	var minimas: int = ReglasPesca.rondas_minimas(_pesca_cana, randi())
	var rondas: int = 0
	# Fishing3: un segundo antes de la primera ronda (A no cuenta).
	await _pesca_esperar(ReglasPesca.FRAMES_ESPERA_LANZAR)
	while true:
		# Fishing4/5: un punto cada 20 frames; A antes de tiempo falla.
		var requeridos: int = ReglasPesca.puntos_requeridos(rondas, randi())
		_pesca_texto_pasivo(cuadro, "")
		_pesca_a_pulsado = false
		for i: int in requeridos + 1:
			if await _pesca_esperar(ReglasPesca.FRAMES_POR_PUNTO):
				await _pesca_sin_captura(cuadro, "PESCA_NO_PICAN" if rondas == 0 else "PESCA_SE_HA_ESCAPADO")
				return
			if i < requeridos:
				_pesca_texto_pasivo(cuadro, ReglasPesca.texto_puntos(i + 1))
		# Fishing6: ¿pica?
		var pica: bool = ReglasPesca.pica(rondas, tiene_pesca, randi())
		rondas += 1
		if not pica:
			await _pesca_sin_captura(cuadro, "PESCA_NO_PICAN")
			return
		# Fishing7/8: "¡Oh! ¡Han picado!" y A antes del plazo de la caña.
		_pesca_reproducir(&"pique_")
		_pesca_texto_pasivo(cuadro, ReglasPesca.texto_puntos(requeridos) + "\n" + tr("PESCA_HAN_PICADO"))
		_pesca_a_pulsado = false
		if not await _pesca_esperar(ReglasPesca.plazo_tirar(_pesca_cana)):
			await _pesca_sin_captura(cuadro, "PESCA_SE_HA_ESCAPADO")
			return
		# Fishing9: otra ronda o enganchado.
		if not ReglasPesca.otra_ronda(_pesca_cana, rondas, minimas, randi()):
			break
	# Fishing10/11: "¡Un POKéMON ha picado el anzuelo!" y FishingWildEncounter.
	await _pesca_mensaje(cuadro, "PESCA_ANZUELO")
	_finalizar_pesca()
	if nodo_administrador != null and nodo_administrador.has_method("iniciar_encuentro_pesca"):
		nodo_administrador.call("iniciar_encuentro_pesca", ReglasPesca.clave_tabla(_pesca_cana))

## Fishing12..16: recoge la caña mientras sale el mensaje; al acabar la
## animación vuelve el sprite normal y, al cerrar el mensaje, el control.
func _pesca_sin_captura(cuadro: Node, clave: String) -> void:
	if pesca:
		pesca.animation_finished.connect(_pesca_restaurar_sprite, CONNECT_ONE_SHOT)
	_pesca_reproducir(&"recoger_")
	await _pesca_mensaje(cuadro, clave)
	if pesca and pesca.animation_finished.is_connected(_pesca_restaurar_sprite):
		pesca.animation_finished.disconnect(_pesca_restaurar_sprite)
	_finalizar_pesca()

func _pesca_restaurar_sprite() -> void:
	if pesca:
		pesca.visible = false
	if animated_sprite:
		animated_sprite.visible = true
	_actualizar_animacion_idle()

## Espera `frames` frames del GBA. Devuelve true si se pulsó A entretanto.
func _pesca_esperar(frames: int) -> bool:
	var restante: float = frames / 60.0
	while restante > 0.0:
		await get_tree().process_frame
		if not en_pesca:
			return false
		if _pesca_a_pulsado:
			_pesca_a_pulsado = false
			return true
		restante -= get_process_delta_time()
	return false

## Texto fijo en la caja (puntos, "¡Oh! ¡Han picado!") sin bloquear el input.
func _pesca_texto_pasivo(cuadro: Node, texto: String) -> void:
	if cuadro != null and cuadro.has_method("mostrar_inmediatamente"):
		cuadro.call("mostrar_inmediatamente", texto)

## Mensaje que espera a que el jugador pulse ({PAUSE_UNTIL_PRESS}).
func _pesca_mensaje(cuadro: Node, clave: String) -> void:
	if cuadro == null or not cuadro.has_method("mostrar"):
		return
	cuadro.call("mostrar", tr(clave), true, true, _pesca_mensaje_terminado.emit)
	await _pesca_mensaje_terminado

## Restaura el estado previo al de pesca.
func _finalizar_pesca() -> void:
	en_pesca = false
	_pesca_a_pulsado = false
	if pesca:
		pesca.stop()
		pesca.visible = false
	en_bicicleta = _pesca_en_bici_previo
	en_wheelie = _pesca_en_wheelie_previo
	if animated_sprite:
		animated_sprite.visible = true
	var prev := _pesca_estado_previo if _pesca_estado_previo != PlayerState.FISHING else PlayerState.IDLE
	_change_state(prev)
	_actualizar_animacion_idle()

## Logger simple para debug
func _logger(mensaje: String):
	print("[🤪 PLAYER] → %s" % mensaje)
