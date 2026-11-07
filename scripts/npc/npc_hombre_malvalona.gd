## npc_hombre_malvalona.gd
## "Hombre de Malvalona" del CENTRO POKéMON de CIUDAD MALVALONA (pokeruby:
## src/mauville_man.c + data/scripts/mauville_man.inc). Es un NPC con cinco
## variantes; cuál aparece lo decide el último dígito del ID de entrenador
## ((id % 10) / 2, SetupMauvilleOldMan). Sin mezcla de récords nunca cambia.
##
## Implementado: el BARDO completo, con la letra nueva escrita en la pantalla de
## PALABRAS FÁCILES (modo BARDO) y guardada en la partida. Las otras cuatro
## variantes siguen el camino del guion original que no depende de sistemas
## inexistentes (decoraciones, estadísticas de partida...).
##
## Patrón de diálogos y bloqueo del jugador: npc_abuela_descanso.gd.
@tool
extends "res://scripts/npc/npc_base.gd"

enum Variante { BARDO, MODERNO, CAMBIADOR, CUENTACUENTOS, RISUENO }

## -1 = según el ID de entrenador (original). 0..4 fuerza una Variante (pruebas).
@export_range(-1, 4) var variante_forzada: int = -1
## SpriteFrames por Variante (EVENT_OBJ_GFX_BARD + id). Una entrada vacía o
## ausente conserva selec_frames.
@export var sprites_variantes: Array[SpriteFrames] = []

const MOTIVO_PAUSA: StringName = &"hombre_malvalona"
const ESCENA_PALABRAS_FACILES: String = "res://UI/palabras_faciles/pantalla_palabras_faciles.tscn"

## ---------------------------------------------------------------------------
## BARDO (data/text/bard.inc; textos de la ROM española, 0x081B43F8-0x081B45A6)
## ---------------------------------------------------------------------------
const BARDO_SALUDO: String = "Hola, soy el BARDO.\\l¿Quieres oír mi canción?"
const BARDO_TRISTE: String = "Oh... Me has dejado más\\ltriste que el alpiste..."
const BARDO_EMOTIVA: String = "Es una canción tan conmovedora...\\lPodría cantarla sin parar..."
const BARDO_QUE_TE_PARECE: String = "¿Y...?\\l¿Te gusta mi canción?\\pPero la letra no me acaba de\\lconvencer. Le falta algo...\\p¿Querrías escribir otra letra\\lpara mí, por favor?"
const BARDO_GRACIAS: String = "¡Qué inspiración!\\lDéjame que te la cante..."
const BARDO_ASI_QUERIAS: String = "¿Es así como querías que sonara\\ltu canción?"
const BARDO_YA_ESTA: String = "Vale, pues ya está.\\lCantaré esta canción un rato."

## sDefaultBardSongLyrics de la ROM española (0x083E9330): MI HERMANA DEVORA /
## GOLOSINAS ¡LA! ¡LA, LA!. Ids de PALABRAS FÁCILES, 3 por página (2 + 1 línea).
const BARDO_LETRA_DEFECTO: Array[int] = [0x0E1E, 0x0A0F, 0x1005, 0x1A04, 0x0C39, 0x0C2A]
## gSaveBlock1.mauvilleMan.bard: songLyrics (ids separados por comas) y
## hasChangedSong. Sin texto guardado se canta la letra por defecto.
const CLAVE_LETRA_BARDO: String = "bardo_letra"
const BANDERA_CANCION_CAMBIADA: String = "bardo_cancion_cambiada"

## Ritmo aproximado de Task_BardSong (60 fps): 3 frames por letra más la espera
## del fonema, pausa entre palabras y 8 frames extra al cambiar de página.
const CANTO_POR_LETRA: float = 0.1
const CANTO_ENTRE_PALABRAS: float = 0.12
const CANTO_CAMBIO_PAGINA: float = 0.4
## "delay 60" tras ScrSpecial_PlayBardSong.
const CANTO_ESPERA_FINAL: float = 1.0
const CANTO_FUNDIDO_MUSICA: float = 0.3
## Escala para cada palabra (la voz original sintetiza fonemas; aquí un tono
## cuadrado con vibrato alterno, como voiceInflection).
const CANTO_ALTURAS: Array[float] = [1.0, 1.19, 1.33, 1.12, 1.5, 1.0]

