; Macros

; AT(X, Y)
; load into hl the VRAM address for a given position on _SCRN0
AT: MACRO
	ld hl, _SCRN0 + (SCRN_VY_B * \2) + \1
ENDM

; DW_AT(X, Y)
; allocates a word holding the VRAM location for a given position on _SCRN0
DW_AT: MACRO
	DW _SCRN0 + (SCRN_VY_B * \2) + \1
ENDM

