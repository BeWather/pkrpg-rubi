extends Node2D

@onready var pp_animac = $AnimatedSprite2D

func _ready():
	add_to_group("PastoAlto1")

func _process(_delta):
	if !pp_animac.is_playing():
		validar_posicion_characterbody2d()

func validar_posicion_characterbody2d():
	var mapa := _obtener_mapa_actual()
	if mapa == null:
		return
	var celda_actual = mapa.global_to_map_cell(global_position)
	var character_en_celda = false

	# Jugador (único nodo en el grupo "Personaje")
	for child in get_tree().get_nodes_in_group("Personaje"):
		if child.visible:
			var celda_character = mapa.global_to_map_cell(child.global_position)
			if celda_actual == celda_character:
				character_en_celda = true
				break

	# NPCs del mapa actual: son hermanos dentro del nodo "NPCs" del MapaConfiguracion
	if not character_en_celda and get_parent() != null:
		for child in get_parent().get_children():
			if child == self or not (child is Node2D) or not child.visible:
				continue
			# Otra animación de pasto en la misma celda no la ocupa: si no, dos
			# animaciones superpuestas se mantienen vivas entre sí para siempre.
			if child.is_in_group(&"PastoAlto1"):
				continue
			# Un objeto oculto (bg_hidden_item_event) no ocupa la celda: sin esto el
			# pasto pisado junto a él no se liberaría nunca.
			if child.has_method("bloquea_paso") and not child.bloquea_paso():
				continue
			var celda_character = mapa.global_to_map_cell(child.global_position)
			if celda_actual == celda_character:
				character_en_celda = true
				break

	if not character_en_celda:
		queue_free()

func _obtener_mapa_actual() -> MapaConfiguracion:
	var nodo: Node = get_parent()
	while nodo != null:
		if nodo is MapaConfiguracion:
			return nodo
		nodo = nodo.get_parent()
	return null
