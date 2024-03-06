BUILD_DIR := build

build:
	zig build -p ${BUILD_DIR}

.PHONY: build
