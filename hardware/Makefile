###############################################################################
#                                                                             #
#                  General Makefile for Xilinx FPGA Design                    #
#           Copyright (C) 2014 Grant Ayers <ayers@cs.stanford.edu>            #
#                                                                             #
# This file is free software distributed under the BSD license. See LICENSE   #
# for more information.                                                       #
#                                                                             #
# This Makefile allows synthesis, simulation, and implementation of Xilinx    #
# FPGA projects from the command line. Its aim is to automatically handle     #
# dependencies and require as few configuration files as possible.            #
#                                                                             #
# Typical Usage:                                                              #
#   make hw   : Synthesize and implement the design                           #
#                                                                             #
# All Targets:                                                                #
#   all:        Build all hardware and simulation files. Don't run the tests. #
#   hw:         Same as 'all'.                                                #
#   cores:      Build the project core IPs using CORE Generator.              #
#   synthesize: Synthesize the design with XST.                               #
#   translate:  Translate a synthesized design using ngdbuild.                #
#   map:        Map a translated design to a device using map.                #
#   par:        Place-and-route a mapped design.                              #
#   trace:      Generate static timing information.                           #
#   bitgen:     Generate an FPGA programming file using bitgen.               #
#   clean:      Cleanup.                                                      #
#                                                                             #
# By default, Xilinx tool output is not shown. You can change this with       #
# the VERBOSE environment variable. For example:                              #
#   > make VERBOSE=yes all                                                    #
#                                                                             #
# All generated files are placed in a build folder. The source folder remains #
# untouched.                                                                  #
#                                                                             #
# Requirements:                                                               #
#   - GNU make, bash, unix-like environment, basic utilities (grep, sed,      #
#     awk, etc.) and python for the testbenches.                              #
#   - Xilinx tools must be in your path (refer to Xilinx documentation).      #
#                                                                             #
###############################################################################


#---------- Device Selection ----------#
DEVICE           := xc6slx45t
SPEED            := 3
PACKAGE          := fgg484

#---------- Basic settings ----------#
PROJECT_TOP      := MIPS32
SRC_DIR          := src
CFG_DIR          := config
BUILD_DIR        := build
VERBOSE          ?= No

#---------- Source file names/types ----------#
VLOG_EXT         := .v
VHDL_EXT         := .vhdl
UCF_EXT          := .ucf
CORE_CFG_EXT     := .xcp
CORE_PRJ_EXT     := .cgp
CORE_OUT_EXT     := .xco
CORE_SRC_OUT     := src_out.lst
SIM_GLBL_V       := $(XILINX)/verilog/src/glbl.v

#---------- Hardware settings ----------#
SRCLIST_SYN      := sources_syn.lst
XST_CFG          := settings.xst
MAP_CFG          := settings.map
BIT_CFG          := settings.ut


#---------- No need to modify below ----------#


#### Call helper functions ####

# Search for the first instance of a program in PATH
pathsearch = $(firstword $(wildcard $(addsuffix /$(1),$(subst :, ,$(PATH)))))

# Given a filename containing a list of sources (1), return only the specified type (2)
src_filter = $(shell grep -v -e '^\ *\#' -e '^$$' < $(1) | grep '$(2)$$')

# Given the name of a core project (.xco) file, return a list of its generated source files
core_srcs  = $(foreach FILE,$(1),$(shell sed -e 's|^|$(dir $(1))|' < $(dir $(1))$(CORE_SRC_OUT)))


#### Precomputed variables for hardware generation ####

