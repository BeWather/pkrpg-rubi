extends RefCounted
class_name CajasPC

# ===================================
# SISTEMA DE CAJAS DEL PC - GESTOR DE DATOS
# ===================================

# Constantes del sistema
## Número de cajas: pokeruby TOTAL_BOXES_COUNT (= SistemaGuardado.TOTAL_CAJAS_PC).
const MAX_CAJAS: int = 14
const POKEMON_POR_CAJA: int = 30
const MAX_POKEMON_TOTAL: int = MAX_CAJAS * POKEMON_POR_CAJA  # 420 total
## Papeles pintados disponibles (pokeruby: 16 fondos para 14 cajas).
const TOTAL_FONDOS: int = 16

# Nombres por defecto de las cajas
const NOMBRES_DEFAULT: Array[String] = [
	"CAJA 1", "CAJA 2", "CAJA 3", "CAJA 4",
	"CAJA 5", "CAJA 6", "CAJA 7", "CAJA 8",
	"CAJA 9", "CAJA 10", "CAJA 11", "CAJA 12",
	"CAJA 13", "CAJA 14"
]

# Fondos por defecto de las cajas (IDs de 0-13)
const FONDOS_DEFAULT: Array[int] = [
	0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13
]

## Pokémon que venían en cajas fuera de rango (partidas guardadas con 16 cajas)
## y no cupieron en ningún hueco libre de las 14 cajas. Se conservan aquí para
## que la sincronización los vuelva a guardar en vez de perderlos.
var pokemon_sin_hueco: Array[BasePokemon] = []

# Estructura de datos principal
var datos_cajas: Dictionary = {
	"caja_actual": 0,
	"nombres_cajas": [],
	"fondos_cajas": [],
	"pokemones": {}  # Clave: "caja_X", Valor: Array[BasePokemon] (30 elementos, null para vacío)
}

## Variables de estado
var inicializado: bool = false

## Constructor - Inicializa la estructura de cajas.
func _init() -> void:
	print("📦 [CAJAS PC] Inicializando gestor de cajas...")
	_inicializar_estructura()
	print("✅ [CAJAS PC] Gestor inicializado correctamente")

# ===================================
# INICIALIZACIÓN Y CONFIGURACIÓN
# ===================================

## Inicializa la estructura completa de cajas vacías.
func _inicializar_estructura() -> void:
	# Inicializar nombres con valores por defecto
	datos_cajas.nombres_cajas = NOMBRES_DEFAULT.duplicate()
	
	# Inicializar fondos con valores por defecto
	datos_cajas.fondos_cajas = FONDOS_DEFAULT.duplicate()
	
	# Inicializar cajas vacías
	for i in range(MAX_CAJAS):
		var clave_caja = "caja_%d" % i
		datos_cajas.pokemones[clave_caja] = []
		
		# Llenar con slots vacíos (null)
		for j in range(POKEMON_POR_CAJA):
			datos_cajas.pokemones[clave_caja].append(null)
	
	# Establecer caja inicial
	datos_cajas.caja_actual = 0
	inicializado = true
	
	print("📋 [CAJAS PC] Estructura inicializada: %d cajas, %d slots c/u" % [MAX_CAJAS, POKEMON_POR_CAJA])

## Carga los datos de las cajas desde el sistema de guardado.
func cargar_desde_guardado(datos_guardado: Dictionary) -> void:
	if not datos_guardado.has("cajas_pc"):
		print("⚠️ [CAJAS PC] No hay datos de cajas en el guardado, usando estructura vacía")
		return
	
	var datos_pc = datos_guardado.cajas_pc
	
	# Cargar caja actual
	datos_cajas.caja_actual = datos_pc.get("caja_actual", 0)
	
	# Cargar nombres (con fallback a defaults)
	if datos_pc.has("nombres_cajas") and datos_pc.nombres_cajas.size() == MAX_CAJAS:
		datos_cajas.nombres_cajas = datos_pc.nombres_cajas.duplicate()
	else:
		datos_cajas.nombres_cajas = NOMBRES_DEFAULT.duplicate()
	
	# Cargar fondos (con fallback a defaults)
	if datos_pc.has("fondos_cajas") and datos_pc.fondos_cajas.size() == MAX_CAJAS:
		datos_cajas.fondos_cajas = datos_pc.fondos_cajas.duplicate()
	else:
		datos_cajas.fondos_cajas = FONDOS_DEFAULT.duplicate()
	
	# Cargar Pokémon
	if datos_pc.has("pokemones"):
		datos_cajas.pokemones = datos_pc.pokemones.duplicate(true)
	
	# Validar integridad de datos
	_validar_integridad()
	
	print("📥 [CAJAS PC] Datos cargados desde guardado")

## Exporta los datos de las cajas para el sistema de guardado.
func exportar_para_guardado() -> Dictionary:
	return {
		"caja_actual": datos_cajas.caja_actual,
		"nombres_cajas": datos_cajas.nombres_cajas.duplicate(),
		"fondos_cajas": datos_cajas.fondos_cajas.duplicate(),
		"pokemones": datos_cajas.pokemones.duplicate(true)
	}

# ===================================
# API PRINCIPAL - GESTIÓN DE POKÉMON
# ===================================

