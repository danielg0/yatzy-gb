INCLUDE "hardware.inc"
INCLUDE "macros.inc"

SECTION "Over", ROM0

; draw game over message
; draw's over the game roll and held columns, whilst preserving the scored
; categories, their values as well as the score and highscore columns
DrawGameOver::
	AT _SCRN0, 1, 1
	ld de, LINE1
	call Strcpy

	AT _SCRN0, 1, 2
	inc de				; ld de, LINE2
	call Strcpy

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

SECTION "Over Data", ROM0

; Game over message
; displayed at 1, 1
LINE1:
	DB "GAME  A - NEW GAME", 0
LINE2:
	DB "OVER  B - MENU", 0

