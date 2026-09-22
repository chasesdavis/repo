SDK := $(shell xcrun --sdk iphoneos --show-sdk-path)
VERSION := 1.0.2
PACKAGE := libroot-roothide
ARCH := iphoneos-arm64e
DEB := $(PACKAGE)_$(VERSION)_$(ARCH).deb

CFLAGS := -Os -Wall -Wextra -Werror -fvisibility=hidden -miphoneos-version-min=15.0
LDFLAGS := -Wl,-dead_strip -install_name @loader_path/.jbroot/usr/lib/libroot.dylib

.PHONY: all clean deb

all: libroot.dylib

libroot.dylib: libroot.c
	xcrun clang -arch arm64 -isysroot $(SDK) $(CFLAGS) -dynamiclib $(LDFLAGS) -o libroot.arm64.dylib $<
	xcrun clang -arch arm64e -isysroot $(SDK) $(CFLAGS) -dynamiclib $(LDFLAGS) -o libroot.arm64e.dylib $<
	lipo -create -output $@ libroot.arm64.dylib libroot.arm64e.dylib
	ldid -S $@
	rm -f libroot.arm64.dylib libroot.arm64e.dylib

deb: libroot.dylib control
	rm -rf stage
	mkdir -p stage/DEBIAN stage/usr/lib
	cp libroot.dylib stage/usr/lib/libroot.dylib
	chmod 0755 stage/usr/lib/libroot.dylib
	installed=$$(du -sk stage/usr | awk '{print $$1}'); \
	sed -e "s/@INSTALLED_SIZE@/$$installed/" control > stage/DEBIAN/control
	chmod 0644 stage/DEBIAN/control
	dpkg-deb --root-owner-group -Zgzip -z9 -b stage $(DEB)
	rm -rf stage

clean:
	rm -rf libroot.dylib libroot.arm64.dylib libroot.arm64e.dylib stage $(PACKAGE)_*_$(ARCH).deb
