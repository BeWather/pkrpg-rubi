class_name EscenaEvolucion
extends CanvasLayer

## Escena de evolución (`EvolutionScene` / `Task_EvolutionScene` de
## `src/evolution_scene.c`). Capa propia por encima de la batalla y de los
## menús, con su fondo, su cuadro de diálogo y su fundido: sirve igual tras un
## combate, desde la mochila (piedras, CARAMELORARO) o desde cualquier evento.
##
## Orden (estados del decomp):
##  0-1  fundido desde negro y "¿Qué? ¡{mon} está evolucionando!";
##  2-4  grito de la especie previa y música MUS_EVOLUTION;
##  5-8  el Pokémon se vuelve blanco y alterna con la silueta de la evolución;
##       si se puede cancelar, mantener B lo detiene (estados 16-18);
##  9-12 destello, grito de la especie nueva y vuelta al color;
##  13   cambio de especie (EvolucionPokemon.evolucionar), Pokédex y
##       "¡Enhorabuena!..." con MUS_EVOLVED;
##  14,19-21 movimientos nuevos de la especie a su nivel (AprendizajeMovimientos);
##  15   fundido a negro y CreateShedinja.
##
## TODO: faltan los destellos (LaunchTask_PreEvoSparklesSet1/2, PostEvo...) y el
## escalado progresivo de sub_8149E7C; aquí las siluetas alternan con un ritmo
## que se acelera. Falta el SE de introducción (MUS_EVOLUTION_INTRO) y SE_EXP.
## TODO: textos pendientes de cotejar con la ROM española (la extracción de
## documentacion/mirubi no incluye gBattleStringsTable).

## Emitida al terminar, ya en negro.
signal terminada(evoluciono: bool)
signal _mensaje_terminado

const SCN_CUADRO_DIALOGO: PackedScene = preload("res://UI/cuadro_dialogo.tscn")
const SCN_FICHA_OLVIDAR: PackedScene = preload("res://UI/poke-info/ficha_olvidar_movimiento.tscn")
## Por encima de CapaBatalla (10) y de Menu (5).
const CAPA_EVOLUCION: int = 20
const TAMANO_PANTALLA: Vector2 = Vector2(240, 160)
## CreateMonPicSprite(..., 120, 64).
const POSICION_POKEMON: Vector2 = Vector2(120, 64)
const RUTA_GRITO: String = "res://Audio/SE/Cries/%03dCry.ogg"
const TEMA_EVOLUCION: String = "EVOLUCION"
const TEMA_EVOLUCIONADO: String = "CONGRATULATIONS_YOUR_POKEMON_EVOLVED"
const TEMA_MOVIMIENTO_APRENDIDO: String = "LEVEL_UP"
const ESPERA_MAXIMA_AUDIO: float = 8.0

const FPS_GBA: float = 60.0
## BeginNormalPaletteFade(..., 16, ...) de entrada y salida.
const FRAMES_FUNDIDO: int = 16
## Destellos previos (LaunchTask_PreEvoSparklesSet1/2) antes de alternar.
const FRAMES_PREVIOS: int = 90
const FRAMES_A_BLANCO: int = 30
## Duración de cada media alternancia de siluetas (se acelera).
const FRAMES_ALTERNANCIA: Array[int] = [
	40, 36, 32, 28, 24, 22, 20, 18, 16, 14, 12, 12, 10, 10, 8, 8, 6, 6, 6, 4, 4, 4, 4, 4, 2, 2, 2, 2,
]
const FRAMES_DESTELLO: int = 20
const FRAMES_VUELTA_COLOR: int = 16
## Pausa tras "aprendió" (tLearnsFirstMove = 0x40 en el estado 19).
const FRAMES_TRAS_APRENDER: int = 64

const SHADER_BLANCO: String = """
shader_type canvas_item;
uniform float blanco : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	COLOR = vec4(mix(c.rgb, vec3(1.0), blanco), c.a);
}
"""

