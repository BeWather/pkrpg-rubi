extends RefCounted
## Port literal de battle_ai_switch_items.c: AI_TrySwitchOrUseItem (rama de cambio),
## ShouldSwitch y GetMostSuitableMonToSwitchInto. Regla pura: todo llega en `ctx`, que
## arma `battle_ai_integrator.gd`. Las tiradas salen de `ctx.draw` (Random(), 16 bits)
## y se piden en el mismo orden que el C, cortocircuitos incluidos.
##
## ctx = {
##   doble: bool, tabla: Dictionary (Singleton.tabla_tipos), draw: Callable,
##   gt1: String,            # gBattleMons[gBattlerTarget].type1
##   actor: {ability, dormido, ps, ps_max, moves: Array[int], perish, perish_count,
##           mods: Array[int], landed: int, party_index: int, tipos: Array[String]},
##   companero_index: int,   # -1 si está ausente (gAbsentBattlerFlags)
##   companero_cambio: int,  # monToSwitchIntoId del compañero; 6 si no eligió
##   hit_by: {} | {tipos_especie, ability, party_index, cambio},  # gLastHitBy
##   party: [{ps, ability, tipos: [t1, t2], moves: Array[int]}],
##   rivales: [{ausente, ability, tipos_especie, tipos, identificado, dano_base: int}],
## }
##
## Las fichas de movimiento (poder/tipo) son las de gBattleMoves de la ROM y no las de
## la tabla Movimientos, que usa valores modernos: la IA debe ver lo que veía el juego.

const SIN_MON := 6
const FORCEJEO := 165
const ID_DESCONOCIDO := 65535

const MISSED := 1
const SUPER_EFFECTIVE := 2
const NOT_VERY_EFFECTIVE := 4
const DOESNT_AFFECT_FOE := 8
const FAILED := 32
const NO_EFFECT := MISSED | DOESNT_AFFECT_FOE | FAILED

const TIPOS_ESPECIALES: Array[String] = ["FUEGO", "AGUA", "PLANTA", "ELECTRICO", "PSIQUICO", "HIELO", "DRAGON", "SINIESTRO"]

static var _rom: Dictionary = {}


static func _fichas() -> Dictionary:
	if _rom.is_empty():
		_rom = JSON.parse_string(FileAccess.get_file_as_string("res://BaseDatos/gbattlemoves_ia.json"))
	return _rom


## gBattleMoves[id].power. Con id 0xFFFF el C lee fuera de la tabla (ShouldSwitchIfNaturalCure,
## tras fallar su primera tirada); en la ROM ese byte no es cero.
static func poder(id: int) -> int:
	if id == ID_DESCONOCIDO:
		return int(_fichas().poder_fuera_de_tabla)
	return int(_fichas().poder[id])


static func tipo(id: int) -> String:
	return str(_fichas().tipo[id])


static func objetivo(id: int) -> int:
	return int(_fichas().objetivo[id])


## ¿El tipo es de los que usan Ataque Especial? ??? (Maldición) no es físico ni especial.
static func es_especial(tipo_movimiento: String) -> bool:
	return TIPOS_ESPECIALES.has(tipo_movimiento)


## Orden de filas de gTypeEffectiveness: las de NORMAL y LUCHA contra FANTASMA van tras
## TYPE_FORESIGHT, al final de la tabla; HIELO→FUEGO y FANTASMA→FANTASMA también.
static func _orden_fila(ataque: String, defensa: String) -> int:
	if ataque in ["NORMAL", "LUCHA"] and defensa == "FANTASMA":
		return 100
	return MoveResolver._orden_tabla_tipos(ataque, defensa)


## Tipos defensores presentes en la tabla para `ataque`, en orden de fila: [[tipo, multiplicador]].
static func _filas(ataque: String, t1: String, t2: String, tabla: Dictionary) -> Array:
	var filas: Dictionary = tabla.get(ataque, {})
	var defensas: Array[String] = [t1]
	if t2 != t1:
		defensas.append(t2)
	defensas.sort_custom(func(a: String, b: String) -> bool: return _orden_fila(ataque, a) < _orden_fila(ataque, b))
	var resultado: Array = []
	for defensa: String in defensas:
		var factor: float = float(filas.get(defensa, 1.0))
		if factor != 1.0:
			resultado.append([defensa, int(factor * 10.0)])
	return resultado


