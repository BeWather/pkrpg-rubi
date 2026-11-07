class_name Fanfarria
extends RefCounted

## Fanfarrias (jingles "ME" de Gen 3: objeto obtenido, baya obtenida...) que
## interrumpen la música del mapa. Equivale a playfanfare + waitfanfare de los
## scripts de pokeruby. La usan NpcBase (objetos entregados) y ControladorBaya
## (MUS_OBTAIN_BERRY al cosechar).

## Suavizado de la música del mapa alrededor de la fanfarria.
const DURACION_BAJADA_MUSICA: float = 0.3
const DURACION_SUBIDA_MUSICA: float = 0.5

## "¡Obtuvo X!" de un objeto (pokeruby MUS_FANFA4) y de una MT/MO (MUS_ME_WAZA).
const TEMA_OBJETO: String = "OBTENIDO_OBJETO"
const TEMA_MT_MO: String = "OBTENIDA_UNA_MT"


## Fanfarria de objeto obtenido según el bolsillo (0-based, `bolsillo_id` de
## SistemaGuardado.obtener_datos_objeto_completos), como GetItem_HandlePocket de
## pokeruby (Std_ObtainItem, Std_FindItem y objetos ocultos): MT/MO → TEMA_MT_MO.
static func tema_objeto_obtenido(bolsillo_id: int) -> String:
	return TEMA_MT_MO if bolsillo_id == ObjetosLlevados.BOLSILLO_MT_MO else TEMA_OBJETO


## Baja la música del mapa en DURACION_BAJADA_MUSICA, la pausa, toca `tema`
## (clave de Singleton.TEMAS_REGISTRADOS) una vez al volumen que tenía y la
## reanuda subiendo en DURACION_SUBIDA_MUSICA. El reproductor temporal cuelga
## del de música (de `anfitrion` si no lo hay): la pantalla que la pide puede
## cerrarse antes de que acabe y, sin `finished`, la música no volvería.
## Fanfarrias solapadas (mensaje saltado) comparten la pausa: restaura la última.
## Vuelve al terminar el tema (waitfanfare); la subida sigue en segundo plano
## salvo con esperar_subida. Devuelve false si el tema no pudo cargarse. El nivel
## de audio de las opciones se respeta: lo aplica el Singleton en el bus Master y
## el reproductor ya lo incluye en su volume_db, que se restaura tal cual.
static func reproducir(anfitrion: Node, tema: String, esperar_subida: bool = false) -> bool:
	var stream: AudioStream = cargar_stream_tema(tema)
	if stream == null or anfitrion == null or not anfitrion.is_inside_tree():
		return false

	var reproductor: NuevoAudioStreamPlayer = Singleton.obtener_nodo("ReproductorMusica") as NuevoAudioStreamPlayer
	var fanfarria: AudioStreamPlayer = AudioStreamPlayer.new()
	fanfarria.stream = stream
	if reproductor:
		while is_instance_valid(reproductor) and reproductor.fanfarria_subiendo:
			await reproductor.get_tree().process_frame
		if not is_instance_valid(reproductor):
			fanfarria.free()
			return false
		if reproductor.fanfarrias_activas == 0:
			reproductor.fanfarria_volumen_previo_db = reproductor.volume_db
			# Su _process relanza el tema cuando no está "playing" (y en pausa no lo está).
			reproductor.fanfarria_procesaba = reproductor.is_processing()
		reproductor.fanfarrias_activas += 1
		reproductor.set_process(false)
		if reproductor.fanfarrias_activas == 1 and reproductor.playing:
			await fundir_volumen_musica(reproductor, reproductor.fanfarria_volumen_previo_db, -80.0, DURACION_BAJADA_MUSICA)
		reproductor.stream_paused = true
		fanfarria.bus = reproductor.bus
		fanfarria.volume_db = reproductor.fanfarria_volumen_previo_db
		reproductor.add_child(fanfarria)
	else:
		anfitrion.add_child(fanfarria)
	fanfarria.play()
	await fanfarria.finished
	fanfarria.queue_free()

	if is_instance_valid(reproductor):
		reproductor.fanfarrias_activas -= 1
		if reproductor.fanfarrias_activas > 0:
			return true
		reproductor.stream_paused = false
		reproductor.set_process(reproductor.fanfarria_procesaba)
		reproductor.fanfarria_subiendo = true
		if esperar_subida:
			await _subir_musica(reproductor)
		else:
			_subir_musica(reproductor)
	return true


