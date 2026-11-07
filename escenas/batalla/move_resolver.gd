extends RefCounted
class_name MoveResolver
## Etapa 2 del cambio SDD `2026-09-14-battle-architecture-split`: lógica pura
## de resolución de movimientos (daño, efectividad, STAB, handlers de
## estado), extraída de `batalla.gd` sin cambiar su comportamiento.
##
## Todas las funciones son estáticas: ninguna depende de estado de
## `batalla.gd` más allá de sus parámetros explícitos (Decisión D4) — se
## pasan los `PokemonEnCombate` ya resueltos en vez de buscarlos con
## `_obtener_combatiente()`. La resolución de movimientos de estado
## (`STATUS_EFFECT_HANDLERS`, dispatch por handler con nombre) vive en
## `StatusEffectResolver`, su clase hermana (SDD
## `2026-09-14-move-effect-resolver`); `clasificar_logica_movimiento()` la
## consulta para su metadata de introspección, pero `MoveResolver` mismo no
## despacha movimientos de estado.
##
## El daño sigue CalculateBaseDamage y atk05-atk07 con aritmética entera: la base vive
## en `source_damage_context.gd`. El daño por turno de TORMENTA_ARENA/GRANIZO es
## responsabilidad de `_procesar_fin_de_ronda()` en `batalla.gd`.

## Calcula el daño de un movimiento. `combatiente_atacante`/`combatiente_defensor`
## pueden ser null (sin estado de combate activo); en ese caso se usan las
## estadísticas base del BasePokemon, igual que el original.
## `campo`: clima y Pokémon activos para las habilidades (MAS/MENOS, ACLIMATACIÓN,
## BUCLE AIRE...). Si es null solo cuentan las habilidades propias de atacante
## y defensor y se usa `clima` tal cual.
static func source_friendship_power(effect: String, friendship: int) -> int:
	# Ruby atkB6 uses integer division; a zero override uses move base1.
	var value: int=clampi(friendship,0,255)
	return maxi(1,10*(value if effect=="EFFECT_RETURN" else 255-value)/25)

static func source_hp_power(actor: BasePokemon) -> int:
	# Ruby atkAC/table969: inclusive scaled HP48 thresholds. No modern boosts.
	var fraction: int=actor.estad_ps_actual*48/maxi(1,actor.estad_ps)
	if fraction==0 and actor.estad_ps_actual>0:fraction=1
	for pair: Array in [[1,200],[4,150],[9,100],[16,80],[32,40],[48,20]]:
		if fraction<=int(pair[0]):return int(pair[1])
	return 20

