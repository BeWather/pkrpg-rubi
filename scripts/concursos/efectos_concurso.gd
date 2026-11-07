class_name EfectosConcurso
extends RefCounted
## Los 48 efectos de concurso de Rubí (src/contest_effect.c, gContestEffectFuncs) y las
## reglas de interferencia que comparten. Cada efecto actúa sobre el concursante
## `estado.actor` durante CalculateAppealMoveImpact, antes de sumar la condición.
## Reglas y casos raros: documentacion/20261027-concursos-pokeruby-nucleo.md §4.

## CONTEST_EFFECT_* (include/contest.h).
enum Efecto {
	HIGHLY_APPEALING,
	USER_MORE_EASILY_STARTLED,
	GREAT_APPEAL_BUT_NO_MORE_MOVES,
	REPETITION_NOT_BORING,
	AVOID_STARTLE_ONCE,
	AVOID_STARTLE,
	AVOID_STARTLE_SLIGHTLY,
	USER_LESS_EASILY_STARTLED,
	STARTLE_FRONT_MON,
	SLIGHTLY_STARTLE_PREV_MONS,
	STARTLE_PREV_MON,
	STARTLE_PREV_MONS,
	BADLY_STARTLE_FRONT_MON,
	BADLY_STARTLE_PREV_MONS,
	STARTLE_PREV_MON_2,
	STARTLE_PREV_MONS_2,
	SHIFT_JUDGE_ATTENTION,
	STARTLE_MON_WITH_JUDGES_ATTENTION,
	JAMS_OTHERS_BUT_MISS_ONE_TURN,
	STARTLE_MONS_SAME_TYPE_APPEAL,
	STARTLE_MONS_COOL_APPEAL,
	STARTLE_MONS_BEAUTY_APPEAL,
	STARTLE_MONS_CUTE_APPEAL,
	STARTLE_MONS_SMART_APPEAL,
	STARTLE_MONS_TOUGH_APPEAL,
	MAKE_FOLLOWING_MON_NERVOUS,
	MAKE_FOLLOWING_MONS_NERVOUS,
	WORSEN_CONDITION_OF_PREV_MONS,
	BADLY_STARTLES_MONS_IN_GOOD_CONDITION,
	BETTER_IF_FIRST,
	BETTER_IF_LAST,
	APPEAL_AS_GOOD_AS_PREV_ONES,
	APPEAL_AS_GOOD_AS_PREV_ONE,
	BETTER_WHEN_LATER,
	QUALITY_DEPENDS_ON_TIMING,
	BETTER_IF_SAME_TYPE,
	BETTER_IF_DIFF_TYPE,
	AFFECTED_BY_PREV_APPEAL,
	IMPROVE_CONDITION_PREVENT_NERVOUSNESS,
	BETTER_WITH_GOOD_CONDITION,
	NEXT_APPEAL_EARLIER,
	NEXT_APPEAL_LATER,
	MAKE_SCRAMBLING_TURN_ORDER_EASIER,
	SCRAMBLE_NEXT_TURN_ORDER,
	EXCITE_AUDIENCE_IN_ANY_CONTEST,
	BADLY_STARTLE_MONS_WITH_GOOD_APPEALS,
	BETTER_WHEN_AUDIENCE_EXCITED,
	DONT_EXCITE_AUDIENCE,
}