## Obtiene el Pokémon en una posición específica.
func obtener_pokemon(caja: int, slot: int) -> BasePokemon:
	if not _validar_coordenadas(caja, slot):
		return null
	
	var clave_caja = "caja_%d" % caja
	if not datos_cajas.pokemones.has(clave_caja):
		return null
	
	return datos_cajas.pokemones[clave_caja][slot]

## Coloca un Pokémon en una posición específica.
func colocar_pokemon(caja: int, slot: int, pokemon: BasePokemon) -> bool:
	if not _validar_coordenadas(caja, slot):
		print("❌ [CAJAS PC] Coordenadas inválidas: caja=%d, slot=%d" % [caja, slot])
		return false
	
	if pokemon == null:
		print("❌ [CAJAS PC] No se puede colocar un Pokémon nulo")
		return false
	
	var clave_caja = "caja_%d" % caja
	datos_cajas.pokemones[clave_caja][slot] = pokemon
	
	print("✅ [CAJAS PC] %s colocado en caja %d, slot %d" % [pokemon.nombre_interno, caja, slot])
	return true

## Quita y devuelve el Pokémon de una posición específica.
func quitar_pokemon(caja: int, slot: int) -> BasePokemon:
	var pokemon = obtener_pokemon(caja, slot)
	if pokemon:
		var clave_caja = "caja_%d" % caja
		datos_cajas.pokemones[clave_caja][slot] = null
		print("🗑️ [CAJAS PC] %s retirado de caja %d, slot %d" % [pokemon.nombre_interno, caja, slot])
	
	return pokemon

## Intercambia dos Pokémon de posición.
func intercambiar_pokemon(origen_caja: int, origen_slot: int, destino_caja: int, destino_slot: int) -> bool:
	if not _validar_coordenadas(origen_caja, origen_slot) or not _validar_coordenadas(destino_caja, destino_slot):
		return false
	
	var pokemon_origen = obtener_pokemon(origen_caja, origen_slot)
	var pokemon_destino = obtener_pokemon(destino_caja, destino_slot)
	
	# Intercambiar posiciones
	var clave_origen = "caja_%d" % origen_caja
	var clave_destino = "caja_%d" % destino_caja
	
	datos_cajas.pokemones[clave_origen][origen_slot] = pokemon_destino
	datos_cajas.pokemones[clave_destino][destino_slot] = pokemon_origen
	
	print("🔄 [CAJAS PC] Intercambio completado entre (%d,%d) y (%d,%d)" % [origen_caja, origen_slot, destino_caja, destino_slot])
	return true

## Mueve un Pokémon de una posición a otra (el destino debe estar vacío).
func mover_pokemon(origen_caja: int, origen_slot: int, destino_caja: int, destino_slot: int) -> bool:
	if not esta_slot_vacio(destino_caja, destino_slot):
		print("❌ [CAJAS PC] El slot destino no está vacío")
		return false
	
	var pokemon = quitar_pokemon(origen_caja, origen_slot)
	if pokemon:
		return colocar_pokemon(destino_caja, destino_slot, pokemon)
	
	return false

# ===================================
# CONSULTAS Y UTILIDADES
# ===================================

## Verifica si un slot está vacío.
func esta_slot_vacio(caja: int, slot: int) -> bool:
	return obtener_pokemon(caja, slot) == null

## Obtiene el número de espacios libres en una caja específica o en total.
func obtener_espacios_libres(caja: int = -1) -> int:
	var espacios_libres = 0
	
	if caja == -1:
		# Contar en todas las cajas
		for i in range(MAX_CAJAS):
			espacios_libres += obtener_espacios_libres(i)
	else:
		# Contar en caja específica
		if not _validar_caja(caja):
			return 0
		
		var clave_caja = "caja_%d" % caja
		for slot in datos_cajas.pokemones[clave_caja]:
			if slot == null:
				espacios_libres += 1
	
	return espacios_libres

## Obtiene todos los Pokémon de una caja (incluyendo nulls para slots vacíos).
func obtener_pokemon_en_caja(caja: int) -> Array[BasePokemon]:
	if not _validar_caja(caja):
		var vacio: Array[BasePokemon] = []
		return vacio
	
	var clave_caja = "caja_%d" % caja
	var resultado: Array[BasePokemon] = []
	resultado.assign(datos_cajas.pokemones[clave_caja])
	return resultado

## Busca Pokémon por nombre y devuelve array de {caja, slot, pokemon}.
func buscar_pokemon(nombre: String) -> Array:
	var resultados = []
	
	for caja in range(MAX_CAJAS):
		var clave_caja = "caja_%d" % caja
		for slot in range(POKEMON_POR_CAJA):
			var pokemon = datos_cajas.pokemones[clave_caja][slot]
			if pokemon and pokemon.nombre_interno.to_lower().contains(nombre.to_lower()):
				resultados.append({
					"caja": caja,
					"slot": slot,
					"pokemon": pokemon
				})
	
	return resultados

## Cuenta el total de Pokémon almacenados en todas las cajas.
func contar_pokemon_total() -> int:
	var total = 0
	
	for caja in range(MAX_CAJAS):
		var clave_caja = "caja_%d" % caja
		for pokemon in datos_cajas.pokemones[clave_caja]:
			if pokemon != null:
				total += 1
	
	return total

