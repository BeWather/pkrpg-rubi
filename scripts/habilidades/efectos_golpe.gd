class_name EfectosGolpe
extends RefCounted

## Mecánicas de golpe de Gen 3 que dan sentido a varias habilidades: golpes
## críticos (ARMADURA BATALLA, CAPARAZÓN), efectos secundarios (DICHA, POLVO
## ESCUDO, FOCO INTERNO, RITMO PROPIO), retroceso (CABEZA ROCA), drenaje (LODO
## LÍQUIDO), autodestrucción (HUMEDAD), K.O. de un golpe (ROBUSTEZ), robo de
## objeto (VISCOSIDAD) y confusión. Funciones estáticas puras como
## `HabilidadesCombate`: mutan el estado lógico y devuelven `AccionHabilidad`.
##
## Datos: columnas `Movimientos.efecto` (`.effect` de gBattleMoves en pokeruby) y
## `Movimientos.prob_secundario` (`.secondaryEffectChance`); ver
## herramientas/migraciones/agregar_flags_movimientos.py.

const E_NORMAL := -1
const E_ENVENENADO := 1
const E_CONGELADO := 2
const E_QUEMADO := 3
const E_PARALIZADO := 4
const E_DORMIDO := 5

## Efectos secundarios que dejan un estado en el objetivo.
const EFECTOS_ESTADO := {
	"EFFECT_PARALYZE_HIT": 4,
	"EFFECT_BURN_HIT": 3,
	"EFFECT_THAW_HIT": 3,
	"EFFECT_BLAZE_KICK": 3,
	"EFFECT_FREEZE_HIT": 2,
	"EFFECT_POISON_HIT": 1,
	"EFFECT_POISON_TAIL": 1,
	"EFFECT_TWINEEDLE": 1,
	"EFFECT_POISON_FANG": 1,
}
## Efectos que bajan una característica del objetivo.
const EFECTOS_BAJAN_OBJETIVO := {
	"EFFECT_ATTACK_DOWN_HIT": ["ataque"],
	"EFFECT_DEFENSE_DOWN_HIT": ["defensa"],
	"EFFECT_SPEED_DOWN_HIT": ["velocidad"],
	"EFFECT_SPECIAL_ATTACK_DOWN_HIT": ["ataque_especial"],
	"EFFECT_SPECIAL_DEFENSE_DOWN_HIT": ["defensa_especial"],
	"EFFECT_ACCURACY_DOWN_HIT": ["precision"],
}
## Efectos que suben una característica del usuario.
const EFECTOS_SUBEN_USUARIO := {
	"EFFECT_ATTACK_UP_HIT": ["ataque"],
	"EFFECT_DEFENSE_UP_HIT": ["defensa"],
	"EFFECT_ALL_STATS_UP_HIT": ["ataque", "defensa", "velocidad", "ataque_especial", "defensa_especial"],
}
const EFECTOS_CRITICO_ALTO := ["EFFECT_HIGH_CRITICAL", "EFFECT_BLAZE_KICK", "EFFECT_POISON_TAIL", "EFFECT_SKY_ATTACK"]
const EFECTOS_CONFUSION_GOLPE := ["EFFECT_CONFUSE_HIT"]
const EFECTOS_RETROCESO_GOLPE := ["EFFECT_FLINCH_HIT", "EFFECT_FLINCH_HIT_2", "EFFECT_SKY_ATTACK", "EFFECT_SNORE"]
## Probabilidad (1 entre N) de crítico por nivel (gCriticalHitChance).
const CRITICO_UNA_ENTRE := [16, 8, 4, 3, 2]


static func _n(p: BasePokemon) -> String:
	return p.get_nombre_combate()


static func _sortear(n: int, sortear: Callable) -> int:
	if sortear.is_valid():
		return int(sortear.call(n))
	return randi() % n


static func efecto_de(movimiento: Movimiento) -> String:
	return "" if movimiento == null else movimiento.get_efecto()


static func prob_secundaria(movimiento: Movimiento) -> int:
	return 0 if movimiento == null else movimiento.get_prob_secundario()


static func es_ko_directo(movimiento: Movimiento) -> bool:
	return efecto_de(movimiento) == "EFFECT_OHKO"


