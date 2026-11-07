## Secuencia de eclosión de un huevo (pokeruby `src/egg_hatch.c`).
##
## Superposición a pantalla completa que se añade al CanvasLayer `Menu` del
## AdministradorMapa (patrón de `evento_pc_centro.gd`): el llamador funde a
## negro, la añade, llama a `iniciar()`, aclara y espera `terminado`.
##
## Orden (CB2_EggHatch_1 y SpriteCB_Egg_0..5):
## 1. el huevo se tambalea tres veces y se agrieta (fragmentos y SE_BOWA);
## 2. destello blanco: se aplican los datos del recién nacido
##    (`Guarderia.eclosionar`) y se registra en la Pokédex;
## 3. aparece el Pokémon con su grito;
## 4. "¡{mon} ha salido del HUEVO!" con la fanfarria;
## 5. "¿Quieres darle un mote a {mon}?" SÍ/NO; con SÍ se
##    abre `entrada_nombre` (vacío o cancelado deja el mote vacío).
## El texto usa la caja de diálogo de batalla (como el original, que muestra el
## mensaje con la ventana de combate), no la del mapa; el Telon (z_index 10)
## sigue tapándolo todo en los fundidos.
class_name EclosionHuevo
extends Control

## Emitida al terminar la secuencia (el llamador funde a negro, salvo que ya
## lo esté según `pantalla_en_negro`, y la libera).
signal terminado
## Emitida por los handlers de la pantalla de nombre.
signal _nombre_introducido(nombre: String)

const TEXTURA_FRAGMENTO: Texture2D = preload("res://graficos/crianza/eclosion_fragmento.png")
const SCN_ENTRADA_NOMBRE: PackedScene = preload("res://escenas/entrada_nombre/entrada_nombre.tscn")
const TEXTURA_CAJA_DIALOGO: Texture2D = preload("res://graficos/batalla/caja_dialogo.png")
const TEXTURA_PUNTERO_TEXTO: Texture2D = preload("res://UI/puntero_texto.png")
const FUENTE_TEXTO: FontFile = preload("res://fuentes/pokemon-rs.ttf")

## data/strings2.s: gOtherText_HatchedFromEgg y gOtherText_NickHatchPrompt.
const TEXTO_NACIO: String = "¡{mon} ha salido del HUEVO!"
const TEXTO_PREGUNTA_MOTE: String = "¿Quieres darle un mote a {mon}?"
## Igual que battle_presentation_controller.pedir_mote.
const TITULO_MOTE: String = "¿Mote de %s?"
## pokeruby POKEMON_NAME_LENGTH.
const MAX_CARACTERES_MOTE: int = 10
## entrada_nombre.gd TipoObjetivo.POKEMON / SexoPokemon.
const ENTRADA_NOMBRE_POKEMON: int = 2
const ENTRADA_NOMBRE_SEXO: Dictionary = {"M": 1, "F": 2}

## Ruta de los gritos (batalla.gd CRY_BASE_PATH + "%03dCry.ogg").
const RUTA_GRITO: String = "res://Audio/SE/Cries/%03dCry.ogg"
## Efectos de toda la secuencia en un solo audio (SE_BOWA de las grietas y SE_TAMAGO de la
## rotura, ya separados por sus silencios): se lanza en la primera grieta y las demás
## suenan solas al ritmo de las sacudidas.
const SE_ECLOSION: AudioStream = preload("res://Audio/eclosion_huevo_AXVS_efectos.wav")
## Claves de Singleton.TEMAS_REGISTRADOS: MUS_SHINKA de fondo y MUS_FANFA5 al nacer.
const TEMA_FONDO: String = "EVOLUCION"
const TEMA_NACIMIENTO: String = "CONGRATULATIONS_YOUR_POKEMON_EVOLVED"
## Espera máxima de la fanfarria (por si el stream no emitiera finished).
const ESPERA_MAXIMA_FANFARRIA: float = 8.0

