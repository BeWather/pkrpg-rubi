class_name MotorConcurso
extends RefCounted
## Reglas de un concurso de Rubí sin UI: ronda 1 (condición), cinco apelaciones de
## cuatro turnos y puntuación final. Replica src/contest.c y src/contest_2.c:
## - `iniciar()`: CalculateRound1Points + ClearContestVars (orden inicial por ronda 1);
## - `elegir_movimientos()`: GetAllChosenMoves (jugador + IAConcurso);
## - `ejecutar_turno()`: CalculateAppealMoveImpact + la parte de reglas de Task_DoAppeals
##   (combo, repetición, público y medidor), que en Rubí vive en la tarea de
##   presentación y aquí se aplica antes de pasar al siguiente concursante;
## - `cerrar_apelacion()`: RankContestants + SetAttentionLevels +
##   SetContestantStatusesForNextRound;
## - `calcular_final()`: CalculateFinalScores + DetermineFinalStandings.
## Cada paso devuelve los EventoConcurso que la escena reproduce.

const CADENA_NINGUNA: int = EfectosConcurso.Cadena.NINGUNA

## Condiciones vecinas del pentágono para la ronda 1 (CalculateContestantRound1Points),
## por Movimiento.CategoriaConcurso: CARISMA → DUREZA y BELLEZA, BELLEZA → CARISMA y
## DULZURA, DULZURA → BELLEZA e INGENIO, INGENIO → DULZURA y DUREZA, DUREZA → INGENIO
## y CARISMA.
const VECINAS: Array = [[4, 1], [0, 2], [1, 3], [2, 4], [3, 0]]

## gContestExcitementTable[categoría del concurso][categoría del movimiento].
const TABLA_EMOCION: Array = [
	[1, 0, -1, -1, 0],
	[0, 1, 0, -1, -1],
	[-1, 0, 1, 0, -1],
	[-1, -1, 0, 1, 0],
	[0, -1, -1, 0, 1],
]

var estado: EstadoConcurso = EstadoConcurso.new()
var datos: DatosConcurso
var aleatorio: AleatorioConcurso
var efectos: EfectosConcurso
## Elige el movimiento de los rivales.
var ia: IAConcurso


func _init(datos_concurso: DatosConcurso = null, rng: AleatorioConcurso = null, ia_concurso: IAConcurso = null) -> void:
	datos = datos_concurso if datos_concurso != null else DatosConcurso.compartido()
	aleatorio = rng if rng != null else AleatorioConcurso.new()
	ia = ia_concurso if ia_concurso != null else IAConcurso.new()


## CalculateContestantRound1Points: principal + (vecina1 + vecina2 + brillo) / 2.
@warning_ignore("integer_division")
static func puntos_ronda1(c: ConcursanteConcurso, categoria: int) -> int:
	var vecinas: Array = VECINAS[categoria]
	return c.condicion_de(categoria) + (c.condicion_de(vecinas[0]) + c.condicion_de(vecinas[1]) + c.brillo) / 2


## Contest_GetMoveExcitement: +1, 0 o −1.
func emocion_movimiento(movimiento: int) -> int:
	return TABLA_EMOCION[estado.categoria][datos.categoria(movimiento)]


## Empieza un concurso: los 4 concursantes ya creados (el jugador en `indice_jugador`).
func iniciar(concursantes: Array[ConcursanteConcurso], categoria: int, nivel: int, indice_jugador: int = 3) -> void:
	estado = EstadoConcurso.new()
	estado.categoria = categoria
	estado.nivel = nivel
	estado.indice_jugador = indice_jugador
	estado.concursantes = concursantes
	for i in EstadoConcurso.NUM_CONCURSANTES:
		concursantes[i].reiniciar_estado()
		estado.puntos_ronda1[i] = puntos_ronda1(concursantes[i], categoria)
	efectos = EfectosConcurso.new(estado, datos, aleatorio)
	_ordenar(0)
	_aplicar_orden_siguiente()


func concursante(i: int) -> ConcursanteConcurso:
	return estado.concursantes[i]


func terminado() -> bool:
	return estado.terminado


## GetAllChosenMoves. `eleccion_jugador` es el hueco 0..3 que eligió el jugador.
func elegir_movimientos(eleccion_jugador: int) -> void:
	estado.eleccion_jugador = eleccion_jugador
	estado.numero_turno = 0
	for i in EstadoConcurso.NUM_CONCURSANTES:
		concursante(i).mov_actual = _movimiento_elegido(i)


