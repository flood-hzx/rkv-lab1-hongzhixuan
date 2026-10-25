# Run from this directory, or use make -C try/lab4.
TESTNAME ?= smoke
SEED     ?= 1
# COVSET keeps baseline and final data/reports isolated. Override TESTS to run a targeted subset.
COVSET   ?= final
ifeq ($(COVSET),baseline)
DEFAULT_TESTS := smoke frames status busy irq errors csr memory random extension
else ifeq ($(COVSET),final)
DEFAULT_TESTS := smoke frames status busy irq errors csr memory random extension coverage closure
else
$(error COVSET must be baseline or final)
endif
TESTS    ?= $(DEFAULT_TESTS)
SEEDS    ?= 1
RUN_ID   ?= AUTO
MERGE_ID ?= AUTO
COVDB    ?=

.PHONY: compile comp run smoke regress rung cov mergecov verdicov

compile comp:
	vsim -c -do "do batch.do compile"

run:
	vsim -c -do "do batch.do $(TESTNAME) $(SEED) $(RUN_ID) $(if $(filter 1 yes true,$(COVERAGE)),coverage,normal) $(COVSET)"

smoke:
	vsim -c -do "do batch.do smoke $(SEED) $(RUN_ID) normal $(COVSET)"

regress:
	@set -e; \
	for testname in $(TESTS); do \
	  for seed in $(SEEDS); do \
	    if [ "$(RUN_ID)" = "AUTO" ]; then run_id=AUTO; else run_id="$(RUN_ID)_$(COVSET)_$${testname}_$${seed}"; fi; \
	    vsim -c -do "do batch.do $$testname $$seed $$run_id normal $(COVSET)"; \
	  done; \
	done

rung:
	vsim -do "do run.do $(TESTNAME) $(SEED) $(RUN_ID) $(if $(filter 1 yes true,$(COVERAGE)),coverage,normal) $(COVSET)"

cov:
	@set -e; \
	for testname in $(TESTS); do \
	  for seed in $(SEEDS); do \
	    if [ "$(RUN_ID)" = "AUTO" ]; then run_id=AUTO; else run_id="$(RUN_ID)_$(COVSET)_$${testname}_$${seed}"; fi; \
	    vsim -c -do "do batch.do $$testname $$seed $$run_id coverage $(COVSET)"; \
	  done; \
	done

COV_INPUTS = $(wildcard coverage/$(COVSET)/*/*.ucdb)

mergecov:
	@if [ -z "$(strip $(COV_INPUTS))" ]; then echo "No per-run UCDBs in coverage/$(COVSET)"; exit 1; fi; \
	vsim -c -viewcov "$(firstword $(COV_INPUTS))" -do "do mergecov.do $(COVSET) $(MERGE_ID)"

verdicov:
	@if [ -n "$(COVDB)" ]; then \
	  vsim -viewcov "$(COVDB)"; \
	else \
	  latest=$$(ls -t coverage/merged_$(COVSET)_*/merged_filtered.ucdb 2>/dev/null | head -n 1); \
	  if [ ! -f "$$latest" ]; then echo "Set COVDB=coverage/merged_$(COVSET)_RUN_ID/merged_raw.ucdb or merged_filtered.ucdb, or run make mergecov COVSET=$(COVSET) first"; exit 1; fi; \
	  vsim -viewcov "$$latest"; \
	fi