## Todas las duraciones del decomp van en frames de GBA.
const FPS_GBA: float = 60.0
## Espera tras el fundido de entrada antes de tambalearse (CB2_PalCounter > 30).
const FRAMES_ESPERA_INICIAL: int = 30
## Paso del ángulo del tambaleo por frame (data[1] += 20, sobre 256).
const PASO_ANGULO: int = 20
## Pausa entre sacudidas (data[2] > 30) y antes del destello (SpriteCB_Egg_3).
const FRAMES_PAUSA_SACUDIDA: int = 30
const FRAMES_PAUSA_DESTELLO: int = 50
## Fundido a blanco y de vuelta (BeginNormalPaletteFade con retardo -1).
const DURACION_DESTELLO: float = 8.0 / FPS_GBA
const DURACION_VUELTA_DESTELLO: float = 16.0 / FPS_GBA
## El Pokémon sube 1 px por frame durante 10 frames al aparecer.
const SUBIDA_POKEMON: float = 10.0
## Fin de SpriteCB_Egg_5 (data[0] > 40).
const FRAMES_POKEMON: int = 40

## Caja de texto de batalla (batalla.tscn: UI/CajaDialogo, RichTextLabel y Cursor) y
## posición del SÍ/NO (battle_presentation_controller.POSICION_MENU_SI_NO).
const POSICION_CAJA_DIALOGO: Vector2 = Vector2(0, 112)
const POSICION_TEXTO_CAJA: Vector2 = Vector2(16, 8)
const TAMANO_TEXTO_CAJA: Vector2 = Vector2(208, 32)
const POSICION_CURSOR_CAJA: Vector2 = Vector2(224, 30)
const POSICION_MENU_SI_NO: Vector2 = Vector2(184, 64)

## Posiciones del decomp (pantalla de 240x160): centro del huevo, centro del
## sprite del Pokémon y origen de los fragmentos.
const POSICION_HUEVO: Vector2 = Vector2(120, 75)
const POSICION_POKEMON: Vector2 = Vector2(120, 70)
const ORIGEN_FRAGMENTOS: Vector2 = Vector2(120, 60)
## Línea en la que se apoyan los pies del Pokémon al aparecer (antes de subir):
## sustituye a gMonFrontPicCoords[].y_offset, que el proyecto no tiene.
const PIES_POKEMON_Y: float = 102.0
## sEggShardVelocities (Q8.8 → píxeles por frame) y gravedad data[3] = 100.
const VELOCIDADES_FRAGMENTOS: Array[Vector2] = [
	Vector2(-1.5, -3.75), Vector2(-5, -3), Vector2(3.5, -3), Vector2(-4, -3.75),
	Vector2(2, -1.5), Vector2(-0.5, -6.75), Vector2(5, -2.25), Vector2(-1.5, -3.75),
	Vector2(4.5, -1.5), Vector2(-1, -6.75), Vector2(4, -2.25), Vector2(-3.5, -3.75),
	Vector2(1, -1.5), Vector2(-3.515625, -6.75), Vector2(4.5, -2.25), Vector2(-0.5, -7.5),
	Vector2(1, -4.5), Vector2(-2.5, -2.25), Vector2(2.5, -7.5),
]
const GRAVEDAD_FRAGMENTO: float = 100.0 / 256.0
## Un fragmento desaparece al bajar más de 20 px de su origen.
const CAIDA_MAXIMA_FRAGMENTO: float = 20.0

@onready var huevo: Sprite2D = $Huevo
@onready var sprite_pokemon: Sprite2D = $Pokemon
@onready var destello: ColorRect = $Destello
@onready var capa_fragmentos: Node2D = $Fragmentos
@onready var reproductor_se: AudioStreamPlayer = $ReproductorSE
@onready var reproductor_musica: AudioStreamPlayer = $ReproductorMusica

## Caja de texto de batalla, creada en `_ready()` (oculta hasta el primer mensaje).
var caja_dialogo: Sprite2D = null
var caja_texto: CajaTextoBatalla = null
var pokemon: BasePokemon = null
## true si la secuencia termina con la pantalla ya en negro (tras la pantalla de
## nombre): el llamador solo tiene que liberarla y aclarar.
var pantalla_en_negro: bool = false

var _angulo: int = 0
var _indice_fragmento: int = 0
## Fragmentos vivos: {"sprite": Sprite2D, "velocidad": Vector2, "desplazamiento": Vector2}.
var _fragmentos: Array[Dictionary] = []
var _musica_mapa: AudioStreamPlayer = null
var _musica_mapa_procesaba: bool = false
var _musica_mapa_pausada: bool = false
var _terminada: bool = false