## GetChosenMove.
func _movimiento_elegido(i: int) -> int:
	var c := concursante(i)
	if c.turno_deshabilitado():
		return DatosConcurso.MOVIMIENTO_NINGUNO
	if i == estado.indice_jugador:
		return c.movimientos[estado.eleccion_jugador]
	return c.movimientos[ia.elegir_movimiento(self, i)]


## Evento de inicio de apelación («¡Exhibición n.º N!»).
func evento_inicio_apelacion() -> EventoConcurso:
	return EventoConcurso.crear(EventoConcurso.Tipo.INICIO_APELACION, -1, {"apelacion": estado.numero_apelacion})


## Un turno completo: el concursante de la posición `numero_turno`.
func ejecutar_turno() -> Array[EventoConcurso]:
	var eventos: Array[EventoConcurso] = []
	var i: int = estado.concursante_en(estado.numero_turno)
	var c := concursante(i)
	calcular_impacto(i)
	if c.turno_deshabilitado():
		eventos.append(_ev(EventoConcurso.Tipo.OBSERVA, i))
		estado.numero_turno += 1
		return eventos
	eventos.append(_ev(EventoConcurso.Tipo.ENTRA, i))
	if c.nervioso:
		c.atencion_juez = false
		eventos.append(_ev(EventoConcurso.Tipo.NERVIOSO, i, {"movimiento": c.mov_actual}))
	else:
		_eventos_actuacion(i, eventos)
	if estado.aplausos > EstadoConcurso.NIVEL_APLAUSO_MAXIMO - 1:
		estado.aplausos = 0
		eventos.append(_ev(EventoConcurso.Tipo.MEDIDOR_REINICIADO, -1))
	eventos.append(_ev(EventoConcurso.Tipo.SALE, i))
	estado.numero_turno += 1
	return eventos


