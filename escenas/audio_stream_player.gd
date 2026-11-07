extends AudioStreamPlayer
class_name NuevoAudioStreamPlayer

# ===============================================
# AUDIO STREAM PLAYER MEJORADO
# ===============================================
# Mantiene compatibilidad total con el sistema legacy
# Agrega funcionalidades avanzadas de transiciones y gestión
# ===============================================

signal musica_cambiada(tema_anterior: String, tema_nuevo: String)
signal transicion_iniciada(tipo: String)
signal transicion_completada()

# ===============================================
# DATOS Y CONFIGURACIÓN
# ===============================================

var tiene_bucle: bool = false
var bucle_inicio: float = 0.0
var bucle_fin: float = 0.0

# ===============================================
# NUEVAS FUNCIONALIDADES
# ===============================================

# Variables del sistema avanzado
var tema_actual: String = ""
var en_transicion: bool = false
var volumen_base: float = 1.0
var tween: Tween = null
## Estado de Fanfarria.reproducir: jingles en curso, lo que restaurar al acabar el
## último y si la música aún está subiendo tras él.
var fanfarrias_activas: int = 0
var fanfarria_volumen_previo_db: float = 0.0
var fanfarria_procesaba: bool = false
var fanfarria_subiendo: bool = false
## Identifica la transición vigente: una transición interrumpida ve que su id ya
## no coincide al reanudarse tras un await y se abandona sin tocar el reproductor.
var _id_transicion: int = 0
var temas_precargados: Dictionary = {}
var contextos_precarga: Dictionary = {}
var propietarios_temas_precargados: Dictionary = {}

# ===============================================
# INICIALIZACIÓN
# ===============================================

func _ready():
	print("[AudioStreamPlayerMejorado] Iniciado con compatibilidad legacy")

	conectar_con_singleton()

func _exit_tree() -> void:
	if tween != null:
		tween.kill()
		tween = null
	stop()
	stream = null
	temas_precargados.clear()
	contextos_precarga.clear()
	propietarios_temas_precargados.clear()

# ===============================================
# COMPATIBILIDAD LEGACY - MANTENER FUNCIONES ORIGINALES
# ===============================================

## Función original - MANTENER EXACTAMENTE IGUAL
func reproducir(musica: AudioStream, ini: float = 0.0, fin: float = 0.0) -> void:
	stream = musica
	bucle_inicio = ini
	bucle_fin = fin
	if ini > 0.0 and fin > 0.0:
		tiene_bucle = true
	else:
		# Si ambos puntos de bucle son 0, la música se reproduce desde el inicio cuando termine
		tiene_bucle = (ini == 0.0 and fin == 0.0)
	# Un OGG con loop/loop_offset en su .import se repite solo y sin saltos de
	# fotograma (Audio/music_gba): el bucle manual de _process queda para los MP3.
	if musica is AudioStreamOggVorbis and musica.loop:
		tiene_bucle = false

	# Aplicar volumen de opciones del juego
	_aplicar_volumen_opciones_juego()

	play()
	set_process(true)

## Proceso original - MANTENER EXACTAMENTE IGUAL
func _process(_delta: float) -> void:
	if tiene_bucle:
		if bucle_inicio > 0.0 and bucle_fin > 0.0:
			# Bucle tradicional entre puntos específicos
			if not playing and not stream_paused and not en_transicion and stream != null and tema_actual != "":
				# El tema llegó a su final sin pasar por bucle_fin (frame perdido o
				# bucle_fin mayor que la duración): vuelve al inicio del bucle.
				play(bucle_inicio)
			elif get_playback_position() >= bucle_fin:
				seek(bucle_inicio)
		elif bucle_inicio == 0.0 and bucle_fin == 0.0:
			# Bucle desde el inicio cuando termine la canción
			if not playing:
				play()

## Aplica el volumen según las opciones del juego
func _aplicar_volumen_opciones_juego() -> void:
	# El volumen se maneja globalmente por el Singleton a nivel de AudioServer
	# Esta función queda lista para futuras implementaciones específicas por tema
	pass

