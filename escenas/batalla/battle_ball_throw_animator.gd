extends RefCounted
## Animación del lanzamiento de una POKé BALL al Pokémon rival (pokeruby
## `Special_BallThrow`, data/battle_anim_scripts.s, y sus callbacks en
## src/battle_anim_special.c: sub_813FA94 → sub_813FD90 … sub_81407F4).
## Solo REPRESENTA el resultado: la fórmula (battle_capture_service.gd) ya
## decidió sacudidas y captura antes de animar.
##
## Reutiliza la POKé BALL del slot rival (`BattleSlot.pokeball`, un
## PokeballSprite2 con su parábola `punto_lanzamiento`), la recogida del slot
## (`animar_recogida`), el sombreado del shader y las partículas de
## `batalla.emitir_particulas_pokeball`. Sin `class_name` (se usa con
## `preload()`), igual que battle_capture_service.gd.

const SE_LANZAR: AudioStream = preload("res://Audio/SE/throw.wav")
const SE_ABRIR: AudioStream = preload("res://Audio/SE/Open Pokeball.WAV")
const SE_ABSORBER: AudioStream = preload("res://Audio/SE/jumptoball.wav")
const SE_REBOTE: AudioStream = preload("res://Audio/SE/balldrop.wav")
const SE_SACUDIDA: AudioStream = preload("res://Audio/SE/ballshake.wav")
## Fanfarria de captura (pokeruby sub_8140454: m4aMPlayAllStop + PlaySE(MUS_FANFA5),
## la misma de "¡tu Pokémon ha evolucionado!").
const TEMA_FANFARRIA_CAPTURA := "CONGRATULATIONS_YOUR_POKEMON_EVOLVED"
## Frames entre el cierre definitivo de la ball y la fanfarria (data[4] == 95).
const ESPERA_FANFARRIA_CAPTURA := 95.0 / 60.0
## Tope de espera de la fanfarria por si el stream no emite `finished`.
const ESPERA_MAXIMA_FANFARRIA := 8.0

## Punto de salida de la ball en pantalla (pokeruby CreateSprite(…, 32, 80)).
const ORIGEN_PANTALLA := Vector2(32, 80)
## El vuelo dura 34 frames y el arco sube 40 px (sub_813FA94 / sub_813FD90).
const DURACION_VUELO := 34.0 / 60.0
const ALTURA_ARCO := 40.0
## La ball se detiene 16 px por encima del centro del Pokémon…
const DESPLAZAMIENTO_OBJETIVO := Vector2(0, -16)
## Proyección inicial del suelo desde el punto donde se cierra la ball.
const CAIDA_SUELO := 24.0
## Destino de la ball en coordenadas de btlSueloArriba, independiente del slot.
const POSICION_FINAL_REL_SUELO: Vector2 = Vector2(63, 6)
## Alturas de los rebotes tras la caída (pokeruby: 32 → 22 → 12 → 2).
const ALTURAS_REBOTE: Array[float] = [10.0, 4.0]
## Color de la luz con la que el Pokémon entra en la ball.
const COLOR_ABSORCION := Color("#ffc8d8")
## Oscurecimiento de la ball que queda en pantalla tras la captura.
const COLOR_BALL_ATRAPADO := Color(0.6, 0.6, 0.6)
## Pausas de pokeruby: 31 frames entre el suelo y cada sacudida.
const PAUSA_SACUDIDA := 31.0 / 60.0
const GRADOS_SACUDIDA := 22.0
## Del centro del frame 16×16 (centered) al borde inferior de la ball cerrada.
const PIVOTE_SACUDIDA := Vector2(0, 8)

var _b: BattleSceneController
var _reproductor: AudioStreamPlayer = null
## Tipo de ball que tenía el slot rival antes del lanzamiento (en combates
## de entrenador es la ball con la que sale su equipo).
var _ball_previa := ""
## Posición de la ball del slot antes del lanzamiento: el envío del rival la
## abre en ese mismo sitio, así que limpiar() la devuelve ahí.
var _posicion_ball_previa := Vector2.ZERO
var _ball_en_pantalla := false
var _fanfarria_captura: AudioStreamPlayer = null


func _init(batalla: BattleSceneController) -> void:
	_b = batalla


