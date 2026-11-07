## evento_casa_treta_prueba5.gd
## Acertijo 5 de la CASA TRETA (Route110_TrickHousePuzzle5): cinco MECAÑECOS (el mismo
## sprite que el MAESTRO) en un pasillo que preguntan un acertijo cada uno.
##
## Activación (por disparador o hablándole), `MechadollNActivate`: VAR_TEMP_n = 1,
## VAR_TEMP_8 = n, SE_PIN, «!», 48 fotogramas, el MECAÑECO anda hacia el jugador tantos
## pasos como indica el disparador pisado (0 al hablarle), presentación, y una de sus tres
## preguntas elegida con `random 3`. Acierto: SE_SUCCESS y «ENHORABUENA...» (el mismo
## texto en los cinco: `Text_CorrectGoThrough1`); desde entonces hablarle da solo ese
## texto y sus disparadores no se vuelven a activar. Fallo: SE_FAILURE, «BZZZZZZ...», los
## cinco se sacuden, «¡JUA, JUA...!», «NOSOTROS ESPERAR SIGUIENTE RETO...» y warp a
## (0,21) del mismo mapa (se recarga la escena: vuelve a empezar, VAR_TEMP = 0).
##
## Aleatorio inyectable: `sorteo` recibe el número de preguntas (3) y devuelve 0..n-1;
## por defecto usa `rng` (RandomNumberGenerator con semilla aleatoria). Los tests fijan
## `sorteo` o `rng.seed`.
##
## `multichoice 0, 0, N, 1` de Rubí (el último argumento 1 = sin cancelar): el cuadro de
## diálogo del proyecto cancela con B eligiendo la última opción; no hay modo de impedirlo
## sin tocar UI/cuadro_dialogo.gd, así que B equivale a responder la última (como en los
## demás multichoice del proyecto, `elegir_opcion`).
extends "res://scripts/eventos/ruta_110/evento_casa_treta_prueba.gd"
class_name EventoCasaTretaPrueba5

const MECANECOS: int = 5
const PREGUNTAS_POR_MECANECO: int = 3
const PLANTILLA_ID: String = "meca%d_t%d"
const ESCENA_PRUEBA: String = "ruta_110_casa_treta_prueba5"
## Llegada al reiniciar: (0,21), mirando al sur.
const LLEGADA: Vector2 = Vector2(0, 21)

## SE_SUCCESS (031) y SE_FAILURE (032) existen en `Singleton.se`.
const SONIDO_ACIERTO: String = "SE_SUCCESS"
const SONIDO_FALLO: String = "SE_FAILURE"

const PLANTILLA_TEXTO_INTRO: String = "CASA_TRETA_P5_MECA%d_INTRO"
const PLANTILLA_TEXTO_PREGUNTA: String = "CASA_TRETA_P5_MECA%d_Q%d"
const TEXTO_CORRECTO: String = "CASA_TRETA_P5_MECA1_CORRECTO"
const TEXTO_ERROR: String = "CASA_TRETA_P5_ERROR"
const TEXTO_RISA: String = "CASA_TRETA_P5_RISA"
const TEXTO_ESPERAR: String = "CASA_TRETA_P5_ESPERAR"

## Sentido en que cada MECAÑECO (índice n-1) anda hacia el jugador y pasos máximos
## (= disparadores de la escena menos uno: el disparador K da K pasos).
const DIRECCIONES: Array[Vector2] = [
	Vector2.LEFT, Vector2.RIGHT, Vector2.LEFT, Vector2.LEFT, Vector2.RIGHT,
]
const PASOS_MAXIMOS: Array[int] = [3, 1, 2, 1, 2]

