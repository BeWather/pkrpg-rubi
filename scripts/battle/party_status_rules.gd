extends RefCounted
## Ruby atkAE cures status1 before attackanimation; never HP, PP or status2/3.
const SOURCE_TYPES={215:"NORMAL",312:"PLANTA"}
static func supports(move: Movimiento) -> bool:return move!=null and SOURCE_TYPES.has(int(move.datos.get("numero_movimiento",0)))
static func capture(move: Movimiento) -> Dictionary:
	# Neither move belongs to gSoundMovesTable; atkAE handles Heal Bell's
	# Soundproof exclusions separately. Both only set F_AFFECTED_BY_SNATCH.
	var d: Dictionary=move.datos.duplicate(true);d.categoria_dano_id=3;d.potencia=0;d.tipo=SOURCE_TYPES[int(d.numero_movimiento)];d.precision=0;d.max_pp=5;d.pp=5;d.contacto=0;d.sonido=0;d.objetivo_id=7;d.prioridad=0;d.prob_secundario=0;d.efecto="EFFECT_HEAL_BELL"
	return {"name":move.nombre,"data":d}
static func accepted_move(phase: Dictionary,move: Movimiento) -> Movimiento:
	if not phase.has("source_party_cure"):return move
	var fact: Dictionary=phase.source_party_cure
	return Movimiento.new(str(fact.name),move.pp_act,move.pp_mas,move.pp_tot,fact.data.duplicate(true))
static func produce(b: BattleSceneController,actor: BasePokemon,move: Movimiento) -> void:
	var party: Array=b.equipo_jugador_pokemones if actor in b.equipo_jugador_pokemones or actor==b.poke_jugador else b.equipo_enemigo_pokemones
	var recipients: Array=party.duplicate()
	if not recipients.has(actor):recipients.append(actor)
	for pokemon: BasePokemon in recipients:
		if pokemon==null:continue
		# Heal Bell shares the source command but alone excludes Soundproof.
		if int(move.datos.get("numero_movimiento",0))==215 and HabilidadesCombate.tiene(pokemon,"INSONORIZAR"):continue
		if pokemon.estad_ps_actual<=0:continue # Native DEBILITADO is not a Ruby status1 bit.
		pokemon.estado=Singleton.ProblemaEstado.NORMAL
		var live: PokemonEnCombate=b._obtener_combatiente(pokemon)
		if live!=null:live.turnos_dormido=0;live.envenenamiento_grave=false;live.contador_veneno_grave=0
		if b.hud!=null:b.hud._actualizar_estado_visual_pokemon(pokemon)