var pokemon: BasePokemon = null
var destino: String = ""
## true en evoluciones por nivel (canStopEvo); false con piedras.
var puede_cancelar: bool = true
## Equipo al que se añade SHEDINJA (normalmente SistemaGuardado.get_equipo()).
var equipo: Array = []
## false si quien llama aún no está en negro: la escena funde a negro primero.
var desde_negro: bool = true
## Oscurece el Telon del mapa antes de liberarse (para volver a un menú que
## gestiona su propio fundido).
var oscurecer_telon_al_salir: bool = false

## --- Pruebas: sin cuadro de diálogo ni esperas, con respuestas fijas. ---
var sin_interfaz: bool = false
## Respuestas SÍ/NO por orden (true = SÍ) cuando sin_interfaz; agotadas, SÍ.
var respuestas_prueba: Array = []
## Índices de movimiento a olvidar por orden cuando sin_interfaz.
var elecciones_prueba: Array = []
## Simula mantener B durante la alternancia.
var cancelar_prueba: bool = false

var _fondo: ColorRect
var _sprite_previo: Sprite2D
var _sprite_nuevo: Sprite2D
var _destello: ColorRect
var _negro: ColorRect
var _dialogo: Node = null
var _capa_menus: Control
var _reproductor_musica: AudioStreamPlayer
var _reproductor_se: AudioStreamPlayer
var _musica_mapa: AudioStreamPlayer = null
var _musica_mapa_procesaba: bool = false
var _musica_mapa_pausada: bool = false
var _terminada: bool = false


## Crea la escena en la raíz, la ejecuta y la libera. Devuelve true si evolucionó.
static func ejecutar_en(arbol: SceneTree, p_pokemon: BasePokemon, p_destino: String,
		p_puede_cancelar: bool, p_equipo: Array, p_desde_negro: bool = true,
		p_oscurecer_telon: bool = false) -> bool:
	var escena := EscenaEvolucion.new()
	escena.pokemon = p_pokemon
	escena.destino = p_destino
	escena.puede_cancelar = p_puede_cancelar
	escena.equipo = p_equipo
	escena.desde_negro = p_desde_negro
	escena.oscurecer_telon_al_salir = p_oscurecer_telon
	arbol.root.add_child(escena)
	var evoluciono: bool = await escena.ejecutar()
	escena.queue_free()
	return evoluciono


func _ready() -> void:
	layer = CAPA_EVOLUCION
	_fondo = _rect(Color.BLACK)
	_sprite_previo = _sprite()
	_sprite_nuevo = _sprite()
	_sprite_nuevo.visible = false
	_destello = _rect(Color.WHITE)
	_destello.modulate.a = 0.0
	if not sin_interfaz:
		_dialogo = SCN_CUADRO_DIALOGO.instantiate()
		add_child(_dialogo)
	_capa_menus = Control.new()
	_capa_menus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capa_menus.size = TAMANO_PANTALLA
	add_child(_capa_menus)
	_negro = _rect(Color.BLACK)
	_negro.modulate.a = 1.0 if desde_negro else 0.0
	_reproductor_musica = AudioStreamPlayer.new()
	add_child(_reproductor_musica)
	_reproductor_se = AudioStreamPlayer.new()
	add_child(_reproductor_se)


func _exit_tree() -> void:
	_restaurar_musica_mapa()