# ===================================
# GESTIÓN DE CAJAS
# ===================================

## Obtiene el nombre de una caja específica.
func obtener_nombre_caja(caja: int) -> String:
	if not _validar_caja(caja):
		return "CAJA INVÁLIDA"
	
	return datos_cajas.nombres_cajas[caja]

## Cambia el nombre de una caja.
func cambiar_nombre_caja(caja: int, nuevo_nombre: String) -> bool:
	if not _validar_caja(caja):
		return false
	
	# Validar longitud del nombre (máximo 16 caracteres)
	if nuevo_nombre.length() > 16:
		nuevo_nombre = nuevo_nombre.substr(0, 16)
	
	datos_cajas.nombres_cajas[caja] = nuevo_nombre
	print("📝 [CAJAS PC] Caja %d renombrada a: %s" % [caja, nuevo_nombre])
	return true

## Obtiene el ID del fondo de una caja específica.
func obtener_fondo_caja(caja: int) -> int:
	if not _validar_caja(caja):
		return 0
	
	return datos_cajas.fondos_cajas[caja]

## Cambia el fondo de una caja.
func cambiar_fondo_caja(caja: int, id_fondo: int) -> bool:
	if not _validar_caja(caja) or id_fondo < 0 or id_fondo >= TOTAL_FONDOS:
		return false
	
	datos_cajas.fondos_cajas[caja] = id_fondo
	print("🎨 [CAJAS PC] Fondo de caja %d cambiado a: %d" % [caja, id_fondo])
	return true

## Obtiene el índice de la caja actualmente seleccionada.
func obtener_caja_actual() -> int:
	return datos_cajas.caja_actual

## Cambia la caja actualmente seleccionada.
func cambiar_caja_actual(caja: int) -> bool:
	if not _validar_caja(caja):
		return false
	
	datos_cajas.caja_actual = caja
	return true

# ===================================
# OPERACIONES AVANZADAS
# ===================================

## Encuentra el primer slot vacío en una caja específica o en cualquiera.
func encontrar_primer_slot_vacio(caja: int = -1) -> Vector2i:
	if caja != -1:
		# Buscar en caja específica
		if not _validar_caja(caja):
			return Vector2i(-1, -1)
		
		var clave_caja = "caja_%d" % caja
		for slot in range(POKEMON_POR_CAJA):
			if datos_cajas.pokemones[clave_caja][slot] == null:
				return Vector2i(caja, slot)
	else:
		# Buscar en todas las cajas
		for i in range(MAX_CAJAS):
			var resultado = encontrar_primer_slot_vacio(i)
			if resultado != Vector2i(-1, -1):
				return resultado
	
	return Vector2i(-1, -1)  # No hay espacios libres

## Organiza los Pokémon de una caja según un criterio.
func organizar_caja(caja: int, criterio: String = "numero") -> bool:
	if not _validar_caja(caja):
		return false
	
	var clave_caja = "caja_%d" % caja
	var pokemones = []
	
	# Extraer Pokémon no nulos
	for pokemon in datos_cajas.pokemones[clave_caja]:
		if pokemon != null:
			pokemones.append(pokemon)
	
	# Ordenar según criterio
	match criterio:
		"numero":
			pokemones.sort_custom(_comparar_por_numero)
		"nivel":
			pokemones.sort_custom(_comparar_por_nivel)
		"nombre":
			pokemones.sort_custom(_comparar_por_nombre)
	
	# Limpiar caja y repoblar
	datos_cajas.pokemones[clave_caja] = []
	for i in range(POKEMON_POR_CAJA):
		if i < pokemones.size():
			datos_cajas.pokemones[clave_caja].append(pokemones[i])
		else:
			datos_cajas.pokemones[clave_caja].append(null)
	
	print("📊 [CAJAS PC] Caja %d organizada por %s" % [caja, criterio])
	return true

# ===================================
# VALIDACIONES Y UTILIDADES INTERNAS
# ===================================

## Valida que las coordenadas sean válidas.
func _validar_coordenadas(caja: int, slot: int) -> bool:
	return _validar_caja(caja) and slot >= 0 and slot < POKEMON_POR_CAJA

## Valida que el número de caja sea válido.
func _validar_caja(caja: int) -> bool:
	return caja >= 0 and caja < MAX_CAJAS

## Valida la integridad de los datos y corrige inconsistencias.
func _validar_integridad() -> void:
	# Verificar que todas las cajas existan
	for i in range(MAX_CAJAS):
		var clave_caja = "caja_%d" % i
		if not datos_cajas.pokemones.has(clave_caja):
			datos_cajas.pokemones[clave_caja] = []
			for j in range(POKEMON_POR_CAJA):
				datos_cajas.pokemones[clave_caja].append(null)
		elif datos_cajas.pokemones[clave_caja].size() != POKEMON_POR_CAJA:
			# Redimensionar si es necesario
			datos_cajas.pokemones[clave_caja].resize(POKEMON_POR_CAJA)
	
	# Verificar nombres y fondos
	if datos_cajas.nombres_cajas.size() != MAX_CAJAS:
		datos_cajas.nombres_cajas = NOMBRES_DEFAULT.duplicate()
	
	if datos_cajas.fondos_cajas.size() != MAX_CAJAS:
		datos_cajas.fondos_cajas = FONDOS_DEFAULT.duplicate()
	
	# Validar caja actual
	if datos_cajas.caja_actual < 0 or datos_cajas.caja_actual >= MAX_CAJAS:
		datos_cajas.caja_actual = 0