# ===============================================
# NUEVAS FUNCIONALIDADES AVANZADAS
# ===============================================

## Reproduce un tema por nombre con transiciones.
## tipo_transicion: 0 = inmediato, 1 = fundido corto, 2 = fundido medio, 3 = fundido largo, 4 = silencio.
## interrumpir: corta la transición en curso (p. ej. el fundido del tema del mapa) y
## aplica este tema; sin él, la petición hecha durante una transición se descarta.
func reproducir_tema(nombre_tema: String, tipo_transicion: int = 1, forzar: bool = false, interrumpir: bool = false) -> void:
	if interrumpir and en_transicion:
		_cancelar_transicion()

	if nombre_tema == tema_actual and not forzar:
		print("[AudioStreamPlayerMejorado] Ya reproduciendo: ", nombre_tema)
		return

	if not Singleton.TEMAS_REGISTRADOS.has(nombre_tema):
		print("[AudioStreamPlayerMejorado] ADVERTENCIA: Tema no encontrado, usando legacy: ", nombre_tema)
		return

	var tema_anterior = tema_actual
	_ejecutar_transicion_avanzada(tema_anterior, nombre_tema, tipo_transicion)

func actualizar_precarga_contexto(contexto: String, temas: Array[String]) -> void:
	var contexto_limpio := contexto.strip_edges()
	if contexto_limpio.is_empty():
		return

	var temas_normalizados := _normalizar_temas_precarga(temas)
	var temas_previos := _obtener_temas_precargados_contexto(contexto_limpio)

	for tema_previo in temas_previos:
		if not temas_normalizados.has(tema_previo):
			_desregistrar_contexto_tema_precargado(contexto_limpio, tema_previo)

	for tema_nuevo in temas_normalizados:
		if not temas_previos.has(tema_nuevo):
			_registrar_contexto_tema_precargado(contexto_limpio, tema_nuevo)

	if temas_normalizados.is_empty():
		contextos_precarga.erase(contexto_limpio)
	else:
		contextos_precarga[contexto_limpio] = temas_normalizados

func liberar_precarga_contexto(contexto: String) -> void:
	var contexto_limpio := contexto.strip_edges()
	if contexto_limpio.is_empty():
		return

	var temas_previos := _obtener_temas_precargados_contexto(contexto_limpio)
	for tema_previo in temas_previos:
		_desregistrar_contexto_tema_precargado(contexto_limpio, tema_previo)

	contextos_precarga.erase(contexto_limpio)

func detener_reproduccion_actual() -> void:
	_cancelar_transicion()
	stop()
	tiene_bucle = false
	tema_actual = ""

## Funde a silencio y detiene el tema, sin relanzarlo (FadeOutMapMusic): la música no
## vuelve hasta que otro tema la pida. Deja el volumen listo para lo que suene después.
func desvanecer_y_detener(duracion: float) -> void:
	var config: Dictionary = Singleton.TEMAS_REGISTRADOS.get(tema_actual, {"volumen": 1.0})
	_cancelar_transicion()
	if playing and duracion > 0.0:
		var id := _id_transicion
		en_transicion = true
		tween = create_tween()
		tween.tween_property(self, "volume_db", -80.0, duracion)
		await tween.finished
		if id != _id_transicion:
			return
	detener_reproduccion_actual()
	_aplicar_volumen_tema(config.volumen)

## Aborta la transición en curso: el tween se mata y la corrutina que esperaba su
## fin queda invalidada por el cambio de id, así que no llega a cargar su tema.
func _cancelar_transicion() -> void:
	_id_transicion += 1
	if tween != null:
		tween.kill()
		tween = null
	en_transicion = false

func obtener_tema_actual() -> String:
	return tema_actual

