## evento_rescate_abedul.gd
## Rescate del PROF. ABEDUL en la Ruta 101 (pokeruby data/maps/Route101/scripts.inc),
## que es donde Rubí entrega el POKéMON inicial.
##
## Estado de la ruta (VAR_ROUTE101_STATE) con banderas de SistemaGuardado:
##   0  primera entrada  (nada activo)
##   1  ya entraste      BANDERA_ENTRADA   (Route101_MapScript2_14E935)
##   2  oíste el socorro BANDERA_SOCORRO   (Route101_EventScript_14E948)
##   3  inicial elegido  BANDERA_INICIAL   (Route101_EventScript_14EA7F)
## `inicial_seleccionado` es la misma bandera que usa la `Bandolera` de Villa Raíz
## (demo): elegir el inicial en cualquiera de las dos da el estado 3 y deja la
## otra sin efecto.
##
## 1. Estado 1, al pisar (10,19) o (11,19) de Rubí: ¡Socorro!, el jugador sube 4
##    casillas corriendo mientras ABEDUL entra por la izquierda con POOCHYENA
##    persiguiéndole; dan vueltas, se miran y ABEDUL pide que cojas su POKé BALL.
## 2. Estado 2: ABEDUL no te deja marchar (empujón de una casilla si pisas
##    (10..11,18), (6,15..18) o (7,13) de Rubí).
## 3. Bolso de ABEDUL (7,14): pantalla negra, POOCHYENA se va, el jugador pasa a
##    (6,13) mirando a la izquierda, elige inicial, primer combate contra POOCHYENA
##    (nv. 2), ABEDUL da un paso y agradece, se cura el equipo y se viaja al
##    laboratorio (6,5).
##
## Coordenadas de Godot = Rubí + (8, 0): el mapa añade 8 columnas de bosque a cada
## lado. Pendiente (ver documentacion/20261001-eventos-ruta-101-pokeruby.md): las
## escenas del laboratorio (VAR_BIRCH_LAB_STATE) y ABEDUL con la POKéDEX (5,11).
extends EventoGuionizado
class_name EventoRescateAbedul

const PokemonInicial := preload("res://scripts/PokemonInicialOverworld.gd")
const ESCENA_SELECCION: PackedScene = preload("res://escenas/inicial/inicial.tscn")

const MOTIVO_PAUSA: StringName = &"rescate_abedul"
## Godot = Rubí + DESFASE.
const DESFASE := Vector2i(8, 0)

const BANDERA_ENTRADA: String = "ruta_101_entrada"
const BANDERA_SOCORRO: String = "ruta_101_socorro"
const BANDERA_INICIAL: String = "inicial_seleccionado"
## FLAG_RESCUED_BIRCH.
const BANDERA_RESCATADO: String = "abedul_rescatado"
const BANDERA_OCULTAR_CARTEL: String = "ocultar_cartel_lugar"

const TEXTO_SOCORRO: String = "RUTA101_SOCORRO"
const TEXTO_AYUDA: String = "RUTA101_AYUDA"
const TEXTO_NO_TE_VAYAS: String = "RUTA101_NO_TE_VAYAS"
const TEXTO_GRACIAS: String = "RUTA101_ABEDUL_GRACIAS"
const TEMA_SOCORRO: String = "AUXILIO"

## CB2_StartFirstBattle: CreateMon(SPECIES_POOCHYENA, 2) en gEnemyParty[0].
const ESPECIE_PRIMER_COMBATE: String = "POOCHYENA"
const NIVEL_PRIMER_COMBATE: int = 2

## ProfBirchs lab: warp 255, 6, 5 (el laboratorio es 13x13 como en Rubí).
const MAPA_LABORATORIO: String = "nodo_laboratorio"
const CELDA_LABORATORIO := Vector2(6, 5)

## Celdas (Rubí) de ABEDUL y POOCHYENA: por defecto, tras el guion, y de entrada.
const ABEDUL_INICIAL := Vector2i(9, 13)
const POOCHYENA_INICIAL := Vector2i(10, 13)
const ABEDUL_FINAL := Vector2i(4, 13)
const POOCHYENA_FINAL := Vector2i(5, 13)
const ABEDUL_ENTRADA := Vector2i(0, 15)
const POOCHYENA_ENTRADA := Vector2i(0, 16)
const BOLSO_CELDA := Vector2i(7, 14)
## setobjectxy LOCALID_PLAYER antes de elegir el inicial.
const JUGADOR_ELECCION := Vector2i(6, 13)

@export var abedul: NodePath
@export var poochyena: NodePath
@export var bolso: NodePath