## Funciones de comparación para ordenamiento
func _comparar_por_numero(a: BasePokemon, b: BasePokemon) -> bool:
	return a.numero_nacional < b.numero_nacional

func _comparar_por_nivel(a: BasePokemon, b: BasePokemon) -> bool:
	return a.nivel > b.nivel  # De mayor a menor nivel

func _comparar_por_nombre(a: BasePokemon, b: BasePokemon) -> bool:
	return a.nombre_interno < b.nombre_interno

# ===================================
# DEBUG E INFORMACIÓN
# ===================================

## Devuelve información de debug del sistema.
func debug_info() -> String:
	var info = []
	info.append("=== CAJAS PC - DEBUG INFO ===")
	info.append("Cajas inicializadas: %d" % MAX_CAJAS)
	info.append("Pokémon por caja: %d" % POKEMON_POR_CAJA)
	info.append("Caja actual: %d" % datos_cajas.caja_actual)
	info.append("Pokémon total: %d/%d" % [contar_pokemon_total(), MAX_POKEMON_TOTAL])
	info.append("Espacios libres totales: %d" % obtener_espacios_libres())
	
	return "\n".join(info)

## Devuelve información de debug de una caja específica.
func debug_caja(caja: int) -> String:
	if not _validar_caja(caja):
		return "Caja inválida: %d" % caja
	
	var info = []
	info.append("=== CAJA %d - %s ===" % [caja, obtener_nombre_caja(caja)])
	info.append("Fondo: %d" % obtener_fondo_caja(caja))
	info.append("Espacios libres: %d/%d" % [obtener_espacios_libres(caja), POKEMON_POR_CAJA])
	
	var clave_caja = "caja_%d" % caja
	for i in range(POKEMON_POR_CAJA):
		var pokemon = datos_cajas.pokemones[clave_caja][i]
		if pokemon:
			info.append("  Slot %d: %s Nv.%d" % [i, pokemon.nombre_interno, pokemon.nivel])
		else:
			info.append("  Slot %d: [VACÍO]" % i)
	
	return "\n".join(info)

# ===================================
# DATOS DE PRUEBA
# ===================================

## Genera datos de prueba para las cajas PC con Pokémon aleatorios.
## PATRÓN ANTERIOR (comentado para uso futuro):
## - CAJA 0: Completamente llena (30 Pokémon)
## - CAJA 1: Con 6 espacios vacíos intercalados (24 Pokémon)  
## - CAJAS 2-4: Con último slot ocupado y algunos Pokémon aleatorios
func generar_datos_prueba() -> void:
	print("🎲 [CAJAS PC] Generando datos de prueba (1 especie por Pokémon)...")
	
	# Verificar que la base de datos esté disponible
	if not DatabaseManager.esta_conectado():
		print("❌ [CAJAS PC] Base de datos no disponible para generar datos de prueba")
		return
	
	# NUEVO PATRÓN: 1 Pokémon de cada especie, 2 slots vacíos aleatorios por caja
	_llenar_cajas_una_especie_por_pokemon()
	
	print("✅ [CAJAS PC] Datos de prueba generados correctamente")
	print("📊 [CAJAS PC] Total de Pokémon generados: %d" % contar_pokemon_total())

## Llena las cajas con un Pokémon de cada especie disponible.
## Los Pokémon aparecen ordenados por número de Pokédex.
## Deja 2 slots aleatorios vacíos por caja.
func _llenar_cajas_una_especie_por_pokemon() -> void:
	print("🎯 [CAJAS PC] Llenando cajas con especies ordenadas por Pokédex...")
	
	# Obtener lista de todas las especies disponibles (1-386 para las primeras 3 generaciones)
	# MANTENER ORDEN SECUENCIAL - NO mezclar
	var especies_disponibles: Array[int] = []
	for numero in range(1, 387):  # 1 a 386
		especies_disponibles.append(numero)
	
	print("📋 [CAJAS PC] Generando %d especies en orden: #001 Bulbasaur → #386 Deoxys" % especies_disponibles.size())
	
	var indice_especie = 0
	var caja_actual = 0
	
	# Llenar cajas una por una
	while indice_especie < especies_disponibles.size() and caja_actual < MAX_CAJAS:
		indice_especie = _llenar_caja_con_especies_ordenadas(caja_actual, especies_disponibles, indice_especie)
		caja_actual += 1
	
	print("✅ [CAJAS PC] %d cajas llenadas con especies ordenadas por Pokédex" % caja_actual)

