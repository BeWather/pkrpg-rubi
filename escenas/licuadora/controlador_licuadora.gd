## controlador_licuadora.gd
## Partida de la LICUABAYAS de un jugador contra rivales NPC (pokeruby
## src/berry_blender.c, `special DoBerryBlending` con gSpecialVar_0x8004 = rivales).
##
## Flujo, como en el C:
## 1. DoBerryBlending → sub_804E56C: la pantalla (solo marco y flechas) sale del negro,
##    «Encendiendo la LICUABAYAS...», fundido y MOCHILA en el bolsillo de BAYAS
##    (sub_80A6978: en Rubí no se puede salir sin elegir; aquí, si se cierra, vuelve
##    a abrirse).
## 2. sub_804E990 → sub_804F378: bayas de los rivales (sub_804F1BC), fundido de
##    entrada, una baya por jugador cada 61 fotogramas (case 11-12), SE_FALL, zoom
##    y giro del disco (case 14) con SE_TRUCK_DOOR y los nombres, temblor (case 15),
##    cuenta atrás (case 16) y, en el case 21, MUS_CYCLING y el minijuego.
## 3. sub_80501FC a 60 fps (`_physics_process`): ángulo, A del jugador (se evalúa en
##    cualquier momento con sub_804F16C), fricción, pulsados (sub_804FE70), barra
##    visible, RPM máxima, temblor, fin con la barra a 1000 e IA de los rivales
##    (tareas sub_804F8C8 / sub_804F9F4 / sub_804FB1C).
## 4. sub_8050954: el disco frena 32 por fotograma, CLASIFICACIÓN (A + SE_SELECT),
##    RESULTADOS DE LA MEZCLA (A), cubo (Blender_CalculatePokeblock), se gasta la baya,
##    el cubo va al estuche, «¡Has hecho un …!» con MUS_LEVEL_UP y vuelve la música
##    del mapa (sub_8052BD0), récord de RPM (Blender_TrySettingRecord).
## 5. «¿Quieres echar otra BAYA?»: SÍ → sin BAYAS o con el TUBO lleno, su mensaje y
##    salir; si no, otra vuelta (DoBerryBlending). NO → salir con fundido.
##
## SE_BERRY_BLENDER (el zumbido en bucle de SE2 con el tono de Blender_ControlHitPitch)
## no suena: el único sample es un bucle truncado a 4 s (ver
## test/audio/sonidos_se_tanda3_test.gd). El tempo de MUS_CYCLING
## (m4aMPlayTempoControl) se imita con `pitch_scale` del reproductor de música, que
## también sube el tono.
class_name ControladorLicuadora
extends Control

## Se emite al terminar, con la pantalla de la licuadora ya en negro.
signal terminado
signal _fin_minijuego
signal _mensaje_terminado
signal _cuenta_atras_lista

const ESCENA_LICUADORA: PackedScene = preload("res://escenas/licuadora/licuadora.tscn")
const ESCENA_MOCHILA: PackedScene = preload("res://UI/mochila/mochila.tscn")
## Atlas de las bayas (graphics/berries/) que comparte con la ficha de baya: cuadros de
## 48x48 en filas de 8; el cuadro 0 está vacío y el N es la baya con Bayas.numero N.
const ATLAS_BAYAS: Texture2D = preload("res://UI/ficha-baya/bayas-43.png")
const LADO_BAYA: int = 48
const COLUMNAS_ATLAS_BAYAS: int = 8
const NUM_BAYAS: int = 43
## Bolsillo de BAYAS de la mochila (BD: bolsillo 4 → mochila 3).
const BOLSILLO_BAYAS: int = 3
const ACCION_A: StringName = &"btn_accion"
const TEMA_MINIJUEGO: String = "BICICLETA"
const TEMA_FANFARRIA: String = "LEVEL_UP"

const TEXTO_ELIGE_BAYA: String = "LICUADORA_ELIGE_BAYA"
const TEXTO_CUBO_HECHO: String = "LICUADORA_CUBO_HECHO"
const TEXTO_OTRA_BAYA: String = "LICUADORA_OTRA_BAYA"
const TEXTO_SIN_BAYAS: String = "LICUADORA_SIN_BAYAS"
const TEXTO_TUBO_LLENO: String = "LICUADORA_TUBO_LLENO"
const TEXTO_RPM: String = "LICUADORA_RPM"
const TEXTO_TIEMPO: String = "LICUADORA_TIEMPO"
const TEXTO_CERRAR_MOCHILA: String = "BAYA_SELECTOR_CERRAR"

