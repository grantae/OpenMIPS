###############################################################################
#                                                                             #
#                      Simulation Harness for MIPS32r1                        #
#           Copyright (C) 2014 Grant Ayers <ayers@cs.stanford.edu>            #
#                                                                             #
# This file is free software distributed under the BSD license. See LICENSE   #
# for more information.                                                       #
#                                                                             #
# This Makefile implements the micro testing infrastructure for the MIPS32r1  #
# processor design. It allows simulating individual components of the design  #
# in separate and customizable unit tests.                                    #
#                                                                             #
# Typical Usage:                                                              #
#   make            : Run all tests.                                          #
#   make test       : Same as 'make'.                                         #
#   make test_<foo> : Run only test <foo>.                                    #
#   make clean      : Clean up.                                               #
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
SRC_DIR          := ../../../hardware/src
CFG_DIR          := harness
BUILD_DIR        := build
VERBOSE          ?= No

#---------- Source file names/types ----------#
VLOG_EXT         := .v
VHDL_EXT         := .vhdl
CORE_CFG_EXT     := .xcp
CORE_PRJ_EXT     := .cgp
CORE_OUT_EXT     := .xco
CORE_SRC_OUT     := src_out.lst
SIM_GLBL_V       := $(XILINX)/verilog/src/glbl.v

#---------- Test/Simulation settings (micro tests only) ----------#
TST_SRC_ROOT     := tests
TST_PRJ_SRCS     := sources.lst
TST_REPORTER     := $(CFG_DIR)/results.py
TST_RESULT_FILE  := result.out
TST_SUMMARY_NAME := test_results


#---------- No need to modify below ----------#


#### Call helper functions ####

# Search for the first instance of a program in PATH
pathsearch = $(firstword $(wildcard $(addsuffix /$(1),$(subst :, ,$(PATH)))))

# Given a filename containing a list of sources (1), return only the specified type (2)
# Also change the wildcard *FILL* to (3)
src_filter = $(shell grep -v -e '^\ *\#' -e '^$$' < $(1) | grep '$(2)$$' | sed 's|\*FILL\*|$(3)|')

# Given the name of a core project (.xco) file, return a list of its generated source files
#core_srcs  = $(shell sed -e 's|^|$(dir $(1))|' < $(dir $(1))$(CORE_SRC_OUT))

#core_srcs  = $(foreach FILE,$(1),$(shell sed -e 's|^|$(dir $(1))|' < $(dir $(1))$(CORE_SRC_OUT)))

core_srcs  = $(foreach FILE,$(1),$(shell sed -e 's|^|$(patsubst $(SRC_DIR)%,$(notdir $(SRC_DIR))%,$(dir $(1)))|' < $(dir $(1))$(CORE_SRC_OUT)))



# Given a test name, return the test output file name
test_result = $(filter %$(1)/$(TST_RESULT_FILE),$(TST_RESULT_FILES))

# Given a test build directory path, return the test executable name
test_exe = $(addsuffix /$(notdir $(1)),$(1))

# Given a test build directory path, return the top-level test name
test_top = $(basename $(notdir $(filter $(patsubst $(BUILD_DIR_PART)/%,%,$(1))%,$(TST_TOP_FILES))))

# Given a test executable name, return the test project file name
test_prj = $(addsuffix .prj,$(basename $(1)))

# Given a test project name, return the source list file name
test_srclist = $(patsubst $(BUILD_DIR_PART)/%,%,$(dir $(1))$(PART)/$(TST_PRJ_SRCS))

# Given a test project name, return the list of all non-core sources (.v, .vhdl)
test_norm_srcs = $(call src_filter,$(call test_srclist,$(1)),$(VLOG_EXT),$(SRC_DIR)) $(call src_filter,$(call test_srclist,$(1)),$(VHDL_EXT),$(SRC_DIR))

# Given a test project name, return a list of all core sources (.xco)
test_cores = $(call src_filter,$(call test_srclist,$(1)),$(CORE_OUT_EXT),$(SRC_DIR))

# Given a test project name, return a list of all core project files (.xco)
test_core_srcs = $(addprefix $(BUILD_DIR_PART)/,$(call src_filter,$(call test_srclist,$(1)),$(CORE_OUT_EXT),$(notdir $(SRC_DIR))))

# Given a test project name, return a list of all generated core sources
test_core_gens = $(addprefix $(BUILD_DIR_PART)/,$(call core_srcs,$(call test_cores,$(1))))


#### Precomputed variables for hardware generation ####

SHELL              := $(call pathsearch,bash)
PART               := $(DEVICE)-$(SPEED)-$(PACKAGE)
BUILD_DIR_PART     := $(BUILD_DIR)/$(PART)
SRCS_ALL_CORE      := $(SRCS_SYN_CORE_BLD) $(SRCS_ALL_CORE)

#### Precomputed variables for testing/simulation ####