## Llena una caja específica con especies ordenadas secuencialmente y 2 slots vacíos aleatorios.
func _llenar_caja_con_especies_ordenadas(caja: int, especies: Array[int], indice_inicial: int) -> int:
	print("🎯 [CAJAS PC] Llenando caja %d con especies ordenadas..." % caja)
	
	# Determinar qué slots van a estar vacíos (2 aleatorios)
	var slots_vacios: Array[int] = []
	slots_vacios.append(randi_range(0, POKEMON_POR_CAJA - 1))
	# Asegurar que el segundo slot vacío sea diferente
	var segundo_slot_vacio = randi_range(0, POKEMON_POR_CAJA - 1)
	while segundo_slot_vacio == slots_vacios[0]:
		segundo_slot_vacio = randi_range(0, POKEMON_POR_CAJA - 1)
	slots_vacios.append(segundo_slot_vacio)
	
	print("  - Slots vacíos en caja %d: %s" % [caja, str(slots_vacios)])
	
	# Llenar los slots en orden secuencial, saltando los slots vacíos
	var pokemon_colocados = 0
	var indice_especie = indice_inicial
	var especies_en_caja: Array[int] = []
	
	for slot in range(POKEMON_POR_CAJA):
		# Saltar slots que deben estar vacíos
		if slot in slots_vacios:
			continue
			
		# Verificar que aún hay especies disponibles
		if indice_especie >= especies.size():
			break
			
		var numero_pokemon = especies[indice_especie]
		
		# Crear Pokémon de esta especie
		var pokemon = _crear_pokemon_de_especie(numero_pokemon)
		if pokemon:
			colocar_pokemon(caja, slot, pokemon)
			especies_en_caja.append(numero_pokemon)
			pokemon_colocados += 1
		
		indice_especie += 1
	
	# Cambiar nombre de la caja con el rango real de especies colocadas
	if especies_en_caja.size() > 0:
		cambiar_nombre_caja(caja, "ESPECIES %03d-%03d" % [especies_en_caja[0], especies_en_caja[-1]])
	else:
		cambiar_nombre_caja(caja, "CAJA VACÍA")
	
	print("  - Pokémon colocados en caja %d: %d (especies #%03d-#%03d)" % [
		caja, 
		pokemon_colocados, 
		especies_en_caja[0] if especies_en_caja.size() > 0 else 0,
		especies_en_caja[-1] if especies_en_caja.size() > 0 else 0
	])
	
	return indice_especie

# ===================================
# FUNCIONES DEL PATRÓN ANTERIOR (PARA USO FUTURO)
# ===================================

## Llena una caja completamente con Pokémon aleatorios.
func _llenar_caja_completa(caja: int) -> void:
	print("🎯 [CAJAS PC] Llenando caja %d completamente..." % caja)
	
	for slot in range(POKEMON_POR_CAJA):
		var pokemon = _crear_pokemon_aleatorio()
		if pokemon:
			colocar_pokemon(caja, slot, pokemon)
	
	# Cambiar nombre de la caja
	cambiar_nombre_caja(caja, "CAJA COMPLETA")

## Llena una caja con espacios vacíos intercalados.
func _llenar_caja_con_espacios_intercalados(caja: int) -> void:
	print("🎯 [CAJAS PC] Llenando caja %d con espacios intercalados..." % caja)
	
	# Definir slots que estarán vacíos (6 espacios intercalados)
	var slots_vacios = [3, 7, 12, 18, 23, 27]
	
	for slot in range(POKEMON_POR_CAJA):
		if slot in slots_vacios:
			# Dejar vacío
			continue
		
		var pokemon = _crear_pokemon_aleatorio()
		if pokemon:
			colocar_pokemon(caja, slot, pokemon)
	
	# Cambiar nombre de la caja
	cambiar_nombre_caja(caja, "ESPACIOS LIBRES")

## Llena una caja con el último slot ocupado y algunos Pokémon aleatorios.
func _llenar_caja_ultimo_slot(caja: int) -> void:
	print("🎯 [CAJAS PC] Llenando caja %d con último slot ocupado..." % caja)
	
	# Generar entre 5-15 Pokémon aleatorios
	var cantidad_pokemon = randi_range(5, 15)
	var slots_usados = []
	
	# Asegurar que el último slot (29) esté ocupado
	var pokemon_ultimo = _crear_pokemon_aleatorio()
	if pokemon_ultimo:
		colocar_pokemon(caja, POKEMON_POR_CAJA - 1, pokemon_ultimo)
		slots_usados.append(POKEMON_POR_CAJA - 1)
	
	# Llenar slots aleatorios
	for i in range(cantidad_pokemon - 1):  # -1 porque ya pusimos uno en el último slot
		var slot_aleatorio = randi_range(0, POKEMON_POR_CAJA - 2)  # Excluir último slot
		
		# Evitar duplicar slots
		while slot_aleatorio in slots_usados:
			slot_aleatorio = randi_range(0, POKEMON_POR_CAJA - 2)
		
		var pokemon = _crear_pokemon_aleatorio()
		if pokemon:
			colocar_pokemon(caja, slot_aleatorio, pokemon)
			slots_usados.append(slot_aleatorio)
	
	# Cambiar nombre de la caja
	cambiar_nombre_caja(caja, "CAJA %d" % (caja + 1))

