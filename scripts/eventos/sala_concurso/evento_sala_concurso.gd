## evento_sala_concurso.gd
## SALA del CONCURSO (pokeruby LinkContestRoom1/scripts.inc + data/scripts/contest_hall.inc:183-1150).
## Se llega con el warp de la recepcionista (VAR_LINK_CONTEST_ROOM_STATE = 1) y SalaConcurso.inscripcion
## con lo que se inscribió. Al activarse el mapa:
##
## - ON_TRANSITION / ON_WARP: público aleatorio (7 espectadores, ScriptRandom(32) sobre la lista de
##   AddRandomAudienceMembers), público fijo del nivel (NPCs/Publico/NivelN) y el jugador oculto; los
##   concursantes 1-3 llevan el gráfico de su rival y el 4 el del jugador.
## - 1A514D: la PRESENTADORA da un paso, presenta el concurso; cada concursante sube al centro, sale la
##   POKé BALL y la ventana con su POKéMON (ShowContestEntryMonPic), el público vota (emote_heart en
##   SalaConcurso.nivel_votacion espectadores distintos de 8) y vuelve; primera votación; apelaciones
##   (ConcursoCompleto); textos del juez; resultados; felicitación al ganador y premios.
## - 15FB64: GAME_STAT_ENTERED_CONTEST (SalaConcurso.cerrar_concurso) y warp al vestíbulo.
extends EventoInteriorMalvalona
class_name EventoSalaConcurso

const MOTIVO_PAUSA: StringName = &"sala_concurso"
const RUTA_DATOS: String = "res://BaseDatos/concursos/sala_concurso.json"
const VENTANA_ENTRADA: PackedScene = preload("res://escenas/concurso/ventana_entrada_concurso.tscn")
const TEXTURA_CORAZON: Texture2D = preload("res://graficos/concurso/emote_corazon.png")
const TEMA_GANADOR: String = "CONCURSO_GANADOR"
## Centro del escenario al que sube cada concursante (Movement_1A5DCE … 1A5DEA).
const CELDA_CENTRO: Vector2i = Vector2i(7, 6)
## Subida al centro y vuelta rápida de cada concursante (Movement_1A5DCE/1A5DD4, 1A5DDA/1A5DDE,
## 1A5DE2/1A5DE6, 1A5DEA/1A5DF0).
const SUBIDAS: Array = [[Vector2.UP, Vector2.RIGHT, Vector2.RIGHT, Vector2.RIGHT], [Vector2.UP, Vector2.RIGHT],
	[Vector2.UP, Vector2.LEFT], [Vector2.UP, Vector2.LEFT, Vector2.LEFT, Vector2.LEFT]]
const BAJADAS: Array = [[Vector2.LEFT, Vector2.LEFT, Vector2.LEFT, Vector2.DOWN], [Vector2.LEFT, Vector2.DOWN],
	[Vector2.RIGHT, Vector2.DOWN], [Vector2.RIGHT, Vector2.RIGHT, Vector2.RIGHT, Vector2.DOWN]]
## Votantes del público (objetos 6, 12, 7, 8, 9, 10, 11 y 15 en 1A54EB): los 7 aleatorios y el ARTISTA.
const NUM_VOTANTES: int = 8
## 1A5A90: rondas de giros del público al anunciar.
const GIROS_PUBLICO: int = 4
## Índice en publico_aleatorio y dirección de cada giro: objetos 9, 12 y 7 (Movement_1A5DB7 y
## 1A5DBB) y objetos 10, 11, 6 y 8 (Movement_1A5DAF, 1A5DBB y 1A5DB3).
const GRUPO_PUBLICO_1: Array = [[4, Vector2.RIGHT], [1, Vector2.DOWN], [2, Vector2.RIGHT]]
const GRUPO_PUBLICO_2: Array = [[5, Vector2.LEFT], [6, Vector2.DOWN], [0, Vector2.UP], [3, Vector2.LEFT]]
## Dirección de turnvobject (índice 1 sur, 2 norte, 3 oeste, 4 este).
const DIRECCIONES_VOBJETO: Array[Vector2] = [Vector2.ZERO, Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]

