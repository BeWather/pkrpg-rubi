extends RefCounted
## Pure move101 workers, not a scheduler, actor adapter, or source OAM emulator.
## Call palette update -> task callback -> VBlank separately in source phase order.
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

# ghost.c346-399: constructor is k0; source RunTasks k1 occurs after OAM capture.
static func ghost_new() -> Dictionary:
	return {"k":0,"matrix":128,"eva":0,"evb":16,"hold":85,"divider":0,"phase":"ramp","live":true,"affine_write":true}

static func ghost_callback(s: Dictionary) -> void:
	if not s.live:return
	s.k += 1;s.affine_write=false
	if s.phase=="ramp":
		s.divider += 1
		if s.divider==3:
			s.divider=0;s.eva+=1;s.evb-=1
			if s.eva==9:s.phase="hold"
		return
	if s.hold>0:s.hold-=1;return
	s.phase="shrink";s.matrix+=8
	if s.matrix<=255:s.affine_write=true
	else:s.live=false;s.phase="dead";s.eva=0;s.evb=0

# battle_anim_mon_movement.c165-252, fixed args [1,2,0,12,1].
# The constructor already performs its immediate step (counter1 -> 0).
static func shake_new() -> Dictionary:
	return {"j":0,"x2":2,"counter":0,"remaining":12,"live":true}

static func shake_callback(s: Dictionary) -> void:
	if not s.live:return
	s.j+=1
	if s.counter>0:s.counter-=1;return
	s.x2=-int(s.x2);s.counter=1;s.remaining-=1
	if s.remaining==0:s.x2=0;s.live=false

# battle_anim.c2411-2444; palette.c716-791. No shared palette authority here.
static func background_new() -> Dictionary:
	return {"pulse":0,"phase":0,"y":0,"target":16,"active":false,"finishing":false,"swapped":false,"done":false,"bldy":0}

static func background_palette_update(s: Dictionary) -> void:
	if not s.active:return
	var direction: int = 1 if s.target==16 else -1
	s.y+=direction
	if (direction==1 and s.y>s.target) or (direction==-1 and s.y<s.target):
		s.y-=direction;s.finishing=true

static func background_callback(s: Dictionary) -> void:
	if s.done:return
	s.pulse+=1
	if s.phase==0:
		s.y=0;s.target=16;s.active=true;s.phase=1;return
	if s.active:return
	if s.phase==1:s.phase=2
	elif s.phase==2:
		s.swapped=true;s.y=16;s.target=0;s.active=true;s.phase=3
	elif s.phase==3:s.done=true

static func background_vblank(s: Dictionary) -> void:
	if not s.active:return
	s.bldy=s.y
	if s.finishing:
		s.active=false;s.finishing=false;s.y=0

# normal.c465-518; palette.c149-191/401-477/793-815.
# Only canonical mask4, delay0, repeat2, black0->13->0 is supported.
# BeginNormalPaletteFade itself calls one update: initially the BG half.
static func target_palette_new(target_bank: int) -> Dictionary:
	assert(target_bank>=0 and target_bank<4)
	var s: Dictionary = {"mask":1<<(target_bank+16),"obj_half":false,"y":0,"target":13,"amount":0,"active":true,"finishing":false,"poll":0,"remaining":1,"live":true}
	target_palette_update(s)
	return s

static func target_palette_update(s: Dictionary) -> void:
	if not s.active:return
	if s.finishing:
		if s.poll==4:s.active=false;s.finishing=false;s.poll=0
		else:s.poll+=1
		return
	if s.obj_half:s.amount=s.y
	s.obj_half=not bool(s.obj_half)
	if not s.obj_half:
		if s.y==s.target:s.finishing=true
		elif s.y<s.target:s.y=mini(int(s.y)+2,int(s.target))
		else:s.y=maxi(int(s.y)-2,int(s.target))

static func target_palette_callback(s: Dictionary) -> void:
	if not s.live or s.active:return
	if s.remaining==0:s.live=false;return
	s.remaining-=1;s.y=13;s.target=0;s.active=true
	target_palette_update(s) # Reverse-segment BeginNormalPaletteFade BG half.

# blend_palette.c: signed arithmetic shift is floor, NOT truncation toward zero.
static func black_rgb5(channel: int,amount: int) -> int:
	return channel+((-channel*amount)>>4)