## CONTEST_STRING_* (include/contest.h): textos de resultado de gUnknown_083CC188.
enum Cadena {
	MORE_CONSCIOUS,
	NO_APPEAL,
	SETTLE_DOWN,
	OBLIVIOUS_TO_OTHERS,
	LESS_AWARE,
	STOPPED_CARING,
	STARTLE_ATTEMPT,
	DAZZLE_ATTEMPT,
	JUDGE_LOOK_AWAY2,
	UNNERVE_ATTEMPT,
	NERVOUS,
	UNNERVE_WAITING,
	TAUNT_WELL,
	REGAINED_FORM,
	JAM_WELL,
	HUSTLE_STANDOUT,
	WORK_HARD_UNNOTICED,
	WORK_BEFORE,
	APPEAL_NOT_WELL,
	WORK_PRECEDING,
	APPEAL_NOT_WELL2,
	APPEAL_NOT_SHOWN_WELL,
	APPEAL_SLIGHTLY_WELL,
	APPEAL_PRETTY_WELL,
	APPEAL_EXCELLENTLY,
	APPEAL_DUD,
	APPEAL_NOT_VERY_WELL,
	APPEAL_SLIGHTLY_WELL2,
	APPEAL_PRETTY_WELL2,
	APPEAL_VERY_WELL,
	APPEAL_EXCELLENTLY2,
	SAME_TYPE_GOOD,
	DIFF_TYPE_GOOD,
	STOOD_OUT_AS_MUCH,
	NOT_AS_WELL,
	CONDITION_ROSE,
	HOT_STATUS,
	MOVE_UP_LINE,
	MOVE_BACK_LINE,
	SCRAMBLE_ORDER,
	JUDGE_EXPECTANTLY2,
	WENT_OVER_WELL,
	WENT_OVER_VERY_WELL,
	APPEAL_COMBO_EXCELLENTLY,
	AVERT_GAZE,
	AVOID_SEEING,
	NOT_FAZED,
	LITTLE_DISTRACTED,
	ATTEMPT_STARTLE,
	LOOKED_DOWN,
	TURNED_BACK,
	UTTER_CRY,
	LEAPT_UP,
	TRIPPED_OVER,
	MESSED_UP2,
	FAILED_TARGET_NERVOUS,
	FAILED_ANYONE_NERVOUS,
	IGNORED,
	NO_CONDITION_IMPROVE,
	BAD_CONDITION_WEAK_APPEAL,
	UNAFFECTED,
	ATTRACTED_ATTENTION,
	NINGUNA = 255,
}

var estado: EstadoConcurso
var datos: DatosConcurso
var aleatorio: AleatorioConcurso
var _funciones: Array[Callable] = []


func _init(estado_concurso: EstadoConcurso, datos_concurso: DatosConcurso, rng: AleatorioConcurso) -> void:
	estado = estado_concurso
	datos = datos_concurso
	aleatorio = rng
	# gContestEffectFuncs: 8/10/12 y 9/11/13 comparten función; solo cambia el jam de la tabla.
	_funciones = [
		_highly_appealing, _user_more_easily_startled, _great_appeal_but_no_more_moves,
		_repetition_not_boring, _avoid_startle_once, _avoid_startle, _avoid_startle_slightly,
		_user_less_easily_startled, _startle_front_mon, _startle_prev_mons, _startle_front_mon,
		_startle_prev_mons, _startle_front_mon, _startle_prev_mons, _startle_prev_mon_2,
		_startle_prev_mons_2, _shift_judge_attention, _startle_mon_with_judges_attention,
		_jams_others_but_miss_one_turn, _startle_mons_same_type_appeal, _startle_mons_cool_appeal,
		_startle_mons_beauty_appeal, _startle_mons_cute_appeal, _startle_mons_smart_appeal,
		_startle_mons_tough_appeal, _make_following_mon_nervous, _make_following_mons_nervous,
		_worsen_condition_of_prev_mons, _badly_startles_mons_in_good_condition, _better_if_first,
		_better_if_last, _appeal_as_good_as_prev_ones, _appeal_as_good_as_prev_one,
		_better_when_later, _quality_depends_on_timing, _better_if_same_type, _better_if_diff_type,
		_affected_by_prev_appeal, _improve_condition_prevent_nervousness, _better_with_good_condition,
		_next_appeal_earlier, _next_appeal_later, _make_scrambling_turn_order_easier,
		_scramble_next_turn_order, _excite_audience_in_any_contest,
		_badly_startle_mons_with_good_appeals, _better_when_audience_excited, _dont_excite_audience,
	]


## gContestEffectFuncs[efecto]().
func aplicar(efecto: int) -> void:
	if efecto >= 0 and efecto < _funciones.size():
		_funciones[efecto].call()


