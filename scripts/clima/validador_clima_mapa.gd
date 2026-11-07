@tool
class_name ValidadorClimaMapa
extends RefCounted

## Validación sin depender del árbol activo ni de los grupos del runtime.
static func validar(mapa: Node) -> PackedStringArray:
	var avisos := PackedStringArray()
	var definiciones: Array[DefinicionClima] = []
	var inicial: DefinicionClima = mapa.get("clima_inicial")
	if inicial != null:
		definiciones.append(inicial)
	var pendientes: Array[Node] = [mapa]
	var selectores := 0
	var ids_evento: Dictionary = {}
	while not pendientes.is_empty():
		var nodo: Node = pendientes.pop_back()
		for hijo: Node in nodo.get_children():
			pendientes.append(hijo)
		if nodo is SelectorClimaEntrada:
			selectores += 1
			for zona: ZonaClimaEntrada in nodo.zonas:
				if zona != null and zona.clima != null:
					definiciones.append(zona.clima)
		if nodo is DisparadorClimaPorTiles and nodo.accion_clima == DisparadorClimaPorTiles.AccionClima.CAMBIAR:
			if nodo.clima_objetivo != null:
				definiciones.append(nodo.clima_objetivo)
		if nodo is DisparadorClimaPersistente and nodo.id_evento != &"":
			if ids_evento.has(nodo.id_evento):
				avisos.append("Clima: ID Evento persistente duplicado: %s." % nodo.id_evento)
			ids_evento[nodo.id_evento] = true
	if selectores > 1:
		avisos.append("Clima: hay varios SelectorClimaEntrada; debe haber uno como máximo.")
	var ids: Dictionary = {}
	for definicion: DefinicionClima in definiciones:
		if ids.has(definicion.id):
			if ids[definicion.id] != definicion:
				avisos.append("Clima: presets distintos comparten el ID %s." % definicion.id)
			continue
		ids[definicion.id] = definicion
		avisos.append_array(definicion.obtener_avisos())
		if definicion.escena_mundo != null and mapa.call("obtener_ancla_clima_mundo") == null:
			avisos.append("Clima %s: falta AnclaClimaMundo; activa canal_clima_mundo en CapasAgua." % definicion.id)
	return avisos
