extends RefCounted
## Ordinary Ruby Rest acceptance. HP presentation remains battle-controller owned.
static func accept(state: PokemonEnCombate) -> Dictionary:
	if state==null:return {"accepted":false}
	var actor: BasePokemon=state.pokemon_base
	if actor==null or actor.estad_ps_actual<=0 or actor.estad_ps_actual>=actor.estad_ps or actor.estado==Singleton.ProblemaEstado.DORMIDO:return {"accepted":false}
	if not HabilidadesCombate.mensaje_impide_estado(actor,HabilidadesCombate.ESTADO_DORMIDO).is_empty():return {"accepted":false}
	actor.estado=Singleton.ProblemaEstado.DORMIDO
	state.envenenamiento_grave=false;state.contador_veneno_grave=0
	state.iniciar_sueno(3) # atk81 stores STATUS1_SLEEP=3; two blocked future attempts.
	return {"accepted":true,"heal":actor.estad_ps}
