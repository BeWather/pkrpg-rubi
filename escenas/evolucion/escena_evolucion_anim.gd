class_name EscenaEvolucionAnim
extends CanvasLayer

## Variante de `EscenaEvolucion` (scripts/evolucion/escena_evolucion.gd) que
## reproduce la misma secuencia de evolución, pero con la parte visual
## delegada a un `AnimationPlayer` definido en
## `escenas/evolucion/escena_evolucion_anim.tscn`, en lugar de tweens y esperas
## por frames hechas desde el script.
##
## Diferencias con `EscenaEvolucion`:
##   - Los nodos y sus materiales viven en el .tscn (Fondo, SpritePrevio,
##     SpriteNuevo, Destello, Negro, Animacion).
##   - El script solo orquesta (diálogos, audio y aprendizaje de movimientos) y
##     encadena las animaciones con `play()` + `animation_finished`.
##   - El intercambio de siluetas se cancela con `AnimationPlayer.stop()`, así
##     que se puede interrumpir con B sin esperar a que termine.
##
## Relación con `AnimacionEvolucion` (`scripts/evolucion/animacion_evolucion.gd`
## + `escenas/evolucion/animacion_evolucion.tscn`): son dos implementaciones con
## alcances distintos, y se mantienen las dos a propósito.
##   - `AnimacionEvolucion` es SOLO la capa visual reutilizable: expone
##     `preparar()`, `entrada()`, `transformacion()`, `vuelta_color()`,
##     `cancelar()` y `salida()`, y deja los textos, gritos y música a quien la
##     use.
##   - Esta escena es la contraparte COMPLETA, equivalente a `EscenaEvolucion`:
##     además de la animación, orquesta diálogos, audio y aprendizaje de
##     movimientos, y se lanza con `ejecutar_en()` igual que aquella.
##   - La secuencia nueva de partículas y mensajes vive aquí; la capa visual
##     independiente aún conserva su ritmo anterior.
##
## IMPORTANTE: instanciar siempre `escena_evolucion_anim.tscn` (o usar
## `ejecutar_en`), nunca `EscenaEvolucionAnim.new()` a secas: los nodos y el
## AnimationPlayer son hijos de la escena.
##
## Secuencia activa (library "" del AnimationPlayer):
##   oscurecer/intro       transición a negro de toda la pantalla y entrada
##   oscurecer_campo       fondo de batalla -> negro, dejando texto y Pokémon
##   remolino_curvo        remolino + Pokémon previo a blanco sólido
##   jaula_particulas      seis series de partículas descendentes
##   intercambio          8,5 s: 29 alternancias de escala cada vez más rápidas (cancelable)
##   dos_circulos          dos anillos de partículas convergentes
##   fuente_y_destello     fuente, destello blanco solo del campo, fondo/color normal
##   cancelar/salida       restauración del previo / salida a negro
##
## Los sprites permanecen visibles: el intercambio se realiza solo por escala.
## Las claves `emitiendo` de cada preset controlan cuándo DEJAN de nacer
## partículas, sin cortar las trayectorias ya iniciadas.
##
## El cuadro de diálogo son nodos de la ESCENA (`CajaDialogo` con su sprite,
## `CajaTextoBatalla` y su `Cursor`), no creados por script: así se pueden editar
## visualmente, como en `batalla.tscn`. Las preguntas SÍ/NO usan
## `MenuConfirmacion` en la posición de la batalla (`POSICION_MENU_SI_NO`).
##
## Los valores iniciales de todo lo que animan las pistas están también en la
## animación `RESET` de la escena.
##
## Se conservan en el recurso las animaciones anteriores como referencia; la
## ejecución usa la secuencia nueva de pistas indicada arriba.
## F6 sobre escena_evolucion_anim.tscn reproduce una vista previa completa
## SILCOON -> BEAUTIFLY sin modificar Pokémon ni partidas y sin esperar botones.

## Emitida al terminar, ya en negro.
signal terminada(evoluciono: bool)
signal vista_previa_terminada