## Sonidos de sub_804FC48 por calidad (FALLO, BUENO, PERFECTO).
const SONIDOS_PULSADO: Array[String] = ["SE_FAILURE", "SE_SUCCESS", "SE_ICE_STAIRS"]
const SONIDO_CAIDA: String = "SE_FALL_RU_HYUU"
const SONIDO_ENCAJE: String = "SE_TRUCK_DOOR"
const SONIDO_CURSOR: String = "SE_SELECT"

## case 12: la siguiente baya cae cuando framesToWait > 60.
const FOTOGRAMAS_ENTRE_BAYAS: int = 61
## sub_8050954 case 2: el disco frena 32 por fotograma.
const FRENADO_POR_FOTOGRAMA: int = 32
## gameFrameTime no pasa de 99 min 59 s.
const TIEMPO_MAXIMO: int = 99 * 60 * 60 + 59 * 60
## Blender_PrintBlendingRanking: framesToWait 255 bajando de 10 en 10 (26 fotogramas)
## y > 20; Blender_PrintBlendingResults: 17 de 10 en 10 (2) y > 20.
const ESPERA_ANTES_RANKING: int = 26 + 21
const ESPERA_TRAS_RANKING: int = 21
const ESPERA_ANTES_RESULTADOS: int = 2 + 21
## gUnknown_082165F3[N] y gUnknown_082165EE[N] (separación de filas, en tiles) y
## gUnknown_082165E9[N] (primera fila de resultados), por número de jugadores.
const FILAS_RANKING: Array[int] = [3, 3, 3, 3, 2]
const FILAS_RESULTADOS: Array[int] = [3, 3, 3, 2, 2]
const PRIMERA_FILA_RESULTADOS: Array[int] = [6, 6, 6, 6, 5]
## Tile de la ventana (Menu_DrawStdWindowFrame(4, 2, 25, 17)) y de las filas de texto.
const TILE_VENTANA_Y: int = 2
const TILE_RANKING_Y: int = 8
## gSaveBlock1.berryBlenderRecords[N - 2] y GAME_STAT_POKEBLOCKS.
const CONTADOR_RECORD: String = "licuadora_record_rpm_%d"
const CONTADOR_POKECUBOS: String = "licuadora_pokecubos_hechos"

enum Fase { INACTIVA, JUGANDO, FRENANDO }

## gSpecialVar_0x8004: rivales NPC (1-3); juegan num_rivales + 1.
@export_range(1, 3) var num_rivales: int = 1

## AdministradorMapa (cuadro de diálogo, capa Menu y música del mapa).
var administrador: Node = null
## Cuadro de diálogo del campo (UI/cuadro_dialogo.gd o un doble con mostrar,
## cerrar, preguntaSiNo y comando_ejecutado). Por defecto, el del administrador.
var cuadro_dialogo: Node = null
var rng := RandomNumberGenerator.new()
## Tests: sin animaciones, fundidos ni esperas; el minijuego corre de golpe.
var modo_rapido: bool = false
## Tests: sustituye a la MOCHILA. Devuelve el nombre_interno de la baya.
var elegir_baya: Callable = Callable()
## Tests: sustituye al botón A. Recibe el ángulo y devuelve true si se pulsa.
var estrategia_jugador: Callable = Callable()

## Estado de la partida (fields de gBerryBlenderData).
var fase: Fase = Fase.INACTIVA
var num_jugadores: int = 2
var objeto_jugador: String = ""
## Filas de `Bayas`, una por jugador (0 = el jugador).
var bayas: Array[Dictionary] = []
var angulo: int = 0
var velocidad: int = 0
var progreso: int = 0
var barra_visible: int = 0
var rpm_maxima: int = 0
var tiempo: int = 0
var perfectos: Array[int] = []
var buenos: Array[int] = []
var fallos: Array[int] = []
## Último cubo hecho y si se pudo guardar.
var ultimo_cubo: Pokecubo = null
var cubos_hechos: int = 0

