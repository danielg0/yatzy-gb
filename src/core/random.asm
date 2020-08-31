INCLUDE "hardware.inc"

SECTION "Random Variables", WRAM0

W_RNG: DS 2			; stores the last word of randomness generated

SECTION "Random", ROM0

; seed the rng value using unintialised RAM
; TODO: in future, when there is a menu present, this could be seeded by the
; clock time when the play presses the button to start the game
; @return a seed used (if 0, very likely running on an emulator)
; @return hl _RAM + 1
RNGSeed::
	ld hl, _RAM		; on real devices/accurate emulators, WRAM will
	ld a, [hli]		; be filled with random-ish trash on boot we can
	ld [W_RNG], a		; use to seed the rng
	ld a, [hl]
	ld [W_RNG + 1], a
	ret

; return a random byte of data
; note: do not call more than once in a row
; @return a random byte of data
; @return bc randow word of data where a equals c
; @return d value of rDIV when RNGByte called
RNGWord::
	ld a, [rDIV]		; get the current cpu clock time
	ld d, a

	ld a, [W_RNG]		; calc first byte of word
	xor d			; xor clock with previous rand byte, adding to
	ld b, a			; the randomness and ensuring some amount of
	ld [W_RNG], a		; randomness on unaccurate emulators

	ld a, [W_RNG + 1]	; calc and store second byte of word
	xor d
	ld c, a
	ld [W_RNG + 1], a

	ret