## Ventana SÍ/NO (`MenuConfirmacion`), misma posición que en la batalla y en la
## eclosión de huevo (battle_presentation_controller.POSICION_MENU_SI_NO).
const POSICION_MENU_SI_NO: Vector2 = Vector2(184, 64)
## Por encima de `CajaDialogo` (z_index 10).
const Z_MENU_SI_NO: int = 11
## La ficha para olvidar movimientos tapa también la caja de diálogo (bajo Negro, z 20).
const Z_FICHA_OLVIDAR: int = 12
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
## Base de tiempo de las animaciones del AnimationPlayer (GBA corre a 60 fps).
const FPS_GBA: float = 60.0
## Escala de la silueta oculta: 0 la deja fuera de pantalla, sin tocar
## `visible` (el intercambio de siluetas es solo de escala).
const ESCALA_OCULTA: Vector2 = Vector2.ZERO

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

# --- Nodos de la escena ---
## CanvasItem y no ColorRect: el fondo puede ser ColorRect o Sprite2D.
@onready var _fondo: CanvasItem = %Fondo
@onready var _sprite_previo: Sprite2D = %SpritePrevio
@onready var _sprite_nuevo: Sprite2D = %SpriteNuevo
@onready var _destello: ColorRect = %Destello
@onready var _negro: ColorRect = %Negro
@onready var _animacion: AnimationPlayer = %Animacion
@onready var _emisores: Array[Node2D] = [
	$ParticulasRemolinoCurvo, $ParticulasJaula, $ParticulasCirculo, $ParticulasFuente,
]
## Cuadro de diálogo de la escena (sprite + CajaTextoBatalla + cursor).
@onready var _caja_dialogo: Sprite2D = %CajaDialogo
@onready var _caja_texto: CajaTextoBatalla = %RichTextLabel
@onready var _cursor: AnimatedSprite2D = %Cursor

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
	var escena: EscenaEvolucionAnim = preload("res://escenas/evolucion/escena_evolucion_anim.tscn").instantiate()
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
	if _animacion == null or _sprite_previo == null or _caja_dialogo == null or _caja_texto == null:
		push_error("[EscenaEvolucionAnim] Faltan nodos: instancia escena_evolucion_anim.tscn (Fondo, SpritePrevio, SpriteNuevo, Destello, Negro, Animacion, CajaDialogo, RichTextLabel, Cursor).")
		_terminar(false)
		return
	layer = CAPA_EVOLUCION
	_animacion.stop()
	_reiniciar_estado_visual()
	_negro.modulate.a = 1.0 if desde_negro else 0.0
	# Cuadro y cursor son nodos de la escena; `set_cursor` los conecta igual que
	# en batalla.gd y en la eclosión. El cuadro se queda oculto hasta el primer
	# mensaje.
	_caja_texto.set_cursor(_cursor)
	_caja_dialogo.visible = false
	_capa_menus = Control.new()
	_capa_menus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capa_menus.size = TAMANO_PANTALLA
	add_child(_capa_menus)
	_reproductor_musica = AudioStreamPlayer.new()
	add_child(_reproductor_musica)
	_reproductor_se = AudioStreamPlayer.new()
	add_child(_reproductor_se)
	# El cuadro de diálogo y los menús deben quedar POR DEBAJO del fundido,
	# como en EscenaEvolucion: Negro ya está en el .tscn, pero lo creado aquí se
	# añade al final, así que lo devolvemos a la cima.
	move_child(_negro, get_child_count() - 1)
	# Comprobarlo diferido: al ejecutar una escena con F6, current_scene puede
	# asignarse después de _ready(). Como subescena instanciada no se autoinicia.
	call_deferred("_iniciar_vista_previa_si_f6")


func _exit_tree() -> void:
	_restaurar_musica_mapa()


func _iniciar_vista_previa_si_f6() -> void:
	if get_tree().current_scene != self:
		return
	_reproducir_vista_previa_f6()


