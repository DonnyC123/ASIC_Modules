GENUS = genus

.PHONY: synth synth-mixed clean

synth:
	mkdir -p out
	$(GENUS) -batch -no_gui -files design.tcl -log out/genus.log

synth-mixed:
	mkdir -p out_mixed
	$(GENUS) -batch -no_gui -files design_mixed.tcl -log out_mixed/genus.log

clean:
	rm -rf out/ out_mixed/
