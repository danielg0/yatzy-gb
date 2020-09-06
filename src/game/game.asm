INCLUDE "hardware.inc"

; Game macros

; AT(X, Y)
; load into hl the VRAM address for a given position on _SCRN0
AT: MACRO
	ld hl, _SCRN0 + (SCRN_VY_B * \2) + \1
ENDM

; DW_AT(X, Y)
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

	; setup cursor position
	; ensure a cursor pos change while avoiding overwriting text, etc.
	ld hl, W_CURSOR_POS
	ld [hl], CURSOR_MAX
	ld a, CURSOR_MIN
	call updateCursor

	call RollDice
	call drawScores

	ret

; draw updated score variables (defined in dice.asm) to the screen
; must be called during vblank period/when display is off
drawScores::
	; offset is equal to $30 as this is the point numbers start in font
	ld b, $30

	; singles
	AT 6, 4
	ld a, [W_SINGLE]
	call BCPcpy
	AT 6, 5
	ld a, [W_SINGLE + 1]
	call BCPcpy
	AT 6, 6
	ld a, [W_SINGLE + 2]
	call BCPcpy
	AT 6, 7
	ld a, [W_SINGLE + 3]
	call BCPcpy
	AT 6, 8
	ld a, [W_SINGLE + 4]
	call BCPcpy
	AT 6, 9
	ld a, [W_SINGLE + 5]
	call BCPcpy

	; left-hand side
	AT 17, 4
	ld a, [W_2_OFAKIND]
	call BCPcpy
	AT 17, 5
	ld a, [W_TWOPAIRS]
	call BCPcpy
	AT 17, 6
	ld a, [W_3_OFAKIND]
	call BCPcpy
	AT 17, 7
	ld a, [W_4_OFAKIND]
	call BCPcpy
	AT 17, 8
	ld a, [W_STRAIGHT_LOW]
	call BCPcpy
	AT 17, 9
	ld a, [W_STRAIGHT_HI]
	call BCPcpy
	AT 17, 10
	ld a, [W_FULLHOUSE]
	call BCPcpy
	AT 17, 11
	ld a, [W_CHANCE]
	call BCPcpy
	AT 17, 12
	ld a, [W_YATZY]
	call BCPcpy

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

; Load in the text that doesn't change during the game as well as 00 scores
; console must be in VBlank/have screen turned off
loadGameText::
	ld de, LABEL_TEXT

	AT 2, 1
	call Strcpy

	inc de				; get past final null char
	AT 2, 2
	call Strcpy

	inc de
	AT 2, 4
	call Strcpy
	inc de
	AT 2, 5
	call Strcpy
	inc de
	AT 2, 6
	call Strcpy
	inc de
	AT 2, 7
	call Strcpy
	inc de
	AT 2, 8
	call Strcpy
	inc de
	AT 2, 9
	call Strcpy
	inc de
	AT 2, 10
	call Strcpy

	inc de
	AT 10, 4
	call Strcpy
	inc de
	AT 10, 5
	call Strcpy
	inc de
	AT 10, 6
	call Strcpy
	inc de
	AT 10, 7
	call Strcpy
	inc de
	AT 10, 8
	call Strcpy
	inc de
	AT 10, 9
	call Strcpy
	inc de
	AT 10, 10
	call Strcpy
	inc de
	AT 10, 11
	call Strcpy
	inc de
	AT 10, 12
	call Strcpy

	inc de
	AT 2, 14
	call Strcpy
	inc de
	AT 2, 15
	call Strcpy
	inc de
	AT 2, 16
	call Strcpy

	ret

SECTION "Game Data", ROM0

LABEL_TEXT:
	DB "ROLL", 0			; AT(2, 1)
	DB "HELD", 0			; AT(2, 2)
	DB "1'S:", 0			; AT(2, 4)
	DB "2'S:", 0			; AT(2, 5)
	DB "3'S:", 0			; AT(2, 6)
	DB "4'S:", 0			; AT(2, 7)
	DB "5'S:", 0			; AT(2, 8)
	DB "6'S:", 0			; AT(2, 9)
	DB "SUM:", 0			; AT(2, 10)

	DB "1 PAIR:", 0			; AT(10, 4)
	DB "2 PAIR:", 0			; AT(10, 5)
	DB "3 KIND:", 0			; AT(10, 6)
	DB "4 KIND:", 0			; AT(10, 7)
	DB "SMALL :", 0			; AT(10, 8)
	DB "LARGE :", 0			; AT(10, 9)
	DB "FULL H:", 0			; AT(10, 10)
	DB "CHANCE:", 0			; AT(10, 11)
	DB "YATZY :", 0			; AT(10, 12)

	DB "BONUS   :00", 0		; AT(2, 14)
	DB "SCORE   :0000000", 0	; AT(2, 15)
	DB "HI-SCORE:0000000", 0	; AT(2, 16)


; Cursor location lookup table
; byte pairs - a lookup table giving screen positions for corresponding
; W_CURSOR_POS values
CURSOR_TABLE:
	DW $000				; blank to allow for wrapping around
	DW_AT 1, 1			; ONES column
	DW_AT 1, 2			; TWOS column
	DW_AT 1, 3			; THREES column

INCLUDE "font.inc"

