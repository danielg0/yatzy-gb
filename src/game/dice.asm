INCLUDE "hardware.inc"

; MOD(X, r)
; perform a MOD X operation on the value stored in r
; @trashes a
MOD: MACRO
	ld a, \2
.loop\@
	sub \1
	jr nc, .loop\@
	add \1				; make value in a positive
	add 1				; for dice, ensure range is 1 to X
	ld \2, a
ENDM

SECTION "Dice Variables", WRAM0

DICE:: DS 5				; store raw values for all 5 dice so
					; they can be drawn to the screen
DICE_SUM: DS 1				; 1 byte with the sum of all the dice
DICE_TYPE: DS 1				; bit-array of dice types present
					; 0 = not present, %--654321
DICE_TYPE_SUM: DS 6			; bytes holding the sum of all dice of
					; each type (1, 2, 3, 4, 5, 6)
DICE_TYPE_COUNT: DS 6			; 6 bytes holding the number of dice of
					; each type (1, 2, 3, 4, 5, 6)

DICE_HELD:: DS 1			; byte bitmap showing which dice are
					; currently held %---54321

; score variables
; pre-calculated so that there is enough time during vblank for transfer
; values stored in BCD using library

; IMPORTANT: stored in memory in the same order as on screen. This is so that
; the score for the category the cursor is next to is:
; score = [W_DICE_SCORES + (W_CURSOR_POS - 3)]
W_DICE_SCORES::
W_SINGLE:: DS 6				; holds values in bcd (1, 2, 3, 4, 5, 6)

W_2_OFAKIND:: DS 1
W_TWOPAIRS:: DS 1
W_3_OFAKIND:: DS 1
W_4_OFAKIND:: DS 1

W_STRAIGHT_LOW:: DS 1
W_STRAIGHT_HI:: DS 1

W_FULLHOUSE:: DS 1
W_CHANCE:: DS 1
W_YATZY:: DS 1

SECTION "Dice", ROM0

; Initialise zero values for all the dice variables
; @return a 0
; @return hl DICE_TYPE_COUNT + 6
InitDice::
	; init all values to 0
	xor a				; ld a, 0

	; 6 byte DICE variable
	ld hl, DICE
REPT 6
	ld [hli], a
ENDR

	; 1 byte DICE_SUM variable
	ld hl, DICE_SUM
	ld [hl], a

	; 1 byte DICE_TYPE variable
	ld hl, DICE_TYPE
	ld [hl], a

	; 6 byte DICE_TYPE_SUM variable
	ld hl, DICE_TYPE_SUM
REPT 6
	ld [hli], a
ENDR

	; 6 byte DICE_TYPE_COUNT variable
	ld hl, DICE_TYPE_COUNT
REPT 6
	ld [hli], a
ENDR

	; 1 byte DICE_HELD variable
	ld hl, DICE_HELD
	ld [hl], a

	; note: no need to init score variables as written to before reading

	ret

; Get new values for all dice using rng functions, updating all DICE_ values,
; then update the score variables using the defined score functions
RollDice::
	; reset score variables before adding new ones
	xor a				; ld a, 0
	ld hl, DICE_SUM
	ld [hl], a
	ld hl, DICE_TYPE
	ld [hl], a

	ld hl, DICE_TYPE_SUM
REPT 6
	ld [hli], a
ENDR
	ld hl, DICE_TYPE_COUNT
REPT 6
	ld [hli], a
ENDR

	; NOTE - to get a dice value, mod 6 is used on a random byte. This
	; DOES NOT create a uniform probability distribution, leaning toward
	; producing 1,2,3 over 4,5,6 by a small amount (1/255 I think).
	; This should probably be replaced in future

	; generate dices rolls for the five dice if the corresponding bit of
	; DICE_HELD isn't set
I_DIE SET 0
REPT 5
	; check if held bit set for this die
	ld a, [DICE_HELD]
	bit I_DIE, a
	jr nz, .dont_roll_\@		; if held bit set use existing value
					; else, roll dice and get new value
	call rand			; load random 16bit value into bc
					; but we'll only use c
	ld c, a				; use value returned into a
					; as entropy is better
	MOD 6, c			; perform modulus to get a value
					; between 1 and 6

	; update DICE variable
	ld hl, DICE + I_DIE
	ld [hl], c

	jr .update_score_\@

.dont_roll_\@
	; load existing dice value into c, which is used by UpdateDice
	ld a, [DICE + I_DIE]
	ld c, a

.update_score_\@
	call UpdateDice			; update score values

I_DIE SET I_DIE + 1
ENDR

	; update score variables

	; singles
	; as DICE_TYPE_SUM already holds required value, just convert
	; essentially, this is memcpy with a call to convert bcd in the middle
	ld c, 6
	ld de, DICE_TYPE_SUM
	ld hl, W_SINGLE
.straightLoop
	ld a, [de]
	call bcd8bit_baa
	ld [hli], a
	inc de
	dec c
	jr nz, .straightLoop

	; chance
	; again, as is held in DICE_SUM, just copy after conversion
	ld a, [DICE_SUM]
	call bcd8bit_baa
	ld [W_CHANCE], a

	; straights
	ld b, %00011111
	call Straight
	call bcd8bit_baa
	ld [W_STRAIGHT_LOW], a
	ld b, %00111110
	call Straight
	call bcd8bit_baa
	ld [W_STRAIGHT_HI], a

	; yatzy
	call Yatzy
	call bcd8bit_baa
	ld [W_YATZY], a

	; two pairs and full house
	call TwoPairs
	call bcd8bit_baa
	ld [W_TWOPAIRS], a
	call FullHouse
	call bcd8bit_baa
	ld [W_FULLHOUSE], a

	; of a kinds
	ld b, 2
	call OfAKind
	call bcd8bit_baa
	ld [W_2_OFAKIND], a
	ld b, 3
	call OfAKind
	call bcd8bit_baa
	ld [W_3_OFAKIND], a
	ld b, 4
	call OfAKind
	call bcd8bit_baa
	ld [W_4_OFAKIND], a

	ret

; Update variable values for a new dice roll
; @param c - new dice roll
; @return c - new dice roll
; @return de - DICE_TYPE_COUNT - DICE_TYPE_SUM
; @return hl - DICE_TYPE_COUNT + c
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
	; able to make a straight comparison as only 5 dice
	ld a, [DICE_TYPE]
	cp b
	jr nz, .fail
	ld a, [DICE_SUM]		; for straights, score is sum of dice
	ret
.fail
	xor a				; ld a, 0
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
	xor a				; ld a, 0
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

	ld a, b				; check for presence of two doubles
	cp 2
	jr c, .noScore			; if b < 2, score is 0
	ld a, c				; else c holds final score
	ret
.noScore
	xor a				; ld a, 0
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
	xor a				; score zero otherwise
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
	xor a				; ld a, 0
	ret
.countEnd

	; after the above, d contains the highest value with a double
	; score is d * b
	xor a				; ld a, 0
.scoreLoop
	add d
	dec b
	jr nz, .scoreLoop
	ret

