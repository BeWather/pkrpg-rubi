extends RefCounted
class_name CambioEstadisticaGen3
## Movimientos de estado que solo cambian niveles de característica (Gruñido,
## Chirrido, Danza Espada, Danza Dragón...), con las cifras y reglas de Rubí
## (battle_scripts EFFECT_*_UP/DOWN y los multi-stat de Gen 3), no las de
## generaciones posteriores: por eso DESARROLLO solo sube AT. ESP., RAFAGA
## sube 2 niveles, DISPDEMORA baja 1 y REDUCCION sube 1.
##
## La tabla es explícita a propósito: `descripcion_efecto` de poke.db viene de
## PokeAPI (texto inglés de la última generación) y no sirve para Gen 3.
##
## Textos oficiales del Rubí español (ROM AXVS, tabla de batalla en 0x4039xx):
##   "¡{STAT} de {POKéMON}\n{subió|subió mucho|bajó|bajó mucho}!"
##   "¡{STAT} de {POKéMON}\nno subirá más!" / "...no bajará más!"
##   "¡Las características de\n{POKéMON} no subirán más!" (multi-stat)
##   "¡{HABILIDAD} de {POKéMON}\nimpide que pierda características!"
##   "¡{HABILIDAD} de {POKéMON}\nimpide que pierda {STAT}!"
##
## Funciones estáticas y sin estado, igual que `StatusEffectResolver`.

## nombre_interno -> { "usuario": bool, "cambios": [[stat, niveles], ...] }
const EFECTOS := {
	# --- Suben características del usuario ---
	"DANZAESPADA": {"usuario": true, "cambios": [["ataque", 2]]},
	"DESARROLLO": {"usuario": true, "cambios": [["ataque_especial", 1]]},
	"MEDITACION": {"usuario": true, "cambios": [["ataque", 1]]},
	"AGILIDAD": {"usuario": true, "cambios": [["velocidad", 2]]},
	"DOBLEEQUIPO": {"usuario": true, "cambios": [["evasion", 1]]},
	"FORTALEZA": {"usuario": true, "cambios": [["defensa", 1]]},
	"REDUCCION": {"usuario": true, "cambios": [["evasion", 1]]},
	"REFUGIO": {"usuario": true, "cambios": [["defensa", 1]]},
	"RIZODEFENSA": {"usuario": true, "cambios": [["defensa", 1]]},
	"BARRERA": {"usuario": true, "cambios": [["defensa", 2]]},
	"AMNESIA": {"usuario": true, "cambios": [["defensa_especial", 2]]},
	"ARMADACIDA": {"usuario": true, "cambios": [["defensa", 2]]},
	"AFILAR": {"usuario": true, "cambios": [["ataque", 1]]},
	"RAFAGA": {"usuario": true, "cambios": [["ataque_especial", 2]]},
	"DEFFERREA": {"usuario": true, "cambios": [["defensa", 2]]},
	"AULLIDO": {"usuario": true, "cambios": [["ataque", 1]]},
	"MASACOSMICA": {"usuario": true, "cambios": [["defensa", 1], ["defensa_especial", 1]]},
	"CORPULENCIA": {"usuario": true, "cambios": [["ataque", 1], ["defensa", 1]]},
	"PAZMENTAL": {"usuario": true, "cambios": [["ataque_especial", 1], ["defensa_especial", 1]]},
	"DANZADRAGON": {"usuario": true, "cambios": [["ataque", 1], ["velocidad", 1]]},
	# --- Bajan características del objetivo ---
	"GRUNIDO": {"usuario": false, "cambios": [["ataque", -1]]},
	"LATIGO": {"usuario": false, "cambios": [["defensa", -1]]},
	"MALICIOSO": {"usuario": false, "cambios": [["defensa", -1]]},
	"ATAQUEARENA": {"usuario": false, "cambios": [["precision", -1]]},
	"PANTALLAHUMO": {"usuario": false, "cambios": [["precision", -1]]},
	"KINETICO": {"usuario": false, "cambios": [["precision", -1]]},
	"DESTELLO": {"usuario": false, "cambios": [["precision", -1]]},
	"DISPDEMORA": {"usuario": false, "cambios": [["velocidad", -1]]},
	"DULCEAROMA": {"usuario": false, "cambios": [["evasion", -1]]},
	"CHIRRIDO": {"usuario": false, "cambios": [["defensa", -2]]},
	"ESPORAGODON": {"usuario": false, "cambios": [["velocidad", -2]]},
	"CARASUSTO": {"usuario": false, "cambios": [["velocidad", -2]]},
	"ENCANTO": {"usuario": false, "cambios": [["ataque", -2]]},
	"DANZAPLUMA": {"usuario": false, "cambios": [["ataque", -2]]},
	"LLANTOFALSO": {"usuario": false, "cambios": [["defensa_especial", -2]]},
	"ECOMETALICO": {"usuario": false, "cambios": [["defensa_especial", -2]]},
	"COSQUILLAS": {"usuario": false, "cambios": [["ataque", -1], ["defensa", -1]]},
}

## Nombres de característica tal como los imprime la ROM española en batalla.
const NOMBRES_ESTADISTICA := {
	"ataque": "ATAQUE",
	"defensa": "DEFENSA",
	"velocidad": "VELOC.",
	"ataque_especial": "AT. ESP",
	"defensa_especial": "DF. ESP",
	"precision": "PRECISIÓN",
	"evasion": "EVASIÓN",
}

