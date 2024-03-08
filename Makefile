BUILD_DIR := build

build:
	zig build -p ${BUILD_DIR}

build_test: $(file)
	mkdir -p ${BUILD_DIR}/test
	zig test --test-no-exec -femit-bin=${BUILD_DIR}/test/$(notdir $(basename $(file))) $(file)

.PHONY: build
