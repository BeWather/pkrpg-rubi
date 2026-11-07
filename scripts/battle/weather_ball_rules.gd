extends RefCounted
## Ruby atkE9 dynamic type; atk05 doubles the complete base, not raw power.
static func supports(move: Movimiento) -> bool:return move!=null and int(move.datos.get("numero_movimiento",0))==311
static func capture(move: Movimiento,field: CampoCombate) -> Dictionary:
	var weather: int=field.clima_efectivo();var data: Dictionary=move.datos.duplicate(true)
	data.tipo=["NORMAL","FUEGO","AGUA","ROCA","HIELO"][weather];data.categoria_dano_id=1 if weather in [0,3] else 2;data.potencia=50;data.precision=100;data.max_pp=10;data.pp=10;data.contacto=0;data.objetivo_id=10;data.prioridad=0;data.prob_secundario=0;data.efecto="EFFECT_WEATHER_BALL"
	# Source0x80 distinguishes Weather Ball from Hidden Power0xC0 at datahpupdate.
	var allowed: bool=not field.hay_habilidad(HabilidadesCombate.ACLIMATACION) and not field.hay_habilidad(HabilidadesCombate.BUCLEAIRE)
	var source_dynamic_type: int=(int([0,10,11,5,15][weather])|0x80) if allowed else 0
	return {"name":move.nombre,"data":data,"weather":weather,"source_dynamic_type":source_dynamic_type}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_weather_ball"):return move
	var fact: Dictionary=phase.source_weather_ball
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))
