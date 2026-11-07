extends RefCounted
class_name ContextoBaseSecreta

## Contrato de navegación. Retorno usa celdas LOCALES Godot, nunca x/y_original.
## La vista previa es volátil y no reserva base, decoración ni retorno persistente.
static func crear(entrada_id: int, retorno: Dictionary, vista_previa: bool,
		sistema: SistemaBasesSecretas) -> Dictionary:
	if sistema == null or not sistema.es_compatible():
		return {}
	var entrada: Dictionary = DatosBasesSecretas.entrada(entrada_id)
	var normalizado: Dictionary = SistemaBasesSecretas.normalizar_retorno(retorno)
	if entrada.is_empty() or normalizado.is_empty() or normalizado["mapa_actual"] != entrada["mapa"]:
		return {}
	if (vista_previa and sistema.tiene_base()) or (not vista_previa and sistema.id_base() != entrada_id):
		return {}
	return {"entrada_id": entrada_id, "vista_previa": vista_previa, "retorno": normalizado}


static func validar(datos: Dictionary, interior_id: int, sistema: SistemaBasesSecretas) -> Dictionary:
	var entrada_id: Variant = datos.get("entrada_id")
	var previa: Variant = datos.get("vista_previa")
	var retorno: Variant = datos.get("retorno")
	if not entrada_id is int or not previa is bool or not retorno is Dictionary:
		return {}
	var entrada: Dictionary = DatosBasesSecretas.entrada(entrada_id)
	if entrada.is_empty() or int(entrada["interior_id"]) != interior_id:
		return {}
	return crear(entrada_id, retorno, previa, sistema)


## CONTINUAR/F6 no es un warp ni una vista previa. No muta visitas ni retorno.
static func desde_guardado(mapa_key: String, sistema: SistemaBasesSecretas) -> Dictionary:
	if sistema == null or not sistema.es_compatible() or not sistema.tiene_base():
		return {}
	var entrada: Dictionary = DatosBasesSecretas.entrada(sistema.id_base())
	var interior: Dictionary = DatosBasesSecretas.interior(int(entrada["interior_id"]))
	if mapa_key.to_lower() != str(interior["nombre_interno"]).to_lower():
		return {}
	return crear(sistema.id_base(), sistema.obtener_retorno(), false, sistema)