## Task_DoAppeals desde «X se exhibió con…» hasta la reacción del público.
func _eventos_actuacion(i: int, eventos: Array[EventoConcurso]) -> void:
	var c := concursante(i)
	eventos.append(_ev(EventoConcurso.Tipo.APELA, i, {"movimiento": c.mov_actual}))
	eventos.append(_ev(EventoConcurso.Tipo.ANIMACION, i, {"movimiento": c.mov_actual, "objetivo": c.objetivo_animacion}))
	var marcados: Array[int] = []
	for k in EstadoConcurso.NUM_CONCURSANTES:
		if estado.marcados[k]:
			marcados.append(k)
	eventos.append(_ev(EventoConcurso.Tipo.INTERFERIDOS, -1, {"concursantes": marcados}))
	# Estado 23: texto del actor y, si nadie más tiene texto pendiente, el segundo.
	if c.cadena != CADENA_NINGUNA:
		eventos.append(_ev_texto(i, c.cadena))
		c.cadena = CADENA_NINGUNA
	if c.cadena2 != CADENA_NINGUNA and not _otro_con_cadena(i):
		eventos.append(_ev_texto(i, c.cadena2))
		c.cadena2 = CADENA_NINGUNA
	# 48-47: bocadillo de cambio de orden e iconos de la siguiente apelación.
	match c.accion_orden:
		1: eventos.append(_ev_bocadillo(EventoConcurso.Simbolo.ANTES))
		2: eventos.append(_ev_bocadillo(EventoConcurso.Simbolo.DESPUES))
		3: eventos.append(_ev_bocadillo(EventoConcurso.Simbolo.BARAJADO))
	eventos.append(_ev(EventoConcurso.Tipo.SIGUIENTE_TURNO, -1, {"orden_siguiente": _ordenes_siguientes(), "modo": _modos_orden()}))
	# 12-50: corazones, condición, estrellas e icono del actor.
	eventos.append(_ev_corazones(i, 0, c.atractivo))
	if c.mod_condicion == 1:
		eventos.append(_ev_bocadillo(EventoConcurso.Simbolo.CONDICION))
	eventos.append(_ev(EventoConcurso.Tipo.ESTRELLAS, i, {"condicion": c.condicion}))
	eventos.append(_ev(EventoConcurso.Tipo.ICONO_ESTADO, i, {"icono": icono_estado(i)}))
	# 26-30: los demás con texto pendiente, por posición.
	for posicion in EstadoConcurso.NUM_CONCURSANTES:
		var otro: int = estado.concursante_en(posicion)
		if otro == i or otro < 0 or concursante(otro).cadena == CADENA_NINGUNA:
			continue
		var o := concursante(otro)
		eventos.append(_ev_texto(otro, o.cadena))
		o.cadena = CADENA_NINGUNA
		eventos.append(_ev_corazones(otro, o.atractivo + o.interferencia_recibida, -o.interferencia_recibida))
		eventos.append(_ev(EventoConcurso.Tipo.ESTRELLAS, otro, {"condicion": o.condicion}))
		eventos.append(_ev(EventoConcurso.Tipo.ICONO_ESTADO, otro, {"icono": icono_estado(otro)}))
		if o.atencion_retirada:
			o.atencion_retirada = false
			eventos.append(_ev(EventoConcurso.Tipo.ATENCION_RETIRADA, otro))
	# Fin del bucle 25-30: DrawStatusSymbols (contest.c:1156) borra los sobresaltos.
	var iconos: Array[int] = []
	for k in EstadoConcurso.NUM_CONCURSANTES:
		iconos.append(icono_estado(k))
	eventos.append(_ev(EventoConcurso.Tipo.ICONOS_ESTADO, -1, {"iconos": iconos}))
	# 51: no podrá exhibirse en la siguiente.
	if c.turnos_saltados != 0 or c.saltara_turno:
		eventos.append(_ev(EventoConcurso.Tipo.NO_PODRA_APELAR, i))
	# 52-16: combo (iniciador o completado).
	if c.uso_combo:
		eventos.append(_ev(EventoConcurso.Tipo.COMBO, i, {"completado": c.combo_completado != 0}))
		eventos.append(_ev_bocadillo(EventoConcurso.Simbolo.COMBO if c.combo_completado != 0 else EventoConcurso.Simbolo.EXPECTANTE))
		if not c.atencion_juez:
			eventos.append(_ev_corazones(i, c.atractivo, c.bonus_combo))
			c.atractivo += c.bonus_combo
	# 17-18: repetición.
	if c.repitio:
		eventos.append(_ev(EventoConcurso.Tipo.REPETICION, i))
		eventos.append(_ev_bocadillo(EventoConcurso.Simbolo.REPETICION))
		eventos.append(_ev_corazones(i, c.atractivo, -c.castigo_repeticion))
		c.atractivo -= c.castigo_repeticion
	# 41-54: público.
	if estado.emocion_congelada and i != estado.congelador:
		eventos.append(_ev(EventoConcurso.Tipo.PUBLICO_CONGELADO, i, {"congelador": estado.congelador, "movimiento": c.mov_actual}))
		return
	var cambio: int = estado.emocion_mov
	if c.emocion_forzada:
		cambio = 1
	if cambio > 0 and c.repitio:
		cambio = 0
	estado.aplausos = maxi(estado.aplausos + cambio, 0)
	if cambio == 0:
		return
	eventos.append(_ev(EventoConcurso.Tipo.PUBLICO, i, {
		"cambio": cambio,
		"aplausos": estado.aplausos,
		"lleno": cambio > 0 and estado.aplausos > EstadoConcurso.NIVEL_APLAUSO_MAXIMO - 1,
		"bonus": estado.bonus_emocion if cambio > 0 else 0,
		"categoria": datos.categoria(c.mov_actual),
		"forzada": c.emocion_forzada,
		"movimiento": c.mov_actual,
	}))
	if cambio > 0:
		eventos.append(_ev_corazones(i, c.atractivo, estado.bonus_emocion))
		c.atractivo += estado.bonus_emocion


