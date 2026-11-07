class_name AccionHabilidad
extends RefCounted

## Un efecto de habilidad ya resuelto, listo para mostrarse. La lógica pura de
## `HabilidadesCombate` muta el estado lógico (modificadores, estado, tipos...)
## y devuelve una lista ordenada de estas acciones; quien tiene la escena las
## presenta (texto, animaciones, barra de PS). STAT_GROUP is the explicit
## exception: a native planned group committed by the controller after its
## source animation, never by a visual callback.

enum Tipo {
	MENSAJE,      ## Solo texto.
	ESTADISTICA,  ## Animación de subida/bajada de `objetivo`, luego el texto.
	ESTADO,       ## Refrescar el icono de estado de `objetivo`, luego el texto.
	DANO,         ## Quitar `cantidad` PS a `objetivo`, luego el texto.
	CURAR,        ## Dar `cantidad` PS a `objetivo`, luego el texto.
	CLIMA,        ## Cambiar el clima a `cantidad` (Singleton.ClimaBatalla).
	ITEM_PHASE,   ## Successful item phase; append to preserve existing enum values.
	STAT_GROUP,   ## Native deferred group: source animation precedes ordered stat commits.
	CAMBIO_FORMA, ## Animar `objetivo` hasta la forma `cantidad` (0 = base), luego el texto.
}

var source_stat_animation: int=-1
var source_stat_changes: Array=[]
var source_stat_state: PokemonEnCombate
var source_stat_rival: bool=false
var source_stat_committed: bool=false
var source_stat_parent: BattleMoveAction
var source_stat_trace_target: BasePokemon
var source_actor: BasePokemon=null
## Animación de estado (p. ej. "ruby:status/1") sobre `objetivo` antes del texto:
## chosenstatus2animation de BattleScript_MoveEffectConfusion.
var source_status_key: String=""
var tipo: Tipo = Tipo.MENSAJE
var objetivo: BasePokemon = null
var cantidad: int = 0
var sube: bool = true
var texto: String = ""


static func mensaje(t: String) -> AccionHabilidad:
	return _crear(Tipo.MENSAJE, null, 0, true, t)


static func estadistica(obj: BasePokemon, subida: bool, t: String, stat: String="", levels: int=0) -> AccionHabilidad:
	var action:=_crear(Tipo.ESTADISTICA, obj, 0, subida, t)
	if not stat.is_empty():action.source_stat_animation=preload("res://scripts/battle/stat_animation_rules.gd").argument([[stat,levels]])
	return action


## Unlike ordinary pre-resolved actions, this explicit native group is committed
## by the ability controller after source General1, never by its visual callback.
static func stat_group(obj: BasePokemon,state: PokemonEnCombate,changes: Array,rival: bool) -> AccionHabilidad:
	var action:=_crear(Tipo.STAT_GROUP,obj,0,true,"");action.source_stat_state=state;action.source_stat_changes=changes.duplicate(true);action.source_stat_rival=rival;return action


static func estado(obj: BasePokemon, t: String) -> AccionHabilidad:
	return _crear(Tipo.ESTADO, obj, 0, true, t)


static func dano(obj: BasePokemon, puntos: int, t: String) -> AccionHabilidad:
	return _crear(Tipo.DANO, obj, puntos, true, t)


static func curar(obj: BasePokemon, puntos: int, t: String) -> AccionHabilidad:
	return _crear(Tipo.CURAR, obj, puntos, true, t)


static func clima(valor: int, t: String) -> AccionHabilidad:
	return _crear(Tipo.CLIMA, null, valor, true, t)


static func cambio_forma(obj: BasePokemon, forma: int, t: String) -> AccionHabilidad:
	return _crear(Tipo.CAMBIO_FORMA, obj, forma, true, t)


static func _crear(t: Tipo, obj: BasePokemon, n: int, s: bool, txt: String) -> AccionHabilidad:
	var a := AccionHabilidad.new()
	a.tipo = t
	a.objetivo = obj
	a.cantidad = n
	a.sube = s
	a.texto = txt
	return a

static func item_phase(actor: BasePokemon,target: BasePokemon,phase: int) -> AccionHabilidad:
	var action:=_crear(Tipo.ITEM_PHASE,target,phase,true,"");action.source_actor=actor;return action