## Sistema de transiciones avanzado
func _ejecutar_transicion_avanzada(tema_anterior: String, tema_nuevo: String, tipo: int) -> void:
	if en_transicion:
		print("[AudioStreamPlayerMejorado] Transición en curso, ignorando solicitud")
		return

	_id_transicion += 1
	var id := _id_transicion
	en_transicion = true
	transicion_iniciada.emit(_tipo_transicion_a_string(tipo))

	match tipo:
		0: # INMEDIATA
			_cambiar_tema_inmediato(tema_nuevo)
		1: # FUNDIDO_CORTO
			await _cambiar_tema_con_fundido(tema_nuevo, 0.5, id)
		2: # FUNDIDO_MEDIO
			await _cambiar_tema_con_fundido(tema_nuevo, 1.0, id)
		3: # FUNDIDO_LARGO
			await _cambiar_tema_con_fundido(tema_nuevo, 2.0, id)
		4: # SILENCIO
			await _cambiar_tema_con_silencio(tema_nuevo, id)
		_:
			await _cambiar_tema_con_fundido(tema_nuevo, 0.5, id)

	if id != _id_transicion:
		return # interrumpida: otra petición controla ya el reproductor
	_finalizar_transicion(tema_anterior, tema_nuevo)

func _cambiar_tema_inmediato(tema_nuevo: String) -> void:
	_cargar_y_reproducir_tema_avanzado(tema_nuevo)

func _cambiar_tema_con_fundido(tema_nuevo: String, duracion: float, id: int) -> void:
	# Fundido de salida
	if playing and tema_actual != "":
		tween = create_tween()
		tween.tween_property(self, "volume_db", -80.0, duracion * 0.5)
		await tween.finished
		if id != _id_transicion:
			return

	# Cambiar tema
	_cargar_y_reproducir_tema_avanzado(tema_nuevo)

	# Fundido de entrada
	if playing:
		volume_db = -80.0
		var volumen_objetivo = _calcular_volumen_db(tema_nuevo)
		tween = create_tween()
		tween.tween_property(self, "volume_db", volumen_objetivo, duracion * 0.5)
		await tween.finished

func _cambiar_tema_con_silencio(tema_nuevo: String, id: int) -> void:
	# Parar música actual
	if playing:
		tween = create_tween()
		tween.tween_property(self, "volume_db", -80.0, 0.5)
		await tween.finished
		if id != _id_transicion:
			return
		stop()

	# Esperar momento de silencio
	await get_tree().create_timer(0.5).timeout
	if id != _id_transicion:
		return

	# Iniciar nuevo tema
	_cargar_y_reproducir_tema_avanzado(tema_nuevo)

func _finalizar_transicion(tema_anterior: String, tema_nuevo: String) -> void:
	en_transicion = false
	musica_cambiada.emit(tema_anterior, tema_nuevo)
	transicion_completada.emit()
	print("[AudioStreamPlayerMejorado] Transición completada: ", tema_anterior, " -> ", tema_nuevo)

func _obtener_temas_precargados_contexto(contexto: String) -> Array[String]:
	var temas: Array[String] = []
	var temas_raw: Variant = contextos_precarga.get(contexto, [])
	if temas_raw is Array:
		for tema in temas_raw:
			if tema is String:
				temas.append(str(tema))
	return temas

func _normalizar_temas_precarga(temas: Array[String]) -> Array[String]:
	var temas_normalizados: Array[String] = []
	for tema in temas:
		var tema_limpio := tema.strip_edges()
		if tema_limpio.is_empty():
			continue
		if not Singleton.TEMAS_REGISTRADOS.has(tema_limpio):
			print("[AudioStreamPlayerMejorado] ADVERTENCIA: No se pudo precargar tema no registrado: ", tema_limpio)
			continue
		if not temas_normalizados.has(tema_limpio):
			temas_normalizados.append(tema_limpio)
	return temas_normalizados

func _registrar_contexto_tema_precargado(contexto: String, nombre_tema: String) -> void:
	var stream_audio := _precargar_stream_tema(nombre_tema)
	if stream_audio == null:
		return

	var contextos_tema: Dictionary = propietarios_temas_precargados.get(nombre_tema, {})
	contextos_tema[contexto] = true
	propietarios_temas_precargados[nombre_tema] = contextos_tema