## Preguntas (pregunta -> opciones y la correcta). Las opciones que empiezan por
## `CASA_TRETA_` son claves de `dialogos.csv`; el resto son nombres propios o cifras.
## Orden de Rubí (`MultichoiceList_25..39`); índices correctos del decomp:
## Q1: 1,0,1; Q2: 2,0,0; Q3: 1,2,1; Q4: 1,0,1; Q5: 1,0,2.
const PREGUNTAS: Array = [
	[  # MECAÑECO 1
		{"opciones": ["ZIGZAGOON", "NINCADA", "POOCHYENA"], "correcta": 1},
		{"opciones": ["NINCADA", "LOTAD", "ROSELIA"], "correcta": 0},
		{"opciones": ["SHROOMISH", "NINCADA", "SURSKIT"], "correcta": 1},
	],
	[  # MECAÑECO 2
		{"opciones": ["TREECKO", "TORCHIC", "MUDKIP"], "correcta": 2},
		{"opciones": ["SEEDOT", "SHROOMISH", "SPINDA"], "correcta": 0},
		{"opciones": ["SHROOMISH", "ZIGZAGOON", "WURMPLE"], "correcta": 0},
	],
	[  # MECAÑECO 3
		{"opciones": ["CASA_TRETA_P5_OPC_POKE_BALLS", "SUPERPOCIÓN", "CASA_TRETA_P5_OPC_IGUAL"], "correcta": 1},
		{"opciones": ["$135", "$155", "$175"], "correcta": 2},
		{"opciones": ["CASA_TRETA_P5_OPC_MAS", "CASA_TRETA_P5_OPC_MENOS", "CASA_TRETA_P5_OPC_IGUAL"], "correcta": 1},
	],
	[  # MECAÑECO 4
		{"opciones": ["♂", "♀", "CASA_TRETA_P5_OPC_NI_IDEA"], "correcta": 1},
		{"opciones": ["CASA_TRETA_P5_OPC_MAS_HOMBRES", "CASA_TRETA_P5_OPC_MAS_MUJERES", "CASA_TRETA_P5_OPC_MISMO_NUMERO"], "correcta": 0},
		{"opciones": ["CASA_TRETA_P5_OPC_HOMBRE", "CASA_TRETA_P5_OPC_MUJER", "CASA_TRETA_P5_OPC_CUALQUIERA"], "correcta": 1},
	],
	[  # MECAÑECO 5
		{"opciones": ["6", "8", "10"], "correcta": 1},
		{"opciones": ["1", "2", "3"], "correcta": 0},
		{"opciones": ["6", "7", "8"], "correcta": 2},
	],
]

## Los cinco MECAÑECOS (NPCs `npc_evento`) en orden 1..5.
@export var mecanecos: Array[NodePath] = []

## Elige la pregunta: recibe el número de preguntas y devuelve 0..n-1. Vacío = `rng`.
var sorteo: Callable = Callable()
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## VAR_TEMP_1..5 (índice 0..4): MECAÑECO ya activado.
var _activados: Array[bool] = [false, false, false, false, false]
## VAR_TEMP_8: último MECAÑECO activado (1..5).
var ultimo_mecaneco: int = 0
## Pregunta elegida en cada activación, para los tests (índice 0..2 por MECAÑECO).
var preguntas_elegidas: Array[int] = [-1, -1, -1, -1, -1]
## Respuestas incorrectas desde que se cargó la escena (reinicios), para los tests.
var reinicios: int = 0


func _init() -> void:
	rng.randomize()


func _preparar() -> void:
	for indice in mecanecos.size():
		var npc := get_node_or_null(mecanecos[indice])
		if npc != null and npc.has_signal("hablado"):
			npc.hablado.connect(_on_mecaneco_hablado.bind(indice + 1))


func _on_disparador(id_evento: StringName) -> void:
	for numero in range(1, MECANECOS + 1):
		for pasos in PASOS_MAXIMOS[numero - 1] + 1:
			if id_evento == StringName(PLANTILLA_ID % [numero, pasos]):
				await activar_mecaneco(numero, pasos)
				return


func _mecaneco(numero: int) -> Node2D:
	if numero < 1 or numero > mecanecos.size():
		return null
	return get_node_or_null(mecanecos[numero - 1]) as Node2D


func esta_activado(numero: int) -> bool:
	return numero >= 1 and numero <= MECANECOS and _activados[numero - 1]


## Hablar con un MECAÑECO (`MechadollN`: FacePlayer; si VAR_TEMP_n == 1, solo el
## «ENHORABUENA»; si no, activación sin pasos).
func _on_mecaneco_hablado(npc: Node2D, numero: int) -> void:
	if _en_curso:
		if is_instance_valid(npc) and npc.get("jugador") != null and npc.jugador.has_method("esperar_dialogo"):
			npc.jugador.esperar_dialogo(false)
		return
	await hablar_con_mecaneco(numero)


func hablar_con_mecaneco(numero: int) -> void:
	var npc := _mecaneco(numero)
	if npc == null or not comenzar(_administrador()):
		return
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	npc.mirar_jugador()
	if _activados[numero - 1]:
		await mensaje(TEXTO_CORRECTO)  # CorrectGoThrough
		terminar(false, [npc])
		return
	await _activar(numero, 0, npc)


