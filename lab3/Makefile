# Run from this directory, or use make -C try/lab3.
TESTNAME ?= smoke
SEED     ?= 1
TESTS    ?= smoke frames status busy irq random extension
SEEDS    ?= 1
RUN_ID   ?= AUTO

.PHONY: compile comp run smoke regress rung

compile comp:
	vsim -c -do "do batch.do compile"

run:
	vsim -c -do "do batch.do $(TESTNAME) $(SEED) $(RUN_ID)"

smoke:
	vsim -c -do "do batch.do smoke $(SEED) $(RUN_ID)"

regress:
	@set -e; \
	for testname in $(TESTS); do \
	  for seed in $(SEEDS); do \
	    if [ "$(RUN_ID)" = "AUTO" ]; then run_id=AUTO; else run_id="$(RUN_ID)_$${testname}_$${seed}"; fi; \
	    vsim -c -do "do batch.do $$testname $$seed $$run_id"; \
	  done; \
	done

rung:
	vsim -do "do run.do $(TESTNAME) $(SEED) $(RUN_ID)"