## ModulateDmgByType2 sobre {flags, dano}.
static func _modular(multiplicador: int, id: int, r: Dictionary) -> void:
	r.dano = r.dano * multiplicador / 10
	if r.dano == 0 and multiplicador != 0:
		r.dano = 1
	match multiplicador:
		0:
			r.flags = (r.flags | DOESNT_AFFECT_FOE) & ~NOT_VERY_EFFECTIVE & ~SUPER_EFFECTIVE
		5:
			if poder(id) != 0 and r.flags & NO_EFFECT == 0:
				if r.flags & SUPER_EFFECTIVE:
					r.flags &= ~SUPER_EFFECTIVE
				else:
					r.flags |= NOT_VERY_EFFECTIVE
		20:
			if poder(id) != 0 and r.flags & NO_EFFECT == 0:
				if r.flags & NOT_VERY_EFFECTIVE:
					r.flags &= ~NOT_VERY_EFFECTIVE
				else:
					r.flags |= SUPER_EFFECTIVE


## Núcleo común de TypeCalc y AI_TypeCalc. Curiosidad del original: el segundo tipo se
## compara con gBattleMons[gBattlerTarget].type1 y no con el primer tipo del defensor.
## Así un defensor de un solo tipo modula dos veces y uno de dos tipos puede saltarse el
## segundo si coincide con el tipo primario del último objetivo.
static func _recorrer_tabla(id: int, t1: String, t2: String, ctx: Dictionary, r: Dictionary, salta_identificado: bool) -> void:
	var ataque: String = tipo(id)
	for fila: Array in _filas(ataque, t1, t2, ctx.tabla):
		# TYPE_FORESIGHT: en TypeCalc un defensor identificado corta aquí la tabla.
		if salta_identificado and ataque in ["NORMAL", "LUCHA"] and fila[0] == "FANTASMA":
			continue
		if fila[0] == t1:
			_modular(fila[1], id, r)
		if fila[0] == t2 and ctx.gt1 != t2:
			_modular(fila[1], id, r)


## AI_TypeCalc: por especie (ignora Conversión) y sin Foresight.
static func ai_type_calc(id: int, tipos_especie: Array, ability: String, ctx: Dictionary) -> int:
	if id == FORCEJEO:
		return 0
	var r: Dictionary = {"flags": 0, "dano": 0}
	if ability == HabilidadesCombate.LEVITACION and tipo(id) == "TIERRA":
		r.flags = MISSED | DOESNT_AFFECT_FOE
	else:
		_recorrer_tabla(id, tipos_especie[0], tipos_especie[1], ctx, r, false)
	if ability == HabilidadesCombate.SUPERGUARDA and (r.flags & SUPER_EFFECTIVE == 0 or r.flags & (SUPER_EFFECTIVE | NOT_VERY_EFFECTIVE) == (SUPER_EFFECTIVE | NOT_VERY_EFFECTIVE)) and poder(id) != 0:
		r.flags |= DOESNT_AFFECT_FOE
	return r.flags


## TypeCalc(move, gActiveBattler, rival): tipos actuales del rival; STAB del activo, no del
## miembro del equipo dueño del movimiento. Su rama de Superguarda solo añade MISSED, sin
## tocar SUPER_EFFECTIVE, único bit que lee GetMostSuitable; no hace falta portarla.
static func type_calc(id: int, rival: Dictionary, dano: int, ctx: Dictionary) -> Dictionary:
	var r: Dictionary = {"flags": 0, "dano": dano}
	if id == FORCEJEO:
		return r
	if ctx.actor.tipos.has(tipo(id)):
		r.dano = r.dano * 15 / 10
	if rival.ability == HabilidadesCombate.LEVITACION and tipo(id) == "TIERRA":
		r.flags |= MISSED | DOESNT_AFFECT_FOE
	else:
		_recorrer_tabla(id, rival.tipos[0], rival.tipos[1], ctx, r, bool(rival.identificado))
	return r


