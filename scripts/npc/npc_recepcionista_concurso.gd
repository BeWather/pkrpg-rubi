@tool
## npc_recepcionista_concurso.gd
## Mesas de recepción de las SALAS de CONCURSOS (pokeruby `*_ContestLobby`, objeto 1,
## TEALA): PUEBLO VERDEGAL (NORMAL), PUEBLO PARDAL (ALTO), CIUDAD PORTUAL (AVANZADO) y
## CIUDAD CALAGUA (EXPERTO, que tiene además la mesa por cable).
##
## - **INDIVIDUAL**: la recepción común de `data/scripts/contest_hall.inc:1-181`
##   (`EventScript_1A4E92`): premio pendiente, saludo con el nivel, PASE de CONCURSO
##   (solo se expide en NORMAL; en los demás niveles remite a VERDEGAL), menú
##   ENTRAR / INFO. / SALIR, categoría, elección del POKéMON
##   (`CanMonParticipateInContest`), confirmación y warp a la sala
##   (escenas/mapas/sala-concurso/sala_concurso.tscn), donde EventoSalaConcurso dirige
##   el concurso (`contest_hall.inc:183-1150`) y devuelve al jugador al vestíbulo.
## - **CABLE** (Calagua, objeto 2): la mesa de inscripción por cable de cuatro
##   jugadores (`LinkContestReceptionist`). La transmisión por cable no existe, así que
##   el hilo acaba con «Esperamos que participes en alguna otra ocasión.».
##
## Bloqueo del jugador y diálogo: patrón de npc_dialogo_condicional.gd.
extends "res://scripts/npc/npc_dialogo_condicional.gd"

## ITEM_CONTEST_PASS (PASE CONCURSO).
const OBJETO_PASE: String = "PASECONCURSO"
## FLAG_RECEIVED_CONTEST_PASS.
const BANDERA_PASE_RECIBIDO: String = "verdegal_pase_concurso_recibido"
## FLAG_TEMP_1 del vestíbulo: ya saludó en esta visita.
const BANDERA_SALUDO: String = "concurso_recepcion_saludo"
## Common_EventScript_ShowBagIsFull.
const TEXTO_MOCHILA_LENA: String = "MOCHILA_LLENA_REGALO"
const ESCENA_EQUIPO: String = "res://UI/equipo/pantalla-equipo.tscn"
## Movement_153E25 / LinkReceptionistApproachCounter: hasta la barra.
const PASOS_HASTA_BARRA: Array = [Vector2.LEFT]
const PASOS_HASTA_BARRA_EXPERTO: Array = [Vector2.LEFT, Vector2.LEFT]
## Movement_153E2C y 153E19: de delante del mostrador a la puerta de la sala.
const PASOS_A_PUERTA_EMPLEADA: Array = [Vector2.LEFT, Vector2.LEFT, Vector2.LEFT, Vector2.UP, Vector2.UP, Vector2.UP]
const PASOS_A_PUERTA_JUGADOR: Array = [Vector2.LEFT, Vector2.LEFT, Vector2.LEFT, Vector2.LEFT, Vector2.UP, Vector2.UP,
	Vector2.UP]
const FOTOGRAMAS_POR_SEGUNDO: float = 60.0
## delay 20 tras cerrar la barra y delay_8 antes de set_invisible.
const FOTOGRAMAS_TRAS_BARRA: float = 20.0
const FOTOGRAMAS_ANTES_DE_OCULTAR: float = 8.0

enum TipoRecepcion {
	## Mesa de inscripción individual.
	INDIVIDUAL,
	## Mesa de inscripción por cable (cuatro jugadores con Game Link).
	CABLE,
}

## Qué mesa es este NPC.
@export var tipo_recepcion: TipoRecepcion = TipoRecepcion.INDIVIDUAL
## VAR_CONTEST_RANK de este vestíbulo (0 NORMAL … 3 EXPERTO).
@export_enum("NORMAL", "ALTO", "AVANZADO", "EXPERTO") var nivel: int = 0
## Barra abatible del mostrador por la que sale la empleada (metatiles (4, 2) y (4, 3)).
@export var barra_mostrador: NodePath = ^"../../Tabla"
## Warp de la puerta (1, 1) a la que acompaña la empleada. Los pasos de guion no activan warps en
## Rubí: aquí se apaga durante el recorrido para que salte el warp a la sala, no este.
@export var puerta_sala: NodePath = ^"../../Warp2"