SHELL              := $(call pathsearch,bash)
PART               := $(DEVICE)-$(SPEED)-$(PACKAGE)
BUILD_DIR_PART     := $(BUILD_DIR)/$(PART)
SRCLIST_SYN_PART   := $(CFG_DIR)/$(PART)/$(SRCLIST_SYN)
SRCS_SYN_VLOG      := $(call src_filter,$(SRCLIST_SYN_PART),$(VLOG_EXT))
SRCS_SYN_VHDL      := $(call src_filter,$(SRCLIST_SYN_PART),$(VHDL_EXT))
SRCS_SYN_UCF       := $(call src_filter,$(SRCLIST_SYN_PART),$(UCF_EXT))
SRCS_SYN_CORE_SRC  := $(call src_filter,$(SRCLIST_SYN_PART),$(CORE_OUT_EXT))
SRCS_SYN_CORE_BLD  := $(addprefix $(BUILD_DIR_PART)/,$(SRCS_SYN_CORE_SRC))
SRCS_SYN_CORE_GEN  := $(addprefix $(BUILD_DIR_PART)/,$(foreach SRC,$(SRCS_SYN_CORE_SRC),$(call core_srcs,$(SRC))))
SRCS_SYN_HDL       := $(SRCS_SYN_VLOG) $(SRCS_SYN_VHDL)
SRCS_ALL_CORE      := $(SRCS_SYN_CORE_BLD) $(SRCS_ALL_CORE)
PRJ_FILE           := $(BUILD_DIR_PART)/$(PROJECT_TOP).prj
XST_TARGET         := $(BUILD_DIR_PART)/xst/$(PROJECT_TOP).ngc
XST_CFG_PART       := $(CFG_DIR)/$(PART)/$(XST_CFG)
TRANS_TARGET       := $(BUILD_DIR_PART)/translate/$(PROJECT_TOP).ngd
MAP_TARGET         := $(BUILD_DIR_PART)/map/$(PROJECT_TOP).ncd
MAP_SETTINGS       := $(shell cat $(CFG_DIR)/$(PART)/$(MAP_CFG))
MAP_PCF            := $(BUILD_DIR_PART)/map/$(PROJECT_TOP).pcf
PAR_TARGET         := $(BUILD_DIR_PART)/par/$(PROJECT_TOP).ncd
TRACE_TARGET       := $(BUILD_DIR_PART)/trace/$(PROJECT_TOP).twr
BITGEN_TARGET      := $(BUILD_DIR_PART)/bitgen/$(PROJECT_TOP).bit
BITGEN_CFG_PART    := $(CFG_DIR)/$(PART)/$(BIT_CFG)


ifeq ($(VERBOSE),No)
    REDIR          := > /dev/null 2>&1
else
    REDIR          :=
endif


.PHONY: all
all: hw

.PHONY: hw
hw: trace bitgen

$(BUILD_DIR_PART):
	@mkdir -p $@

#### Create a synthesis project file ####

.PHONY: prj
prj: $(PRJ_FILE)

$(PRJ_FILE): $(SRCLIST_SYN_PART) $(SRCS_SYN_CORE_BLD) $(SRCS_SYN_HDL) | $(BUILD_DIR_PART)
	@echo '[PRJ]         $@'
	@rm -f $(PRJ_FILE)
	@grep -v -e '^\ *\#' -e '^$$' < $(SRCLIST_SYN_PART) | grep '.$(VLOG_EXT)$$' | awk '{print "verilog work \"" $$0 "\""}' > $(PRJ_FILE)
	@grep -v -e '^\ *\#' -e '^$$' < $(SRCLIST_SYN_PART) | grep '.$(VHDL_EXT)$$' | awk '{print "verilog work \"" $$0 "\""}' >> $(PRJ_FILE)
	@echo '$(SRCS_SYN_CORE_GEN)' | tr ' ' '\n' | grep '.$(VLOG_EXT)$$' | awk '{print "verilog work \"" $$0 "\""}' >> $(PRJ_FILE)
	@echo '$(SRCS_SYN_CORE_GEN)' | tr ' ' '\n' | grep '.$(VHDL_EXT)$$' | awk '{print "vhdl work \"" $$0 "\""}' >> $(PRJ_FILE)


#### Build Xilinx cores using coregen ####

.PHONY: cores
cores: $(SRCS_ALL_CORE)

$(SRCS_ALL_CORE): $(BUILD_DIR_PART)/%$(CORE_OUT_EXT) : | check-env
	@echo '[COREGEN]     $@'
	@rm -rf '$(dir $@)*'
	@mkdir -p '$(dir $@)'
	@cp -R $(dir $*)* $(dir $@)
	@cd $(dir $@) && coregen -intstyle silent -b $(notdir $*)$(CORE_CFG_EXT) -p $(notdir $*)$(CORE_PRJ_EXT) $(REDIR)


#### Synthesize using XST ####

.PHONY: synthesize
synthesize: $(XST_TARGET)

