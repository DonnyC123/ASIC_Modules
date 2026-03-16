TB_DIRS = uint64_sqrt mac_float divider_float

.PHONY: all clean $(TB_DIRS)

all: $(TB_DIRS)
	@echo "All testbenches completed."

$(TB_DIRS):
	@echo "================================================="
	@echo " Running Make in $@"
	@echo "================================================="
	$(MAKE) -C $@ run

clean:
	@for dir in $(TB_DIRS); do \
		echo "Cleaning $$dir..."; \
		$(MAKE) -C $$dir clean; \
	done