const TEXTO_SALUDO: String = "CONCURSO_RECEPCION_SALUDO"
const TEXTO_PASE_EN_VERDEGAL: String = "CONCURSO_RECEPCION_PASE_EN_VERDEGAL"
const TEXTO_OFRECE_PASE: String = "CONCURSO_RECEPCION_OFRECE_PASE"
const TEXTO_AQUI_LO_TIENES: String = "CONCURSO_RECEPCION_AQUI_LO_TIENES"
const TEXTO_YA_TIENE_PASE: String = "CONCURSO_RECEPCION_YA_TIENE_PASE"
const TEXTO_VUELVE: String = "CONCURSO_RECEPCION_VUELVE"
const TEXTO_QUIERES_INSCRIBIR: String = "CONCURSO_RECEPCION_QUIERES_INSCRIBIR"
const TEXTO_QUE_SABER: String = "CONCURSO_RECEPCION_QUE_SABER"
const TEXTOS_INFO: Array[String] = ["CONCURSO_RECEPCION_INFO_QUE_ES", "CONCURSO_RECEPCION_INFO_TIPOS",
	"CONCURSO_RECEPCION_INFO_NIVELES"]
const TEXTO_QUE_CONCURSO: String = "CONCURSO_RECEPCION_QUE_CONCURSO"
const TEXTO_ELEGIR_POKEMON: String = "CONCURSO_RECEPCION_ELEGIR_POKEMON"
const TEXTO_NO_CUALIFICADO: String = "CONCURSO_RECEPCION_NO_CUALIFICADO"
const TEXTO_HUEVO: String = "CONCURSO_RECEPCION_HUEVO"
const TEXTO_DEBILITADO: String = "CONCURSO_RECEPCION_DEBILITADO"
const TEXTO_YA_GANO: String = "CONCURSO_RECEPCION_YA_GANO"
const TEXTO_CONFIRMAR: String = "CONCURSO_RECEPCION_CONFIRMAR"
const TEXTO_INSCRITO: String = "CONCURSO_RECEPCION_INSCRITO"
const TEXTO_PASA: String = "CONCURSO_RECEPCION_PASA"
const TEXTO_PREMIO_GUARDADO: String = "CONCURSO_RECEPCION_PREMIO_GUARDADO"
const TEXTO_PREMIO_LUEGO: String = "CONCURSO_RECEPCION_PREMIO_LUEGO"

const TEXTO_CABLE_PREGUNTA: String = "CALAGUA_CONCURSO_CABLE_PREGUNTA"
const TEXTO_CABLE_SIN_PASE: String = "CALAGUA_CONCURSO_CABLE_SIN_PASE"
const TEXTO_CABLE_GUARDAR: String = "CALAGUA_CONCURSO_CABLE_GUARDAR"
const TEXTO_CABLE_EXPLICAR: String = "CALAGUA_CONCURSO_CABLE_EXPLICAR"
const TEXTO_CABLE_VUELVE: String = "CALAGUA_CONCURSO_CABLE_VUELVE"

## Sustitutos para tests: elegir del equipo (-> int, -1 = B) y el warp a la sala.
var selector_equipo: Callable = Callable()
var ir_a_sala: Callable = Callable()
## Semilla del sorteo de rivales (-1 = aleatoria).
var semilla_concurso: int = -1
## El jugador sigue bloqueado tras la conversación porque va a la sala.
var _control_transferido: bool = false

signal _equipo_cerrado


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
	if tipo_recepcion == TipoRecepcion.CABLE:
		await _guion_cable()
	else:
		await _guion_individual()
	nodo_administrador.cuadro_dialogo.cerrar()
	if _control_transferido:
		_control_transferido = false
		Singleton.mantener_pausa(MOTIVO_PAUSA, false)
	else:
		_bloquear_jugador(false)
	_volver_a_direccion_base()
	_secuencia_activa = false
	cambiar_estado(EstadoNPC.IDLE)


# === Recepción común (EventScript_1A4E92) ===

func _guion_individual() -> void:
	if not _tiene_pase():
		SistemaGuardado.set_flag_temporal(BANDERA_SALUDO, false)
	if not RegistroPremio.pendiente().is_empty():
		await _entregar_premio_pendiente()
		return
	if not SistemaGuardado.get_flag_temporal(BANDERA_SALUDO):
		await _mensaje(TEXTO_SALUDO)
		if not _tiene_pase() and not await _expedir_pase():
			return
		SistemaGuardado.set_flag_temporal(BANDERA_SALUDO)
	await _menu_principal()