$(XST_TARGET): $(PRJ_FILE) $(XST_CFG_PART) | check-env
	@echo '[XST]         $@'
	@rm -rf $(dir $@)
	@mkdir -p $(dir $@)
	@ln -s $(abspath $(SRC_DIR)) $(dir $@)
	@ln -s $(abspath $(BUILD_DIR)) $(dir $@)
	@cp $(XST_CFG_PART) $(dir $@)
	@sed -i 's|AUTO_TMPDIR|.|' $(dir $@)$(notdir $(XST_CFG_PART))
	@sed -i 's|AUTO_XSTHDPDIR|.|' $(dir $@)$(notdir $(XST_CFG_PART))
	@sed -i 's|AUTO_PRJ|$(abspath $(PRJ_FILE))|' $(dir $@)$(notdir $(XST_CFG_PART))
	@sed -i 's|AUTO_PART|$(PART)|' $(dir $@)$(notdir $(XST_CFG_PART))
	@sed -i 's|AUTO_TOP|$(PROJECT_TOP)|' $(dir $@)$(notdir $(XST_CFG_PART))
	@sed -i 's|AUTO_COREDIRS|$(patsubst %,\"%\",$(dir $(SRCS_SYN_CORE_BLD))))|' $(dir $@)$(notdir $(XST_CFG_PART))
	@cd $(dir $@) && xst -ifn $(abspath $(dir $@)$(notdir $(XST_CFG_PART))) -ofn $(PROJECT_TOP).syr $(REDIR)


#### Translate using ngdbuild ####

.PHONY: translate
translate: $(TRANS_TARGET)

$(TRANS_TARGET): $(XST_TARGET) | check-env
	@echo '[TRANSLATE]   $@'
	@rm -rf $(dir $@)
	@mkdir -p $(dir $@)
	@ln -s $(abspath $(SRC_DIR)) $(dir $@)
	@ln -s $(abspath $(BUILD_DIR)) $(dir $@)
	@cd $(dir $@) && ngdbuild -dd ngo $(addprefix -sd ,$(dir $(SRCS_SYN_CORE_BLD))) \
     -nt timestamp -uc $(SRCS_SYN_UCF) -p $(PART) $(abspath $(XST_TARGET)) $(notdir $@) $(REDIR)


#### Map ####

.PHONY: map
map: $(MAP_TARGET)

$(MAP_TARGET): $(TRANS_TARGET) | check-env
	@echo '[MAP]         $@'
	@rm -rf $(dir $@)
	@mkdir -p $(dir $@)
	@cd $(dir $@) && map -p $(PART) $(MAP_SETTINGS) \
     -o $(notdir $@) $(abspath $(TRANS_TARGET)) $(notdir $(MAP_PCF)) $(REDIR)

#### Place & Route ####

.PHONY: par
par: $(PAR_TARGET)

$(PAR_TARGET): $(MAP_TARGET) | check-env
	@echo '[PAR]         $@'
	@rm -rf $(dir $@)
	@mkdir -p $(dir $@)
	@cd $(dir $@) && par -w -ol high -mt 4 $(abspath $(MAP_TARGET)) $(notdir $@) \
     $(abspath $(MAP_PCF)) $(REDIR)


#### Static Timing ####

.PHONY: trace
trace: $(TRACE_TARGET)

$(TRACE_TARGET): $(PAR_TARGET) | check-env
	@echo '[TRACE]       $@'
	@rm -rf $(dir $@)
	@mkdir -p $(dir $@)
	@cd $(dir $@) && trce -v 3 -s $(SPEED) -n 3 -fastpaths -xml $(PROJECT_TOP).twx \
     $(abspath $(PAR_TARGET)) -o $(notdir $@) $(abspath $(MAP_PCF)) $(REDIR)


#### Bitgen ####

.PHONY: bitgen
bitgen: $(BITGEN_TARGET)

$(BITGEN_TARGET): $(BITGEN_CFG_PART) $(PAR_TARGET) | check-env
	@echo '[BITGEN]      $@'
	@rm -rf $(dir $@)
	@mkdir -p $(dir $@)
	@cd $(dir $@) && bitgen -f $(abspath $(BITGEN_CFG_PART)) $(abspath $(PAR_TARGET)) \
     $(notdir $@) $(REDIR)


# If you are seeing an error about Xilinx, the Makefile can't find the Xilinx tools. Refer to Xilinx
# documentation for the scripts that define the XILINX (and other) environment variables.

# If you are seeing an error about Bash, you need to either install bash, make sure it's
# in your path, or modify the shell commands in this file to match your shell.

.PHONY: check-env
check-env:
ifndef XILINX
	$(error The XILINX environment variable is undefined)
endif
ifndef SHELL
	$(error Bash not found)
endif


#### Cleanup ####

.PHONY: clean
clean:
ifeq ($(SRC_DIR),$(BUILD_DIR))
    @echo "clean: Source and build directories are the same. Not deleting anything!"
else
	@rm -rf $(BUILD_DIR)
endif
