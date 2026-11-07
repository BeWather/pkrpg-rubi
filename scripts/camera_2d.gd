extends Camera2D

const SPEED = 60
const tile_size = 16
var objetivo: Node2D = null
var pos_objetivo: Vector2
var centrar: Vector2 = Vector2(128, 88)
var en_foco: bool = false
var inmediato: bool = true

# Sistema de override temporal para posiciones fijas
var override_activo: bool = false
var posicion_override: Vector2 = Vector2.ZERO
var posicion_original_guardada: Vector2 = Vector2.ZERO

func _ready() -> void:
	# La cámara se actualiza después del jugador y los NPC: con la prioridad por
	# defecto iba un frame por detrás (a 4 px/frame de la bici, el jugador y los
	# efectos pegados a él, como la oscuridad de cueva, vibraban en pantalla).
	process_priority = 100


func _process(delta):
	_actualizar_posicion(delta)
	# Aplica ya la posición al canvas: si no, se aplicaría en el frame siguiente.
	if is_inside_tree():
		force_update_scroll()


func _actualizar_posicion(delta: float) -> void:
	# Si hay un override activo, mantener la posición fija
	if override_activo:
		global_position = posicion_override
		return
	
	# Comportamiento normal de la cámara
	if is_instance_valid(Singleton) and is_instance_valid(Singleton.foco_camara):
		objetivo = Singleton.foco_camara
		pos_objetivo = objetivo.global_position - centrar
		if en_foco:
			var distancia = global_position.distance_to(pos_objetivo)
			if distancia < 20:
				global_position = pos_objetivo
			else:
				en_foco = false
		else:
			if inmediato:
				global_position = pos_objetivo
				en_foco = true
			else:
				var direction = (pos_objetivo - global_position).normalized()
				global_position += direction * SPEED * delta
				#global_position = global_position.linear_interpolate(pos_objetivo, 2.0 / SPEED * tile_size)
				if global_position.distance_to(pos_objetivo) < 2:
					global_position = pos_objetivo
					en_foco = true

## ============================================================================
## SISTEMA DE OVERRIDE TEMPORAL
## ============================================================================

## Establece una posición fija para la cámara, deshabilitando el auto-enfoque
func establecer_posicion_fija(nueva_posicion: Vector2):
	if not override_activo:
		# Guardar la posición actual antes del override
		posicion_original_guardada = global_position
	
	posicion_override = nueva_posicion
	override_activo = true
	global_position = nueva_posicion
	print("🎥 [CÁMARA] Posición fija establecida: %s" % nueva_posicion)

## Quita el override y vuelve al comportamiento normal de la cámara
func quitar_posicion_fija():
	if override_activo:
		override_activo = false
		# Restaurar comportamiento normal - la cámara volverá a seguir al objetivo
		en_foco = false  # Forzar recálculo en el siguiente frame
		print("🎥 [CÁMARA] Override removido, volviendo al auto-enfoque")

## Verifica si la cámara tiene un override activo
func tiene_override_activo() -> bool:
	return override_activo

## Obtiene la posición original guardada antes del override
func obtener_posicion_original() -> Vector2:
	return posicion_original_guardada

## ============================================================================
## SACUDIDA VERTICAL
## ============================================================================

## Sacudida del aterrizaje tras caer por un agujero (sub_80869B8 de pokeruby,
## SetCameraPanning): el desplazamiento vertical cambia de signo cada frame
## (+4, -4, +4, -4) y se reduce a la mitad cada FRAMES_POR_AMPLITUD_SACUDIDA
## frames: ±4, ±2 y ±1 px. Mueve `offset` y lo deja como estaba al terminar.
const AMPLITUDES_SACUDIDA: Array[int] = [4, 2, 1]
const FRAMES_POR_AMPLITUD_SACUDIDA := 4
var _tween_sacudida: Tween = null
var _offset_base_sacudida: Vector2 = Vector2.ZERO

