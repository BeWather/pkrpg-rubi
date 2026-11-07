## pokemon_errante.gd
## El Pokémon errante de Rubí: LATIOS (ROAMER_SPECIES), port de pokeruby src/roamer.c.
## Lo suelta el boletín de noticias de la tele del salón del jugador tras la LIGA
## (EventScript_1A6F0B → special InitRoamer, ProgramacionTV.ver) y desde entonces
## vaga por las rutas de HOENN hasta que se le derrota o se le atrapa.
##
## | ROM                                   | Aquí                                     |
## |---------------------------------------|------------------------------------------|
## | gSaveBlock1.roamer (struct Roamer)    | contadores `errante_*` de SistemaGuardado|
## | sRoamerLocation / sLocationHistory    | `_ubicacion` / `_historial` (EWRAM: no se guardan) |
## | sRoamerLocations (mapNum del grupo 0) | UBICACIONES (claves de escena `ruta_1xx`) |
## | FLAG_LATIOS_OR_LATIAS_ROAMING         | bandera `latios_errante_liberado`         |
##
## Movimiento (src/overworld.c): al llegar por un warp, al cargar la partida y al
## empezar (sub_8053994 / sub_805308C) salta a otro grupo de rutas
## (RoamerMoveToOtherLocationSet); al cruzar el borde entre dos mapas exteriores
## (LoadMapFromCameraTransition) se mueve a una ruta vecina (RoamerMove). Antes de
## moverse, UpdateLocationHistoryForRoamer apunta el mapa actual.
##
## Encuentro (StandardWildEncounter / SweetScentWildEncounter): cuando la tirada de
## encuentro de hierba o agua sale y el errante está en el mapa, 1 de cada 4 veces
## aparece él (TryStartRoamerEncounter); con REPELENTE que lo bloquee no hay combate.
## El combate es BATTLE_TYPE_ROAMER (AI_Roaming: huye en cuanto puede); al acabar
## guarda PS y estado y salta de grupo (UpdateRoamerHPStatus), y si se le derrota o
## atrapa deja de vagar (SetRoamerInactive).
##
## Fallo de la ROM conservado: CreateRoamerMonInstance pasa los IV a
## CreateMonWithIVsPersonality, cuyo SetMonData(MON_DATA_IVS) solo lee el primer
## byte, así que el LATIOS que aparece tiene el IV de PS y los 3 bits bajos del IV de
## ATAQUE; los demás IV son 0 (los guardados siguen intactos).
##
## Naturaleza, sexo y variocolor no salen de la personalidad en el proyecto, así que
## se guardan aparte para que sea el mismo LATIOS en cada encuentro.
extends RefCounted
class_name PokemonErrante

## ROAMER_SPECIES de Rubí (Zafiro: LATIAS).
const ESPECIE: String = "LATIOS"
## CreateInitialRoamerMon: CreateMon(..., 40, ...).
const NIVEL: int = 40
## FLAG_LATIOS_OR_LATIAS_ROAMING: ya se emitió el boletín y se soltó al errante.
const BANDERA_LIBERADO: String = "latios_errante_liberado"

## Campos de struct Roamer.
const C_ACTIVO: String = "errante_activo"
const C_IVS: String = "errante_ivs"
const C_PERSONALIDAD: String = "errante_personalidad"
const C_PS: String = "errante_ps"
const C_NIVEL: String = "errante_nivel"
const C_ESTADO: String = "errante_estado"
const C_CARISMA: String = "errante_carisma"
const C_BELLEZA: String = "errante_belleza"
const C_DULZURA: String = "errante_dulzura"
const C_INGENIO: String = "errante_ingenio"
const C_DUREZA: String = "errante_dureza"
const C_VARIOCOLOR: String = "errante_variocolor"
const T_ESPECIE: String = "errante_especie"
const T_NATURALEZA: String = "errante_naturaleza"
const T_SEXO: String = "errante_sexo"

## sRoamerLocations: cada fila empieza por la ruta donde está y sigue con sus
## vecinas; "" = 0xFF (hueco). RoamerMove elige `fila[randi() % 5 + 1]`.
const UBICACIONES: Array = [
	["ruta_110", "ruta_111", "ruta_117", "ruta_118", "ruta_134", ""],
	["ruta_111", "ruta_110", "ruta_117", "ruta_118", "", ""],
	["ruta_117", "ruta_111", "ruta_110", "ruta_118", "", ""],
	["ruta_118", "ruta_117", "ruta_110", "ruta_111", "ruta_119", "ruta_123"],
	["ruta_119", "ruta_118", "ruta_120", "", "", ""],
	["ruta_120", "ruta_119", "ruta_121", "", "", ""],
	["ruta_121", "ruta_120", "ruta_122", "ruta_123", "", ""],
	["ruta_122", "ruta_121", "ruta_123", "", "", ""],
	["ruta_123", "ruta_122", "ruta_118", "", "", ""],
	["ruta_124", "ruta_121", "ruta_125", "ruta_126", "", ""],
	["ruta_125", "ruta_124", "ruta_127", "", "", ""],
	["ruta_126", "ruta_124", "ruta_127", "", "", ""],
	["ruta_127", "ruta_125", "ruta_126", "ruta_128", "", ""],
	["ruta_128", "ruta_127", "ruta_129", "", "", ""],
	["ruta_129", "ruta_128", "ruta_130", "", "", ""],
	["ruta_130", "ruta_129", "ruta_131", "", "", ""],
	["ruta_131", "ruta_130", "ruta_132", "", "", ""],
	["ruta_132", "ruta_131", "ruta_133", "", "", ""],
	["ruta_133", "ruta_132", "ruta_134", "", "", ""],
	["ruta_134", "ruta_133", "ruta_110", "", "", ""],
]

