# Makefile for creating yatzy-gb
# Daniel G - MIT License

RGBASM	:= rgbasm
RGBLINK	:= rgblink
RGBFIX	:= rgbfix
MKDIR	:= mkdir

SRC	:= src
INC	:= inc
BIN	:= bin
RES	:= res

PROJ	:= yatzy
OUT	:= $(BIN)/$(PROJ)
EMU	:= bgb

# Find all the source files (.asm) below the src/ dir
# I don't know how portable this is
SRCFILE	:= $(shell find $(SRC) -type f -name '*.asm')
OBJFILE	:= $(patsubst $(SRC)/%.asm, $(BIN)/obj/%.o, $(SRCFILE))

.PHONY	: all clean fix run

all: fix

fix: $(OUT).gb
	$(RGBFIX) -jvp 0 \
	--title "YATZY" \
	--game-id "DG0 " \
	--old-licensee 51 \
	$(OUT).gb

$(OUT).map $(OUT).sym $(OUT).gb: $(OBJFILE)
	$(RGBLINK) --tiny --dmg \
	--map $(OUT).map \
	--sym $(OUT).sym \
	--output $(OUT).gb \
	$(OBJFILE)

$(BIN)/obj/%.o: $(SRC)/%.asm
	$(MKDIR) -p $(dir $@)
	$(RGBASM) -o $@ -i $(RES) -i $(INC) $<

clean:
	rm -r $(BIN)

run: all
	$(EMU) $(OUT).gb