## Vista previa independiente: usa los sprites de ejemplo del .tscn y las
## mismas pistas que la evolución real, pero no consulta ni muta BasePokemon,
## Pokédex, inventario o equipo. Deja el mensaje final visible hasta cerrar F6.
func _reproducir_vista_previa_f6() -> void:
	puede_cancelar = false
	_reiniciar_estado_visual()
	_fondo.visible = true
	_negro.modulate.a = 1.0
	_caja_dialogo.visible = false
	await _reproducir("intro")
	await _mostrar(tr("EVOLUCION_ANIM_INICIO").replace("{mon}", "SILCOON"), false)
	_reproducir_musica(TEMA_EVOLUCION)
	await _reproducir_transformacion_visual()
	_reproductor_musica.stop()
	await _mostrar(tr("EVOLUCION_ANIM_FIN").replace("{mon}", "SILCOON").replace("{especie}", "BEAUTIFLY"), false, true)
	vista_previa_terminada.emit()


## Ejecuta la secuencia completa. Devuelve true si el Pokémon evolucionó.
func ejecutar() -> bool:
	if pokemon == null or destino.is_empty():
		push_warning("[EscenaEvolucionAnim] Sin Pokémon o sin especie de destino")
		_terminar(false)
		return false
	if _animacion.is_playing():
		_animacion.stop()
	_reiniciar_estado_visual()
	var especie_previa := pokemon.nombre_interno
	var nombre_previo := pokemon.get_nombre_mostrar()
	_preparar_sprites(especie_previa)
	_fondo.visible = desde_negro
	_mostrar_sprite(_sprite_previo, desde_negro)
	if not desde_negro:
		await _reproducir("oscurecer")
		_fondo.visible = true
		_mostrar_sprite(_sprite_previo, true)
	_pausar_musica_mapa()

	# Transición negra desde batalla y mensaje sobre el campo todavía iluminado.
	await _reproducir("intro")
	await _mostrar(tr("EVOLUCION_ANIM_INICIO").replace("{mon}", nombre_previo), false)
	await _reproducir_grito(pokemon.numero_nacional)
	_reproducir_musica(TEMA_EVOLUCION)

	if await _reproducir_transformacion_visual():
		_limpiar_emisores()
		await _cancelar(nombre_previo)
		await _salir()
		_terminar(false)
		return false

	_reproductor_musica.stop()
	var numero_nuevo := int(DatabaseManager.obtener_datos_pokemon(destino).get("numero_nacional", 0))
	await _reproducir_grito(numero_nuevo)

	# Estado 13: cambio de especie, Pokédex y enhorabuena.
	EvolucionPokemon.evolucionar(pokemon, destino)
	EvolucionPokemon.registrar_evolucion(destino)
	var fanfarria := _crear_reproductor_tema(TEMA_EVOLUCIONADO)
	if fanfarria != null:
		fanfarria.play()
	await _mostrar(tr("EVOLUCION_ANIM_FIN").replace("{mon}", nombre_previo).replace("{especie}", pokemon.nombre), true, true)
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
	_mostrar_sprite(_sprite_nuevo, false)
	_mostrar_sprite(_sprite_previo, true)
	await _reproducir("cancelar")
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


## Lista de movimientos (0-3 olvidar, 4 = ninguno).
func elegir_movimiento_aprendizaje(aprendizaje: AprendizajeMovimientos, _nombre_mov: String) -> int:
	if sin_interfaz:
		return int(elecciones_prueba.pop_front()) if not elecciones_prueba.is_empty() else FichaOlvidarMovimiento.INDICE_NUEVO
	await _mostrar(tr("EVOLUCION_MOV_CUAL"), false)
	# ShowSelectMovePokemonSummaryScreen: la ficha ocupa toda la pantalla con fundido.
	var ficha: FichaOlvidarMovimiento = SCN_FICHA_OLVIDAR.instantiate()
	ficha.z_index = Z_FICHA_OLVIDAR
	_capa_menus.add_child(ficha)
	var indice: int = await ficha.elegir_aprendizaje(aprendizaje)
	ficha.queue_free()
	return indice


