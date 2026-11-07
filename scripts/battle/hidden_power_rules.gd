extends RefCounted
## Ruby atkC1. Table type/BANK category are NOT the effective damage type.
const IVS=["iv_ps","iv_ataque","iv_defensa","iv_velocidad","iv_ataque_especial","iv_defensa_especial"]
const TYPES=["NORMAL","LUCHA","VOLADOR","VENENO","TIERRA","ROCA","BICHO","FANTASMA","ACERO","???","FUEGO","AGUA","PLANTA","ELECTRICO","PSIQUICO","HIELO","DRAGON","SINIESTRO"]
static func supports(move: Movimiento) -> bool:return move!=null and int(move.datos.get("numero_movimiento",0))==237
static func derive(ivs: Array) -> Dictionary:
	if ivs.size()!=6:return {}
	var parity: int=0;var second: int=0
	for index: int in 6:
		if typeof(ivs[index])!=TYPE_INT or int(ivs[index])<0 or int(ivs[index])>31:return {}
		parity|=(int(ivs[index])&1)<<index;second|=((int(ivs[index])>>1)&1)<<index
	var type: int=parity*15/63+1
	if type>=9:type+=1
	return {"source_table_type":"NORMAL","source_effective_type_id":type,"source_dynamic_type":type|0xC0,"power":30+second*40/63,"category":1 if type<9 else 2}
static func capture(move: Movimiento,actor: BasePokemon) -> Dictionary:
	if actor==null:return {}
	# Transform copies IVs together with the first0x24 bytes of BattlePokemon.
	var domain: Dictionary=BattleTransformRules.data(actor);var ivs: Array=[]
	for property: String in IVS:ivs.append(domain.get("ivs",{}).get(property) if not domain.is_empty() else actor.get(property))
	var fact: Dictionary=derive(ivs)
	if fact.is_empty():return {}
	var data: Dictionary=move.datos.duplicate(true)
	data.numero_movimiento=237;data.tipo=TYPES[int(fact.source_effective_type_id)];data.categoria_dano_id=fact.category;data.potencia=fact.power;data.precision=100;data.max_pp=15;data.pp=15;data.contacto=0;data.sonido=0;data.objetivo_id=10;data.prioridad=0;data.prob_secundario=0;data.efecto="EFFECT_HIDDEN_POWER"
	fact.name=move.nombre;fact.data=data;return fact
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_hidden_power") or phase.source_hidden_power.is_empty():return move
	var fact: Dictionary=phase.source_hidden_power
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))
