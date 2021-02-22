INCLUDE "hardware.inc"

; TODO: move frequently used functions to RST bank

SECTION "RST Vectors", ROM0[$00]

	DS $40 - @

SECTION "Interrup Vectors", ROM0[$40]

; VBlank handler
	reti
	DS $48 - @

; STAT handler
	reti
	DS $50 - @

; timer handler
	reti
	DS $58 - @

; serial handler
	reti
	DS $60 - @

; joypad handler
	reti

; fill up to entry point
	DS $100 - @, 0