func _ready() -> void:
	destello.modulate.a = 0.0
	sprite_pokemon.visible = false
	huevo.position = POSICION_HUEVO
	huevo.frame = 0
	_crear_caja_dialogo()


func _exit_tree() -> void:
	_restaurar_musica_mapa()


func _process(delta: float) -> void:
	_mover_fragmentos(delta * FPS_GBA)


## Lanza la secuencia para `p_pokemon` (un huevo del equipo). Prepara la escena
## al momento y devuelve en el primer `await`; emite `terminado` al acabar
## (también, en diferido, si no recibe un huevo).
func iniciar(p_pokemon: BasePokemon, guarderia: Guarderia, lugar: String) -> void:
	pokemon = p_pokemon
	if pokemon == null or not pokemon.huevo or guarderia == null:
		push_warning("[EclosionHuevo] iniciar() sin huevo o sin guardería")
		_finalizar.call_deferred()
		return
	huevo.visible = true
	huevo.frame = 0
	_pausar_musica_mapa()
	_reproducir_musica(TEMA_FONDO)

	await _esperar_frames(FRAMES_ESPERA_INICIAL)
	await _tambalear(guarderia, lugar)
	await _mostrar_textos()
	_finalizar()


## true cuando ya se emitió `terminado`.
func esta_terminada() -> bool:
	return _terminada


## Datos del recién nacido (CreatedHatchedMon) y Pokédex vista + atrapada
## (AddHatchedMonToParty). Público para los tests.
func aplicar_eclosion(guarderia: Guarderia, lugar: String) -> void:
	guarderia.eclosionar(pokemon, lugar)
	SistemaGuardado.registrar_pokemon_atrapado(pokemon.nombre_interno)


# ==============================================
# ANIMACIÓN
# ==============================================

## SpriteCB_Egg_0..5: tres sacudidas con grietas, pausa, destello, rotura y
## aparición del Pokémon.
func _tambalear(guarderia: Guarderia, lugar: String) -> void:
	# SpriteCB_Egg_0: 20 frames de amplitud 1; grieta en el frame 15.
	await _sacudir(20, 1.0, {15: func() -> void:
		_reproducir_se(SE_ECLOSION)
		_agrietar(1, 1)
	})
	# SpriteCB_Egg_1: pausa y 20 frames de amplitud 2; grieta en el 15.
	await _esperar_frames(FRAMES_PAUSA_SACUDIDA)
	await _sacudir(20, 2.0, {15: func() -> void: _agrietar(2, 0)})
	# SpriteCB_Egg_2: pausa y 38 frames; grieta con dos fragmentos en el 15.
	# Ruby repite la animación 2; se usa la 3 (la última
	# grieta de egg_hatch.png, como Esmeralda).
	await _esperar_frames(FRAMES_PAUSA_SACUDIDA)
	await _sacudir(38, 2.0, {
		15: func() -> void: _agrietar(3, 2),
	})
	huevo.position = POSICION_HUEVO
	# SpriteCB_Egg_3: pausa antes de romperse.
	await _esperar_frames(FRAMES_PAUSA_DESTELLO)
	# SpriteCB_Egg_4: fundido a blanco con cuatro fragmentos por frame.
	var tween := create_tween()
	tween.tween_property(destello, "modulate:a", 1.0, DURACION_DESTELLO)
	for i in range(4):
		for j in range(4):
			_crear_fragmento()
		await _esperar_frames(1)
	await tween.finished
	huevo.visible = false
	aplicar_eclosion(guarderia, lugar)
	# SpriteCB_Egg_5: aparece el Pokémon, sube 10 px y vuelve el color.
	_preparar_sprite_pokemon()
	_reproducir_grito()
	var subida := create_tween()
	subida.tween_property(sprite_pokemon, "position:y", sprite_pokemon.position.y - SUBIDA_POKEMON, SUBIDA_POKEMON / FPS_GBA)
	var vuelta := create_tween()
	vuelta.tween_interval(8.0 / FPS_GBA)
	vuelta.tween_property(destello, "modulate:a", 0.0, DURACION_VUELTA_DESTELLO)
	await _esperar_frames(FRAMES_POKEMON)


