INCLUDE "hardware.inc"
INCLUDE "macros.inc"

; Game Constants
CURSOR_MIN EQU 01			; max value W_CURSOR_POS can hold
CURSOR_MAX EQU 17			; min ""
HELD_MIN EQU 01				; max and min value W_HELD_POS can hold
HELD_MAX EQU 05

SECTION "Game Variables", WRAM0

W_CURSOR_POS: DS 1			; byte holding position of cursor
					; last bit is 1 if both cursors are
					; locked in place
W_HELD_POS: DS 1			; byte holding position of hold cursor
					; the 7th (last) bit's 0 if visible

W_SCORE: DS 2				; stores score of current game as BCD
					; two bytes as max value is 374
W_HIGH_SCORE: DS 2			; stores highest game score achieved as
					; BCD. Reset when game turned off
W_SINGLE_SUM: DS 2			; stores sum of all scored single
					; categories as bcd (max is 126)
					; the last bit of the second byte
					; stores whether the bonus has been
					; scored yet

W_USED_SCORES: DS 2			; bit array storing which scoring
					; categories have been used (order is
					; the same as for cursor position)
					; set bit = category used

W_ROLLS: DS 1				; a byte holding the number of dice
					; rolls left

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

	; zero out score
	xor a				; ld a, 0
	ld hl, W_SCORE
	ldi [hl], a
	ld [hl], a

	; zero out singles total
	ld hl, W_SINGLE_SUM
	ldi [hl], a
	ld [hl], a

	; zero out used scores
	ld hl, W_USED_SCORES
	ldi [hl], a
	ld [hl], a

	; load number for a "0" into d to save cycles
	ld d, "0"

	; draw zeros next to sum, bonus and high score labels
	; done in setup to draw over previous game's score
	; performed manually as it's quicker than calling functions and means
	; it all fits in vblank
	AT _SCRN0, 6, 11
	ld [hli], a			; a = 0 which is blank character
	ld [hl], d
	AT _SCRN0, 6, 12
	ld [hli], a
	ld [hl], d

	AT _SCRN0, 14, 14
	ld [hli], a
	ld [hli], a
	ld [hl], d

	; draw zeros next to all scoring categories
	; similar reasons to above
	; iterate over left categories column
	AT _SCRN0, 6, 4
	ld bc, SCRN_VX_B - 1		; added to hl each iter to get next row
REPT 6
	ld [hli], a			; a = 0, null tile
	ld [hl], d
	add hl, bc
ENDR

	; iterate over right categories
	AT _SCRN0, 17, 4
	;ld bc, SCRN_X_B - 1
REPT 9
	ld [hli], a
	ld [hl], d
	add hl, bc
ENDR

	; erase all used category markers
	ld hl, CURSOR_TABLE_CATEGORIES
REPT 15
	ld a, [hli]
	ld c, a
	ld a, [hli]
	ld b, a
	xor a				; ld a, 0
	ld [bc], a
ENDR

	; draw ROLL and HOLD buttons here so it appears after game over
	ld de, LABEL_TEXT_ROLLHELD
	AT _SCRN0, 2, 1
	call Strcpy
	inc de				; get past final null char
	AT _SCRN0, 2, 2
	call Strcpy

	; setup cursor position
	; ensure a cursor pos change while avoiding overwriting text, etc.
	ld hl, W_CURSOR_POS
	ld [hl], CURSOR_MIN
	AT _SCRN0, 1, 1
	ld [hl], ">"

	; lock cursor in position next to roll button
	; don't allow player to score/change held until they've rolled the dice
	ld a, [W_CURSOR_POS]
	set 7, a
	ld [W_CURSOR_POS], a

	; setup roll count
	; start with 3 rolls
	ld hl, W_ROLLS
	ld [hl], 3

	; setup hold pos
	ld a, HELD_MAX
	ld [W_HELD_POS], a
	ld a, HELD_MIN			; start out with non-visible cursor
	or %10000000			; in first possible position
	call UpdateHeldCursor

	; draw press a prompt
	call DrawPrompt

	ret