static func es_autodestruccion(movimiento: Movimiento) -> bool:
	return efecto_de(movimiento) == "EFFECT_EXPLOSION"


# ─── Golpes críticos ─────────────────────────────────────────────────────────

## 1 entre N de ser crítico (N=16 normal, 8 en movimientos de crítico alto).
static func una_entre_critico(movimiento: Movimiento, combatiente: PokemonEnCombate = null) -> int:
	var nivel := 1 if EFECTOS_CRITICO_ALTO.has(efecto_de(movimiento)) else 0
	if combatiente!=null and combatiente.source_focus_energy:nivel+=2
	return int(CRITICO_UNA_ENTRE[mini(nivel,4)])


## ¿Es crítico este golpe? ARMADURA BATALLA y CAPARAZÓN del defensor lo evitan.
static func golpe_critico(atacante: BasePokemon, defensor: BasePokemon, movimiento: Movimiento, sortear: Callable = Callable(), combatiente: PokemonEnCombate = null) -> bool:
	if movimiento == null or HabilidadesCombate.evita_critico(defensor):
		return false
	return _sortear(una_entre_critico(movimiento,combatiente), sortear) == 0


# ─── K.O. de un golpe y autodestrucción ──────────────────────────────────────

## Fisura, Guillotina, Perforador y Frío Polar. ROBUSTEZ los anula; fallan si el
## atacante tiene menos nivel; si no, aciertan con (nivel atacante - nivel
## objetivo + precisión)%.
static func resolver_ko_directo(atacante: BasePokemon, defensor: BasePokemon, movimiento: Movimiento, sortear: Callable = Callable(), source_focus: bool=false, sure_hit: bool=false) -> Array[AccionHabilidad]:
	var acciones: Array[AccionHabilidad] = []
	if HabilidadesCombate.inmune_a_ko_directo(defensor):
		acciones.append(AccionHabilidad.mensaje("¡%s de %s\nhace %s inefectivo!" % [HabilidadesCombate.nombre(HabilidadesCombate.ROBUSTEZ), _n(defensor), movimiento.nombre]))
		return acciones
	var fallo := AccionHabilidad.mensaje("¡El ataque de\n%s falló!" % _n(atacante))
	if not source_focus and atacante.nivel < defensor.nivel:
		acciones.append(fallo)
		return acciones
	var probabilidad := atacante.nivel - defensor.nivel + maxi(movimiento.get_precision(), 0)
	var roll: int=0 if source_focus and sure_hit else _sortear(100, sortear)+1
	# Ruby no-LockOn consumes KO RNG before its level rejection; Sturdy above
	# consumes none. Preserve the legacy no39 path outside this bounded fix.
	if (atacante.nivel<defensor.nivel or (not sure_hit and roll>=(probabilidad&65535))) if source_focus else roll>probabilidad:
		acciones.append(fallo)
		return acciones
	acciones.append(AccionHabilidad.dano(defensor, defensor.estad_ps_actual, "¡K.O. en 1 golpe!"))
	return acciones


## HUMEDAD de cualquier Pokémon del campo impide la autodestrucción; devuelve
## el mensaje o "".
static func mensaje_bloqueo_autodestruccion(atacante: BasePokemon, movimiento: Movimiento, campo: CampoCombate) -> String:
	if not es_autodestruccion(movimiento) or not HabilidadesCombate.bloquea_autodestruccion(campo):
		return ""
	for p in campo.todos():
		if HabilidadesCombate.tiene(p, HabilidadesCombate.HUMEDAD):
			return "¡%s de %s\nbloquea %s!" % [HabilidadesCombate.nombre(HabilidadesCombate.HUMEDAD), _n(p), movimiento.nombre]
	return ""


# ─── Confusión ───────────────────────────────────────────────────────────────