const TEXTO_PRESENTACION: String = "CONCURSO_SALA_PRESENTACION"
const TEXTO_ENTRADA: String = "CONCURSO_SALA_ENTRADA"
const TEXTO_PRIMERA_VOTACION: String = "CONCURSO_SALA_PRIMERA_VOTACION"
const TEXTO_VOTANDO: String = "CONCURSO_SALA_VOTANDO"
const TEXTO_SEGUNDA_VOTACION: String = "CONCURSO_SALA_SEGUNDA_VOTACION"
const TEXTO_FIN_VOTACION: String = "CONCURSO_SALA_FIN_VOTACION"
const TEXTO_GRACIAS: String = "CONCURSO_SALA_GRACIAS"
const TEXTO_PROCLAMAR: String = "CONCURSO_SALA_PROCLAMAR"
const TEXTO_JUEZ_GANADOR: String = "CONCURSO_SALA_JUEZ_GANADOR"
const TEXTO_FELICIDADES_GANADOR: String = "CONCURSO_SALA_FELICIDADES_GANADOR"
const TEXTO_CINTA: String = "CONCURSO_SALA_CINTA"
const TEXTO_RECIBIO_CINTA: String = "CONCURSO_SALA_RECIBIO_CINTA"
const TEXTO_PUSO_CINTA: String = "CONCURSO_SALA_PUSO_CINTA"
const TEXTO_PREMIO: String = "CONCURSO_SALA_PREMIO"
const TEXTO_FELICIDADES: String = "CONCURSO_SALA_FELICIDADES"
const TEXTO_PREMIO_EN_RECEPCION: String = "CONCURSO_SALA_PREMIO_EN_RECEPCION"

@export var presentadora: NodePath
@export var juez: NodePath
@export var concursantes: Array[NodePath] = []
@export var publico_aleatorio: Array[NodePath] = []
@export var pokeball: NodePath
@export var artista: NodePath
@export var publico_fijo: NodePath

## Sustitutos para tests: jugar las apelaciones (concursantes, categoría, nivel, aleatorio) ->
## MotorConcurso terminado, y mostrar los resultados (motor).
var jugar_apelaciones: Callable = Callable()
var mostrar_resultados: Callable = Callable()
## Textos de entrada mostrados (para tests).
var entradas_mostradas: PackedStringArray = []
## Votos del público de cada entrada (para tests).
var votos: Array[int] = []

var _datos: Dictionary = {}
var _ventana: Node = null


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var mapa := obtener_mapa()
	if mapa != null:
		mapa.mapa_activado.connect(_on_mapa_activado)


func _on_mapa_activado(por_warp: bool) -> void:
	if por_warp and not SalaConcurso.inscripcion.is_empty():
		await escena()


func datos_sala() -> Dictionary:
	if _datos.is_empty() and FileAccess.file_exists(RUTA_DATOS):
		var leido: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUTA_DATOS))
		if leido is Dictionary:
			_datos = leido
	return _datos


## ON_TRANSITION + ON_WARP: público y gráficos de los concursantes.
func preparar(inscripcion: Dictionary, aleatorio: AleatorioConcurso) -> void:
	var datos := datos_sala()
	var lista: Array = datos.get("publico_aleatorio", [])
	for ruta in publico_aleatorio:
		var espectador := nodo(ruta)
		if espectador != null and not lista.is_empty():
			_vestir(espectador, str(lista[aleatorio.modulo(lista.size())]))
	var fijo: Node = get_node_or_null(publico_fijo)
	if fijo != null:
		for grupo in fijo.get_children():
			grupo.visible = grupo.name == "Nivel%d" % int(inscripcion.get("nivel", 0))
	var lista_concursantes: Array = inscripcion.get("concursantes", [])
	var rivales: Dictionary = datos.get("rivales", {})
	for i in mini(concursantes.size(), lista_concursantes.size()):
		var npc := nodo(concursantes[i])
		var c: ConcursanteConcurso = lista_concursantes[i]
		if npc == null:
			continue
		if c.es_jugador:
			var sexo := str(SistemaGuardado.datos_vivos.jugador.get("sexo", "M"))
			_vestir(npc, str(datos.get("jugador", {}).get(sexo, "rival_bruno")))
		elif rivales.has(c.grafico):
			_vestir(npc, str(rivales[c.grafico]))
		mirar(npc, Vector2.UP)
	var ball := nodo(pokeball)
	if ball != null:
		ball.visible = false


