# SPDX-License-Identifier: GPL-3.0-only
AXON_VARIANT ?= roothide
ifeq ($(AXON_VARIANT),rootful)
THEOS_PACKAGE_SCHEME =
else ifeq ($(AXON_VARIANT),rootless)
THEOS_PACKAGE_SCHEME = rootless
else ifeq ($(AXON_VARIANT),roothide)
THEOS_PACKAGE_SCHEME = roothide
else
$(error AXON_VARIANT must be rootful, rootless, or roothide)
endif
export THEOS_PACKAGE_SCHEME AXON_VARIANT
ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
FINALPACKAGE = 1
DEBUG = 0
