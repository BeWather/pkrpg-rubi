extends RefCounted
class_name RamasNativas
## Datos de batalla que eligen la rama de una animación nativa de la familia especial (§24 de
## documentacion/piloto_animaciones_nativas.md). La lógica de juego ya decidió; aquí solo se lee lo mismo que lee
## la VM legada (MoveAnimationContext: source_damage, source_power, source_counter_inputs con source_friendship,
## source_fury_count, source_roll_count, source_weather y source_environment) y se traduce a la rama del script del
## original (las tareas que escriben gBattleAnimArgs[7] antes de un jumpargeq). Nada de esto es estado de juego.
##
## Las ramas que dependen del turno (jumpifmoveturn, choosetwoturnanim: Escupir, Tragar, Triplepatada, Paliza,
## Maldición) no pasan por aquí: la escena las elige con MoveAnimationContext.source_move_turn.

## Daño Secreto (AnimTask_GetBattleEnvironment → jumpargeq 0): la animación de otro movimiento según el terreno
## (BATTLE_ENVIRONMENT_*: hierba, hierba alta, arena, bajo el agua, agua, estanque, montaña, cueva, edificio y el
## resto). Reutiliza las escenas que ya tienen esos movimientos.
const ESCENA_POR_TERRENO: Dictionary = {
	"ruby:move/290": ["ruby:move/302", "ruby:move/345", "ruby:move/341", "ruby:move/127", "ruby:move/57",
		"ruby:move/61", "ruby:move/88", "ruby:move/44", "ruby:move/70", "ruby:move/21"],
}
## Movimientos cuya imagen nueva se queda tras la animación (Transformación, Sustituto): AparienciaNativa.
## §33: también General_SubstituteAppear (general/3, el mismo sub_81312E4 que Sustituto).
const APARIENCIA: Array[String] = ["ruby:move/144", "ruby:move/164", "ruby:general/3"]
## §33: animaciones que pasan del muñeco del sustituto al Pokémon o al revés (special/5, special/6, el sustituto que se
## desvanece y el robo de Snatch): la escena recibe las dos imágenes en `datos.sustituto`
## (AparienciaNativa.imagenes_sustituto(), del estado de presentación que ya registró la batalla) y no confirma nada.
const IMAGENES_SUSTITUTO: Array[String] = ["ruby:general/2", "ruby:special/5", "ruby:special/6", "ruby:general/17"]


## Sufijo de la animación para el movimiento `clave` (vacío = la animación base).
static func sufijo(clave: String, contexto: MoveAnimationContext) -> String:
	var entradas: Dictionary = contexto.source_counter_inputs if contexto != null else {}
	match clave:
		"ruby:move/69":
			# Sísmico (sub_80DDA4C): gAnimMoveDmg < 33, 33-65 o más.
			var dano: int = contexto.source_damage
			return "r0" if dano < 33 else ("r1" if dano < 66 else "r2")
		"ruby:move/216":
			# Retroceso (AnimTask_GetReturnPowerLevel): amistad; 60 justo se queda en la rama 0 (como la VM).
			var amistad: int = clampi(int(entradas.get("source_friendship", 0)), 0, 255)
			if amistad > 200:
				return "r3"
			if amistad > 91:
				return "r2"
			return "r1" if amistad > 60 else "r0"
		"ruby:move/218":
			# Frustración (sub_8079CEC): amistad <= 30, <= 100, <= 200 o más.
			var amistad_f: int = clampi(int(entradas.get("source_friendship", 0)), 0, 255)
			return "r0" if amistad_f <= 30 else ("r1" if amistad_f <= 100 else ("r2" if amistad_f <= 200 else "r3"))
		"ruby:move/217":
			# Presente (sub_812C960): daño (explosión) o curación (destellos).
			return "r0" if contexto.source_damage > 0 else "r1"
		"ruby:move/222":
			# Magnitud (sub_80E1B88): potencia > 99 añade los destellos.
			return "r1" if contexto.source_power > 99 else "r0"
		"ruby:move/210":
			# Corte Furia (UpdateFuryCutterAnimDirection / Count): sentido = bit bajo; 1, 2 o el resto (tres destellos).
			var cuenta: int = int(entradas.get("source_fury_count", 0))
			return "d%d_n%d" % [cuenta & 1, cuenta if cuenta in [1, 2] else 3]
		"ruby:move/205":
			# §34, Desenrollar (sub_80DD8BC): rolloutTimer2 - rolloutTimer1 = usos seguidos 1..5 (fuera de rango, 1, como el
			# original); el nivel 1 es la animación base y los 2..5, las rocas (variantes_desenrollar.tscn).
			var nivel: int = int(entradas.get("source_roll_count", 1))
			return "r%d" % nivel if nivel >= 2 and nivel <= 5 else ""
		"ruby:move/301":
			# Bola Hielo (AnimTask_CountIceBallThrows): usos seguidos - 1 (0-4).
			var usos: int = int(entradas.get("source_roll_count", 1)) - 1
			return "r%d" % usos if usos >= 0 and usos <= 4 else ""
		"ruby:move/311":
			# Meteorobola (AnimTask_GetWeather): ninguno, sol, lluvia, arena, granizo.
			return "r%d" % clampi(int(entradas.get("source_weather", 0)), 0, 4)
		"ruby:general/17":
			# §33, General_SnatchMove: sub_80E4264 (el que roba y la víctima del mismo lado: compañero, solo en dobles) y
			# sub_81417D8 (gBattleSpriteInfo.behindSubstitute del que roba: el battler enseña el muñeco). Los dos son datos
			# de presentación que la batalla ya tiene: los lados de los slots y el estado del muñeco registrado.
			var companero: bool = is_instance_valid(contexto.slot_atacante) and is_instance_valid(contexto.slot_defensor) 				and contexto.slot_atacante != contexto.slot_defensor and contexto.slot_atacante.es_jugador == contexto.slot_defensor.es_jugador
			var tras_sustituto: bool = str(BattleSubstitutePresentation.owned_state(contexto.slot_atacante).get("kind", "")) == "substitute"
			var partes: PackedStringArray = []
			if companero:
				partes.append("companero")
			if tras_sustituto:
				partes.append("sustituto")
			return "_".join(partes)
	return ""