## Lanza `nombre_ball` al Pokémon rival: vuelo, absorción, caída con rebotes y
## `sacudidas` balanceos (0-3). Si `atrapado`, la ball queda atenuada en su
## sitio hasta limpiar(); si no, el Pokémon sale y la ball desaparece.
func reproducir_lanzamiento(nombre_ball: String, sacudidas: int, atrapado: bool) -> void:
	var slot := _slot()
	if slot == null:
		return
	var ball := slot.pokeball
	var posicion_original := slot.sprite_pokemon.position
	var objetivo := _objetivo_local(slot)

	_preparar_ball(slot, nombre_ball)
	await _volar_hasta(ball, _origen_local(slot), objetivo)

	# Se abre, el Pokémon se vuelve luz y entra en la ball, que se cierra.
	ball.frame = PokeballSprite2.EstadoAnimacion.ABIERTA
	_reproducir(SE_ABRIR)
	_emitir_particulas(ball)
	slot.preparar_sombreado(COLOR_ABSORCION)
	await _b.get_tree().create_timer(10.0 / 60.0).timeout
	_reproducir(SE_ABSORBER)
	await slot.animar_recogida(objetivo - Vector2(3, 3))
	ball.frame = PokeballSprite2.EstadoAnimacion.MEDIO_ABIERTA
	await _b.get_tree().create_timer(0.05).timeout
	ball.frame = PokeballSprite2.EstadoAnimacion.CERRADA

	await _caer_con_rebotes(slot, objetivo)
	var sacudidas_a_mostrar := clampi(sacudidas, 0, 3)
	for i in range(sacudidas_a_mostrar):
		await _b.get_tree().create_timer(PAUSA_SACUDIDA).timeout
		await _sacudir(ball, i)

	await _b.get_tree().create_timer(PAUSA_SACUDIDA).timeout
	if atrapado:
		await _animar_captura_confirmada(ball)
		return
	await _liberar_pokemon(slot, ball, posicion_original)


## pokeruby BallThrowTrainerBlock (sub_81407B8/sub_81407F4): la ball llega al
## Pokémon del ENTRENADOR y sale desviada hacia abajo a la izquierda.
func reproducir_bloqueo_entrenador(nombre_ball: String) -> void:
	var slot := _slot()
	if slot == null:
		return
	var ball := slot.pokeball
	var objetivo := _objetivo_local(slot)
	_preparar_ball(slot, nombre_ball)
	await _volar_hasta(ball, _origen_local(slot), objetivo)
	_reproducir(SE_REBOTE)
	var tween := _b.create_tween()
	tween.tween_property(ball, "position", objetivo + Vector2(-70, 90), 0.35)
	await tween.finished
	limpiar()


## Oculta la ball del lanzamiento y restaura el slot rival (tipo de ball,
## color, giro). Idempotente: se llama al cerrar la batalla.
func limpiar() -> void:
	_liberar_fanfarria_captura()
	var slot := _slot()
	if slot == null or not _ball_en_pantalla:
		return
	_ball_en_pantalla = false
	var ball := slot.pokeball
	ball.activo_lanzamiento = false
	ball.visible = false
	ball.modulate = Color.WHITE
	ball.rotation_degrees = 0.0
	ball.position = _posicion_ball_previa
	ball.frame = PokeballSprite2.EstadoAnimacion.CERRADA
	if not _ball_previa.is_empty():
		slot.configurar_pokeball(_ball_previa)


## Vértice y `factor_ancho` de PokeballSprite2 para que su parábola salga de
## `inicio` y aterrice exactamente en `destino`. Como el arco de pokeruby
## (InitAnimArcTranslation), la cima queda `altura` px por encima del punto
## medio del segmento, y siempre algo por encima del extremo más alto; el
## vértice cae entre ambos, más cerca del extremo más alto.
static func calcular_parabola(inicio: Vector2, destino: Vector2, altura: float) -> Dictionary:
	var y_vertice := minf((inicio.y + destino.y) / 2.0 - absf(altura), minf(inicio.y, destino.y) - 4.0)
	var caida_inicio := inicio.y - y_vertice
	var caida_destino := destino.y - y_vertice
	var proporcion := sqrt(caida_inicio / caida_destino) if caida_destino > 0.0 else 1.0
	var x_vertice := (inicio.x + proporcion * destino.x) / (1.0 + proporcion)
	var dx := inicio.x - x_vertice
	var factor := (x_vertice - destino.x) / dx if absf(dx) > 0.001 else 1.0
	return {"vertice": Vector2(x_vertice, y_vertice), "factor_ancho": factor}