## Crea un Pokémon aleatorio usando datos de la base de datos.
func _crear_pokemon_aleatorio() -> BasePokemon:
	# Obtener un número aleatorio entre 1 y 386 (primera a tercera generación)
	var numero_pokemon = randi_range(1, 386)
	
	# Obtener datos del Pokémon de la base de datos
	var datos_especie = DatabaseManager.obtener_pokemon_por_numero(numero_pokemon)
	if not datos_especie:
		print("⚠️ [CAJAS PC] No se encontraron datos para Pokémon #%d" % numero_pokemon)
		return null
	
	# Crear instancia de BasePokemon
	var pokemon = BasePokemon.new()
	
	# Configurar datos básicos
	pokemon.numero_nacional = numero_pokemon
	pokemon.nombre_interno = datos_especie.get("nombre", "???")
	pokemon.nivel = randi_range(5, 50)  # Nivel aleatorio entre 5 y 50
	
	# Configurar tipos
	var tipo1 = datos_especie.get("tipo1", "")
	var tipo2 = datos_especie.get("tipo2", "")
	pokemon.tipo_1 = tipo1
	if tipo2 != "" and tipo2 != tipo1:
		pokemon.tipo_2 = tipo2
	else:
		pokemon.tipo_2 = ""
	
	# Configurar estadísticas base desde la base de datos
	var base_ps = datos_especie.get("base_ps", 50)
	var base_atq = datos_especie.get("base_atq", 50)
	var base_def = datos_especie.get("base_def", 50)
	var base_atq_esp = datos_especie.get("base_atq_esp", 50)
	var base_def_esp = datos_especie.get("base_def_esp", 50)
	var base_vel = datos_especie.get("base_vel", 50)
	
	# Configurar IVs aleatorios (0-31)
	pokemon.iv_ps = randi_range(0, 31)
	pokemon.iv_ataque = randi_range(0, 31)
	pokemon.iv_defensa = randi_range(0, 31)
	pokemon.iv_ataque_especial = randi_range(0, 31)
	pokemon.iv_defensa_especial = randi_range(0, 31)
	pokemon.iv_velocidad = randi_range(0, 31)
	
	# Calcular estadísticas finales
	pokemon.estad_ps = pokemon.get_calc_stat_hp(base_ps, pokemon.iv_ps, pokemon.ev_ps, pokemon.nivel)
	pokemon.estad_ataque = pokemon.get_calc_stat(base_atq, pokemon.iv_ataque, pokemon.ev_ataque, pokemon.nivel)
	pokemon.estad_defensa = pokemon.get_calc_stat(base_def, pokemon.iv_defensa, pokemon.ev_defensa, pokemon.nivel)
	pokemon.estad_ataque_especial = pokemon.get_calc_stat(base_atq_esp, pokemon.iv_ataque_especial, pokemon.ev_ataque_especial, pokemon.nivel)
	pokemon.estad_defensa_especial = pokemon.get_calc_stat(base_def_esp, pokemon.iv_defensa_especial, pokemon.ev_defensa_especial, pokemon.nivel)
	pokemon.estad_velocidad = pokemon.get_calc_stat(base_vel, pokemon.iv_velocidad, pokemon.ev_velocidad, pokemon.nivel)
	
	# Configurar características adicionales
	pokemon.experiencia = pokemon.get_exp_nivel(pokemon.nivel, "medium_fast")  # Usar ratio de crecimiento por defecto
	pokemon.sexo = "M" if randi() % 2 == 0 else "F"
	pokemon.shiny = (randi() % 100) < 5  # 5% de probabilidad de ser shiny (aumentado para pruebas)
	pokemon.naturaleza = _obtener_naturaleza_aleatoria()
	pokemon.habilidad = str(datos_especie.get("habilidad_1", ""))
	
	# Configurar marcas aleatorias (30% de probabilidad de tener marcas)
	if randi() % 100 < 30:
		var marcas_disponibles = ["circulo", "cuadrado", "triangulo", "corazon"]
		var cantidad_marcas = randi_range(1, 3)  # Entre 1 y 3 marcas
		
		for i in range(cantidad_marcas):
			var marca = marcas_disponibles[randi() % marcas_disponibles.size()]
			pokemon.marcas[marca] = true
			# Evitar duplicados para la siguiente iteración
			marcas_disponibles.erase(marca)
			if marcas_disponibles.size() == 0:
				break
	
	# Configurar movimientos aleatorios con objetos Movimiento
	pokemon.movimientos = _obtener_movimientos_aleatorios()
	
	# Configurar metadatos
	pokemon.entrenador_original = "RUBY"
	pokemon.entrenador_id = 12345
	pokemon.encuentro_bola = "pokeball"
	pokemon.encuentro_lugar = "RUTA_101"
	
	return pokemon

