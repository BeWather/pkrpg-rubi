extends RefCounted
## Explicit current BANK identity at calculation; never retain a holder payload.
const Held=preload("res://scripts/battle/held_damage_rules.gd")
static func describe(battle: Node,actor: BasePokemon,state: PokemonEnCombate) -> Dictionary:
	if actor==null or state==null or battle._obtener_combatiente(actor)!=state:return {}
	var lease: Dictionary=battle.field_rules.capture(actor)
	return battle.held_item_effects.resolve(battle,actor,lease) if battle.field_rules.valid(lease) else {}
static func stage(value: int,mod: int) -> int:return value*(2+maxi(0,mod))/(2+maxi(0,-mod))
static func physical_base(actor: BasePokemon,target: BasePokemon,sa: PokemonEnCombate,st: PokemonEnCombate,power: int,descriptor: Dictionary,critical: bool=false,screen: int=0,spread: bool=false,explosion: bool=false) -> int:
	var attack: int=BattleTransformRules.stat(sa,"estad_ataque",actor.estad_ataque) if sa!=null else actor.estad_ataque
	var defense: int=BattleTransformRules.stat(st,"estad_defensa",target.estad_defensa) if st!=null else target.estad_defensa
	attack&=65535;defense&=65535
	if HabilidadesCombate.de(actor) in [HabilidadesCombate.POTENCIA,HabilidadesCombate.ENERGIAPURA]:attack=(attack*2)&65535
	# Badge boosts are not modeled by this native battle domain (REQUIRED).
	attack=Held.attack(attack,descriptor)
	if HabilidadesCombate.tiene(actor,HabilidadesCombate.ENTUSIASMO) or (HabilidadesCombate.tiene(actor,HabilidadesCombate.AGALLAS) and actor.estado!=Singleton.ProblemaEstado.NORMAL):attack=(attack*150/100)&65535
	if HabilidadesCombate.tiene(target,HabilidadesCombate.ESCAMAESPECIAL) and target.estado!=Singleton.ProblemaEstado.NORMAL:defense=(defense*150/100)&65535
	if explosion:defense/=2
	var attack_stage: int=sa.mod_ataque if sa!=null else 0
	var defense_stage: int=st.mod_defensa if st!=null else 0
	attack=stage(attack,attack_stage if not critical or attack_stage>0 else 0)
	defense=stage(defense,defense_stage if not critical or defense_stage<0 else 0)
	var damage: int=attack*power*(2*actor.nivel/5+2)/maxi(1,defense)/50
	if actor.estado==Singleton.ProblemaEstado.QUEMADO and not HabilidadesCombate.tiene(actor,HabilidadesCombate.AGALLAS):damage/=2
	if screen>0 and not critical:damage=2*(damage/3) if screen==2 else damage/2
	if spread:damage/=2
	return maxi(1,damage)+2
## CalculateBaseDamage, IS_TYPE_SPECIAL branch. Unlike the physical one it has no
## minimum of 1 before the final +2, and it owns the weather and Flash Fire steps.
static func special_base(actor: BasePokemon,target: BasePokemon,sa: PokemonEnCombate,st: PokemonEnCombate,power: int,type: String,critical: bool=false,screen: int=0,spread: bool=false,weather: int=0,solar_beam: bool=false,field: CampoCombate=null) -> int:
	var attack: int=BattleTransformRules.stat(sa,"estad_ataque_especial",actor.estad_ataque_especial) if sa!=null else actor.estad_ataque_especial
	var defense: int=BattleTransformRules.stat(st,"estad_defensa_especial",target.estad_defensa_especial) if st!=null else target.estad_defensa_especial
	attack&=65535;defense&=65535
	if HabilidadesCombate.tiene(target,HabilidadesCombate.SEBO) and type in ["FUEGO","HIELO"]:attack/=2
	if field!=null and ((HabilidadesCombate.tiene(actor,HabilidadesCombate.MAS) and field.hay_habilidad(HabilidadesCombate.MENOS)) or (HabilidadesCombate.tiene(actor,HabilidadesCombate.MENOS) and field.hay_habilidad(HabilidadesCombate.MAS))):attack=(attack*150/100)&65535
	var attack_stage: int=sa.mod_ataque_especial if sa!=null else 0
	var defense_stage: int=st.mod_defensa_especial if st!=null else 0
	attack=stage(attack,attack_stage if not critical or attack_stage>0 else 0)
	defense=stage(defense,defense_stage if not critical or defense_stage<0 else 0)
	var damage: int=attack*power*(2*actor.nivel/5+2)/maxi(1,defense)/50
	if screen>0 and not critical:damage=2*(damage/3) if screen==2 else damage/2
	if spread:damage/=2
	if weather==2:
		if type=="FUEGO":damage/=2
		elif type=="AGUA":damage=15*damage/10
	if solar_beam and weather in [2,3,4]:damage/=2
	if weather==1:
		if type=="FUEGO":damage=15*damage/10
		elif type=="AGUA":damage/=2
	if sa!=null and sa.absorbe_fuego and type=="FUEGO":damage=15*damage/10
	return damage+2
