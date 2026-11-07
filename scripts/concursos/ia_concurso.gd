class_name IAConcurso
extends RefCounted
## IA de los rivales de concurso (src/contest_ai.c + data/contest_ai_scripts.s).
## Cada movimiento empieza con 100 puntos; los scripts de los bits activos de
## `ia_flags` suman o restan (con saturación 0..255) y se elige al azar, de forma
## uniforme, entre los movimientos con la puntuación máxima.
##
## Los 7 scripts útiles están portados etiqueta a etiqueta, incluidos sus saltos
## raros (p. ej. ContestEffect_FollowingMonsNervous, que salta dentro de la rutina
## de ContestEffect16or17). Los bits 7..31 (CONTEST_AI_DUMMY_*) apuntan a AI_Nothing.
## En los scripts, «MON_n» es la posición de actuación, no el índice del concursante.
##
## Bugs del original (documentacion/20261027-concursos-pokeruby-ia-flujo-resultados.md §1.6):
## - `if_random p` lee scriptArr fuera de rango (comportamiento indefinido): aquí
##   salta con probabilidad p/256, como el UBFIX de pokeemerald.
## - `if_effect_in_user_moveset EFECTO` compara el número de movimiento con el de
##   efecto: con COMPARA_EFECTO_REAL = false se conserva (pregunta si conoce
##   GOLPE CABEZA, CORNADA o LÁTIGO); con true compara el efecto.

## AI_CheckForBadMove: efectos que afectan al de justo delante (ContestEffect2_8)...
const MALOS_SI_NADIE_DELANTE: Array[int] = [
	EfectosConcurso.Efecto.STARTLE_FRONT_MON,
	EfectosConcurso.Efecto.STARTLE_PREV_MON,
	EfectosConcurso.Efecto.BADLY_STARTLE_FRONT_MON,
	EfectosConcurso.Efecto.STARTLE_PREV_MON_2,
	EfectosConcurso.Efecto.APPEAL_AS_GOOD_AS_PREV_ONE,
	EfectosConcurso.Efecto.BETTER_IF_SAME_TYPE,
	EfectosConcurso.Efecto.BETTER_IF_DIFF_TYPE,
	EfectosConcurso.Efecto.AFFECTED_BY_PREV_APPEAL,
]
## ...a todos los de delante (ContestEffect2_9)...
const MALOS_SI_NADIE_ANTES: Array[int] = [
	EfectosConcurso.Efecto.SLIGHTLY_STARTLE_PREV_MONS,
	EfectosConcurso.Efecto.STARTLE_PREV_MONS,
	EfectosConcurso.Efecto.BADLY_STARTLE_PREV_MONS,
	EfectosConcurso.Efecto.STARTLE_PREV_MONS_2,
	EfectosConcurso.Efecto.STARTLE_MON_WITH_JUDGES_ATTENTION,
	EfectosConcurso.Efecto.SHIFT_JUDGE_ATTENTION,
	EfectosConcurso.Efecto.JAMS_OTHERS_BUT_MISS_ONE_TURN,
	EfectosConcurso.Efecto.STARTLE_MONS_SAME_TYPE_APPEAL,
	EfectosConcurso.Efecto.BADLY_STARTLE_MONS_WITH_GOOD_APPEALS,
	EfectosConcurso.Efecto.STARTLE_MONS_COOL_APPEAL,
	EfectosConcurso.Efecto.STARTLE_MONS_BEAUTY_APPEAL,
	EfectosConcurso.Efecto.STARTLE_MONS_CUTE_APPEAL,
	EfectosConcurso.Efecto.STARTLE_MONS_SMART_APPEAL,
	EfectosConcurso.Efecto.STARTLE_MONS_TOUGH_APPEAL,
	EfectosConcurso.Efecto.BADLY_STARTLES_MONS_IN_GOOD_CONDITION,
	EfectosConcurso.Efecto.WORSEN_CONDITION_OF_PREV_MONS,
	EfectosConcurso.Efecto.APPEAL_AS_GOOD_AS_PREV_ONES,
]
## ...y a los de detrás (ContestEffect2_26 y ContestEffect2_4).
const MALOS_SI_NADIE_DETRAS: Array[int] = [
	EfectosConcurso.Efecto.MAKE_FOLLOWING_MONS_NERVOUS,
	EfectosConcurso.Efecto.DONT_EXCITE_AUDIENCE,
	EfectosConcurso.Efecto.AVOID_STARTLE_ONCE,
	EfectosConcurso.Efecto.AVOID_STARTLE,
	EfectosConcurso.Efecto.AVOID_STARTLE_SLIGHTLY,
]
## AI_CheckOrder.
const BUENOS_TERCERO: Array[int] = [
	EfectosConcurso.Efecto.BETTER_WHEN_LATER,
	EfectosConcurso.Efecto.APPEAL_AS_GOOD_AS_PREV_ONES,
	EfectosConcurso.Efecto.USER_MORE_EASILY_STARTLED,
]
const BUENOS_ULTIMO: Array[int] = [
	EfectosConcurso.Efecto.BETTER_WHEN_LATER,
	EfectosConcurso.Efecto.BETTER_IF_LAST,
	EfectosConcurso.Efecto.APPEAL_AS_GOOD_AS_PREV_ONES,
	EfectosConcurso.Efecto.USER_MORE_EASILY_STARTLED,
]
const PUNTUACION_INICIAL: int = 100
const BITS_UTILES: int = 7