var licuadora: Licuadora = null
var _contador_friccion: int = 0
var _primer_fotograma_frenado: bool = false
var _temblor: Vector2i = Vector2i.ZERO
## gRecvCmds[2][jugador]: calidad pendiente de aplicar (-1 = nada).
var _comandos: Array[int] = []
## gTasks[].data[0] de cada rival: ya decidió en esta pasada.
var _ia_decidida: Array[bool] = []
## Tareas sub_804F844: FALLOS de la IA que llegan con retraso.
var _fallos_retrasados: Array[Dictionary] = []

@onready var _ventana_ranking: NinePatchRect = %VentanaRanking
@onready var _ventana_resultados: NinePatchRect = %VentanaResultados


func _ready() -> void:
	licuadora = %Licuadora
	_preparar_licuadora()
	_ventana_ranking.visible = false
	_ventana_resultados.visible = false


func _exit_tree() -> void:
	_aplicar_tempo(ReglasLicuadora.TEMPO_NORMAL)


func _physics_process(_delta: float) -> void:
	if not modo_rapido and fase != Fase.INACTIVA:
		paso_fotograma()


## Partida completa: una o más vueltas hasta que el jugador no quiere otra.
func ejecutar() -> void:
	if cuadro_dialogo == null and administrador != null:
		cuadro_dialogo = administrador.get("cuadro_dialogo")
	if not modo_rapido:
		rng.randomize()
	num_jugadores = clampi(num_rivales + 1, ReglasLicuadora.NUM_JUGADORES_MIN, ReglasLicuadora.NUM_JUGADORES_MAX)
	while true:
		var baya: String = await _elegir_baya_inicial()
		await _licuar(baya)
		var otra: bool = await _preguntar_otra()
		_cerrar_cuadro()
		# sub_80510E8 case 9: BeginFastPaletteFade(3) hacia negro.
		await _fundido_salida()
		if not otra:
			break
		_reiniciar_licuadora()
	_restaurar_musica_mapa()
	terminado.emit()


## true si queda alguna BAYA en la mochila (IsBagPocketNonEmpty(BAG_BERRIES)).
static func jugador_tiene_bayas() -> bool:
	var datos = SistemaGuardado.datos_vivos
	if datos == null or typeof(datos.mochila) != TYPE_DICTIONARY or not datos.mochila.has("bolsillos"):
		return false
	var bolsillo: Dictionary = datos.mochila.bolsillos.get(str(BOLSILLO_BAYAS), {})
	for objeto in bolsillo.get("items", []):
		if int(objeto.get("cantidad", 0)) > 0:
			return true
	return false


## ============================================================================
## 1. ELEGIR BAYA (sub_804E56C)
## ============================================================================

func _elegir_baya_inicial() -> String:
	licuadora.poner_en_negro()
	licuadora.mostrar_disco(false)
	if not modo_rapido:
		await licuadora.reproducir_fundido_entrada()
	await _mensaje(tr(TEXTO_ELIGE_BAYA))
	_cerrar_cuadro()
	await _fundido_salida()
	var baya: String = ""
	while baya.is_empty():
		baya = await _abrir_mochila()
	return baya


## sub_80A6978: la MOCHILA fija en el bolsillo de BAYAS. "" si se cerró sin elegir.
func _abrir_mochila() -> String:
	if elegir_baya.is_valid():
		return str(await elegir_baya.call())
	var contenedor: Node = _capa_menu()
	if contenedor == null:
		push_warning("[Licuadora] Sin capa Menu para la MOCHILA")
		return ""
	await Singleton.transicion("oscurecer")
	var mochila: MochilaUI = ESCENA_MOCHILA.instantiate() as MochilaUI
	contenedor.add_child(mochila)
	var eleccion: Dictionary = {"nombre_interno": ""}
	mochila.objeto_seleccionado_selector.connect(
		func(objeto: Dictionary) -> void: eleccion.nombre_interno = str(objeto.get("nombre_interno", ""))
	)
	mochila.activar_modo_selector(BOLSILLO_BAYAS, tr(TEXTO_CERRAR_MOCHILA), true)
	await Singleton.transicion("aclarar")
	await mochila.mochila_cerrada
	await Singleton.transicion("oscurecer")
	contenedor.remove_child(mochila)
	mochila.queue_free()
	await Singleton.transicion("aclarar")
	return str(eleccion.nombre_interno)


