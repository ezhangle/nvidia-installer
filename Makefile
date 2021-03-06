#
# nvidia-installer: A tool for installing NVIDIA software packages on
# Unix and Linux systems.
#
# Copyright (C) 2008 NVIDIA Corporation
#
# This program is free software; you can redistribute it and/or modify it
# under the terms and conditions of the GNU General Public License,
# version 2, as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, see <http://www.gnu.org/licenses>.
#
#
# Makefile
#


##############################################################################
# include common variables and functions
##############################################################################

include utils.mk


##############################################################################
# The calling Makefile may export any of the following variables; we
# assign default values if they are not exported by the caller
##############################################################################


NCURSES_CFLAGS        ?=
NCURSES_LDFLAGS       ?=
PCI_CFLAGS            ?=
PCI_LDFLAGS           ?=


##############################################################################
# assign variables
##############################################################################

NVIDIA_INSTALLER = $(OUTPUTDIR)/nvidia-installer
MKPRECOMPILED = $(OUTPUTDIR)/mkprecompiled
MAKESELF_HELP_SCRIPT = $(OUTPUTDIR)/makeself-help-script
MAKESELF_HELP_SCRIPT_SH = $(OUTPUTDIR)/makeself-help-script.sh

NVIDIA_INSTALLER_PROGRAM_NAME = "nvidia-installer"

NVIDIA_INSTALLER_VERSION := $(NVIDIA_VERSION)

# We only need to run the TLS test on Linux-x86 and Linux-x86_64
ifeq ($(findstring Linux-x86,$(TARGET_OS)-$(TARGET_ARCH)),)
  NEED_TLS_TEST =
else
  NEED_TLS_TEST = 1
endif

NCURSES_UI_C       = ncurses-ui.c
NCURSES_UI_SO      = $(OUTPUTDIR)/nvidia-installer-ncurses-ui.so
NCURSES_UI_SO_C    = $(OUTPUTDIR)/g_$(notdir $(NCURSES_UI_SO:.so=.c))

ifneq ($(NEED_TLS_TEST),)
  TLS_TEST_C         = $(OUTPUTDIR)/g_tls_test.c
  TLS_TEST_DSO_C     = $(OUTPUTDIR)/g_tls_test_dso.c
  TLS_TEST           = tls_test_$(TARGET_OS)-$(TARGET_ARCH)
  TLS_TEST_DSO_SO    = tls_test_dso_$(TARGET_OS)-$(TARGET_ARCH).so

  TLS_TEST_32_C      = $(OUTPUTDIR)/g_tls_test_32.c
  TLS_TEST_DSO_32_C  = $(OUTPUTDIR)/g_tls_test_dso_32.c
  TLS_TEST_32        = tls_test_$(TARGET_OS)-x86
  TLS_TEST_DSO_SO_32 = tls_test_dso_$(TARGET_OS)-x86.so
else
  TLS_TEST_C         =
  TLS_TEST_DSO_C     =
  TLS_TEST           =
  TLS_TEST_DSO_SO    =

  TLS_TEST_32_C      =
  TLS_TEST_DSO_32_C  =
  TLS_TEST_32        =
  TLS_TEST_DSO_SO_32 =
endif

RTLD_TEST_C        = $(OUTPUTDIR)/g_rtld_test.c
RTLD_TEST          = rtld_test_$(TARGET_OS)-$(TARGET_ARCH)$(if $(TARGET_ARCH_ABI),-$(TARGET_ARCH_ABI))

RTLD_TEST_32_C     = $(OUTPUTDIR)/g_rtld_test_32.c
RTLD_TEST_32       = rtld_test_$(TARGET_OS)-x86

GEN_UI_ARRAY       = $(OUTPUTDIR)/gen-ui-array
CONFIG_H           = $(OUTPUTDIR)/config.h

MANPAGE            = $(OUTPUTDIR)/nvidia-installer.1.gz
GEN_MANPAGE_OPTS   = $(OUTPUTDIR_ABSOLUTE)/gen-manpage-opts
OPTIONS_1_INC      = $(OUTPUTDIR)/options.1.inc