## Política del bug B2 de `if_effect_in_user_moveset` (false = Rubí).
static var compara_efecto_real: bool = false

var _motor: MotorConcurso
var _yo: int = 0
var _m: int = 0
var _puntos: Array[int] = [0, 0, 0, 0]


## ContestAI_ResetAI + ContestAI_GetActionToUse: hueco (0..3) que usará el rival.
func elegir_movimiento(motor: MotorConcurso, indice: int) -> int:
	_motor = motor
	_yo = indice
	_puntos = [PUNTUACION_INICIAL, PUNTUACION_INICIAL, PUNTUACION_INICIAL, PUNTUACION_INICIAL]
	var flags: int = _c(_yo).ia_flags
	for bit in BITS_UTILES:
		if flags & (1 << bit) == 0:
			continue
		for m in 4:
			_m = m
			if _mov(m) == 0:
				_puntos[m] = 0
				continue
			match bit:
				0: _bad_move()
				1: _combo()
				2: _boring()
				3: _excitement()
				4: _order()
				5: _good_move()
				6: _erratic()
	while true:
		var r: int = _motor.aleatorio.u16() & 3
		var maximo: bool = true
		for i in 4:
			if _puntos[r] < _puntos[i]:
				maximo = false
				break
		if maximo:
			return r
	return 0


## Puntuaciones de la última elección (para tests y depuración).
func puntuaciones() -> Array[int]:
	return _puntos.duplicate()


# === Consultas (ContestAICmd_*) ===

func _c(i: int) -> ConcursanteConcurso:
	return _motor.estado.concursantes[i]


func _mov(m: int) -> int:
	return _c(_yo).movimientos[m]


func _sumar(delta: int) -> void:
	_puntos[_m] = clampi(_puntos[_m] + delta, 0, 255)


## if_random p: true = salta (con probabilidad p/256).
func _azar(p: int) -> bool:
	return (_motor.aleatorio.u16() & 0xFF) < p


## get_turn: sContest.appealNumber (0..4).
func _turno() -> int:
	return _motor.estado.numero_apelacion


## get_excitement: sContest.applauseLevel.
func _aplausos() -> int:
	return _motor.estado.aplausos


## get_user_order: posición propia (0 = MON_1).
func _orden() -> int:
	return _motor.estado.orden[_yo]


## get_user_condition: estrellas propias (0..3).
@warning_ignore("integer_division")
func _condicion() -> int:
	return _c(_yo).condicion / 10