## Deja confuso a `objetivo` 2-5 turnos. RITMO PROPIO lo impide (en silencio si
## es un efecto secundario); no se acumula.
static func confundir(objetivo: BasePokemon, combatiente: PokemonEnCombate, sortear: Callable = Callable(), es_secundario: bool = true) -> Array[AccionHabilidad]:
	var acciones: Array[AccionHabilidad] = []
	if combatiente == null or combatiente.esta_confuso or objetivo.estad_ps_actual <= 0:
		return acciones
	if HabilidadesCombate.evita_confusion(objetivo):
		if not es_secundario:
			acciones.append(AccionHabilidad.mensaje("¡%s de %s\nevita la confusión!" % [HabilidadesCombate.nombre(HabilidadesCombate.RITMOPROPIO), _n(objetivo)]))
		return acciones
	combatiente.esta_confuso = true
	combatiente.turnos_confuso = 2 + _sortear(4, sortear)
	var accion := AccionHabilidad.mensaje("¡%s está\nconfuso!" % _n(objetivo))
	accion.objetivo = objetivo
	accion.source_status_key = "ruby:status/1"
	acciones.append(accion)
	return acciones


## Chequeo al empezar el turno de un Pokémon confuso (atkCanceler, confusión).
## Devuelve {mensajes: PackedStringArray, puede_actuar: bool, dano_propio: int}.
static func chequeo_confusion(pokemon: BasePokemon, combatiente: PokemonEnCombate, sortear: Callable = Callable(), held_descriptor: Dictionary={}) -> Dictionary:
	var resultado := {"mensajes": PackedStringArray(), "puede_actuar": true, "dano_propio": 0}
	if combatiente == null or not combatiente.esta_confuso:
		return resultado
	combatiente.turnos_confuso -= 1
	if combatiente.turnos_confuso <= 0:
		combatiente.esta_confuso = false
		resultado["mensajes"].append("¡%s ya\nno está confuso!" % _n(pokemon))
		return resultado
	resultado["mensajes"].append("¡%s se\nencuentra confuso!" % _n(pokemon))
	if _sortear(2, sortear) == 0:
		resultado["mensajes"].append("¡Está tan confuso\nque se hirió a si mismo!")
		resultado["puede_actuar"] = false
		resultado["dano_propio"] = dano_por_confusion(pokemon, combatiente, sortear, held_descriptor)
	return resultado


## Golpe de confusión: movimiento físico de 40 de potencia sin tipo, sin
## crítico ni STAB, con el factor aleatorio de 85-100%.
static func dano_por_confusion(pokemon: BasePokemon, combatiente: PokemonEnCombate, sortear: Callable = Callable(), held_descriptor: Dictionary={}) -> int:
	var ataque := float(combatiente.get_ataque_combate()) if combatiente != null else float(pokemon.estad_ataque)
	var defensa := float(combatiente.get_defensa_combate()) if combatiente != null else float(pokemon.estad_defensa)
	var base := (2.0 * pokemon.nivel / 5.0 + 2.0) * 40.0 * ataque / maxf(defensa, 1.0) / 50.0 + 2.0
	if preload("res://scripts/battle/held_damage_rules.gd").choice(held_descriptor):base=preload("res://scripts/battle/source_damage_context.gd").physical_base(pokemon,pokemon,combatiente,combatiente,40,held_descriptor)
	var azar := 100 - _sortear(16, sortear)
	return maxi(1, int(base * azar / 100.0))


# ─── Después del golpe ───────────────────────────────────────────────────────