func _vestir(npc: Node2D, avatar: String) -> void:
	var ruta := "res://escenas/avatares/%s.tres" % avatar
	if ResourceLoader.exists(ruta):
		npc.selec_frames = load(ruta)


## LinkContestRoom1_EventScript_15F61A: todo el concurso y el regreso.
func escena() -> void:
	var inscripcion: Dictionary = SalaConcurso.inscripcion
	if not comenzar(_administrador()):
		return
	# ON_TRANSITION: mapa_activado llega con la pantalla aún en negro; todo queda listo antes del fundido.
	var jugador: Node = admin.get("jugador")
	if jugador != null:
		jugador.visible = false  # hideobjectat LOCALID_PLAYER
	var aleatorio: AleatorioConcurso = inscripcion.get("aleatorio", AleatorioConcurso.new(randi() & 0xFFFF))
	preparar(inscripcion, aleatorio)
	# Al terminar, el warp vuelve a mostrar y a dar el control al jugador justo cuando aclara.
	while int(admin.get("coneccion")) != 0:
		await get_tree().process_frame
	if jugador != null:
		jugador.visible = false
		jugador.no_control = true
	await esperar_fin_warp(admin)
	var lista: Array[ConcursanteConcurso] = []
	lista.assign(inscripcion.get("concursantes", []))
	var categoria: int = int(inscripcion.get("categoria", 0))
	var nivel: int = int(inscripcion.get("nivel", 0))
	var mc := nodo(presentadora)
	var el_juez := nodo(juez)
	# 1A514D: el concursante 4 mira arriba y la PRESENTADORA da un paso.
	await caminar(mc, Vector2.DOWN)
	await mensaje(TEXTO_PRESENTACION, true, {"{categoria}": tr("CONCURSO_CATEGORIA_%d" % categoria),
		"{nivel}": tr("CONCURSO_NIVEL_%d" % nivel)})
	await caminar(mc, Vector2.UP, NpcBase.VelocidadPaso.NORMAL, Vector2.DOWN)
	for i in lista.size():
		await _entrada(i, lista[i], categoria, nivel, aleatorio)
	# 1A5377: primera votación.
	await mensaje(TEXTO_PRIMERA_VOTACION)
	await _mensaje_sin_espera(TEXTO_VOTANDO)
	_sonar("SE_M_ENCORE2")
	await _girar_publico(nivel)
	mirar(mc, Vector2.RIGHT)
	mirar(el_juez, Vector2.LEFT)
	await esperar_fotogramas(20)
	mirar(mc, Vector2.DOWN)
	mirar(el_juez, Vector2.DOWN)
	# 1A58EE: apelaciones.
	await mensaje(TEXTO_SEGUNDA_VOTACION)
	admin.cuadro_dialogo.cerrar()
	# Movement_1A5D91 y 1A5D95: se apartan para dejar sitio y vuelven al terminar.
	await _mover_presentadora_y_juez(mc, el_juez, Vector2.LEFT, Vector2.RIGHT)
	var motor: MotorConcurso = await _jugar_apelaciones(lista, categoria, nivel, aleatorio)
	await _mover_presentadora_y_juez(mc, el_juez, Vector2.RIGHT, Vector2.LEFT)
	# 1A594A: fin, agradecimiento, proclamación y resultados.
	await mensaje(TEXTO_FIN_VOTACION)
	await mensaje(TEXTO_GRACIAS)
	mirar(mc, Vector2.RIGHT)  # Movement_1A5D8B: la PRESENTADORA mira al JUEZ.
	await mensaje(TEXTO_PROCLAMAR)
	await mensaje(TEXTO_JUEZ_GANADOR)
	mirar(mc, Vector2.DOWN)
	admin.cuadro_dialogo.cerrar()
	await _mostrar_resultados(motor)
	if not jugar_apelaciones.is_valid():
		reproducir_musica(TEMA_GANADOR)
	# 1A59FC / 1A5A49: el ganador.
	var ganador: int = motor.estado.ganador()
	var c_ganador: ConcursanteConcurso = motor.concursante(ganador)
	await mensaje(TEXTO_FELICIDADES_GANADOR, true, {"{numero}": ganador + 1, "{mon}": c_ganador.mote,
		"{entrenador}": c_ganador.entrenador})
	# Movement_1A5D99: el ganador da un paso al frente.
	var npc_ganador := nodo(concursantes[ganador]) if ganador < concursantes.size() else null
	if npc_ganador != null:
		await caminar(npc_ganador, Vector2.UP)
		mirar(npc_ganador, Vector2.DOWN)
	_sonar("SE_M_ENCORE2")
	await _girar_publico(nivel)
	# sub_80BE23C (Task_EndAppeals) y sub_80BE284 (resultados): el CONCURSO para el programa
	# ENTRENADOR ESTRELLA y el REPORTERO que espera en el vestíbulo.
	var jugador_concurso: ConcursanteConcurso = motor.concursante(motor.estado.indice_jugador)
	ProgramasTV.al_terminar_apelaciones(motor.datos.nombre_interno_movimiento(jugador_concurso.mov_previo))
	ProgramasTV.al_terminar_concurso(motor.estado.puestos_finales[motor.estado.indice_jugador], categoria,
		nivel, inscripcion.get("pokemon") as BasePokemon, str(inscripcion.get("vestibulo", "")))
	# 1A5BAB: premios.
	var tipo := SalaConcurso.cerrar_concurso(motor, bool(inscripcion.get("ya_tenia_cinta", false)),
		SistemaGuardado.get_registro_concursos())
	await _entregar_premio(tipo, inscripcion.get("pokemon") as BasePokemon, categoria, mc)
	await _regresar(inscripcion)