# Setup some architecture specific build options
ifeq ($(TARGET_OS)-$(TARGET_ARCH), Linux-x86_64)
  TLS_MODEL = initial-exec
  PIC = -fPIC
  # Only Linux-x86_64 needs the tls_test_32 files
  COMPAT_32_SRC = $(TLS_TEST_32_C) $(TLS_TEST_DSO_32_C) \
    $(RTLD_TEST_32_C)
else
  # So far all other platforms use local-exec
  TLS_MODEL = local-exec
  PIC =
  # Non-Linux-x86_64 platforms do not include the tls_test_32 files
  COMPAT_32_SRC =
endif

##############################################################################
# The common-utils directory may be in one of two places: either
# elsewhere in the driver source tree when building nvidia-installer
# as part of the NVIDIA driver build (in which case, COMMON_UTILS_DIR
# should be defined by the calling makefile), or directly in the
# source directory when building from the nvidia-installer source
# tarball (in which case, the below conditional assignments should be
# used)
##############################################################################

COMMON_UTILS_DIR          ?= common-utils

# include the list of source files; defines SRC
include dist-files.mk

include $(COMMON_UTILS_DIR)/src.mk
SRC += $(addprefix $(COMMON_UTILS_DIR)/,$(COMMON_UTILS_SRC))

INSTALLER_SRC = $(SRC) $(NCURSES_UI_SO_C) $(TLS_TEST_C) $(TLS_TEST_DSO_C) \
	$(RTLD_TEST_C) $(COMPAT_32_SRC) $(STAMP_C)

INSTALLER_OBJS = $(call BUILD_OBJECT_LIST,$(INSTALLER_SRC))

common_cflags  = -I.
common_cflags += -imacros $(CONFIG_H)
common_cflags += -I $(OUTPUTDIR)
common_cflags += -I $(COMMON_UTILS_DIR)
common_cflags += $(if $(NEED_TLS_TEST),-DNV_TLS_TEST)

CFLAGS += $(common_cflags)

HOST_CFLAGS += $(common_cflags)

LDFLAGS += -L.
LIBS += -ldl

MKPRECOMPILED_SRC = crc.c mkprecompiled.c $(COMMON_UTILS_DIR)/common-utils.c \
                    precompiled.c $(COMMON_UTILS_DIR)/nvgetopt.c
MKPRECOMPILED_OBJS = $(call BUILD_OBJECT_LIST,$(MKPRECOMPILED_SRC))

MAKESELF_HELP_SCRIPT_SRC  = makeself-help-script.c
MAKESELF_HELP_SCRIPT_SRC += $(COMMON_UTILS_DIR)/common-utils.c
MAKESELF_HELP_SCRIPT_SRC += $(COMMON_UTILS_DIR)/nvgetopt.c
MAKESELF_HELP_SCRIPT_SRC += $(COMMON_UTILS_DIR)/msg.c

BUILD_MAKESELF_OBJECT_LIST = \
  $(patsubst %.o,%.makeself.o,$(call BUILD_OBJECT_LIST,$(1)))

MAKESELF_HELP_SCRIPT_OBJS = \
  $(call BUILD_MAKESELF_OBJECT_LIST,$(MAKESELF_HELP_SCRIPT_SRC))

ALL_SRC = $(sort $(INSTALLER_SRC) $(NCURSES_UI_C) $(MKPRECOMPILED_SRC))

# define a quiet rule for GEN-UI-ARRAY
quiet_GEN_UI_ARRAY = GEN-UI-ARRAY $@


##############################################################################
# build rules
##############################################################################

.PNONY: all install NVIDIA_INSTALLER_install MKPRECOMPILED_install \
  MANPAGE_install MAKESELF_HELP_SCRIPT_install clean clobber

all: $(NVIDIA_INSTALLER) $(MKPRECOMPILED) $(MAKESELF_HELP_SCRIPT) \
  $(MAKESELF_HELP_SCRIPT_SH) $(MANPAGE)