## Crea un Pokémon específico de una especie dada usando datos de la base de datos.
func _crear_pokemon_de_especie(numero_pokemon: int) -> BasePokemon:
	# Obtener datos del Pokémon de la base de datos
	var datos_especie = DatabaseManager.obtener_pokemon_por_numero(numero_pokemon)
	if not datos_especie:
		print("⚠️ [CAJAS PC] No se encontraron datos para Pokémon #%d" % numero_pokemon)
		return null
	
	# Crear instancia de BasePokemon
	var pokemon = BasePokemon.new()
	
	# Configurar datos básicos
	pokemon.numero_nacional = numero_pokemon
	pokemon.nombre_interno = datos_especie.get("nombre_interno", "???")
	pokemon.nombre = datos_especie.get("nombre", "???")
	pokemon.nivel = randi_range(10, 40)  # Nivel aleatorio entre 10 y 40
	
	# Configurar tipos
	var tipo1 = datos_especie.get("tipo1", "")
	var tipo2 = datos_especie.get("tipo2", "")
	pokemon.tipo_1 = tipo1
	if tipo2 != "" and tipo2 != tipo1:
		pokemon.tipo_2 = tipo2
	else:
		pokemon.tipo_2 = ""
	
	# Configurar estadísticas base desde la base de datos
	var base_ps = datos_especie.get("base_ps", 50)
	var base_atq = datos_especie.get("base_atq", 50)
	var base_def = datos_especie.get("base_def", 50)
	var base_atq_esp = datos_especie.get("base_atq_esp", 50)
	var base_def_esp = datos_especie.get("base_def_esp", 50)
	var base_vel = datos_especie.get("base_vel", 50)
	
	# Configurar IVs aleatorios pero balanceados (15-31 para mejor calidad)
	pokemon.iv_ps = randi_range(15, 31)
	pokemon.iv_ataque = randi_range(15, 31)
	pokemon.iv_defensa = randi_range(15, 31)
	pokemon.iv_ataque_especial = randi_range(15, 31)
	pokemon.iv_defensa_especial = randi_range(15, 31)
	pokemon.iv_velocidad = randi_range(15, 31)
	
	# Calcular estadísticas finales
	pokemon.estad_ps = pokemon.get_calc_stat_hp(base_ps, pokemon.iv_ps, pokemon.ev_ps, pokemon.nivel)
	pokemon.estad_ataque = pokemon.get_calc_stat(base_atq, pokemon.iv_ataque, pokemon.ev_ataque, pokemon.nivel)
	pokemon.estad_defensa = pokemon.get_calc_stat(base_def, pokemon.iv_defensa, pokemon.ev_defensa, pokemon.nivel)
	pokemon.estad_ataque_especial = pokemon.get_calc_stat(base_atq_esp, pokemon.iv_ataque_especial, pokemon.ev_ataque_especial, pokemon.nivel)
	pokemon.estad_defensa_especial = pokemon.get_calc_stat(base_def_esp, pokemon.iv_defensa_especial, pokemon.ev_defensa_especial, pokemon.nivel)
	pokemon.estad_velocidad = pokemon.get_calc_stat(base_vel, pokemon.iv_velocidad, pokemon.ev_velocidad, pokemon.nivel)
	
	# Configurar características adicionales
	pokemon.experiencia = pokemon.get_exp_nivel(pokemon.nivel, "medium_fast")  # Usar ratio de crecimiento por defecto
	pokemon.sexo = "M" if randi() % 2 == 0 else "F"
	pokemon.shiny = (randi() % 200) < 1  # 0.5% de probabilidad de ser shiny (más realista)
	pokemon.naturaleza = _obtener_naturaleza_aleatoria()
	pokemon.habilidad = str(datos_especie.get("habilidad_1", ""))
	
	# Configurar marcas aleatorias (15% de probabilidad de tener marcas para más variedad)
	if randi() % 100 < 15:
		var marcas_disponibles = ["circulo", "cuadrado", "triangulo", "corazon"]
		var cantidad_marcas = randi_range(1, 2)  # Entre 1 y 2 marcas
		
		for i in range(cantidad_marcas):
			var marca = marcas_disponibles[randi() % marcas_disponibles.size()]
			pokemon.marcas[marca] = true
			# Evitar duplicados para la siguiente iteración
			marcas_disponibles.erase(marca)
			if marcas_disponibles.size() == 0:
				break
	
	# Configurar movimientos aleatorios con objetos Movimiento
	pokemon.movimientos = _obtener_movimientos_aleatorios()
	
	# Configurar metadatos
	pokemon.entrenador_original = "RUBY"
	pokemon.entrenador_id = 12345
	pokemon.encuentro_bola = "pokeball"
	pokemon.encuentro_lugar = "RUTA_%d" % randi_range(101, 134)  # Rutas aleatorias de Hoenn
	
	return pokemon

## Obtiene una naturaleza aleatoria.
func _obtener_naturaleza_aleatoria() -> String:
	var naturalezas = [
		"Hardy", "Lonely", "Brave", "Adamant", "Naughty",
		"Bold", "Docile", "Relaxed", "Impish", "Lax",
		"Timid", "Hasty", "Serious", "Jolly", "Naive",
		"Modest", "Mild", "Quiet", "Bashful", "Rash",
		"Calm", "Gentle", "Sassy", "Careful", "Quirky"
	]
	return naturalezas[randi() % naturalezas.size()]

## Movimientos (nombre_interno de la tabla Movimientos) entre los que se sortean
## los de los Pokémon de prueba.
const MOVIMIENTOS_PRUEBA: Array[String] = [
	"PLACAJE", "ARANAZO", "GRUNIDO", "LATIGO", "ATRAPIDO",
	"ASCUAS", "PISTOLAAGUA", "LATIGOCEPA", "IMPACTRUENO", "CONFUSION",
]