## 1A52AE … 1A5880: una entrada.
func _entrada(i: int, c: ConcursanteConcurso, categoria: int, nivel: int, aleatorio: AleatorioConcurso) -> void:
	var npc := nodo(concursantes[i]) if i < concursantes.size() else null
	if npc != null:
		await recorrer(npc, SUBIDAS[i])
		mirar(npc, Vector2.UP)
	await esperar_fotogramas(32)
	var ball := nodo(pokeball)
	if ball != null:
		ball.visible = true  # addobject 13
	_sonar("SE_LEDGE")
	await esperar_fotogramas(32)
	_sonar("SE_BALL_OPEN")
	_mostrar_ventana(c)
	var texto := tr(TEXTO_ENTRADA).replace("{numero}", str(i + 1)).replace("{mon}", c.mote) \
		.replace("{entrenador}", c.entrenador)
	entradas_mostradas.append(texto)
	await _mostrar_sin_espera(texto)
	# 1A5455: votación del público.
	var cantidad: int = SalaConcurso.nivel_votacion(MotorConcurso.puntos_ronda1(c, categoria), nivel)
	votos.append(cantidad)
	await _votar(cantidad, aleatorio)
	# 1A53E5: la PRESENTADORA mira al público y después se gira hacia el JUEZ.
	var mc := nodo(presentadora)
	mirar(mc, Vector2.LEFT)
	await esperar_fotogramas(16)
	mirar(mc, Vector2.DOWN)
	_sonar("SE_M_ENCORE2")
	await _girar_vobjetos(nivel)
	await _girar_grupo(GRUPO_PUBLICO_1)
	mirar(mc, Vector2.RIGHT)
	await esperar_fotogramas(16)
	mirar(mc, Vector2.DOWN)
	await _girar_grupo(GRUPO_PUBLICO_2)
	mirar(mc, Vector2.UP)
	await esperar_fotogramas(16)
	var el_juez := nodo(juez)
	mirar(mc, Vector2.RIGHT)
	mirar(el_juez, Vector2.LEFT)
	await esperar_fotogramas(32)
	mirar(mc, Vector2.DOWN)
	mirar(el_juez, Vector2.DOWN)
	# 1A5880: cierra la ventana y vuelve a su sitio.
	admin.cuadro_dialogo.cerrar()
	if ball != null:
		ball.visible = false
	_cerrar_ventana()
	if npc != null:
		await recorrer(npc, BAJADAS[i], NpcBase.VelocidadPaso.RAPIDO)
		mirar(npc, Vector2.UP)


