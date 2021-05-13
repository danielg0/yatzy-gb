INCLUDE "hardware.inc"

SECTION "Header", ROM0[$100]

EntryPoint:
	di				; disable interrupts
	jr Setup

	DS $150 - @, 0			; fill header with zeros, rgbfix will
					; handle it

SECTION "Main", ROM0[$150]

Setup:
	; enable vblank interrupts - used for WaitVBlank
	ld hl, rIE
	ld [hl], IEF_VBLANK
	ei

	; clear WRAM variables
	ld a, $FF			; reset joypad values to none down
	ld [W_DPAD], a
	ld [W_BUTT], a
	ld [W_DPAD_OLD], a
	ld [W_BUTT_OLD], a

	; disable sound controller as unused
	; according to pan docs, saves ~16% GB power consumption
	xor a				; ld a, $00
	ld [rAUDENA], a

	call WaitVBlank			; wait for VBlank before disabling
					; screen in in order to perform
					; setup/load in tiles
	ld hl, rLCDC
	res 7, [hl]			; disable screen

	; clear nintendo logo from VRAM
	ld hl, $9900
	ld b, $9900 - $9930
	xor a				; ld a, $00
.ninLoop
	ld [hl], a
	inc hl
	dec b
	jr nz, .ninLoop

	ld hl, rBGP
	ld [hl], %11100100		; setup BG palette

	; setup color palette
	ld hl, rBCPD
	ld [hl], $FC
	ld [hl], $6B

	ld [hl], $11
	ld [hl], $3B

	ld [hl], $A6
	ld [hl], $29

	ld [hl], $61
	ld [hl], $10

	; load game and menu tiles into vram
	; as they don't overlap, they only need to be loaded once
	call LoadMenuTiles
	call LoadGameTiles

	; draw menu to second map
	call LoadMenuScreen

	; draw fixed game text to first map
	call LoadGameText
	; setup first game so all graphics are present for transition
	call SetupGame

	; load highscore from RAM
	call ReadHighscore
	call DrawHighscore

	; enable screen
	ld hl, rLCDC
	set 7, [hl]

	; fallthrough to menu

Menu:
	; set LCDC options
	ld hl, rLCDC
	set 3, [hl]			; draw SCRN_1 background
	res 4, [hl]			; set vram tile addressing mode

.menuLoop
	; wait for frame end and check joypad
	call WaitVBlank
	call ReadJoypad

	; check if start pressed yet
	; inputs changed = W_BUTT || !W_BUTT_OLD
	; inputs changed = W_BUTT || (W_BUTT_OLD xor $FF)
	ld a, [W_BUTT_OLD]
	cpl				; a = a xor $FF
	ld hl, W_BUTT
	or [hl]

	; start is pressed if bit 3 is 0
	; so if not-zero, continue looping
	bit 3, a
	jr nz, .menuLoop

	; else, do slide transition and fallthrough to game
	call Transition

Game:
	; seed rng used for dice rolls
	; if RNG value set to -1, use clock time
IF RNG == -1
	ld b, $00
	ld a, [rDIV]
	ld c, a				; bc now contains 16 bit rDIV
	; otherwise use the value in RNG as a seed
ELSE
	ld bc, RNG
ENDC
	call srand

	; set LCDC settings
	ld hl, rLCDC
	res 3, [hl]			; set correct bg layer
	set 4, [hl]			; set vram tile addressing mode

.gameLoop
	; wait for a vblank before checking input
	call WaitVBlank

	; get joypad input and call function based on values
	call ReadJoypad

	; if directional button pressed, move cursor
	; directions changed = W_DPAD || !W_DPAD_OLD
	ld a, [W_DPAD_OLD]
	cpl
	ld hl, W_DPAD
	or [hl]
	or %11110000			; so first 4 bits don't change result
	cp $FF
	jr z, .noDPAD			; if dpad not pressed, check a button

	; move dpad change into e, and call dpad update function
	ld e, a
	call GameDPAD

