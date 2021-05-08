INCLUDE "hardware.inc"
INCLUDE "macros.inc"

SECTION "Over", ROM0

; draw game over message
; draw's over the game roll and held columns, whilst preserving the scored
; categories, their values as well as the score and highscore columns
DrawGameOver::
	; copying of string to screen is inlined to save cycles

	AT _SCRN0, 1, 1
DEF I = 0
REPT 18
; strings in rgbds are one-indexed
DEF I = I + 1
	; take a single character from LINE1
	ld a, STRSUB("GAME  A - NEW GAME", I, 1)
	; draw to screen
	ldi [hl], a
ENDR

	AT _SCRN0, 1, 2
DEF I = 0
REPT 14
DEF I = I + 1
	ld a, STRSUB("OVER  B - MENU", I, 1)
	ldi [hl], a
ENDR

	ret

; cleanup game over message
CleanupGameOver::
	xor a				; ld a, $00

	AT _SCRN0, 1, 1
REPT 18
	ld [hl], a
	inc hl
ENDR

	AT _SCRN0, 1, 2
REPT 18
	ld [hl], a
	inc hl
ENDR

	ret