## sRoamerLocation: ruta donde está ("" = ninguna, como 0/0 tras ClearRoamerLocationData).
static var _ubicacion: String = ""
## sLocationHistory[0..2]: los tres últimos mapas en los que ha estado el jugador.
static var _historial: Array[String] = ["", "", ""]


## gSaveBlock1.roamer.active.
static func activo() -> bool:
	return SistemaGuardado.get_contador(C_ACTIVO) != 0


static func ubicacion() -> String:
	return _ubicacion


## Clave de Lugares de la ruta donde vaga ("" si no vaga): el ÁREA de la POKéDEX
## (GetRoamerLocation en pokedex_area_screen.c).
static func seccion() -> String:
	if not activo() or _ubicacion.is_empty():
		return ""
	return _ubicacion.to_upper()


## IsRoamerAt.
static func esta_en(clave_mapa: String) -> bool:
	return activo() and not _ubicacion.is_empty() and clave_mapa == _ubicacion


## Coloca al errante en una ruta concreta (Debug_CreateRoamer, tests).
static func fijar_ubicacion(clave_mapa: String) -> void:
	_ubicacion = clave_mapa


## InitRoamer: ClearRoamerData + ClearRoamerLocationData + CreateInitialRoamerMon.
static func iniciar() -> void:
	borrar_datos()
	borrar_ubicacion()
	_crear_errante_inicial()


## ClearRoamerData (partida nueva).
static func borrar_datos() -> void:
	for clave: String in [C_ACTIVO, C_IVS, C_PERSONALIDAD, C_PS, C_NIVEL, C_ESTADO, C_CARISMA,
			C_BELLEZA, C_DULZURA, C_INGENIO, C_DUREZA, C_VARIOCOLOR]:
		SistemaGuardado.reset_contador(clave)
	for clave: String in [T_ESPECIE, T_NATURALEZA, T_SEXO]:
		SistemaGuardado.set_texto(clave, "")


## ClearRoamerLocationData.
static func borrar_ubicacion() -> void:
	_historial = ["", "", ""]
	_ubicacion = ""


## CreateInitialRoamerMon: LATIOS de Nv. 40 con IV y personalidad al azar, PS al
## máximo y sin estado; empieza en la cabeza de un grupo al azar.
static func _crear_errante_inicial() -> void:
	var pokemon := BasePokemon.new(ESPECIE, NIVEL, "salvaje")
	SistemaGuardado.set_texto(T_ESPECIE, ESPECIE)
	SistemaGuardado.set_contador(C_NIVEL, NIVEL)
	SistemaGuardado.set_contador(C_ESTADO, Singleton.ProblemaEstado.NORMAL)
	SistemaGuardado.set_contador(C_ACTIVO, 1)
	SistemaGuardado.set_contador(C_IVS, empaquetar_ivs(pokemon))
	SistemaGuardado.set_contador(C_PERSONALIDAD, pokemon.personalidad)
	SistemaGuardado.set_contador(C_PS, pokemon.estad_ps)
	SistemaGuardado.set_contador(C_CARISMA, pokemon.carisma)
	SistemaGuardado.set_contador(C_BELLEZA, pokemon.belleza)
	SistemaGuardado.set_contador(C_DULZURA, pokemon.dulzura)
	SistemaGuardado.set_contador(C_INGENIO, pokemon.ingenio)
	SistemaGuardado.set_contador(C_DUREZA, pokemon.dureza)
	SistemaGuardado.set_contador(C_VARIOCOLOR, 1 if pokemon.shiny else 0)
	SistemaGuardado.set_texto(T_NATURALEZA, pokemon.naturaleza)
	SistemaGuardado.set_texto(T_SEXO, pokemon.sexo)
	_ubicacion = str(UBICACIONES[randi() % 20][0])


