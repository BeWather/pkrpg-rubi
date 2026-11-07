extends RefCounted
## Ruby atkCC and sNaturePowerMoves. Terrain is gameplay metadata, not renderer RNG.
const IDS: Array[int]=[78,75,89,56,57,61,157,247,129,129]
# power, type, category, accuracy, source target mask, effect, secondary chance
const POLICIES={
	78:[0,"PLANTA",3,75,0,"EFFECT_PARALYZE",0],
	75:[55,"PLANTA",2,95,8,"EFFECT_HIGH_CRITICAL",0],
	89:[100,"TIERRA",1,100,32,"EFFECT_EARTHQUAKE",0],
	56:[120,"AGUA",2,80,0,"EFFECT_HIT",0],
	57:[95,"AGUA",2,100,8,"EFFECT_HIT",0],
	61:[65,"AGUA",2,100,0,"EFFECT_SPEED_DOWN_HIT",10],
	157:[75,"ROCA",1,90,8,"EFFECT_FLINCH_HIT",30],
	247:[80,"FANTASMA",1,100,0,"EFFECT_SPECIAL_DEFENSE_DOWN_HIT",20],
	129:[60,"NORMAL",1,0,8,"EFFECT_ALWAYS_HIT",0],
}
static func supports(move: Movimiento) -> bool:return move!=null and int(move.datos.get("numero_movimiento",0))==267
static func capture(battle: BattleSceneController,move: Movimiento) -> Dictionary:
	var data: Dictionary=move.datos.duplicate(true)
	data.categoria_dano_id=3;data.potencia=0;data.tipo="NORMAL";data.precision=95;data.max_pp=20;data.pp=20;data.contacto=0;data.objetivo_id=1;data.source_target_mask=16;data.prioridad=0;data.prob_secundario=0;data.efecto="EFFECT_NATURE_POWER"
	var environment: int=int(battle.obtener_terreno_batalla())
	return {"name":move.nombre,"data":data,"environment":environment,"called":called_move(IDS[environment])}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_nature_power"):return move
	if phase.has("source_nature_power_admitted"):return phase.source_nature_power_admitted
	var fact: Dictionary=phase.source_nature_power
	var accepted:=Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))
	phase.source_nature_power_admitted=accepted;return accepted
static func called_move(id: int) -> Movimiento:
	var move: Movimiento=preload("res://scripts/battle/thought_finger_rules.gd").called_move(id)
	if move==null or not POLICIES.has(id):return null
	var p: Array=POLICIES[id];var d: Dictionary=move.datos
	d.potencia=p[0];d.tipo=p[1];d.categoria_dano_id=p[2];d.precision=p[3];d.source_target_mask=p[4];d.efecto=p[5];d.prob_secundario=p[6];d.objetivo_id=10 if p[4]==0 else 11 if p[4]==8 else 9;d.contacto=0;d.sonido=0;d.prioridad=0
	return move
