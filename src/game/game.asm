INCLUDE "hardware.inc"

; Game macros

; AT(X, Y)
; allocates a word holding the VRAM location for a given position on _SCRN0
DW_AT: MACRO
	DW _SCRN0 + (SCRN_VY_B * \2) + \1
ENDM

; Game Constants
CURSOR_MIN EQU 01			; max value W_CURSOR_POS can hold
CURSOR_MAX EQU 03			; min ""

SECTION "Game Variables", WRAM0

W_CURSOR_POS: DS 1			; byte holding position of cursor

SECTION "Game", ROM0

; Load game tiles from ROM into VRAM
; console must be in VBlank/have screen turned off
loadGameTiles::
	ld de, font_tile_data
	ld bc, font_tile_data_size
	ld hl, _VRAM
	call Memcpy
	ret

; Perform all pre-game, post-load setup (ie. setting values in bg map)
setupGame::
	; zero out dice variables
	call InitDice

	; setup some test text - replace this
	ld de, r_str_test
	ld hl, _SCRN0 + 32 + 2
	call Strcpy
	ld bc, 33 - (r_str_test2 - r_str_test)
	add hl, bc
	inc de
	call Strcpy
	ld bc, 33 - (r_str_test3 - r_str_test2)
	add hl, bc
	inc de
	call Strcpy

	; setup cursor position
	; ensure a cursor pos change while avoiding overwriting text, etc.
	ld hl, W_CURSOR_POS
	ld [hl], CURSOR_MAX
	ld a, CURSOR_MIN
	call updateCursor

	call RollDice

	ret

; Update cursor position
; @param a the new position of the cursor
; if cursor position didn't change
; @return a the position of the cursor
; @return hl W_CURSOR_POS
; @return flags Z set C reset
; else
; @return a character code for ">"
; @return bc address in VRAM of the new cursors position
; @return hl W_CURSOR_POS
; @return d new cursor position (ie. a)
; @return flags depends on if a was in range
updateCursor:
	ld hl, W_CURSOR_POS
	cp [hl]				; check if cursor position actually
	ret z				; needs changing

	; for the moment, wraps around above and below CURSOR_MIN
	; TODO - implement some sort of switch statement allow for moving left
	; and right

	cp CURSOR_MIN			; if a >= CURSOR_MIN
	jr nc, .aboveMin
	ld a, CURSOR_MAX
.aboveMin
	cp CURSOR_MAX + 1		; if a <= CURSOR_MAX
	jr c, .belowMax
	ld a, CURSOR_MIN
.belowMax

	ld d, a				; save value of a for later

	ld b, $00			; bc now contains [W_CURSOR_POS] as
	ld c, [hl]			; a word
	ld hl, CURSOR_TABLE
	add hl, bc			; [hl] is now the address in VRAM
	add hl, bc			; of the old cursor. add twice because
					; each address is a word (2 bytes)

	ld a, [hli]			; remember: little endian encoding
	ld c, a
	ld a, [hl]			; bc contains VRAM addres of cursor
	ld b, a

	xor a				; a set to zero to get rid of cursor
	ld [bc], a

	; repeat the above to set the character in its new position
	ld b, $00
	ld c, d
	ld hl, CURSOR_TABLE
	add hl, bc
	add hl, bc

	ld a, [hli]
	ld c, a
	ld a, [hl]
	ld b, a
	ld a, ">"
	ld [bc], a

	; write new cursor position to WRAM
	ld hl, W_CURSOR_POS
	ld [hl], d
	ret

SECTION "Game Data", ROM0

r_str_test:
	DB "ONES: 4", 0
r_str_test2:
	DB "TWOS: 2", 0
r_str_test3:
	DB "THREES: 0", 0

; Cursor location lookup table
; byte pairs - a lookup table giving screen positions for corresponding
; W_CURSOR_POS values
CURSOR_TABLE:
	DW $000				; blank to allow for wrapping around
	DW_AT 1, 1			; ONES column
	DW_AT 1, 2			; TWOS column
	DW_AT 1, 3			; THREES column

INCLUDE "font.inc"

