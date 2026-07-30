# Decode-only libwebp (libwebpdecoder).
#
#   make build                         # native host → out/linux/ (or macos)
#   make build TARGET_PLATFORM=windows # cross from Linux (mingw)
#   make clean

ROOT     := $(abspath .)
SRC      := $(ROOT)/src
OUT      := $(ROOT)/out
SCRIPTS  := $(ROOT)/scripts

# libwebp release tag
WEBP_TAG ?= v1.5.0

TARGET_PLATFORM ?= $(shell uname -s | tr '[:upper:]' '[:lower:]' | sed 's/darwin/macos/')
ifeq ($(TARGET_PLATFORM),darwin)
  TARGET_PLATFORM := macos
endif

JOBS ?= $(shell nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

.PHONY: all build check-src fetch clean help

all: build

help:
	@echo "  make fetch                  # clone libwebp $(WEBP_TAG) into src/"
	@echo "  make build [TARGET_PLATFORM=linux|windows|macos|ios|android]"
	@echo "  WEBP_TAG=$(WEBP_TAG)"

fetch:
	@if [ -f $(SRC)/CMakeLists.txt ]; then \
		echo "src/ already present"; \
	else \
		git clone --depth 1 --branch $(WEBP_TAG) https://github.com/webmproject/libwebp.git $(SRC); \
	fi

check-src:
	@test -f $(SRC)/CMakeLists.txt || { \
		echo "Missing $(SRC)/CMakeLists.txt — run: make fetch"; \
		exit 1; \
	}

build: check-src
	TARGET_PLATFORM=$(TARGET_PLATFORM) JOBS=$(JOBS) $(SCRIPTS)/build.sh

clean:
	rm -rf $(OUT) $(ROOT)/build-*
