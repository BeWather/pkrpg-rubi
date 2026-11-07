class_name TransicionCentro
extends Node
## Coordinador de puertas, salidas, escaleras automáticas y, en el GIMNASIO de LAVACALDA,
## de los huecos de arena caliente y los géiseres; vive con el administrador.
## Ruby: field_fadetransition.c + field_effect.c:1172-1423 (escaleras) y
## field_effect.c:1534-1840 (DoLavaridgeGymB1FWarp y DoLavaridgeGym1FWarp).

## FldEff_LavaridgeGymWarp: el chorro de agua del géiser (5 fotogramas de 6 ticks).
const ESCENA_AGUA_GEISER: PackedScene = preload("res://escenas/mapas/animaciones/agua_geiser_gimnasio.tscn")
## FldEff_PopOutOfAsh: la nube de ceniza que traga al jugador y lo suelta.
const FRAMES_CENIZA: SpriteFrames = preload("res://graficos/efectos_campo/salir_de_ceniza.tres")
## 16x16 centrado en la celda del jugador (el origen del jugador está en la base de la celda).
const OFFSET_CENIZA := Vector2(-8, -14)
const OFFSET_AGUA_GEISER := Vector2(0, -6)
## sub_80876F8: cuatro pasos en el sitio (con SE_LAVARIDGE_FALL_WARP cada uno) antes de la ceniza.
const PASOS_HUNDIMIENTO := 4
const FOTOGRAMAS_PASO_HUNDIMIENTO := 4
const SONIDO_HUNDIMIENTO := "SE_LAVARIDGE_FALL_WARP"
const SONIDO_GEISER := "SE_M_EXPLOSION"
const SONIDO_SALIDA_ARENA := "SE_M_DIG"
## sub_8087264: la cámara tiembla (+1, -1...) estos fotogramas antes de que brote el agua.
const FOTOGRAMAS_PRESACUDIDA_GEISER := 8
## sub_80872E4: el jugador empieza a subir cuando el contador de la sacudida pasa de 6.
const CONTADOR_INICIO_ASCENSO := 6
## La velocidad de ascenso crece de 1 en 1 px/fotograma hasta 8.
const VELOCIDAD_MAX_ASCENSO := 8
const SEGUNDOS_POR_FOTOGRAMA := 1.0 / 60.0

signal fase_cambiada(fase: StringName)
signal terminada(exito: bool)
signal escalera_llegada_terminada
var activa := false
var administrador: Node = null
var _jugador: Node2D
var _puerta_llegada: Warp
var _escalera: EscaleraCentro
var _tipo: int
var _estilo: int
var _servicio := false
var _entrada_animada := false
var _dar_paso := false
var _inverso := false
var _radio := 0
var _ticks := 0
var _acumulado := 0.0
var _desplazar := false
var _sprite: Node2D
var _sprite_base := Vector2.ZERO
var _camara_base: Dictionary = {}
var _bloqueo_anterior := false
var _llegada_animada := false
var _offset_sprite_base: Variant = null
var _offset_camara_base: Variant = null

func _ready() -> void:
	if administrador == null:
		administrador = get_parent()

func iniciar(warp: Warp, preparacion_servicio: Callable = Callable()) -> bool:
	if activa or administrador.coneccion != 0 or not administrador.destino_warp_valido(warp.ruta_mapa_destino, warp.posicion_destino):
		return false
	if not warp.usa_coordinador() or (warp.es_servicio() and not preparacion_servicio.is_valid()):
		return false
	activa = true
	_jugador = administrador.jugador
	_bloqueo_anterior = bool(_jugador.get("_no_control_local"))
	_jugador.bloqueo_transicion = true
	_tipo = warp.tipo_warp
	_estilo = warp.estilo_warp
	_servicio = warp.es_servicio()
	_entrada_animada = warp.es_puerta_animada()
	_dar_paso = warp.dar_paso
	_llegada_animada = false
	var destino := warp.ruta_mapa_destino
	var celda := warp.posicion_destino
	var direccion := warp.direccion_llegada()
	_ejecutar(warp, destino, celda, direccion, preparacion_servicio)
	return true

