class_name EfectosAgua
extends Node

## Efectos de agua al pisar de una entidad del overworld (jugador o NPC):
## salpicadura a los pies sobre AGUA_SALPICA / AGUA_PIES y ondas circulares solo
## sobre AGUA_SALPICA (AguaFX del mapa vía MapaConfiguracion.reproducir_onda).
##
## Solo a ras de agua: la capa de datos de la entidad debe admitirlos
## (TPTileDataMap.admite_efectos_agua(): capa 0 y sin bandera PUENTE_*), así que
## sobre un puente nunca salpica ni hace ondas aunque debajo haya agua.
##
## La entidad decide cuándo (inicio/fin de paso, aterrizajes…) y aporta cómo
## resolver su capa de datos y su mapa (Callables), además de su sprite de
## salpicadura: el jugador usa el nodo `salpicadura` de su escena y los NPC uno
## creado en código (crear_salpicadura_npc()).
##
## Ondas por paso: `cantidad_ondas` separadas `intervalo_ondas` segundos (jugador
## 2 a 0.5 s, NPC 1). Cada onda posterior a la primera vuelve a pedir el mapa: si
## cambió de mapa entre medias (null) ya no se reproduce.
##
## AGUA_PIES (charcos) es CONTINUA: la animación de los pies se repite mientras la
## entidad esté sobre la celda, también parada, y desaparece al salir de ella. La
## entidad informa del inicio y progreso de cada paso (`iniciar_paso`,
## `actualizar_progreso`: el agua pasa del tile de origen al de destino a mitad de
## paso, como la tierra de los pies) y de cuando queda quieta (`actualizar_reposo`);
## este nodo no consulta tiles por frame. AGUA_SALPICA sigue siendo una salpicadura
## puntual al pisar.

const TEXTURA_SALPICADURA_NPC: Texture2D = preload("res://graficos/character/salpica_agua_pies.png")
const ANIMACION_SALPICADURA := &"salpica"
## Banderas que disparan la salpicadura a los pies. Solo AGUA_SALPICA hace además
## ondas; AGUA_PIES (charcos) se queda en la animación de los pies.
const MASCARA_SALPICADURA: int = TPTileDataMap.Flags.AGUA_SALPICA | TPTileDataMap.Flags.AGUA_PIES
## Como la tierra de los pies, el agua pasa del tile de origen al de destino a mitad
## de paso (en píxeles recorridos).
const PIXELES_CAMBIO_TILE: float = 8.0

## Ondas que se reproducen por paso sobre AGUA_SALPICA.
var cantidad_ondas: int = 1
## Segundos entre ondas consecutivas del mismo paso.
var intervalo_ondas: float = 0.5
## Sprite de salpicadura de la entidad (puede ser null: sin salpicadura).
var salpicadura: AnimatedSprite2D = null

## La entidad está sobre AGUA_PIES ahora: la animación se repite sin parar.
var continua: bool = false

var _en_paso: bool = false
var _origen_pies: bool = false
var _destino_pies: bool = false

## () -> TPTileDataMap: capa de datos en la que está la entidad.
var _obtener_tp: Callable
## () -> MapaConfiguracion: mapa al que pedir las ondas.
var _obtener_mapa: Callable


func _init(
	obtener_tp: Callable = Callable(),
	obtener_mapa: Callable = Callable(),
	sprite_salpicadura: AnimatedSprite2D = null,
	ondas: int = 1,
	intervalo: float = 0.5
) -> void:
	name = "EfectosAgua"
	_obtener_tp = obtener_tp
	_obtener_mapa = obtener_mapa
	cantidad_ondas = maxi(ondas, 0)
	intervalo_ondas = maxf(intervalo, 0.0)
	_configurar_salpicadura(sprite_salpicadura)


## true si `tp` admite efectos de agua en `celda` y la celda es AGUA_SALPICA o
## AGUA_PIES (las dos disparan la salpicadura a los pies).
static func celda_admite_salpicadura(tp: TPTileDataMap, celda: Vector2) -> bool:
	return tp != null and tp.admite_efectos_agua(celda) \
		and (tp.get_flags(celda) & MASCARA_SALPICADURA) != 0


## true si `tp` admite efectos de agua en `celda` y la celda es AGUA_SALPICA: solo
## ella dispara las ondas circulares (AGUA_PIES salpica pero no hace ondas).
static func celda_admite_ondas(tp: TPTileDataMap, celda: Vector2) -> bool:
	return tp != null and tp.admite_efectos_agua(celda) \
		and tp.has_flag(celda, TPTileDataMap.Flags.AGUA_SALPICA)


## true si la celda (de la capa de datos actual de la entidad) es AGUA_SALPICA o
## AGUA_PIES a ras de agua: salpica a los pies.
func celda_tiene_agua_salpica(celda: Vector2) -> bool:
	return celda_admite_salpicadura(_tp(), celda)


## true si `tp` admite efectos de agua en `celda` y la celda es AGUA_PIES (charco):
## la animación de los pies dura mientras se esté sobre ella.
static func celda_admite_agua_pies(tp: TPTileDataMap, celda: Vector2) -> bool:
	return tp != null and tp.admite_efectos_agua(celda) 		and tp.has_flag(celda, TPTileDataMap.Flags.AGUA_PIES)


## true si la celda (de la capa de datos actual de la entidad) es AGUA_PIES a ras de agua.
func celda_tiene_agua_pies(celda: Vector2) -> bool:
	return celda_admite_agua_pies(_tp(), celda)