func _efecto() -> int:
	return _motor.datos.efecto(_mov(_m))


func _tipo_efecto() -> int:
	return _motor.datos.tipo_efecto(_efecto())


## get_move_excitement.
func _emocion() -> int:
	return _motor.emocion_movimiento(_mov(_m))


## get_move_used_count: 0 si no es el anterior; si no, repeticiones + 1.
func _veces_usado() -> int:
	if _mov(_m) != _c(_yo).mov_previo:
		return 0
	return _c(_yo).repeticiones + 1


## check_combo_starter: este movimiento abre un combo que cierra otro propio.
func _inicia_combo() -> bool:
	for i in 4:
		if _mov(i) != 0 and _motor.datos.son_combo(_mov(_m), _mov(i)) != 0:
			return true
	return false


## check_combo_finisher: otro movimiento propio abre un combo que cierra este.
func _termina_combo() -> bool:
	for i in 4:
		if _mov(i) != 0 and _motor.datos.son_combo(_mov(i), _mov(_m)) != 0:
			return true
	return false


## check_would_finish_combo.
func _completaria_combo() -> bool:
	var previo: int = _c(_yo).mov_previo
	return previo != 0 and _motor.datos.son_combo(previo, _mov(_m)) != 0


## sub_8128A7C: concursante en la posición `pos` (MON_1..MON_4 = 0..3).
func _en(pos: int) -> int:
	var i: int = _motor.estado.concursante_en(pos)
	return i if i >= 0 else 0


## get_condition MON_n.
@warning_ignore("integer_division")
func _condicion_en(pos: int) -> int:
	return _c(_en(pos)).condicion / 10


## get_used_combo_starter MON_n: su movimiento anterior abría combo.
func _uso_iniciador(pos: int) -> bool:
	var c := _c(_en(pos))
	return c.puede_combo() and _motor.datos.combo_inicio(c.mov_previo) != 0


## check_can_participate MON_n.
func _participa(pos: int) -> bool:
	return not _c(_en(pos)).turno_deshabilitado()


## contest_58 / get_val_812A188: completedComboFlag.
func _completo_combo(pos: int) -> bool:
	return _c(_en(pos)).completo_combo_alguna_vez


## check_for_exciting_move: algún movimiento propio con emoción +1.
func _tiene_mov_emocionante() -> bool:
	for i in 4:
		if _mov(i) != 0 and _motor.emocion_movimiento(_mov(i)) == 1:
			return true
	return false


## ContestAICmd_unk_85: ¿algún movimiento propio «con» ese efecto? (ver B2).
func _tiene_efecto(efecto: int) -> bool:
	for i in 4:
		if compara_efecto_real:
			if _mov(i) != 0 and _motor.datos.efecto(_mov(i)) == efecto:
				return true
		elif _mov(i) == efecto:
			return true
	return false


# === AI_CheckBoring ===

func _boring() -> void:
	if _efecto() == EfectosConcurso.Efecto.REPETITION_NOT_BORING:
		return
	match _veces_usado():
		1: _sumar(-5)
		2: _sumar(-15)
		3: _sumar(-20)
		4: _sumar(-25)


# === AI_CheckExcitement ===

func _excitement() -> void:
	var emocion: int = _emocion()
	if emocion < 0:
		if _aplausos() == 4:
			if _orden() != 0:
				if _azar(127):
					return
				_sumar(-10)
				return
			if _azar(51):
				return
			_sumar(20)
			return
		if _aplausos() == 3:
			if _orden() != 0:
				if _azar(127):
					return
				_sumar(10)
				return
			if _turno() == 4:
				_sumar(15)
				return
			if _azar(51):
				return
			_sumar(10)
			return
		if _tiene_mov_emocionante():
			return
		_sumar(15)
	elif emocion == 0:
		if _azar(127):
			return
		_sumar(10)
	elif emocion == 1:
		if _veces_usado() > 0 and _efecto() != EfectosConcurso.Efecto.REPETITION_NOT_BORING:
			return
		if _orden() == 0 and _aplausos() == 4:
			_sumar(30)
			return
		if _azar(100):
			return
		_sumar(10)