func _ejecutar(warp: Warp, destino: String, celda: Vector2, direccion: Vector2, preparar: Callable) -> void:
	if _servicio:
		_fase(&"preparar_servicio")
		if not await preparar.call():
			_limpiar(false)
			return
		for paso: Vector2 in [Vector2.RIGHT, Vector2.UP, Vector2.UP]:
			await _jugador.caminar_guion(paso)
	if _entrada_animada:
		# Licencia respecto a Rubí (que entra en bici y deja a pie con la pantalla en
		# negro): si dentro no se permite la bici, el jugador se baja frente a la puerta.
		if administrador.has_method("destino_solo_caminar") and administrador.destino_solo_caminar(destino) \
				and _jugador.has_method("bajar_de_bicicleta_sin_musica"):
			_jugador.bajar_de_bicicleta_sin_musica()
		# Mirando hacia otro lado (p. ej. recién salido por la puerta), el jugador se gira
		# hacia ella antes de que se abra, no al dar el paso.
		if _jugador.has_method("girar_en_el_sitio"):
			_jugador.girar_en_el_sitio(Vector2.UP)
		_fase(&"abrir")
		Singleton.play_sound.emit(warp.sonido_puerta())
		await warp.animar_puerta(&"abrir_puerta")
		_fase(&"entrar")
		await _jugador.caminar_guion(Vector2.UP)
		_jugador.visible = false
		_fase(&"cerrar")
		await warp.animar_puerta(&"cerrar_puerta")
	elif _es_escalera():
		_inverso = _estilo == Singleton.EstiloWarp.ESCALERA_CENTRO_SUBIR
		_escalera = warp.obtener_efecto_escalera()
		_guardar_camara()
		if _escalera != null:
			_escalera.iniciar(_inverso)
		_preparar_sprite()
		_radio = 0
		_ticks = 0
		_acumulado = 0.0
		_desplazar = true
		_fase(&"escalera_salida")
		Singleton.play_sound.emit("SE_ESCALATOR")
		# Ruby inicia el fundido cuando radio > 3; sigue desplazando durante él.
		while _radio <= 3:
			await get_tree().process_frame
	elif _es_hueco():
		await _hundirse()
	elif _es_geiser():
		await _lanzarse()
	else:
		Singleton.play_sound.emit("puerta_salida")
	_fase(&"fundir")
	administrador.warp_perfil_preparado.connect(_preparar_llegada, CONNECT_ONE_SHOT)
	administrador.conectar_warp_perfil(destino, celda, direccion)
	var exito: bool = await administrador.warp_perfil_finalizado
	_desplazar = false
	if not exito:
		if administrador.warp_perfil_preparado.is_connected(_preparar_llegada):
			administrador.warp_perfil_preparado.disconnect(_preparar_llegada)
		_limpiar(false)
		return
	_fase(&"llegada")
	if _es_escalera():
		if not _llegada_animada:
			await escalera_llegada_terminada
		# sub_8086ED4 unlocks when scheduling this held eastward step.
		_jugador.caminar_guion(Vector2.RIGHT)
	elif _es_hueco():
		await _llegar_cayendo()
	elif _es_geiser():
		await _llegar_de_la_arena()
	elif is_instance_valid(_puerta_llegada):
		_jugador.visible = true
		await _jugador.caminar_guion(Vector2.DOWN)
		_fase(&"cerrar_llegada")
		await _puerta_llegada.animar_puerta(&"cerrar_puerta")
	elif _dar_paso:
		await _jugador.caminar_guion(_jugador.facing_direction)
	_limpiar(true)

func _preparar_llegada() -> void:
	_desplazar = false
	_restaurar_sprite()
	_puerta_llegada = administrador.warp_en_celda(administrador.mapa_actual,
		Vector2i(administrador.coneccion_posicion))
	if _es_escalera():
		if is_instance_valid(_escalera):
			_escalera.detener()
		_escalera = _puerta_llegada.obtener_efecto_escalera() if _puerta_llegada != null else null
		if _escalera != null:
			_escalera.iniciar(_inverso)
		_jugador.facing_direction = Vector2.RIGHT
		_jugador._actualizar_animacion_idle()
		_preparar_sprite()
		_radio = 16
		# Arrival uses the opposite slope to departure (Ruby's destination behavior).
		_poner_offset(offset_escalera(_radio, not _inverso))
		_fijar_camara()
		_animar_llegada_escalera()
	elif _es_hueco() or _es_geiser():
		# El jugador no se ve hasta que se aclara la pantalla: cae del cielo o sale de la ceniza.
		_puerta_llegada = null
		_jugador.visible = false
		# El ascenso del géiser ya no hace falta: el jugador reaparece en su sitio.
		_restaurar_ascenso()
	elif _puerta_llegada != null and _puerta_llegada.es_puerta_animada() and not _puerta_llegada.es_servicio():
		_puerta_llegada.establecer_abierta()
		_jugador.visible = false
	else:
		_puerta_llegada = null
	_fase(&"aclarar")