## Todo lo que sigue a un golpe que hizo `dano` PS: drenaje, retroceso, robo de
## objeto, efecto secundario y autodestrucción. `defensor_ya_actuo`: el
## retroceso solo afecta a quien aún no ha actuado este turno.
static func tras_dano(atacante: BasePokemon, defensor: BasePokemon, movimiento: Movimiento, dano: int, combatiente_de: Callable = Callable(), defensor_ya_actuo: bool = false, sortear: Callable = Callable(), substitute_hit: bool = false, source_action: BattleMoveAction=null) -> Array[AccionHabilidad]:
	var acciones: Array[AccionHabilidad] = []
	if movimiento == null or atacante == null or defensor == null:
		return acciones
	var efecto := efecto_de(movimiento)
	if movimiento.get_nombre_interno() == "BOTE": efecto = "EFFECT_PARALYZE_HIT"
	# Accepted Endure-at-one-HP hits can deal zero body HP without NO_EFFECT.
	# Ruby's Struggle recoil effect still clamps that quarter damage to one.
	if dano==0 and efecto=="EFFECT_RECOIL" and movimiento.get_nombre_interno() in ["COMBATE","STRUGGLE"]:
		acciones.append_array(_retroceso(atacante,0,4,true))

	if dano > 0:
		if efecto == "EFFECT_ABSORB" and atacante.estad_ps_actual > 0:
			acciones.append_array(_drenar(atacante, defensor, dano))
		if efecto == "EFFECT_RECOIL" or efecto == "EFFECT_DOUBLE_EDGE":
			acciones.append_array(_retroceso(atacante, dano, 3 if efecto == "EFFECT_DOUBLE_EDGE" else 4, movimiento.get_nombre_interno() in ["COMBATE","STRUGGLE"]))
		if efecto=="EFFECT_KNOCK_OFF" and not substitute_hit:
			acciones.append(AccionHabilidad.item_phase(atacante,defensor,5))
		if efecto == "EFFECT_THIEF" and not substitute_hit:
			acciones.append_array(_robar(atacante, defensor, combatiente_de, source_action))
		acciones.append_array(_efecto_secundario(atacante, defensor, movimiento, efecto, combatiente_de, defensor_ya_actuo, sortear, substitute_hit))

	if efecto == "EFFECT_EXPLOSION" and atacante.estad_ps_actual > 0:
		acciones.append(AccionHabilidad.dano(atacante, atacante.estad_ps_actual, ""))
	return acciones


## Action-end secondary only, shared with the one-hit compatibility wrapper.
static func efecto_secundario(atacante: BasePokemon, defensor: BasePokemon, movimiento: Movimiento, combatiente_de: Callable = Callable(), defensor_ya_actuo: bool = false, sortear: Callable = Callable(), substitute_hit: bool = false) -> Array[AccionHabilidad]:
	return _efecto_secundario(atacante, defensor, movimiento, efecto_de(movimiento), combatiente_de, defensor_ya_actuo, sortear, substitute_hit)


static func _drenar(atacante: BasePokemon, defensor: BasePokemon, dano: int) -> Array[AccionHabilidad]:
	var acciones: Array[AccionHabilidad] = []
	var cantidad := maxi(1, dano / 2)
	if HabilidadesCombate.invierte_drenaje(defensor):
		acciones.append(AccionHabilidad.dano(atacante, cantidad, "¡Absorbió el\n%s!" % HabilidadesCombate.nombre(HabilidadesCombate.LODOLIQUIDO)))
	else:
		acciones.append(AccionHabilidad.curar(atacante, cantidad, "¡%s ha perdido\nenergía!" % _n(defensor)))
	return acciones


static func _retroceso(atacante: BasePokemon, dano: int, divisor: int, source_struggle: bool=false) -> Array[AccionHabilidad]:
	var acciones: Array[AccionHabilidad] = []
	if (not source_struggle and HabilidadesCombate.evita_dano_retroceso(atacante)) or atacante.estad_ps_actual <= 0:
		return acciones
	acciones.append(AccionHabilidad.dano(atacante, maxi(1, dano / divisor), "¡%s es golpeado\ncon retroceso!" % _n(atacante)))
	return acciones


static func _robar(atacante: BasePokemon, defensor: BasePokemon, combatiente_de: Callable=Callable(), source_action: BattleMoveAction=null) -> Array[AccionHabilidad]:
	var acciones: Array[AccionHabilidad] = []
	if not atacante.objeto.strip_edges().is_empty() or ObjetosLlevados.en_combate(defensor).is_empty():
		return acciones
	if HabilidadesCombate.evita_robo_objeto(defensor):
		acciones.append(AccionHabilidad.mensaje("¡%s de %s\nimpide el robo!" % [HabilidadesCombate.nombre(HabilidadesCombate.VISCOSIDAD), _n(defensor)]))
		return acciones
	var original_state: PokemonEnCombate=combatiente_de.call(defensor) if combatiente_de.is_valid() else null
	var objeto := defensor.objeto
	atacante.objeto = objeto
	defensor.objeto = ""
	if combatiente_de.is_valid() and combatiente_de.call(defensor)==original_state:preload("res://scripts/battle/choice_band_rules.gd").clear_state(original_state)
	# Ruby queues receipt in changedItems until MoveEnd7, after Choice6.
	# Keep native party exchange atomic; only this successful action chain defers observation.
	preload("res://scripts/battle/choice_band_rules.gd").defer_received_item(source_action)
	acciones.append(AccionHabilidad.item_phase(atacante,defensor,16))
	acciones.append(AccionHabilidad.mensaje("¡%s robó\n%s de %s!" % [_n(atacante), ObjetosLlevados.nombre_objeto(objeto), _n(defensor)]))
	return acciones