# ==============================================
# ANIMACIÓN (delegada al AnimationPlayer)
# ==============================================

## Compartida entre el juego y F6: así la vista previa siempre usa las mismas
## pistas, tiempos y emisiones. Devuelve true si se canceló en el intercambio.
func _reproducir_transformacion_visual() -> bool:
	# El fondo se oscurece sin tapar ni el cuadro de texto ni al Pokémon.
	await _reproducir("oscurecer_campo")
	await _reproducir("remolino_curvo")
	await _reproducir("jaula_particulas")
	_fijar_blanco(_sprite_nuevo, 1.0)
	if await _alternar_siluetas():
		return true
	# AnimationPlayer puede terminar una fracción de fotograma antes del último
	# valor; fijar exactamente 0/1 después del intercambio interpolado.
	_mostrar_sprite(_sprite_previo, false)
	_mostrar_sprite(_sprite_nuevo, true)
	print("[Evolución] Intercambio completo; comienzan los dos círculos.")
	await _reproducir("dos_circulos")
	await _reproducir("fuente_y_destello")
	return false


## Reproduce una animación del AnimationPlayer y espera a que termine. Con
## `sin_interfaz` aplica el último fotograma y sigue, sin esperar.
func _reproducir(nombre: String) -> void:
	if _animacion == null or not _animacion.has_animation(nombre):
		return
	_animacion.play(nombre)
	if sin_interfaz:
		_animacion.seek(_animacion.get_animation(nombre).length, true)
		return
	await _animacion.animation_finished


## Intercambia las siluetas mediante escala; devuelve true si se interrumpe con B.
func _alternar_siluetas() -> bool:
	if sin_interfaz:
		if cancelar_prueba and puede_cancelar:
			return true
		await _reproducir("intercambio")
		return false
	var estado := {"terminada": false}
	var al_terminar := func(nombre: StringName) -> void:
		if nombre == &"intercambio":
			estado["terminada"] = true
	_animacion.animation_finished.connect(al_terminar)
	var duracion: float = _animacion.get_animation("intercambio").length
	var inicio_ms: int = Time.get_ticks_msec()
	var ultimo_aviso: int = 0
	var alternancias: int = _animacion.get_animation("intercambio").track_get_key_count(0) - 1
	print("[Evolución] Inicia intercambio: %d alternancias de escala aceleradas en %.2f s." % [alternancias, duracion])
	_animacion.play("intercambio")
	while not estado["terminada"]:
		if puede_cancelar and _b_mantenido():
			# stop() no emite animation_finished: la animación queda cortada en
			# el fotograma actual, como el B del decomp.
			var posicion_cancelar: float = _animacion.current_animation_position
			_animacion.stop()
			_animacion.animation_finished.disconnect(al_terminar)
			print("[Evolución] Intercambio cancelado en %.2f / %.2f s." % [posicion_cancelar, duracion])
			return true
		var segundo: int = int(_animacion.current_animation_position)
		if segundo >= ultimo_aviso + 2:
			ultimo_aviso = segundo
			print("[Evolución] Intercambio en curso: %.2f / %.2f s." % [_animacion.current_animation_position, duracion])
		await get_tree().process_frame
	_animacion.animation_finished.disconnect(al_terminar)
	print("[Evolución] Intercambio terminado: %.2f / %.2f s de animación (%.2f s reales)." % [
		_animacion.current_animation_position, duracion,
		float(Time.get_ticks_msec() - inicio_ms) / 1000.0,
	])
	# Dejar dibujar el último fotograma antes de iniciar los círculos.
	await get_tree().process_frame
	return false


func _preparar_sprites(especie_previa: String) -> void:
	_sprite_previo.texture = PokemonSpriteManager.cargar_sprite_frente(especie_previa, pokemon.es_shiny())
	_sprite_nuevo.texture = PokemonSpriteManager.cargar_sprite_frente(destino, pokemon.es_shiny())
	_fijar_blanco(_sprite_previo, 0.0)
	_fijar_blanco(_sprite_nuevo, 0.0)


