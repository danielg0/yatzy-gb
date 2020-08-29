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

SRCFILE	:= $(shell find $(SRC) -type f -name '*.asm')
OBJFILE	:= $(patsubst $(SRC)/%.asm, $(BIN)/obj/%.o, $(SRCFILE))

.PHONY	: all clean fix run

all: fix

fix: $(OUT).gb
	$(RGBFIX) -vp 0 $(OUT).gb

$(OUT).map $(OUT).sym $(OUT).gb: $(OBJFILE)
	$(RGBLINK) -m $(OUT).map \
	-n $(OUT).sym \
	-o $(OUT).gb \
	$(OBJFILE)

$(BIN)/obj/%.o: $(SRC)/%.asm
	$(MKDIR) -p $(dir $@)
	$(RGBASM) -o $@ -i $(RES) -i $(INC) $<

clean:
	rm -r $(BIN)

run: all
	$(EMU) $(OUT).gb