static func _efecto_secundario(atacante: BasePokemon, defensor: BasePokemon, movimiento: Movimiento, efecto: String, combatiente_de: Callable, defensor_ya_actuo: bool, sortear: Callable, substitute_hit: bool = false, source_action: BattleMoveAction=null) -> Array[AccionHabilidad]:
	var acciones: Array[AccionHabilidad] = []
	# Ruby certain USER recharge follows an accepted damaging hit, before faint check.
	if efecto=="EFFECT_RECHARGE":
		var user: PokemonEnCombate=combatiente_de.call(atacante) if combatiente_de.is_valid() else null
		if user!=null:user.source_recharge_turns=2
		return acciones
	# Ruby Superpower: certain user Attack then Defense, after committed hit.
	if efecto=="EFFECT_SUPERPOWER":
		var user: PokemonEnCombate=combatiente_de.call(atacante) if combatiente_de.is_valid() else null
		return [AccionHabilidad.stat_group(atacante,user,[["ataque",-1],["defensa",-1]],false)]
	# Ruby EFFECT_OVERHEAT sets AFFECTS_USER|CERTAIN, after committed damage.
	# It is not a random target secondary (Shield Dust/Substitute gate below).
	if efecto=="EFFECT_OVERHEAT":
		var user: PokemonEnCombate=combatiente_de.call(atacante) if combatiente_de.is_valid() else null
		return cambiar_estadistica(atacante,user,"ataque_especial",-2,false)
	# Ruby Fake Out sets certain flinch (136), not a random secondary chance.
	if efecto=="EFFECT_FAKE_OUT":
		var target: PokemonEnCombate=combatiente_de.call(defensor) if combatiente_de.is_valid() else null
		if target!=null and not substitute_hit and defensor.estad_ps_actual>0 and not defensor_ya_actuo and not HabilidadesCombate.ignora_efecto_secundario(defensor) and not HabilidadesCombate.evita_retroceso(defensor):target.retrocede=true
		return acciones
	var base := prob_secundaria(movimiento)
	if base <= 0:
		return acciones
	var sube_usuario: bool = EFECTOS_SUBEN_USUARIO.has(efecto)
	# Ruby keeps STATUS2_SUBSTITUTE through move-end, including the breaking hit.
	if substitute_hit and not sube_usuario:return acciones
	# POLVO ESCUDO protege al objetivo de los efectos secundarios (no al usuario).
	if not sube_usuario and HabilidadesCombate.ignora_efecto_secundario(defensor):
		return acciones
	if not sube_usuario and defensor.estad_ps_actual <= 0:
		return acciones
	var probabilidad := HabilidadesCombate.probabilidad_efecto_secundario(atacante, base)
	if _sortear(100, sortear) >= probabilidad:
		return acciones

	if efecto == "EFFECT_TRI_ATTACK":
		var elegido: int = [E_QUEMADO, E_CONGELADO, E_PARALIZADO][_sortear(3, sortear)]
		return aplicar_estado(defensor, elegido, atacante, combatiente_de)
	if EFECTOS_ESTADO.has(efecto):
		return aplicar_estado(defensor, int(EFECTOS_ESTADO[efecto]), atacante, combatiente_de)
	if EFECTOS_CONFUSION_GOLPE.has(efecto):
		var combatiente: PokemonEnCombate = combatiente_de.call(defensor) if combatiente_de.is_valid() else null
		return confundir(defensor, combatiente, sortear, true)
	if EFECTOS_RETROCESO_GOLPE.has(efecto):
		var objetivo: PokemonEnCombate = combatiente_de.call(defensor) if combatiente_de.is_valid() else null
		if objetivo != null and not defensor_ya_actuo and not HabilidadesCombate.evita_retroceso(defensor):
			objetivo.retrocede = true
		return acciones
	if EFECTOS_BAJAN_OBJETIVO.has(efecto):
		var combatiente_obj: PokemonEnCombate = combatiente_de.call(defensor) if combatiente_de.is_valid() else null
		for stat in EFECTOS_BAJAN_OBJETIVO[efecto]:
			acciones.append_array(cambiar_estadistica(defensor, combatiente_obj, str(stat), -1, true))
		return acciones
	if sube_usuario:
		var combatiente_usr: PokemonEnCombate = combatiente_de.call(atacante) if combatiente_de.is_valid() else null
		if efecto=="EFFECT_ALL_STATS_UP_HIT":return [AccionHabilidad.stat_group(atacante,combatiente_usr,[["ataque",1],["defensa",1],["velocidad",1],["ataque_especial",1],["defensa_especial",1]],false)]
		for stat in EFECTOS_SUBEN_USUARIO[efecto]:
			acciones.append_array(cambiar_estadistica(atacante, combatiente_usr, str(stat), 1, false))
	return acciones


