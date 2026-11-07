## pokedex_partida.gd
## POKéDEX de la partida: si el jugador la tiene (FLAG_SYS_POKEDEX_GET) y la
## Nacional (FLAG_SYS_NATIONAL_DEX), el modo y orden de la lista
## (gSaveBlock2.pokedex.mode/order) y los registros que muestra
## UI/pokedex/pokedex.tscn. Los vistos y atrapados los registra SistemaGuardado
## (registrar_pokemon_visto / registrar_pokemon_atrapado).
## Sin equivalente todavía: la valoración de ABEDUL
## (ProfBirch_EventScript_AskRatePokedex).
class_name PokedexPartida
extends RefCounted

const TABLAS = preload("res://UI/pokedex/tablas_pokedex.gd")
const ORDENADOR = preload("res://UI/pokedex/ordenador_pokedex.gd")
const BANDERA: String = "pokedex_obtenida"
## La activan las máquinas del laboratorio de ABEDUL con 8 medallas
## (EventoLaboratorioAbedul); sin ella la POKéDEX solo muestra HOENN.
const BANDERA_NACIONAL: String = "dex_nacional"
## CompletedHoennPokedex recorre las 200 primeras entradas de HOENN.
const HOENN_EXIGIDOS: int = 200
## Claves dentro de datos_vivos.pokedex (junto a vistos/atrapados).
const CLAVE_MODO: String = "modo"
const CLAVE_ORDEN: String = "orden"
const RUTA_FRENTE: String = "res://graficos/pokemon/front/%s.png"

## Especies de poke.db en orden nacional; no cambian durante la partida.
static var _especies: Array[Dictionary] = []


## setflag FLAG_SYS_POKEDEX_GET.
static func obtener() -> void:
	SistemaGuardado.set_flag(BANDERA, true)


static func obtenida() -> bool:
	return SistemaGuardado.get_flag(BANDERA)


## setflag FLAG_SYS_NATIONAL_DEX.
static func activar_nacional() -> void:
	SistemaGuardado.set_flag(BANDERA_NACIONAL, true)


static func nacional_disponible() -> bool:
	return SistemaGuardado.get_flag(BANDERA_NACIONAL)


## Sin Dex Nacional el modo siempre es HOENN (pokedex.c fuerza DEX_MODE_HOENN).
## int(): el JSON del guardado devuelve los números como float.
static func modo() -> int:
	if not nacional_disponible():
		return ORDENADOR.Modo.HOENN
	return clampi(int(SistemaGuardado.datos_vivos.pokedex.get(CLAVE_MODO, 0)), 0, ORDENADOR.Modo.size() - 1)


static func orden() -> int:
	return clampi(int(SistemaGuardado.datos_vivos.pokedex.get(CLAVE_ORDEN, 0)), 0, ORDENADOR.Orden.size() - 1)


## Sección donde vaga LATIOS (GetRoamerLocation); "" con el errante inactivo hace
## que su ÁREA sea DESCONOCIDA.
static func seccion_errante() -> String:
	return PokemonErrante.seccion()


## CAMBIO → VALE en el buscador guarda modo y orden en la partida.
static func guardar_vista(nuevo_modo: int, nuevo_orden: int) -> void:
	SistemaGuardado.datos_vivos.pokedex[CLAVE_MODO] = nuevo_modo
	SistemaGuardado.datos_vivos.pokedex[CLAVE_ORDEN] = nuevo_orden


## CompletedHoennPokedex: los 200 primeros de la POKéDEX de HOENN (JIRACHI y DEOXYS, los dos últimos,
## no cuentan) están atrapados.
static func hoenn_completa() -> bool:
	var atrapados: int = 0
	for especie in _cargar_especies():
		var numero: int = int(especie["numero"])
		if numero >= 1 and numero <= HOENN_EXIGIDOS and SistemaGuardado.pokemon_atrapado(str(especie["nombre_interno"])):
			atrapados += 1
	return atrapados >= HOENN_EXIGIDOS


## Contador de POKéDEX del resumen del menú de inicio, calculado sobre un
## guardado sin cargar (`atrapados` y `banderas` tal como salen del JSON).
## Sin POKéDEX: 0; con la de HOENN: atrapados de HOENN; con la Nacional: todos.
static func contar_atrapados_resumen(atrapados: Array, banderas: Dictionary) -> int:
	if not banderas.get(BANDERA, false):
		return 0
	if banderas.get(BANDERA_NACIONAL, false):
		return atrapados.size()
	var total: int = 0
	for especie in _cargar_especies():
		if int(especie["numero"]) > 0 and atrapados.has(especie["nombre_interno"]):
			total += 1
	return total


## Registros para Pokedex.cargar_datos: todas las especies con su n.º Hoenn
## (0 si no es de HOENN), tipos y color de 3.ª gen y lo visto/atrapado.
static func crear_registros() -> Array[Dictionary]:
	var registros: Array[Dictionary] = []
	for especie in _cargar_especies():
		var registro := especie.duplicate(true)
		var interno: String = especie["nombre_interno"]
		registro["atrapado"] = SistemaGuardado.pokemon_atrapado(interno)
		registro["visto"] = registro["atrapado"] or SistemaGuardado.pokemon_visto(interno)
		registros.append(registro)
	return registros


static func _cargar_especies() -> Array[Dictionary]:
	if not _especies.is_empty():
		return _especies
	var hoenn_por_nacional: Dictionary = {}
	for i in TABLAS.HOENN_A_NACIONAL.size():
		hoenn_por_nacional[TABLAS.HOENN_A_NACIONAL[i]] = i + 1
	var consulta := """SELECT p.numero_nacional, p.nombre_interno, p.nombre,
		t1.nombre AS tipo_1, t2.nombre AS tipo_2, p.color, p.peso, p.altura
		FROM Pokemon p
		LEFT JOIN Tipos t1 ON t1.id = p.tipo_1_id
		LEFT JOIN Tipos t2 ON t2.id = p.tipo_2_id
		ORDER BY p.numero_nacional"""
	if not DatabaseManager.ejecutar_consulta(consulta):
		push_error("[POKEDEX] No se pudieron leer las especies de poke.db")
		return _especies
	for fila in DatabaseManager.obtener_resultados():
		var nacional := int(fila["numero_nacional"])
		var tipos: Array = TABLAS.TIPOS_GEN3.get(nacional, [])
		if tipos.is_empty():
			tipos = [str(fila["tipo_1"])]
			if fila["tipo_2"] != null and str(fila["tipo_2"]) != str(fila["tipo_1"]):
				tipos.append(str(fila["tipo_2"]))
		_especies.append({
			"numero": int(hoenn_por_nacional.get(nacional, 0)),
			"nacional": nacional,
			"nombre_interno": str(fila["nombre_interno"]),
			"nombre": str(fila["nombre"]),
			"tipos": tipos.duplicate(),
			"color": str(TABLAS.COLORES_GEN3.get(nacional, fila["color"])),
			"peso": float(fila["peso"]),
			"altura": float(fila["altura"]),
			# Los frentes se llaman por nombre interno (NIDORAN_F, MRMIME...).
			"sprite": RUTA_FRENTE % str(fila["nombre_interno"]),
		})
	return _especies