# === Utilidades ===

func _c(i: int) -> ConcursanteConcurso:
	return estado.concursantes[i]


func _actor() -> ConcursanteConcurso:
	return estado.concursantes[estado.actor]


func _pos_actor() -> int:
	return estado.orden[estado.actor]


## Atractivo de la tabla del efecto del movimiento actual del actor.
func _atractivo_tabla_actor() -> int:
	return datos.atractivo_efecto(datos.efecto(_actor().mov_actual))


## SetContestantEffectStringID / SetContestantEffectStringID2.
func poner_cadena(i: int, cadena: int) -> void:
	_c(i).cadena = cadena


func poner_cadena2(i: int, cadena: int) -> void:
	_c(i).cadena2 = cadena


## MakeContestantNervous.
func poner_nervioso(i: int) -> void:
	_c(i).nervioso = true
	_c(i).mov_actual = DatosConcurso.MOVIMIENTO_NINGUNO


## CanUnnerveContestant: marca el icono y consume la protección de un uso.
func puede_afectar(i: int) -> bool:
	estado.marcados[i] = true
	var c := _c(i)
	if c.inmune:
		poner_cadena(i, Cadena.AVOID_SEEING)
		return false
	if c.protecciones != 0:
		c.protecciones -= 1
		poner_cadena(i, Cadena.AVERT_GAZE)
		return false
	return not c.sin_mas_turnos and c.turnos_saltados == 0


## WasAtLeastOneOpponentJammed con la cola `objetivos`: aplica estado.interferencia.
func interferir(objetivos: Array[int]) -> bool:
	var alguno: bool = false
	for i in objetivos:
		if not puede_afectar(i):
			continue
		var c := _c(i)
		estado.interferencia2 = estado.interferencia
		if c.mas_asustadizo:
			estado.interferencia2 *= 2
		if c.resistente:
			estado.interferencia2 = 10
			poner_cadena(i, Cadena.LITTLE_DISTRACTED)
		else:
			estado.interferencia2 -= c.reduccion_interferencia
			if estado.interferencia2 <= 0:
				estado.interferencia2 = 0
				poner_cadena(i, Cadena.NOT_FAZED)
			else:
				c.atractivo -= estado.interferencia2
				c.interferencia_recibida += estado.interferencia2
				_cadena_sobresalto(i, estado.interferencia2)
				alguno = true
	return alguno


## SetStartledString.
func _cadena_sobresalto(i: int, jam: int) -> void:
	if jam >= 60:
		poner_cadena(i, Cadena.TRIPPED_OVER)
	elif jam >= 40:
		poner_cadena(i, Cadena.LEAPT_UP)
	elif jam >= 30:
		poner_cadena(i, Cadena.UTTER_CRY)
	elif jam >= 20:
		poner_cadena(i, Cadena.TURNED_BACK)
	elif jam >= 10:
		poner_cadena(i, Cadena.LOOKED_DOWN)


## Concursantes que ya actuaron en esta apelación, en orden de índice.
func _anteriores() -> Array[int]:
	var lista: Array[int] = []
	for i in EstadoConcurso.NUM_CONCURSANTES:
		if _pos_actor() > estado.orden[i]:
			lista.append(i)
	return lista


## El que actuó justo antes (o -1 si el actor es el primero). Si no hay nadie en
## esa posición devuelve 4, como el bucle de pokeruby.
func _anterior_inmediato() -> int:
	if _pos_actor() == 0:
		return -1
	for i in EstadoConcurso.NUM_CONCURSANTES:
		if _pos_actor() - 1 == estado.orden[i]:
			return i
	return EstadoConcurso.NUM_CONCURSANTES


## RoundTowardsZero (en realidad redondea hacia −∞ en negativos: −15 → −20).
static func redondear_abajo(valor: int) -> int:
	var resto: int = absi(valor) % 10
	if valor < 0:
		if resto != 0:
			valor -= 10 - resto
	else:
		valor -= resto
	return valor