install: NVIDIA_INSTALLER_install MKPRECOMPILED_install MANPAGE_install \
  MAKESELF_HELP_SCRIPT_install

NVIDIA_INSTALLER_install: $(NVIDIA_INSTALLER)
	$(MKDIR) $(BINDIR)
	$(INSTALL) $(INSTALL_BIN_ARGS) $< $(BINDIR)/$(notdir $<)

MKPRECOMPILED_install: $(MKPRECOMPILED)
	$(MKDIR) $(BINDIR)
	$(INSTALL) $(INSTALL_BIN_ARGS) $< $(BINDIR)/$(notdir $<)

MAKESELF_HELP_SCRIPT_install: $(MAKESELF_HELP_SCRIPT)
	$(MKDIR) $(BINDIR)
	$(INSTALL) $(INSTALL_BIN_ARGS) $< $(BINDIR)/$(notdir $<)

MANPAGE_install: $(MANPAGE)
	$(MKDIR) $(MANDIR)
	$(INSTALL) $(INSTALL_DOC_ARGS) $< $(MANDIR)/$(notdir $<)

$(MKPRECOMPILED): $(MKPRECOMPILED_OBJS)
	$(call quiet_cmd,LINK) $(CFLAGS) $(LDFLAGS) $(BIN_LDFLAGS) \
	  $(MKPRECOMPILED_OBJS) -o $@ $(LIBS)
	$(call quiet_cmd,STRIP_CMD) $@

$(MAKESELF_HELP_SCRIPT): $(MAKESELF_HELP_SCRIPT_OBJS)
	$(call quiet_cmd,HOST_LINK) $(HOST_CFLAGS) $(HOST_LDFLAGS) \
	  $(HOST_BIN_LDFLAGS) $(MAKESELF_HELP_SCRIPT_OBJS) -o $@

$(NVIDIA_INSTALLER): $(INSTALLER_OBJS)
	$(call quiet_cmd,LINK) $(CFLAGS) $(LDFLAGS) $(PCI_LDFLAGS) \
	  $(BIN_LDFLAGS) $(INSTALLER_OBJS) -o $@ \
	  $(LIBS) -Bstatic -lpci -Bdynamic
	$(call quiet_cmd,STRIP_CMD) $@

$(GEN_UI_ARRAY): gen-ui-array.c $(CONFIG_H)
	$(call quiet_cmd,HOST_CC) $(HOST_CFLAGS) $(HOST_LDFLAGS) \
	  $(HOST_BIN_LDFLAGS) $< -o $@

$(NCURSES_UI_SO): $(call BUILD_OBJECT_LIST,ncurses-ui.c)
	$(call quiet_cmd,LINK) -shared $(NCURSES_LDFLAGS) \
	  $(CFLAGS) $(LDFLAGS) $(BIN_LDFLAGS) $< -o $@ -lncurses $(LIBS)

$(NCURSES_UI_SO_C): $(GEN_UI_ARRAY) $(NCURSES_UI_SO)
	$(call quiet_cmd,GEN_UI_ARRAY) $(NCURSES_UI_SO) ncurses_ui_array > $@

ifneq ($(NEED_TLS_TEST),)
  $(TLS_TEST_C): $(GEN_UI_ARRAY) $(TLS_TEST)
	$(call quiet_cmd,GEN_UI_ARRAY) $(TLS_TEST) tls_test_array > $@

  $(TLS_TEST_DSO_C): $(GEN_UI_ARRAY) $(TLS_TEST_DSO_SO)
	$(call quiet_cmd,GEN_UI_ARRAY) \
	  $(TLS_TEST_DSO_SO) tls_test_dso_array > $@

  $(TLS_TEST_32_C): $(GEN_UI_ARRAY) $(TLS_TEST_32)
	$(call quiet_cmd,GEN_UI_ARRAY) $(TLS_TEST_32) tls_test_array_32 > $@

  $(TLS_TEST_DSO_32_C): $(GEN_UI_ARRAY) $(TLS_TEST_DSO_SO_32)
	$(call quiet_cmd,GEN_UI_ARRAY) \
	  $(TLS_TEST_DSO_SO_32) tls_test_dso_array_32 > $@
