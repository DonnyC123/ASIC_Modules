GENUS = genus

.PHONY: synth clean

synth:
	mkdir -p out
	$(GENUS) -batch -no_gui -files design.tcl -log out/genus.log

clean:
	rm -rf out/