## ============================================================================
## 2. ENTRADA (sub_804F378) Y MINIJUEGO (sub_80501FC)
## ============================================================================

func _licuar(nombre_baya: String) -> void:
	objeto_jugador = nombre_baya
	var objeto_id: int = int(DatabaseManager.obtener_datos_objeto(nombre_baya).get("id", 0))
	# case 0: Blender_CopyBerryData del jugador y sub_804F1BC para los rivales.
	bayas.clear()
	bayas.append(DatabaseManager.obtener_datos_baya(objeto_id))
	bayas.append_array(ReglasLicuadora.bayas_rivales_desde_bd(objeto_id, num_jugadores))
	_reiniciar_estado()
	licuadora.mostrar_disco(false)
	licuadora.establecer_progreso(0)
	licuadora.establecer_velocidad(0)
	# case 3-4: fundido de entrada.
	if not modo_rapido:
		await licuadora.reproducir_fundido_entrada()
	# case 11-12: una baya por jugador, en orden de jugador, desde su ranura.
	for jugador in num_jugadores:
		licuadora.lanzar_baya(ReglasLicuadora.ranura_de_jugador(jugador, num_jugadores), _textura_baya(bayas[jugador]))
		await _esperar_fotogramas(FOTOGRAMAS_ENTRE_BAYAS)
	# case 13: SE_FALL; case 14: zoom y giro (arrowPos += 0x200) hasta el ángulo inicial.
	_reproducir_sonido(SONIDO_CAIDA)
	angulo = ReglasLicuadora.angulo_inicial(num_jugadores)
	licuadora.establecer_angulo(angulo)
	if modo_rapido:
		licuadora.mostrar_disco(true)
	else:
		await licuadora.reproducir_giro_entrada()
	_reproducir_sonido(SONIDO_ENCAJE)
	# sub_804F2A8: nombres (el del jugador en rojo) y flechas en reposo.
	for jugador in num_jugadores:
		licuadora.establecer_jugador(ReglasLicuadora.ranura_de_jugador(jugador, num_jugadores),
				nombre_jugador(jugador), jugador == 0)
	# case 15-16: temblor y cuenta atrás.
	if not modo_rapido:
		await licuadora.reproducir_temblor_inicio()
		licuadora.iniciar_cuenta_atras()
		await licuadora.cuenta_atras_terminada
	# case 21.
	velocidad = ReglasLicuadora.VELOCIDAD_INICIAL
	tiempo = 0
	_contador_friccion = 0
	fase = Fase.JUGANDO
	_reproducir_musica(TEMA_MINIJUEGO)
	if modo_rapido:
		while fase != Fase.INACTIVA:
			paso_fotograma()
	else:
		await _fin_minijuego
	await _mostrar_ranking()
	await _mostrar_resultados()
	await _hacer_pokecubo()


## Nombre de un jugador: el del jugador o SEÑOR/CHICO/CHICA (sBlenderOpponentsNames).
func nombre_jugador(jugador: int) -> String:
	if jugador == 0:
		return SistemaGuardado.get_nombre_jugador()
	return tr(ReglasLicuadora.clave_nombre_rival(jugador))


## Un fotograma del minijuego o del frenado final.
func paso_fotograma() -> void:
	match fase:
		Fase.JUGANDO:
			_fotograma_minijuego()
		Fase.FRENANDO:
			_fotograma_frenado()