## ---------------------------------------------------------------------------
## MODERNO / HIPSTER (data/text/hipster.inc)
## ---------------------------------------------------------------------------
const MODERNO_SALUDO: String = "¡Eh, tú! Me llaman el MODERNO.\\lTe enseñaré lo que está de moda."
const MODERNO_YA_SABES: String = "Pero, oye, tú ya sabes mucho de\\llo que está de moda.\\p¡No tengo nada nuevo que enseñarte!"

## ---------------------------------------------------------------------------
## CAMBIADOR / TRADER (data/text/trader.inc)
## ---------------------------------------------------------------------------
const CAMBIADOR_SALUDO: String = "¡Hola! Soy el CAMBIADOR.\\l¿Quieres cambiar decoraciones conmigo?"
const CAMBIADOR_RECHAZADO: String = "Oh...\\lMe siento rechazado..."
const CAMBIADOR_NADA: String = "¿No quieres nada?\\lMe siento rechazado..."

## ---------------------------------------------------------------------------
## CUENTACUENTOS / STORYTELLER (data/text/storyteller.inc)
## ---------------------------------------------------------------------------
const CUENTACUENTOS_SALUDO: String = "Soy el CUENTACUENTOS.\\lTe contaré historias de ENTRENADORES\\wlegendarios.\\p¿Quieres escuchar mi historia?"
const CUENTACUENTOS_SIN_LEYENDAS: String = "Pero no conozco a ningún ENTRENADOR\\llegendario. Así que no sé historias.\\p¿Dónde encontraré a un ENTRENADOR\\ldigno de una leyenda?"
const CUENTACUENTOS_TIENES_HISTORIAS: String = "¿Eres ENTRENADOR?\\p¿Y tienes alguna historia que sea\\lmínimamente legendaria?"
const CUENTACUENTOS_NO_SATISFECHO: String = "Mmm...\\lNo me convence...\\pOjalá me trajeras noticias dignas\\lde llamarse leyenda."
const CUENTACUENTOS_AGOBIADO: String = "Oh...\\lMe siento agobiado..."

## ---------------------------------------------------------------------------
## RISUEÑO / GIDDY (data/text/giddy.inc)
## ---------------------------------------------------------------------------
const RISUENO_SALUDO: String = "¡Soy el RISUEÑO!\\l¡Tengo una historia fascinante!\\p¿Quieres escucharla?"
const RISUENO_DESINFLADO: String = "Oh...\\lMe has desinflado..."
const RISUENO_ADIOS: String = "Creo que eso es todo...\\p¡Tenemos que volver a charlar!\\l¡Adiós!"

## Emitida por el callback del cuadro de diálogo al avanzar/cerrar un mensaje.
signal _mensaje_terminado

## Sustituye la pantalla de PALABRAS FÁCILES (tests): recibe la letra actual y
## devuelve la nueva, o [] si se cancela o no cambia.
var editor_letra: Callable = Callable()

var _secuencia_activa: bool = false
var _variante: Variante = Variante.BARDO
## Tono generado una vez para toda la escena (ver _crear_tono_canto()).
var _tono_canto: AudioStreamWAV = null

func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	_variante = _determinar_variante()
	if _variante < sprites_variantes.size() and sprites_variantes[_variante] != null:
		selec_frames = sprites_variantes[_variante]

## SetupMauvilleOldMan: (id visible de 16 bits % 10) / 2.
func _determinar_variante() -> Variante:
	if variante_forzada >= 0:
		return variante_forzada as Variante
	var id_jugador: int = 0
	if SistemaGuardado and SistemaGuardado.datos_vivos and SistemaGuardado.datos_vivos.jugador:
		id_jugador = int(SistemaGuardado.datos_vivos.jugador.get("id", 0)) & 0xFFFF
	@warning_ignore("integer_division")
	return ((id_jugador % 10) / 2) as Variante

## ============================================================================
## INTERACCIÓN
## ============================================================================