# === AI_CheckForCombo ===

func _combo() -> void:
	if _completaria_combo():
		_sumar(25)
		return
	# call AI_contest3F_081DC348
	if _veces_usado() == 0 and _inicia_combo():
		if _turno() == 4:
			if not _azar(125):
				_sumar(-15)
		else:
			match _orden():
				0:
					if not _azar(150):
						_sumar(10)
				1:
					if not _azar(125):
						_sumar(10)
				2:
					if not _azar(50):
						_sumar(10)
				3:
					_sumar(10)
	# call AI_contest45_081DC348
	if _termina_combo():
		_sumar(-10)


# === AI_CheckForGoodMove ===

func _good_move() -> void:
	match _efecto():
		EfectosConcurso.Efecto.BETTER_WITH_GOOD_CONDITION: _bueno_39()
		EfectosConcurso.Efecto.NEXT_APPEAL_EARLIER: _bueno_40_41(EfectosConcurso.Efecto.BETTER_IF_FIRST)
		EfectosConcurso.Efecto.NEXT_APPEAL_LATER: _bueno_40_41(EfectosConcurso.Efecto.BETTER_IF_LAST)
		EfectosConcurso.Efecto.REPETITION_NOT_BORING: _bueno_3()
		EfectosConcurso.Efecto.IMPROVE_CONDITION_PREVENT_NERVOUSNESS: _bueno_38()
		EfectosConcurso.Efecto.DONT_EXCITE_AUDIENCE: _bueno_47()
		EfectosConcurso.Efecto.APPEAL_AS_GOOD_AS_PREV_ONES: _bueno_31()
		EfectosConcurso.Efecto.APPEAL_AS_GOOD_AS_PREV_ONE: _bueno_32()
		EfectosConcurso.Efecto.BETTER_WHEN_AUDIENCE_EXCITED: _bueno_46()
		EfectosConcurso.Efecto.WORSEN_CONDITION_OF_PREV_MONS: _bueno_27()
		EfectosConcurso.Efecto.SHIFT_JUDGE_ATTENTION, EfectosConcurso.Efecto.STARTLE_MON_WITH_JUDGES_ATTENTION: _bueno_16_17()
		EfectosConcurso.Efecto.MAKE_FOLLOWING_MONS_NERVOUS: _bueno_nervios()
		EfectosConcurso.Efecto.JAMS_OTHERS_BUT_MISS_ONE_TURN: _bueno_18()


func _bueno_39() -> void:
	match _condicion():
		3:
			_sumar(20)
		2:
			if not _azar(125):
				_sumar(15)
		1:
			if not _azar(125):
				_sumar(5)
		0:
			_sumar(-20)


## ContestEffect40/41 (0x87 salta si NO tiene el movimiento).
func _bueno_40_41(efecto: int) -> void:
	if not _tiene_efecto(efecto):
		return
	if _azar(50):
		return
	_sumar(20)


func _bueno_3() -> void:
	if _orden() != 3:
		return
	if _azar(50):
		return
	_sumar(15)


func _bueno_38() -> void:
	if not _tiene_efecto(EfectosConcurso.Efecto.BETTER_WITH_GOOD_CONDITION):
		# ContestEffect38_contest04
		if _turno() == 4:
			_sumar(-10)
			return
		if _turno() == 0:
			if _azar(100):
				return
			_sumar(10)
			return
		if _veces_usado() == 1:
			return
		if _azar(125):
			return
		_sumar(10)
		return
	if _condicion() == 3:
		_sumar(-10)
		return
	if _azar(50):
		return
	_sumar(15)


func _bueno_47() -> void:
	if _veces_usado() == 1:
		return
	if _orden() == 0 or _orden() == 1:
		if _azar(127):
			return
		_sumar(10)
		return
	if _turno() != 4:
		return
	if _tiene_mov_emocionante():
		return
	if _aplausos() < 1:
		return
	_sumar(10)


