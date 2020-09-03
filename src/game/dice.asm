INCLUDE "hardware.inc"

SECTION "Dice Variables", WRAM0

DICE_SUM:: DS 1				; 1 byte with the sum of all the dice
DICE_TYPE:: DS 1			; bit-array of dice types present
					; 0 = not present, %--654321
DICE_TYPE_SUM:: DS 6			; bytes holding the sum of all dice of
					; each type (6, 5, 4, 3, 2, 1)
DICE_TYPE_COUNT:: DS 6			; 6 bytes holding the number of dice of
					; each type (6, 5, 4, 3, 2, 1)

SECTION "Dice", ROM0

; Initialise zero values for all the dice variables
; @return a 0
; @return hl DICE_TYPE_COUNT + 6
InitDice::
	; 1 byte DICE_SUM variable
	ld hl, DICE_SUM
	ld [hl], 0

	; 1 byte DICE_TYPE variable
	ld hl, DICE_TYPE
	ld [hl], 0

	; 6 byte DICE_TYPE_SUM variable
	ld a, 6
	ld hl, DICE_TYPE_SUM
.loop_DICE_TYPE_SUM
	ld [hl], 0
	inc hl
	dec a
	jr nz, .loop_DICE_TYPE_SUM

	; 6 byte DICE_TYPE_COUNT variable
	ld a, 6
	ld hl, DICE_TYPE_COUNT
.loop_DICE_TYPE_COUNT
	ld [hl], 0
	inc hl
	dec a
	jr nz, .loop_DICE_TYPE_COUNT

	ret

; Get new values for all dice using rng functions, updating all DICE_ values
RollDice::
	; DEBUG - set constant dice roll
	ld c, 4
	call UpdateDice
	ld c, 2
	call UpdateDice
	ld c, 6
	call UpdateDice
	ld c, 4
	call UpdateDice
	ld c, 1
	call UpdateDice

	ret

; Update variable values for a new dice roll
; @param c - new dice roll
; @return c - new dice roll
; @return de - 16bit value of c, decremented
; @return hl - DICE_TYPE_SUM + c
; @trashes a
; @trashes b
UpdateDice:
	; add to dice sum
	ld a, c
	ld hl, DICE_SUM
	add [hl]
	ld [hl], a

	; create bit mask for this dice roll
	ld a, c
	ld b, %00000001
.shiftStart
	dec a
	jr z, .shiftEnd
	sla b
	jr .shiftStart
.shiftEnd
	; or bitmask with current dice type to get new dice type
	ld hl, DICE_TYPE
	ld a, [hl]
	or b
	ld [hl], a

	; have de hold a 16bit value of the dice
	; important: decrement as byte array starts at 0
	ld e, c
	ld d, 0
	dec de

	; update dice type sum and count
	ld hl, DICE_TYPE_SUM
	add hl, de
	ld a, [hl]
	add c
	ld [hl], a

	ld de, DICE_TYPE_COUNT - DICE_TYPE_SUM
	add hl, de
	inc [hl]

	ret

