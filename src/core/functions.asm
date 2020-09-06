INCLUDE "hardware.inc"

SECTION "Functions", ROM0

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
	ld a, [de]		; grab one byte of source
	ld [hli], a		; place in dest, incrementing hl at same time
	inc de			; move to next byte
	dec bc			; decrement count
	ld a, b			; check if count 0, as `dec bc` doesn't update flags
	or c
	jr nz, Memcpy		; if count not 0, copy more data
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

; Hang until a vblank occurs
; TODO: Rewrite this using HALT instruction
; @return a 144
; @return flags Z reset C set
WaitVBlank::
	ld a, [rLY]		; Wait until rLY == 144 (start of vblank period)
	cp 144
	jr c, WaitVBlank	; Else, loop
	ret

; write a bcd formatted value to address
; split into its seperate digits and add an offset
; @param a number in bcd format
; @param hl address to start writing to
; @param b offset to add to digit
BCPcpy::
	; remember - little endian encoding
	ld c, a
	and $F0
	swap a
	add b
	ld [hli], a
	ld a, c
	and $0F
	add b
	ld [hl], a
	ret

