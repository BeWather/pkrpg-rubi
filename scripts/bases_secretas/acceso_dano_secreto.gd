extends RefCounted
class_name AccesoDanoSecreto

## SetUpFieldMove_SecretPower: sin medalla, norte, entrada cerrada y SIN base.
## El menú está pausado al consultar; no usar puede_actuar_jugador como preflight.
static func entrada_frente(admin: Node = null) -> EntradaBaseSecreta:
	if admin == null:
		var arbol: SceneTree = Engine.get_main_loop() as SceneTree
		admin = arbol.root.get_node_or_null("AdministradorMapa") if arbol != null else null
	var sistema: SistemaBasesSecretas = SistemaGuardado.get_bases_secretas()
	if not is_instance_valid(admin) or not sistema.es_compatible() or sistema.tiene_base() \
		or int(admin.get("coneccion")) != 0:
		return null
	var mapa: MapaConfiguracion = admin.get("mapa_actual") as MapaConfiguracion
	var jugador: Node2D = admin.get("jugador") as Node2D
	if not is_instance_valid(mapa) or not mapa.is_inside_tree() or not is_instance_valid(jugador) or jugador.get("facing_direction") != Vector2.UP \
		or bool(jugador.get("paso_en_curso")):
		return null
	var frente: Vector2i = admin.call("celda_frente_jugador")
	for nodo: Node in mapa.get_tree().get_nodes_in_group("entradas_bases_secretas"):
		if not nodo is EntradaBaseSecreta:
			continue
		var entrada: EntradaBaseSecreta = nodo as EntradaBaseSecreta
		var datos: Dictionary = DatosBasesSecretas.entrada(entrada.entrada_id)
		if entrada._mapa_padre() == mapa and not datos.is_empty() \
			and str(datos["mapa"]) == mapa.scene_file_path.get_file().get_basename() \
			and entrada.capa_datos == Singleton.capa_activa \
			and mapa.global_to_map_cell(entrada.global_position) == frente \
			and not entrada._activa and not entrada._pose_equipo_pendiente and not entrada._abierta and not entrada._temporal \
			and not entrada._originales.is_empty():
			return entrada
	return null


static func puede_usar(pokemon: BasePokemon, admin: Node = null) -> bool:
	return pokemon != null and SistemaGuardado.get_equipo().has(pokemon) \
		and EntradaBaseSecreta.pokemon_con_dano_secreto([pokemon]) == pokemon \
		and entrada_frente(admin) != null
