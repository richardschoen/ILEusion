
BIN_LIB=ILEUSION
DBGVIEW=*ALL
MODS=$(BIN_LIB)/ACTIONS $(BIN_LIB)/DATA $(BIN_LIB)/CALLFUNC $(BIN_LIB)/TYPES

# ---------------

.ONESHELL:

all: clean $(BIN_LIB).lib ileusion.pgm cmds ileusion_s.srvpgm
	@echo "Build finished!"

%.lib:
	-system -q "CRTLIB $* TYPE(*PROD) TEXT('ILEusion')"

ileusion.pgm: ileusion.rpgle actions.rpgle data.rpgle callfunc.rpgle types.c ileusion.bnddir

ileusion_s.srvpgm: ileusion_s.rpgle actions.rpgle data.rpgle callfunc.rpgle types.c ileusion.bnddir

ileusion.bnddir: jsonxml.entry ileastic.entry

%.pgm:
	qsh <<EOF
	liblist -a NOXDB
	liblist -a ILEASTIC
	liblist -a $(BIN_LIB)
	system -i "CRTPGM PGM($(BIN_LIB)/$*) MODULE($(BIN_LIB)/$* $(MODS)) BNDDIR($(BIN_LIB)/ILEUSION)"
	EOF

%.srvpgm:
	qsh <<EOF
	liblist -a NOXDB
	liblist -a ILEASTIC
	liblist -a $(BIN_LIB)
	system -i "CRTSRVPGM SRVPGM($(BIN_LIB)/$*) MODULE($(BIN_LIB)/$* $(MODS)) EXPORT(*ALL) ACTGRP(*CALLER) BNDDIR($(BIN_LIB)/ILEUSION)"
	EOF

cmds:
	qsh <<EOF
	liblist -a $(BIN_LIB)
	
	-system -q "CRTSRCPF FILE($(BIN_LIB)/QSRC) RCDLEN(112)"
	system "CPYFRMSTMF FROMSTMF('./src/strilesrv.clle') TOMBR('/QSYS.lib/$(BIN_LIB).lib/QSRC.file/STRILESRV.mbr') MBROPT(*replace)"
	system "CPYFRMSTMF FROMSTMF('./src/strilesrv.cmd') TOMBR('/QSYS.lib/$(BIN_LIB).lib/QSRC.file/STRILESRVC.mbr') MBROPT(*replace)"
	
	system "CRTBNDCL PGM($(BIN_LIB)/STRILESRV) SRCFILE($(BIN_LIB)/QSRC) DBGVIEW($(DBGVIEW))"
	system "CRTCMD CMD($(BIN_LIB)/STRILESRV) PGM($(BIN_LIB)/STRILESRV) SRCFILE($(BIN_LIB)/QSRC) SRCMBR(STRILESRVC)"
	EOF

%.rpgle:
	system -q "CRTRPGMOD MODULE($(BIN_LIB)/$*) SRCSTMF('./src/$*.rpgle') DBGVIEW($(DBGVIEW)) REPLACE(*YES)" | grep '*RNF' | grep -v '*RNF7031' | sed  "s!*!$@: &!"
	
%.c:
	system "CRTCMOD MODULE($(BIN_LIB)/$*) SRCSTMF('./src/$*.c') DBGVIEW($(DBGVIEW)) REPLACE(*YES)"

%.bnddir:
	-system -qi "CRTBNDDIR BNDDIR($(BIN_LIB)/$*)"
	-system -qi "ADDBNDDIRE BNDDIR($(BIN_LIB)/$*) OBJ($(patsubst %.entry,(*LIBL/% *SRVPGM *IMMED),$^))"

%.entry:
	# Basically do nothing..
	@echo "Adding binding entry $*"

clean:
	-system -qi "DLTOBJ OBJ($(BIN_LIB)/*ALL) OBJTYPE(*FILE)"
	-system -qi "DLTOBJ OBJ($(BIN_LIB)/*ALL) OBJTYPE(*MODULE)"
	
release: clean
	@echo " -- Creating ILEusion release. --"
	@echo " -- Copying service programs deps. --"
	system "CRTDUPOBJ OBJ(ILEASTIC) FROMLIB(ILEASTIC) OBJTYPE(*SRVPGM) TOLIB($(BIN_LIB))"
	system "CRTDUPOBJ OBJ(JSONXML) FROMLIB(NOXDB) OBJTYPE(*SRVPGM) TOLIB($(BIN_LIB))"
	@echo " -- Creating save file. --"
	system "CRTSAVF FILE($(BIN_LIB)/RELEASE)"
	system "SAVLIB LIB($(BIN_LIB)) DEV(*SAVF) SAVF($(BIN_LIB)/RELEASE) OMITOBJ((RELEASE *FILE))"
	-rm -r release
	-mkdir release
	system "CPYTOSTMF FROMMBR('/QSYS.lib/$(BIN_LIB).lib/RELEASE.FILE') TOSTMF('./release/release.savf') STMFOPT(*REPLACE) STMFCCSID(1252) CVTDTA(*NONE)"
	@echo " -- Cleaning up... --"
	system "DLTOBJ OBJ($(BIN_LIB)/RELEASE) OBJTYPE(*FILE)"
	system "DLTOBJ OBJ($(BIN_LIB)/ILEASTIC) OBJTYPE(*SRVPGM)"
	system "DLTOBJ OBJ($(BIN_LIB)/JSONXML) OBJTYPE(*SRVPGM)"
	@echo " -- Release created! --"
	@echo ""
	@echo "To install the release, run:"
	@echo "  > CRTLIB $(BIN_LIB)"
	@echo "  > CPYFRMSTMF FROMSTMF('./release/release.savf') TOMBR('/QSYS.lib/$(BIN_LIB).lib/RELEASE.FILE') MBROPT(*REPLACE) CVTDTA(*NONE)"
	@echo "  > RSTLIB SAVLIB($(BIN_LIB)) DEV(*SAVF) SAVF($(BIN_LIB)/RELEASE)"
	@echo ""