## MON_DATA_IVS: PS | ATAQUE << 5 | DEFENSA << 10 | VELOCIDAD << 15 | AT. ESP. << 20
## | DEF. ESP. << 25.
static func empaquetar_ivs(pokemon: BasePokemon) -> int:
	return pokemon.iv_ps | (pokemon.iv_ataque << 5) | (pokemon.iv_defensa << 10) \
		| (pokemon.iv_velocidad << 15) | (pokemon.iv_ataque_especial << 20) \
		| (pokemon.iv_defensa_especial << 25)


## UpdateLocationHistoryForRoamer + RoamerMoveToOtherLocationSet (warp, carga de
## partida) o RoamerMove (cruce de borde entre mapas exteriores).
static func al_entrar_en_mapa(clave_mapa: String, cruce_de_borde: bool) -> void:
	actualizar_historial(clave_mapa)
	if cruce_de_borde:
		mover()
	else:
		mover_a_otro_grupo()


## UpdateLocationHistoryForRoamer.
static func actualizar_historial(clave_mapa: String) -> void:
	_historial = [clave_mapa, _historial[0], _historial[1]]


static func historial() -> Array[String]:
	return _historial.duplicate()


## RoamerMoveToOtherLocationSet: salta a la cabeza de otro grupo distinto del actual.
static func mover_a_otro_grupo() -> void:
	if not activo():
		return
	while true:
		var destino := str(UBICACIONES[randi() % 20][0])
		if destino != _ubicacion:
			_ubicacion = destino
			return


## RoamerMove: 1 de cada 16 veces salta de grupo; si no, pasa a una vecina que no
## sea el mapa de hace dos cambios (sLocationHistory[2]).
static func mover() -> void:
	if randi() % 16 == 0:
		mover_a_otro_grupo()
		return
	if not activo():
		return
	for fila: Array in UBICACIONES:
		if str(fila[0]) != _ubicacion:
			continue
		while true:
			var destino := str(fila[randi() % 5 + 1])
			if not destino.is_empty() and destino != _historial[2]:
				_ubicacion = destino
				return


## TryStartRoamerEncounter: con el errante en `clave_mapa`, 1 de cada 4 encuentros.
static func intentar_encuentro(clave_mapa: String) -> bool:
	return esta_en(clave_mapa) and randi() % 4 == 0


## CreateRoamerMonInstance: el LATIOS del combate con la personalidad, PS, estado y
## condiciones guardados (y los IV recortados por el fallo de la ROM).
static func crear_instancia() -> BasePokemon:
	var especie := SistemaGuardado.get_texto(T_ESPECIE)
	var pokemon := BasePokemon.new(especie if not especie.is_empty() else ESPECIE,
		maxi(SistemaGuardado.get_contador(C_NIVEL), 1), "salvaje")
	pokemon.personalidad = SistemaGuardado.get_contador(C_PERSONALIDAD)
	pokemon.asignar_habilidad_por_personalidad()
	var ivs := SistemaGuardado.get_contador(C_IVS) & 0xFF
	var instantanea := {
		"iv_ps": ivs & 0x1F, "iv_ataque": (ivs >> 5) & 0x1F, "iv_defensa": 0,
		"iv_ataque_especial": 0, "iv_defensa_especial": 0, "iv_velocidad": 0,
		"shiny": SistemaGuardado.get_contador(C_VARIOCOLOR) != 0,
		"estado": SistemaGuardado.get_contador(C_ESTADO),
		"estad_ps_actual": SistemaGuardado.get_contador(C_PS),
	}
	var naturaleza := SistemaGuardado.get_texto(T_NATURALEZA)
	if not naturaleza.is_empty():
		instantanea["naturaleza"] = naturaleza
	var sexo := SistemaGuardado.get_texto(T_SEXO)
	if not sexo.is_empty():
		instantanea["sexo"] = sexo
	pokemon.aplicar_snapshot(instantanea)
	pokemon.carisma = SistemaGuardado.get_contador(C_CARISMA)
	pokemon.belleza = SistemaGuardado.get_contador(C_BELLEZA)
	pokemon.dulzura = SistemaGuardado.get_contador(C_DULZURA)
	pokemon.ingenio = SistemaGuardado.get_contador(C_INGENIO)
	pokemon.dureza = SistemaGuardado.get_contador(C_DUREZA)
	return pokemon


## Fin del combate (BATTLE_TYPE_ROAMER en sub_800E7F8 de battle_main.c):
## UpdateRoamerHPStatus guarda PS y estado y salta de grupo; si se le derrota o
## atrapa, SetRoamerInactive.
static func tras_combate(pokemon: BasePokemon, resultado: ResultadoBatalla.Valor) -> void:
	SistemaGuardado.set_contador(C_PS, maxi(pokemon.estad_ps_actual, 0))
	SistemaGuardado.set_contador(C_ESTADO, pokemon.estado)
	mover_a_otro_grupo()
	if resultado == ResultadoBatalla.Valor.VICTORIA_JUGADOR or resultado == ResultadoBatalla.Valor.CAPTURA:
		SistemaGuardado.set_contador(C_ACTIVO, 0)