## 1A4EE1: el PASE solo se expide en NORMAL. Devuelve true si el jugador puede seguir.
func _expedir_pase() -> bool:
	if nivel != 0:
		await _mensaje(TEXTO_PASE_EN_VERDEGAL)
		return false
	if not await _preguntar_si_no(TEXTO_OFRECE_PASE):
		await _mensaje(TEXTO_VUELVE)
		return false
	if SistemaGuardado.get_flag(BANDERA_PASE_RECIBIDO):
		await _mensaje(TEXTO_YA_TIENE_PASE)
		return false
	await _mensaje(TEXTO_AQUI_LO_TIENES)
	var resultado: Dictionary = SistemaGuardado.dar_objeto_jugador(OBJETO_PASE, 1)
	if not bool(resultado.get("exito", false)):
		await _mensaje(TEXTO_MOCHILA_LENA)
		return false
	SistemaGuardado.set_flag(BANDERA_PASE_RECIBIDO, true)
	await mostrar_objeto_recibido(OBJETO_PASE)
	await _mensaje(TEXTOS_INFO[0])  # ExplainContests
	return true


## 1A4F8F: multichoice 0, 0, 2 (ENTRAR, INFO., SALIR).
func _menu_principal() -> void:
	var opciones := PackedStringArray([tr("CONCURSO_MENU_INSCRIBIR"), tr("CONCURSO_MENU_INFORMACION"),
		tr("CONCURSO_MENU_SALIR")])
	while true:
		match await _elegir_opcion(TEXTO_QUIERES_INSCRIBIR, opciones, true):
			0:
				await _inscribir()
				return
			1:
				await _menu_informacion()
			_:
				await _mensaje(TEXTO_VUELVE)
				return


## multichoice 0, 0, 3: ¿Qué es CONCURSO?, tipos, niveles, SALIR.
func _menu_informacion() -> void:
	var opciones := PackedStringArray([tr("CONCURSO_MENU_QUE_ES"), tr("CONCURSO_MENU_TIPOS"),
		tr("CONCURSO_MENU_NIVELES"), tr("CONCURSO_MENU_SALIR")])
	while true:
		var eleccion: int = await _elegir_opcion(TEXTO_QUE_SABER, opciones, true)
		if eleccion >= TEXTOS_INFO.size():
			return
		await _mensaje(TEXTOS_INFO[eleccion])


## 1A5097 (multichoice 0, 0, 4: categoría) y 1A5048 (Pokémon). SALIR o B en la categoría terminan.
func _inscribir() -> void:
	var opciones := PackedStringArray()
	for categoria in 5:
		opciones.append(tr("CONCURSO_MENU_CATEGORIA_%d" % categoria))
	opciones.append(tr("CONCURSO_MENU_SALIR"))
	while true:
		var categoria: int = await _elegir_opcion(TEXTO_QUE_CONCURSO, opciones, true)
		if categoria >= 5:
			return
		while true:
			await _mensaje(TEXTO_ELEGIR_POKEMON)
			var indice: int = await _elegir_del_equipo(categoria)
			var equipo: Array = SistemaGuardado.get_equipo()
			if indice < 0 or indice >= equipo.size():
				break
			var pokemon: BasePokemon = equipo[indice]
			var resultado := InscripcionConcurso.puede_participar(pokemon, categoria, nivel)
			match resultado:
				InscripcionConcurso.Resultado.NO_CUMPLE:
					await _mensaje(TEXTO_NO_CUALIFICADO)
					continue
				InscripcionConcurso.Resultado.HUEVO:
					await _mensaje(TEXTO_HUEVO)
					continue
				InscripcionConcurso.Resultado.DEBILITADO:
					await _mensaje(TEXTO_DEBILITADO)
					continue
				InscripcionConcurso.Resultado.YA_TIENE_CINTA:
					if not await _preguntar_si_no(TEXTO_YA_GANO):
						continue
				_:
					if not await _preguntar_si_no(TEXTO_CONFIRMAR):
						continue
			await _mensaje(TEXTO_INSCRITO)
			nodo_administrador.cuadro_dialogo.cerrar()
			await _acompanar_a_la_puerta()
			await _ir_a_la_sala(pokemon, categoria, resultado == InscripcionConcurso.Resultado.YA_TIENE_CINTA)
			return


# === Paso a la sala (EventScript_153DA1 + warp a LinkContestRoom1) ===