## Ejecuta la secuencia completa. Devuelve true si el Pokémon evolucionó.
func ejecutar() -> bool:
	if pokemon == null or destino.is_empty():
		push_warning("[EscenaEvolucion] Sin Pokémon o sin especie de destino")
		_terminar(false)
		return false
	var especie_previa := pokemon.nombre_interno
	var nombre_previo := pokemon.get_nombre_mostrar()
	_preparar_sprites(especie_previa)
	_fondo.visible = desde_negro
	_sprite_previo.visible = desde_negro
	if not desde_negro:
		await _fundir(_negro, 1.0, FRAMES_FUNDIDO)
		_fondo.visible = true
		_sprite_previo.visible = true
	_pausar_musica_mapa()

	# Estados 0-4.
	await _fundir(_negro, 0.0, FRAMES_FUNDIDO)
	await _mostrar(tr("EVOLUCION_INICIO").replace("{mon}", nombre_previo), false)
	await _reproducir_grito(pokemon.numero_nacional)
	_reproducir_musica(TEMA_EVOLUCION)

	# Estados 5-8: blanco y alternancia (B lo detiene).
	await _esperar_frames(FRAMES_PREVIOS)
	await _fundir_blanco(_sprite_previo, 1.0, FRAMES_A_BLANCO)
	_fijar_blanco(_sprite_nuevo, 1.0)
	if await _alternar_siluetas():
		await _cancelar(nombre_previo)
		await _salir()
		_terminar(false)
		return false

	# Estados 9-12: destello, grito y color.
	_sprite_previo.visible = false
	_sprite_nuevo.visible = true
	await _fundir(_destello, 1.0, FRAMES_DESTELLO / 2)
	await _fundir(_destello, 0.0, FRAMES_DESTELLO / 2)
	_reproductor_musica.stop()
	var numero_nuevo := int(DatabaseManager.obtener_datos_pokemon(destino).get("numero_nacional", 0))
	_fundir_blanco(_sprite_nuevo, 0.0, FRAMES_VUELTA_COLOR)
	await _reproducir_grito(numero_nuevo)

	# Estado 13: cambio de especie, Pokédex y enhorabuena.
	EvolucionPokemon.evolucionar(pokemon, destino)
	EvolucionPokemon.registrar_evolucion(destino)
	var fanfarria := _crear_reproductor_tema(TEMA_EVOLUCIONADO)
	if fanfarria != null:
		fanfarria.play()
	await _mostrar(tr("EVOLUCION_FIN").replace("{mon}", nombre_previo).replace("{especie}", pokemon.nombre))
	if fanfarria != null:
		await _esperar_fin_audio(fanfarria)
		fanfarria.queue_free()

	# Estados 14, 19-21.
	await aprender_movimientos()

	# Estado 15.
	await _salir()
	EvolucionPokemon.crear_shedinja(especie_previa, pokemon, equipo)
	_terminar(true)
	return true


func esta_terminada() -> bool:
	return _terminada


# ==============================================
# CANCELACIÓN Y MOVIMIENTOS
# ==============================================

## Estados 16-18: para la música, devuelve el color, grito y "¿Eh?...".
func _cancelar(nombre_previo: String) -> void:
	_reproductor_musica.stop()
	_sprite_nuevo.visible = false
	_sprite_previo.visible = true
	await _fundir_blanco(_sprite_previo, 0.0, FRAMES_FUNDIDO)
	await _reproducir_grito(pokemon.numero_nacional)
	await _mostrar(tr("EVOLUCION_CANCELADA").replace("{mon}", nombre_previo))


## `MonTryLearningNewMove` tras evolucionar (estados 14 y 19-21). Público
## para reutilizarlo en las pruebas.
func aprender_movimientos() -> void:
	await DialogoAprendizaje.ejecutar(pokemon, self)


# --- Interfaz de DialogoAprendizaje ---

func mostrar_texto_aprendizaje(texto: String) -> void:
	await _mostrar(texto)


func preguntar_aprendizaje(texto: String) -> bool:
	return await _preguntar(texto)


## Estado 19: "¡{mon} aprendió {mov}!" con la fanfarria de subir de nivel.
func anunciar_movimiento_aprendido(texto: String) -> void:
	var fanfarria := _crear_reproductor_tema(TEMA_MOVIMIENTO_APRENDIDO)
	if fanfarria != null:
		fanfarria.play()
	await _mostrar(texto)
	if fanfarria != null:
		await _esperar_fin_audio(fanfarria)
		fanfarria.queue_free()
	await _esperar_frames(FRAMES_TRAS_APRENDER)