func _desregistrar_contexto_tema_precargado(contexto: String, nombre_tema: String) -> void:
	if not propietarios_temas_precargados.has(nombre_tema):
		return

	var contextos_tema: Dictionary = propietarios_temas_precargados.get(nombre_tema, {})
	contextos_tema.erase(contexto)
	if contextos_tema.is_empty():
		propietarios_temas_precargados.erase(nombre_tema)
		temas_precargados.erase(nombre_tema)
	else:
		propietarios_temas_precargados[nombre_tema] = contextos_tema

func _precargar_stream_tema(nombre_tema: String) -> AudioStream:
	if temas_precargados.has(nombre_tema):
		return temas_precargados.get(nombre_tema, null) as AudioStream

	var stream_audio := _cargar_stream_tema(nombre_tema)
	if stream_audio != null:
		temas_precargados[nombre_tema] = stream_audio
		print("[AudioStreamPlayerMejorado] Tema precargado: ", nombre_tema)
	return stream_audio

func _obtener_stream_tema(nombre_tema: String) -> AudioStream:
	var stream_precargado: Variant = temas_precargados.get(nombre_tema, null)
	if stream_precargado is AudioStream:
		return stream_precargado as AudioStream
	return _cargar_stream_tema(nombre_tema)

func _cargar_stream_tema(nombre_tema: String) -> AudioStream:
	if not Singleton.TEMAS_REGISTRADOS.has(nombre_tema):
		return null

	var config: Dictionary = Singleton.TEMAS_REGISTRADOS[nombre_tema]
	var ruta_completa: String = str(config.get("ruta", "res://Audio/emerald/" + config.get("archivo", "")))
	var stream_audio := load(ruta_completa) as AudioStream
	if stream_audio == null:
		print("[AudioStreamPlayerMejorado] ERROR: No se pudo cargar: ", ruta_completa)
	return stream_audio

## Carga y reproduce tema con configuración avanzada
func _cargar_y_reproducir_tema_avanzado(nombre_tema: String) -> void:
	if not Singleton.TEMAS_REGISTRADOS.has(nombre_tema):
		return

	var config = Singleton.TEMAS_REGISTRADOS[nombre_tema]
	var stream_audio := _obtener_stream_tema(nombre_tema)
	if stream_audio == null:
		return

	# Configurar usando la función legacy (mantiene compatibilidad)
	reproducir(stream_audio, config.bucle_inicio, config.bucle_fin)

	# Aplicar volumen del tema
	_aplicar_volumen_tema(config.volumen)

	# Actualizar estado
	tema_actual = nombre_tema
	print("[AudioStreamPlayerMejorado] Tema cargado: ", nombre_tema, " (", config.archivo, ")")

## Control de volumen avanzado
func establecer_volumen_base(volumen: float) -> void:
	volumen_base = clampf(volumen, 0.0, 1.0)
	if tema_actual != "":
		var config = Singleton.TEMAS_REGISTRADOS.get(tema_actual, {"volumen": 1.0})
		_aplicar_volumen_tema(config.volumen)

func _aplicar_volumen_tema(volumen_tema: float) -> void:
	# Obtener el volumen de las opciones del juego
	var volumen_opciones = _obtener_volumen_opciones_juego()

	# Combinar volumen base, del tema y de las opciones
	var volumen_final = volumen_base * volumen_tema * volumen_opciones
	volume_db = _calcular_volumen_db_desde_linear(volumen_final)

## Obtiene el volumen configurado en las opciones del juego
func _obtener_volumen_opciones_juego() -> float:
	# Verificar si existe SistemaGuardado y tiene opciones de audio
	var sg = get_tree().root.get_node_or_null("SistemaGuardado")
	if sg and sg.datos_vivos and sg.datos_vivos.opciones:
		var nivel_audio = int(sg.datos_vivos.opciones.nivel_audio)
		match nivel_audio:
			Singleton.NivelAudio.NO:      # 0 - Silenciado
				return 0.0
			Singleton.NivelAudio.BAJO:    # 1 - Volumen bajo
				return 0.4
			Singleton.NivelAudio.NORMAL:  # 2 - Volumen normal
				return 1.0
			_:
				return 1.0
	else:
		# Si no hay opciones guardadas, usar volumen normal
		return 1.0