## Punto de entrada tras evento_accion() (inmediato o al terminar un paso).
func _procesar_interaccion() -> void:
	interrupcion_pendiente = false
	if _secuencia_activa:
		return

	if nodo_administrador == null or nodo_administrador.cuadro_dialogo == null:
		_loggear("AdministradorMapa o cuadro de diálogo no disponible")
		if jugador and jugador.has_method("esperar_dialogo"):
			jugador.esperar_dialogo(false)
		cambiar_estado(EstadoNPC.IDLE)
		return

	_ejecutar_secuencia()

func _ejecutar_secuencia() -> void:
	_secuencia_activa = true
	cambiar_estado(EstadoNPC.INTERACTING)
	if tipo_movimiento != TipoMovimientoNPC.SIN_MOVIMIENTO:
		mirar_jugador()
	_bloquear_jugador(true)

	match _variante:
		Variante.BARDO:
			await _hablar_bardo()
		Variante.MODERNO:
			await _hablar_moderno()
		Variante.CAMBIADOR:
			await _hablar_cambiador()
		Variante.CUENTACUENTOS:
			await _hablar_cuentacuentos()
		Variante.RISUENO:
			await _hablar_risueno()

	_finalizar()

func _finalizar() -> void:
	_bloquear_jugador(false)
	_volver_a_direccion_base()
	_secuencia_activa = false
	cambiar_estado(EstadoNPC.IDLE)

## Bloqueo equivalente al de la enfermera: pausa global + estado TALKING.
func _bloquear_jugador(activo: bool) -> void:
	Singleton.mantener_pausa(MOTIVO_PAUSA, activo)
	if jugador == null:
		return
	if activo:
		jugador.start_dialog()
	else:
		jugador.end_dialog()
	jugador.no_control = activo

## ============================================================================
## VARIANTES
## ============================================================================

## SpeakToBard.
func _hablar_bardo() -> void:
	if not await _preguntar_si_no(BARDO_SALUDO):
		await _mostrar_mensaje(BARDO_TRISTE, true)
		return

	await _cantar(letra_bardo())
	await get_tree().create_timer(CANTO_ESPERA_FINAL).timeout

	# ScrSpecial_HasBardSongBeenChanged: con la letra ya cambiada no pide otra.
	if cancion_bardo_cambiada():
		await _mostrar_mensaje(BARDO_EMOTIVA, true)
		return
	if not await _preguntar_si_no(BARDO_QUE_TE_PARECE):
		await _mostrar_mensaje(BARDO_TRISTE, true)  # dont_write_lyrics
		return

	# write_lyrics: cada vuelta parte de la letra guardada (sub_80E60D8 copia
	# songLyrics en temporaryLyrics) hasta que el jugador acepta la nueva.
	while true:
		var nueva: Array[int] = await _escribir_letra()
		if nueva.is_empty():
			await _mostrar_mensaje(BARDO_TRISTE, true)
			return
		await _mostrar_mensaje(BARDO_GRACIAS, true)
		await _cantar(nueva)
		await get_tree().create_timer(CANTO_ESPERA_FINAL).timeout
		if await _preguntar_si_no(BARDO_ASI_QUERIAS):
			guardar_letra_bardo(nueva)  # ScrSpecial_SaveBardSongLyrics
			await _mostrar_mensaje(BARDO_YA_ESTA, true)
			return

## MauvilleCity_PokemonCenter_1F_EventScript_1A00F3 con VAR_SPECIAL_4 = 6:
## PALABRAS FÁCILES en modo BARDO entre fundidos. Devuelve la letra nueva, o []
## si se cancela o se acepta sin cambios (gSpecialVar_Result = 0).
func _escribir_letra() -> Array[int]:
	var actual: Array[int] = letra_bardo()
	var nueva: Array[int] = []
	if editor_letra.is_valid():
		nueva.assign(editor_letra.call(actual))
	else:
		var capa: Node = get_tree().root.get_node_or_null("AdministradorMapa/Menu")
		if capa == null:
			return nueva
		nodo_administrador.cuadro_dialogo.cerrar()
		await Singleton.transicion("oscurecer")
		var pantalla := (load(ESCENA_PALABRAS_FACILES) as PackedScene).instantiate() as PantallaPalabrasFaciles
		pantalla.z_index = 6
		capa.add_child(pantalla)
		pantalla.abrir(PantallaPalabrasFaciles.Modo.BARDO, actual)
		var resultado: Array = await pantalla.terminada
		pantalla.queue_free()
		if bool(resultado[0]):
			nueva.assign(resultado[1])
		await Singleton.transicion("aclarar")
	if PantallaPalabrasFaciles.contar_cambios(actual, nueva) == 0:
		nueva.clear()
	return nueva

