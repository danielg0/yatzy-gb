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
CURSOR_MAX EQU 17			; min ""

SECTION "Game Variables", WRAM0

W_CURSOR_POS: DS 1			; byte holding position of cursor

SECTION "Game", ROM0

; Load game tiles from ROM into VRAM
; console must be in VBlank/have screen turned off
LoadGameTiles::
	ld de, font_tile_data
	ld bc, font_tile_data_size
	ld hl, _VRAM
	call Memcpy
	ret

; Perform all pre-game, post-load setup (ie. setting values in bg map)
SetupGame::
	; zero out dice variables
	call InitDice

	; setup cursor position
	; ensure a cursor pos change while avoiding overwriting text, etc.
	ld hl, W_CURSOR_POS
	ld [hl], CURSOR_MAX
	ld a, CURSOR_MIN
	call UpdateCursor

	ret

; draw updated score variables (defined in dice.asm) to the screen
; must be called during vblank period/when display is off
DrawScores::
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

; draw dice values to the screen - reading from DICE (defined in dice.asm)
; must be called during vblank period
DrawDice::
	ld de, DICE
	ld a, [de]			; use ascii hidden chars for dice
	AT 8, 1
	ld [hl], a

	inc de
	ld a, [de]
	AT 10, 1
	ld [hl], a

	inc de
	ld a, [de]
	AT 12, 1
	ld [hl], a

	inc de
	ld a, [de]
	AT 14, 1
	ld [hl], a

	inc de
	ld a, [de]
	AT 16, 1
	ld [hl], a

	ret

; Perform an action
; A button just pressed, use cursor pos to figure out what to do next
GameAction::
	; load cursor pos into a
	ld a, [W_CURSOR_POS]

	cp 1				; cursor pos 1 is roll button
	jr nz, .noRoll			; if a == 1, roll dice

	; roll dice, updating scores, then draw to screen
	; remember to wait for a vblank after updating scores as this may take
	; more than one frame
	call RollDice
	call WaitVBlank
	call DrawScores
	call DrawDice
.noRoll

	ret

; Update cursor index based on controller input
; @param a the dpad input byte, 0 used where input changed
; @param a new position of the cursor
MoveCursor::
	; load cursor pos variable into d
	ld hl, W_CURSOR_POS
	ld d, [hl]

	; move cursor up and down if up/down dpad
	bit 3, a			; if down pressed, inc position
	jr nz, .notDown
	inc d
.notDown
	bit 2, a			; if up pressed, dec position
	jr nz, .notUp
	dec d
.notUp
	ld a, d
	ret

; Update cursor position on screen
; assumes cursor position changed
; @param a the new position of the cursor
; @return a character code for ">"
; @return bc address in VRAM of the new cursors position
; @return hl W_CURSOR_POS
; @return d new cursor position (ie. a)
; @return flags depends on if a was in range
UpdateCursor::
	; wraps around above and below CURSOR_MIN and CURSOR_MAX
	cp CURSOR_MIN			; if a >= CURSOR_MIN
	jr nc, .aboveMin
	ld a, CURSOR_MAX
.aboveMin
	cp CURSOR_MAX + 1		; if a <= CURSOR_MAX
	jr c, .belowMax
	ld a, CURSOR_MIN
.belowMax

	ld d, a				; save value of a for later

	ld hl, W_CURSOR_POS
	ld b, $00			; bc now contains [W_CURSOR_POS] as
	ld c, [hl]			; a word
	ld hl, CURSOR_TABLE
	add hl, bc			; [hl] is now the address in VRAM
	add hl, bc			; of the old cursor. add twice because
					; each address is a word (2 bytes)

	ld a, [hli]			; remember: little endian encoding
	ld c, a
	ld a, [hl]			; bc contains VRAM address of cursor
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
LoadGameText::
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
	DW $0000			; blank to allow for wrapping around
	DW_AT 1, 1			; ROLL
	DW_AT 1, 2			; HELD

	; singles
	DW_AT 1, 4			; 1'S
	DW_AT 1, 5			; 2's
	DW_AT 1, 6			; 3's
	DW_AT 1, 7			; 4's
	DW_AT 1, 8			; 5's
	DW_AT 1, 9			; 6's

	; other combinations
	DW_AT 9, 4			; 1 PAIR
	DW_AT 9, 5			; 2 PAIR
	DW_AT 9, 6			; 3 KIND
	DW_AT 9, 7			; 4 KIND
	DW_AT 9, 8			; SMALL
	DW_AT 9, 9			; LARGE
	DW_AT 9, 10			; FULL H
	DW_AT 9, 11			; CHANCE
	DW_AT 9, 12			; YATZY

INCLUDE "font.inc"