endif

$(RTLD_TEST_C): $(GEN_UI_ARRAY) $(RTLD_TEST)
	$(call quiet_cmd,GEN_UI_ARRAY) $(RTLD_TEST) rtld_test_array > $@

$(RTLD_TEST_32_C): $(GEN_UI_ARRAY) $(RTLD_TEST_32)
	$(call quiet_cmd,GEN_UI_ARRAY) $(RTLD_TEST_32) rtld_test_array_32 > $@

# misc.c includes pci.h
$(call BUILD_OBJECT_LIST,misc.c): CFLAGS += $(PCI_CFLAGS)

# ncurses-ui.c includes ncurses.h
$(call BUILD_OBJECT_LIST,ncurses-ui.c): CFLAGS += $(NCURSES_CFLAGS) -fPIC

# define the rule to build each object file
$(foreach src,$(ALL_SRC),$(eval $(call DEFINE_OBJECT_RULE,TARGET,$(src))))

# define a rule to build each makeself-help-script object file
$(foreach src,$(MAKESELF_HELP_SCRIPT_SRC),\
  $(eval $(call DEFINE_OBJECT_RULE_WITH_OBJECT_NAME,HOST,$(src),\
    $(call BUILD_MAKESELF_OBJECT_LIST,$(src)))))

# define the rule to generate $(STAMP_C)
$(eval $(call DEFINE_STAMP_C_RULE, $(INSTALLER_OBJS),$(NVIDIA_INSTALLER_PROGRAM_NAME)))

$(CONFIG_H): $(VERSION_MK)
	@ $(RM) -f $@
	@ $(MKDIR) $(OUTPUTDIR)
	@ $(ECHO)    "#define INSTALLER_OS \"$(TARGET_OS)\"" >> $@
	@ $(ECHO)    "#define INSTALLER_ARCH \"$(TARGET_ARCH)\"" >> $@
	@ $(ECHO) -n "#define NVIDIA_INSTALLER_VERSION " >> $@
	@ $(ECHO)    "\"$(NVIDIA_INSTALLER_VERSION)\"" >> $@
	@ $(ECHO) -n "#define PROGRAM_NAME " >> $@
	@ $(ECHO)    "\"$(NVIDIA_INSTALLER_PROGRAM_NAME)\"" >> $@

$(call BUILD_OBJECT_LIST,$(ALL_SRC)): $(CONFIG_H)
$(call BUILD_MAKESELF_OBJECT_LIST,$(MAKESELF_HELP_SCRIPT_SRC)): $(CONFIG_H)

clean clobber:
	rm -rf $(OUTPUTDIR)


##############################################################################
# rule to rebuild tls_test and tls_test_dso; a precompiled tls_test
# and tls_test_dso is distributed with nvidia_installer because they
# require a recent toolchain to build.
##############################################################################

rebuild_tls_test: tls_test.c
	gcc -Wall -O2 -fomit-frame-pointer -o $(TLS_TEST) -ldl $<
	strip $(TLS_TEST)

rebuild_tls_test_dso: tls_test_dso.c
	gcc -Wall -O2 $(PIC) -fomit-frame-pointer -c $< \
		-ftls-model=$(TLS_MODEL)
	gcc -o $(TLS_TEST_DSO_SO) -shared tls_test_dso.o
	strip $(TLS_TEST_DSO_SO)

# dummy rule to override implicit rule that builds tls_test from
# tls_test.c

tls_test: tls_test.c
	touch $@

# rule to rebuild rtld_test; a precompiled rtld_test is distributed with
# nvidia-installer to simplify x86-64 builds.

rebuild_rtld_test: rtld_test.c $(CONFIG_H)
	$(call quiet_cmd,LINK) $(CFLAGS) $(LDFLAGS) $(BIN_LDFLAGS) -o $(RTLD_TEST) -lGL $<
	$(call quiet_cmd,STRIP_CMD) $(RTLD_TEST)