## Letra que canta el BARDO: la guardada o, si no hay, la de por defecto.
static func letra_bardo() -> Array[int]:
	var letra: Array[int] = BARDO_LETRA_DEFECTO.duplicate()
	var guardada: PackedStringArray = SistemaGuardado.get_texto(CLAVE_LETRA_BARDO).split(",", false)
	if guardada.size() == letra.size():
		for i in letra.size():
			letra[i] = int(guardada[i])
	return letra

static func cancion_bardo_cambiada() -> bool:
	return SistemaGuardado.get_flag(BANDERA_CANCION_CAMBIADA)

## ScrSpecial_SaveBardSongLyrics: guarda la letra y marca hasChangedSong.
static func guardar_letra_bardo(letra: Array[int]) -> void:
	var textos: PackedStringArray = []
	for id_palabra: int in letra:
		textos.append(str(id_palabra))
	SistemaGuardado.set_texto(CLAVE_LETRA_BARDO, ",".join(textos))
	SistemaGuardado.set_flag(BANDERA_CANCION_CAMBIADA, true)

## SpeakToHipster sin palabras de Charla Fácil por enseñar.
func _hablar_moderno() -> void:
	await _mostrar_mensaje(MODERNO_SALUDO, false)
	await _mostrar_mensaje(MODERNO_YA_SABES, true)

## SpeakToTrader: sin decoraciones, SÍ equivale a cancelar su menú.
func _hablar_cambiador() -> void:
	if await _preguntar_si_no(CAMBIADOR_SALUDO):
		await _mostrar_mensaje(CAMBIADOR_NADA, true)  # cancelled_get_menu
	else:
		await _mostrar_mensaje(CAMBIADOR_RECHAZADO, true)

## SpeakToStoryteller sin historias grabadas ni estadísticas de partida
## (ScrSpecial_StorytellerInitializeRandomStat falla → ImNotSatisfied).
func _hablar_cuentacuentos() -> void:
	if not await _preguntar_si_no(CUENTACUENTOS_SALUDO):
		await _mostrar_mensaje(CUENTACUENTOS_AGOBIADO, true)
		return
	await _mostrar_mensaje(CUENTACUENTOS_SIN_LEYENDAS, false)
	if not await _preguntar_si_no(CUENTACUENTOS_TIENES_HISTORIAS):
		await _mostrar_mensaje(CUENTACUENTOS_AGOBIADO, true)
		return
	await _mostrar_mensaje(CUENTACUENTOS_NO_SATISFECHO, true)

## SpeakToGiddy: sin palabras de Charla Fácil no genera frases (bye_bye).
func _hablar_risueno() -> void:
	if await _preguntar_si_no(RISUENO_SALUDO):
		await _mostrar_mensaje(RISUENO_ADIOS, true)
	else:
		await _mostrar_mensaje(RISUENO_DESINFLADO, true)

## ============================================================================
## CANCIÓN DEL BARDO (Task_BardSong)
## ============================================================================