static func calcular_dano(mov, atacante: BasePokemon, defensor: BasePokemon, combatiente_atacante: PokemonEnCombate, combatiente_defensor: PokemonEnCombate, clima: int = 0, area_dos_rivales: bool = false, campo: CampoCombate = null, permitir_criticos: bool = false, sortear_critico: Callable = Callable(), potencia_override: int = -1, source_stockpile_count: int = 0, source_damage_multiplier: int = 1, held_descriptor: Dictionary = {}) -> ResultadoMovimiento:
	var resultado := ResultadoMovimiento.new()
	if mov is Movimiento and preload("res://scripts/battle/fixed_damage_rules.gd").supports(mov):
		return preload("res://scripts/battle/fixed_damage_rules.gd").result(mov,atacante,defensor,combatiente_defensor)
	if mov is Movimiento and mov.get_efecto() in ["EFFECT_SONICBOOM","EFFECT_LEVEL_DAMAGE"]:
		# Ruby typecalc retains immunity, then clears only SUPER/NOT_VERY.
		# setdamage20/dmgtolevel + adjustsetdamage never calculate stats, crit, screens or RNG.
		# Endure/Substitute and the explicit ordinary attack Focus Band adapter
		# belong to accepted-hit authority, never this fixed-damage calculation.
		if calc_efectividad(mov,defensor,combatiente_defensor)==0.0:
			resultado.effectiveness=0.0
			resultado.message="No afecta a\n%s..."%defensor.get_nombre_combate()
		else:resultado.damage=20 if mov.get_efecto()=="EFFECT_SONICBOOM" else atacante.nivel
		return resultado
	var tipo_mov: String = mov.get_tipo() if mov is Movimiento else str(mov["datos"].get("tipo", ""))
	var categoria: int = mov.get_categoria_dano_id() if mov is Movimiento else Movimiento.categoria_por_tipo(tipo_mov, int(mov["datos"].get("categoria_dano_id", 1)))
	if potencia_override<0 and mov is Movimiento and mov.get_efecto()=="EFFECT_ERUPTION":potencia_override=preload("res://scripts/battle/hp_burst_rules.gd").power(atacante)
	if potencia_override<0 and mov is Movimiento and mov.get_efecto()=="EFFECT_FLAIL":potencia_override=source_hp_power(atacante)
	if potencia_override<0 and mov is Movimiento and mov.get_efecto()=="EFFECT_LOW_KICK":potencia_override=preload("res://scripts/battle/variable_power_rules.gd").low_kick_power(defensor)
	if potencia_override<0 and mov is Movimiento and mov.get_efecto() in ["EFFECT_RETURN","EFFECT_FRUSTRATION"]:potencia_override=source_friendship_power(mov.get_efecto(),atacante.felicidad)
	var potencia = float(max(potencia_override if potencia_override >= 0 else mov.get_potencia(), 0))
	if potencia <= 0.0:
		return resultado
	potencia = BattleSportRules.power(potencia,tipo_mov,campo)
	potencia = HabilidadesCombate.potencia_modificada(atacante, tipo_mov, potencia)
	var clima_aplicado := campo.clima_efectivo() if campo != null else clima

	var struggle: bool=mov is Movimiento and mov.get_nombre_interno() in ["COMBATE","STRUGGLE"]
	var efectividad = 1.0 if struggle else calc_efectividad(mov, defensor,combatiente_defensor)
	resultado.effectiveness = efectividad
	if efectividad == 0:
		resultado.message = "No afecta a\n%s..." % defensor.get_nombre_combate()
		print(resultado.message)
		return resultado
	elif efectividad < 1:
		resultado.message = "No es muy eficaz..."
		print(resultado.message)
	elif efectividad > 1:
		resultado.message = "¡Es super efectivo!"
		print(resultado.message)

	# ApplyRandomDmgMultiplier: 100 - Random()%16. Se sortea aquí para no alterar el
	# orden de las tiradas; se aplica al final, tras el tipo.
	var porcentaje_azar: int = 100 if source_stockpile_count>0 else 100-randi()%16
	var critico: int = 1
	# Golpe crítico (1/16, 1/8 en movimientos de crítico alto): ARMADURA BATALLA y
	# CAPARAZÓN del defensor lo evitan. Decide qué etapas cuentan en la base.
	if source_stockpile_count<=0 and permitir_criticos and mov is Movimiento and EfectosGolpe.golpe_critico(atacante, defensor, mov, sortear_critico, combatiente_atacante):
		critico = 2
		resultado.critico = true

	var pantallas: int=_pantallas_activas(campo,defensor,categoria)
	var contexto=preload("res://scripts/battle/source_damage_context.gd")
	var dano: int
	if categoria==2:
		dano=contexto.special_base(atacante,defensor,combatiente_atacante,combatiente_defensor,int(potencia),tipo_mov,resultado.critico,pantallas,area_dos_rivales,clima_aplicado,mov is Movimiento and mov.get_efecto()=="EFFECT_SOLARBEAM",campo)
	else:
		dano=contexto.physical_base(atacante,defensor,combatiente_atacante,combatiente_defensor,int(potencia),held_descriptor,resultado.critico,pantallas,area_dos_rivales,mov is Movimiento and mov.get_efecto()=="EFFECT_EXPLOSION")
	# atk05_damagecalc: base completa (+2) × crítico × dmgMultiplier; atk86 (Reserva) y
	# atkD6 multiplican también la base completa. Después Carga y Refuerzo.
	dano*=critico*(int(BattleMoveSchedule.multiplicador_semi(mov, combatiente_defensor)) if mov is Movimiento else 1)*maxi(1,source_stockpile_count)*source_damage_multiplier
	if mov is Movimiento and preload("res://scripts/battle/charge_rules.gd").boosted(mov,combatiente_atacante):dano*=2
	if combatiente_atacante!=null and combatiente_atacante.source_helping_hand:dano=dano*15/10
	# atk06_typecalc: STAB y luego cada tipo, truncando en cada paso. Forcejeo no pasa por aquí.
	if not struggle:
		if calc_stab(mov, atacante) > 1.0:dano=dano*15/10
		dano=_aplicar_tipos(dano,mov,defensor,combatiente_defensor)
	# atk07_adjustnormaldamage: Reserva usa atk69, sin factor aleatorio.
	if dano!=0:dano=maxi(1,dano*porcentaje_azar/100)
	print("Dano: ", dano)
	resultado.damage = dano
	return resultado

