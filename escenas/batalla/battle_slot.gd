@tool
extends Node2D
class_name BattleSlot

enum Posicion {
	JUGADOR_IZQUIERDA,
	JUGADOR_DERECHA,
	RIVAL_IZQUIERDA,
	RIVAL_DERECHA,
}

## El Pokémon empieza a salir de la Poké Ball (configurar_aparicion): la batalla
## reproduce su grito.
signal aparicion_iniciada
## El Pokémon ya salió de la Poké Ball (ballAnimActive = 0): la batalla prueba sus destellos de variocolor.
signal aparicion_terminada

@export var posicion_batalla: Posicion = Posicion.JUGADOR_IZQUIERDA
@export var es_jugador: bool = true

const COLOR_SOMBREADO_DEFAULT := Color(0.12, 0.14, 0.2, 0.8)

@onready var sprite_pokemon: Sprite2D = $Pokemon
@onready var pokeball: PokeballSprite2 = $Pokeball
const SHADER_MOSAICO: Shader = preload("res://escenas/batalla/animaciones_nativas/mosaico.gdshader")
const SONIDO_FORMA_INICIO: AudioStream = preload("res://Audio/SE-AVXS/203_SE_M_TELEPORT.wav")
const SONIDO_FORMA_FIN: AudioStream = preload("res://Audio/SE/PRSFX- Minimize1.wav")
const PASOS_MOSAICO_FORMA: int = 15
const FOTOGRAMAS_POR_PASO_FORMA: float = 3.0
const FOTOGRAMAS_SONIDO_FORMA: float = 48.0
const FOTOGRAMAS_POR_SEGUNDO: float = 60.0

@onready var anim_player: AnimationPlayer = $AnimationPlayer
## Sombra bajo el Pokémon (`Sombra1`, oculta por defecto en la escena). Opcional: si el
## slot no la tiene (escenas antiguas) todo lo relativo a la sombra se ignora.
@onready var sombra: Sprite2D = get_node_or_null("Sombra1") as Sprite2D

var shader_pokemon: PokemonBattleShaderController
var cuadro_ps: Node2D
var marcador_objetivo: Line2D

## Bandera `sombra` de la especie que ocupa el slot (battle_positions.json). La fija
## `fijar_sombra_activa()`; la visibilidad real de `Sombra1` sale de `_sincronizar_sombra()`.
var _sombra_activa: bool = false
## true mientras el Pokémon está apareciendo (silueta/escala/lanzamiento): sin sombra.
var _en_aparicion: bool = false
## true desde que empieza la recogida o el debilitamiento hasta que entra otro Pokémon.
var _retirando: bool = false
## Destellos de variocolor en curso de este slot (los crea `BattleSceneController`).
var destellos_variocolor: Node2D

## Invalidates presentation handles when a slot gets a new occupant.
var animation_generation: int = 0

func _ready() -> void:
	shader_pokemon = PokemonBattleShaderController.new(sprite_pokemon)
	shader_pokemon.name = "PokemonShaderController"
	add_child(shader_pokemon, false, Node.INTERNAL_MODE_BACK)
	# Cualquier cambio de `Pokemon.visible` (también los hechos desde batalla.gd) reevalúa
	# la sombra; la animación local de aparición avisa cuando termina.
	sprite_pokemon.visibility_changed.connect(_sincronizar_sombra)
	if not Engine.is_editor_hint():sprite_pokemon.tree_exiting.connect(_retirar_presentacion_sustituto)
	anim_player.animation_finished.connect(_al_terminar_animacion)
	# En el editor la Pokéball puede quedar visible en la escena para que se dibuje la guía de
	# su trayectoria; en juego arranca siempre oculta (la muestra la animación de lanzamiento).
	if not Engine.is_editor_hint():
		pokeball.visible = false
	_sincronizar_sombra()

## Activa o desactiva la sombra del Pokémon que entra en este slot (bandera `sombra` de su
## especie). Se llama cada vez que un Pokémon se aplica al slot (`aplicar_offset_a_slot`):
## además de fijar la bandera, marca que ya no se está retirando ningún Pokémon.
func fijar_sombra_activa(activa: bool) -> void:
	_sombra_activa = activa
	_retirando = false
	_sincronizar_sombra()