# dummy rule to override implicit rule that builds dls_test from
# rtld_test.c

rtld_test: rtld_test.c
	touch $@


##############################################################################
# rule to build MAKESELF_HELP_SCRIPT_SH; this shell script is packaged
# with the driver so that the script can be run on any platform when
# the driver is later repackaged
##############################################################################

$(MAKESELF_HELP_SCRIPT_SH): $(MAKESELF_HELP_SCRIPT)
	@ $(ECHO) "#!/bin/sh" > $@
	@ $(ECHO) "while [ \"\$$1\" ]; do" >> $@
	@ $(ECHO) "    case \$$1 in" >> $@
	@ $(ECHO) "        \"--advanced-options-args-only\")" >> $@
	@ $(ECHO) "            cat <<- \"ADVANCED_OPTIONS_ARGS_ONLY\"" >> $@
	$(MAKESELF_HELP_SCRIPT) --advanced-options-args-only >> $@
	@ $(ECHO) "ADVANCED_OPTIONS_ARGS_ONLY" >> $@
	@ $(ECHO) "            ;;" >> $@
	@ $(ECHO) "        \"--help-args-only\")" >> $@
	@ $(ECHO) "            cat <<- \"HELP_ARGS_ONLY\"" >> $@
	$(MAKESELF_HELP_SCRIPT) --help-args-only >> $@
	@ $(ECHO) "HELP_ARGS_ONLY" >> $@
	@ $(ECHO) "            ;;" >> $@
	@ $(ECHO) "        *)" >> $@
	@ $(ECHO) "            echo \"unrecognized option '$$1'"\" >> $@
	@ $(ECHO) "            break" >> $@
	@ $(ECHO) "            ;;" >> $@
	@ $(ECHO) "    esac" >> $@
	@ $(ECHO) "    shift" >> $@
	@ $(ECHO) "done" >> $@
	$(CHMOD) u+x $@


##############################################################################
# Documentation
##############################################################################

AUTO_TEXT = ".\\\" WARNING: THIS FILE IS AUTO-GENERATED!  Edit $< instead."

doc: $(MANPAGE)

GEN_MANPAGE_OPTS_SRC  = gen-manpage-opts.c
GEN_MANPAGE_OPTS_SRC += $(COMMON_UTILS_DIR)/gen-manpage-opts-helper.c

GEN_MANPAGE_OPTS_OBJS = $(call BUILD_OBJECT_LIST,$(GEN_MANPAGE_OPTS_SRC))

$(foreach src, $(GEN_MANPAGE_OPTS_SRC), \
    $(eval $(call DEFINE_OBJECT_RULE,HOST,$(src))))

$(GEN_MANPAGE_OPTS_OBJS): $(CONFIG_H)

$(GEN_MANPAGE_OPTS): $(GEN_MANPAGE_OPTS_OBJS)
	$(call quiet_cmd,HOST_LINK) \
	    $(HOST_CFLAGS) $(HOST_LDFLAGS) $(HOST_BIN_LDFLAGS) $^ -o $@

$(OPTIONS_1_INC): $(GEN_MANPAGE_OPTS)
	@$< > $@

$(MANPAGE): nvidia-installer.1.m4 $(OPTIONS_1_INC) $(VERSION_MK)
	$(call quiet_cmd,M4) \
	   -D__HEADER__=$(AUTO_TEXT) \
	   -D__VERSION__=$(NVIDIA_INSTALLER_VERSION) \
	   -D__DATE__="`$(DATE) +%F`" \
	   -D__INSTALLER_OS__="$(TARGET_OS)" \
	   -D__INSTALLER_ARCH__="$(TARGET_ARCH)" \
	   -D__DRIVER_VERSION__="$(NVIDIA_VERSION)" \
	   -D__OUTPUTDIR__=$(OUTPUTDIR) \
	   -I $(OUTPUTDIR) \
	   $< | $(GZIP_CMD) -9f > $@