func _slot() -> BattleSlot:
	if _b == null or not is_instance_valid(_b.slot_rival):
		return null
	return _b.slot_rival


func _preparar_ball(slot: BattleSlot, nombre_ball: String) -> void:
	var ball := slot.pokeball
	if not _ball_en_pantalla:
		_ball_previa = ball.get_nombre_tipo_actual()
		_posicion_ball_previa = ball.position
	_ball_en_pantalla = true
	ball.mostrar_pokeball(nombre_ball, PokeballSprite2.EstadoAnimacion.CERRADA)
	ball.modulate = Color.WHITE
	ball.rotation_degrees = 0.0
	ball.visible = true


## Centro del Pokémon rival menos 16 px, en coordenadas del slot.
func _objetivo_local(slot: BattleSlot) -> Vector2:
	var sprite := slot.sprite_pokemon
	var tamano := sprite.texture.get_size() if sprite.texture != null else Vector2(64, 64)
	return sprite.position + tamano / 2.0 + DESPLAZAMIENTO_OBJETIVO


## ORIGEN_PANTALLA (coordenadas de batalla.gd) en coordenadas del slot.
func _origen_local(slot: BattleSlot) -> Vector2:
	return slot.to_local(_b.to_global(ORIGEN_PANTALLA))


func _volar_hasta(ball: PokeballSprite2, inicio: Vector2, destino: Vector2) -> void:
	var parabola := calcular_parabola(inicio, destino, ALTURA_ARCO)
	ball.posicion_inicial = inicio
	ball.vertice = parabola["vertice"]
	ball.factor_ancho = parabola["factor_ancho"]
	ball.progreso = 0.0
	ball.activo_lanzamiento = true
	_reproducir(SE_LANZAR)
	var tween := _b.create_tween()
	tween.tween_property(ball, "progreso", 1.0, DURACION_VUELO)
	await tween.finished
	ball.activo_lanzamiento = false
	ball.position = destino
	ball.rotation_degrees = 0.0