## Regla de visibilidad de `Sombra1`: solo se ve si la especie tiene la bandera, el sprite
## del Pokémon está visible y no está apareciendo ni retirándose. En el editor no se toca
## (la escena conserva su `visible = false`).
func _sincronizar_sombra() -> void:
	if Engine.is_editor_hint() or not is_instance_valid(sombra) or not is_instance_valid(sprite_pokemon):
		return
	sombra.visible = _sombra_activa and sprite_pokemon.visible and not _en_aparicion and not _retirando

func _empezar_aparicion() -> void:
	_en_aparicion = true
	_retirando = false
	_sincronizar_sombra()

func _terminar_aparicion() -> void:
	var estaba_apareciendo: bool = _en_aparicion
	_en_aparicion = false
	_sincronizar_sombra()
	if estaba_apareciendo:
		aparicion_terminada.emit()

## Espera a que acaben la aparición en curso y sus destellos de variocolor.
func esperar_destellos_variocolor() -> void:
	while is_inside_tree() and (_en_aparicion or (is_instance_valid(destellos_variocolor) and not destellos_variocolor.finalizados)):
		await get_tree().process_frame

func _empezar_retirada() -> void:
	_retirar_presentacion_sustituto()
	_retirando = true
	_sincronizar_sombra()

func _retirar_presentacion_sustituto() -> void:
	if not Engine.is_editor_hint():
		BattleSubstitutePresentation.retire(self);BattleTransformPresentation.retire(self)
		EfectoMovimientoNativo.cancelar_en_slot(self)

func _exit_tree() -> void:
	_retirar_presentacion_sustituto()

func _al_terminar_animacion(nombre: StringName) -> void:
	if nombre == &"aparicion":
		_terminar_aparicion()

## Vincula el HUD que corresponde a este slot. El HUD está separado del campo
## para que las animaciones de suelo, Pokémon y cuadros sean independientes.
func configurar_interfaz(cuadro: Node2D, marcador: Line2D) -> void:
	cuadro_ps = cuadro
	marcador_objetivo = marcador
	cuadro_ps.visible = false
	marcador_objetivo.visible = false

## Coordenada base del Pokémon respecto del suelo que contiene este slot.
## `Pokemon.position` queda libre para el offset visual propio de cada sprite.
func fijar_posicion_relativa_al_suelo(posicion: Vector2) -> void:
	position = posicion
	sprite_pokemon.position = Vector2.ZERO

## Offset individual del sprite respecto del anclaje del slot.
func fijar_offset_pokemon(offset: Vector2) -> void:
	sprite_pokemon.position = offset

## General_CastformChange (sub_812D7E8): el sprite se pixela un escalón cada 3 fotogramas
## hasta 15, `aplicar_forma` cambia la imagen en el máximo y se despixela. Suena
## SE_M_TELEPORT al empezar y SE_M_MINIMIZE a los 48 fotogramas.
func animar_cambio_forma(aplicar_forma: Callable) -> void:
	var material_previo: Material = sprite_pokemon.material
	var mosaico := ShaderMaterial.new()
	mosaico.shader = SHADER_MOSAICO
	sprite_pokemon.material = mosaico
	_sonar_cambio_forma(SONIDO_FORMA_INICIO)
	get_tree().create_timer(FOTOGRAMAS_SONIDO_FORMA / FOTOGRAMAS_POR_SEGUNDO).timeout.connect(_sonar_cambio_forma.bind(SONIDO_FORMA_FIN))
	for paso: int in range(1, PASOS_MOSAICO_FORMA + 1):
		mosaico.set_shader_parameter(&"mosaico", float(paso))
		await get_tree().create_timer(FOTOGRAMAS_POR_PASO_FORMA / FOTOGRAMAS_POR_SEGUNDO).timeout
	aplicar_forma.call()
	for paso: int in range(PASOS_MOSAICO_FORMA - 1, -1, -1):
		mosaico.set_shader_parameter(&"mosaico", float(paso))
		await get_tree().create_timer(FOTOGRAMAS_POR_PASO_FORMA / FOTOGRAMAS_POR_SEGUNDO).timeout
	sprite_pokemon.material = material_previo

