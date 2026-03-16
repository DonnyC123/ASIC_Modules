TB_DIRS = sqrt_uint64_tb mac_float_16_tb divider_float_16_tb

.PHONY: all clean $(TB_DIRS)

all: $(TB_DIRS)
	@echo "All testbenches completed."

$(TB_DIRS):
	@echo "================================================="
	@echo " Running Make in $@"
	@echo "================================================="
	$(MAKE) -C $@ sim

clean:
	@for dir in $(TB_DIRS); do \
		echo "Cleaning $$dir..."; \
		$(MAKE) -C $$dir clean; \
	done
