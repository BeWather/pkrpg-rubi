## historia_blasco.gd
## Estado de la historia de BLASCO en CIUDAD PETALIA: el GIMNASIO (NORMAN le
## presta su ZIGZAGOON), el tutorial de captura en la RUTA 102 y la despedida en el
## GIMNASIO (pokeruby PetalburgCity_Gym/scripts.inc y PetalburgCity/scripts.inc).
## Como HistoriaVillaRaiz, no es un nodo ni guarda nada por sí misma: lo consultan
## y avanzan EventoGimnasioPetalia y EventoCiudadPetalia.
##
## Qué se guarda de BLASCO: solo lo que declara PERSISTENTE (SistemaGuardado). Lo
## demás se deduce de ello y no se guarda:
## - FLAG_HIDE_WALLY_PETALBURG: BLASCO está en la ciudad con TUTORIAL_PENDIENTE.
## - FLAG_HIDE_WALLY_PETALBURG_GYM: está en el GIMNASIO con VUELTA_TUTORIAL.
## - El ZIGZAGOON prestado y el RALTS atrapado solo existen dentro del combate
##   tutorial; el equipo del jugador no se toca (en Rubí, SavePlayerParty y
##   LoadPlayerParty lo dejan igual que estaba).
## - VAR_PETALBURG_GYM_STATE de 2 en adelante sale de las MEDALLAS
##   (EventoGimnasioPetalia.estado()).
class_name HistoriaBlasco
extends RefCounted

## VAR_PETALBURG_STATE.
const CONTADOR_CIUDAD: String = "petalia_estado"
## VAR_PETALBURG_GYM_STATE mientras dura la historia de BLASCO (0..2).
const CONTADOR_GIMNASIO: String = "petalia_gimnasio_estado"
## FLAG_HIDE_WALLY_MOM_PETALBURG_1: la madre de BLASCO deja de buscarle en la
## ciudad cuando él sale del GIMNASIO con el jugador.
const BANDERA_MADRE: String = "petalia_blasco_acompanado"

## VAR_PETALBURG_STATE.
enum Ciudad {
	INICIAL = 0,
	## BLASCO espera en la ciudad para ir a la RUTA 102 (WallyTutorial).
	TUTORIAL_PENDIENTE = 2,
	TUTORIAL_HECHO = 3,
}

## VAR_PETALBURG_GYM_STATE hasta la despedida.
enum Gimnasio {
	INICIAL = 0,
	## De vuelta de la RUTA 102: BLASCO se despide (ReturnFromWallyTutorial).
	VUELTA_TUTORIAL = 1,
	## NORMAN ya mandó al jugador a por las MEDALLAS.
	DESPEDIDA = 2,
}

## Clave de SistemaGuardado → [tipo, equivalente en Gen 3].
const PERSISTENTE := {
	CONTADOR_CIUDAD: ["contador", "VAR_PETALBURG_STATE"],
	CONTADOR_GIMNASIO: ["contador", "VAR_PETALBURG_GYM_STATE (0..2)"],
	BANDERA_MADRE: ["bandera", "FLAG_HIDE_WALLY_MOM_PETALBURG_1"],
	HistoriaVillaRaiz.BANDERA_RIVAL_DEJA_LABORATORIO: ["bandera", "FLAG_HIDE_RIVAL_BIRCH_LAB (lo vuelve a activar BeginWallyTutorial)"],
}


static func ciudad() -> int:
	return SistemaGuardado.get_contador(CONTADOR_CIUDAD)


static func gimnasio() -> int:
	return SistemaGuardado.get_contador(CONTADOR_GIMNASIO)


## VAR_PETALBURG_STATE ≥ 2: BLASCO ya salió del GIMNASIO con el jugador.
static func acompanado() -> bool:
	return ciudad() >= Ciudad.TUTORIAL_PENDIENTE


## FLAG_HIDE_WALLY_PETALBURG desactivada.
static func en_la_ciudad() -> bool:
	return ciudad() == Ciudad.TUTORIAL_PENDIENTE


## FLAG_HIDE_WALLY_PETALBURG_GYM desactivada.
static func de_vuelta_en_el_gimnasio() -> bool:
	return gimnasio() == Gimnasio.VUELTA_TUTORIAL


## BeginWallyTutorial: setflag FLAG_HIDE_WALLY_MOM_PETALBURG_1,
## VAR_PETALBURG_GYM_STATE 1, VAR_PETALBURG_STATE 2 y setflag FLAG_HIDE_RIVAL_BIRCH_LAB
## (el rival deja el laboratorio de ABEDUL).
static func salir_con_blasco() -> void:
	SistemaGuardado.set_flag(BANDERA_MADRE, true)
	SistemaGuardado.set_flag(HistoriaVillaRaiz.BANDERA_RIVAL_DEJA_LABORATORIO, true)
	SistemaGuardado.set_contador(CONTADOR_GIMNASIO, Gimnasio.VUELTA_TUTORIAL)
	SistemaGuardado.set_contador(CONTADOR_CIUDAD, Ciudad.TUTORIAL_PENDIENTE)


## WallyTutorial: VAR_PETALBURG_STATE 3, VAR_PETALBURG_GYM_STATE 1.
static func terminar_tutorial() -> void:
	SistemaGuardado.set_contador(CONTADOR_CIUDAD, Ciudad.TUTORIAL_HECHO)
	SistemaGuardado.set_contador(CONTADOR_GIMNASIO, Gimnasio.VUELTA_TUTORIAL)


## ReturnFromWallyTutorial: VAR_PETALBURG_GYM_STATE 2.
static func despedir() -> void:
	SistemaGuardado.set_contador(CONTADOR_GIMNASIO, Gimnasio.DESPEDIDA)


## Valores actuales de todo lo persistente (depuración y tests).
static func instantanea() -> Dictionary:
	var datos := {}
	for clave: String in PERSISTENTE:
		datos[clave] = SistemaGuardado.get_flag(clave) if PERSISTENTE[clave][0] == "bandera" \
			else SistemaGuardado.get_contador(clave)
	return datos


## Restaura una instantánea (o, vacía, la partida antes de conocer a BLASCO).
static func restablecer(datos: Dictionary = {}) -> void:
	for clave: String in PERSISTENTE:
		if PERSISTENTE[clave][0] == "bandera":
			SistemaGuardado.set_flag(clave, bool(datos.get(clave, false)))
		else:
			SistemaGuardado.set_contador(clave, int(datos.get(clave, 0)))