func _sonar_cambio_forma(sonido: AudioStream) -> void:
	var reproductor := AudioStreamPlayer.new()
	reproductor.stream = sonido
	reproductor.finished.connect(reproductor.queue_free)
	add_child(reproductor, false, Node.INTERNAL_MODE_BACK)
	reproductor.play()

func configurar_pokemon(pokemon: BasePokemon, es_slot_jugador: bool, estado: String, exp_inicio_nivel: int = 0) -> void:
	_retirar_presentacion_sustituto()
	animation_generation += 1
	if pokemon == null:
		ocultar()
		return

	if not is_instance_valid(cuadro_ps):
		push_error("[BATTLE_SLOT] Falta configurar el cuadro de PS para %s" % name)
		return
	cuadro_ps.set_nombre(pokemon.nombre_interno)
	cuadro_ps.set_sexo(pokemon.sexo)
	cuadro_ps.set_nivel(pokemon.nivel)
	cuadro_ps.set_estado(estado)
	if es_slot_jugador:
		cuadro_ps.set_salud_max(pokemon.estad_ps)
		cuadro_ps.set_experiencia(pokemon.experiencia, exp_inicio_nivel, pokemon.exp_sig_nivel)
		cuadro_ps.set_salud_instantanea(pokemon.estad_ps, pokemon.estad_ps_actual)
	else:
		cuadro_ps.set_salud_max()
		if pokemon.estad_ps_actual != pokemon.estad_ps:
			var tween_inicial := create_tween()
			cuadro_ps.set_salud(pokemon.estad_ps, pokemon.estad_ps_actual, tween_inicial)

func actualizar_estado(estado: String) -> void:
	if not is_instance_valid(cuadro_ps):
		return
	cuadro_ps.set_estado(estado)

func actualizar_salud(salud_maxima: int, salud_actual: int, tween: Tween) -> void:
	if not is_instance_valid(cuadro_ps):
		return
	cuadro_ps.set_salud(salud_maxima, salud_actual, tween)

func actualizar_salud_instantanea(salud_maxima: int, salud_actual: int) -> void:
	if is_instance_valid(cuadro_ps) and cuadro_ps.has_method("set_salud_instantanea"):
		cuadro_ps.set_salud_instantanea(salud_maxima, salud_actual)

func marcar_objetivo(activo: bool) -> void:
	if not is_instance_valid(marcador_objetivo):
		return
	marcador_objetivo.visible = activo
	if activo:
		# El marcador ahora es hijo del cuadro de PS, no del slot.
		marcador_objetivo.global_position = sprite_pokemon.global_position + Vector2(32, 32)

func preparar_posiciones(posicion_sprite_inicial: Vector2, posicion_cuadro_inicial: Vector2) -> void:
	sprite_pokemon.position = posicion_sprite_inicial
	if is_instance_valid(cuadro_ps):
		cuadro_ps.position = posicion_cuadro_inicial

## Prepara el sombreado inicial del Pokémon.
## Se restablecen todos los parámetros para no depender del estado anterior
## del material compartido por la instancia del BattleSlot.
func preparar_sombreado(color_sombreado: Color = COLOR_SOMBREADO_DEFAULT) -> void:
	if not shader_pokemon:
		return

	shader_pokemon.set_parametro("efecto_silueta", true)
	shader_pokemon.set_parametro("color_silueta", color_sombreado)
	shader_pokemon.set_parametro("intensidad_silueta", 1.0)
	shader_pokemon.set_parametro("progreso_silueta", 0.0)

## Lleva el Pokémon sombreado a su color normal y desactiva el efecto.
## Puede invocarse desde una Call Method Track del AnimationPlayer.
func animar_sombreado(duracion: float = 0.8) -> void:
	if not shader_pokemon:
		return

	shader_pokemon.set_parametro("efecto_silueta", true)
	shader_pokemon.set_parametro("progreso_silueta", 0.0)
	await shader_pokemon.animar_parametro("progreso_silueta", 0.0, 1.0, duracion)
	shader_pokemon.set_parametro("efecto_silueta", false)
	shader_pokemon.set_parametro("intensidad_silueta", 1.0)
	shader_pokemon.set_parametro("progreso_silueta", 1.0)