func _reiniciar_estado_visual() -> void:
	_limpiar_emisores()
	_fondo.modulate = Color.WHITE
	_destello.modulate.a = 0.0
	_fijar_blanco(_sprite_previo, 0.0)
	_fijar_blanco(_sprite_nuevo, 0.0)
	_mostrar_sprite(_sprite_previo, true)
	_mostrar_sprite(_sprite_nuevo, false)


func _limpiar_emisores() -> void:
	for emisor in _emisores:
		emisor.call("limpiar")


## Muestra u oculta una silueta SIN tocar `visible`: la visibilidad se queda
## activa mientras dura el fondo y el shader blanco, y el intercambio se hace
## con la escala (1.0 mostrada, `ESCALA_OCULTA` oculta).
func _mostrar_sprite(sprite: Sprite2D, mostrar: bool) -> void:
	sprite.visible = true
	sprite.scale = Vector2.ONE if mostrar else ESCALA_OCULTA


func _fijar_blanco(sprite: Sprite2D, valor: float) -> void:
	(sprite.material as ShaderMaterial).set_shader_parameter("blanco", valor)


## Estado 15: fundido a negro y música del mapa.
func _salir() -> void:
	_cerrar_dialogo()
	_limpiar_emisores()
	await _reproducir("salida")
	_reproductor_musica.stop()
	_restaurar_musica_mapa()
	if oscurecer_telon_al_salir and not sin_interfaz and Singleton.obtener_nodo("Telon") != null:
		await Singleton.transicion("oscurecer", 0.01)


func _terminar(evoluciono: bool) -> void:
	if _terminada:
		return
	_terminada = true
	terminada.emit(evoluciono)


func _b_mantenido() -> bool:
	if sin_interfaz:
		return cancelar_prueba
	return Input.is_action_pressed("btn_cancelar")


# ==============================================
# TEXTOS
# ==============================================

## Muestra `texto`; con `esperar_boton` espera A/B, si no sigue al terminar de
## escribirlo. El cuadro queda abierto hasta el siguiente texto.
func _mostrar(texto: String, esperar_boton: bool = true, ajustar_dos_lineas: bool = false) -> void:
	if sin_interfaz:
		return
	# La segunda línea de la felicitación puede ser larga. Ajustar su fuente
	# para conservar las dos líneas dentro del cuadro, sin alterar otros textos.
	var tamano_fuente: int = 15
	if ajustar_dos_lineas:
		var fuente: Font = _caja_texto.get_theme_font("normal_font")
		for linea in texto.split("\n"):
			while tamano_fuente > 10 and fuente.get_string_size(linea, HORIZONTAL_ALIGNMENT_LEFT, -1, tamano_fuente).x > _caja_texto.size.x:
				tamano_fuente -= 1
	_caja_texto.add_theme_font_size_override("normal_font_size", tamano_fuente)
	_caja_dialogo.visible = true
	await _caja_texto.mostrar_texto(texto)
	if esperar_boton:
		await _caja_texto.esperar_input_continuar(Callable())


## Ventana SÍ/NO (`MenuConfirmacion`); CANCELAR equivale a NO. El texto de la
## pregunta lo muestra antes el cuadro, como en batalla y en la eclosión.
func _preguntar(texto: String) -> bool:
	if sin_interfaz:
		# Sin respuestas: SÍ (acaba siempre: elegir "ninguno" y dejar de aprender).
		return bool(respuestas_prueba.pop_front()) if not respuestas_prueba.is_empty() else true
	await _mostrar(texto, false)
	var menu := MenuConfirmacion.new()
	menu.z_index = Z_MENU_SI_NO
	add_child(menu)
	menu.crear_menu(POSICION_MENU_SI_NO)
	var respuesta: String = await menu.opcion_seleccionada
	menu.queue_free()
	return respuesta == "Y"


func _cerrar_dialogo() -> void:
	if _caja_texto != null:
		_caja_texto.limpiar()
	if _caja_dialogo != null:
		_caja_dialogo.visible = false


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
