@tool
extends RefCounted
class_name IndiceEncuentrosPokedex
## Dónde aparece salvaje cada especie, agrupando las tablas de encuentros por especie.
## Solo cuenta los slots con probabilidad (ModeloEncuentros.resumen descarta los "Sin uso").

const TIPO_ESPECIAL := "especial"
const ICONOS_TIPO: Dictionary = {"hierba": "🌿", "agua": "🌊", "pesca": "🎣", "roca": "🪨", TIPO_ESPECIAL: "⭐"}
const TITULOS_TIPO: Dictionary = {"hierba": "Hierba", "agua": "Agua", "pesca": "Pesca", "roca": "Roca"}
## No salen de las tablas; ver SECCIONES_EXTRA y ERRANTE en UI/pokedex/areas_pokedex.gd.
const ESPECIALES: Dictionary = {
	"FEEBAS": {"lugar": "RUTA 119", "metodo": "Pesca en casillas especiales"},
	"LATIOS": {"lugar": "Errante por HOENN", "metodo": "Pokémon errante"},
}


## Carga la tabla que usa el juego: la original y, con `alternativa`, la alternativa
## superpuesta mapa a mapa (como DatabaseManager). Vacío si algún archivo falla.
static func cargar_modelos(alternativa: bool) -> Array[ModeloEncuentros]:
	var rutas: Array[String] = [ModeloEncuentros.RUTA_DEFECTO]
	if alternativa:
		rutas.append(ModeloEncuentros.RUTA_ALTERNATIVO)
	var modelos: Array[ModeloEncuentros] = []
	for ruta: String in rutas:
		var modelo := ModeloEncuentros.new()
		if modelo.cargar(ruta) != OK:
			push_error("[VISOR POKEDEX] %s" % modelo.ultimo_error)
			return []
		modelos.append(modelo)
	return modelos


## {nombre_interno: Array de {clave, lugar, tipo, grupo, porcentaje, nivel_min, nivel_max}}.
## Si una clave está en varios modelos gana el último. `nombre_lugar`: (clave) -> String.
static func indexar(modelos: Array[ModeloEncuentros], nombre_lugar: Callable) -> Dictionary:
	var modelo_de_clave: Dictionary = {}
	for modelo: ModeloEncuentros in modelos:
		for clave: String in modelo.claves():
			modelo_de_clave[clave] = modelo
	var claves: Array = modelo_de_clave.keys()
	claves.sort()
	var indice: Dictionary = {}
	for clave: String in claves:
		var modelo: ModeloEncuentros = modelo_de_clave[clave]
		var lugar: String = nombre_lugar.call(clave)
		for tipo: String in modelo.tipos_de(clave):
			for fila: Dictionary in ModeloEncuentros.resumen(tipo, modelo.slots(clave, tipo)):
				var entrada: Dictionary = fila.duplicate()
				entrada["clave"] = clave
				entrada["lugar"] = lugar
				entrada["tipo"] = tipo
				_agregar(indice, str(fila["nombre_interno"]), entrada)
	for especie: String in ESPECIALES:
		var datos: Dictionary = ESPECIALES[especie]
		_agregar(indice, especie, {"clave": "", "lugar": datos["lugar"], "tipo": TIPO_ESPECIAL,
				"grupo": datos["metodo"], "porcentaje": -1.0, "nivel_min": 0, "nivel_max": 0})
	return indice


static func _agregar(indice: Dictionary, especie: String, entrada: Dictionary) -> void:
	if not indice.has(especie):
		indice[especie] = []
	indice[especie].append(entrada)


## Lugares distintos, en orden de aparición.
static func lugares(entradas: Array) -> PackedStringArray:
	var resultado: PackedStringArray = []
	for entrada: Dictionary in entradas:
		if not resultado.has(str(entrada["lugar"])):
			resultado.append(str(entrada["lugar"]))
	return resultado


## Iconos de los métodos distintos, en un orden fijo: "🌿🎣".
static func iconos_metodos(entradas: Array) -> String:
	var resultado: String = ""
	for tipo: String in ICONOS_TIPO:
		for entrada: Dictionary in entradas:
			if entrada["tipo"] == tipo:
				resultado += str(ICONOS_TIPO[tipo])
				break
	return resultado


## "🎣 Caña vieja", "🌿 Hierba".
static func texto_metodo(entrada: Dictionary) -> String:
	var grupo: String = str(entrada.get("grupo", ""))
	if grupo.is_empty():
		grupo = str(TITULOS_TIPO.get(entrada["tipo"], entrada["tipo"]))
	return "%s %s" % [ICONOS_TIPO.get(entrada["tipo"], ""), grupo]
