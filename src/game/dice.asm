INCLUDE "hardware.inc"

SECTION "Dice Variables", WRAM0

DICE_SUM: DS 1				; 1 byte with the sum of all the dice
DICE_TYPE: DS 1				; bit-array of dice types present
					; 0 = not present, %--654321
DICE_TYPE_SUM: DS 6			; bytes holding the sum of all dice of
					; each type (1, 2, 3, 4, 5, 6)
DICE_TYPE_COUNT: DS 6			; 6 bytes holding the number of dice of
					; each type (1, 2, 3, 4, 5, 6)

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

; Calculate the score for a straight
; @param b required DICE_TYPE bit pattern
; @return a score
Straight::
	; able to make a straight comparision as only 5 dice
	ld a, [DICE_TYPE]
	cp b
	jr nz, .fail
	ld a, [DICE_SUM]		; for straights, score is sum of dice
	ret
.fail
	ld a, 0
	ret

; Calculate score for a single number
; @param a the dice number to calculate the score for
; @return a the score
; @return b 0
; @return c dice number
; @return hl DICE_TYPE_SUM + bc
Single::
	ld hl, DICE_TYPE_SUM
	ld b, $00
	ld c, a
	dec bc				; make sure to decrement bc as
					; DICE_TYPE_SUM is zero-indexed
	add hl, bc
	ld a, [hl]
	ret

; Calculate yatzy score
; @return a score
Yatzy::
	; logical right shift til a 1 is found
	ld a, [DICE_TYPE]
.shiftStart
	bit 0, a
	jr nz, .shiftEnd
	srl a
	jr .shiftStart
.shiftEnd
	; perform a final right shift then compare a with 0
	; if it matches, all 5 dice are the same number
	srl a
	jr nz, .noYatzy
	ld a, 50			; score for a yatzy is 50
	ret
.noYatzy
	ld a, 0
	ret

; Calculate a chance score. Just place [DICE_SUM] in a
; @return a score
Chance::
	ld a, [DICE_SUM]
	ret

; Calculate score for pair of pairs
TwoPairs::
	ld b, 0				; keep track of distinct doubles
	ld hl, DICE_TYPE_COUNT + 5	; loop over 6 dice from last one
	ld d, 6				; keep track of current dice
	ld c, 0				; keep track of score

.loop
	ld a, [hld]
	cp 2
	jr c, .notDouble		; if a < 2, not a double
	inc b
	ld a, c				; add 2*(current dice) to score
	add d
	add d
	ld c, a
.notDouble
	dec d
	jr nz, .loop

	ld a, b				; check for prescence of two doubles
	cp 2
	jr c, .noScore			; if b < 2, score is 0
	ld a, c				; else c holds final score
	ret
.noScore
	ld a, 0
	ret

; Calculate full house score
FullHouse::
	ld b, 0				; keeps track of doubles
	ld c, 0				; keeps track of triples

	ld hl, DICE_TYPE_COUNT + 5	; loop from end of DICE_TYPE_COUNT array
	ld d, 6				; loop over all 6 dice values,
					; incrementing b and c as needed

.loop
	ld a, [hld]
	cp 2
	jr nz, .notDouble
	inc b
.notDouble
	cp 3
	jr nz, .notTriple
	inc c
.notTriple
	dec d
	jr nz, .loop

	; for a full house, there must be a single double and single triple
	; by and-ing both b and c, we'll get 1 if and only if this is the case
	ld a, b
	and c
	cp %00000001
	jr nz, .noFullHouse
	ld a, [DICE_SUM]		; if full house present, score is sum
					; of all dice
	ret
.noFullHouse
	ld a, 0				; score zero otherwise
	ret

; Calculate the score for "Of A Kind" scores
; @param b number of dice required to score
; @return a score
OfAKind::
	ld hl, DICE_TYPE_COUNT + 5	; start at end to get highest score
	ld d, 6				; repeat max 6 times for dice values

	; find first dice value with a count greater than b
.countLoop
	ld a, [hld]
	cp b
	jr nc, .countEnd		; if a >= b break
	dec d
	jr nz, .countLoop		; if d > 0 return
	ld a, 0
	ret
.countEnd

	; subtract DICE_TYPE_COUNT from hl to get offset which = 6 - dice value
	ld de, $FFFF - DICE_TYPE_COUNT - 1
	add hl, de			; l now contains 6 - dice value
	; subtract from six to get actual dice value
	ld a, 6
	sub l
	ld l, a

	ld a, 0
.scoreLoop
	add l
	dec b
	jr nz, .scoreLoop
	ret