## Lista de movimientos (0-3 olvidar, 4 = ninguno).
func elegir_movimiento_aprendizaje(aprendizaje: AprendizajeMovimientos, _nombre_mov: String) -> int:
	if sin_interfaz:
		return int(elecciones_prueba.pop_front()) if not elecciones_prueba.is_empty() else FichaOlvidarMovimiento.INDICE_NUEVO
	await _mostrar(tr("EVOLUCION_MOV_CUAL"), false)
	# ShowSelectMovePokemonSummaryScreen: la ficha ocupa toda la pantalla con fundido.
	var ficha: FichaOlvidarMovimiento = SCN_FICHA_OLVIDAR.instantiate()
	_capa_menus.add_child(ficha)
	var indice: int = await ficha.elegir_aprendizaje(aprendizaje)
	ficha.queue_free()
	return indice


# ==============================================
# ANIMACIÓN
# ==============================================

## Estados 7-8: alterna las siluetas cada vez más rápido. Devuelve true si se
## detuvo con B (solo si `puede_cancelar`).
func _alternar_siluetas() -> bool:
	var mostrar_nuevo := false
	for frames in FRAMES_ALTERNANCIA:
		mostrar_nuevo = not mostrar_nuevo
		_sprite_previo.visible = not mostrar_nuevo
		_sprite_nuevo.visible = mostrar_nuevo
		for i in range(frames):
			if puede_cancelar and _b_mantenido():
				return true
			await _esperar_frames(1)
	return false


func _b_mantenido() -> bool:
	if sin_interfaz:
		return cancelar_prueba
	return Input.is_action_pressed("btn_cancelar")


func _preparar_sprites(especie_previa: String) -> void:
	_sprite_previo.texture = PokemonSpriteManager.cargar_sprite_frente(especie_previa, pokemon.es_shiny())
	_sprite_nuevo.texture = PokemonSpriteManager.cargar_sprite_frente(destino, pokemon.es_shiny())
	_fijar_blanco(_sprite_previo, 0.0)
	_fijar_blanco(_sprite_nuevo, 0.0)


func _fijar_blanco(sprite: Sprite2D, valor: float) -> void:
	(sprite.material as ShaderMaterial).set_shader_parameter("blanco", valor)


func _fundir_blanco(sprite: Sprite2D, hasta: float, frames: int) -> void:
	var material := sprite.material as ShaderMaterial
	var desde: float = float(material.get_shader_parameter("blanco"))
	if sin_interfaz or frames <= 0:
		material.set_shader_parameter("blanco", hasta)
		return
	var tween := create_tween()
	tween.tween_method(func(v: float) -> void: material.set_shader_parameter("blanco", v),
		desde, hasta, float(frames) / FPS_GBA)
	await tween.finished


func _fundir(nodo: CanvasItem, alfa: float, frames: int) -> void:
	if sin_interfaz or frames <= 0:
		nodo.modulate.a = alfa
		return
	var tween := create_tween()
	tween.tween_property(nodo, "modulate:a", alfa, float(frames) / FPS_GBA)
	await tween.finished


## Estado 15: fundido a negro y música del mapa.
func _salir() -> void:
	_cerrar_dialogo()
	await _fundir(_negro, 1.0, FRAMES_FUNDIDO)
	_reproductor_musica.stop()
	_restaurar_musica_mapa()
	if oscurecer_telon_al_salir and not sin_interfaz and Singleton.obtener_nodo("Telon") != null:
		await Singleton.transicion("oscurecer", 0.01)


func _terminar(evoluciono: bool) -> void:
	if _terminada:
		return
	_terminada = true
	terminada.emit(evoluciono)