## RoundUp: al múltiplo de 10 superior en valor absoluto.
static func redondear_arriba(valor: int) -> int:
	var resto: int = absi(valor) % 10
	if resto != 0:
		valor += 10 - resto
	return valor


# === Efectos ===

func _highly_appealing() -> void:
	pass


func _user_more_easily_startled() -> void:
	_actor().mas_asustadizo = true
	poner_cadena(estado.actor, Cadena.MORE_CONSCIOUS)


func _great_appeal_but_no_more_moves() -> void:
	_actor().exploto = true
	poner_cadena(estado.actor, Cadena.NO_APPEAL)


func _repetition_not_boring() -> void:
	_actor().repitio = false
	_actor().repeticiones = 0


func _avoid_startle_once() -> void:
	_actor().protecciones = 1
	poner_cadena(estado.actor, Cadena.SETTLE_DOWN)


func _avoid_startle() -> void:
	_actor().inmune = true
	poner_cadena(estado.actor, Cadena.OBLIVIOUS_TO_OTHERS)


func _avoid_startle_slightly() -> void:
	_actor().reduccion_interferencia = 20
	poner_cadena(estado.actor, Cadena.LESS_AWARE)


func _user_less_easily_startled() -> void:
	_actor().resistente = true
	poner_cadena(estado.actor, Cadena.STOPPED_CARING)


func _startle_front_mon() -> void:
	var alguno: bool = false
	if _pos_actor() != 0:
		var objetivo: int = _anterior_inmediato()
		if objetivo < EstadoConcurso.NUM_CONCURSANTES:
			alguno = interferir([objetivo])
	if not alguno:
		poner_cadena2(estado.actor, Cadena.MESSED_UP2)
	poner_cadena(estado.actor, Cadena.ATTEMPT_STARTLE)


func _startle_prev_mons() -> void:
	var alguno: bool = false
	if _pos_actor() != 0:
		alguno = interferir(_anteriores())
	if not alguno:
		poner_cadena2(estado.actor, Cadena.MESSED_UP2)
	poner_cadena(estado.actor, Cadena.ATTEMPT_STARTLE)


func _startle_prev_mon_2() -> void:
	var r: int = aleatorio.modulo(10)
	if r < 2:
		estado.interferencia = 20
	elif r < 8:
		estado.interferencia = 40
	else:
		estado.interferencia = 60
	_startle_front_mon()


func _startle_prev_mons_2() -> void:
	var sobresaltados: int = 0
	if _pos_actor() != 0:
		for i in _anteriores():
			var r: int = aleatorio.modulo(10)
			if r == 0:
				estado.interferencia = 0
			elif r <= 2:
				estado.interferencia = 10
			elif r <= 4:
				estado.interferencia = 20
			elif r <= 6:
				estado.interferencia = 30
			elif r <= 8:
				estado.interferencia = 40
			else:
				estado.interferencia = 60
			if interferir([i]):
				sobresaltados += 1
	poner_cadena(estado.actor, Cadena.ATTEMPT_STARTLE)
	if sobresaltados == 0:
		poner_cadena2(estado.actor, Cadena.MESSED_UP2)


func _shift_judge_attention() -> void:
	var alguno: bool = false
	if _pos_actor() != 0:
		for i in EstadoConcurso.NUM_CONCURSANTES:
			if _pos_actor() > estado.orden[i] and _c(i).atencion_juez and puede_afectar(i):
				_c(i).atencion_juez = false
				_c(i).atencion_retirada = true
				poner_cadena(i, Cadena.JUDGE_LOOK_AWAY2)
				alguno = true
	poner_cadena(estado.actor, Cadena.DAZZLE_ATTEMPT)
	if not alguno:
		poner_cadena2(estado.actor, Cadena.MESSED_UP2)


