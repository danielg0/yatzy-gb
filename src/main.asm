INCLUDE "hardware.inc"

SECTION "Header", ROM0[$100]

EntryPoint:
	di			; disable interrupts
	jp Setup

	DS $150 - @, 0		; fill header with zeros, rgbfix will handle it

SECTION "Main", ROM0

Setup:
	ld hl, rIE		; enable vblank interrupts - used for WaitVBlank
	ld [hl], IEF_VBLANK
	ei

	; debug - seed rng with constant value to get same values every time
	ld bc, 1
	call srand

	; clear WRAM variables
	ld a, $FF		; reset joypad values (none pressed at start)
	ld [W_DPAD], a
	ld [W_BUTT], a
	ld [W_DPAD_OLD], a
	ld [W_BUTT_OLD], a

	call WaitVBlank		; wait for VBlank before disabling screen in
				; in order to perform setup / load in tiles
	ld hl, rLCDC
	res 7, [hl]		; disable screen

	; clear nintendo logo from VRAM
	ld hl, $9900
	ld b, $9900 - $9930
	xor a			; ld a, $00
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
	ld [hl], %11100100	; setup BG palette

	ld hl, rLCDC
	set 7, [hl]		; enable screen

.gameLoop
	; wait for a vblank before checking input
	call WaitVBlank

	; get joypad input and call function based on values
	call ReadJoypad

	; if a button just pressed, call action
	; will perform function based on cursor position
	; inputs changed = W_BUTT || !W_BUTT_OLD
	; inputs changed = W_BUTT || (W_BUTT_OLD xor $FF)
	ld a, [W_BUTT_OLD]
	cpl			; a = a xor $FF
	ld hl, W_BUTT
	or [hl]
	bit 0, a
	jr nz, .noAction	; if a button not pressed (bit 0, a == 1) break
	call GameAction

	; if action called, don't move til next frame
	jr .gameLoop

.noAction
	; if directional button pressed, move cursor
	; directions changed = W_DPAD || !W_DPAD_OLD
	ld a, [W_DPAD_OLD]
	cpl
	ld hl, W_DPAD
	or [hl]
	or %11110000		; ensure first 4 bits don't influence result
	cp $FF
	jr z, .gameLoop		; if dpad not pressed, break

	; move dpad change into e, and call game update func
	ld e, a
	call GameDPAD

	jr .gameLoop