## La PRESENTADORA y el JUEZ dan dos pasos a la vez y miran abajo.
func _mover_presentadora_y_juez(mc: Node2D, el_juez: Node2D, dir_mc: Vector2, dir_juez: Vector2) -> void:
	var pendientes := [2]
	var andar := func(npc: Node2D, direccion: Vector2) -> void:
		await recorrer(npc, [direccion, direccion])
		mirar(npc, Vector2.DOWN)
		pendientes[0] -= 1
	andar.call(mc, dir_mc)
	andar.call(el_juez, dir_juez)
	while pendientes[0] > 0:
		await get_tree().process_frame


## 1A54EB: `cantidad` espectadores distintos (de 8) hacen emote_heart con SE_PIN, 14 frames entre uno y otro.
func _votar(cantidad: int, aleatorio: AleatorioConcurso) -> void:
	var votantes: Array[Node2D] = []
	for ruta in publico_aleatorio:
		votantes.append(nodo(ruta))
	votantes.append(nodo(artista))
	var usados: Array[int] = []
	while usados.size() < mini(cantidad, NUM_VOTANTES):
		var k: int = aleatorio.modulo(NUM_VOTANTES)
		if k in usados:
			continue
		usados.append(k)
		if k < votantes.size() and votantes[k] != null:
			_corazon(votantes[k])
		_sonar("SE_PIN")
		await esperar_fotogramas(14)


## emote_heart: el corazón aparece sobre la cabeza y se va.
func _corazon(npc: Node2D) -> void:
	var icono := Sprite2D.new()
	icono.texture = TEXTURA_CORAZON
	icono.z_index = 20
	icono.position = Vector2(0, -30)
	npc.add_child(icono)
	var tween := icono.create_tween()
	tween.tween_property(icono, "position", Vector2(0, -36), 0.1)
	tween.tween_property(icono, "position", Vector2(0, -30), 0.15)
	tween.tween_interval(0.5)
	tween.tween_callback(icono.queue_free)


## 1A5A90: cuatro rondas de giros. Desde el nivel ALTO también gira el público fijo.
func _girar_publico(nivel: int) -> void:
	for _ronda in GIROS_PUBLICO:
		if nivel > 0:
			await _girar_vobjetos(nivel)
		_girar_grupo(GRUPO_PUBLICO_1)
		await esperar_fotogramas(30)
		_girar_grupo(GRUPO_PUBLICO_2)
	await esperar_fotogramas(30)


## Movement_1A5DAF … 1A5DBB: face_* + delay_16 + face_original_direction.
func _girar_grupo(grupo: Array) -> void:
	var originales: Array[Vector2] = []
	for giro: Array in grupo:
		var npc := nodo(publico_aleatorio[giro[0]])
		originales.append(npc.facing_direction)
		mirar(npc, giro[1])
	await esperar_fotogramas(16)
	for k in grupo.size():
		mirar(nodo(publico_aleatorio[grupo[k][0]]), originales[k])


## 1A5AE4: turnvobject del público fijo del nivel, 10 fotogramas por etapa. Si varios comparten
## vobjeto, gira el primero creado (como FindVirtualObjectSpriteIdByLocalId).
func _girar_vobjetos(nivel: int) -> void:
	var fijo: Node = get_node_or_null(publico_fijo)
	var datos := datos_sala()
	var vobjetos: Array = datos.get("vobjetos_publico", [[], [], [], []])[nivel]
	var grupo: Node = fijo.get_node_or_null("Nivel%d" % nivel) if fijo != null else null
	for etapa: Array in datos.get("giros_vobjetos", []):
		for giro: Array in etapa:
			var k: int = vobjetos.find(giro[0])
			if grupo != null and k >= 0 and k < grupo.get_child_count():
				mirar(grupo.get_child(k), DIRECCIONES_VOBJETO[int(giro[1])])
		await esperar_fotogramas(10)