## CalculateAppealMoveImpact.
func calcular_impacto(i: int) -> void:
	var c := concursante(i)
	c.atractivo = 0
	c.atractivo_base = 0
	if c.turno_deshabilitado():
		return
	var efecto: int = datos.efecto(c.mov_actual)
	c.categoria_mov = datos.categoria(c.mov_actual)
	if c.mov_actual == c.mov_previo and c.mov_actual != DatosConcurso.MOVIMIENTO_NINGUNO:
		c.repitio = true
		c.repeticiones += 1
	else:
		c.repeticiones = 0
	c.atractivo_base = datos.atractivo_efecto(efecto)
	c.atractivo = c.atractivo_base
	estado.interferencia = datos.interferencia_efecto(efecto)
	estado.interferencia2 = estado.interferencia
	estado.actor = i
	for k in EstadoConcurso.NUM_CONCURSANTES:
		concursante(k).interferencia_recibida = 0
		estado.marcados[k] = false
	if c.atencion_juez and datos.son_combo(c.mov_previo, c.mov_actual) == 0:
		c.atencion_juez = false
	efectos.aplicar(efecto)
	if c.mod_condicion == 1:
		c.atractivo += c.condicion - 10
	elif c.condicion_triple:
		c.atractivo += c.condicion * 3
	else:
		c.atractivo += c.condicion
	c.combo_completado = 0
	c.uso_combo = false
	if c.puede_combo():
		var combo: int = datos.son_combo(c.mov_previo, c.mov_actual)
		if combo != 0 and c.atencion_juez:
			c.combo_completado = combo
			c.uso_combo = true
			c.atencion_juez = false
			c.bonus_combo = c.atractivo_base * c.combo_completado
			c.completo_combo_alguna_vez = true
		elif datos.combo_inicio(c.mov_actual) != 0:
			c.atencion_juez = true
			c.uso_combo = true
		else:
			c.atencion_juez = false
	if c.repitio:
		c.castigo_repeticion = (c.repeticiones + 1) * 10
	if c.nervioso:
		c.atencion_juez = false
		c.atractivo = 0
		c.atractivo_base = 0
	estado.emocion_mov = emocion_movimiento(c.mov_actual)
	if c.emocion_forzada:
		estado.emocion_mov = 1
	if estado.emocion_mov > 0:
		estado.bonus_emocion = 60 if estado.aplausos + estado.emocion_mov > EstadoConcurso.NIVEL_APLAUSO_MAXIMO - 1 else 10
	else:
		estado.bonus_emocion = 0
	# Objetivo visual de TRANSFORMACIÓN/ROL: consume una tirada aunque no se use.
	var r: int = aleatorio.modulo(3)
	var objetivo: int = 0
	while objetivo < EstadoConcurso.NUM_CONCURSANTES:
		if objetivo != i:
			if r == 0:
				break
			r -= 1
		objetivo += 1
	c.objetivo_animacion = objetivo


## Fin de una apelación: ranking, orden de la siguiente, nivel de atención y reinicio.
func cerrar_apelacion() -> Array[EventoConcurso]:
	_clasificar()
	_niveles_atencion()
	var puntos: Array[int] = []
	for c in estado.concursantes:
		puntos.append(c.puntos_totales)
	var eventos: Array[EventoConcurso] = [_ev(EventoConcurso.Tipo.FIN_APELACION, estado.indice_jugador, {
		"puntos": puntos,
		"orden": estado.orden.duplicate(),
		"nivel_atencion": concursante(estado.indice_jugador).nivel_atencion,
	})]
	_preparar_siguiente_apelacion()
	estado.numero_apelacion += 1
	estado.numero_turno = 0
	if estado.numero_apelacion == EstadoConcurso.NUM_APELACIONES:
		calcular_final()
		eventos.append(_ev(EventoConcurso.Tipo.FIN_CONCURSO, -1))
	return eventos


## Una apelación entera (elección + 4 turnos + cierre).
func jugar_apelacion(eleccion_jugador: int) -> Array[EventoConcurso]:
	var eventos: Array[EventoConcurso] = [evento_inicio_apelacion()]
	elegir_movimientos(eleccion_jugador)
	for _turno in EstadoConcurso.NUM_CONCURSANTES:
		eventos.append_array(ejecutar_turno())
	eventos.append_array(cerrar_apelacion())
	return eventos


## RankContestants (sin el reinicio, que va aparte como en Rubí).
func _clasificar() -> void:
	var totales: Array[int] = []
	for c in estado.concursantes:
		c.puntos_totales += c.atractivo
		totales.append(c.puntos_totales)
	for i in 3:
		var j: int = 3
		while j > i:
			if totales[j - 1] < totales[j]:
				var t: int = totales[j]
				totales[j] = totales[j - 1]
				totales[j - 1] = t
			j -= 1
	for c in estado.concursantes:
		c.puesto = totales.find(c.puntos_totales)
	_ordenar(1)
	_aplicar_orden_siguiente()