func _caer_con_rebotes(slot: BattleSlot, objetivo: Vector2) -> void:
	var ball: PokeballSprite2 = slot.pokeball
	var suelo_inicial: Vector2 = objetivo + Vector2(0, CAIDA_SUELO)
	var suelo_final: Vector2 = slot.to_local(_b.suelo_arriba.to_global(POSICION_FINAL_REL_SUELO))
	# La caída y cada rebote recorren una parte del camino hacia el punto fijo.
	var cantidad_tramos: float = float(ALTURAS_REBOTE.size() + 1)
	var suelo: Vector2 = suelo_inicial.lerp(suelo_final, 1.0 / cantidad_tramos)
	var tween: Tween = _b.create_tween()
	tween.tween_property(ball, "position", suelo, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	_reproducir(SE_REBOTE)
	for indice: int in range(ALTURAS_REBOTE.size()):
		var altura: float = ALTURAS_REBOTE[indice]
		var siguiente_suelo: Vector2 = suelo_inicial.lerp(suelo_final, float(indice + 2) / cantidad_tramos)
		var cima: Vector2 = suelo.lerp(siguiente_suelo, 0.5) - Vector2(0, altura)
		tween = _b.create_tween()
		tween.tween_property(ball, "position", cima, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(ball, "position", siguiente_suelo, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tween.finished
		suelo = siguiente_suelo
		_reproducir(SE_REBOTE)


## Un balanceo: izquierda → derecha → centro, alternando el lado de inicio.
## Pivota sobre el píxel inferior de la ball (apoyada en el suelo): durante el
## balanceo el dibujo sube PIVOTE_SACUDIDA y el nodo baja lo mismo.
func _sacudir(ball: PokeballSprite2, indice: int) -> void:
	var sentido := -1.0 if indice % 2 == 0 else 1.0
	_reproducir(SE_SACUDIDA)
	var offset_previo := ball.offset
	ball.offset = offset_previo - PIVOTE_SACUDIDA
	ball.position += PIVOTE_SACUDIDA
	var tween := _b.create_tween()
	tween.tween_property(ball, "rotation_degrees", GRADOS_SACUDIDA * sentido, 0.12)
	tween.tween_property(ball, "rotation_degrees", -GRADOS_SACUDIDA * sentido, 0.2)
	tween.tween_property(ball, "rotation_degrees", 0.0, 0.12)
	await tween.finished
	ball.position -= PIVOTE_SACUDIDA
	ball.offset = offset_previo


## Captura: la ball se queda quieta y atenuada hasta limpiar().
## TODO: estrellitas de captura fácil (no existen en Gen 3, pedido aparte).
## La ball se atenúa y, ESPERA_FANFARRIA_CAPTURA después, se corta la música del
## combate (no se reanuda: luego suena MUS_CAUGHT) y empieza la fanfarria.
## Vuelve en cuanto empieza: el mensaje de captura se escribe mientras suena.
func _animar_captura_confirmada(ball: PokeballSprite2) -> void:
	var tween := _b.create_tween()
	tween.tween_property(ball, "modulate", COLOR_BALL_ATRAPADO, 0.3)
	await _b.get_tree().create_timer(ESPERA_FANFARRIA_CAPTURA).timeout
	_iniciar_fanfarria_captura(_b)


## Corta la música (como m4aMPlayAllStop) y toca la fanfarria colgada de `anfitrion`.
func _iniciar_fanfarria_captura(anfitrion: Node) -> void:
	var musica := Singleton.obtener_nodo("ReproductorMusica") as NuevoAudioStreamPlayer
	if musica != null:
		musica.detener_reproduccion_actual()
	_liberar_fanfarria_captura()
	var stream: AudioStream = Fanfarria.cargar_stream_tema(TEMA_FANFARRIA_CAPTURA)
	if stream == null:
		return
	_fanfarria_captura = AudioStreamPlayer.new()
	_fanfarria_captura.name = "FanfarriaCaptura"
	_fanfarria_captura.stream = stream
	_fanfarria_captura.bus = musica.bus if musica != null else &"Master"
	anfitrion.add_child(_fanfarria_captura)
	_fanfarria_captura.play()


## {WAIT_SE} de BattleText_BallCaught1/2: espera a que termine la fanfarria de
## captura (si suena) antes de poner MUS_CAUGHT.
func esperar_fanfarria_captura() -> void:
	var reproductor := _fanfarria_captura
	if reproductor == null or not is_instance_valid(reproductor) or not reproductor.playing:
		_liberar_fanfarria_captura()
		return
	var arbol := reproductor.get_tree()
	var fin := {"listo": false}
	var marcar := func() -> void: fin["listo"] = true
	reproductor.finished.connect(marcar, CONNECT_ONE_SHOT)
	arbol.create_timer(ESPERA_MAXIMA_FANFARRIA).timeout.connect(marcar)
	while not bool(fin["listo"]) and is_instance_valid(reproductor):
		await arbol.process_frame
	if is_instance_valid(reproductor) and reproductor.finished.is_connected(marcar):
		reproductor.finished.disconnect(marcar)
	if reproductor == _fanfarria_captura:
		_liberar_fanfarria_captura()


func _liberar_fanfarria_captura() -> void:
	if _fanfarria_captura != null and is_instance_valid(_fanfarria_captura):
		_fanfarria_captura.stop()
		_fanfarria_captura.queue_free()
	_fanfarria_captura = null


## Escape: la ball se abre con partículas, el Pokémon sale a su tamaño y
## color normales y la ball desaparece (sub_81405F4/sub_81406BC).
func _liberar_pokemon(slot: BattleSlot, ball: PokeballSprite2, posicion_original: Vector2) -> void:
	ball.frame = PokeballSprite2.EstadoAnimacion.ABIERTA
	_reproducir(SE_ABRIR)
	_emitir_particulas(ball)
	var sprite := slot.sprite_pokemon
	sprite.scale = Vector2(0.1, 0.1)
	sprite.position = ball.position
	sprite.modulate.a = 1.0
	slot.restaurar()
	var tween := _b.create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "position", posicion_original, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished
	limpiar()
	await slot.animar_sombreado(0.3)


func _emitir_particulas(ball: PokeballSprite2) -> void:
	# El emisor suma (32, 32) a la posición (ver emitir_particulas_pokeball).
	_b.emitir_particulas_pokeball({
		"posicion": _b.to_local(ball.global_position) - Vector2(32, 32),
		"tiempo_emision": 0.3,
		"intervalo_emision": 0.02,
	})


func _reproducir(stream: AudioStream) -> void:
	if _reproductor == null or not is_instance_valid(_reproductor):
		_reproductor = AudioStreamPlayer.new()
		_reproductor.name = "ReproductorEfectosBall"
		_reproductor.bus = "Master"
		_b.add_child(_reproductor)
	_reproductor.stream = stream
	_reproductor.play()