## Funde la música del mapa, escribe la letra palabra a palabra con un tono por
## letra y la vuelve a subir (FadeOutBGMTemporarily / FadeInNewBGM).
func _cantar(letra_ids: Array[int]) -> void:
	var letra: Array[String] = []
	for id_palabra: int in letra_ids:
		letra.append(PalabrasFaciles.texto(id_palabra))
	var dialogo: NinePatchRect = nodo_administrador.cuadro_dialogo
	var reproductor: AudioStreamPlayer = Singleton.obtener_nodo("ReproductorMusica") as AudioStreamPlayer
	var volumen_previo_db: float = 0.0
	var procesaba: bool = false
	if reproductor:
		volumen_previo_db = reproductor.volume_db
		# Su _process relanza el tema si no está "playing" (ver Fanfarria).
		procesaba = reproductor.is_processing()
		reproductor.set_process(false)
		if reproductor.playing:
			await Fanfarria.fundir_volumen_musica(reproductor, volumen_previo_db, -80.0, CANTO_FUNDIDO_MUSICA)
		reproductor.stream_paused = true

	var voz: AudioStreamPlayer = AudioStreamPlayer.new()
	voz.stream = _crear_tono_canto()
	voz.volume_db = -10.0
	if reproductor:
		voz.bus = reproductor.bus
	add_child(voz)

	# PrepareSongText: por página "P1 P2" / "P3".
	for pagina in range(2):
		var palabras: Array[String] = letra.slice(pagina * 3, pagina * 3 + 3)
		var texto: String = "%s %s\n%s" % palabras
		dialogo.mostrar_inmediatamente(texto)
		dialogo.label.visible_characters = 0
		for i in range(palabras.size()):
			var altura: float = CANTO_ALTURAS[(pagina * 3 + i) % CANTO_ALTURAS.size()]
			for j in range(palabras[i].length()):
				dialogo.label.visible_characters += 1
				voz.pitch_scale = altura * (1.03 if j % 2 == 0 else 0.97)
				voz.play()
				await get_tree().create_timer(CANTO_POR_LETRA).timeout
			dialogo.label.visible_characters += 1  # espacio o salto de línea
			await get_tree().create_timer(CANTO_ENTRE_PALABRAS).timeout
		if pagina == 0:
			await get_tree().create_timer(CANTO_CAMBIO_PAGINA).timeout

	voz.queue_free()
	if is_instance_valid(reproductor):
		reproductor.stream_paused = false
		reproductor.set_process(procesaba)
		Fanfarria.fundir_volumen_musica(reproductor, -80.0, volumen_previo_db, CANTO_FUNDIDO_MUSICA)

## Onda cuadrada corta con caída lineal (16 bits, mono).
func _crear_tono_canto() -> AudioStreamWAV:
	if _tono_canto:
		return _tono_canto
	const FRECUENCIA_MUESTREO: int = 22050
	const FRECUENCIA_NOTA: float = 330.0
	const DURACION: float = 0.09
	var muestras: int = int(FRECUENCIA_MUESTREO * DURACION)
	var datos: PackedByteArray = PackedByteArray()
	datos.resize(muestras * 2)
	for i in range(muestras):
		var fase: float = fmod(i * FRECUENCIA_NOTA / FRECUENCIA_MUESTREO, 1.0)
		var envolvente: float = 1.0 - float(i) / muestras
		var valor: int = int((1.0 if fase < 0.5 else -1.0) * envolvente * 12000.0)
		datos.encode_s16(i * 2, valor)
	_tono_canto = AudioStreamWAV.new()
	_tono_canto.format = AudioStreamWAV.FORMAT_16_BITS
	_tono_canto.mix_rate = FRECUENCIA_MUESTREO
	_tono_canto.stereo = false
	_tono_canto.data = datos
	return _tono_canto

## ============================================================================
## DIÁLOGOS
## ============================================================================

## Muestra un mensaje y espera a que el jugador lo avance.
## cerrar = false deja el cuadro abierto (ESPERANDO_CIERRE_EXTERNO).
func _mostrar_mensaje(texto: String, cerrar: bool) -> void:
	nodo_administrador.cuadro_dialogo.mostrar(tr(texto), true, cerrar, _mensaje_terminado.emit)
	await _mensaje_terminado

## Muestra la pregunta con menú SÍ/NO y devuelve true si se eligió SÍ.
## Cancelar en el menú equivale a NO.
func _preguntar_si_no(texto: String) -> bool:
	var dialogo: NinePatchRect = nodo_administrador.cuadro_dialogo
	# preguntaSiNo() exige el cuadro en IDLE o ESPERANDO_REINGRESO.
	dialogo.cerrar()
	dialogo.preguntaSiNo(tr(texto))
	var respuesta: String = ""
	while respuesta.is_empty():
		var datos: Array = await dialogo.comando_ejecutado
		if datos.size() >= 2 and str(datos[0]) == "respuesta_confirmacion":
			var parametros: Array = datos[1]
			respuesta = str(parametros[0]) if not parametros.is_empty() else "N"
	return respuesta == "Y"
