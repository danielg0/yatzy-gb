INCLUDE "hardware.inc"
INCLUDE "macros.inc"

SECTION "Menu", ROM0

; Load game tiles from ROM into VRAM
; must have screen off
LoadMenuTiles::
	ld de, menu_tile_data
	ld bc, menu_tile_data_size
	ld hl, $8800			; load tiles into second/third bank
	call Memcpy
	ret

; Load screen one with tiles
; screen must be off
LoadMenuScreen::
Y SET 0
REPT $12				; REPT menu_tile_height
	AT _SCRN1, 0, Y
	ld de, menu_map_data + Y * (menu_tile_map_size / menu_tile_map_height)
	ld bc, menu_tile_map_size / menu_tile_map_height
	call Memcpy
Y SET Y + 1
ENDR
	ret

SECTION "Menu Data", ROM0

INCLUDE "menu.inc"

