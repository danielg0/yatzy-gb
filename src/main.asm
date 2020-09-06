INCLUDE "hardware.inc"

SECTION "Header", ROM0[$100]

EntryPoint:
	di			; disable interrupts
	jp Setup

	DS $150 - @, 0		; fill header with zeros, rgbfix will handle it

SECTION "Main", ROM0

Setup:
	; debug - seed rng with constant value to get same values every time
	ld bc, 1
	call srand

	; clear WRAM variables
	; etc.

	call WaitVBlank		; wait for VBlank before disabling screen in
				; in order to perform setup / load in tiles
	ld hl, rLCDC
	res 7, [hl]		; disable screen

	; clear nintendo logo from VRAM
	ld hl, $9900
	ld b, $9900 - $9930
	ld a, $00
.ninLoop
	ld [hl], a
	inc hl
	dec b
	jr nz, .ninLoop

Game:
	call loadGameTiles
	call loadGameText
	call setupGame

	ld hl, rBGP
	ld [hl], %11100100	; setup BG palette

	ld hl, rLCDC
	set 7, [hl]		; enable screen

.gameLoop
	jr .gameLoop