## Sustituye al AdministradorMapa de la raíz del árbol (tests).
var administrador: Node = null
## Sustituye a la pantalla de elección de inicial (tests): sin argumentos, devuelve
## el Dictionary de `seleccion_hecha`.
var selector_inicial: Callable = Callable()
## Sustituye al primer combate (tests): recibe (especie, nivel, ubicación) y
## devuelve el ResultadoBatalla.Valor o -1 si no hubo combate.
var lanzador_primer_combate: Callable = Callable()

var _generacion_trote: int = 0


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	for hijo in get_children():
		if hijo is DisparadorEventoPorTiles:
			hijo.evento_activado.connect(_on_disparador)
	var objeto := _bolso()
	if objeto != null and objeto.has_signal("hablado"):
		objeto.hablado.connect(_on_bolso_hablado)
	var mapa := obtener_mapa()
	if mapa != null:
		mapa.mapa_activado.connect(func(_por_warp: bool) -> void: _on_mapa_activado())
	colocar_actores()


## Celda de Godot de una celda de Rubí.
static func celda_de(celda_rubi: Vector2i) -> Vector2i:
	return celda_rubi + DESFASE


## VAR_ROUTE101_STATE.
func estado() -> int:
	if SistemaGuardado.get_flag(BANDERA_INICIAL):
		return 3
	if SistemaGuardado.get_flag(BANDERA_SOCORRO):
		return 2
	if SistemaGuardado.get_flag(BANDERA_ENTRADA):
		return 1
	return 0


## Route101_MapScript2_14E935 (ON_FRAME con estado 0): la primera vez que entras
## se suprime el cartel del lugar y el estado pasa a 1.
func _on_mapa_activado() -> void:
	if _en_curso:
		return
	if estado() == 0:
		SistemaGuardado.set_flag(BANDERA_OCULTAR_CARTEL, true)
		SistemaGuardado.set_flag(BANDERA_ENTRADA, true)
	elif estado() == 3 and SistemaGuardado.get_flag(BANDERA_OCULTAR_CARTEL):
		# El inicial se eligió por otra vía (Bandolera de Villa Raíz) con el cartel suprimido.
		SistemaGuardado.set_flag(BANDERA_OCULTAR_CARTEL, false)
	colocar_actores()


## Los objetos vuelven a sus celdas al cargar el mapa. Hasta el estado 2 están
## ABEDUL, POOCHYENA y el bolso; con el inicial elegido (flags FLAG_HIDE_*) no. Con
## el estado 2 ABEDUL y POOCHYENA se quedan donde acaba el guion (en Rubí volverían a
## (9,13) y (10,13), lejos del bolso y de la celda del jugador).
func colocar_actores() -> void:
	if _en_curso:
		return
	_aplicar_colocacion()


func _aplicar_colocacion() -> void:
	var presentes := estado() < 3
	var tras_guion := estado() == 2
	_colocar(_abedul(), ABEDUL_FINAL if tras_guion else ABEDUL_INICIAL, presentes)
	_colocar(_poochyena(), POOCHYENA_FINAL if tras_guion else POOCHYENA_INICIAL, presentes)
	_colocar(_bolso(), BOLSO_CELDA, presentes)
	_iniciar_trote_ocioso()


func _colocar(npc: Node2D, celda_rubi: Vector2i, visible_: bool) -> void:
	if npc == null:
		return
	colocar(npc, celda_de(celda_rubi))
	npc.visible = visible_


## JOG_IN_PLACE_RIGHT (ABEDUL) y JOG_IN_PLACE_LEFT (POOCHYENA): trotan sin parar
## mientras no haya un guion en curso.
func _iniciar_trote_ocioso() -> void:
	_generacion_trote += 1
	_bucle_trote(_abedul(), Vector2.RIGHT, _generacion_trote)
	_bucle_trote(_poochyena(), Vector2.LEFT, _generacion_trote)


func _bucle_trote(npc: Node2D, direccion: Vector2, generacion: int) -> void:
	if npc == null:
		return
	while generacion == _generacion_trote and is_instance_valid(npc) and is_inside_tree():
		if npc.visible and not _en_curso:
			await trotar_en_sitio(npc, direccion, 1)
		else:
			await get_tree().process_frame


func _abedul() -> Node2D:
	return get_node_or_null(abedul) as Node2D


func _poochyena() -> Node2D:
	return get_node_or_null(poochyena) as Node2D


func _bolso() -> Node2D:
	return get_node_or_null(bolso) as Node2D


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


## ============================================================================
## COORD_EVENTS (disparadores de celda hijos de este nodo)
## ============================================================================

func _on_disparador(id_evento: StringName) -> void:
	match id_evento:
		&"socorro":
			_escena_socorro()
		&"empuja_arriba":
			_no_te_vayas(Vector2.UP)
		&"empuja_derecha":
			_no_te_vayas(Vector2.RIGHT)
		&"empuja_abajo":
			_no_te_vayas(Vector2.DOWN)