## Aliados vivos que reparten la pantalla: 0 sin REFLEJO/PANTALLA LUZ, 2 si son dos
## (2/3 del daño en dobles), 1 si no (mitad).
static func _pantallas_activas(campo: CampoCombate, defensor: BasePokemon, categoria: int) -> int:
	if campo==null or campo.screen_timers.size()!=2:return 0
	var side: int=campo.lado_de(defensor)
	var screen: String="EFFECT_REFLECT" if categoria==1 else "EFFECT_LIGHT_SCREEN" if categoria==2 else ""
	if side<0 or int(campo.screen_timers[side].get(screen,0))<=0:return 0
	var allies: Array=campo.activos_jugador if side==0 else campo.activos_enemigo
	return 2 if allies.filter(func(p: BasePokemon)->bool:return p!=null and p.estad_ps_actual>0).size()==2 else 1

## ModulateDmgByType: `daño * multiplicador / 10` por tipo, con mínimo 1 salvo inmunidad.
## Se recorre en el orden de gTypeEffectiveness: importa al truncar en tipos dobles.
static func _aplicar_tipos(dano: int, mov, defensor: BasePokemon, combatiente_defensor: PokemonEnCombate) -> int:
	var tipo_movimiento: String = mov.get_tipo() if mov is Movimiento else str(mov["datos"].get("tipo", ""))
	var tabla: Dictionary = Singleton.tabla_tipos.get(tipo_movimiento, {}) if Singleton.tabla_tipos != null else {}
	var tipos: Array[String]=BattleTransformRules.types(defensor)
	var orden: Array=[]
	for tipo: String in tipos:
		if tipo!="" and tipo not in orden:orden.append(tipo)
	orden.sort_custom(func(a: String,b: String)->bool:return _orden_tabla_tipos(tipo_movimiento,a)<_orden_tabla_tipos(tipo_movimiento,b))
	for tipo: String in orden:
		var factor: float=float(tabla.get(tipo,1.0))
		if combatiente_defensor!=null and combatiente_defensor.source_identified and tipo=="FANTASMA" and tipo_movimiento in ["NORMAL","LUCHA"]:factor=1.0
		if factor==1.0:continue
		dano=dano*int(factor*10.0)/10
		if dano==0 and factor>0.0:dano=1
	return dano

## La tabla sigue este orden salvo HIELO→FUEGO y FANTASMA→FANTASMA, que van al final.
static func _orden_tabla_tipos(ataque: String, defensa: String) -> int:
	if (ataque=="HIELO" and defensa=="FUEGO") or (ataque=="FANTASMA" and defensa=="FANTASMA"):return 99
	return ["NORMAL","FUEGO","AGUA","ELECTRICO","PLANTA","HIELO","LUCHA","VENENO","TIERRA","VOLADOR","PSIQUICO","BICHO","ROCA","FANTASMA","DRAGON","SINIESTRO","ACERO"].find(defensa)

	# Daño (PS) = {( [ { (2 * Nv. / 5 + 2) * Ataque * Poder / Defensa} / 50] * 1°Mod. + 2) * STAB * Efec.Tipo#1 * Efec.Tipo#2 * 2°Mod. * Rnd / 100} * CH;
	#                    |--- base ------|