## Aplica un estado como efecto secundario: respeta el estado previo, las
## habilidades que lo impiden y la inmunidad por tipo; activa SINCRONÍA.
static func aplicar_estado(objetivo: BasePokemon, estado: int, causante: BasePokemon, combatiente_de: Callable = Callable()) -> Array[AccionHabilidad]:
	var acciones: Array[AccionHabilidad] = []
	if objetivo.estado != Singleton.ProblemaEstado.NORMAL or objetivo.estad_ps_actual <= 0:
		return acciones
	if not HabilidadesCombate.habilidad_que_impide_estado(objetivo, estado).is_empty() or HabilidadesCombate.inmune_por_tipo(objetivo, estado):
		return acciones
	objetivo.estado = estado
	if estado == E_DORMIDO:
		var propio: PokemonEnCombate = combatiente_de.call(objetivo) if combatiente_de.is_valid() else null
		if propio != null:
			propio.iniciar_sueno()
	elif estado == E_CONGELADO:
		# Ruby SetMoveEffect cancels multi-turn counters on newly accepted freeze.
		var propio: PokemonEnCombate = combatiente_de.call(objetivo) if combatiente_de.is_valid() else null
		if propio != null:BattleCounterRules.cancel_multi(propio)
	var texto: String = {
		E_ENVENENADO: "¡%s\nfue envenenado!",
		E_CONGELADO: "¡%s\nfue congelado!",
		E_QUEMADO: "¡%s se ha quemado!",
		E_PARALIZADO: "¡%s está paralizado!\n¡Quizás no se mueva!",
		E_DORMIDO: "¡%s se quedó dormido!",
	}[estado] % _n(objetivo)
	acciones.append(AccionHabilidad.estado(objetivo, texto))
	acciones.append_array(HabilidadesCombate.sincronizar(objetivo, causante, estado, combatiente_de))
	return acciones


## Cambia una característica con los topes de ±6 y las protecciones de
## habilidad (CUERPO PURO, HUMO BLANCO, CORTE FUERTE, VISTA LINCE) si baja.
static func puede_cambiar_estadistica(objetivo: BasePokemon,combatiente: PokemonEnCombate,stat: String,niveles: int,es_rival: bool) -> bool:
	if objetivo==null or combatiente==null or objetivo.estad_ps_actual<=0:return false
	if niveles<0 and es_rival and preload("res://scripts/battle/mist_rules.gd").blocks(combatiente):return false
	if niveles<0 and es_rival and not HabilidadesCombate.impide_bajar_estadistica(objetivo,stat).is_empty():return false
	var nivel: int=combatiente.obtener_modificador(stat)
	return niveles>0 and nivel<6 or niveles<0 and nivel>-6

static func cambiar_estadistica(objetivo: BasePokemon, combatiente: PokemonEnCombate, stat: String, niveles: int, es_rival: bool) -> Array[AccionHabilidad]:
	var acciones: Array[AccionHabilidad]=[]
	if not puede_cambiar_estadistica(objetivo,combatiente,stat,niveles,es_rival):return acciones
	combatiente.cambiar_modificador(stat, niveles)
	acciones.append(AccionHabilidad.estadistica(objetivo, niveles > 0, CambioEstadisticaGen3.construir_mensaje_cambio(_n(objetivo), stat, niveles),stat,niveles))
	return acciones