## EventScript_153DA1 / LeadToLinkContestHall: la empleada sale por la barra y lleva al
## jugador hasta la puerta. En EXPERTO empieza una celda más a la derecha y el jugador
## se le acerca un paso.
func _acompanar_a_la_puerta() -> void:
	var barra: CanvasItem = get_node_or_null(barra_mostrador) as CanvasItem
	_activar_puerta(false)
	await _recorrer_empleada(PASOS_HASTA_BARRA_EXPERTO if nivel == SalaConcurso.NIVEL_EXPERTO else PASOS_HASTA_BARRA)
	update_direction(Vector2.DOWN)
	_mover_barra(barra, false)
	await _recorrer_empleada([Vector2.DOWN, Vector2.DOWN])
	update_direction(Vector2.UP)
	_mover_barra(barra, true)
	await get_tree().create_timer(FOTOGRAMAS_TRAS_BARRA / FOTOGRAMAS_POR_SEGUNDO).timeout
	update_direction(Vector2.RIGHT)
	if jugador != null:
		jugador.detener_movimientos(Vector2.LEFT)
		if nivel == SalaConcurso.NIVEL_EXPERTO:
			await jugador.caminar_guion(Vector2.LEFT)
	await _mensaje(TEXTO_PASA)
	nodo_administrador.cuadro_dialogo.cerrar()
	var pendientes := [2]
	var al_terminar := func(andar: Callable) -> void:
		await andar.call()
		pendientes[0] -= 1
	al_terminar.call(_recorrer_empleada.bind(PASOS_A_PUERTA_EMPLEADA))
	al_terminar.call(_llevar_jugador_a_la_puerta)
	while pendientes[0] > 0:
		await get_tree().process_frame
	await get_tree().create_timer(FOTOGRAMAS_ANTES_DE_OCULTAR / FOTOGRAMAS_POR_SEGUNDO).timeout
	visible = false  # set_invisible
	if jugador != null:
		jugador.visible = false


func _llevar_jugador_a_la_puerta() -> void:
	if jugador == null:
		return
	for direccion: Vector2 in PASOS_A_PUERTA_JUGADOR:
		await jugador.caminar_guion(direccion)


func _recorrer_empleada(direcciones: Array) -> void:
	for direccion: Vector2 in direcciones:
		mover_npc(direccion, true)
		while estado_actual == EstadoNPC.MOVING:
			await get_tree().process_frame
		cambiar_estado(EstadoNPC.INTERACTING)


## setmetatile + DrawWholeMapView: abre o cierra la barra con SE_BRIDGE_WALK.
func _mover_barra(barra: CanvasItem, cerrada: bool) -> void:
	Singleton.play_sound.emit("SE_BRIDGE_WALK")
	if barra != null:
		barra.visible = cerrada


func _activar_puerta(activa: bool) -> void:
	var puerta: Node = get_node_or_null(puerta_sala)
	if puerta != null:
		puerta.set_process(activa)


## Al volver del concurso la empleada ya está en su sitio tras el mostrador.
func _volver_tras_el_mostrador() -> void:
	_activar_puerta(true)
	EventoGuionizado.colocar(self, celda_origen)
	visible = true
	_volver_a_direccion_base()


## Inscribe al Pokémon (sortea los rivales) y lleva al jugador a la sala, donde
## EventoSalaConcurso dirige el concurso y lo devuelve al vestíbulo.
func _ir_a_la_sala(pokemon: BasePokemon, categoria: int, ya_tenia_cinta: bool) -> void:
	var aleatorio := AleatorioConcurso.new(semilla_concurso if semilla_concurso >= 0 else randi() & 0xFFFF)
	var mapa := _obtener_mapa_propio()
	var vestibulo: String = mapa.scene_file_path.get_file().get_basename() if mapa != null else ""
	SalaConcurso.inscribir(pokemon, categoria, nivel, ya_tenia_cinta, vestibulo, aleatorio,
		SistemaGuardado.get_nombre_jugador())
	_control_transferido = true
	if ir_a_sala.is_valid():
		ir_a_sala.call()
		_volver_tras_el_mostrador()
		return
	if mapa != null:
		mapa.mapa_activado.connect(func(_por_warp: bool) -> void: _volver_tras_el_mostrador(), CONNECT_ONE_SHOT)
	nodo_administrador.cuadro_dialogo.cerrar()
	var jugador_actual: Node = nodo_administrador.get("jugador")
	if jugador_actual != null:
		jugador_actual.end_dialog()
		jugador_actual.no_control = true
	nodo_administrador.conectar_escalera(SalaConcurso.MAPA_SALA, Vector2(SalaConcurso.CELDA_LLEGADA), Vector2.UP,
		false, true)