# Función para calcular la efectividad del movimiento
# Si el movimiento es del mismo tipo que el Pokémon que lo usa, la efectividad es 1.5
static func calc_efectividad(mov, defensor, combatiente_defensor: PokemonEnCombate=null) -> float:
	var tipo_movimiento = mov.get_tipo() if mov is Movimiento else str(mov["datos"].get("tipo", ""))
	var native_types: Array[String]=BattleTransformRules.types(defensor)
	var tipo_1_defensor = native_types[0]
	var tipo_2_defensor = native_types[1]

	# Verificar que la tabla de tipos existe en Singleton
	if Singleton.tabla_tipos == null or Singleton.tabla_tipos.is_empty():
		print("⚠️ Tabla de tipos no encontrada en Singleton")
		return 1.0

	var efectividad1 = 1.0
	var efectividad2 = 1.0

	# Calcular efectividad contra tipo 1
	if Singleton.tabla_tipos.has(tipo_movimiento) and Singleton.tabla_tipos[tipo_movimiento].has(tipo_1_defensor):
		efectividad1 = Singleton.tabla_tipos[tipo_movimiento][tipo_1_defensor]
	else:
		print("⚠️ Efectividad no encontrada para %s vs %s" % [tipo_movimiento, tipo_1_defensor])

	# Calcular efectividad contra tipo 2 (solo si existe)
	if tipo_2_defensor != "" and tipo_2_defensor != null:
		if Singleton.tabla_tipos.has(tipo_movimiento) and Singleton.tabla_tipos[tipo_movimiento].has(tipo_2_defensor):
			efectividad2 = Singleton.tabla_tipos[tipo_movimiento][tipo_2_defensor]
		else:
			print("⚠️ Efectividad no encontrada para %s vs %s" % [tipo_movimiento, tipo_2_defensor])

	# Skip only the two Ghost immunity entries after Ruby's TYPE_FORESIGHT sentinel.
	if combatiente_defensor!=null and combatiente_defensor.source_identified and tipo_movimiento in ["NORMAL","LUCHA"]:
		if tipo_1_defensor=="FANTASMA":efectividad1=1.0
		if tipo_2_defensor=="FANTASMA":efectividad2=1.0
	print("🎯 Efectividad: %s vs %s/%s = %.2f x %.2f = %.2f" % [tipo_movimiento, tipo_1_defensor, tipo_2_defensor, efectividad1, efectividad2, efectividad1 * efectividad2])
	return efectividad1 * efectividad2

# Función para calcular el modificador de daño por stab
# Si el movimiento es del mismo tipo que el Pokémon que lo usa, el STAB es 1.5
static func calc_stab(_mov, _atacante) -> float:
	var stab = 1.0
	var tipo_movimiento = _mov.get_tipo() if _mov is Movimiento else str(_mov["datos"].get("tipo", ""))
	var native_types: Array[String]=BattleTransformRules.types(_atacante)
	var tipo_1_atacante = native_types[0]
	var tipo_2_atacante = native_types[1]

	# Verificar si el tipo del movimiento coincide con algún tipo del atacante
	if tipo_movimiento == tipo_1_atacante or (tipo_2_atacante != "" and tipo_2_atacante != null and tipo_movimiento == tipo_2_atacante):
		stab = 1.5
		print("⚡ STAB aplicado: %s usa movimiento %s (%.1fx)" % [_atacante.nombre_interno, tipo_movimiento, stab])
	else:
		print("➖ Sin STAB: %s (%s/%s) usa movimiento %s" % [_atacante.nombre_interno, tipo_1_atacante, tipo_2_atacante, tipo_movimiento])

	return stab

## Un movimiento es "de estado" cuando su categoría de daño es 3 (estado
## puro) o no tiene potencia — no pasa por calcular_dano().
static func es_movimiento_estado(movimiento: Movimiento) -> bool:
	if movimiento == null:
		return false
	# Ruby fixed damage commands are damaging even when DB power is NULL.
	if preload("res://scripts/battle/fixed_damage_rules.gd").supports(movimiento):return false
	if movimiento.get_efecto() in ["EFFECT_SONICBOOM","EFFECT_LEVEL_DAMAGE","EFFECT_BEAT_UP"]:return false
	return movimiento.get_categoria_dano_id() == 3 or movimiento.get_potencia() <= 0

