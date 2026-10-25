TESTNAME ?= normal
SEED ?= 1
RUN_ID ?= AUTO

.PHONY: comp run smoke regress rung

comp:
	vsim -c -do "do batch.do compile"

run:
	vsim -c -do "do batch.do $(TESTNAME) $(SEED) $(RUN_ID)"

smoke:
	$(MAKE) run TESTNAME=normal SEED=$(SEED) RUN_ID=$(RUN_ID)
	$(MAKE) run TESTNAME=length SEED=$(SEED) RUN_ID=$(RUN_ID)
	$(MAKE) run TESTNAME=timing SEED=$(SEED) RUN_ID=$(RUN_ID)
	@printf '[SMOKE_PASS] normal length timing seed=$(SEED)\n'

regress: smoke
	$(MAKE) run TESTNAME=type SEED=$(SEED) RUN_ID=$(RUN_ID)
	$(MAKE) run TESTNAME=checksum SEED=$(SEED) RUN_ID=$(RUN_ID)
	$(MAKE) run TESTNAME=extension SEED=$(SEED) RUN_ID=$(RUN_ID)
	@printf '[REGRESS_PASS] 6/6 tests seed=$(SEED)\n'

rung:
	vsim -do "do run.do $(TESTNAME) $(SEED) $(RUN_ID)"