func _bueno_31() -> void:
	match _orden():
		1: _sumar(5)
		2: _sumar(15)
		3: _sumar(20)


func _bueno_32() -> void:
	match _orden():
		0:
			_sumar(-10)
		1:
			if not _participa(0):
				return
			_sumar(5)
		2:
			if _participa(0):
				_sumar(5)
			if not _participa(1):
				return
			_sumar(5)
		3:
			if _participa(0):
				_sumar(5)
			if _participa(1):
				_sumar(5)
			if not _participa(2):
				return
			_sumar(5)


func _bueno_46() -> void:
	if _orden() == 0:
		if _turno() != 0:
			if _azar(125):
				return
			_sumar(-15)
			return
		if _aplausos() == 4:
			if _azar(125):
				return
			_sumar(20)
			return
		if _aplausos() == 3:
			if _azar(125):
				return
			_sumar(15)
		return
	if _orden() > 0:
		if _azar(178):
			return
		_sumar(10)


## ContestEffect27: recorre MON_1..MON_3 con saltos que no siempre miran la
## posición propia (literal).
func _bueno_27() -> void:
	if _orden() == 0:
		return
	# ContestEffect27_55_1
	var siguiente: bool = _bueno_27_paso(0, 1)
	if not siguiente:
		return
	siguiente = _bueno_27_paso(1, 2)
	if not siguiente:
		return
	# ContestEffect27_55_3
	if not _participa(2):
		return
	var estrellas: int = _condicion_en(2)
	if estrellas < 1 or estrellas > 3:
		return
	if _azar(125):
		return
	_sumar(5 * estrellas)


## Un tramo ContestEffect27_55_n: devuelve true si se pasa al siguiente.
func _bueno_27_paso(pos: int, limite: int) -> bool:
	if not _participa(pos) or _condicion_en(pos) == 0:
		return _orden() > limite
	var estrellas: int = _condicion_en(pos)
	if estrellas > 3:
		return false
	if _azar(125):
		return true
	_sumar(5 * estrellas)
	return _orden() > limite


## ContestEffect16or17.
func _bueno_16_17() -> void:
	if _orden() == 0:
		return
	if _atencion_tramo(0):
		return
	_atencion_0e_1()


## ContestEffect16or17_0E_1.
func _atencion_0e_1() -> void:
	if _orden() == 1:
		return
	if _atencion_tramo(1):
		return
	_atencion_0e_2()


## ContestEffect16or17_0E_2.
func _atencion_0e_2() -> void:
	if _orden() == 2:
		return
	_atencion_tramo(2)


## Un tramo de ContestEffect16or17: true si termina el script (sumó +2 y +8).
func _atencion_tramo(pos: int) -> bool:
	if not _participa(pos) or _uso_iniciador(pos):
		return false
	if _azar(125):
		return false
	_sumar(2)
	if not _completo_combo(pos):
		return false
	_sumar(8)
	return true


## ContestEffect_FollowingMonsNervous (salta a ContestEffect16or17_0E_1/0E_2).
func _bueno_nervios() -> void:
	if _orden() == 3:
		return
	# CheckMon4
	if _participa(3) and _uso_iniciador(3):
		_sumar(5)
		if _azar(125):
			_atencion_0e_1()
			return
		_sumar(5)
		return
	# CheckMon3
	if _orden() == 2:
		return
	if _participa(2) and _uso_iniciador(2):
		_sumar(5)
		if _azar(125):
			_atencion_0e_2()
			return
		_sumar(5)
		return
	# CheckMon2
	if _orden() == 1:
		return
	if not _participa(1) or not _uso_iniciador(1):
		return
	_sumar(5)
	if _azar(125):
		return
	_sumar(5)


