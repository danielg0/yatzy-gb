INCLUDE "hardware.inc"

SECTION "Header", ROM0[$100]

EntryPoint:
	di			; disable interrupts
	jp Setup

	DS $150 - @, 0		; fill header with zeros, rgbfix will handle it

SECTION "Main", ROM0

Setup:
	; clear WRAM variables
	; etc.

Game:
	call WaitVBlank		; wait for VBlank before disabling screen in
				; in order to load in tiles
	ld hl, rLCDC
	res 7, [hl]		; disable screen

	call loadGameTiles
	call setupGame

	ld hl, rBGP
	ld [hl], %11100100	; setup BG palette

	ld hl, rLCDC
	set 7, [hl]		; enable screen

.gameLoop
	jr .gameLoop

