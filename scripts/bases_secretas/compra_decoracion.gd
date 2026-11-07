class_name CompraDecoracion
extends RefCounted

## Compra de UNA decoración (`Task_DoItemPurchase` de pokeruby `src/shop.c`, rama de tienda de
## decoración): en Rubí no hay cantidad, se compra de una en una y la decoración va al PC de casa
## (`AddDecoration`), no a la mochila. Sin dinero o sin sitio en su categoría no se cobra nada: la
## decoración se añade al inventario primero y solo entonces se descuenta el dinero, sin ningún
## `await` entre las dos cosas (misma atomicidad que `TallerVidrio.canjear`).
##
## El inventario es `SistemaBasesSecretas` (`SistemaGuardado.get_bases_secretas()`): las copias
## llevan un `copia_id` estable y cada categoría tiene su capacidad (10 mesas, 10 sillas...).

const COMPRADA: StringName = &"comprada"
const SIN_DINERO: StringName = &"sin_dinero"
const SIN_SITIO: StringName = &"sin_sitio"
const NO_DISPONIBLE: StringName = &"no_disponible"
const VERSION_INCOMPATIBLE: StringName = &"version_incompatible"


## ¿Alcanza el dinero para esa decoración? (`IsEnoughMoney`).
static func puede_pagar(decoracion_id: int, almacen: Object = null) -> bool:
	var datos: Dictionary = DatosBasesSecretas.decoracion(decoracion_id)
	return not datos.is_empty() and _almacen(almacen).get_dinero_jugador() >= int(datos["precio"])


## ¿Hay sitio para otra copia en la categoría de esa decoración? (`CheckDecorationInventoryHasSpace`).
static func hay_sitio(decoracion_id: int, almacen: Object = null) -> bool:
	if DatosBasesSecretas.decoracion(decoracion_id).is_empty():
		return false
	return _inventario(almacen).puede_agregar_decoracion(decoracion_id)


## Resultado: COMPRADA, SIN_DINERO, SIN_SITIO, NO_DISPONIBLE (id fuera del catálogo) o
## VERSION_INCOMPATIBLE (guardado de una versión que este código no entiende: no se toca).
## `almacen` (por defecto `SistemaGuardado`) solo hace falta en las pruebas.
static func comprar(decoracion_id: int, almacen: Object = null) -> StringName:
	var datos: Dictionary = DatosBasesSecretas.decoracion(decoracion_id)
	if datos.is_empty():
		return NO_DISPONIBLE
	var inventario: SistemaBasesSecretas = _inventario(almacen)
	if not inventario.es_compatible():
		return VERSION_INCOMPATIBLE
	var precio: int = int(datos["precio"])
	if _almacen(almacen).get_dinero_jugador() < precio:
		return SIN_DINERO
	var copia_id: int = inventario.agregar_decoracion(decoracion_id)
	if copia_id < 0:
		return SIN_SITIO
	if not _almacen(almacen).quitar_dinero_jugador(precio):
		# No debería ocurrir (ya se comprobó): deshacer para no regalar la decoración.
		inventario.tirar_decoracion(copia_id)
		return SIN_DINERO
	return COMPRADA


static func _almacen(almacen: Object) -> Object:
	return almacen if almacen != null else SistemaGuardado


static func _inventario(almacen: Object) -> SistemaBasesSecretas:
	return _almacen(almacen).get_bases_secretas() as SistemaBasesSecretas