## ModulateByTypeEffectiveness: multiplicador de un tipo atacante sobre `valor`.
## Curiosidad: GetMostSuitable lo llama con type1 y type2 aunque coincidan, de modo que un
## rival de un solo tipo cuenta dos veces.
static func modular_por_tipo(ataque: String, t1: String, t2: String, valor: int, tabla: Dictionary) -> int:
	for fila: Array in _filas(ataque, t1, t2, tabla):
		valor = (valor * fila[1] / 10) & 255
	return valor


static func _r(ctx: Dictionary) -> int:
	return int(ctx.draw.call()) & 65535


static func _miembro(ctx: Dictionary, i: int) -> Dictionary:
	return ctx.party[i] if i < ctx.party.size() and ctx.party[i] != null else {}


## battlerIn1/battlerIn2 y sus monToSwitchIntoId. Ruby pone a 6 el del propio battler al
## empezar su selección; un compañero ausente se sustituye por el propio battler.
static func _excluidos(ctx: Dictionary) -> Dictionary:
	var propio: int = ctx.actor.party_index
	if ctx.doble and ctx.companero_index >= 0:
		return {"p1": propio, "p2": ctx.companero_index, "c1": SIN_MON, "c2": ctx.companero_cambio}
	return {"p1": propio, "p2": propio, "c1": SIN_MON, "c2": SIN_MON}


static func _elegible(ctx: Dictionary, i: int, e: Dictionary) -> bool:
	var mon: Dictionary = _miembro(ctx, i)
	if mon.is_empty() or int(mon.ps) == 0:
		return false
	return i != e.p1 and i != e.p2 and i != e.c1 and i != e.c2


## ShouldSwitchIfPerishSong. Devuelve 6: elige relevo GetMostSuitable.
static func perish_song(ctx: Dictionary) -> int:
	return SIN_MON if ctx.actor.perish and int(ctx.actor.perish_count) == 0 else -1


## ShouldSwitchIfWonderGuard. Solo en simple y solo mira al jugador izquierdo.
static func wonder_guard(ctx: Dictionary) -> int:
	if ctx.doble:
		return -1
	var rival: Dictionary = ctx.rivales[0]
	if rival.ability != HabilidadesCombate.SUPERGUARDA:
		return -1
	for id: int in ctx.actor.moves:
		if id != 0 and ai_type_calc(id, rival.tipos_especie, rival.ability, ctx) & SUPER_EFFECTIVE:
			return -1
	for i: int in 6:
		var mon: Dictionary = _miembro(ctx, i)
		if mon.is_empty() or int(mon.ps) == 0 or i == ctx.actor.party_index:
			continue
		for id: int in mon.moves:
			if id != 0 and ai_type_calc(id, rival.tipos_especie, rival.ability, ctx) & SUPER_EFFECTIVE and _r(ctx) % 3 < 2:
				return i
	return -1


## FindMonThatAbsorbsOpponentsMove.
static func absorbe_movimiento(ctx: Dictionary) -> int:
	if tiene_supereficaz(ctx, true) and _r(ctx) % 3 != 0:
		return -1
	var landed: int = ctx.actor.landed
	if landed == 0 or landed == ID_DESCONOCIDO or poder(landed) == 0:
		return -1
	var habilidad: String
	match tipo(landed):
		"FUEGO":
			habilidad = HabilidadesCombate.ABSORBEFUEGO
		"AGUA":
			habilidad = HabilidadesCombate.ABSORBEAGUA
		"ELECTRICO":
			habilidad = HabilidadesCombate.ABSORBEELEC
		_:
			return -1
	if ctx.actor.ability == habilidad:
		return -1
	var e: Dictionary = _excluidos(ctx)
	for i: int in 6:
		if _elegible(ctx, i, e) and _miembro(ctx, i).ability == habilidad and _r(ctx) & 1:
			return i
	return -1


