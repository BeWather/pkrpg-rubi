extends AprendizajeMovimientos
class_name EnsenanzaMaquina

## Enseñar una MT/MO de la mochila a un Pokémon del equipo (`Task_TeamMonTMMove`):
## reutiliza GiveMoveToMon/SetMonMoveSlot y el veto de MO. Un solo commit: la MT se
## gasta en el mismo paso en que se aprende el movimiento (`Task_TeamMonTMMove2`,
## `RemoveBagItem` solo si `itemId < ITEM_HM01_CUT`); las MO no se gastan.
enum Estado { VALIDA, YA_CONOCE, INCOMPATIBLE, INVALIDA }
var aprendida: bool = false
## Nombre interno de la máquina ("MT24", "MO03"...).
var objeto: String
## Nombre interno del movimiento que enseña y su nombre mostrable (gStringVar2).
var movimiento: String
var nombre_mov: String
## MT: se gasta al aprenderse. MO: no.
var gasta_objeto: bool
var _partida: EstructuraGuardado
var _mochila: Dictionary
var _movimientos: Array
var _estado_movimientos: Array = []
var _especie: String
var _bolsillo: int


func _init(p_pokemon: BasePokemon, p_objeto: String, bolsillo: int = DatosMaquinas.BOLSILLO, datos: Object = null) -> void:
	super(p_pokemon, datos)
	objeto = p_objeto
	movimiento = DatosMaquinas.movimiento(objeto)
	nombre_mov = DatosMaquinas.nombre_movimiento(objeto)
	gasta_objeto = not DatosMaquinas.es_mo(objeto)
	_cola.clear()
	if not movimiento.is_empty():
		_cola.append(movimiento)
	_bolsillo = bolsillo
	_partida = SistemaGuardado.datos_vivos
	_mochila = _partida.mochila.duplicate(true)
	if pokemon != null:
		_especie = pokemon.nombre_interno
		_movimientos = pokemon.movimientos.duplicate()
		for m: Movimiento in pokemon.movimientos:
			_estado_movimientos.append([m.nombre, m.pp_act, m.pp_mas, m.pp_tot, m.datos.duplicate(true)] if m != null else [])


## La partida, la mochila, el Pokémon y sus movimientos siguen como al empezar.
## Un huevo sigue vigente: no es compatible con ninguna máquina (CanMonLearnTMHM).
func vigente() -> bool:
	if aprendida or pokemon == null or movimiento.is_empty() or _partida != SistemaGuardado.datos_vivos \
		or not SistemaGuardado.get_equipo().has(pokemon) or pokemon.nombre_interno != _especie \
		or _bolsillo != DatosMaquinas.BOLSILLO or _partida.mochila != _mochila \
		or pokemon.movimientos != _movimientos or _movimientos.size() > MAX_MOVIMIENTOS \
		or DatosMaquinas.movimiento(objeto) != movimiento \
		or not SistemaGuardado.tiene_objeto(objeto, 1, _bolsillo):
		return false
	for i: int in _movimientos.size():
		var m: Movimiento = pokemon.movimientos[i]
		if m == null or [m.nombre, m.pp_act, m.pp_mas, m.pp_tot, m.datos] != _estado_movimientos[i]: return false
	return true


## `Task_TeamMonTMMove`: primero "ya lo conoce" y después la compatibilidad (un huevo
## nunca es compatible: CanMonLearnTMHM devuelve 0 para SPECIES_EGG).
func estado() -> Estado:
	if not vigente(): return Estado.INVALIDA
	if conoce(movimiento): return Estado.YA_CONOCE
	if pokemon.huevo or not _datos.puede_aprender_mt(_especie, movimiento): return Estado.INCOMPATIBLE
	return Estado.VALIDA


func siguiente() -> Dictionary:
	if estado() != Estado.VALIDA:
		return {"resultado": Resultado.FIN, "movimiento": ""}
	return super.siguiente()


func _aplicar_movimiento(nuevo: Movimiento, indice: int) -> bool:
	if estado() != Estado.VALIDA or nuevo == null or _datos.id_movimiento(nuevo) != movimiento \
		or (indice < 0 and pokemon.movimientos.size() >= MAX_MOVIMIENTOS) \
		or (indice >= 0 and (indice >= pokemon.movimientos.size() or es_mo(indice))):
		return false
	# Consumo y movimiento son atómicos: después de quitar no hay fallo ni await.
	if gasta_objeto and not SistemaGuardado.quitar_objeto_jugador(objeto, 1, _bolsillo): return false
	super._aplicar_movimiento(nuevo, indice)
	# FRIENDSHIP_EVENT_LEARN_TMHM, con MT y con MO.
	Amistad.ajustar(pokemon, Amistad.Evento.MT_MO)
	aprendida = true
	return true
