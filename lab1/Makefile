# 在 try/lab1 运行。smoke 为必做，regress 包含原有用例及本次 IRQ 同周期检查。
TEST ?= smoke
SEED ?= 1
ifeq ($(origin RUN_ID), undefined)
RUN_ID := $(shell date +%Y%m%d_%H%M%S_%N)
endif

.PHONY: comp run smoke regress rung

comp:
	@mkdir -p logs/$(RUN_ID)
	@test ! -e logs/$(RUN_ID)/compile_console.log
	vsim -c -l logs/$(RUN_ID)/compile_console.log -do "do batch.do compile $(SEED) $(RUN_ID)"

run:
	@mkdir -p logs/$(RUN_ID)
	@test ! -e logs/$(RUN_ID)/$(TEST)_$(SEED)_console.log
	vsim -c -l logs/$(RUN_ID)/$(TEST)_$(SEED)_console.log -do "do batch.do $(TEST) $(SEED) $(RUN_ID)"

smoke:
	$(MAKE) run TEST=smoke SEED=$(SEED) RUN_ID=$(RUN_ID)

regress:
	$(MAKE) run TEST=regress SEED=1 RUN_ID=$(RUN_ID)
	$(MAKE) run TEST=regress SEED=123 RUN_ID=$(RUN_ID)
	$(MAKE) run TEST=regress SEED=2026 RUN_ID=$(RUN_ID)

rung:
	@mkdir -p logs/$(RUN_ID)
	@test ! -e logs/$(RUN_ID)/$(TEST)_$(SEED)_console.log
	vsim -l logs/$(RUN_ID)/$(TEST)_$(SEED)_console.log -do "do run.do $(TEST) $(SEED) $(RUN_ID)"