## sub_80501FC.
func _fotograma_minijuego() -> void:
	angulo = ReglasLicuadora.avanzar_angulo(angulo, velocidad)
	if tiempo < TIEMPO_MAXIMO:
		tiempo += 1
	# sub_80500A8: A del jugador (se evalúa donde esté la flecha) y fricción.
	if _jugador_pulsa():
		licuadora.pulsar_flecha(ReglasLicuadora.ranura_de_jugador(0, num_jugadores))
		_comandos[0] = ReglasLicuadora.calidad_pulsado_jugador(angulo, 0, num_jugadores)
	var friccion: Vector2i = ReglasLicuadora.paso_friccion(velocidad, _contador_friccion)
	velocidad = friccion.x
	_contador_friccion = friccion.y
	# sub_804FE70: pulsados recibidos este fotograma, en orden de jugador.
	for jugador in num_jugadores:
		if _comandos[jugador] >= 0:
			var calidad: int = _comandos[jugador]
			_comandos[jugador] = -1
			_aplicar_pulsado(jugador, calidad)
	barra_visible = ReglasLicuadora.paso_barra_visible(barra_visible, progreso)
	rpm_maxima = ReglasLicuadora.actualizar_rpm_maxima(rpm_maxima, velocidad)
	_amortiguar_temblor()
	if ReglasLicuadora.ha_terminado(barra_visible):
		progreso = ReglasLicuadora.PROGRESO_MAXIMO
		_empezar_frenado()
	else:
		_turno_rivales()
	_actualizar_pantalla()


func _jugador_pulsa() -> bool:
	if estrategia_jugador.is_valid():
		return bool(estrategia_jugador.call(angulo))
	return Input.is_action_just_pressed(ACCION_A)


## sub_804FD30 + sub_804FE70 + sub_804FC48 para un pulsado de `jugador`.
func _aplicar_pulsado(jugador: int, calidad: int) -> void:
	var c: ReglasLicuadora.Calidad = calidad as ReglasLicuadora.Calidad
	var velocidad_previa: int = velocidad
	velocidad = ReglasLicuadora.velocidad_tras_pulsado(velocidad, c, num_jugadores)
	if ReglasLicuadora.pulsado_hace_temblar(velocidad_previa, c):
		@warning_ignore("integer_division")
		var amplitud: int = velocidad / 100 - 10
		_iniciar_temblor(amplitud)
	progreso = ReglasLicuadora.progreso_tras_pulsado(progreso, velocidad, c)
	match c:
		ReglasLicuadora.Calidad.PERFECTO:
			perfectos[jugador] += 1
		ReglasLicuadora.Calidad.BUENO:
			buenos[jugador] += 1
		_:
			fallos[jugador] = ReglasLicuadora.sumar_fallo(fallos[jugador])
	licuadora.mostrar_resultado(ReglasLicuadora.ranura_de_jugador(jugador, num_jugadores),
			calidad as Licuadora.Calidad, angulo)
	_reproducir_sonido(SONIDOS_PULSADO[calidad])
	_aplicar_tempo(ReglasLicuadora.tempo_musica(velocidad))


## RunTasks: las tareas de la IA (una por rival) y los FALLOS retrasados.
func _turno_rivales() -> void:
	for i in range(_fallos_retrasados.size() - 1, -1, -1):
		var pendiente: Dictionary = _fallos_retrasados[i]
		pendiente["cuenta"] = int(pendiente["cuenta"]) + 1
		if int(pendiente["cuenta"]) > ReglasLicuadora.RETRASO_FALLO_IA:
			_comandos[int(pendiente["rival"])] = ReglasLicuadora.Calidad.FALLO
			_fallos_retrasados.remove_at(i)
	for rival in range(1, num_jugadores):
		if not ReglasLicuadora.en_ventana_ia(rival, angulo, num_jugadores):
			_ia_decidida[rival] = false
			continue
		if _ia_decidida[rival]:
			continue
		_ia_decidida[rival] = true
		var decision: Dictionary = ReglasLicuadora.decidir_ia(rival, velocidad, ReglasLicuadora.tirada_ia(rng))
		if not bool(decision["pulsa"]):
			continue
		if int(decision["retraso"]) > 0:
			_fallos_retrasados.append({"rival": rival, "cuenta": 0})
		else:
			_comandos[rival] = int(decision["calidad"])


## sub_8051AC8: solo si no hay temblor en curso, Random() % a − a / 2.
func _iniciar_temblor(amplitud: int) -> void:
	if amplitud <= 0:
		return
	@warning_ignore("integer_division")
	var mitad: int = amplitud / 2
	if _temblor.x == 0:
		_temblor.x = rng.randi_range(0, 0xFFFF) % amplitud - mitad
	if _temblor.y == 0:
		_temblor.y = rng.randi_range(0, 0xFFFF) % amplitud - mitad