## true si la celda es AGUA_SALPICA a ras de agua: además hace ondas.
func celda_tiene_ondas(celda: Vector2) -> bool:
	return celda_admite_ondas(_tp(), celda)


func disparar_salpicadura() -> void:
	if salpicadura == null:
		return
	# Sobre un charco la animación ya se está repitiendo: no se reinicia.
	if continua and salpicadura.visible:
		return
	salpicadura.visible = true
	salpicadura.play(ANIMACION_SALPICADURA)


func ocultar_salpicadura() -> void:
	if salpicadura != null:
		salpicadura.visible = false


## Inicio de paso, con la entidad aún en `celda_origen`. Si el origen es AGUA_PIES la
## animación sigue (y se corta a mitad de paso si el destino no lo es); si no, se
## comporta como `actualizar_salpicadura`. `permitir` es false en surf, saltos...
func iniciar_paso(celda_origen: Vector2, celda_destino: Vector2, permitir: bool = true) -> void:
	_en_paso = true
	_origen_pies = permitir and celda_tiene_agua_pies(celda_origen)
	_destino_pies = permitir and celda_tiene_agua_pies(celda_destino)
	if _origen_pies:
		_fijar_continua(true)
		return
	_fijar_continua(false)
	actualizar_salpicadura(celda_origen, permitir)


## `pixeles`: distancia recorrida en el paso actual (0..16). A mitad de paso el agua
## pasa del tile de origen al de destino.
func actualizar_progreso(pixeles: float) -> void:
	if not _en_paso:
		return
	_fijar_continua(_origen_pies if pixeles < PIXELES_CAMBIO_TILE else _destino_pies)


## Entidad quieta en `celda` (fin de paso, aterrizaje, teletransporte o aparición):
## sobre un charco la animación se repite hasta que salga de él.
func actualizar_reposo(celda: Vector2, permitir: bool = true) -> void:
	_en_paso = false
	_origen_pies = permitir and celda_tiene_agua_pies(celda)
	_destino_pies = _origen_pies
	_fijar_continua(_origen_pies)


## Sin agua en los pies (surf, salto o NPC oculto).
func ocultar() -> void:
	_en_paso = false
	_origen_pies = false
	_destino_pies = false
	_fijar_continua(false)
	ocultar_salpicadura()


func _fijar_continua(activa: bool) -> void:
	if activa == continua:
		return
	continua = activa
	if activa:
		if salpicadura != null:
			salpicadura.visible = true
			salpicadura.play(ANIMACION_SALPICADURA)
	else:
		ocultar_salpicadura()


## Fin de la animación: sobre un charco vuelve a empezar; si no, se oculta.
func _al_terminar_salpicadura() -> void:
	if continua and salpicadura != null:
		salpicadura.play(ANIMACION_SALPICADURA)
	else:
		ocultar_salpicadura()


## Inicio de paso: salpica si `permitir` y la celda es AGUA_SALPICA; si no, oculta
## la salpicadura que quedara del paso anterior.
func actualizar_salpicadura(celda: Vector2, permitir: bool = true) -> void:
	if permitir and celda_tiene_agua_salpica(celda):
		disparar_salpicadura()
	else:
		ocultar_salpicadura()


## Reproduce las ondas del paso en `pos_global` si `celda` es AGUA_SALPICA a ras
## de agua y hay mapa. La primera es inmediata y el resto se programan cada
## `intervalo_ondas` s (sin bloquear al llamador). Devuelve si hubo onda.
func intentar_ondas(celda: Vector2, pos_global: Vector2) -> bool:
	if cantidad_ondas <= 0 or not celda_tiene_ondas(celda):
		return false
	var mapa := _mapa()
	if mapa == null:
		return false
	mapa.reproducir_onda(pos_global)
	if cantidad_ondas > 1:
		_reproducir_ondas_restantes(pos_global)
	return true


## Sprite de salpicadura de los NPC (2 frames de 16×16 a 6 fps, sin bucle,
## oculto). El jugador usa el de su escena (boy.tscn / girl.tscn).
static func crear_salpicadura_npc() -> AnimatedSprite2D:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(ANIMACION_SALPICADURA)
	frames.set_animation_speed(ANIMACION_SALPICADURA, 6.0)
	frames.set_animation_loop(ANIMACION_SALPICADURA, false)
	for indice: int in 2:
		var frame := AtlasTexture.new()
		frame.atlas = TEXTURA_SALPICADURA_NPC
		frame.region = Rect2(16 * indice, 0, 16, 16)
		frames.add_frame(ANIMACION_SALPICADURA, frame)
	var sprite := AnimatedSprite2D.new()
	sprite.name = "salpicadura"
	sprite.visible = false
	sprite.sprite_frames = frames
	sprite.animation = ANIMACION_SALPICADURA
	return sprite


func _reproducir_ondas_restantes(pos_global: Vector2) -> void:
	for _indice: int in range(1, cantidad_ondas):
		if not is_inside_tree():
			return
		await get_tree().create_timer(intervalo_ondas).timeout
		var mapa := _mapa()
		if mapa == null:
			return  # Cambio de mapa durante la espera
		mapa.reproducir_onda(pos_global)


func _configurar_salpicadura(sprite: AnimatedSprite2D) -> void:
	salpicadura = sprite
	if salpicadura != null:
		salpicadura.animation_finished.connect(_al_terminar_salpicadura)


func _tp() -> TPTileDataMap:
	if not _obtener_tp.is_valid():
		return null
	return _obtener_tp.call() as TPTileDataMap


func _mapa() -> MapaConfiguracion:
	if not _obtener_mapa.is_valid():
		return null
	return _obtener_mapa.call() as MapaConfiguracion
