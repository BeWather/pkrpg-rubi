@tool
## npc_reportero_concurso.gd
## REPORTERO de los vestíbulos de CONCURSOS (pokeruby FallarborTown_ContestLobby_EventScript_
## Reporter, el mismo en PARDAL, VERDEGAL, PORTUAL y CALAGUA: lock + faceplayer). Solo está
## al volver de un CONCURSO con sitio en la cola de la TV (ProgramasTV.al_cambiar_de_mapa
## pone su `bandera_mostrar`). Orden del guion:
## 1. Ya entrevistado en esta visita (FLAG_TEMP_2) o sin sitio (InterviewBefore == 1):
##    «Estoy deseando que participes en otro CONCURSO POKéMON».
## 2. «¿Podría hacerte unas preguntas?» SÍ/NO; NO → «si te encuentras con una buena historia…».
## 3. SÍ → «¿Podrías describirme el CONCURSO…?» y PALABRAS FÁCILES de una palabra
##    (VAR_0x8004 = 11); después «Cuando oyes la palabra “{categoria}”…» y otra palabra;
##    cancelar cualquiera de las dos → «si te encuentras con una buena historia…».
## 4. Con las dos: «Así que imaginas el concepto de “{categoria}” así…», FLAG_TEMP_2 y la
##    entrevista va a la cola de la TV (InterviewAfter → ProgramasTV.grabar_entrenador_estrella:
##    ENTRENADOR ESTRELLA).
## {categoria} es la del CONCURSO (SetContestCategoryStringVarForInterview). El texto de «Estoy
## deseando…» es `id_texto` (cada vestíbulo tiene su clave).
## Bloqueo del jugador y diálogo: patrón de npc_reportero_museo.gd.
extends "res://scripts/npc/npc_dialogo_condicional.gd"

const TEXTO_INVITA: String = "CONCURSO_REPORTERO_INVITA"
const TEXTO_ACEPTA: String = "CONCURSO_REPORTERO_ACEPTA"
const TEXTO_PREGUNTA: String = "CONCURSO_REPORTERO_PREGUNTA"
const TEXTO_GRACIAS: String = "CONCURSO_REPORTERO_GRACIAS"
const TEXTO_RECHAZA: String = "CONCURSO_REPORTERO_RECHAZA"

## FLAG_TEMP_2: ya entrevistado en esta visita al vestíbulo.
const TEMPORAL_ENTREVISTADO: String = "concurso_reportero_entrevistado"

## Sustituye a la pantalla de PALABRAS FÁCILES (tests): recibe el modo y devuelve las
## palabras aceptadas ([] = cancelada).
var editor_palabras: Callable = Callable()


func _procesar_interaccion() -> void:
	interrupcion_pendiente = false
	if _secuencia_activa:
		return
	if nodo_administrador == null or nodo_administrador.cuadro_dialogo == null:
		if jugador and jugador.has_method("esperar_dialogo"):
			jugador.esperar_dialogo(false)
		cambiar_estado(EstadoNPC.IDLE)
		return
	_conversar()


func _conversar() -> void:
	_secuencia_activa = true
	cambiar_estado(EstadoNPC.INTERACTING)
	mirar_jugador()  # faceplayer
	_bloquear_jugador(true)
	await _guion()
	nodo_administrador.cuadro_dialogo.cerrar()
	_bloquear_jugador(false)
	_volver_a_direccion_base()
	_secuencia_activa = false
	cambiar_estado(EstadoNPC.IDLE)


func _guion() -> void:
	var hueco := -1
	if not SistemaGuardado.get_flag_temporal(TEMPORAL_ENTREVISTADO):
		hueco = ProgramasTV.antes_de_entrevista(ProgramasTV.Tipo.ENTRENADOR_ESTRELLA)
	if hueco < 0:
		await _mensaje(id_texto)  # 1AE17E
		return
	if not await _preguntar_si_no(TEXTO_INVITA):
		await _mensaje(TEXTO_RECHAZA)  # 1AE12D
		return
	await _mensaje(TEXTO_ACEPTA)
	var primera := await _chat_facil()
	if primera.is_empty():
		await _mensaje(TEXTO_RECHAZA)
		return
	var categoria := {"{categoria}": ProgramasTV.categoria_concurso_pendiente()}
	await _mensaje(TEXTO_PREGUNTA, categoria)
	var segunda := await _chat_facil()
	if segunda.is_empty():
		await _mensaje(TEXTO_RECHAZA)
		return
	await _mensaje(TEXTO_GRACIAS, categoria)
	SistemaGuardado.set_flag_temporal(TEMPORAL_ENTREVISTADO, true)
	ProgramasTV.grabar_entrenador_estrella(hueco, [primera[0], segunda[0]])  # InterviewAfter


## Common_EventScript_ShowEasyChatScreen (VAR_0x8004 = 11) y, al volver, lock + faceplayer.
func _chat_facil() -> Array[int]:
	nodo_administrador.cuadro_dialogo.cerrar()
	var palabras: Array[int] = []
	if editor_palabras.is_valid():
		palabras.assign(await editor_palabras.call(PantallaPalabrasFaciles.Modo.ENTREVISTA))
	else:
		palabras = await PantallaPalabrasFaciles.escribir(self, PantallaPalabrasFaciles.Modo.ENTREVISTA)
	mirar_jugador()
	return palabras


## Cada mensaje en un cuadro nuevo: tras SÍ/NO o tras la pantalla de PALABRAS FÁCILES.
func _mensaje(clave: String, sustituciones: Dictionary = {}) -> void:
	var texto: String = tr(clave)
	for marca in sustituciones:
		texto = texto.replace(str(marca), str(sustituciones[marca]))
	nodo_administrador.cuadro_dialogo.cerrar()
	nodo_administrador.cuadro_dialogo.mostrar(texto, true, false, _mensaje_terminado.emit)
	await _mensaje_terminado