## sub_8051B18: el desplazamiento vuelve a 0 de uno en uno.
func _amortiguar_temblor() -> void:
	_temblor.x -= signi(_temblor.x)
	_temblor.y -= signi(_temblor.y)


## sub_8050954 case 1: fin del minijuego, tempo normal y fuera la IA.
func _empezar_frenado() -> void:
	fase = Fase.FRENANDO
	_primer_fotograma_frenado = true
	_fallos_retrasados.clear()
	_aplicar_tempo(ReglasLicuadora.TEMPO_NORMAL)


## sub_8050954 case 2: el disco frena hasta pararse.
func _fotograma_frenado() -> void:
	angulo = ReglasLicuadora.avanzar_angulo(angulo, velocidad)
	if _primer_fotograma_frenado:
		_primer_fotograma_frenado = false
	else:
		velocidad -= FRENADO_POR_FOTOGRAMA
	_amortiguar_temblor()
	var parado: bool = velocidad <= 0
	if parado:
		velocidad = 0
	rpm_maxima = ReglasLicuadora.actualizar_rpm_maxima(rpm_maxima, velocidad)
	_actualizar_pantalla()
	if parado:
		fase = Fase.INACTIVA
		_fin_minijuego.emit()


func _actualizar_pantalla() -> void:
	licuadora.establecer_angulo(angulo)
	licuadora.establecer_velocidad(velocidad)
	licuadora.establecer_progreso(barra_visible)
	licuadora.establecer_temblor(Vector2(_temblor))


## ============================================================================
## 3. CLASIFICACIÓN, RESULTADOS Y CUBO
## ============================================================================

## Blender_SortScores: jugadores de mayor a menor puntuación.
func clasificacion() -> Array[int]:
	var puntos: Array[int] = []
	for jugador in num_jugadores:
		puntos.append(ReglasLicuadora.puntuacion(perfectos[jugador], buenos[jugador], fallos[jugador]))
	return ReglasLicuadora.ordenar_ranking(puntos)


## Blender_PrintBlendingRanking.
func _mostrar_ranking() -> void:
	await _esperar_fotogramas(ESPERA_ANTES_RANKING)
	var puestos: Array[int] = clasificacion()
	var filas: Node = _ventana_ranking.get_node("Filas")
	var salto: int = FILAS_RANKING[num_jugadores] * 8
	for i in filas.get_child_count():
		var fila: Control = filas.get_child(i) as Control
		fila.visible = i < num_jugadores
		if not fila.visible:
			continue
		var jugador: int = puestos[i]
		fila.position.y = (TILE_RANKING_Y - TILE_VENTANA_Y) * 8 + i * salto
		(fila.get_node("Puesto") as Label).text = "%d." % (i + 1)
		(fila.get_node("Nombre") as Label).text = nombre_jugador(jugador)
		(fila.get_node("Perfectos") as Label).text = str(perfectos[jugador])
		(fila.get_node("Buenos") as Label).text = str(buenos[jugador])
		(fila.get_node("Fallos") as Label).text = str(fallos[jugador])
	_ventana_ranking.visible = true
	await _esperar_fotogramas(ESPERA_TRAS_RANKING)
	await _esperar_boton_a()
	_reproducir_sonido(SONIDO_CURSOR)


## Blender_PrintBlendingResults (cases 0-4).
func _mostrar_resultados() -> void:
	await _esperar_fotogramas(ESPERA_ANTES_RESULTADOS)
	_ventana_ranking.visible = false
	var puestos: Array[int] = clasificacion()
	var filas: Node = _ventana_resultados.get_node("Filas")
	var salto: int = FILAS_RESULTADOS[num_jugadores] * 8
	for i in filas.get_child_count():
		var fila: Control = filas.get_child(i) as Control
		fila.visible = i < num_jugadores
		if not fila.visible:
			continue
		var jugador: int = puestos[i]
		fila.position.y = (PRIMERA_FILA_RESULTADOS[num_jugadores] - TILE_VENTANA_Y) * 8 + i * salto
		(fila.get_node("Puesto") as Label).text = "%d." % (i + 1)
		(fila.get_node("Nombre") as Label).text = nombre_jugador(jugador)
		(fila.get_node("Baya") as Label).text = _nombre_baya(bayas[jugador])
	(_ventana_resultados.get_node("VelocidadMaxima/Valor") as Label).text = texto_rpm(rpm_maxima)
	(_ventana_resultados.get_node("Tiempo/Valor") as Label).text = texto_tiempo(tiempo)
	_ventana_resultados.visible = true
	await _esperar_boton_a()
	_ventana_resultados.visible = false


