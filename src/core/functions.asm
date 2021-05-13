INCLUDE "hardware.inc"

SECTION "Function Variables", WRAM0

; joypad variables
W_DPAD:: DS 1				; byte holding current state of dpad
W_BUTT:: DS 1				;    ""    current button press state
W_DPAD_OLD:: DS 1			;    ""    previous state of dpad
W_BUTT_OLD:: DS 1			;    ""    previous button press state

; highscore
W_HIGHSCORE:: DS 2			; two bytes holding highscore as bcd
					; low byte (tens and units) first

SECTION "Functions", ROM0

; Read highscore variable from external RAM
; in ram, highscore is ordered with the lower nibbles first
; ie. tens, units, thousands, hundreds
; in external ram, the values are also in this order, but each nibble is in its
; own byte, located in the 4 low bits (in order to have compatibility with MBC2)
; of the first 4 bytes from $A000 onward
ReadHighscore::
	ld hl, _SRAM
	ld de, W_HIGHSCORE

	; enable ram
	ld a, $0A
	ld [rRAMG], a

	; read in score from external RAM
	; as doing so, check that what is read is valid. As max score is 374,
	; the thousands digit must be 0, the hundreds less than 4, and the next
	; two must be less than 9 as the highscore is stored as a BCD

	; read first byte highscore from low nibble of RAM
	ld a, [hli]
	and $0F				; only read low nibble
	cp 10
	jr nc, .invalid			; tens digit must be less than 10
	swap a
	ld b, a
	ld a, [hli]
	and $0F
	cp 10				; units digit must be less than 10
	jr nc, .invalid
	or a, b
	ld [de], a

	; first byte written, prepare to write to second byte of W_HIGHSCORE
	inc de

	ld a, [hli]
	and $0F
	jr nz, .invalid			; thousands digit must be 0
	swap a
	ld b, a				; save a
	ld a, [hl]			; no need to increment
	and $0F
	cp 4
	jr nc, .invalid			; hundreds digit must be less than 4
	or a, b				; combine with first read nibble
	ld [de], a

	; disable ram
	xor a				; ld a, $00
	ld [rRAMG], a

	ret

.invalid
	; if saved highscore is invalid, save a score of zero
	ld hl, W_HIGHSCORE
	xor a				; ld a, $00
	ld [hli], a
	ld [hl], a

	; call WriteHighscore (RAM already enabled)
	jr WriteHighscore.noEnableRAM

; Write highscore variable to external RAM
WriteHighscore::
	; enable ram
	ld a, $0A
	ld [rRAMG], a

.noEnableRAM
	ld hl, _SRAM
	ld de, W_HIGHSCORE

	ld a, [de]
	and $F0
	swap a
	ld [hli], a
	ld a, [de]
	and $0F
	ld [hli], a

	inc de

	ld a, [de]
	and $F0
	swap a
	ld [hli], a
	ld a, [de]
	and $0F
	ld [hl], a			; no need for increment

	; disable ram
	ld a, $0A
	ld [rRAMG], a

	ret

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