; return a value indicating whether the game is finished yet
; @return c flag reset if game is over, overwise it's set
; @trashes a
IsGameOver::
	; game over if all categories have been used
	ld a, [W_USED_SCORES]
	cp $ff
	jr nz, .GameNotOver		; if all bits 1, all categories used
	ld a, [W_USED_SCORES + 1]
	cp $7f				; not all bits are used in 2nd byte
	jr nz, .GameNotOver

	; if reached here, game is over
	; set carry flag then invert it to reset it
	scf
	ccf
	ret

.GameNotOver
	; game not over yet, so set carry flag
	scf
	ret

; draw updated score variables (defined in dice.asm) to the screen
; must be called during vblank period/when display is off
DrawScores::
	; draw all scores to screen, ignoring those already used
	; ie. freeze category scores on the value they were used
	; and using the fact that all scores are in a contiguous memory space
	; ordered according to cursor position

	; use de to track the address of the next score
	ld de, W_DICE_SCORES

	; load the first byte at W_USED_SCORES into c
	ld hl, W_USED_SCORES
	ld c, [hl]

	; create variable to track which bit of c is being used
C_BIT = 0

	; singles - track y coord using Y variable
Y = 4
REPT 6
	bit C_BIT, c			; if bit is 1, category has been used
	jr nz, .next_\@			; if category already used, don't draw
	AT _SCRN0, 6, Y			; load vram address into hl
	ld a, [de]			; load score into a
	call BCDcpy
.next_\@
	inc de				; get address of score for next iter
C_BIT = C_BIT + 1			; move to next bit of c
Y = Y + 1				; draw next score in row below
ENDR


	; left-hand side, using first byte of c
Y = 4
REPT 2
	bit C_BIT, c
	jr nz, .next_\@
	AT _SCRN0, 17, Y
	ld a, [de]
	call BCDcpy
.next_\@
	inc de
C_BIT = C_BIT + 1
Y = Y + 1
ENDR


	; reset C_BIT and load second byte of W_USED_SCORES into c
C_BIT = 0
	ld hl, W_USED_SCORES + 1
	ld c, [hl]


	; left-hand side, second byte
	; no need to reset Y as it carries on from last loop
REPT 7
	bit C_BIT, c
	jr nz, .loop_\@
	AT _SCRN0, 17, Y
	ld a, [de]
	call BCDcpy
.loop_\@
	inc de
Y = Y + 1
C_BIT = C_BIT + 1
ENDR

	ret

; draw current game score, singles sum and bonus to the screen
DrawCurrentScores:
	AT _SCRN0, 14, 14		; load pos of score zone into hl

	ld a, [W_SCORE + 1]		; load hundreds column into a
	or a				; compare to zero
	jr nz, .hundredsNonZero		; if non-zero, write number
	ld [hli], a			; else, write blank char

	; only write tens char if non-zero, else write blank
	ld a, [W_SCORE]			; load tens into a
	and $F0
	swap a

	; if non-zero add offset then write
	; this has effect of writing blank if tens zero
	jr z, .tensNotZero
	add $30
.tensNotZero
	ld [hli], a

	jr .units

.hundredsNonZero
	add $30				; add offset to get to numbers in font
	ld [hli], a

	; always write a char to screen, even if tens zero
	ld a, [W_SCORE]			; load tens into a
	and $F0
	swap a

	add $30				; add offset to get to numbers in font
	ld [hli], a

	; for units, always write, even if zero
.units
	ld a, [W_SCORE]			; load units into a
	and $0F
	add $30				; add offset to get to numbers in font
	ld [hl], a

	; draw sum of scored singles categories and the bonus value (if scored)
	ld hl, W_SINGLE_SUM + 1
	ld a, [hld]
	ld c, a				; get hundreds digit and whether bonus
					; scored yet flag
	ld a, [hl]			; get tens and units values
	ld b, a				; store value of a for later

	; if no hundreds column, write bcd value in a to screen
	bit 0, c			; as 105 is the max value, only a one
					; will be stored in the hundreds col
	jr nz, .drawHundreds

	AT _SCRN0, 6, 11
	call BCDcpy

	; if bonus bit set, write 50 to the bonus section
	bit 7, c			; bonus bit is last bit
	ret z				; if zero, return, else continue
					; and draw bonus score

.drawBonus
	; draw bonus value (50) to the screen
	ld a, $50
	AT _SCRN0, 6, 12
	call BCDcpy

	ret				; VERY IMPORTANT