## §32: sufijo de una animación general por su argumento (el mismo `source_general_argument` que lee la VM):
## B_ANIM_STATS_CHANGE (sub_807BB88) usa la animación «grande» si el cambio es de dos niveles o más; B_ANIM_TURN_TRAP
## (sub_8141DAC) elige la rama por el movimiento que atrapa (Giro Fuego, Torbellino, Tenaza, Bucle Arena; el resto,
## Atadura y Constricción, la base).
static func sufijo_auxiliar(clave: String, argumento: int) -> String:
	match clave:
		"ruby:general/1":
			var datos_mascara: Array = decodificar_estadistica(argumento)
			return "grande" if not datos_mascara.is_empty() and bool(datos_mascara[2]) else ""
		"ruby:general/6":
			return str({83: "r1", 250: "r2", 128: "r3", 328: "r4"}.get(argumento, ""))
	return ""


## §32: argumento de B_ANIM_STATS_CHANGE (sub_807BB88) → [estadística 0..7, baja, grande], o [] si no lo trata (el
## original destruye la tarea sin hacer nada).
static func decodificar_estadistica(argumento: int) -> Array:
	if argumento >= 15 and argumento <= 21:
		return [argumento - 15, false, false]
	if argumento >= 22 and argumento <= 28:
		return [argumento - 22, true, false]
	if argumento >= 39 and argumento <= 45:
		return [argumento - 39, false, true]
	if argumento >= 46 and argumento <= 52:
		return [argumento - 46, true, true]
	if argumento in [55, 56, 57, 58]:
		return [7, argumento >= 57, argumento in [56, 58]]
	return []


## Datos de presentación para las escenas que los leen sin ramificar.
static func datos(contexto: MoveAnimationContext) -> Dictionary:
	var resultado: Dictionary = {"terreno": terreno(contexto), "potencia": contexto.source_power if contexto != null else 60}
	var batalla: Variant = contexto.batalla if contexto != null else null
	if is_instance_valid(batalla) and (batalla as Object).has_method(&"_pokemon_de_slot"):
		for par: Array in [["atacante", contexto.slot_atacante], ["defensor", contexto.slot_defensor]]:
			var pokemon: BasePokemon = batalla._pokemon_de_slot(par[1])
			if pokemon != null:
				resultado["especie_" + str(par[0])] = pokemon.nombre_interno
			# §33: un battler transformado se ve como la especie que copió (gBattleSpriteInfo.transformSpecies del
			# original): la del estado de presentación que dejó la Transformación.
			var estado: Dictionary = BattleSubstitutePresentation.owned_state(par[1])
			if str(estado.get("kind", "")) == "transform" and not str(estado.get("species", "")).is_empty():
				resultado["especie_" + str(par[0])] = str(estado.species)
	return resultado


## Terreno de la batalla (índice de BATTLE_ENVIRONMENT_*, el de EscenarioBatalla.Terreno): el que la batalla pasa a
## la VM para Camuflaje o, si no lo pasó, el de la batalla; 0 (hierba) sin batalla.
static func terreno(contexto: MoveAnimationContext) -> int:
	if contexto == null:
		return 0
	if contexto.source_counter_inputs.has("source_environment"):
		return int(contexto.source_counter_inputs.source_environment)
	var batalla: Variant = contexto.batalla
	if is_instance_valid(batalla) and (batalla as Object).has_method(&"obtener_terreno_batalla"):
		return int(batalla.obtener_terreno_batalla())
	return 0