## «12,34 rpm»: max_RPM / 100 y max_RPM % 100 con dos cifras.
static func texto_rpm(rpm: int) -> String:
	@warning_ignore("integer_division")
	var entero: int = rpm / 100
	return tr_estatico(TEXTO_RPM).replace("{entero}", str(entero)).replace("{decimal}", "%02d" % (rpm % 100))


## «01 min 23 s» a partir de gameFrameTime (fotogramas).
static func texto_tiempo(fotogramas: int) -> String:
	@warning_ignore("integer_division")
	var segundos: int = fotogramas / 60
	@warning_ignore("integer_division")
	var minutos: int = segundos / 60
	return tr_estatico(TEXTO_TIEMPO).replace("{min}", "%02d" % minutos).replace("{seg}", "%02d" % (segundos % 60))


static func tr_estatico(clave: String) -> String:
	return TranslationServer.translate(clave)


## Blender_PrintBlendingResults case 5-6: cubo, baya gastada, cubo al estuche y
## mensaje con MUS_LEVEL_UP; al acabar la fanfarria vuelve la música del mapa.
func _hacer_pokecubo() -> void:
	ultimo_cubo = ReglasLicuadora.calcular_pokecubo(bayas, rpm_maxima, rng)
	var texto: String = tr(TEXTO_CUBO_HECHO) \
			.replace("{pokecubo}", tr(ultimo_cubo.clave_nombre())) \
			.replace("{nivel}", str(ultimo_cubo.nivel())) \
			.replace("{suavidad}", str(ultimo_cubo.suavidad_mostrada()))
	_fanfarria_y_musica_mapa()
	SistemaGuardado.quitar_objeto_jugador(objeto_jugador, 1, BOLSILLO_BAYAS)
	if SistemaGuardado.obtener_estuche_pokecubos().agregar(ultimo_cubo) >= 0:
		cubos_hechos += 1
	SistemaGuardado.incrementar_contador(CONTADOR_POKECUBOS)
	await _mensaje(texto)
	# Blender_TrySettingRecord.
	var clave_record: String = CONTADOR_RECORD % num_jugadores
	if SistemaGuardado.get_contador(clave_record) < rpm_maxima:
		SistemaGuardado.set_contador(clave_record, rpm_maxima)


## sub_8050954 cases 7-11: ¿otra? SÍ solo sigue si quedan BAYAS y hueco en el TUBO.
func _preguntar_otra() -> bool:
	if not await _preguntar_si_no(tr(TEXTO_OTRA_BAYA)):
		return false
	if not jugador_tiene_bayas():
		await _mensaje(tr(TEXTO_SIN_BAYAS))
		return false
	if SistemaGuardado.obtener_estuche_pokecubos().esta_lleno():
		await _mensaje(tr(TEXTO_TUBO_LLENO))
		return false
	return true


## ============================================================================
## UTILIDADES
## ============================================================================

## Nueva vuelta: DoBerryBlending vuelve a montar la pantalla desde cero.
func _reiniciar_licuadora() -> void:
	var vieja: Licuadora = licuadora
	licuadora = ESCENA_LICUADORA.instantiate() as Licuadora
	licuadora.name = vieja.name
	licuadora.unique_name_in_owner = false
	remove_child(vieja)
	vieja.queue_free()
	add_child(licuadora)
	move_child(licuadora, 0)
	_preparar_licuadora()


func _preparar_licuadora() -> void:
	licuadora.sonido_solicitado.connect(_reproducir_sonido)
	licuadora.poner_en_negro()
	licuadora.mostrar_disco(false)


func _reiniciar_estado() -> void:
	angulo = 0
	velocidad = 0
	progreso = 0
	barra_visible = 0
	rpm_maxima = 0
	tiempo = 0
	_contador_friccion = 0
	_temblor = Vector2i.ZERO
	_fallos_retrasados.clear()
	perfectos.clear()
	buenos.clear()
	fallos.clear()
	_comandos.clear()
	_ia_decidida.clear()
	for i in num_jugadores:
		perfectos.append(0)
		buenos.append(0)
		fallos.append(0)
		_comandos.append(-1)
		_ia_decidida.append(false)