## contest_hall.inc:53-70 (VAR_CONTEST_PRIZE_PICKUP).
func _entregar_premio_pendiente() -> void:
	var objeto: String = RegistroPremio.pendiente()
	await _mensaje(TEXTO_PREMIO_GUARDADO)
	var resultado: Dictionary = SistemaGuardado.dar_objeto_jugador(objeto, 1)
	if bool(resultado.get("exito", false)):
		RegistroPremio.fijar("")
		await mostrar_objeto_recibido(objeto)
	else:
		await _mensaje(TEXTO_PREMIO_LUEGO)


## Premio pendiente del registro de concursos (VAR_CONTEST_PRIZE_PICKUP).
class RegistroPremio:
	static func pendiente() -> String:
		var registro: RegistroConcursos = SistemaGuardado.get_registro_concursos()
		return registro.premio_pendiente if registro != null else ""

	static func fijar(objeto: String) -> void:
		var registro: RegistroConcursos = SistemaGuardado.get_registro_concursos()
		if registro != null:
			registro.premio_pendiente = objeto


## choosecontestmon: menú del equipo (B = -1), con PUEDE / NO PUEDE según `categoria`
## (sub_80F9C00). Patrón de intercambio_npc.gd.
func _elegir_del_equipo(categoria: int) -> int:
	if selector_equipo.is_valid():
		return int(selector_equipo.call())
	var capa := get_tree().root.get_node_or_null("AdministradorMapa/Menu")
	if capa == null:
		return -1
	nodo_administrador.cuadro_dialogo.cerrar()
	await Singleton.transicion("oscurecer")
	var equipo := EquipoPokemon.new()
	for poke: BasePokemon in SistemaGuardado.get_equipo():
		equipo.agregar_pokemon(poke)
	var pantalla := (load(ESCENA_EQUIPO) as PackedScene).instantiate() as PantallaEquipoControlador
	capa.add_child(pantalla)
	var eleccion := {"indice": -1, "lista": false}
	pantalla.pokemon_elegido.connect(func(i: int) -> void:
		eleccion["indice"] = i
		eleccion["lista"] = true
		_equipo_cerrado.emit()
	, CONNECT_ONE_SHOT)
	pantalla.seleccion_cancelada.connect(func() -> void:
		eleccion["lista"] = true
		_equipo_cerrado.emit()
	, CONNECT_ONE_SHOT)
	pantalla.mostrar_equipo_modo(Singleton.ModoPEquipo.ELEGIR, equipo)
	var descriptores: Array[int] = []
	for poke: BasePokemon in equipo.pokemones:
		descriptores.append(InscripcionConcurso.descriptor_equipo(poke, categoria, nivel))
	pantalla.mostrar_descriptores(descriptores)
	await Singleton.transicion("aclarar")
	if not bool(eleccion["lista"]):
		await _equipo_cerrado
	pantalla.activo = false
	await Singleton.transicion("oscurecer")
	pantalla.ocultar_pantalla_equipo()
	pantalla.queue_free()
	await Singleton.transicion("aclarar")
	return int(eleccion["indice"])


# === Mesa por cable ===

## Pregunta, PASE de CONCURSO y explicación del Game Link.
func _guion_cable() -> void:
	if not await _preguntar_si_no(TEXTO_CABLE_PREGUNTA):
		await _mensaje(TEXTO_CABLE_VUELVE)
		return
	if not _tiene_pase():
		await _mensaje(TEXTO_CABLE_SIN_PASE)
		await _mensaje(TEXTO_CABLE_VUELVE)
		return
	await _mensaje(TEXTO_CABLE_GUARDAR)
	await _mensaje(TEXTO_CABLE_EXPLICAR)
	await _mensaje(TEXTO_CABLE_VUELVE)


## checkitem ITEM_CONTEST_PASS, 1.
func _tiene_pase() -> bool:
	var datos: Dictionary = SistemaGuardado.obtener_datos_objeto_completos(OBJETO_PASE)
	return SistemaGuardado.get_cantidad_objeto(OBJETO_PASE, int(datos.get("bolsillo_id", 0))) > 0


## Mensaje traducido con {nivel} del vestíbulo y los `valores` dados.
func _mensaje(clave: String, valores: Dictionary = {}) -> void:
	var texto: String = tr(clave).replace("{nivel}", tr("CONCURSO_NIVEL_%d" % nivel))
	for k in valores:
		texto = texto.replace("{%s}" % k, str(valores[k]))
	nodo_administrador.cuadro_dialogo.mostrar(texto, true, false, _mensaje_terminado.emit)
	await _mensaje_terminado
