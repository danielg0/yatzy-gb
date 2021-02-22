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

	; debug - seed rng with constant value to get same values every time
	ld bc, 1
	call srand

	; clear WRAM variables
	ld a, $FF			; reset joypad values to none down
	ld [W_DPAD], a
	ld [W_BUTT], a
	ld [W_DPAD_OLD], a
	ld [W_BUTT_OLD], a

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

Game:
	call LoadGameTiles
	call LoadGameText
	call SetupGame

	ld hl, rBGP
	ld [hl], %11100100		; setup BG palette

	ld hl, rLCDC
	set 7, [hl]			; enable screen

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
	; wait for vblank, disable screen and jump back to game setup
	; TODO: decide whether to reseed rng
	ld hl, rLCDC
	res 7, [hl]			; disable screen

	; display game over message
	call DrawGameOver

	ld hl, rLCDC
	set 7, [hl]			; enable screen

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

.aPressed
	; start new game
	; disable screen - no need to wait for vblank
	ld hl, rLCDC
	res 7, [hl]
	call CleanupGameOver
	jr Game

.bPressed
	; TODO - menu
	jr .bPressed