.noDPAD
	; if a button just pressed, call action
	; will perform function based on cursor position
	; inputs changed = W_BUTT || !W_BUTT_OLD
	; inputs changed = W_BUTT || (W_BUTT_OLD xor $FF)
	ld a, [W_BUTT_OLD]
	cpl				; a = a xor $FF
	ld hl, W_BUTT
	or [hl]
	bit 0, a
	jr nz, .gameLoop		; if a button not pressed
					; (bit 0, a != 0) continue game loop

	; a button pressed, so call GameAction then check if game over
	call GameAction

	; check if the game is over
	; the game can only be over following an a button press, so reduce
	; calls by only checking after one has occurred
	call IsGameOver			; resets c flag if game over
	jr c, .gameLoop			; only continue loop if game not over

GameOver:
	; display game over message
	call DrawGameOver

.gameOverLoop
	; wait for a vblank before checking input
	call WaitVBlank

	; get joypad input and call function based on values
	call ReadJoypad

	; check if a or b button pressed
	; inputs changed = W_BUTT || !W_BUTT_OLD
	; inputs changed = W_BUTT || (W_BUTT_OLD xor $FF)
	ld a, [W_BUTT_OLD]
	cpl				; a = a xor $FF
	ld hl, W_BUTT
	or [hl]
	bit 0, a
	jr z, .aPressed
	bit 1, a
	jr z, .bPressed

	; if no input given, loop
	jr .gameOverLoop

	; otherwise, restart/end game based on button pressed
	; push destination to stack so that return acts like a jp
	; this saves repeating various cleanup calls
.aPressed
	; start new game
	ld hl, Game
	jr .gameOver
.bPressed
	; transition to menu
	; done now so that game over message is still visible during transition
	call Transition

	ld hl, Menu
	; fallthrough to .gameOver
.gameOver
	; hl just set to where to jp to next
	push hl

	; draw over game over message
	call CleanupGameOver
	; setup next game
	call SetupGame

	; jps to label just pushed to stack
	ret

; Display animation transitioning from _SCRN1->_SCRN0 or vice versa
Transition:
	; use bit 3 in rLCDC to determine screen we're transitioning from
	; use this to set various constants used in the function
	ld a, [rLCDC]
	bit 3, a
	jr z, .gameToMenu
.menuToGame
	; use d register to track the y position of the seam
	; will go from SCRN_Y - 4 to 0 if currently on SCRN_1, vice versa
	; otherwise. the minus 4 is so that subtracting 3 to get LYC doesn't
	; give negative value
	ld d, SCRN_Y - 4
	; use b to track the value to end the loop on
	ld b, 0
	; use c to track value add to d to get the value for LYC
	ld c, 3
	; use e to track the number added to d each loop iteration
	ld e, -2
	jr .constSet
.gameToMenu
	ld d, 0
	ld b, SCRN_Y - 4
	ld c, -3
	ld e, 2

	; as not on menu screen currently, switch to it
	; this is because the menu screen is always drawn at the top
	xor %00011000			; a holds value of rLCDC from earlier
	ld [rLCDC], a
.constSet

	; enable stat LYC=LY interrupts
	ld hl, rSTAT
	set 6, [hl]
	ld hl, rIE
	set 1, [hl]

	; preload rLCDC address into hl
	; saves cycles after stat interrupt
	ld hl, rLCDC

	; preload bitmask for flipping SCRN&Tiles into C
	; saves cycles during stat interrupt
	ld c, %00011000

.loop
	; set line to interrupt on, using e constant set earlier
	ld a, d
	add 3
	ldh [rLYC], a

	; calculate new value for scroll y
	; use cycles now to save them after stat interrupt
	xor a
	sub d

	halt				; suspend cpu and wait til LY=LYC
					; ie. wait til stat interrupt

	; assign new value for scroll y
	ldh [rSCY], a

	; swap which screen/tile bank is being used
	; always swap from SCRN1 to SCRN0
	ld a, [hl]
	xor c
	ld [hl], a

	halt				; suspend cpu til vblank

	; change screen being used, tile bank and value of scroll y
	; always change from SCRN0 to SCRN1
	ldh a, [rLCDC]
	xor c
	ldh [rLCDC], a
	xor a				; ld a, 0
	ldh [rSCY], a

	; add difference to d and if not yet zero, loop
	ld a, d
	add e				; sets z flag if d now 0
	ld d, a
	cp a, b
	jr nz, .loop

	; disable stat LYC=LY interrupts
	ld hl, rSTAT
	res 6, [hl]
	ld hl, rIE
	res 1, [hl]

	ret

