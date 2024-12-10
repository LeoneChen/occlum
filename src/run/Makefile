include ../sgxenv.mk

KAFL_TARGET_DIR := /home/leone/kAFL/kafl/examples/
BIN := $(BUILD_DIR)/bin/occlum-run

C_SRCS := $(sort $(wildcard *.c)) $(KAFL_TARGET_DIR)/linux-user/libnyx_agent/src/nyx_agent.c
C_OBJS := $(addprefix $(OBJ_DIR)/run/,$(C_SRCS:.c=.o))
CXX_SRCS := $(sort $(wildcard *.cpp))
CXX_OBJS := $(addprefix $(OBJ_DIR)/run/,$(CXX_SRCS:.cpp=.o))

C_COMMON_FLAGS := -I$(PROJECT_DIR)/src/pal/include -I$(KAFL_TARGET_DIR) -I$(KAFL_TARGET_DIR)/linux-user/libnyx_agent/src
CXX_COMMON_FLAGS := $(C_COMMON_FLAGS)
C_FLAGS := $(C_COMMON_FLAGS) $(SGX_CFLAGS_U)
CXX_FLAGS := $(CXX_COMMON_FLAGS) $(SGX_CXXFLAGS_U) -std=c++17
LINK_FLAGS := $(SGX_COMMON_CFLAGS) -L$(SGX_LIBRARY_PATH) -L$(BUILD_DIR)/lib -lsgx_uprotected_fs -locclum-pal -lfmt

ALL_BUILD_SUBDIRS := $(sort $(patsubst %/,%,$(dir $(BIN) $(C_OBJS) $(CXX_OBJS))))

.PHONY: all format format-check clean

all: $(ALL_BUILD_SUBDIRS) $(BIN)

$(ALL_BUILD_SUBDIRS):
	@mkdir -p $@

$(BIN): $(C_OBJS) $(CXX_OBJS)
	@$(CXX) $^ -o $@ $(LINK_FLAGS)
	@echo "LINK => $@"

$(OBJ_DIR)/run/%.o: %.c
	@$(CC) $(C_FLAGS) -c $< -o $@
	@echo "CC <= $@"

$(OBJ_DIR)/run/%.o: %.cpp
	@$(CXX) $(CXX_FLAGS) -c $< -o $@
	@echo "CXX <= $@"

format: $(C_SRCS) $(CXX_SRCS)
	@$(C_FORMATTER) $^

format-check: $(C_SRCS) $(CXX_SRCS)
	@$(C_FORMATTER) --check $^

clean:
	@-$(RM) -f $(BIN) $(C_OBJS) $(CXX_OBJS)
