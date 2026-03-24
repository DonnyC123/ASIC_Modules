TB_DIRS    = uint64_sqrt float_mac float_divider
SYNTH_DIRS = uint64_sqrt float_mac float_divider float_sqrt

.PHONY: all synth clean $(TB_DIRS) $(SYNTH_DIRS:%=synth-%)

all: $(TB_DIRS)
	@echo "All testbenches completed."

$(TB_DIRS):
	@echo "================================================="
	@echo " Running Make in $@"
	@echo "================================================="
	$(MAKE) -C $@/tb run

# Run synthesis for all designs: make synth
synth: $(SYNTH_DIRS:%=synth-%)

synth-interactive:
	mkdir -p out
	$(GENUS) -no_gui -files design.tcl -log out/genus.log




# Run synthesis for one design: make synth-float_sqrt
$(SYNTH_DIRS:%=synth-%):
	@echo "================================================="
	@echo " Synthesizing $(@:synth-%=%)"
	@echo "================================================="
	$(MAKE) -C $(@:synth-%=%)/synth synth

clean:
	@for dir in $(TB_DIRS); do \
		echo "Cleaning $$dir..."; \
		$(MAKE) -C $$dir/tb clean; \
	done
	@for dir in $(SYNTH_DIRS); do \
		echo "Cleaning synth $$dir..."; \
		$(MAKE) -C $$dir/synth clean; \
	done