func _startle_mon_with_judges_attention() -> void:
	var sobresaltados: int = 0
	if _pos_actor() != 0:
		for i in _anteriores():
			estado.interferencia = 50 if _c(i).atencion_juez else 10
			if interferir([i]):
				sobresaltados += 1
	poner_cadena(estado.actor, Cadena.ATTEMPT_STARTLE)
	if sobresaltados == 0:
		poner_cadena2(estado.actor, Cadena.MESSED_UP2)


func _jams_others_but_miss_one_turn() -> void:
	_actor().saltara_turno = true
	_startle_prev_mons()
	poner_cadena(estado.actor, Cadena.ATTEMPT_STARTLE)


func _startle_mons_same_type_appeal() -> void:
	_interferir_por_categoria(datos.categoria(_actor().mov_actual))
	poner_cadena(estado.actor, Cadena.ATTEMPT_STARTLE)


func _startle_mons_cool_appeal() -> void:
	_interferir_por_categoria(Movimiento.CategoriaConcurso.CARISMA)
	poner_cadena(estado.actor, Cadena.ATTEMPT_STARTLE)


func _startle_mons_beauty_appeal() -> void:
	_interferir_por_categoria(Movimiento.CategoriaConcurso.BELLEZA)
	poner_cadena(estado.actor, Cadena.ATTEMPT_STARTLE)


func _startle_mons_cute_appeal() -> void:
	_interferir_por_categoria(Movimiento.CategoriaConcurso.DULZURA)
	poner_cadena(estado.actor, Cadena.ATTEMPT_STARTLE)


func _startle_mons_smart_appeal() -> void:
	_interferir_por_categoria(Movimiento.CategoriaConcurso.INGENIO)
	poner_cadena(estado.actor, Cadena.ATTEMPT_STARTLE)


func _startle_mons_tough_appeal() -> void:
	_interferir_por_categoria(Movimiento.CategoriaConcurso.DUREZA)
	poner_cadena(estado.actor, Cadena.ATTEMPT_STARTLE)


## JamByMoveCategory.
func _interferir_por_categoria(categoria: int) -> void:
	var sobresaltados: int = 0
	for i in _anteriores():
		estado.interferencia = 40 if categoria == datos.categoria(_c(i).mov_actual) else 10
		if interferir([i]):
			sobresaltados += 1
	if sobresaltados == 0:
		poner_cadena2(estado.actor, Cadena.MESSED_UP2)


func _make_following_mon_nervous() -> void:
	var alguno: bool = false
	if _pos_actor() != 3:
		for i in EstadoConcurso.NUM_CONCURSANTES:
			if _pos_actor() + 1 == estado.orden[i]:
				if puede_afectar(i):
					poner_nervioso(i)
					poner_cadena(i, Cadena.NERVOUS)
				else:
					poner_cadena(i, Cadena.UNAFFECTED)
				alguno = true
	poner_cadena(estado.actor, Cadena.UNNERVE_ATTEMPT)
	if not alguno:
		poner_cadena2(estado.actor, Cadena.MESSED_UP2)


@warning_ignore("integer_division")
func _make_following_mons_nervous() -> void:
	var candidatos: Array[int] = []
	for i in EstadoConcurso.NUM_CONCURSANTES:
		if _pos_actor() < estado.orden[i] and not _c(i).nervioso and not _c(i).turno_deshabilitado():
			candidatos.append(i)
	var prob: Array[int] = [0, 0, 0, 0]
	match candidatos.size():
		1: prob = [60, 0, 0, 0]
		2: prob = [30, 30, 0, 0]
		3: prob = [20, 20, 20, 0]
	var modificador: Array[int] = [0, 0, 0, 0]
	for i in EstadoConcurso.NUM_CONCURSANTES:
		var c := _c(i)
		if c.atencion_juez and c.puede_combo():
			# gComboStarterLookupTable[...] * 10: 10 si su movimiento anterior inicia combo.
			modificador[i] = (1 if datos.combo_inicio(c.mov_previo) != 0 else 0) * 10
		modificador[i] -= (c.condicion / 10) * 10
	var afectados: int = 0
	if prob[0] != 0:
		for k in candidatos.size():
			var i: int = candidatos[k]
			var sin_efecto: bool = false
			if aleatorio.modulo(100) < prob[k] + modificador[i]:
				if puede_afectar(i):
					poner_nervioso(i)
					poner_cadena(i, Cadena.NERVOUS)
					afectados += 1
				else:
					sin_efecto = true
			else:
				sin_efecto = true
			if sin_efecto:
				poner_cadena(i, Cadena.UNAFFECTED)
				afectados += 1
			estado.marcados[i] = true
	poner_cadena(estado.actor, Cadena.UNNERVE_WAITING)
	if afectados == 0:
		poner_cadena2(estado.actor, Cadena.MESSED_UP2)