const COLOR_SUBIDA_ESTADISTICA := Color(0.35, 0.65, 1.0, 0.75)
const COLOR_BAJADA_ESTADISTICA := Color(0.1, 0.15, 0.45, 0.75)

## Animación de subida/bajada de característica (B_ANIM_STATS_CHANGE de Gen 3,
## simplificada): dos pulsos de tinte con el efecto silueta del shader.
func animar_cambio_estadistica(sube: bool) -> void:
	if not shader_pokemon:
		return
	shader_pokemon.set_parametro("color_silueta", COLOR_SUBIDA_ESTADISTICA if sube else COLOR_BAJADA_ESTADISTICA)
	shader_pokemon.set_parametro("intensidad_silueta", 1.0)
	shader_pokemon.set_parametro("progreso_silueta", 1.0)
	shader_pokemon.set_parametro("efecto_silueta", true)
	for _pulso in 2:
		await shader_pokemon.animar_parametro("progreso_silueta", 1.0, 0.0, 0.2)
		await shader_pokemon.animar_parametro("progreso_silueta", 0.0, 1.0, 0.2)
	shader_pokemon.set_parametro("efecto_silueta", false)

func configurar_aparicion(posicion_inicial: Vector2, color_silueta: Color) -> void:
	# Primero se marca la aparición: al hacerse visible el sprite la sombra sigue oculta.
	_empezar_aparicion()
	sprite_pokemon.position = posicion_inicial
	sprite_pokemon.visible = true
	sprite_pokemon.scale = Vector2(0.1, 0.1)
	preparar_sombreado(color_silueta)
	aparicion_iniciada.emit()

## Reproduce la animación local "aparicion" (escala 0.1→1 + revelado de
## silueta del shader, definida en este mismo nodo sobre `Pokemon`). Vive en
## el AnimationPlayer propio del slot para que el timeline global de batalla
## solo tenga que decirle "aparecé" a este nodo (Call Method Track) en vez de
## animar directamente rutas internas como `Pokemon:scale` — eso acopla el
## timeline global a la jerarquía interna del slot y obliga a duplicar esas
## pistas por cada slot (jugador/rival, simple/doble). La posición inicial es
## dependiente de la especie enviada y no vive acá: la fija quien llame a
## `configurar_aparicion()` antes de disparar esta animación.
func reproducir_aparicion() -> void:
	if is_instance_valid(anim_player):
		anim_player.play(&"aparicion")
	else:
		_terminar_aparicion()

func configurar_pokeball(nombre_bola: String) -> void:
	pokeball.mostrar_pokeball(nombre_bola if not nombre_bola.is_empty() else "POKEBALL")

func preparar_pokeball(posicion: Vector2) -> void:
	pokeball.position = posicion
	pokeball.visible = true
	pokeball.frame = 0

func abrir_pokeball(demora: float = 0.3) -> void:
	pokeball.visible = true
	pokeball.frame = 0
	await get_tree().create_timer(demora).timeout
	pokeball.frame = 1

func cerrar_pokeball() -> void:
	pokeball.frame = 2
	await get_tree().create_timer(0.1).timeout
	pokeball.visible = false
	pokeball.frame = 0

## Desplazamiento del origen del lanzamiento en curso (ver `animar_lanzamiento_parabolico`).
var _desplazamiento_origen_lanzamiento: Vector2 = Vector2.ZERO