func _animar_llegada_escalera() -> void:
	var acumulado := 0.0
	var ticks := 0
	while _radio > 0:
		await get_tree().process_frame
		acumulado += get_process_delta_time()
		while acumulado >= 1.0 / 60.0 and _radio > 0:
			acumulado -= 1.0 / 60.0
			_poner_offset(offset_escalera(_radio, not _inverso))
			ticks += 1
			if ticks % 2 == 1:
				_radio -= 1
	_restaurar_sprite()
	if is_instance_valid(_escalera):
		await _escalera.finalizar()
	_restaurar_camara()
	_llegada_animada = true
	escalera_llegada_terminada.emit()

func _process(delta: float) -> void:
	if not _desplazar:
		return
	_acumulado += delta
	while _acumulado >= 1.0 / 60.0:
		_acumulado -= 1.0 / 60.0
		_poner_offset(offset_escalera(_radio, _inverso))
		_ticks += 1
		if _ticks % 2 == 1:
			_radio += 1

static func offset_escalera(radio: int, subiendo: bool) -> Vector2:
	# gSineTable / Cos/Sin Q8.8 (arithmetic right shift), not float sin/lerp.
	return Vector2((-254 * radio) >> 8, ((-120 if subiendo else 62) * radio) >> 8)

func _es_hueco() -> bool:
	return _tipo == Warp.TipoWarp.HUECOS

func _es_geiser() -> bool:
	return _tipo == Warp.TipoWarp.GEISERES

## sub_80876C8..sub_80877AC (DoLavaridgeGym1FWarp): el jugador da cuatro pasos en el sitio
## hundiéndose en la arena (SE_LAVARIDGE_FALL_WARP en cada uno), la nube de ceniza se lo
## traga (desaparece en su fotograma 2) y, cuando acaba, empieza el fundido.
func _hundirse() -> void:
	_fase(&"hundir")
	for _paso in PASOS_HUNDIMIENTO:
		Singleton.play_sound.emit(SONIDO_HUNDIMIENTO)
		await _jugador.caminar_en_sitio_guion(FOTOGRAMAS_PASO_HUNDIMIENTO)
	var ceniza := _crear_ceniza()
	while is_instance_valid(ceniza) and ceniza.is_playing() and ceniza.frame < 2:
		await get_tree().process_frame
	_jugador.visible = false
	while is_instance_valid(ceniza) and ceniza.is_playing():
		await get_tree().process_frame
	if is_instance_valid(ceniza):
		ceniza.queue_free()

## sub_8087470 con FieldCB_FallWarpExit: con la pantalla ya clara el jugador cae del borde
## superior (SE_FALL), aterriza con polvo y la cámara tiembla.
func _llegar_cayendo() -> void:
	_fase(&"caer")
	await _jugador.animar_llegada_caida()

## sub_80874CC..sub_808759C: el jugador sigue invisible mientras la ceniza estalla en su
## celda; al llegar la nube al fotograma 2 reaparece (SE_M_DIG) y salta una casilla hacia
## el este, como al bajar del camión de la mudanza.
func _llegar_de_la_arena() -> void:
	_fase(&"salir_arena")
	var ceniza := _crear_ceniza()
	while is_instance_valid(ceniza) and ceniza.is_playing() and ceniza.frame < 2:
		await get_tree().process_frame
	_jugador.visible = true
	Singleton.play_sound.emit(SONIDO_SALIDA_ARENA)
	await _jugador.saltar_guion(Vector2.RIGHT)
	while is_instance_valid(ceniza) and ceniza.is_playing():
		await get_tree().process_frame
	if is_instance_valid(ceniza):
		ceniza.queue_free()

## sub_808722C..sub_80873D8 (DoLavaridgeGymB1FWarp): la cámara tiembla, brota el agua
## (SE_M_EXPLOSION) y el jugador sube cada vez más rápido hasta salir por arriba de la
## pantalla mientras la sacudida crece hasta ±4 px y se apaga; después, el fundido.
func _lanzarse() -> void:
	_fase(&"lanzar")
	var camara := administrador.cam as Camera2D
	var sprite := _jugador.get("animated_sprite") as AnimatedSprite2D
	if camara != null:
		_offset_camara_base = camara.offset
	if sprite != null:
		_offset_sprite_base = sprite.offset
	var altura := _jugador._distancia_al_borde_superior() as float
	var sacudida := 1
	for _fotograma in FOTOGRAMAS_PRESACUDIDA_GEISER:
		_poner_sacudida(camara, sacudida)
		sacudida = -sacudida
		await _esperar_fotograma()
	var agua := _crear_agua_geiser()
	Singleton.play_sound.emit(SONIDO_GEISER)
	var contador := 0
	var velocidad := 1
	var subida := 0.0
	var arriba := false
	while true:
		_poner_sacudida(camara, sacudida)
		sacudida = -sacudida
		contador += 1
		if contador <= 17:
			if (contador & 1) == 0 and sacudida <= 3:
				sacudida <<= 1
		elif (contador & 4) == 0 and sacudida > 0:
			sacudida >>= 1
		if contador > CONTADOR_INICIO_ASCENSO and not arriba:
			if subida < altura:
				subida += velocidad
				if velocidad < VELOCIDAD_MAX_ASCENSO:
					velocidad += 1
				if sprite != null:
					sprite.offset.y = (_offset_sprite_base as Vector2).y - subida
			else:
				arriba = true
		if sacudida == 0 and arriba:
			break
		await _esperar_fotograma()
	_poner_sacudida(camara, 0)
	if is_instance_valid(agua):
		agua.queue_free()