## Clasifica qué ruta de resolución usaría un movimiento, sin ejecutarla.
## Utilidad de introspección/depuración; no forma parte del flujo de batalla.
static func clasificar_logica_movimiento(movimiento) -> Dictionary:
	if movimiento == null:
		return {
			"implemented": false,
			"kind": "missing",
			"summary": "Movimiento nulo"
		}

	if movimiento is Movimiento and preload("res://scripts/battle/fixed_damage_rules.gd").supports(movimiento):
		return {"implemented":true,"kind":"source_fixed_damage","summary":"Ruby fixed/fraction damage with source typecalc and command-specific survival"}

	var nombre = movimiento.nombre if movimiento is Movimiento else str(movimiento.get("nombre", ""))
	var nombre_interno = movimiento.get_nombre_interno() if movimiento is Movimiento else str(movimiento.get("nombre_interno", ""))
	var categoria = movimiento.get_categoria_dano_id() if movimiento is Movimiento else int(movimiento.get("categoria_dano_id", 0))
	var potencia = movimiento.get_potencia() if movimiento is Movimiento else int(movimiento.get("potencia", movimiento.get("poder", 0)))
	if categoria != 3 and potencia > 0:
		return {
			"implemented": true,
			"kind": "damage",
			"summary": "%s usa la ruta general de daño" % nombre
		}

	var handler = StatusEffectResolver.obtener_definicion_handler_movimiento(nombre_interno)
	if not handler.is_empty():
		return {
			"implemented": true,
			"kind": "named_handler",
			"summary": str(handler.get("summary", "%s usa un handler específico" % nombre))
		}

	var efecto_estadistica := CambioEstadisticaGen3.obtener_efecto(nombre_interno)
	if not efecto_estadistica.is_empty():
		var cambios: Array = efecto_estadistica.get("cambios", [])
		var partes := PackedStringArray()
		for cambio in cambios:
			partes.append("%s %+d" % [CambioEstadisticaGen3.nombre_estadistica(str(cambio[0])), int(cambio[1])])
		return {
			"implemented": true,
			"kind": "stat_change",
			"summary": "%s aplica %s" % [nombre, ", ".join(partes)]
		}

	return {
		"implemented": false,
		"kind": "unimplemented_status",
		"summary": "%s cae en estado sin handler específico" % nombre
		}

## Ratios de precisión de Gen 3 (sAccuracyStageRatios), índice = 6 +
## nivel de precisión del atacante - nivel de evasión del objetivo.
const RATIOS_PRECISION_GEN3 := [
	[33, 100], [36, 100], [43, 100], [50, 100], [60, 100], [75, 100],
	[1, 1],
	[133, 100], [166, 100], [2, 1], [233, 100], [133, 50], [3, 1],
]

## Probabilidad (1-100+) de acertar según la fórmula de Rubí. Los movimientos
## sin precisión (null/0 en poke.db: Rapidez, los que apuntan al usuario...)
## devuelven -1: aciertan siempre.
## `campo`: para las habilidades de precisión (OJO COMPUESTO, VELO ARENA,
## ENTUSIASMO); sin campo solo se aplican las de los dos Pokémon.
static func calcular_precision_efectiva(movimiento: Movimiento, combatiente_atacante: PokemonEnCombate, combatiente_defensor: PokemonEnCombate, campo: CampoCombate = null) -> int:
	var precision := movimiento.get_precision() if movimiento != null else -1
	if precision <= 0:
		return -1
	var nivel_precision := combatiente_atacante.mod_precision if combatiente_atacante != null else 0
	var nivel_evasion := combatiente_defensor.mod_evasion if combatiente_defensor != null else 0
	if combatiente_defensor!=null and combatiente_defensor.source_identified:nivel_evasion=0
	var indice := clampi(6 + nivel_precision - nivel_evasion, 0, 12)
	var ratio: Array = RATIOS_PRECISION_GEN3[indice]
	var efectiva: int = int(ratio[0]) * precision / int(ratio[1])
	if combatiente_atacante != null and combatiente_defensor != null:
		efectiva = HabilidadesCombate.precision_modificada(efectiva, combatiente_atacante.pokemon_base, combatiente_defensor.pokemon_base, movimiento, campo)
	return efectiva

## Gen 3: falla si `Random() % 100 + 1 > precisión efectiva`.
static func movimiento_acierta(movimiento: Movimiento, combatiente_atacante: PokemonEnCombate, combatiente_defensor: PokemonEnCombate, tirada: int = -1, campo: CampoCombate = null) -> bool:
	if BattleSureHitRules.guarantees(combatiente_atacante,combatiente_defensor):return true
	if BattleMoveSchedule.multiplicador_semi(movimiento, combatiente_defensor) == 0.0: return false
	var precision_efectiva := calcular_precision_efectiva(movimiento, combatiente_atacante, combatiente_defensor, campo)
	if precision_efectiva < 0:
		return true
	if tirada < 0:
		tirada = randi() % 100 + 1
	return tirada <= precision_efectiva
