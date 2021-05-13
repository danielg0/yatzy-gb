# Makefile for creating yatzy-gb
# Daniel G - MIT License

# Set a custom emulator command
# Path of ROM will be appended to command
EMU	:= sameboy

# Set a custom seed for the rng
# -1 for a random seed
RNG	:= -1

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

# Find all the source files (.asm) below the src/ dir
# I don't know how portable this is
SRCFILE	:= $(shell find $(SRC) -type f -name '*.asm')
OBJFILE	:= $(patsubst $(SRC)/%.asm, $(BIN)/obj/%.o, $(SRCFILE))

.PHONY	: all clean fix run

all: fix

fix: $(OUT).gb
	$(RGBFIX) -jvc \
	--title "YATZY" \
	--game-id "DG0 " \
	--old-licensee 51 \
	--pad-value 0xff \
	--mbc-type "MBC1+RAM+BATTERY" \
	--ram-size 0x02 \
	$(OUT).gb

$(OUT).map $(OUT).sym $(OUT).gb: $(OBJFILE)
	$(RGBLINK) --tiny --dmg \
	--map $(OUT).map \
	--sym $(OUT).sym \
	--output $(OUT).gb \
	--pad 0xff \
	$(OBJFILE)

$(BIN)/obj/%.o: $(SRC)/%.asm
	$(MKDIR) -p $(dir $@)
	$(RGBASM) -o $@ -i $(RES) -i $(INC) -D RNG=$(RNG) $<

clean:
	rm -r $(BIN)

run: all
	$(EMU) $(OUT).gb

