.PHONY: all help linux windows web clean serve
.NOTPARALLEL: linux windows web

PLATFORM_TARGETS := all help linux windows web clean serve
REQUESTED_PLATFORMS := $(filter $(PLATFORM_TARGETS),$(MAKECMDGOALS))
ifneq ($(word 2,$(REQUESTED_PLATFORMS)),)
$(error Cannot build multiple targets in one invocation. Build sequentially instead: `make clean && make -j$$(nproc) linux && make -j$$(nproc) web`)
endif

D_SRC := src

STD := -std=c99
WARNINGS := -Wall -Wextra -Werror -Wshadow -Wnon-virtual-dtor -Wold-style-cast
INCLUDES := -Iinclude
SOURCES := $(wildcard $(D_SRC)/*.c)
EXE_NAME := main

RL_SRC := external/raylib/src
RL_VERSION := $(shell git -C external/raylib describe --tags --abbrev=0 2>/dev/null || echo "5.0")
RL_LIB_NAME := libraylib.a

LINUX_CC := clang
LINUX_CFLAGS_DEBUG := $(STD) $(WARNINGS) $(INCLUDES)
LINUX_CFLAGS_RELEASE := $(STD) $(WARNINGS) $(INCLUDES) -DNDEBUG -Os
LINUX_LINK_FLAGS := -Llib/linux -lraylib -lm -ldl -lpthread -lGL

WINDOWS_CC := gcc
WINDOWS_CFLAGS_DEBUG := $(STD) $(WARNINGS) $(INCLUDES)
WINDOWS_CFLAGS_RELEASE := $(STD) $(WARNINGS) $(INCLUDES) -DNDEBUG -Os
WINDOWS_LINK_FLAGS := -Llib/windows -lraylib -lopengl32 -lgdi32 -lwinmm

WEB_CC := emcc
WEB_CFLAGS_DEBUG := $(STD) $(WARNINGS) $(INCLUDES) -DPLATFORM_WEB
WEB_CFLAGS_RELEASE := $(STD) $(WARNINGS) $(INCLUDES) -DPLATFORM_WEB -DNDEBUG -Os
WEB_PRELOAD_ASSETS := $(shell find res -type f 2>/dev/null | xargs -I{} echo --preload-file {})
WEB_LINK_FLAGS := lib/web/libraylib.web.a \
                  -s USE_GLFW=3 -s ASYNCIFY -s ALLOW_MEMORY_GROWTH=1 \
                  -s FORCE_FILESYSTEM=1 $(WEB_PRELOAD_ASSETS) \
                  --shell-file web/shell.html

all: help

help:
	@echo "Available targets:"
	@echo "  make linux   - Build for Linux (debug and release)"
	@echo "  make windows - Build for Windows (debug and release)"
	@echo "  make web     - Build for Web (debug and release)"
	@echo "  make clean   - Remove the 'build/' directory"
	@echo "  make serve   - Serve web release build on port 8080"

linux: lib/linux/libraylib.a build/linux/debug/$(EXE_NAME) build/linux/release/$(EXE_NAME) 

windows: lib/windows/libraylib.a build/windows/debug/$(EXE_NAME).exe build/windows/release/$(EXE_NAME).exe

web: lib/web/libraylib.web.a build/web/debug/index.html build/web/release/index.html 

build/linux/debug/%.o: $(D_SRC)/%.c | build/linux/debug
	$(LINUX_CC) $(LINUX_CFLAGS_DEBUG) -c $< -o $@

build/linux/debug/$(EXE_NAME): $(patsubst $(D_SRC)/%.c,build/linux/debug/%.o,$(SOURCES))
	$(LINUX_CC) $(filter %.o,$^) $(LINUX_LINK_FLAGS) -o $@

build/linux/release/%.o: $(D_SRC)/%.c | build/linux/release
	$(LINUX_CC) $(LINUX_CFLAGS_RELEASE) -c $< -o $@

build/linux/release/$(EXE_NAME): $(patsubst $(D_SRC)/%.c,build/linux/release/%.o,$(SOURCES))
	$(LINUX_CC) $(filter %.o,$^) $(LINUX_LINK_FLAGS) -o $@

build/windows/debug/%.o: $(D_SRC)/%.c | build/windows/debug
	$(WINDOWS_CC) $(WINDOWS_CFLAGS_DEBUG) -c $< -o $@

build/windows/debug/$(EXE_NAME).exe: $(patsubst $(D_SRC)/%.c,build/windows/debug/%.o,$(SOURCES))
	$(WINDOWS_CC) $(filter %.o,$^) $(WINDOWS_LINK_FLAGS) -o $@

build/windows/release/%.o: $(D_SRC)/%.c | build/windows/release
	$(WINDOWS_CC) $(WINDOWS_CFLAGS_RELEASE) -c $< -o $@

build/windows/release/$(EXE_NAME).exe: $(patsubst $(D_SRC)/%.c,build/windows/release/%.o,$(SOURCES))
	$(WINDOWS_CC) $(filter %.o,$^) $(WINDOWS_LINK_FLAGS) -o $@

build/web/debug/%.o: $(D_SRC)/%.c | build/web/debug
	$(WEB_CC) $(WEB_CFLAGS_DEBUG) -c $< -o $@

build/web/debug/index.html: $(patsubst $(D_SRC)/%.c,build/web/debug/%.o,$(SOURCES))
	$(WEB_CC) $^ $(WEB_LINK_FLAGS) -o $@

build/web/release/%.o: $(D_SRC)/%.c | build/web/release
	$(WEB_CC) $(WEB_CFLAGS_RELEASE) -c $< -o $@

build/web/release/index.html: $(patsubst $(D_SRC)/%.c,build/web/release/%.o,$(SOURCES))
	$(WEB_CC) $^ $(WEB_LINK_FLAGS) -o $@

lib/linux/libraylib.a: | lib/linux
	@echo "Building raylib $(RL_VERSION) for Linux..."
	@rm -f $(RL_SRC)/*.o
	@$(MAKE) -j$(shell nproc) -C $(RL_SRC) PLATFORM=PLATFORM_DESKTOP \
		GLFW_LINUX_ENABLE_WAYLAND=TRUE GLFW_LINUX_ENABLE_X11=TRUE \
		RAYLIB_LIBTYPE=STATIC >/dev/null 2>&1
	@mv $(RL_SRC)/libraylib.a $@

lib/windows/libraylib.a: | lib/windows
	@echo "Building raylib $(RL_VERSION) for Windows..."
	@rm -f $(RL_SRC)/*.o
	@$(MAKE) -j$(shell nproc) -C $(RL_SRC) PLATFORM=PLATFORM_DESKTOP CC=gcc \
		RAYLIB_LIBTYPE=STATIC >/dev/null 2>&1
	@mv $(RL_SRC)/libraylib.a $@

lib/web/libraylib.web.a: | lib/web
	@echo "Building raylib $(RL_VERSION) for Web..."
	@rm -f $(RL_SRC)/*.o
	@$(MAKE) -j$(shell nproc) -C $(RL_SRC) PLATFORM=PLATFORM_WEB CC=emcc AR=emar \
		RAYLIB_LIBTYPE=STATIC >/dev/null 2>&1
	@mv $(RL_SRC)/libraylib.web.a $@

build/linux/debug build/linux/release build/windows/debug build/windows/release build/web/debug build/web/release lib/linux lib/windows lib/web:
	mkdir -p $@

clean:
	rm -rf build

serve: build/web/release/index.html
	cd build/web/release && python -m http.server 8080