func _textura_baya(baya: Dictionary) -> Texture2D:
	var numero := int(baya.get("numero", 0))
	if numero < 1 or numero > NUM_BAYAS:
		return null
	@warning_ignore("integer_division")
	var fila := numero / COLUMNAS_ATLAS_BAYAS
	var textura := AtlasTexture.new()
	textura.atlas = ATLAS_BAYAS
	textura.region = Rect2(
		(numero % COLUMNAS_ATLAS_BAYAS) * LADO_BAYA, fila * LADO_BAYA, LADO_BAYA, LADO_BAYA)
	return textura


func _nombre_baya(baya: Dictionary) -> String:
	var nombre_interno: String = DatabaseManager.obtener_nombre_interno_objeto_por_id(int(baya.get("objeto_id", 0)))
	if nombre_interno.is_empty():
		return ""
	return str(SistemaGuardado.obtener_datos_objeto_completos(nombre_interno).get("nombre", nombre_interno))


func _capa_menu() -> Node:
	if administrador != null:
		var capa: Node = administrador.get_node_or_null("Menu")
		if capa != null:
			return capa
	return get_parent()


func _fundido_salida() -> void:
	if not modo_rapido:
		await licuadora.reproducir_fundido_salida()


func _esperar_fotogramas(fotogramas: int) -> void:
	if modo_rapido:
		return
	for i in fotogramas:
		await get_tree().physics_frame


func _esperar_boton_a() -> void:
	if modo_rapido:
		return
	await get_tree().physics_frame
	while not Input.is_action_just_pressed(ACCION_A):
		await get_tree().physics_frame


## MenuPrintMessage en la caja de mensajes (la del campo); espera el botón y la deja
## abierta para el siguiente mensaje.
func _mensaje(texto: String) -> void:
	if cuadro_dialogo == null:
		return
	cuadro_dialogo.mostrar(texto, true, false, _mensaje_terminado.emit)
	await _mensaje_terminado


## Pregunta SÍ/NO; cancelar equivale a NO.
func _preguntar_si_no(texto: String) -> bool:
	if cuadro_dialogo == null:
		return false
	cuadro_dialogo.cerrar()
	cuadro_dialogo.preguntaSiNo(texto)
	while true:
		var datos: Array = await cuadro_dialogo.comando_ejecutado
		if datos.size() >= 2 and str(datos[0]) == "respuesta_confirmacion":
			var parametros: Array = datos[1]
			return not parametros.is_empty() and str(parametros[0]) == "Y"
	return false


func _cerrar_cuadro() -> void:
	if cuadro_dialogo != null:
		cuadro_dialogo.cerrar()


func _reproducir_sonido(clave: String) -> void:
	if Singleton.se.has(clave):
		Singleton.play_sound.emit(clave)


func _reproducir_musica(tema: String) -> void:
	if not modo_rapido and Singleton.TEMAS_REGISTRADOS.has(tema):
		Singleton.reproducir_tema(tema, true)


## sub_8052BD0: MUS_LEVEL_UP y, al acabar, la música del mapa (field_178).
func _fanfarria_y_musica_mapa() -> void:
	if not modo_rapido:
		await Fanfarria.reproducir(self, TEMA_FANFARRIA)
	_restaurar_musica_mapa()


func _restaurar_musica_mapa() -> void:
	if is_instance_valid(administrador) and administrador.has_method("restaurar_musica_mapa_actual"):
		administrador.restaurar_musica_mapa_actual()


## m4aMPlayTempoControl(&gMPlayInfo_BGM, tempo): 256 = normal. Con pitch_scale,
## que también cambia el tono (el m4a solo cambia el tempo).
func _aplicar_tempo(tempo: int) -> void:
	if modo_rapido or not is_inside_tree():
		return
	var reproductor := Singleton.obtener_nodo("ReproductorMusica") as AudioStreamPlayer
	if reproductor != null:
		reproductor.pitch_scale = float(tempo) / float(ReglasLicuadora.TEMPO_NORMAL)
