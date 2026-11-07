## monedero_fichas.gd
## Contador de FICHAS del CASINO (pokeruby src/coins.c: GetCoins / AddCoins /
## RemoveCoins / PlayerHasCoins / AreCoinsMaxed) y su texto de uso.
##
## Las fichas se guardan en un contador persistente de SistemaGuardado
## (gSaveBlock1.coins). Solo se puede tener hasta MAXIMO. El MONEDERO es el objeto
## clave que habilita jugar, comprar y canjear (uso_campo "MONEDERO": muestra las
## fichas, ItemUseOutOfBattle_CoinCase).
class_name MonederoFichas
extends RefCounted

## Contador persistente (gSaveBlock1.coins).
const CONTADOR: String = "monedero_fichas"
const MAXIMO: int = 9999
const OBJETO: String = "MONEDERO"
const BOLSILLO_CLAVE: int = 4
const TEXTO_USO: String = "CIUDAD_MALVALONA_MONEDERO_FICHAS"


## ¿Tiene el MONEDERO? (checkitem ITEM_COIN_CASE, 1)
static func tiene_monedero() -> bool:
	return SistemaGuardado.tiene_objeto(OBJETO, 1, BOLSILLO_CLAVE)


static func fichas() -> int:
	return clampi(SistemaGuardado.get_contador(CONTADOR), 0, MAXIMO)


## ¿Caben `cantidad` fichas más sin pasar de MAXIMO? (CoinCaseIsFull compara con
## el tope menos la compra).
static func caben(cantidad: int) -> bool:
	return fichas() + cantidad <= MAXIMO


## AddCoins: suma con tope. Devuelve las fichas realmente añadidas.
static func dar(cantidad: int) -> int:
	var antes := fichas()
	var despues := mini(antes + maxi(cantidad, 0), MAXIMO)
	SistemaGuardado.set_contador(CONTADOR, despues)
	return despues - antes


## RemoveCoins: false (sin tocar nada) si no hay suficientes.
static func quitar(cantidad: int) -> bool:
	if cantidad < 0 or fichas() < cantidad:
		return false
	SistemaGuardado.set_contador(CONTADOR, fichas() - cantidad)
	return true


static func establecer(cantidad: int) -> void:
	SistemaGuardado.set_contador(CONTADOR, clampi(cantidad, 0, MAXIMO))


## Texto de ItemUseOutOfBattle_CoinCase («FICHAS: N»).
static func texto_uso() -> String:
	return TranslationServer.translate(TEXTO_USO).replace("{fichas}", str(fichas()))