## Lanzamiento de la Poké Ball del jugador en parábola hasta este slot.
## desplazamiento_origen: posición del slot respecto del slot principal; en
## dobles todas las balls salen del mismo punto (pokeball.c, (24,68)) y solo
## cambia el destino, así que el origen se compensa y se anula al aterrizar.
## espera_apertura: tiempo que la ball queda en el suelo antes de abrirse
## (SendOutMonAnimation_Delay del 2.º Pokémon en dobles).
func animar_lanzamiento_parabolico(callback_final: Callable = Callable(), desplazamiento_origen: Vector2 = Vector2.ZERO, espera_apertura: float = 0.0) -> void:
	_desplazamiento_origen_lanzamiento = desplazamiento_origen
	preparar_pokeball(Vector2.ZERO)
	_actualizar_lanzamiento(0.0)
	var tween_lanzamiento := get_tree().create_tween()
	tween_lanzamiento.tween_method(_actualizar_lanzamiento, 0.0, 1.0, 0.8)
	await tween_lanzamiento.finished
	if espera_apertura > 0.0:
		await get_tree().create_timer(espera_apertura).timeout
	pokeball.visible = false
	if callback_final.is_valid():
		callback_final.call()

func _actualizar_lanzamiento(progreso: float) -> void:
	var x: float = lerp(30.0, 68.0, progreso)
	pokeball.position = Vector2(x, _parabola(x)) + Vector2(-80, -60) - _desplazamiento_origen_lanzamiento * (1.0 - progreso)
	pokeball.rotation_degrees = (x - 30.0) / 2.0

## Punto en el que aterriza la ball del lanzamiento: ahí vuelve a abrirse al retirarse.
func posicion_aterrizaje_ball() -> Vector2:
	return Vector2(68.0, _parabola(68.0)) + Vector2(-80, -60)

func _parabola(x: float) -> float:
	return 0.08 * pow(x - 44.0, 2) + 62.0

## Silueta que se agranda hasta `posicion_final` y recupera su color. Con
## `iluminacion` el slot también hace el destello del campo; sin ella (null)
## lo controla quien llama, p. ej. la intro doble, donde dos apariciones
## solapadas comparten un único destello.
func animar_aparicion(posicion_final: Vector2, iluminacion: ColorRect, callback_final: Callable = Callable()) -> void:
	var duracion_agrandar := 0.2
	var duracion_fade_out := 0.4
	var tween_iluminacion := get_tree().create_tween()
	tween_iluminacion.set_parallel(true)
	if iluminacion:
		tween_iluminacion.tween_property(iluminacion, "modulate:a", 1.0, duracion_agrandar).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween_iluminacion.tween_property(sprite_pokemon, "position", posicion_final, duracion_agrandar).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween_iluminacion.tween_property(sprite_pokemon, "scale", Vector2.ONE, duracion_agrandar).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween_iluminacion.finished
	await get_tree().create_timer(0.1).timeout

	if iluminacion:
		tween_iluminacion = get_tree().create_tween()
		tween_iluminacion.tween_property(iluminacion, "modulate:a", 0.0, duracion_fade_out).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		animar_sombreado(duracion_fade_out)
		await tween_iluminacion.finished
		iluminacion.visible = false
	else:
		await animar_sombreado(duracion_fade_out)
	_terminar_aparicion()
	if callback_final.is_valid():
		callback_final.call()