## Route101_EventScript_14E948: estado 1 → 2.
func _escena_socorro() -> void:
	if _en_curso or estado() != 1:
		return
	if not comenzar(_administrador()):
		return
	var profesor := _abedul()
	var perro := _poochyena()
	reproducir_musica(TEMA_SOCORRO)
	await mensaje(TEXTO_SOCORRO)
	admin.cuadro_dialogo.cerrar()  # closemessage
	if profesor == null or perro == null:
		push_warning("[RESCATE_ABEDUL] Faltan ABEDUL o POOCHYENA en el mapa")
		SistemaGuardado.set_flag(BANDERA_SOCORRO, true)
		terminar()
		return
	_colocar(profesor, ABEDUL_ENTRADA, true)
	_colocar(perro, POOCHYENA_ENTRADA, true)

	# Entran corriendo: el jugador sube 4, ABEDUL → ×4 ↑×2, POOCHYENA ↑ →×4 ↑.
	await en_paralelo([
		recorrer_jugador.bind(_pasos([[Vector2.UP, 4]]), VelocidadPaso.RAPIDO),
		recorrer.bind(profesor, _pasos([[Vector2.RIGHT, 4], [Vector2.UP, 2]]), VelocidadPaso.RAPIDO),
		recorrer.bind(perro, _pasos([[Vector2.UP, 1], [Vector2.RIGHT, 4], [Vector2.UP, 1]]), VelocidadPaso.RAPIDO),
	])
	# Dan vueltas: ABEDUL 3 × (↑2 →3 ↓2 ←3); POOCHYENA ↑3 →3 ↓2 ←3, ↑2 →3 ↓2 ←3, ↑2 →3 ↓2 ←2.
	var vuelta_abedul: Array = _pasos([[Vector2.UP, 2], [Vector2.RIGHT, 3], [Vector2.DOWN, 2], [Vector2.LEFT, 3]])
	var vuelta_perro: Array = _pasos([
		[Vector2.UP, 3], [Vector2.RIGHT, 3], [Vector2.DOWN, 2], [Vector2.LEFT, 3],
		[Vector2.UP, 2], [Vector2.RIGHT, 3], [Vector2.DOWN, 2], [Vector2.LEFT, 3],
		[Vector2.UP, 2], [Vector2.RIGHT, 3], [Vector2.DOWN, 2], [Vector2.LEFT, 2],
	])
	await en_paralelo([
		recorrer.bind(perro, vuelta_perro, VelocidadPaso.RAPIDO),
		recorrer.bind(profesor, vuelta_abedul + vuelta_abedul + vuelta_abedul, VelocidadPaso.RAPIDO),
	])
	mirar(profesor, Vector2.RIGHT)  # Common_Movement_WalkInPlaceFastestRight
	await esperar_fotogramas(4)
	# Se miran: POOCHYENA ←, ABEDUL → (4 pasos en el sitio, rápidos).
	await en_paralelo([
		trotar_en_sitio.bind(perro, Vector2.LEFT, 4),
		trotar_en_sitio.bind(profesor, Vector2.RIGHT, 4),
	])
	await mensaje(TEXTO_AYUDA)
	admin.cuadro_dialogo.cerrar()
	SistemaGuardado.set_flag(BANDERA_SOCORRO, true)
	terminar(false, [profesor, perro])


## Route101_EventScript_14E9B8 / 14E9CE / 14E9E4: estado 2, el jugador se aleja.
func _no_te_vayas(direccion: Vector2) -> void:
	if _en_curso or estado() != 2:
		return
	if not comenzar(_administrador()):
		return
	await mensaje(TEXTO_NO_TE_VAYAS)
	admin.cuadro_dialogo.cerrar()
	await recorrer_jugador([direccion])
	terminar()


## ============================================================================
## BOLSO DE ABEDUL (Route101_EventScript_14EA7F)
## ============================================================================