func _poner_sacudida(camara: Camera2D, desplazamiento: int) -> void:
	if camara != null and _offset_camara_base != null:
		camara.offset = (_offset_camara_base as Vector2) + Vector2(0, desplazamiento)

func _esperar_fotograma() -> void:
	await get_tree().create_timer(SEGUNDOS_POR_FOTOGRAMA).timeout

## FLDEFF_POP_OUT_OF_ASH en la celda del jugador, delante de él.
func _crear_ceniza() -> AnimatedSprite2D:
	var efecto := AnimatedSprite2D.new()
	efecto.name = "CenizaGimnasio"
	efecto.centered = false
	efecto.offset = OFFSET_CENIZA
	efecto.sprite_frames = FRAMES_CENIZA
	efecto.position = _jugador.position
	efecto.z_index = 1
	_jugador.get_parent().add_child(efecto)
	efecto.play(&"default")
	return efecto

## FLDEFF_LAVARIDGE_GYM_WARP en la celda del jugador.
func _crear_agua_geiser() -> AnimatedSprite2D:
	var agua := ESCENA_AGUA_GEISER.instantiate() as AnimatedSprite2D
	agua.name = "AguaGeiserGimnasio"
	agua.position = _jugador.position + OFFSET_AGUA_GEISER
	agua.z_index = 1
	_jugador.get_parent().add_child(agua)
	return agua

## Devuelve al sprite y a la cámara el desplazamiento que el géiser les dio.
func _restaurar_ascenso() -> void:
	var sprite := _jugador.get("animated_sprite") as AnimatedSprite2D if is_instance_valid(_jugador) else null
	if sprite != null and _offset_sprite_base != null:
		sprite.offset = _offset_sprite_base
	var camara := administrador.cam as Camera2D if administrador != null else null
	if camara != null and _offset_camara_base != null:
		camara.offset = _offset_camara_base
	_offset_sprite_base = null
	_offset_camara_base = null

func _es_escalera() -> bool:
	return _tipo == Warp.TipoWarp.ESCALERAS and _estilo in [Singleton.EstiloWarp.ESCALERA_CENTRO_SUBIR, Singleton.EstiloWarp.ESCALERA_CENTRO_BAJAR]

func _preparar_sprite() -> void:
	_sprite = _jugador.get("animated_sprite") as Node2D
	if _sprite != null:
		_sprite_base = _sprite.position

func _poner_offset(valor: Vector2) -> void:
	if is_instance_valid(_sprite):
		_sprite.position = _sprite_base + valor

func _restaurar_sprite() -> void:
	if is_instance_valid(_sprite):
		_sprite.position = _sprite_base
	_sprite = null

func _guardar_camara() -> void:
	var cam: Node = administrador.cam
	_camara_base = {"override": cam.override_activo, "posicion": cam.posicion_override}
	_fijar_camara()

func _fijar_camara() -> void:
	administrador.cam.establecer_posicion_fija(_jugador.global_position - administrador.cam.centrar)

func _restaurar_camara() -> void:
	if _camara_base.is_empty():
		return
	if _camara_base["override"]:
		administrador.cam.establecer_posicion_fija(_camara_base["posicion"])
	else:
		administrador.cam.quitar_posicion_fija()
	_camara_base.clear()

func _limpiar(exito: bool) -> void:
	_desplazar = false
	_restaurar_sprite()
	_restaurar_camara()
	_restaurar_ascenso()
	if is_instance_valid(_escalera):
		_escalera.detener()
	_escalera = null
	if is_instance_valid(_jugador):
		_jugador.visible = true
		_jugador.no_control = _bloqueo_anterior
		_jugador.bloqueo_transicion = false
	_puerta_llegada = null
	activa = false
	_fase(&"terminada" if exito else &"abortada")
	terminada.emit(exito)

func _fase(valor: StringName) -> void:
	fase_cambiada.emit(valor)

func _exit_tree() -> void:
	if activa:
		_limpiar(false)