## SetAttentionLevels.
func _niveles_atencion() -> void:
	for c in estado.concursantes:
		if c.mov_actual == DatosConcurso.MOVIMIENTO_NINGUNO:
			c.nivel_atencion = 5
		elif c.atractivo <= 0:
			c.nivel_atencion = 0
		elif c.atractivo < 30:
			c.nivel_atencion = 1
		elif c.atractivo < 60:
			c.nivel_atencion = 2
		elif c.atractivo < 80:
			c.nivel_atencion = 3
		else:
			c.nivel_atencion = 4


## SetContestantStatusesForNextRound.
func _preparar_siguiente_apelacion() -> void:
	for c in estado.concursantes:
		c.atractivo = 0
		c.atractivo_base = 0
		c.protecciones = 0
		if c.turnos_saltados > 0:
			c.turnos_saltados -= 1
		c.interferencia_recibida = 0
		c.resistente = false
		c.reduccion_interferencia = 0
		c.inmune = false
		c.mas_asustadizo = false
		c.nervioso = false
		c.cadena = CADENA_NINGUNA
		c.cadena2 = CADENA_NINGUNA
		c.mod_condicion = 0
		c.repitio_previo = c.repitio
		c.repitio = false
		c.accion_orden = 0
		c.condicion_triple = false
		if c.saltara_turno:
			c.turnos_saltados = 1
			c.saltara_turno = false
		if c.exploto:
			c.sin_mas_turnos = true
			c.exploto = false
		c.emocion_forzada = false
	for i in EstadoConcurso.NUM_CONCURSANTES:
		var c := concursante(i)
		c.mov_previo = c.mov_actual
		estado.historial_movimientos[estado.numero_apelacion][i] = c.mov_previo
		estado.historial_emocion[estado.numero_apelacion][i] = emocion_movimiento(c.mov_actual)
		c.mov_actual = DatosConcurso.MOVIMIENTO_NINGUNO
	estado.emocion_congelada = false


## Task_EndAppeals: CalculateFinalScores + DetermineFinalStandings.
func calcular_final() -> void:
	for i in EstadoConcurso.NUM_CONCURSANTES:
		estado.totales_apelacion[i] = concursante(i).puntos_totales
		estado.puntos_ronda2[i] = estado.totales_apelacion[i] * 2
		estado.puntos_finales[i] = estado.puntos_ronda1[i] + estado.puntos_ronda2[i]
	var azar: Array[int] = _aleatorios_unicos()
	var clasificacion: Array[int] = [0, 1, 2, 3]
	for i in 3:
		var j: int = 3
		while j > i:
			if _queda_por_debajo(clasificacion[j - 1], clasificacion[j], azar):
				var t: int = clasificacion[j]
				clasificacion[j] = clasificacion[j - 1]
				clasificacion[j - 1] = t
			j -= 1
	for puesto in EstadoConcurso.NUM_CONCURSANTES:
		estado.puestos_finales[clasificacion[puesto]] = puesto
	estado.terminado = true


## DidContestantPlaceHigher(a, b): true si `a` debe ir detrás de `b`.
func _queda_por_debajo(a: int, b: int, azar: Array[int]) -> bool:
	if estado.puntos_finales[a] != estado.puntos_finales[b]:
		return estado.puntos_finales[a] < estado.puntos_finales[b]
	if estado.puntos_ronda1[a] != estado.puntos_ronda1[b]:
		return estado.puntos_ronda1[a] < estado.puntos_ronda1[b]
	return azar[a] < azar[b]


## Cuatro Random() distintos (se repite la tirada si coincide).
func _aleatorios_unicos() -> Array[int]:
	var valores: Array[int] = []
	while valores.size() < EstadoConcurso.NUM_CONCURSANTES:
		var v: int = aleatorio.u16()
		if not valores.has(v):
			valores.append(v)
	return valores