## ShouldSwitchIfNaturalCure. Con landed 0xFFFF y primera tirada fallida, el `else if` lee
## gBattleMoves fuera de tabla (ver `poder`).
static func natural_cure(ctx: Dictionary) -> int:
	var a: Dictionary = ctx.actor
	if not a.dormido or a.ability != HabilidadesCombate.CURANATURAL or int(a.ps) < int(a.ps_max) / 2:
		return -1
	if (a.landed == 0 or a.landed == ID_DESCONOCIDO) and _r(ctx) & 1:
		return SIN_MON
	elif poder(a.landed) == 0 and _r(ctx) & 1:
		return SIN_MON
	var encontrado: int = busca_con_flags_y_supereficaz(ctx, DOESNT_AFFECT_FOE, 1)
	if encontrado >= 0:
		return encontrado
	encontrado = busca_con_flags_y_supereficaz(ctx, NOT_VERY_EFFECTIVE, 1)
	if encontrado >= 0:
		return encontrado
	return SIN_MON if _r(ctx) & 1 else -1


## HasSuperEffectiveMoveAgainstOpponents. Por cada movimiento supereficaz con tirada, un
## 1/10 lo descarta y sigue buscando.
static func tiene_supereficaz(ctx: Dictionary, sin_azar: bool) -> bool:
	for flanco: int in (2 if ctx.doble else 1):
		if flanco >= ctx.rivales.size() or ctx.rivales[flanco].ausente:
			continue
		var rival: Dictionary = ctx.rivales[flanco]
		for id: int in ctx.actor.moves:
			if id == 0:
				continue
			if ai_type_calc(id, rival.tipos_especie, rival.ability, ctx) & SUPER_EFFECTIVE:
				if sin_azar or _r(ctx) % 10 != 0:
					return true
	return false


## AreStatsRaised: más de 3 etapas positivas sumadas.
static func stats_subidas(ctx: Dictionary) -> bool:
	var suma: int = 0
	for etapa: int in ctx.actor.mods:
		if etapa > 0:
			suma += etapa
	return suma > 3


## FindMonWithFlagsAndSuperEffective. Curiosidad del original: al encontrar un candidato
## con los flags pedidos reutiliza battlerIn1 para gLastHitBy y no lo restaura, así que los
## siguientes miembros se comparan con el índice de equipo del atacante, que además suele
## ser del equipo del jugador, en lugar del propio.
static func busca_con_flags_y_supereficaz(ctx: Dictionary, flags: int, modulo: int) -> int:
	var landed: int = ctx.actor.landed
	if landed == 0 or landed == ID_DESCONOCIDO or ctx.hit_by.is_empty() or poder(landed) == 0:
		return -1
	var e: Dictionary = _excluidos(ctx)
	for i: int in 6:
		if not _elegible(ctx, i, e):
			continue
		var mon: Dictionary = _miembro(ctx, i)
		if ai_type_calc(landed, mon.tipos, mon.ability, ctx) & flags:
			e.p1 = ctx.hit_by.party_index
			e.c1 = ctx.hit_by.cambio
			for id: int in mon.moves:
				if id == 0:
					continue
				if ai_type_calc(id, ctx.hit_by.tipos_especie, ctx.hit_by.ability, ctx) & SUPER_EFFECTIVE and _r(ctx) % modulo == 0:
					return i
	return -1


## ShouldSwitch sin sus bloqueos iniciales, que dependen del motor y comprueba el integrador.
## Devuelve -1 si no cambia, 6 si cambia sin relevo elegido o el índice del relevo.
static func debe_cambiar(ctx: Dictionary) -> int:
	var e: Dictionary = _excluidos(ctx)
	var disponibles: int = 0
	for i: int in 6:
		if _elegible(ctx, i, e):
			disponibles += 1
	if disponibles == 0:
		return -1
	var eleccion: int = perish_song(ctx)
	if eleccion >= 0:
		return eleccion
	eleccion = wonder_guard(ctx)
	if eleccion >= 0:
		return eleccion
	eleccion = absorbe_movimiento(ctx)
	if eleccion >= 0:
		return eleccion
	eleccion = natural_cure(ctx)
	if eleccion >= 0:
		return eleccion
	if tiene_supereficaz(ctx, false) or stats_subidas(ctx):
		return -1
	eleccion = busca_con_flags_y_supereficaz(ctx, DOESNT_AFFECT_FOE, 2)
	if eleccion >= 0:
		return eleccion
	return busca_con_flags_y_supereficaz(ctx, NOT_VERY_EFFECTIVE, 3)