func _calcular_volumen_db(nombre_tema: String) -> float:
	var config = Singleton.TEMAS_REGISTRADOS.get(nombre_tema, {"volumen": 1.0})
	var volumen_final = volumen_base * config.volumen
	return _calcular_volumen_db_desde_linear(volumen_final)

func _calcular_volumen_db_desde_linear(volumen_linear: float) -> float:
	if volumen_linear <= 0.0:
		return -80.0
	return 20.0 * log(volumen_linear) / log(10.0)

# ===============================================
# INTEGRACIÓN CON SINGLETON (MANTENER COMPATIBILIDAD)
# ===============================================

## Función para conectar con las señales del Singleton
func conectar_con_singleton() -> void:
	if Singleton.has_signal("play_musica_fondo"):
		Singleton.connect("play_musica_fondo", Callable(self, "_on_play_musica_fondo_legacy"))
		print("[AudioStreamPlayerMejorado] Conectado con señales legacy del Singleton")

	# Conectar con la señal de configuración de audio para actualizar volumen
	if Singleton.has_signal("configurar_audio"):
		Singleton.connect("configurar_audio", Callable(self, "_on_configurar_audio"))
		print("[AudioStreamPlayerMejorado] Conectado con configuración de audio")

## Maneja cambios en las opciones de audio
func _on_configurar_audio(_opcion: int) -> void:
	# Actualizar el volumen actual si hay un tema reproduciéndose
	if tema_actual != "" and playing:
		var config = Singleton.TEMAS_REGISTRADOS.get(tema_actual, {"volumen": 1.0})
		_aplicar_volumen_tema(config.volumen)

## Maneja llamadas legacy del Singleton
func _on_play_musica_fondo_legacy(musica: AudioStreamMP3, ini: float = 0.0, fin: float = 0.0) -> void:
	print("[AudioStreamPlayerMejorado] Llamada legacy recibida")
	# Usar la función original para mantener compatibilidad total
	reproducir(musica, ini, fin)

# ===============================================
# UTILIDADES Y DEBUG
# ===============================================

## Obtiene información del tema actual
func obtener_info_tema_actual() -> Dictionary:
	return {
		"tema": tema_actual,
		"reproduciendo": playing,
		"posicion": get_playback_position(),
		"bucle_activo": tiene_bucle,
		"volumen_db": volume_db,
		"en_transicion": en_transicion
	}

## Lista todos los temas disponibles
func obtener_temas_disponibles() -> Array:
	return Singleton.TEMAS_REGISTRADOS.keys()

## Verifica si un tema existe
func tema_existe(nombre: String) -> bool:
	return Singleton.TEMAS_REGISTRADOS.has(nombre)

func _tipo_transicion_a_string(tipo: int) -> String:
	match tipo:
		0: return "INMEDIATA"
		1: return "FUNDIDO_CORTO"
		2: return "FUNDIDO_MEDIO"
		3: return "FUNDIDO_LARGO"
		4: return "SILENCIO"
		_: return "DESCONOCIDO"

## Debug del estado actual
func debug_info() -> void:
	print("=== AUDIO STREAM PLAYER MEJORADO DEBUG ===")
	print("Tema actual: ", tema_actual)
	print("Reproduciendo: ", playing)
	print("Posición: ", get_playback_position())
	print("Bucle activo: ", tiene_bucle, " (", bucle_inicio, " - ", bucle_fin, ")")
	print("Volumen base: ", volumen_base)
	print("Volumen dB: ", volume_db)
	print("En transición: ", en_transicion)
	print("Temas disponibles: ", Singleton.TEMAS_REGISTRADOS.size())
	print("===========================================")