func _rect(color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.size = TAMANO_PANTALLA
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect


func _sprite() -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.position = POSICION_POKEMON
	var shader := Shader.new()
	shader.code = SHADER_BLANCO
	var material := ShaderMaterial.new()
	material.shader = shader
	sprite.material = material
	add_child(sprite)
	return sprite


func _esperar_frames(frames: int) -> void:
	if sin_interfaz or frames <= 0:
		return
	await get_tree().create_timer(float(frames) / FPS_GBA).timeout


# ==============================================
# TEXTOS
# ==============================================

## Muestra `texto`; con `esperar_boton` espera A/B, si no sigue al terminar de
## escribirlo. El cuadro queda abierto hasta el siguiente texto.
func _mostrar(texto: String, esperar_boton: bool = true) -> void:
	if _dialogo == null:
		return
	_dialogo.mostrar(texto, esperar_boton, false, _mensaje_terminado.emit)
	await _mensaje_terminado


## preguntaSiNo() del cuadro propio; CANCELAR equivale a NO.
func _preguntar(texto: String) -> bool:
	if _dialogo == null:
		# Sin respuestas: SÍ (acaba siempre: elegir "ninguno" y dejar de aprender).
		return bool(respuestas_prueba.pop_front()) if not respuestas_prueba.is_empty() else true
	_dialogo.cerrar()
	_dialogo.preguntaSiNo(texto)
	var respuesta := ""
	while respuesta.is_empty():
		var datos: Array = await _dialogo.comando_ejecutado
		if datos.size() >= 2 and str(datos[0]) == "respuesta_confirmacion":
			var parametros: Array = datos[1]
			respuesta = str(parametros[0]) if not parametros.is_empty() else "N"
	return respuesta == "Y"


func _cerrar_dialogo() -> void:
	if _dialogo != null:
		_dialogo.cerrar()


# ==============================================
# SONIDO
# ==============================================

## Grito de la especie (`PlayCry_Normal` + `IsCryFinished`).
func _reproducir_grito(numero_nacional: int) -> void:
	if sin_interfaz or numero_nacional <= 0:
		return
	var ruta := RUTA_GRITO % numero_nacional
	if not ResourceLoader.exists(ruta):
		return
	_reproductor_se.stream = load(ruta) as AudioStream
	_reproductor_se.play()
	await _esperar_fin_audio(_reproductor_se)


func _reproducir_musica(tema: String) -> void:
	if sin_interfaz:
		return
	var stream: AudioStream = Fanfarria.cargar_stream_tema(tema)
	if stream == null:
		return
	stream = stream.duplicate()
	if "loop" in stream:
		stream.set("loop", true)
	_reproductor_musica.stream = stream
	if is_instance_valid(_musica_mapa):
		_reproductor_musica.bus = _musica_mapa.bus
	_reproductor_musica.play()


## Reproductor de un tema sin bucle (fanfarrias). null si no carga o en pruebas.
func _crear_reproductor_tema(tema: String) -> AudioStreamPlayer:
	if sin_interfaz:
		return null
	var stream: AudioStream = Fanfarria.cargar_stream_tema(tema)
	if stream == null:
		return null
	var reproductor := AudioStreamPlayer.new()
	reproductor.stream = stream
	reproductor.bus = _reproductor_musica.bus
	add_child(reproductor)
	return reproductor


func _esperar_fin_audio(reproductor: AudioStreamPlayer) -> void:
	if not reproductor.playing:
		return
	var fin := {"listo": false}
	var marcar := func() -> void: fin["listo"] = true
	reproductor.finished.connect(marcar, CONNECT_ONE_SHOT)
	get_tree().create_timer(ESPERA_MAXIMA_AUDIO).timeout.connect(marcar)
	while not bool(fin["listo"]):
		await get_tree().process_frame
	if reproductor.finished.is_connected(marcar):
		reproductor.finished.disconnect(marcar)


## Pausa la música del mapa como EclosionHuevo (su _process la relanzaría).
func _pausar_musica_mapa() -> void:
	if sin_interfaz:
		return
	_musica_mapa = Singleton.obtener_nodo("ReproductorMusica") as AudioStreamPlayer
	if _musica_mapa == null:
		return
	_musica_mapa_procesaba = _musica_mapa.is_processing()
	_musica_mapa.set_process(false)
	_musica_mapa.stream_paused = true
	_musica_mapa_pausada = true


func _restaurar_musica_mapa() -> void:
	if not _musica_mapa_pausada:
		return
	_musica_mapa_pausada = false
	if is_instance_valid(_musica_mapa):
		_musica_mapa.stream_paused = false
		_musica_mapa.set_process(_musica_mapa_procesaba)
