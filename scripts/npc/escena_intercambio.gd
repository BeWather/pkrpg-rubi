class_name EscenaIntercambio
extends EscenaEvolucion

## Escena del intercambio con un NPC (`DoInGameTradeScene`, pokeruby `src/trade.c`), en versión
## SENCILLA: NO es la animación original del cable (las dos POKé BALL cruzando la pantalla y el
## cable entre las consolas), pero respeta su orden y sus textos:
##  1. fundido desde negro, música MUS_EVOLUTION y el Pokémon del jugador en pantalla;
##  2. «{mon} se enviará a {EO}.» y «¡Adiós, {mon}!»: el Pokémon se vuelve blanco y desaparece;
##  3. el recibido aparece (de blanco a su color) con su grito;
##  4. «{EO} envió a {mon recibido}.» con la fanfarria MUS_EVOLVED y «¡Cuida bien de {mon recibido}!»;
##  5. fundido a negro y vuelta a la música del mapa.
## La escena no toca el equipo: quien la lanza (`IntercambioNpc`) hace el cambio después.
## Reutiliza de `EscenaEvolucion` la capa, el cuadro de diálogo, los fundidos y la música.

const FRAMES_SE_ENVIARA: int = 80
const FRAMES_ADIOS: int = 60
const FRAMES_A_BLANCO_ADIOS: int = 20
const FRAMES_ENVIO: int = 30
const FRAMES_CUIDALO: int = 60

## El Pokémon del jugador que se va y el que llega.
var saliente: BasePokemon = null
var entrante: BasePokemon = null
## Nombre del EO del Pokémon recibido (el NPC).
var entrenador: String = ""


## Crea la escena en la raíz, la ejecuta y la libera. `desde_negro`: quien llama ya está en
## negro (lo normal: oscurece el Telón del mapa antes). Termina siempre en negro.
static func intercambiar_en(arbol: SceneTree, p_saliente: BasePokemon, p_entrante: BasePokemon,
		p_entrenador: String, p_desde_negro: bool = true) -> void:
	var escena := EscenaIntercambio.new()
	escena.saliente = p_saliente
	escena.entrante = p_entrante
	escena.entrenador = p_entrenador
	escena.desde_negro = p_desde_negro
	arbol.root.add_child(escena)
	await escena.ejecutar_intercambio()
	escena.queue_free()


## Textos del trueque con los marcadores resueltos (se prueban sin lanzar la escena).
func texto_se_enviara() -> String:
	return _texto_escena("INTERCAMBIO_ESCENA_SE_ENVIARA")


func texto_adios() -> String:
	return _texto_escena("INTERCAMBIO_ESCENA_ADIOS")


func texto_envio() -> String:
	return _texto_escena("INTERCAMBIO_ESCENA_ENVIO")


func texto_cuidalo() -> String:
	return _texto_escena("INTERCAMBIO_ESCENA_CUIDALO")


func _texto_escena(clave: String) -> String:
	return tr(clave) \
		.replace("{mon_jugador}", saliente.get_nombre_mostrar() if saliente != null else "") \
		.replace("{mon_recibido}", entrante.get_nombre_mostrar() if entrante != null else "") \
		.replace("{entrenador}", entrenador)


## Ejecuta la secuencia. Termina en negro, con la música del mapa devuelta.
func ejecutar_intercambio() -> void:
	if saliente == null or entrante == null:
		push_warning("[EscenaIntercambio] Falta el Pokémon que sale o el que entra")
		_terminar(false)
		return
	_sprite_previo.texture = PokemonSpriteManager.cargar_sprite_frente_de(saliente)
	_sprite_nuevo.texture = PokemonSpriteManager.cargar_sprite_frente_de(entrante)
	_fijar_blanco(_sprite_previo, 0.0)
	_fijar_blanco(_sprite_nuevo, 1.0)
	_sprite_previo.visible = true
	_sprite_nuevo.visible = false
	_fondo.visible = true
	if not desde_negro:
		await _fundir(_negro, 1.0, FRAMES_FUNDIDO)
	_pausar_musica_mapa()

	# Aparece el Pokémon del jugador (case 0-1 de sub_804C29C) con la música del trueque.
	await _fundir(_negro, 0.0, FRAMES_FUNDIDO)
	_reproducir_musica(TEMA_EVOLUCION)

	# «{mon} se enviará a {EO}.» y «¡Adiós, {mon}!» (cases 10-12).
	await _mostrar(texto_se_enviara(), false)
	await _esperar_frames(FRAMES_SE_ENVIARA)
	_cerrar_dialogo()
	await _mostrar(texto_adios(), false)
	await _fundir_blanco(_sprite_previo, 1.0, FRAMES_A_BLANCO_ADIOS)
	_sprite_previo.visible = false
	await _esperar_frames(FRAMES_ADIOS)
	_cerrar_dialogo()

	# Llega el Pokémon recibido (case 67): de blanco a su color y su grito.
	_sprite_nuevo.visible = true
	await _fundir_blanco(_sprite_nuevo, 0.0, FRAMES_VUELTA_COLOR)
	await _reproducir_grito(entrante.numero_nacional)
	_reproductor_musica.stop()

	# «{EO} envió a {mon}.» con MUS_EVOLVED (case 68) y «¡Cuida bien de {mon}!» (case 69).
	var fanfarria_recibido := _crear_reproductor_tema(TEMA_EVOLUCIONADO)
	if fanfarria_recibido != null:
		fanfarria_recibido.play()
	await _mostrar(texto_envio(), false)
	await _esperar_frames(FRAMES_ENVIO)
	if fanfarria_recibido != null:
		await _esperar_fin_audio(fanfarria_recibido)
		fanfarria_recibido.queue_free()
	_cerrar_dialogo()
	await _mostrar(texto_cuidalo(), false)
	await _esperar_frames(FRAMES_CUIDALO)

	# Fundido a negro (case 73) y música del mapa.
	_cerrar_dialogo()
	await _fundir(_negro, 1.0, FRAMES_FUNDIDO)
	_restaurar_musica_mapa()
	_terminar(true)
