class_name AlmacenObjetosPC
extends RefCounted

## Port de player_pc.c / item.c de pret/pokeruby, sobre los datos vivos.
const HUECOS: int = 50
const MAX_POR_HUECO: int = 999
enum Resultado { EXITO, INVALIDO, IMPORTANTE, PC_LLENO }


static func objetos() -> Array:
	return SistemaGuardado.datos_vivos.objetos_pc


static func importancia(nombre: String) -> int:
	var bolsillo: int = ObjetosLlevados.bolsillo_de(nombre)
	if bolsillo == 4:
		return 2
	return 1 if ObjetosLlevados.es_mo({"nombre_interno": nombre}) else 0


static func depositar(nombre: String, cantidad: int) -> Resultado:
	nombre = nombre.strip_edges().to_upper()
	var bolsillo: int = ObjetosLlevados.bolsillo_de(nombre)
	SistemaGuardado.inicializar_mochila_estructura()
	if cantidad <= 0 or bolsillo < 0 or not SistemaGuardado.tiene_objeto(nombre, cantidad, bolsillo):
		return Resultado.INVALIDO
	# Ruby permite almacenar MO (importance 1), pero no objetos clave (2).
	if importancia(nombre) == 2:
		return Resultado.IMPORTANTE
	var nuevos: Array = objetos().duplicate(true)
	var restante: int = cantidad
	for item in nuevos:
		if item.nombre_interno == nombre:
			var agregar: int = mini(restante, maxi(0, MAX_POR_HUECO - int(item.cantidad)))
			item.cantidad = int(item.cantidad) + agregar
			restante -= agregar
	while restante > 0 and nuevos.size() < HUECOS:
		var agregar: int = mini(restante, MAX_POR_HUECO)
		nuevos.append({"nombre_interno": nombre, "cantidad": agregar})
		restante -= agregar
	if restante > 0:
		return Resultado.PC_LLENO
	if not SistemaGuardado.quitar_objeto_jugador(nombre, cantidad, bolsillo):
		return Resultado.INVALIDO
	SistemaGuardado.datos_vivos.objetos_pc = nuevos
	return Resultado.EXITO


static func sacar(indice: int, cantidad: int) -> Resultado:
	if not _valido(indice, cantidad):
		return Resultado.INVALIDO
	var nombre: String = objetos()[indice].nombre_interno
	# A diferencia de Ruby no se comprueba si la mochila está llena.
	if ObjetosLlevados.bolsillo_de(nombre) < 0:
		return Resultado.INVALIDO
	SistemaGuardado.inicializar_mochila_estructura()
	if not SistemaGuardado.dar_objeto_jugador(nombre, cantidad).exito:
		return Resultado.INVALIDO
	_quitar(indice, cantidad)
	return Resultado.EXITO


static func tirar(indice: int, cantidad: int) -> Resultado:
	if not _valido(indice, cantidad):
		return Resultado.INVALIDO
	if importancia(objetos()[indice].nombre_interno) != 0:
		return Resultado.IMPORTANTE
	_quitar(indice, cantidad)
	return Resultado.EXITO


static func intercambiar(a: int, b: int) -> bool:
	if a < 0 or b < 0 or a >= objetos().size() or b >= objetos().size():
		return false
	var temporal: Dictionary = objetos()[a]
	objetos()[a] = objetos()[b]
	objetos()[b] = temporal
	return true


static func _valido(indice: int, cantidad: int) -> bool:
	return indice >= 0 and indice < objetos().size() and cantidad > 0 and cantidad <= int(objetos()[indice].cantidad)


static func _quitar(indice: int, cantidad: int) -> void:
	objetos()[indice].cantidad = int(objetos()[indice].cantidad) - cantidad
	if int(objetos()[indice].cantidad) == 0:
		objetos().remove_at(indice)
