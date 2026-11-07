extends EfectoMovimientoNativo
## Placaje (Move_TACKLE). Todo es declarativo en placaje.tscn: embestida del
## atacante (gHorizontalLungeSpriteTemplate: 4 frames +4 px, 4 frames de vuelta),
## golpe en el frame 8 (`delay 6` dura 8 frames en la ROM; gBasicHitSplatSpriteTemplate
## a escala 0xB0/0x100 durante 10 frames), sacudida del defensor (AnimTask_ShakeMon
## 3,0,6,1: dos pulsos, medidos en la ROM) y SE_W004.
## Este script no añade comportamiento; existe para poder ampliarlo.
