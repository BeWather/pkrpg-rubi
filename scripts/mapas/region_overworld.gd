class_name RegionOverworld
extends Node2D
## Grupo de mapas del Overworld contiguos entre sí pero separados del resto
## (ZONA SAFARI, mapas submarinos). Sus mapas son hijos directos y se colocan
## unos respecto de otros dentro de la escena de la región; la región se coloca
## en Overworld.tscn como cualquier otro mapa.[br]
## En Overworld.tscn se instancia con "Load As Placeholder": no se carga hasta
## que el jugador entra en uno de sus mapas y se libera al salir
## (AdministradorMapa). Solo es visible la región del mapa actual; mientras el
## jugador está en una región, los mapas sueltos del Overworld se ocultan y los
## bordes solo conectan mapas de la misma región, así que puede solaparse con
## ellos (los submarinos van justo debajo de sus rutas).


## Mapas de la región, en orden de escena.
func mapas() -> Array[MapaConfiguracion]:
	var lista: Array[MapaConfiguracion] = []
	for hijo: Node in get_children():
		if hijo is MapaConfiguracion:
			lista.append(hijo as MapaConfiguracion)
	return lista


## Instancia la región de `placeholder` como hermana suya, con las propiedades
## que tiene en Overworld.tscn (posición). A diferencia de
## InstancePlaceholder.create_instance, funciona con el Overworld aún fuera del
## árbol (al iniciar la partida). null si la escena no es una RegionOverworld.
static func instanciar_desde(placeholder: InstancePlaceholder) -> RegionOverworld:
	var escena := load(placeholder.get_instance_path()) as PackedScene
	var nodo: Node = escena.instantiate() if escena != null else null
	var region := nodo as RegionOverworld
	if region == null:
		if nodo != null:
			nodo.free()
		return null
	var valores: Dictionary = placeholder.get_stored_values()
	for propiedad: Variant in valores:
		region.set(propiedad, valores[propiedad])
	region.name = "%sCargada" % placeholder.name
	var padre := placeholder.get_parent()
	if padre != null:
		padre.add_child(region)
		padre.move_child(region, placeholder.get_index())
	return region


## Claves de mapa (nombre de escena) que contiene la escena de región `ruta`,
## leídas de sus dependencias sin cargarla. Sirve para saber qué placeholder
## cargar antes de entrar en uno de sus mapas.
static func claves_de_escena(ruta: String) -> PackedStringArray:
	var claves := PackedStringArray()
	for dependencia: String in ResourceLoader.get_dependencies(ruta):
		# Formato "uid://…::Tipo::res://ruta" (o solo la ruta en formatos viejos).
		var ruta_dep := dependencia.get_slice("::", dependencia.get_slice_count("::") - 1)
		if ruta_dep.begins_with("uid://"):
			ruta_dep = ResourceUID.uid_to_path(ruta_dep)
		if ruta_dep.get_extension() == "tscn":
			claves.append(ruta_dep.get_file().get_basename())
	return claves