func _worsen_condition_of_prev_mons() -> void:
	var alcanzados: int = 0
	for i in EstadoConcurso.NUM_CONCURSANTES:
		if _pos_actor() > estado.orden[i] and _c(i).condicion > 0 and puede_afectar(i):
			_c(i).condicion = 0
			_c(i).mod_condicion = 2
			poner_cadena(i, Cadena.REGAINED_FORM)
			alcanzados += 1
	poner_cadena(estado.actor, Cadena.TAUNT_WELL)
	if alcanzados == 0:
		poner_cadena2(estado.actor, Cadena.IGNORED)


func _badly_startles_mons_in_good_condition() -> void:
	var alcanzados: int = 0
	for i in _anteriores():
		estado.interferencia = 40 if _c(i).condicion > 0 else 10
		if interferir([i]):
			alcanzados += 1
	poner_cadena(estado.actor, Cadena.JAM_WELL)
	if alcanzados == 0:
		poner_cadena2(estado.actor, Cadena.IGNORED)


func _better_if_first() -> void:
	if _pos_actor() == 0:
		_actor().atractivo += 2 * _atractivo_tabla_actor()
		poner_cadena(estado.actor, Cadena.HUSTLE_STANDOUT)


func _better_if_last() -> void:
	if _pos_actor() == 3:
		_actor().atractivo += 2 * _atractivo_tabla_actor()
		poner_cadena(estado.actor, Cadena.WORK_HARD_UNNOTICED)


@warning_ignore("integer_division")
func _appeal_as_good_as_prev_ones() -> void:
	var suma: int = 0
	for i in _anteriores():
		suma += _c(i).atractivo
	if suma < 0:
		suma = 0
	if _pos_actor() == 0 or suma == 0:
		poner_cadena(estado.actor, Cadena.APPEAL_NOT_WELL)
	else:
		_actor().atractivo += suma / 2
		poner_cadena(estado.actor, Cadena.WORK_BEFORE)
	_actor().atractivo = redondear_abajo(_actor().atractivo)


func _appeal_as_good_as_prev_one() -> void:
	var previo: int = 0
	var anterior: int = _anterior_inmediato()
	if anterior >= 0 and anterior < EstadoConcurso.NUM_CONCURSANTES:
		previo = _c(anterior).atractivo
	if _pos_actor() == 0 or previo <= 0:
		poner_cadena(estado.actor, Cadena.APPEAL_NOT_WELL2)
	else:
		_actor().atractivo += previo
		poner_cadena(estado.actor, Cadena.WORK_PRECEDING)


func _better_when_later() -> void:
	var turno: int = _pos_actor()
	_actor().atractivo = 10 if turno == 0 else 20 * turno
	match turno:
		0: poner_cadena(estado.actor, Cadena.APPEAL_NOT_SHOWN_WELL)
		1: poner_cadena(estado.actor, Cadena.APPEAL_SLIGHTLY_WELL)
		2: poner_cadena(estado.actor, Cadena.APPEAL_PRETTY_WELL)
		_: poner_cadena(estado.actor, Cadena.APPEAL_EXCELLENTLY)


