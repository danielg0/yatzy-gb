INCLUDE "hardware.inc"

SECTION "Function Variables", WRAM0

; joypad variables
W_DPAD:: DS 1				; byte holding current state of dpad
W_BUTT:: DS 1				;    ""    current button press state
W_DPAD_OLD:: DS 1			;    ""    previous state of dpad
W_BUTT_OLD:: DS 1			;    ""    previous button press state

SECTION "Functions", ROM0

; Read joypad and write input to memory
; Credit to bitnenfer - I've made a change where the io registers are read
; repeatedly to create a delay and allow the inputs to stabilise (see pandocs)
ReadJoypad::
	; Read P14
	ld hl, rP1
	ld a, $20
	ld [hl], a
REPT 5
	ld a, [hl]
ENDR
	ld hl, W_DPAD
	ld b, [hl]
	ld [hl], a
	ld hl, W_DPAD_OLD
	ld [hl], b

	; Read P15
	ld hl, rP1
	ld a, $10
	ld [hl], a
REPT 5
	ld a, [hl]
ENDR
	ld hl, W_BUTT
	ld b, [hl]
	ld [hl], a
	ld hl, W_BUTT_OLD
	ld [hl], b

	; Reset
	ld hl, rP1
	ld a, $FF
	ld [hl], a
	ret

; Copy a slice of data from one point in memory to another
; @param de memory address of start of data to be copied
; @param bc size of the data to be copied
; @param hl where in memory to start copying data to
; @return de memory address of byte after last original byte
; @return hl memory address of byte after last copied byte
; @return bc zero
; @return a zero
; @return flags Z set C reset
Memcpy::
	ld a, [de]			; grab one byte of source
	ld [hli], a			; place in dest, incrementing hl at same time
	inc de				; move to next byte
	dec bc				; decrement count
	ld a, b				; check if count 0, as `dec bc` doesn't update flags
	or c
	jr nz, Memcpy			; if count not 0, copy more data
	ret

; Copy a nul-terminated string up to, but not including the NULL character
; @param de memory address of start of string
; @param hl memory address of destination
; @return de memory address of NULL character at end of original string
; @return hl memory address of byte after last copied byte
; @return a zero
; @return flags Z set C reset
Strcpy::
	ld a, [de]
	and a
	ret z
	ld [hli], a
	inc de
	jr Strcpy

; Halt until a vblank occurs
WaitVBlank::
	halt				; suspend cpu and wait for any 
	ret				; interrupt as a vblank is the only
					; interrupt that can occur

; write a bcd formatted value to address
; split into its seperate digits and add ascii number offset
; @param a number in bcd format
; @param hl address to start writing to
; @trashes b
BCDcpy::
	; remember - little endian encoding
	ld b, a
	and $F0
	swap a
	; if a 0, print space (ie. don't add offset)
	jr z, .zero
	; add offset to get into ASCII digits
	add $30
.zero
	ld [hli], a
	ld a, b
	and $0F
	add $30
	ld [hl], a
	ret