static func obtener_efecto(nombre_interno: String) -> Dictionary:
	var clave := nombre_interno.to_upper().replace("_", "").replace("-", "")
	return EFECTOS.get(clave, {})

static func es_movimiento_de_estadistica(movimiento: Movimiento) -> bool:
	return movimiento != null and not obtener_efecto(movimiento.get_nombre_interno()).is_empty()

static func apunta_al_usuario(movimiento: Movimiento) -> bool:
	return movimiento != null and bool(obtener_efecto(movimiento.get_nombre_interno()).get("usuario", false))

static func nombre_estadistica(stat: String) -> String:
	return str(NOMBRES_ESTADISTICA.get(stat, stat.to_upper()))

## Aplica el efecto del movimiento. Devuelve un `ResultadoEstado` vacío
## (`mensaje == ""`) si el movimiento no está en la tabla, para que quien
## llama pruebe otra ruta. Con un solo cambio usa los mensajes por
## característica; con varios (Danza Dragón, Cosquillas...) imprime un
## mensaje por cada característica que sí cambió, y solo si ninguna podía
## cambiar el mensaje colectivo de "Las características de...".
static func resolver(movimiento: Movimiento, atacante: BasePokemon, defensor: BasePokemon, combatiente_atacante: PokemonEnCombate, combatiente_defensor: PokemonEnCombate) -> ResultadoEstado:
	var resultado := ResultadoEstado.new()
	var efecto := obtener_efecto(movimiento.get_nombre_interno())
	if efecto.is_empty():
		return resultado

	var al_usuario := bool(efecto.get("usuario", false))
	var objetivo: BasePokemon = atacante if al_usuario else defensor
	var combatiente: PokemonEnCombate = combatiente_atacante if al_usuario else combatiente_defensor
	if objetivo == null or combatiente == null or (not al_usuario and objetivo.estad_ps_actual <= 0):
		resultado.mensaje = "¡Pero falló!"
		return resultado

	var nombre := objetivo.get_nombre_combate()
	var cambios: Array = efecto.get("cambios", [])
	var mensajes := PackedStringArray()

	if not al_usuario and objetivo != atacante:
		if preload("res://scripts/battle/mist_rules.gd").blocks(combatiente) and cambios.any(func(c):return int(c[1])<0):
			resultado.mensaje="¡La neblina protegió a %s!"%nombre;return resultado
		var protector := HabilidadesCombate.impide_bajar_estadistica(objetivo, "")
		if not protector.is_empty():
			resultado.mensaje = "¡%s de %s\nimpide que pierda características!" % [HabilidadesCombate.nombre(protector), nombre]
			return resultado

	var algun_cambio_posible := false
	for cambio in cambios:
		if _puede_cambiar(combatiente, str(cambio[0]), int(cambio[1])):
			algun_cambio_posible = true
	if cambios.size() > 1 and not algun_cambio_posible:
		resultado.mensaje = "¡Las características de\n%s no %s más!" % [nombre, "subirán" if int(cambios[0][1]) > 0 else "bajarán"]
		return resultado

	var source_changes: Array=[]
	var sube := true
	for cambio in cambios:
		var stat := str(cambio[0])
		var niveles := int(cambio[1])
		sube = niveles > 0
		if not al_usuario and objetivo != atacante and niveles < 0:
			var protector_stat := HabilidadesCombate.impide_bajar_estadistica(objetivo, stat)
			if not protector_stat.is_empty():
				mensajes.append("¡%s de %s\nimpide que pierda %s!" % [HabilidadesCombate.nombre(protector_stat), nombre, nombre_estadistica(stat)])
				continue
		if not _puede_cambiar(combatiente, stat, niveles):
			# En los multi-stat de Gen 3 la característica que ya está al
			# tope se salta en silencio.
			if cambios.size() == 1:
				mensajes.append("¡%s de %s\nno %s más!" % [nombre_estadistica(stat), nombre, "subirá" if sube else "bajará"])
			continue
		source_changes.append([stat,niveles])
		combatiente.cambiar_modificador(stat, niveles)
		resultado.aplicado = true
		mensajes.append(construir_mensaje_cambio(nombre, stat, niveles))

	if resultado.aplicado:
		resultado.source_stat_animation=preload("res://scripts/battle/stat_animation_rules.gd").argument(source_changes)
		resultado.pokemon_cambio_estadistica = objetivo
		resultado.cambio_estadistica_sube = sube
	if not mensajes.is_empty():
		resultado.mensaje = mensajes[0]
		resultado.mensajes_adicionales = mensajes.slice(1)
	return resultado

## Gen 3 elige "mucho" por los niveles pedidos, no por los aplicados: Danza
## Espada a +5 deja +6 y aun así dice "subió mucho".
static func construir_mensaje_cambio(nombre_objetivo: String, stat: String, niveles: int) -> String:
	var verbo := "subió" if niveles > 0 else "bajó"
	if abs(niveles) >= 2:
		verbo += " mucho"
	return "¡%s de %s\n%s!" % [nombre_estadistica(stat), nombre_objetivo, verbo]

static func _puede_cambiar(combatiente: PokemonEnCombate, stat: String, niveles: int) -> bool:
	var nivel := combatiente.obtener_modificador(stat)
	return nivel < 6 if niveles > 0 else nivel > -6