func _quality_depends_on_timing() -> void:
	var r: int = aleatorio.modulo(10)
	var valor: int
	if r < 3:
		valor = 10
		poner_cadena(estado.actor, Cadena.APPEAL_NOT_VERY_WELL)
	elif r < 6:
		valor = 20
		poner_cadena(estado.actor, Cadena.APPEAL_SLIGHTLY_WELL2)
	elif r < 8:
		valor = 40
		poner_cadena(estado.actor, Cadena.APPEAL_PRETTY_WELL2)
	elif r < 9:
		valor = 60
		poner_cadena(estado.actor, Cadena.APPEAL_VERY_WELL)
	else:
		valor = 80
		poner_cadena(estado.actor, Cadena.APPEAL_EXCELLENTLY2)
	_actor().atractivo = valor


func _better_if_same_type() -> void:
	var turno: int = _pos_actor()
	if turno == 0:
		return
	# Busca hacia atrás el primero que sí actuó (salta nerviosos y deshabilitados).
	var posicion: int = turno - 1
	var anterior: int = -1
	while true:
		anterior = estado.concursante_en(posicion)
		if anterior < 0:
			return
		var c := _c(anterior)
		if c.sin_mas_turnos or c.nervioso or c.turnos_saltados != 0:
			posicion -= 1
			if posicion < 0:
				return
		else:
			break
	if datos.categoria(_actor().mov_actual) == datos.categoria(_c(anterior).mov_actual):
		_actor().atractivo += _atractivo_tabla_actor() * 2
		poner_cadena(estado.actor, Cadena.SAME_TYPE_GOOD)


func _better_if_diff_type() -> void:
	var anterior: int = _anterior_inmediato()
	if anterior >= 0 and anterior < EstadoConcurso.NUM_CONCURSANTES \
			and datos.categoria(_actor().mov_actual) != datos.categoria(_c(anterior).mov_actual):
		_actor().atractivo += _atractivo_tabla_actor() * 2
		poner_cadena(estado.actor, Cadena.DIFF_TYPE_GOOD)


## Compara su appeal (sin la condición, que aún no se ha sumado) con el appeal final
## del anterior.
func _affected_by_prev_appeal() -> void:
	var anterior: int = _anterior_inmediato()
	if anterior < 0 or anterior >= EstadoConcurso.NUM_CONCURSANTES:
		return
	if _actor().atractivo > _c(anterior).atractivo:
		_actor().atractivo *= 2
		poner_cadena(estado.actor, Cadena.STOOD_OUT_AS_MUCH)
	elif _actor().atractivo < _c(anterior).atractivo:
		_actor().atractivo = 0
		poner_cadena(estado.actor, Cadena.NOT_AS_WELL)


func _improve_condition_prevent_nervousness() -> void:
	if _actor().condicion < 30:
		_actor().condicion += 10
		_actor().mod_condicion = 1
		poner_cadena(estado.actor, Cadena.CONDITION_ROSE)
	else:
		poner_cadena(estado.actor, Cadena.NO_CONDITION_IMPROVE)


func _better_with_good_condition() -> void:
	_actor().condicion_triple = true
	if _actor().condicion != 0:
		poner_cadena(estado.actor, Cadena.HOT_STATUS)
	else:
		poner_cadena(estado.actor, Cadena.BAD_CONDITION_WEAK_APPEAL)


func _next_appeal_earlier() -> void:
	if estado.numero_apelacion == EstadoConcurso.NUM_APELACIONES - 1:
		return
	var orden: Array[int] = []
	for c in estado.concursantes:
		orden.append(c.orden_siguiente)
	orden[estado.actor] = ConcursanteConcurso.ORDEN_LIBRE
	# Empuja hacia atrás, en cadena, a quien ya tenía fijada la posición 0, 1...
	for i in EstadoConcurso.NUM_CONCURSANTES:
		var j: int = 0
		while j < EstadoConcurso.NUM_CONCURSANTES:
			if j != estado.actor and i == orden[j] and orden[j] == _c(j).orden_siguiente:
				orden[j] = (orden[j] + 1) & 0xFF
				break
			j += 1
		if j == EstadoConcurso.NUM_CONCURSANTES:
			break
	orden[estado.actor] = 0
	_actor().mod_orden = 1
	for i in EstadoConcurso.NUM_CONCURSANTES:
		_c(i).orden_siguiente = orden[i]
	_actor().accion_orden = 1
	poner_cadena(estado.actor, Cadena.MOVE_UP_LINE)