## Obtiene movimientos aleatorios para un Pokémon.
func _obtener_movimientos_aleatorios() -> Array[Movimiento]:
	var movimientos: Array[Movimiento] = []
	var cantidad = randi_range(1, 4)  # Entre 1 y 4 movimientos

	for i in range(cantidad):
		var nombre_interno: String = MOVIMIENTOS_PRUEBA[randi() % MOVIMIENTOS_PRUEBA.size()]

		# Verificar que no esté ya en la lista
		var ya_tiene = false
		for mov_existente in movimientos:
			if mov_existente.get_nombre_interno() == nombre_interno:
				ya_tiene = true
				break

		if not ya_tiene:
			# Movimiento con datos completos de la BD y PP al máximo
			var movimiento: Movimiento = Movimiento.desde_guardado(nombre_interno)
			if movimiento != null:
				movimientos.append(movimiento)

	# Si no se agregó ningún movimiento (casos extremos), agregar uno por defecto
	if movimientos.is_empty():
		movimientos.append(Movimiento.crear_por_defecto())

	return movimientos

# ===================================
# CARGA DESDE SISTEMA DE GUARDADO
# ===================================

## Carga datos de cajas desde el sistema de guardado.
func cargar_cajas_desde_datos(cajas_datos: Array) -> void:
	print("📥 [CAJAS PC] Cargando datos desde sistema de guardado...")
	
	# Limpiar datos existentes
	_limpiar_datos_cajas()
	pokemon_sin_hueco.clear()
	## Pokémon de cajas que no existen en Ruby (>= MAX_CAJAS): se recolocan.
	var fuera_de_rango: Array[BasePokemon] = []

	# Procesar cada caja de los datos guardados
	for caja_index in range(cajas_datos.size()):
		if caja_index >= MAX_CAJAS:
			for pokemon_extra in cajas_datos[caja_index]:
				if pokemon_extra is BasePokemon:
					fuera_de_rango.append(pokemon_extra)
			continue

		var caja_datos = cajas_datos[caja_index]
		var clave_caja = "caja_%d" % caja_index
		
		# Inicializar array de la caja
		var array_caja = []
		array_caja.resize(POKEMON_POR_CAJA)
		
		# Cargar Pokémon de la caja
		for slot_index in range(caja_datos.size()):
			if slot_index >= POKEMON_POR_CAJA:
				print("⚠️ [CAJAS PC] Se alcanzó el límite máximo de slots por caja (%d), ignorando slot %d en caja %d" % [POKEMON_POR_CAJA, slot_index, caja_index])
				break
			
			var pokemon_data = caja_datos[slot_index]
			if pokemon_data != null:
				# El Pokémon ya debería ser una instancia de BasePokemon
				# gracias al procesamiento en EstructuraGuardado.from_dict()
				array_caja[slot_index] = pokemon_data
			else:
				array_caja[slot_index] = null
		
		# Guardar caja en los datos
		datos_cajas.pokemones[clave_caja] = array_caja
		print("📥 [CAJAS PC] Caja %d cargada con %d Pokémon" % [caja_index, _contar_pokemon_en_caja(array_caja)])

	_recolocar_pokemon_fuera_de_rango(fuera_de_rango)
	print("✅ [CAJAS PC] Datos cargados: %d cajas con %d Pokémon total" % [cajas_datos.size(), contar_pokemon_total()])

## Las partidas guardadas antes de limitar el PC a 14 cajas podían tener 16:
## sus Pokémon pasan al primer hueco libre de las 14 cajas reales. Si no queda
## ninguno se guardan en `pokemon_sin_hueco` (nunca se descartan).
func _recolocar_pokemon_fuera_de_rango(pokemones: Array[BasePokemon]) -> void:
	for pokemon in pokemones:
		var hueco: Vector2i = encontrar_primer_slot_vacio()
		if hueco.x < 0:
			pokemon_sin_hueco.append(pokemon)
			push_warning("[CAJAS PC] %s no cabe en las %d cajas; se conserva aparte" % [pokemon.nombre_interno, MAX_CAJAS])
		else:
			colocar_pokemon(hueco.x, hueco.y, pokemon)
			print("📦 [CAJAS PC] %s recolocado de una caja inexistente a caja %d, slot %d" % [pokemon.nombre_interno, hueco.x, hueco.y])

## Cuenta los Pokémon de una caja (0 si el índice no es válido).
func contar_pokemon_en_caja(caja: int) -> int:
	if not _validar_caja(caja):
		return 0
	return _contar_pokemon_en_caja(datos_cajas.pokemones["caja_%d" % caja])

## Primer slot libre de una caja, o -1 si está llena (pokeruby
## GetFirstFreeBoxSpot).
func primer_slot_libre(caja: int) -> int:
	var hueco: Vector2i = encontrar_primer_slot_vacio(caja)
	return hueco.y if hueco.x >= 0 else -1

## Limpia todos los datos de las cajas.
func _limpiar_datos_cajas() -> void:
	print("🧹 [CAJAS PC] Limpiando datos existentes...")
	
	# Limpiar pokemones de todas las cajas
	datos_cajas.pokemones.clear()
	
	# Reinicializar estructura básica
	for i in range(MAX_CAJAS):
		var clave_caja = "caja_%d" % i
		var array_caja = []
		array_caja.resize(POKEMON_POR_CAJA)
		for j in range(POKEMON_POR_CAJA):
			array_caja[j] = null
		datos_cajas.pokemones[clave_caja] = array_caja

## Cuenta cuántos Pokémon hay en una caja específica.
func _contar_pokemon_en_caja(caja: Array) -> int:
	var count = 0
	for pokemon in caja:
		if pokemon != null:
			count += 1
	return count