.drawHundreds
	; draw 1 to screen next to sum, then increment and draw hundreds
	; and units column (don't use BCDcpy, as this won't draw the tens
	; column if it's value is zero)
	AT _SCRN0, 6, 11
	ld a, $31			; 1 + 0x30 to get an ascii 1
	ld [hli], a
	ld a, b				; draw tens column
	swap a
	and $0F				; remove units column
	add $30				; to get an ascii digit
	ld [hli], a
	ld a, b				; draw units
	and $0F
	add $30
	ld [hl], a

	; jump back to earlier to draw the bonus score
	; if sum >= 100, bonus (63) must have already been scored
	jr .drawBonus

; draw score to the screen
DrawHighscore::
	; store address of W_HIGHSCORE in hl
	ld de, W_HIGHSCORE + 1

	; get hundreds column of highscore
	ld a, [de]
	dec de				; ld hl, W_HIGHSCORE
	or a				; set flags based on value of a
	jr z, .checkTens		; if zero, don't draw

	; as hundreds non-zero, draw to screen
	add a, $30			; convert to ascii
	AT _SCRN0, 14, 15
	ld [hl], a
	jr .drawTens			; as hundreds present, always draw tens

.checkTens
	ld a, [de]
	and $F0
	swap a
	jr z, .drawUnits		; if tens not present, draw units
	jr .drawTensLoaded		; skip loading tens unit if already done

.drawTens
	ld a, [de]
	and $F0
	swap a

.drawTensLoaded
	add a, $30
	AT _SCRN0, 15, 15
	ld [hl], a

.drawUnits
	ld a, [de]
	and $0F
	add a, $30
	AT _SCRN0, 16, 15
	ld [hl], a

	ret

; draw a text prompt asking the player to press a
; must be called during vblank period
DrawPrompt::
	ld de, PROMPT_TEXT
	AT _SCRN0, 8, 1			; load screen pos into hl
	call Strcpy
	ret

; draw dice values to the screen - reading from DICE (defined in dice.asm)
; must be called during vblank period
DrawDice::
	ld de, DICE
	ld a, [de]			; use ascii hidden chars for dice
	AT _SCRN0, 8, 1
	ld [hli], a

REPT 4
	xor a				; ld a, $00
	ld [hli], a			; write 0s inbetween to erase any text
	inc de
	ld a, [de]
	ld [hli], a
ENDR

	ret

; Draw a held symbol (*) beneath all held dice
; @trashes a
; @trashes hl
DrawHeld:
	; load in held bit array (defined in dice.asm)
	ld a, [DICE_HELD]
	; load in position of first dice
	AT _SCRN0, 8, 2

I_DIE = 0
REPT 5
	; if ith of a is set, write "*", else write " "
	bit I_DIE, a
	jr z, .drawSpace_\@
	ld [hl], "*"
	jr .end_\@
.drawSpace_\@
	ld [hl], " "
.end_\@

	; increment hl twice as that's the gap between dice
	inc hl
	inc hl
I_DIE = I_DIE + 1
ENDR

	ret

; Perform an action
; A button just pressed, use cursor pos to figure out what to do next
GameAction::
	; load cursor pos into a
	ld a, [W_CURSOR_POS]

	; if last bit set, unset to unlock cursor movement
	res 7, a			; don't bother comparing, just clear
	ld [W_CURSOR_POS], a

	cp 1				; cursor pos 1 is roll button
	jr nz, .noRoll			; if a == 1, roll dice

	; check roll count to see if there are any left
	ld hl, W_ROLLS
	ld a, [hl]
	and a				; cp a, a
	ret z				; return if no rolls left
	dec a				; else decrease and write to memory
	ld [hl], a

	; roll dice, updating scores, then draw to screen
	; remember to wait for a vblank after updating scores as this may take
	; more than one frame
	call RollDice
	call WaitVBlank
	call DrawScores
	call DrawDice

	; when complete, return to main loop
	ret
.noRoll

	; if cursor next to hold button, toggle holding of die
	ld a, [W_HELD_POS]
	bit 7, a			; last bit indicates visibility
	jr nz, .noHeldToggle		; if 1, action isn't toggling hold

	; create bit mask where bit set where held cursor is
	ld b, %00000001
.leftShiftBegin
	cp a, 1				; not a do-while loop as b already
					; holds a value required to flip die 1
	jr z, .leftShiftEnd
	sla b
	dec a
	jr .leftShiftBegin
.leftShiftEnd

	; xor existing HELD_DIE variable (see dice.asm) to flip selected die
	ld hl, DICE_HELD
	ld a, [hl]
	xor b
	ld [hl], a

	; redraw held dice indicator
	call DrawHeld

	; return to make sure scoring isn't attempted
	ret

.noHeldToggle

	; else, assume cursor is next to a scoring button
	; NOTE: this *will* cause errors if cursor pos out of range

	; check if this scoring category has been used before
	; index in W_USED_SCORES is W_CURSOR_POS - 3
	ld a, [W_CURSOR_POS]		; needed as hold trashed a
	sub 3				; ignore held and roll buttons

	; as USED_SCORES spread over two bytes, find correct byte to right to
	ld hl, W_USED_SCORES		; get address of score variables
	cp a, 8				; if a >= 8, write to second byte
	jr c, .firstByte
	inc hl
	sub 8				; get a back into correct range
.firstByte

	add 1				; add one to a so decrement can be
					; done at least once
	ld b, $01			; use b to hold bit mask
.loop
	dec a				; decrement a, if zero, than b is the
	jr z, .done			; correct bit mask
	sla b
	jr .loop
.done

	; get value of bit in W_USED_SCORES
	; if set, return, else set bit and continue
	ld a, [hl]
	and b				; if value in a is non-zero, bit set
	ret nz
	ld a, [hl]			; bit not-set so set it and write to
	or b				; memory
	ld [hl], a

	; get address of score using W_DICE_SCORES + (W_CURSOR_POS - 3)
	; see dice.asm for more info
	ld a, [W_CURSOR_POS]		; needed as a trashed
	sub 3				; a = W_CURSOR_POS - 3
	ld c, a
	ld b, $00			; bc now contains 16bit W_CURSOR_POS-3
	add 3				; a = W_CURSOR_POS
	ld hl, W_DICE_SCORES
	add hl, bc			; score = [hl]
	ld b, [hl]			; b holds score of cat next to cursor

	; if cursor is next to a singles category, add score to total and check
	; if the bonus is scored
	ld a, [W_CURSOR_POS]		; assume W_CURSOR_POS > 2
	cp 9				; if W_CURSOR_POS < 9 add to single sum
	jr nc, .singleEnd		; so if a >= 9, skip add (no need
					; to check if bonus scored)
	; add score to single sum, correcting for bcd format
	ld a, [W_SINGLE_SUM]
	add b
	daa				; will set c flag if overflow occurs
	ld [W_SINGLE_SUM], a
	jr nc, .noOverflow		; if overflow occured, inc next byte
	ld hl, W_SINGLE_SUM + 1
	ld [hl], %10000001		; as max is 105, overflow will only
					; occur once during game, so a one
					; will always be written on overflow.
					; Also, whenever overflow occurs, the
					; bonus must have already been scored
					; so set the bonus scored bit

.noOverflow
	; if score is greater than bonus, add bonus to this round's score if
	; not added (this is tracked using the last bit of the second byte of
	; W_SINGLE_SUM)
	ld hl, W_SINGLE_SUM + 1		; check if bonus scored yet
	bit 7, [hl]
	jr nz, .singleEnd		; if set, bonus already scored

	dec hl				; ld hl, W_SINGLE_SUM
	ld a, [hl]			; no need to check hundred's column
					; as max score for singles in one round
					; is 30, so singles sum would already
					; be at least 70, and have already
					; scored the bonus
	cp $63				; c flag set if units < 63
	jr c, .singleEnd

	; add bonus to this round's score
	; there's no need to worry about overflow, as the bonus is only scored
	; on rounds where a single was scored, the max score of which is 30
	; (ie. five 6's), giving a total score of 80
	ld a, $50
	add b				; this round's score is stored in b
	daa
	ld b, a

	; set bonus scored bit
	inc hl
	set 7, [hl]

.singleEnd
	; add score to total score and redraw on screen
	; must occur during vblank period, which it always will
	ld a, b				; load score into a
	ld hl, W_SCORE
	add [hl]
	daa				; will set c flag if overflow occurs
	ld [hl], a

	; if carry flag set, overflow occurred, so increment the hundreds
	; column stored in the next memory address
	; incrementing will preserve bcd, as the highest value that'll be
	; stored is 374
	jr nc, .noCarry
	inc hl
	inc [hl]
.noCarry

	; write score to screen
	call DrawCurrentScores

	; if new score is greater than highscore, increase highscore and redraw
	ld de, W_SCORE + 1
	ld hl, W_HIGHSCORE + 1
	; compare hundreds column
	ld a, [de]
	cp [hl]

	; for hundreds column:
	; if highscore > score, the highscore doesn't need changing
	; if highscore == score, the units column needs to be checked
	; if highscore < score, the highscore needs to be changed
	jr c, .noHighscoreChange	; if highscore > score, c set
	; decrement hl and de in preperation to either check units or change the
	; highscore. This WONT affect the flags, so the comparision still works
	dec hl
	dec de
	jr z, .checkUnits		; if highscore == score, z set
	jr .highscoreChange		; if we're here, highscore < score

.checkUnits
	; de and hl already point at units columns
	; however, switch around whats being compared so only needs a single jr
	ld a, [de]
	ld b, a
	ld a, [hl]
	cp b

	; for units column:
	; if highscore >= score, don't change highscore
	; else, change highscore
	jr nc, .noHighscoreChange	; if highscore >= score, c reset
	; else, fallthrough to highscore change

.highscoreChange
	; de and hl both point at units column
	; copy score to highscore
	ld a, [de]
	ld [hli], a
	inc de
	ld a, [de]
	ld [hl], a

	call WriteHighscore
	call DrawHighscore

.noHighscoreChange

	; reset game to pre-roll state
	; move cursor back next to roll button
	ld a, 1
	call UpdateCursor

	; lock dice until roll occurs
	ld hl, W_CURSOR_POS
	ld a, [hl]
	set 7, a
	ld [hl], a

	; reset held dice
	xor a				; ld a, 0
	ld [DICE_HELD], a
	call DrawHeld

	; blank out dice and draw text
	call DrawPrompt

	; increase dice rolls back to 3
	ld hl, W_ROLLS
	ld [hl], 3

	ret

; Perform actions based on DPAD input
; @param e the dpad input byte, 0 used where input changed
GameDPAD::
	ld hl, W_CURSOR_POS
	ld a, [hl]

	; if last bit of W_CURSOR_POS set, don't perform dpad update
	; note: this will lock cursor and held-cursor in position
	bit 7, a
	ret nz

	bit 3, e			; check if down pressed
	jr nz, .notCursorDown
	inc a				; if so, increment position
.notCursorDown

	bit 2, e			; check if up pressed
	jr nz, .notCursorUp
	dec a				; if so, decrement position
.notCursorUp

	; if cursor is in score zone, process left/right movement
	cp 3				; if a >= 3
	jr c, .cursorLREnd

	bit 0, e			; 	if right pressed and a < 9
	jr nz, .notCursorRight
	cp 9
	jr nc, .notCursorRight

	add 6				; 		a += 6

.notCursorRight

	bit 1, e			; 	if left pressed and 9 <= a < 15
	jr nz, .cursorLREnd
	cp 9
	jr c, .cursorLREnd
	cp 15
	jr nc, .cursorLREnd

	sub 6				; 		a -= 6

.cursorLREnd

	; if a cursor position change occurred, call UpdateCursor
	cp [hl]
	jr z, .noCursorUpdate

	call UpdateCursor		; no need to save dpad (e) as unchanged
	ld a, d				; load new cursor pos back into a
.noCursorUpdate

	; load current held cursor position into b
	ld hl, W_HELD_POS
	ld b, [hl]

	; update held cursor visibility based on cursor position
	cp a, 2				; if cursor position is next to held
	jr nz, .notHeld
	res 7, b			; set held cursor visible
	jr .heldVisEnd
.notHeld
	set 7, b			; else make visible
.heldVisEnd

	; if cursor visible, process dpad input
	bit 7, b
	jr nz, .heldLREnd

	; if right held, increment position
	bit 0, e
	jr nz, .notHeldRight
	inc b
.notHeldRight

	; if left held, decrement position
	bit 1, e
	jr nz, .heldLREnd
	dec b
.heldLREnd

	; if held pos changed, call UpdateHeldCursor
	ld a, b
	cp [hl]
	ret z

	call UpdateHeldCursor
	ret

; Update cursor position on screen
; assumes cursor position changed
; @param a the new position of the cursor
; @return a character code for ">"
; @return bc address in VRAM of the new cursors position
; @return hl W_CURSOR_POS
; @return d new cursor position (ie. a)
; @trashes e
; @return flags depends on if a was in range
UpdateCursor:
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

	; load old position and check if next to a score category
	ld hl, W_CURSOR_POS
	ld a, [hl]			; retrieve current cursor position
	cp 3				; check if next to scoring category
	jr c, .writeBlankCharacter	; if a < 3, just writeBlankCharacter

	; else, check if category next to cursor has been used
	sub 3				; ignore held and roll buttons
	cp a, 8				; see if score category is in first
					; or second byte
	ld hl, W_USED_SCORES
	jr c, .firstByte		; if a < 8, read first byte
	inc hl
	sub 8
.firstByte

	ld e, [hl]
	and a				; set zero flag if a zero
.loop
	jr z, .rotateEnd		; if a zero, jump to end of loop
	rrc e				; rotate b right to put correct bit
					; into first position
	dec a
	jr .loop
.rotateEnd

	; first bit in b now indicates whether score category has been used
	bit 0, e
	jr z, .writeBlankCharacter
	ld a, "*"
	ld [bc], a			; write star to show category used
	jr .writeEnd
.writeBlankCharacter
	xor a				; ld a, $00
	ld [bc], a
.writeEnd

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

; update held cursor position on screen
; @param a new value for cursor position where last bit indicates visibility
; @return a new cursor position
; @trashes ce
; @trashes hl
; @trashes b if old cursor position visible
; @trashes d if new cursor position visible
UpdateHeldCursor:
	; assume held cursor always needs changing when this is called

	ld e, a				; save new pos for later

	; ignore last bit of new value when restricting range
	and %01111111

	; wraps around above and below CURSOR_MIN and CURSOR_MAX
	cp HELD_MIN			; if a >= HELD_MIN
	jr nc, .aboveMin
	ld a, HELD_MAX
.aboveMin
	cp HELD_MAX + 1			; if a <= HELD_MAX
	jr c, .belowMax
	ld a, HELD_MIN
.belowMax

	; correct final bit
	bit 7, e
	jr z, .endBitZero
	set 7, a
.endBitZero

	; save limited and corrected value
	ld e, a

	; load old position into c
	ld hl, W_HELD_POS
	ld c, [hl]

	; if visible, delete old character
	bit 7, c
	jr nz, .dontClearOld

	; dereference address in HELD_TABLE to get old vram address
	ld hl, HELD_TABLE
	ld b, $00			; bc contains 16-bit old held pos
	add hl, bc			; [hl] is VRAM position
	add hl, bc			; add twice due to 16-bit values

	ld a, [hli]			; remember: little endian encoding
	ld c, a
	ld a, [hl]			; bc contains VRAM address of cursor
	ld b, a

	; clear old cursor
	xor a				; ld a, $00
	ld [bc], a

.dontClearOld

	; if visible bit of new pos set, write new cursor
	bit 7, e
	jr nz, .dontDrawNew

	; dereference held table pos
	ld hl, HELD_TABLE
	ld d, $00			; de contains 16-bit new held pos
	add hl, de
	add hl, de

	ld a, [hli]
	ld c, a
	ld a, [hl]
	ld b, a

	; write new cursor
	ld a, "^"
	ld [bc], a

.dontDrawNew

	; update variable
	ld a, e
	ld [W_HELD_POS], a

	ret

; Load in the text that doesn't change during the game as well as 00 scores
; console must be in VBlank/have screen turned off
LoadGameText::
	ld de, LABEL_TEXT

	; This code used to draw ROLL/HELD text, but this isn't needed anymore
	; as they're drawn in the setup function.

;	AT _SCRN0, 1, 1
;	call Strcpy
;	inc de
;	AT _SCRN0, 1, 2
;	call Strcpy
;	inc de

	AT _SCRN0, 2, 4
	call Strcpy

	inc de				; get past final null char
	AT _SCRN0, 2, 5
	call Strcpy

	inc de
	AT _SCRN0, 2, 6
	call Strcpy
	inc de
	AT _SCRN0, 2, 7
	call Strcpy
	inc de
	AT _SCRN0, 2, 8
	call Strcpy
	inc de
	AT _SCRN0, 2, 9
	call Strcpy
	inc de
	AT _SCRN0, 2, 11
	call Strcpy

	inc de
	AT _SCRN0, 10, 4
	call Strcpy
	inc de
	AT _SCRN0, 10, 5
	call Strcpy
	inc de
	AT _SCRN0, 10, 6
	call Strcpy
	inc de
	AT _SCRN0, 10, 7
	call Strcpy
	inc de
	AT _SCRN0, 10, 8
	call Strcpy
	inc de
	AT _SCRN0, 10, 9
	call Strcpy
	inc de
	AT _SCRN0, 10, 10
	call Strcpy
	inc de
	AT _SCRN0, 10, 11
	call Strcpy
	inc de
	AT _SCRN0, 10, 12
	call Strcpy

	inc de
	AT _SCRN0, 2, 12
	call Strcpy
	inc de
	AT _SCRN0, 3, 14
	call Strcpy
	inc de
	AT _SCRN0, 3, 15
	call Strcpy

	; Draw game border
	; Corners
	AT _SCRN0, 0, 0
	ld [hl], $0C
	AT _SCRN0, 19, 0
	ld [hl], $0D
	AT _SCRN0, 19, 17
	ld [hl], $0E
	AT _SCRN0, 0, 17
	ld [hl], $0F

	; Borders
	; Top border
	AT _SCRN0, 1, 0
	ld a, $08
REPT 18
	ld [hli], a
ENDR

	; Right Border
	AT _SCRN0, 19, 1
	ld a, $09
	ld bc, $20
REPT 16
	ld [hl], a
	add hl, bc
ENDR

	; Bottom Border
	AT _SCRN0, 1, 17
	ld a, $0A
REPT 18
	ld [hli], a
ENDR

	; Left Border
	AT _SCRN0, 0, 1
	ld a, $0B
	; ld bc, 19			; unnecessary - see right border
REPT 16
	ld [hl], a
	add hl, bc
ENDR

	ret

SECTION "Game Data", ROM0

LABEL_TEXT_ROLLHELD:
	DB "ROLL", 0			; AT(2, 1)
	DB "HELD", 0			; AT(2, 1)
LABEL_TEXT:
	DB "1'S: 0", 0			; AT(2, 4)
	DB "2'S: 0", 0			; AT(2, 5)
	DB "3'S: 0", 0			; AT(2, 6)
	DB "4'S: 0", 0			; AT(2, 7)
	DB "5'S: 0", 0			; AT(2, 8)
	DB "6'S: 0", 0			; AT(2, 9)
	DB "SUM:", 0			; AT(2, 11)

	DB "1 PAIR: 0", 0			; AT(10, 4)
	DB "2 PAIR: 0", 0			; AT(10, 5)
	DB "3 KIND: 0", 0			; AT(10, 6)
	DB "4 KIND: 0", 0			; AT(10, 7)
	DB "SMALL : 0", 0			; AT(10, 8)
	DB "LARGE : 0", 0			; AT(10, 9)
	DB "FULL H: 0", 0			; AT(10, 10)
	DB "CHANCE: 0", 0			; AT(10, 11)
	DB "YATZY : 0", 0			; AT(10, 12)

	DB "BON:", 0			; AT(2, 12)
	DB "SCORE:", 0			; AT(3, 14)
	DB "HIGHSCORE:", 0		; AT(3, 15)


; Cursor location lookup table
; byte pairs - a lookup table giving screen positions for corresponding
; W_CURSOR_POS values
CURSOR_TABLE:
	DW $0000			; blank to allow for wrapping around
	DW_AT 1, 1			; ROLL
	DW_AT 1, 2			; HELD

CURSOR_TABLE_CATEGORIES:
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

; Held cursor location lookup table
; byte pairs - lookup table similar to CURSOR_TABLE
HELD_TABLE:
	DW $0000			; blank to allow for wrapping
	DW_AT 8, 3			; dice 1
	DW_AT 10, 3			; dice 2
	DW_AT 12, 3			; dice 3
	DW_AT 14, 3			; dice 4
	DW_AT 16, 3			; dice 5

; A text prompt displayed whenever the user needs to press a
PROMPT_TEXT:
	DB "(PRESS A)", 0			; AT(8, 1)

INCLUDE "font.inc"