static func _subir_musica(reproductor: NuevoAudioStreamPlayer) -> void:
	await fundir_volumen_musica(reproductor, -80.0, reproductor.fanfarria_volumen_previo_db, DURACION_SUBIDA_MUSICA)
	if is_instance_valid(reproductor):
		reproductor.fanfarria_subiendo = false


## Variante con sesión cancelable; las llamadas anteriores conservan su contrato.
## No reanuda un tema reemplazado por otro mapa ni deja música pausada al salir.
static func reproducir_cancelable(anfitrion: Node, tema: String, vigente: Callable) -> bool:
	var stream: AudioStream = cargar_stream_tema(tema)
	if stream == null or not vigente.is_valid() or not vigente.call(): return false
	var tree: SceneTree = anfitrion.get_tree()
	var musica: NuevoAudioStreamPlayer = Singleton.obtener_nodo("ReproductorMusica") as NuevoAudioStreamPlayer
	var tema_previo: AudioStream = musica.stream if musica != null else null
	var procesaba: bool = musica.is_processing() if musica != null else false
	var volumen: float = musica.volume_db if musica != null else 0.0
	var pausada: bool = musica.stream_paused if musica != null else false
	if musica != null:
		musica.set_process(false)
		var inicio: int = Time.get_ticks_msec()
		while is_instance_valid(musica) and musica.playing and musica.stream == tema_previo \
			and vigente.is_valid() and vigente.call() and Time.get_ticks_msec() - inicio < DURACION_BAJADA_MUSICA * 1000:
			var peso: float = float(Time.get_ticks_msec() - inicio) / (DURACION_BAJADA_MUSICA * 1000)
			musica.volume_db = linear_to_db(lerpf(db_to_linear(volumen), db_to_linear(-80.0), peso))
			await tree.process_frame
	var fanfarria: AudioStreamPlayer
	if vigente.is_valid() and vigente.call() and (musica == null or (is_instance_valid(musica) and musica.stream == tema_previo)):
		fanfarria = AudioStreamPlayer.new()
		fanfarria.stream = stream
		if is_instance_valid(musica):
			musica.stream_paused = true
			fanfarria.bus = musica.bus
			fanfarria.volume_db = volumen
		anfitrion.add_child(fanfarria)
		fanfarria.play()
		while is_instance_valid(fanfarria) and fanfarria.playing and vigente.is_valid() and vigente.call() \
			and (musica == null or (is_instance_valid(musica) and musica.stream == tema_previo)):
			await tree.process_frame
	var termino: bool = vigente.is_valid() and vigente.call()
	if is_instance_valid(fanfarria):
		fanfarria.stop()
		fanfarria.queue_free()
	if is_instance_valid(musica) and musica.stream == tema_previo:
		musica.set_process(procesaba)
		musica.stream_paused = pausada
		musica.volume_db = volumen
	return termino


## Interpola en escala lineal (no en dB) para que el fundido se perciba parejo.
## El tween vive en el reproductor para que no quede la música baja si el
## anfitrión se libera.
static func fundir_volumen_musica(reproductor: AudioStreamPlayer, desde_db: float, hasta_db: float, duracion: float) -> void:
	var tween: Tween = reproductor.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_method(
		func(lineal: float) -> void: reproductor.volume_db = linear_to_db(lineal),
		db_to_linear(desde_db), db_to_linear(hasta_db), duracion)
	await tween.finished
	if is_instance_valid(reproductor):
		reproductor.volume_db = hasta_db


## Misma resolución de ruta que NuevoAudioStreamPlayer._cargar_stream_tema().
static func cargar_stream_tema(tema: String) -> AudioStream:
	if tema.is_empty():
		return null
	if not Singleton.TEMAS_REGISTRADOS.has(tema):
		print("🎺 [FANFARRIA] Tema %s no registrado" % tema)
		return null
	var config: Dictionary = Singleton.TEMAS_REGISTRADOS[tema]
	var ruta: String = str(config.get("ruta", "res://Audio/emerald/" + str(config.get("archivo", ""))))
	return load(ruta) as AudioStream
