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
	jr Setup