## Disparador del suelo: `MechadollNTriggerK` (K = pasos).
func activar_mecaneco(numero: int, pasos: int) -> void:
	var npc := _mecaneco(numero)
	if npc == null or numero < 1 or numero > MECANECOS or _activados[numero - 1] or _en_curso:
		return
	if not comenzar(_administrador()):
		return
	await _activar(numero, pasos, npc)


## `MechadollNActivate` (con el guion ya iniciado).
func _activar(numero: int, pasos: int, npc: Node2D) -> void:
	_activados[numero - 1] = true
	ultimo_mecaneco = numero
	_sonido(SONIDO_PIN)
	if con_esperas:
		await exclamacion(npc)
	await esperar_fotogramas(48)  # Common_Movement_Delay48
	if con_esperas and pasos > 0:
		await recorrer(npc, _pasos_hacia_jugador(numero, pasos))
	await mensaje(PLANTILLA_TEXTO_INTRO % numero)
	var pregunta := _elegir_pregunta()
	preguntas_elegidas[numero - 1] = pregunta
	var datos: Dictionary = PREGUNTAS[numero - 1][pregunta]
	var opciones := PackedStringArray()
	for opcion: String in datos["opciones"]:
		opciones.append(tr(opcion) if opcion.begins_with("CASA_TRETA_") else opcion)
	var elegida := await elegir_opcion(PLANTILLA_TEXTO_PREGUNTA % [numero, pregunta + 1], opciones)
	if elegida == int(datos["correcta"]):
		_sonido(SONIDO_ACIERTO)
		await mensaje(TEXTO_CORRECTO)
		terminar(false, [npc])
	else:
		await _fallar()


func _pasos_hacia_jugador(numero: int, pasos: int) -> Array:
	var lista: Array = []
	for _i in pasos:
		lista.append(DIRECCIONES[numero - 1])
	return lista


## `random 3`.
func _elegir_pregunta() -> int:
	if sorteo.is_valid():
		return clampi(int(sorteo.call(PREGUNTAS_POR_MECANECO)), 0, PREGUNTAS_POR_MECANECO - 1)
	return rng.randi_range(0, PREGUNTAS_POR_MECANECO - 1)


## `IncorrectAnswer`: SE_FAILURE, «BZZZ», sacudida de los cinco, risa, «esperar siguiente
## reto» y vuelta a (0,21).
func _fallar() -> void:
	_sonido(SONIDO_FALLO)
	await mensaje(TEXTO_ERROR)
	var sacudidas: Array[Callable] = []
	for numero in range(1, MECANECOS + 1):
		var npc := _mecaneco(numero)
		if npc != null:
			sacudidas.append(_sacudir.bind(npc))
	if con_esperas:
		await en_paralelo(sacudidas)
	await mensaje(TEXTO_RISA, false)
	await mensaje(TEXTO_ESPERAR)
	admin.cuadro_dialogo.cerrar()
	reinicios += 1
	var adm := admin
	terminar()
	adm.conectar_escalera(ESCENA_PRUEBA, LLEGADA, Vector2.DOWN)


## Route110_TrickHousePuzzle5_Movement_MechadollShake: izquierda/derecha con delay_2.
func _sacudir(npc: Node2D) -> void:
	for i in 16:
		if not is_instance_valid(npc):
			return
		mirar(npc, Vector2.LEFT if i % 2 == 0 else Vector2.RIGHT)
		await esperar_fotogramas(2)


## multichoice: índice de la opción elegida (cancelar = la última). Con más de dos
## opciones el menú responde el índice. Es la quinta copia de este patrón en el proyecto
## (EventoEscuelaFerrica, EventoBarcaArenque, EventoPuebloAzuliza…): no está en la base
## porque dos de ellas lo declaran con otra firma.
func elegir_opcion(clave: String, opciones: PackedStringArray) -> int:
	var dialogo: NinePatchRect = admin.cuadro_dialogo
	dialogo.cerrar()
	dialogo.preguntaSiNo(tr(clave), opciones)
	while true:
		var datos: Array = await dialogo.comando_ejecutado
		if datos.size() >= 2 and str(datos[0]) == "respuesta_confirmacion":
			var parametros: Array = datos[1]
			var respuesta := str(parametros[0]) if not parametros.is_empty() else "N"
			if respuesta == "Y":
				return 0
			if respuesta.is_valid_int():
				return clampi(int(respuesta), 0, opciones.size() - 1)
			return opciones.size() - 1
	return opciones.size() - 1
