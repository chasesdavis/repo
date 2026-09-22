SDK := $(shell xcrun --sdk iphoneos --show-sdk-path)
TARGET := arm64-apple-ios15.0
VERSION := 1.0.0
PACKAGE := libroot-roothide
ARCH := iphoneos-arm64e
DEB := $(PACKAGE)_$(VERSION)_$(ARCH).deb

CFLAGS := -Os -Wall -Wextra -fvisibility=hidden
LDFLAGS := -Wl,-dead_strip -install_name @loader_path/.jbroot/usr/lib/libroot.dylib

.PHONY: all clean deb

all: libroot.dylib

libroot.dylib: libroot.c
	xcrun clang -target $(TARGET) -isysroot $(SDK) $(CFLAGS) -dynamiclib $(LDFLAGS) -o $@ $<
	ldid -S $@

deb: libroot.dylib control
	rm -rf stage
	mkdir -p stage/DEBIAN stage/usr/lib
	cp libroot.dylib stage/usr/lib/libroot.dylib
	chmod 0755 stage/usr/lib/libroot.dylib
	installed=$$(du -sk stage/usr | awk '{print $$1}'); \
	sed -e "s/@INSTALLED_SIZE@/$$installed/" control > stage/DEBIAN/control
	chmod 0644 stage/DEBIAN/control
	dpkg-deb --root-owner-group -Zzstd -b stage $(DEB)
	rm -rf stage

clean:
	rm -rf libroot.dylib stage $(DEB)