TST_SRC_DIRS     := $(shell find $(TST_SRC_ROOT) -mindepth 1 -maxdepth 1 -type d -print)
TST_TOP_FILES    := $(shell find $(TST_SRC_DIRS) -name *$(VLOG_EXT) -type f -print -o -name *$(VHDL_EXT) -type f -print)
TST_BLD_DIRS     := $(addprefix $(BUILD_DIR_PART)/,$(TST_SRC_DIRS))
TST_NAMES        := $(addprefix test_,$(notdir $(TST_SRC_DIRS)))
TST_RESULT_FILES := $(addsuffix /$(TST_RESULT_FILE),$(TST_BLD_DIRS))
TST_EXE_FILES    := $(foreach DIR,$(TST_BLD_DIRS),$(DIR)/$(notdir $(DIR)))
TST_PRJ_FILES    := $(addsuffix .prj,$(basename $(TST_EXE_FILES)))
TST_SUMMARY_FILE := $(BUILD_DIR_PART)/$(TST_SUMMARY_NAME)
TST_REPORTALL    := 0

ifeq ($(VERBOSE),No)
    REDIR          := > /dev/null 2>&1
else
    REDIR          :=
endif


.PHONY: all
all: test


$(BUILD_DIR_PART):
	@mkdir -p $@


#### Build Xilinx cores using coregen ####

$(BUILD_DIR_PART)/$(notdir $(SRC_DIR))%$(CORE_OUT_EXT): | $(BUILD_DIR_PART)
	@echo '[COREGEN]     $@'
	@rm -rf '$(dir $@)*'
	@mkdir -p '$(dir $@)'
	@cp -r $(dir $(addprefix $(SRC_DIR),$*))* $(dir $@)
	@cd $(dir $@) && coregen -intstyle silent -b $(notdir $*)$(CORE_CFG_EXT) -p $(notdir $*)$(CORE_PRJ_EXT) $(REDIR)


.SECONDEXPANSION:

#### Top-level wrapper target for testing ####

.PHONY: test
test: TST_REPORTALL=1
test: test_reset $(TST_NAMES)
	@$(TST_REPORTER) -r $(TST_SUMMARY_FILE)

.PHONY: test_reset
test_reset:
	@rm -f $(TST_SUMMARY_FILE)


#### Top-level target for individual tests ####

.PHONY: $(TST_NAMES)
$(TST_NAMES): test_%: $$(call test_result,$$*)
	@if [ '$(TST_REPORTALL)' -eq '0' ]; then rm -f $(TST_SUMMARY_FILE); fi
	@printf '$* %s\n' $$(cat $(call test_result,$*)) >> $(TST_SUMMARY_FILE)
	@if [ '$(TST_REPORTALL)' -eq '0' ]; then $(TST_REPORTER) -r $(TST_SUMMARY_FILE); fi


#### Run a simulation test and output the result ####

$(TST_RESULT_FILES): %/$(TST_RESULT_FILE): $$(call test_exe,$$*)
	@echo '[TEST]        $@'
	@cd $(dir $@) && ./$(notdir $(call test_exe,$*)) <<< 'run all' $(REDIR)


#### Build a simulation executable for a test ####

$(TST_EXE_FILES): $$(call test_prj,$$@) | check-env
	@echo '[FUSE]        $@'
	@rm -f $@
	@cd $(dir $@) && vlogcomp -intstyle silent -prj $(notdir $(call test_prj,$@))
	@cd $(dir $@) && vhpcomp  -intstyle silent -prj $(notdir $(call test_prj,$@))
	@cd $(dir $@) && fuse -incremental -lib unisims_ver -lib unimacro_ver -lib xilinxcorelib_ver \
     -lib secureip -o $(notdir $@) -prj $(notdir $(call test_prj,$@)) work.$(call test_top,$(dir $@)) work.glbl $(REDIR)


#### Create a project file for a test ####

$(TST_PRJ_FILES): $$(call test_srclist,$$@) $$(call test_norm_srcs,$$@) $$(call test_core_srcs,$$@) | $(BUILD_DIR_PART)
	@echo '[SIM PRJ]     $@'
	@rm -f $@
	@mkdir -p $(dir $@)
	@echo $(abspath $(call test_norm_srcs,$@)) | tr ' ' '\n' | grep '.$(VLOG_EXT)$$' | awk 'NF {print "verilog work \"" $$0 "\""}' > $@
	@echo $(abspath $(call test_norm_srcs,$@)) | tr ' ' '\n' | grep '.$(VHDL_EXT)$$' | awk 'NF {print "vhdl work \"" $$0 "\""}' >> $@
	@echo $(abspath $(call test_core_gens,$@)) | tr ' ' '\n' | grep '.$(VLOG_EXT)$$' | awk 'NF {print "verilog work \"" $$0 "\""}' >> $@
	@echo $(abspath $(call test_core_gens,$@)) | tr ' ' '\n' | grep '.$(VHDL_EXT)$$' | awk 'NF {print "vhdl work \"" $$0 "\""}' >> $@
	@echo 'verilog work "$(SIM_GLBL_V)"' >> $@


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

