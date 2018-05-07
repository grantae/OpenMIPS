###############################################################################
#                                                                             #
#                   GCC MIPS Cross-compiler for MIPS32r1                      #
#           Copyright (C) 2015 Grant Ayers <ayers@cs.stanford.edu>            #
#                                                                             #
# This Makefile downloads and builds a MIPS cross-compiler C toolchain        #
# based on GCC and Binutils.                                                  #
#                                                                             #
# Typical Usage:                                                              #
#   make          : Download and build everything (binutils + gcc).           #
#   make download : Download packages.                                        #
#   make binutils : Download and build binutils.                              #
#   make gcc      : Download and build binutils and gcc.                      #
#   make clean    : Delete the build directory.                               #
#   make cleanall : Delete the build and install directories.                 #
#                                                                             #
# Requirements:                                                               #
#   - GNU Make                                                                #
#   - wget                                                                    #
#   - common utilities (grep, awk)                                            #
#                                                                             #
###############################################################################


#---------- Basic settings ----------#
ARCHITECTURE := mipsisa32-elf
INST_DIR     := mips_tc
PKG_LIST     := packages.lst
BLD_DIR      := build
NEWLIB_PATCH := sbrkr.patch


#---------- No need to modify below ----------#
PKGS          := $(notdir $(shell awk '{print $$2;}' < $(PKG_LIST) | sed 's/.tar.*//g'))
PKGS_URL      := $(shell awk '{print $$2;}' < $(PKG_LIST))
PKGS_TBALL    := $(addprefix $(BLD_DIR)/,$(notdir $(PKGS_URL)))
BINUTILS_NAME := $(filter binutils%,$(PKGS))
GCC_NAME      := $(filter gcc%,$(PKGS))
GMP_NAME      := $(filter gmp%,$(PKGS))
MPC_NAME      := $(filter mpc%,$(PKGS))
MPFR_NAME     := $(filter mpfr%,$(PKGS))
NEWLIB_NAME   := $(filter newlib%,$(PKGS))
GCC_DEPS      := $(filter-out $(BLD_DIR)/binutils%,$(PKGS_TBALL))

.PHONY: all download binutils patch-gcc gcc clean cleanall

hash_from_url = $(shell grep $(notdir $(1)) $(PKG_LIST) | awk '{print $$1;}')

all: gcc

$(BLD_DIR):
	@mkdir -p $@


download: $(PKGS_TBALL)

$(PKGS_TBALL): $(PKG_LIST) | $(BLD_DIR)
	@echo [download]  $@
	@cd $(BLD_DIR) && wget --quiet --no-use-server-timestamps $(shell grep '$(notdir $@)' < $(PKG_LIST) | awk '{print $$2;}')
	@echo '$(call hash_from_url,$@) $(BLD_DIR)/$(notdir $@)' > $@.check && sha256sum --check $@.check
	@rm $@.check
	@tar xf $@ -C $(BLD_DIR)


binutils: $(INST_DIR)/bin/$(ARCHITECTURE)-as

$(INST_DIR)/bin/$(ARCHITECTURE)-as: $(filter $(BLD_DIR)/binutils%,$(PKGS_TBALL)) | $(BLD_DIR)
	@rm -rf $(BLD_DIR)/binutils-build
	@mkdir $(BLD_DIR)/binutils-build
	@cd $(BLD_DIR)/binutils-build && ../$(BINUTILS_NAME)/configure --prefix=$(abspath $(INST_DIR)) \
     --target=$(ARCHITECTURE) --disable-nls
	@$(MAKE) -C $(BLD_DIR)/binutils-build
	@$(MAKE) -C $(BLD_DIR)/binutils-build install


patch-gcc: $(BLD_DIR)/patched

$(BLD_DIR)/patched: $(PKGS_TBALL)
	@patch $(BLD_DIR)/$(NEWLIB_NAME)/newlib/libc/reent/sbrkr.c $(NEWLIB_PATCH)
	@ln -s ../$(GMP_NAME) $(BLD_DIR)/$(GCC_NAME)/gmp
	@ln -s ../$(MPC_NAME) $(BLD_DIR)/$(GCC_NAME)/mpc
	@ln -s ../$(MPFR_NAME) $(BLD_DIR)/$(GCC_NAME)/mpfr
	@ln -s ../$(NEWLIB_NAME)/newlib $(BLD_DIR)/$(GCC_NAME)/newlib
	@ln -s ../$(NEWLIB_NAME)/libgloss $(BLD_DIR)/$(GCC_NAME)/libgloss
	@touch $@


gcc: $(INST_DIR)/bin/$(ARCHITECTURE)-gcc

$(INST_DIR)/bin/$(ARCHITECTURE)-gcc: $(GCC_DEPS) | patch-gcc binutils $(BLD_DIR)
	@rm -rf $(BLD_DIR)/gcc-build
	@mkdir $(BLD_DIR)/gcc-build
	@cd $(BLD_DIR)/gcc-build && ../$(GCC_NAME)/configure --prefix=$(abspath $(INST_DIR)) --target=$(ARCHITECTURE) \
     --with-newlib --without-headers --with-gnu-ld --with-gnu-as --disable-libssp --disable-nls --enable-c99 \
     --enable-long-long --enable-languages=c
	@$(MAKE) -C $(BLD_DIR)/gcc-build
	@$(MAKE) -C $(BLD_DIR)/gcc-build install


clean:
	@rm -rf $(BLD_DIR)

cleanall: clean
	@rm -rf $(INST_DIR)