## GetMostSuitableMonToSwitchInto. Curiosidades del original que se conservan:
## - En dobles sortea el rival (`Random() & BIT_FLANK`) aunque solo haya uno útil.
## - La primera pasada busca por tipos: un candidato con multiplicador 0 no supera bestDmg
##   y, si ninguno lo supera, se abandona la pasada entera.
## - La segunda calcula el daño con gCurrentMove (último movimiento ejecutado) y las
##   estadísticas del Pokémon ACTIVO, no con las del candidato; `move` solo aporta el tipo.
##   Por eso `dano_base` es único por rival.
## - bestDmg es u8: se trunca al guardar, pero se compara con el daño sin truncar.
static func mejor_relevo(ctx: Dictionary) -> int:
	var e: Dictionary = _excluidos(ctx)
	var flanco: int = 0
	if ctx.doble:
		flanco = (_r(ctx) & 2) / 2
		if ctx.rivales[flanco].ausente:
			flanco ^= 1
	var rival: Dictionary = ctx.rivales[flanco]
	var invalidos: int = 0
	while invalidos != 63:
		var mejor: int = 0
		var mejor_id: int = SIN_MON
		for i: int in 6:
			if _elegible(ctx, i, e) and invalidos & (1 << i) == 0:
				var mon: Dictionary = _miembro(ctx, i)
				var valor: int = 10
				valor = modular_por_tipo(rival.tipos[0], mon.tipos[0], mon.tipos[1], valor, ctx.tabla)
				valor = modular_por_tipo(rival.tipos[1], mon.tipos[0], mon.tipos[1], valor, ctx.tabla)
				if mejor < valor:
					mejor = valor
					mejor_id = i
			else:
				invalidos |= 1 << i
		if mejor_id != SIN_MON:
			for id: int in _miembro(ctx, mejor_id).moves:
				if id != 0 and type_calc(id, rival, 0, ctx).flags & SUPER_EFFECTIVE:
					return mejor_id
			invalidos |= 1 << mejor_id
		else:
			invalidos = 63
	var mejor_dano: int = 0
	var mejor_mon: int = SIN_MON
	for i: int in 6:
		if not _elegible(ctx, i, e):
			continue
		for id: int in _miembro(ctx, i).moves:
			var dano: int = 0
			if id != 0 and poder(id) != 1:
				dano = type_calc(id, rival, int(rival.dano_base), ctx).dano
			if mejor_dano < dano:
				mejor_dano = dano & 255
				mejor_mon = i
	return mejor_mon


## Rama de cambio de AI_TrySwitchOrUseItem: índice del relevo o -1 si no cambia.
static func decidir(ctx: Dictionary) -> int:
	var eleccion: int = debe_cambiar(ctx)
	if eleccion < 0:
		return -1
	if eleccion != SIN_MON:
		return eleccion
	return relevo_mas_adecuado(ctx)


## OpponentHandlecmd22 con AI_monToSwitchIntoId a 6: GetMostSuitable y, sin candidato,
## el primer miembro con PS que no esté en campo ni reservado. -1 si no queda ninguno.
## El valor guardado nunca sobrevive a una selección: B_ACTION_SWITCH lo consume al
## momento con esta misma orden, así que un relevo tras K.O. siempre llega aquí.
static func relevo_mas_adecuado(ctx: Dictionary) -> int:
	var eleccion: int = mejor_relevo(ctx)
	if eleccion != SIN_MON:
		return eleccion
	var e: Dictionary = _excluidos(ctx)
	for i: int in 6:
		if _elegible(ctx, i, e):
			return i
	return -1