## Tambaleo horizontal `x = Sin(ángulo, amplitud)` durante `frames` frames,
## con `eventos` {frame: Callable} en los frames indicados.
func _sacudir(frames: int, amplitud: float, eventos: Dictionary) -> void:
	var angulo_inicial := _angulo
	var tween := create_tween()
	tween.tween_method(
		func(f: float) -> void: _colocar_huevo(angulo_inicial, int(f), amplitud),
		1.0, float(frames), float(frames) / FPS_GBA
	)
	for frame_evento in eventos:
		var accion: Callable = eventos[frame_evento]
		var disparo := create_tween()
		disparo.tween_interval(float(frame_evento) / FPS_GBA)
		disparo.tween_callback(accion)
	await tween.finished
	_angulo = (angulo_inicial + PASO_ANGULO * frames) & 0xFF


func _colocar_huevo(angulo_inicial: int, frame_actual: int, amplitud: float) -> void:
	var angulo := (angulo_inicial + PASO_ANGULO * frame_actual) & 0xFF
	# Sin() del GBA: (gSineTable[x] * amplitud) >> 8, es decir, redondeo hacia abajo.
	huevo.position.x = POSICION_HUEVO.x + floorf(sin(TAU * angulo / 256.0) * amplitud)


## Cambia al grabado `frame` de egg_hatch.png y suelta fragmentos.
func _agrietar(frame: int, fragmentos: int) -> void:
	huevo.frame = frame
	for i in range(fragmentos):
		_crear_fragmento()


## CreateRandomEggShardSprite: velocidad de la tabla en orden y grabado al azar.
func _crear_fragmento() -> void:
	var fragmento := Sprite2D.new()
	fragmento.texture = TEXTURA_FRAGMENTO
	fragmento.hframes = 4
	fragmento.frame = randi() % 4
	fragmento.position = ORIGEN_FRAGMENTOS
	capa_fragmentos.add_child(fragmento)
	var velocidad: Vector2 = VELOCIDADES_FRAGMENTOS[_indice_fragmento % VELOCIDADES_FRAGMENTOS.size()]
	_indice_fragmento += 1
	_fragmentos.append({"sprite": fragmento, "velocidad": velocidad, "desplazamiento": Vector2.ZERO})


## SpriteCB_EggShard: movimiento balístico; se destruye al caer 20 px.
func _mover_fragmentos(frames: float) -> void:
	for i in range(_fragmentos.size() - 1, -1, -1):
		var datos: Dictionary = _fragmentos[i]
		var sprite: Sprite2D = datos["sprite"]
		var velocidad: Vector2 = datos["velocidad"]
		var desplazamiento: Vector2 = datos["desplazamiento"] + velocidad * frames
		velocidad.y += GRAVEDAD_FRAGMENTO * frames
		datos["velocidad"] = velocidad
		datos["desplazamiento"] = desplazamiento
		sprite.position = ORIGEN_FRAGMENTOS + desplazamiento.floor()
		if desplazamiento.y > CAIDA_MAXIMA_FRAGMENTO and velocidad.y > 0.0:
			sprite.queue_free()
			_fragmentos.remove_at(i)


## Sprite frontal centrado en POSICION_POKEMON con los pies en PIES_POKEMON_Y.
func _preparar_sprite_pokemon() -> void:
	# pokeruby egg_hatch.c: el frente lleva las manchas de SPINDA.
	var textura := PokemonSpriteManager.cargar_sprite_frente(pokemon.nombre_interno, pokemon.es_shiny(), pokemon.personalidad)
	sprite_pokemon.texture = textura
	sprite_pokemon.position = POSICION_POKEMON
	if textura != null:
		var imagen := textura.get_image()
		if imagen != null:
			var usado := imagen.get_used_rect()
			if usado.size.y > 0:
				var pies := POSICION_POKEMON.y - textura.get_height() / 2.0 + usado.end.y
				sprite_pokemon.position.y += PIES_POKEMON_Y - pies
	sprite_pokemon.visible = true


# ==============================================
# TEXTOS Y MOTE
# ==============================================