func _next_appeal_later() -> void:
	if estado.numero_apelacion == EstadoConcurso.NUM_APELACIONES - 1:
		return
	var orden: Array[int] = []
	for c in estado.concursantes:
		orden.append(c.orden_siguiente)
	orden[estado.actor] = ConcursanteConcurso.ORDEN_LIBRE
	var i: int = 3
	while i > -1:
		var j: int = 0
		while j < EstadoConcurso.NUM_CONCURSANTES:
			if j != estado.actor and i == orden[j] and orden[j] == _c(j).orden_siguiente:
				orden[j] = (orden[j] - 1) & 0xFF
				break
			j += 1
		if j == EstadoConcurso.NUM_CONCURSANTES:
			break
		i -= 1
	orden[estado.actor] = 3
	_actor().mod_orden = 1
	for k in EstadoConcurso.NUM_CONCURSANTES:
		_c(k).orden_siguiente = orden[k]
	_actor().accion_orden = 2
	poner_cadena(estado.actor, Cadena.MOVE_BACK_LINE)


func _make_scrambling_turn_order_easier() -> void:
	pass  # Vacío en pokeruby («dummied out?») y sin movimientos que lo usen.


func _scramble_next_turn_order() -> void:
	if estado.numero_apelacion == EstadoConcurso.NUM_APELACIONES - 1:
		return
	var orden: Array[int] = []
	var libres: Array[bool] = [true, true, true, true]
	for c in estado.concursantes:
		orden.append(c.orden_siguiente)
	for i in EstadoConcurso.NUM_CONCURSANTES:
		var r: int = aleatorio.modulo(4 - i)
		for j in EstadoConcurso.NUM_CONCURSANTES:
			if libres[j]:
				if r == 0:
					orden[j] = i
					libres[j] = false
					break
				r -= 1
	for i in EstadoConcurso.NUM_CONCURSANTES:
		_c(i).orden_siguiente = orden[i]
		_c(i).mod_orden = 2
	_actor().accion_orden = 3
	poner_cadena(estado.actor, Cadena.SCRAMBLE_ORDER)


func _excite_audience_in_any_contest() -> void:
	if datos.categoria(_actor().mov_actual) != estado.categoria:
		_actor().emocion_forzada = true


@warning_ignore("integer_division")
func _badly_startle_mons_with_good_appeals() -> void:
	var alcanzados: int = 0
	for i in _anteriores():
		if _c(i).atractivo > 0:
			estado.interferencia = redondear_arriba(_c(i).atractivo / 2)
		else:
			estado.interferencia = 10
		if interferir([i]):
			alcanzados += 1
	if alcanzados == 0:
		poner_cadena2(estado.actor, Cadena.MESSED_UP2)
	poner_cadena(estado.actor, Cadena.ATTEMPT_STARTLE)


func _better_when_audience_excited() -> void:
	var valor: int
	match estado.aplausos:
		0:
			valor = 10
			poner_cadena(estado.actor, Cadena.APPEAL_NOT_VERY_WELL)
		1:
			valor = 20
			poner_cadena(estado.actor, Cadena.APPEAL_SLIGHTLY_WELL2)
		2:
			valor = 30
			poner_cadena(estado.actor, Cadena.APPEAL_PRETTY_WELL2)
		3:
			valor = 50
			poner_cadena(estado.actor, Cadena.APPEAL_VERY_WELL)
		_:
			valor = 60
			poner_cadena(estado.actor, Cadena.APPEAL_EXCELLENTLY2)
	_actor().atractivo = valor


func _dont_excite_audience() -> void:
	if not estado.emocion_congelada:
		estado.emocion_congelada = true
		estado.congelador = estado.actor
		poner_cadena(estado.actor, Cadena.ATTRACTED_ATTENTION)