## 1A5BAB: premio según SalaConcurso.premio.
func _entregar_premio(tipo: SalaConcurso.Premio, pokemon: BasePokemon, categoria: int, mc: Node2D) -> void:
	if tipo == SalaConcurso.Premio.REPETIDO:
		await mensaje(TEXTO_FELICIDADES)
		return
	await mensaje(TEXTO_PREMIO)
	match tipo:
		SalaConcurso.Premio.CINTA:
			if pokemon != null:
				SalaConcurso.entregar_cinta(pokemon, categoria)
			await mensaje(TEXTO_CINTA)
			await mensaje_con_fanfarria(TEXTO_RECIBIO_CINTA)
			await mensaje(TEXTO_PUSO_CINTA, true, {"{mon}": pokemon.get_nombre_mostrar() if pokemon != null else ""})
		SalaConcurso.Premio.LUJO_BALL:
			if not await dar_objeto(mc, SalaConcurso.OBJETO_PREMIO_EXPERTO):
				SistemaGuardado.get_registro_concursos().premio_pendiente = SalaConcurso.OBJETO_PREMIO_EXPERTO
				await mensaje(TEXTO_PREMIO_EN_RECEPCION)
		_:
			await mensaje(TEXTO_FELICIDADES)


## 15FB64: vuelta al vestíbulo (el jugador reaparece en la celda de delante del mostrador).
func _regresar(inscripcion: Dictionary) -> void:
	var jugador: Node = admin.get("jugador")
	var admin_actual: Node = admin
	SalaConcurso.inscripcion = {}
	terminar(true, [])
	if jugador != null:
		jugador.visible = true
		jugador.end_dialog()
		jugador.no_control = true
	var celda: Vector2i = inscripcion.get("celda_regreso", Vector2i(5, 4))
	admin_actual.conectar_escalera(str(inscripcion.get("vestibulo", "")), Vector2(celda), Vector2.DOWN)


func _jugar_apelaciones(lista: Array[ConcursanteConcurso], categoria: int, nivel: int,
		aleatorio: AleatorioConcurso) -> MotorConcurso:
	if jugar_apelaciones.is_valid():
		return await jugar_apelaciones.call(lista, categoria, nivel, aleatorio)
	var solo_apelaciones := func(capa: ConcursoCompleto) -> void:
		capa.fases = ConcursoCompleto.Fases.APELACIONES
	return await ConcursoCompleto.jugar(self, lista, categoria, nivel, aleatorio, solo_apelaciones)


func _mostrar_resultados(motor: MotorConcurso) -> void:
	if mostrar_resultados.is_valid():
		await mostrar_resultados.call(motor)
		return
	await ConcursoCompleto.mostrar_resultados(self, motor)


## ShowContestEntryMonPic / sub_80C5164: ventana con el POKéMON de frente.
func _mostrar_ventana(c: ConcursanteConcurso) -> void:
	_cerrar_ventana()
	_ventana = VENTANA_ENTRADA.instantiate()
	add_child(_ventana)
	_ventana.mostrar(c)


func _cerrar_ventana() -> void:
	if is_instance_valid(_ventana):
		_ventana.queue_free()
	_ventana = null


## message + waitmessage: el texto se escribe y el guion sigue sin esperar el botón.
func _mostrar_sin_espera(texto: String) -> void:
	var listo := [false]
	admin.cuadro_dialogo.mostrar(texto, false, false, func() -> void: listo[0] = true)
	while not listo[0]:
		await get_tree().process_frame


func _mensaje_sin_espera(clave: String) -> void:
	await _mostrar_sin_espera(tr(clave))


func _sonar(clave: String) -> void:
	TiempoConcurso.sonar(self, clave)