func _mostrar_textos() -> void:
	var nombre := pokemon.get_nombre_mostrar()
	caja_dialogo.visible = true
	# Mensaje y fanfarria a la vez; la pregunta sale al acabar la fanfarria. El tema de
	# fondo no se corta: baja, se pausa y vuelve a subir (como Fanfarria con la del mapa).
	var fanfarria := _crear_fanfarria(TEMA_NACIMIENTO)
	var volumen_fondo_db := reproductor_musica.volume_db
	if fanfarria != null:
		_bajar_musica_fondo(volumen_fondo_db)
		fanfarria.play()
	await caja_texto.mostrar_texto(TEXTO_NACIO.replace("{mon}", nombre))
	await caja_texto.esperar_input_continuar(Callable())
	if fanfarria != null:
		await _esperar_fin_musica(fanfarria)
		fanfarria.queue_free()
		await _subir_musica_fondo(volumen_fondo_db)
	await caja_texto.mostrar_texto(TEXTO_PREGUNTA_MOTE.replace("{mon}", nombre))
	if not await _preguntar_si_no():
		caja_dialogo.visible = false
		return
	caja_dialogo.visible = false
	var mote := await _pedir_mote()
	if not mote.is_empty():
		pokemon.mote = mote


## Ventana SÍ/NO de batalla (MenuConfirmacion); CANCELAR equivale a NO.
func _preguntar_si_no() -> bool:
	var menu := MenuConfirmacion.new()
	menu.z_index = 6
	add_child(menu)
	menu.crear_menu(POSICION_MENU_SI_NO)
	var respuesta: String = await menu.opcion_seleccionada
	menu.queue_free()
	return respuesta == "Y"


## Pantalla de nombre como battle_presentation_controller.pedir_mote: "" si se
## confirma vacío o se cancela.
func _pedir_mote() -> String:
	await Singleton.transicion("oscurecer")
	_ocultar_escena()
	var entrada := SCN_ENTRADA_NOMBRE.instantiate() as Control
	# Por encima del cuadro de diálogo (1) y por debajo del Telon (10).
	entrada.z_index = 2
	entrada.set("sexo_pokemon", int(ENTRADA_NOMBRE_SEXO.get(pokemon.sexo, 0)))
	# La respuesta puede llegar durante el fundido: se guarda y se emite.
	var respuesta := {"lista": false, "nombre": ""}
	var al_confirmar := func(nombre: String) -> void:
		respuesta["lista"] = true
		respuesta["nombre"] = nombre
		_nombre_introducido.emit(nombre)
	var al_cancelar := func() -> void:
		respuesta["lista"] = true
		_nombre_introducido.emit("")
	entrada.connect("nombre_confirmado", al_confirmar, CONNECT_ONE_SHOT)
	entrada.connect("cancelado", al_cancelar, CONNECT_ONE_SHOT)
	add_child(entrada)
	entrada.call(
		"configurar",
		TITULO_MOTE % pokemon.get_nombre_mostrar(),
		MAX_CARACTERES_MOTE,
		false,
		ENTRADA_NOMBRE_POKEMON,
		maxi(pokemon.numero_nacional, 1)
	)
	await Singleton.transicion("aclarar")
	if not bool(respuesta["lista"]):
		await _nombre_introducido
	# Se sale en negro directamente al mapa: la eclosión ya no vuelve a verse.
	await Singleton.transicion("oscurecer")
	entrada.queue_free()
	pantalla_en_negro = true
	return str(respuesta["nombre"]).strip_edges()


## Oculta los elementos de la eclosión (no la pantalla de nombre que se añada después).
func _ocultar_escena() -> void:
	for hijo in get_children():
		if hijo is CanvasItem:
			(hijo as CanvasItem).visible = false


## Caja de diálogo de batalla (graficos/batalla/caja_dialogo.png) con su texto y el
## cursor de continuar, igual que UI/CajaDialogo de batalla.tscn.
func _crear_caja_dialogo() -> void:
	caja_dialogo = Sprite2D.new()
	caja_dialogo.name = "CajaDialogo"
	caja_dialogo.texture = TEXTURA_CAJA_DIALOGO
	caja_dialogo.centered = false
	caja_dialogo.position = POSICION_CAJA_DIALOGO
	caja_dialogo.z_index = 1
	caja_dialogo.visible = false
	add_child(caja_dialogo)

	caja_texto = CajaTextoBatalla.new()
	caja_texto.name = "Texto"
	caja_texto.position = POSICION_TEXTO_CAJA
	caja_texto.size = TAMANO_TEXTO_CAJA
	caja_texto.add_theme_color_override("font_shadow_color", Color.BLACK)
	caja_texto.add_theme_font_override("normal_font", FUENTE_TEXTO)
	caja_texto.add_theme_font_size_override("normal_font_size", 15)
	caja_dialogo.add_child(caja_texto)

	var fotogramas := SpriteFrames.new()
	for i in range(4):
		var atlas := AtlasTexture.new()
		atlas.atlas = TEXTURA_PUNTERO_TEXTO
		atlas.region = Rect2(8 * i, 0, 8, 16)
		fotogramas.add_frame("default", atlas)
	fotogramas.set_animation_speed("default", 8.0)
	var cursor := AnimatedSprite2D.new()
	cursor.name = "Cursor"
	cursor.sprite_frames = fotogramas
	cursor.position = POSICION_CURSOR_CAJA
	caja_dialogo.add_child(cursor)
	caja_texto.set_cursor(cursor)