func sacudir_vertical() -> void:
	if _tween_sacudida != null and _tween_sacudida.is_valid():
		_tween_sacudida.kill()
		offset = _offset_base_sacudida
	_offset_base_sacudida = offset
	_tween_sacudida = create_tween()
	for desplazamiento: int in obtener_desplazamientos_sacudida():
		_tween_sacudida.tween_callback(_poner_offset_sacudida.bind(Vector2(0, desplazamiento)))
		_tween_sacudida.tween_interval(1.0 / 60.0)
	_tween_sacudida.tween_callback(_poner_offset_sacudida.bind(Vector2.ZERO))

## Desplazamiento vertical de cada frame de la sacudida: 4, -4, 4, -4, 2, -2...
static func obtener_desplazamientos_sacudida() -> Array[int]:
	var desplazamientos: Array[int] = []
	for amplitud: int in AMPLITUDES_SACUDIDA:
		for frame: int in range(FRAMES_POR_AMPLITUD_SACUDIDA):
			desplazamientos.append(amplitud if frame % 2 == 0 else -amplitud)
	return desplazamientos

## Segundos que dura sacudir_vertical().
func duracion_sacudida() -> float:
	return AMPLITUDES_SACUDIDA.size() * FRAMES_POR_AMPLITUD_SACUDIDA / 60.0

## ShakeCamera de pokeruby (field_specials.c, sub_810F7A8): cada FRAMES_POR_PASO_TEMBLOR
## frames cambia de signo el desplazamiento (horizontal = VAR_0x8005, vertical =
## VAR_0x8004) y lo aplica (SetCameraPanning); tras PASOS_TEMBLOR cambios la cámara
## vuelve a su sitio. Suena SE_M_STRENGTH al empezar.
const FRAMES_POR_PASO_TEMBLOR := 5
const PASOS_TEMBLOR := 8
const SONIDO_TEMBLOR := "SE_M_STRENGTH_ATERRIZAJE"

func sacudir_camara(horizontal: int, vertical: int) -> void:
	if _tween_sacudida != null and _tween_sacudida.is_valid():
		_tween_sacudida.kill()
		offset = _offset_base_sacudida
	_offset_base_sacudida = offset
	Singleton.play_sound.emit(SONIDO_TEMBLOR)
	_tween_sacudida = create_tween()
	for desplazamiento: Vector2 in obtener_desplazamientos_temblor(horizontal, vertical):
		_tween_sacudida.tween_interval(FRAMES_POR_PASO_TEMBLOR / 60.0)
		_tween_sacudida.tween_callback(_poner_offset_sacudida.bind(desplazamiento))
	_tween_sacudida.tween_callback(_poner_offset_sacudida.bind(Vector2.ZERO))

## SealedChamberShakingEffect (braille_puzzles.c): como ShakeCamera pero con `pasos` cambios
## de signo cada `frames_por_paso` fotogramas y sin sonido (el guion pone el suyo).
func sacudir_camara_pasos(horizontal: int, vertical: int, pasos: int, frames_por_paso: int) -> void:
	if _tween_sacudida != null and _tween_sacudida.is_valid():
		_tween_sacudida.kill()
		offset = _offset_base_sacudida
	_offset_base_sacudida = offset
	_tween_sacudida = create_tween()
	for desplazamiento: Vector2 in obtener_desplazamientos_temblor(horizontal, vertical, pasos):
		_tween_sacudida.tween_interval(frames_por_paso / 60.0)
		_tween_sacudida.tween_callback(_poner_offset_sacudida.bind(desplazamiento))
	_tween_sacudida.tween_callback(_poner_offset_sacudida.bind(Vector2.ZERO))

## Desplazamiento de cada paso de sacudir_camara: (-h, -v), (h, v), (-h, -v)...
static func obtener_desplazamientos_temblor(horizontal: int, vertical: int, pasos: int = PASOS_TEMBLOR) -> Array[Vector2]:
	var res: Array[Vector2] = []
	var actual := Vector2(horizontal, vertical)
	for _paso in pasos:
		actual = -actual
		res.append(actual)
	return res

## Segundos que dura sacudir_camara().
static func duracion_temblor() -> float:
	return PASOS_TEMBLOR * FRAMES_POR_PASO_TEMBLOR / 60.0

func _poner_offset_sacudida(desplazamiento: Vector2) -> void:
	offset = _offset_base_sacudida + desplazamiento