func _on_bolso_hablado(npc: Node2D) -> void:
	if _en_curso or estado() == 3:
		return
	if not comenzar(npc.nodo_administrador):
		if npc.jugador and npc.jugador.has_method("esperar_dialogo"):
			npc.jugador.esperar_dialogo(false)
		return
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	var profesor := _abedul()
	var perro := _poochyena()
	SistemaGuardado.set_flag(BANDERA_RESCATADO, true)  # FLAG_SYS_POKEMON_GET + FLAG_RESCUED_BIRCH

	await oscurecer_pantalla()
	if perro != null:
		perro.visible = false  # removeobject 4
	colocar_jugador(celda_de(JUGADOR_ELECCION), Vector2.LEFT)
	var elegido: Dictionary = await _elegir_inicial()
	var especie: String = str(elegido.get("nombre_interno", ""))
	var seccion: String = ""
	if admin.has_method("obtener_seccion_lugar_actual"):
		seccion = str(admin.obtener_seccion_lugar_actual())
	var entregado := PokemonInicial.entregar_inicial(especie, seccion)
	if entregado:
		# El laboratorio y el rival se basan en este registro: debe apuntar al
		# Pokémon recién entregado, esté donde esté en el equipo.
		var registrado := SistemaGuardado.get_pokemon_inicial()
		if registrado == null or registrado != SistemaGuardado.get_equipo().back():
			push_warning("[RESCATE_ABEDUL] El inicial '%s' no quedó registrado" % especie)
		if admin.has_method("actualizar_opciones_menu"):
			admin.actualizar_opciones_menu()
	else:
		push_warning("[RESCATE_ABEDUL] No se pudo entregar el inicial '%s'" % especie)
	# CB2_StartFirstBattle → CB2_EndFirstBattle: gane, pierda o huya POOCHYENA, el
	# guion sigue (sin volver al punto de curación) con la música del mapa.
	if entregado:
		await _primer_combate(seccion)
	await aclarar_pantalla()

	if profesor != null:
		await caminar(profesor, Vector2.RIGHT)
	await mensaje(TEXTO_GRACIAS)
	SistemaGuardado.curar_equipo_completo()  # special ScrSpecial_HealPlayerParty
	SistemaGuardado.set_flag(BANDERA_INICIAL, true)  # VAR_ROUTE101_STATE = 3
	SistemaGuardado.set_flag(BANDERA_OCULTAR_CARTEL, false)  # clearflag FLAG_HIDE_MAP_NAME_POPUP
	_ir_al_laboratorio([profesor])


## special ScrSpecial_ChooseStarter + waitstate.
func _elegir_inicial() -> Dictionary:
	if selector_inicial.is_valid():
		return await selector_inicial.call()
	var menu: Node = admin.get_node_or_null("Menu")
	if menu == null:
		push_warning("[RESCATE_ABEDUL] No se encontró el nodo Menu del administrador")
		return {}
	Singleton.mantener_pausa(&"pokemon_inicial", true)
	var seleccion: Node = ESCENA_SELECCION.instantiate()
	seleccion.set_iniciales(SistemaGuardado.INICIALES)
	menu.add_child(seleccion)
	var elegido: Dictionary = await seleccion.seleccion_hecha
	await oscurecer_pantalla()  # la elección funde a negro antes de CB2_GiveStarter
	seleccion.queue_free()
	Singleton.mantener_pausa(&"pokemon_inicial", false)
	return elegido


## BATTLE_TYPE_FIRST_BATTLE contra POOCHYENA nv. 2. La pantalla viene en negro
## de la elección (el combate empieza sin transición, como BattleTransition_Start
## sobre la pantalla fundida) y vuelve en negro: el guion aclara después.
func _primer_combate(seccion: String) -> int:
	if lanzador_primer_combate.is_valid():
		return int(await lanzador_primer_combate.call(ESPECIE_PRIMER_COMBATE, NIVEL_PRIMER_COMBATE, seccion))
	var manager := admin.get("battle_manager") as OverworldBattleManager
	if manager == null:
		push_warning("[RESCATE_ABEDUL] Sin OverworldBattleManager: no hay primer combate")
		return -1
	var opciones := OpcionesBatallaOverworld.para_salvaje()
	opciones.secuencia_transicion = PackedStringArray(["ninguna"])
	var ejecucion: ResultadoEjecucionBatalla = await manager.combatir_primer_salvaje(
		ESPECIE_PRIMER_COMBATE, NIVEL_PRIMER_COMBATE, seccion, opciones)
	if ejecucion.fue_rechazada():
		push_warning("[RESCATE_ABEDUL] Primer combate rechazado: %s" % ejecucion.codigo_error)
		return -1
	return int(ejecucion.resultado)


## warp MAP_LITTLEROOT_TOWN_PROFESSOR_BIRCHS_LAB, 255, 6, 5. Los objetos de la ruta
## ya están ocultos (FLAG_HIDE_*) cuando se vuelva a entrar.
func _ir_al_laboratorio(npcs: Array) -> void:
	var jugador: Node = admin.jugador
	var admin_actual: Node = admin
	_aplicar_colocacion()  # con el estado 3, ABEDUL, POOCHYENA y el bolso dejan de estar
	terminar(true, npcs)  # solo suelta la pausa del guion: el warp conserva el control
	jugador.end_dialog()
	jugador.no_control = true
	admin_actual.conectar_escalera(MAPA_LABORATORIO, CELDA_LABORATORIO, Vector2.UP)


## [[dirección, veces], …] → lista plana de pasos.
static func _pasos(tramos: Array) -> Array:
	var lista: Array = []
	for tramo in tramos:
		for i in int(tramo[1]):
			lista.append(tramo[0])
	return lista