func _finalizar() -> void:
	if _terminada:
		return
	_terminada = true
	_detener_musica()
	terminado.emit()


# ==============================================
# SONIDO
# ==============================================

func _reproducir_se(stream: AudioStream) -> void:
	reproductor_se.stream = stream
	reproductor_se.play()


func _reproducir_grito() -> void:
	if pokemon.numero_nacional <= 0:
		return
	var ruta := RUTA_GRITO % pokemon.numero_nacional
	if not ResourceLoader.exists(ruta):
		return
	var grito := AudioStreamPlayer.new()
	grito.stream = load(ruta) as AudioStream
	grito.bus = reproductor_se.bus
	grito.finished.connect(grito.queue_free)
	add_child(grito)
	grito.play()


## Toca `tema` en el reproductor propio. Devuelve false si no se pudo cargar.
func _reproducir_musica(tema: String, en_bucle: bool = true) -> bool:
	var stream: AudioStream = Fanfarria.cargar_stream_tema(tema)
	if stream == null:
		return false
	if en_bucle:
		stream = stream.duplicate()
		if "loop" in stream:
			stream.set("loop", true)
	reproductor_musica.stop()
	reproductor_musica.stream = stream
	if is_instance_valid(_musica_mapa):
		reproductor_musica.bus = _musica_mapa.bus
	reproductor_musica.play()
	return true


func _detener_musica() -> void:
	if is_instance_valid(reproductor_musica):
		reproductor_musica.stop()


## Reproductor propio para la fanfarria de `tema` (sin arrancar), en el bus y al
## volumen del tema de fondo. null si el tema no pudo cargarse.
func _crear_fanfarria(tema: String) -> AudioStreamPlayer:
	var stream: AudioStream = Fanfarria.cargar_stream_tema(tema)
	if stream == null:
		return null
	var fanfarria := AudioStreamPlayer.new()
	fanfarria.stream = stream
	fanfarria.bus = reproductor_musica.bus
	fanfarria.volume_db = reproductor_musica.volume_db
	add_child(fanfarria)
	return fanfarria


## Baja el tema de fondo y lo pausa mientras suena la fanfarria.
func _bajar_musica_fondo(volumen_db: float) -> void:
	await Fanfarria.fundir_volumen_musica(reproductor_musica, volumen_db, -80.0, Fanfarria.DURACION_BAJADA_MUSICA)
	reproductor_musica.stream_paused = true


## Reanuda el tema de fondo pausado y lo sube hasta `volumen_db`.
func _subir_musica_fondo(volumen_db: float) -> void:
	reproductor_musica.stream_paused = false
	await Fanfarria.fundir_volumen_musica(reproductor_musica, -80.0, volumen_db, Fanfarria.DURACION_SUBIDA_MUSICA)


func _esperar_fin_musica(reproductor: AudioStreamPlayer) -> void:
	if not reproductor.playing:
		return
	var temporizador := get_tree().create_timer(ESPERA_MAXIMA_FANFARRIA)
	var fin := {"listo": false}
	var marcar := func() -> void: fin["listo"] = true
	reproductor.finished.connect(marcar, CONNECT_ONE_SHOT)
	temporizador.timeout.connect(marcar)
	while not bool(fin["listo"]):
		await get_tree().process_frame
	if reproductor.finished.is_connected(marcar):
		reproductor.finished.disconnect(marcar)


## Pausa la música del mapa como Fanfarria (su _process la relanzaría).
func _pausar_musica_mapa() -> void:
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


func _esperar_frames(frames: int) -> void:
	await get_tree().create_timer(float(frames) / FPS_GBA).timeout