func _bueno_18() -> void:
	if _turno() == 4:
		_sumar(5)
	match _orden():
		0:
			_sumar(-15)
		1:
			if not _azar(125):
				_sumar(-10)
		2:
			if not _azar(125):
				_sumar(5)
		3:
			if not _azar(125):
				_sumar(15)


# === AI_Erratic ===

func _erratic() -> void:
	var categoria: int = _motor.estado.categoria
	if categoria == Movimiento.CategoriaConcurso.DULZURA or categoria == Movimiento.CategoriaConcurso.INGENIO \
			or categoria == Movimiento.CategoriaConcurso.DUREZA:
		if _azar(125):
			return
		_sumar(10)


# === AI_CheckForBadMove ===

func _bad_move() -> void:
	var efecto: int = _efecto()
	if efecto in MALOS_SI_NADIE_DELANTE:
		_malo_anterior()
	elif efecto in MALOS_SI_NADIE_ANTES:
		_malo_anteriores()
	elif efecto == EfectosConcurso.Efecto.MAKE_FOLLOWING_MON_NERVOUS:
		_malo_siguiente()
	elif efecto in MALOS_SI_NADIE_DETRAS:
		_malo_siguientes()
	elif efecto == EfectosConcurso.Efecto.IMPROVE_CONDITION_PREVENT_NERVOUSNESS:
		if _condicion() >= 3:
			_sumar(-20)
	elif efecto == EfectosConcurso.Efecto.GREAT_APPEAL_BUT_NO_MORE_MOVES:
		_malo_explosion()


## ContestEffect2_8: afecta al de delante; inútil si es el primero o el de delante no actúa.
func _malo_anterior() -> void:
	if _orden() == 0:
		_sumar(-10)
		return
	if _participa(_orden() - 1):
		return
	_sumar(-10)


## ContestEffect2_9: afecta a los de delante; inútil si ninguno actúa.
func _malo_anteriores() -> void:
	if _orden() == 0:
		_sumar(-20)
		return
	for pos in _orden():
		if _participa(pos):
			return
	_sumar(-15)


## ContestEffect2_25: afecta al de detrás.
func _malo_siguiente() -> void:
	if _orden() == 3:
		_sumar(-10)
		return
	if _participa(_orden() + 1):
		return
	_sumar(-10)


## ContestEffect2_26 / ContestEffect2_4: afecta a los de detrás.
func _malo_siguientes() -> void:
	if _orden() == 3:
		_sumar(-10)
		return
	for pos in range(_orden() + 1, 4):
		if _participa(pos):
			return
	_sumar(-10)


## ContestEffect2_2.
func _malo_explosion() -> void:
	var probabilidades: Array[int] = [20, 40, 60, 80]
	var turno: int = _turno()
	if turno < 4:
		if _azar(probabilidades[turno]):
			return
		_sumar(-15)
	elif turno == 4:
		if _azar(20):
			return
		_sumar(20)


# === AI_CheckOrder ===

func _order() -> void:
	var efecto: int = _efecto()
	match _orden():
		0:
			if efecto == EfectosConcurso.Efecto.BETTER_IF_FIRST:
				_sumar(15)
			elif efecto == EfectosConcurso.Efecto.BETTER_WHEN_LATER:
				_sumar(-15)
			elif _tipo_efecto() == 1:
				if not _azar(100):
					_sumar(10)
		1:
			if efecto == EfectosConcurso.Efecto.BETTER_WHEN_LATER:
				_sumar(-5)
			elif _tipo_efecto() == 1:
				if not _azar(125):
					_sumar(10)
		2:
			if efecto in BUENOS_TERCERO:
				_sumar(5)
		3:
			if efecto in BUENOS_ULTIMO:
				_sumar(15)
			elif efecto == EfectosConcurso.Efecto.JAMS_OTHERS_BUT_MISS_ONE_TURN:
				_sumar(5)
			elif _tipo_efecto() == 1:
				_sumar(-10)
			elif _tipo_efecto() == 3:
				if not _azar(125):
					_sumar(10)