## SortContestants(modo): 0 = por ronda 1 (inicio); 1 = por ranking acumulado.
func _ordenar(modo: int) -> void:
	var azar: Array[int] = _aleatorios_unicos()
	var orden: Array[int] = [0, 0, 0, 0]
	if modo == 0:
		var lista: Array[int] = [0, 0, 0, 0]
		for i in EstadoConcurso.NUM_CONCURSANTES:
			lista[i] = i
			for r4 in i:
				var otro: int = lista[r4]
				if estado.puntos_ronda1[otro] < estado.puntos_ronda1[i] \
						or (estado.puntos_ronda1[otro] == estado.puntos_ronda1[i] and azar[otro] < azar[i]):
					var r2: int = i
					while r2 > r4:
						lista[r2] = lista[r2 - 1]
						r2 -= 1
					lista[r4] = i
					break
		for posicion in EstadoConcurso.NUM_CONCURSANTES:
			orden[lista[posicion]] = posicion
	else:
		var ocupado: Array[int] = [-1, -1, -1, -1]
		for i in EstadoConcurso.NUM_CONCURSANTES:
			var p: int = concursante(i).puesto
			while ocupado[p] != -1:
				p += 1
			ocupado[p] = i
			orden[i] = p
		# Desempate solo entre índices contiguos con el mismo ranking (sesgo de Rubí).
		for i in 3:
			var r4: int = 3
			while r4 > i:
				if concursante(r4 - 1).puesto == concursante(r4).puesto and orden[r4 - 1] < orden[r4] \
						and azar[r4 - 1] < azar[r4]:
					var t: int = orden[r4]
					orden[r4] = orden[r4 - 1]
					orden[r4 - 1] = t
				r4 -= 1
	estado.orden = orden


## ApplyNextTurnOrder: posiciones fijadas por efectos y el resto por el orden actual.
func _aplicar_orden_siguiente() -> void:
	var nuevo: Array[int] = estado.orden.duplicate()
	var colocado: Array[bool] = [false, false, false, false]
	var siguiente: int = 0
	for i in EstadoConcurso.NUM_CONCURSANTES:
		var j: int = 0
		while j < EstadoConcurso.NUM_CONCURSANTES:
			if concursante(j).orden_siguiente == i:
				nuevo[j] = i
				colocado[j] = true
				break
			j += 1
		if j == EstadoConcurso.NUM_CONCURSANTES:
			j = 0
			while j < EstadoConcurso.NUM_CONCURSANTES:
				if not colocado[j] and concursante(j).orden_siguiente == ConcursanteConcurso.ORDEN_LIBRE:
					siguiente = j
					j += 1
					break
				j += 1
			while j < EstadoConcurso.NUM_CONCURSANTES:
				if not colocado[j] and concursante(j).orden_siguiente == ConcursanteConcurso.ORDEN_LIBRE \
						and estado.orden[siguiente] > estado.orden[j]:
					siguiente = j
				j += 1
			nuevo[siguiente] = i
			colocado[siguiente] = true
	for i in EstadoConcurso.NUM_CONCURSANTES:
		concursante(i).orden_siguiente = ConcursanteConcurso.ORDEN_LIBRE
		concursante(i).mod_orden = 0
	estado.orden = nuevo


# === Eventos ===

func _otro_con_cadena(i: int) -> bool:
	for k in EstadoConcurso.NUM_CONCURSANTES:
		if k != i and concursante(k).cadena != CADENA_NINGUNA:
			return true
	return false


func _ordenes_siguientes() -> Array[int]:
	var lista: Array[int] = []
	for c in estado.concursantes:
		lista.append(c.orden_siguiente)
	return lista


func _modos_orden() -> Array[int]:
	var lista: Array[int] = []
	for c in estado.concursantes:
		lista.append(c.mod_orden)
	return lista


## DrawStatusSymbol.
func icono_estado(i: int) -> int:
	var c := concursante(i)
	if c.resistente or c.inmune or c.protecciones != 0 or c.reduccion_interferencia != 0:
		return EventoConcurso.Icono.PROTEGIDO
	if c.nervioso:
		return EventoConcurso.Icono.NERVIOSO
	if c.turno_deshabilitado():
		return EventoConcurso.Icono.SALTA_TURNO
	return EventoConcurso.Icono.NINGUNO


func _ev(tipo: EventoConcurso.Tipo, i: int, d: Dictionary = {}) -> EventoConcurso:
	return EventoConcurso.crear(tipo, i, d)


func _ev_texto(i: int, cadena: int) -> EventoConcurso:
	return _ev(EventoConcurso.Tipo.TEXTO_EFECTO, i, {"cadena": cadena, "actor": estado.actor})


func _ev_bocadillo(simbolo: int) -> EventoConcurso:
	return _ev(EventoConcurso.Tipo.BOCADILLO, -1, {"simbolo": simbolo})


func _ev_corazones(i: int, desde: int, delta: int) -> EventoConcurso:
	return _ev(EventoConcurso.Tipo.CORAZONES, i, {"desde": desde, "delta": delta, "valor": desde + delta})