func animar_recogida(posicion_pokeball: Vector2) -> void:
	if not sprite_pokemon.visible:
		return
	_empezar_retirada()
	var tween_recogida := get_tree().create_tween()
	tween_recogida.set_parallel(true)
	tween_recogida.tween_property(sprite_pokemon, "scale", Vector2(0.1, 0.1), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween_recogida.tween_property(sprite_pokemon, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween_recogida.tween_property(sprite_pokemon, "position", posicion_pokeball, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween_recogida.finished
	sprite_pokemon.visible = false
	sprite_pokemon.scale = Vector2.ONE
	sprite_pokemon.modulate.a = 1.0

## Duración del tinte del Pokémon antes de encogerse hacia su ball al retirarse.
const DURACION_TINTE_RETIRADA := 0.15

## Vuelta a la Poké Ball (pokeruby AnimTask_SwitchOutBallEffect +
## AnimTask_SwitchOutShrinkMon): la ball aparece abierta en `posicion_ball`, el
## Pokémon se tiñe de `color_silueta` y se encoge hacia `posicion_recogida`, y la
## ball se cierra y desaparece. Sin Pokémon a la vista (debilitado o ya retirado
## por Relevo) no hace nada.
func animar_vuelta_a_pokeball(posicion_ball: Vector2, posicion_recogida: Vector2, color_silueta: Color) -> void:
	if not sprite_pokemon.visible:
		return
	pokeball.position = posicion_ball
	pokeball.rotation_degrees = 0.0
	pokeball.frame = PokeballSprite2.EstadoAnimacion.ABIERTA
	pokeball.visible = true
	if shader_pokemon:
		shader_pokemon.set_parametro("efecto_silueta", true)
		shader_pokemon.set_parametro("color_silueta", color_silueta)
		shader_pokemon.set_parametro("intensidad_silueta", 1.0)
		await shader_pokemon.animar_parametro("progreso_silueta", 1.0, 0.0, DURACION_TINTE_RETIRADA)
	await animar_recogida(posicion_recogida)
	if shader_pokemon:
		shader_pokemon.set_parametro("efecto_silueta", false)
		shader_pokemon.set_parametro("progreso_silueta", 1.0)
	pokeball.frame = PokeballSprite2.EstadoAnimacion.MEDIO_ABIERTA
	await get_tree().create_timer(0.05).timeout
	pokeball.frame = PokeballSprite2.EstadoAnimacion.CERRADA
	await get_tree().create_timer(0.1).timeout
	pokeball.visible = false

func animar_lanzamiento_y_salida(posicion_destino: Vector2, posicion_final: Vector2, actualizar_sprite: Callable = Callable(), emitir_particulas: Callable = Callable()) -> void:
	# Sin sombra durante todo el lanzamiento y la aparición (en un cambio forzado el sprite
	# anterior sigue visible hasta que llega el nuevo).
	_empezar_aparicion()
	pokeball.visible = true
	pokeball.frame = 0
	pokeball.position = Vector2(200, 130)
	var tween_lanzamiento := get_tree().create_tween()
	tween_lanzamiento.tween_property(pokeball, "position", posicion_destino, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween_lanzamiento.finished
	pokeball.frame = 1
	await get_tree().create_timer(0.1).timeout
	if actualizar_sprite.is_valid():
		actualizar_sprite.call()
	if emitir_particulas.is_valid():
		emitir_particulas.call(posicion_final + Vector2(0, 8))
	pokeball.frame = 2
	await get_tree().create_timer(0.1).timeout
	pokeball.visible = false
	pokeball.frame = 0
	configurar_aparicion(Vector2(26, 64), Color("#aaffff"))
	var tween_aparicion := get_tree().create_tween()
	tween_aparicion.set_parallel(true)
	tween_aparicion.tween_property(sprite_pokemon, "position", Vector2.ZERO, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween_aparicion.tween_property(sprite_pokemon, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween_aparicion.tween_property(sprite_pokemon, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween_aparicion.finished
	animar_sombreado(0.2)
	await get_tree().create_timer(0.2).timeout
	_terminar_aparicion()

func animar_debilitamiento(desplazamiento: float, duracion: float) -> void:
	_empezar_retirada()
	var tween_debilitado := get_tree().create_tween()
	tween_debilitado.tween_property(sprite_pokemon, "position", sprite_pokemon.position + Vector2(0, desplazamiento), duracion).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween_debilitado.parallel().tween_property(sprite_pokemon, "modulate:a", 0.0, duracion)
	await tween_debilitado.finished
	ocultar()

func ocultar() -> void:
	sprite_pokemon.visible = false
	_sincronizar_sombra()
	if is_instance_valid(cuadro_ps):
		cuadro_ps.visible = false
	pokeball.visible = false
	if is_instance_valid(marcador_objetivo):
		marcador_objetivo.visible = false

func restaurar() -> void:
	_retirando = false
	sprite_pokemon.visible = true
	sprite_pokemon.modulate.a = 1.0
	_sincronizar_sombra()
	if is_instance_valid(cuadro_ps):
		cuadro_ps.visible = true
		cuadro_ps.modulate.a = 1.0
