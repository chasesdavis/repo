#!/bin/bash
# Bounded self-improvement loop for the StayOn17 Theos packaging pipeline.
# BOUNDED: fixed checklist with check_*/fix_* per item. Stops when all green or MAX_PASSES.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TWEAK="$ROOT/tweaks/StayOn17"
MAX_PASSES=8
PASS=0
PASSED=""
green(){ printf "  [PASS]  %s\n" "$1"; }
red(){   printf "  [FAIL]  %s\n" "$1"; }
info(){  printf "          %s\n" "$1"; }
has(){ case " $1 " in *" $2 "*) return 0;; esac; return 1; }

check_root_makefile_delegates(){ [ -f "$ROOT/Makefile" ] && grep -q 'tweaks/StayOn17' "$ROOT/Makefile" && ! grep -qE 'StayOn17Core|StayOn17Prefs' "$ROOT/Makefile" && awk '/^[[:space:]]*\$\(MAKE\)/{f=1} END{exit !f}' "$ROOT/Makefile"; }
fix_root_makefile_delegates(){
  {
    printf '%s\n' '# StayOn17 root entrypoint. Real Theos build lives in tweaks/StayOn17/.'
    printf '%s\n' 'THEOS ?= $(HOME)/theos'
    printf '%s\n' '.DEFAULT_GOAL := package'
    printf '%s\n' '%:'
    printf '\t%s\n' '$(MAKE) -C tweaks/StayOn17 $@'
  } > "$ROOT/Makefile"
}

check_no_stale_root_duplicates(){ ! [ -e "$ROOT/StayOn17Core" ] && ! [ -e "$ROOT/control" ] && ! [ -e "$ROOT/resources" ] && ! [ -e "$ROOT/layout" ]; }
fix_no_stale_root_duplicates(){ rm -rf "$ROOT/StayOn17Core" "$ROOT/control" "$ROOT/resources" "$ROOT/layout"; }

check_package_identity(){ grep -q '^Package: com.chasedavis.stayon17$' "$TWEAK/control"; }
fix_package_identity(){ true; }

check_prerm_present(){ [ -f "$TWEAK/layout/DEBIAN/prerm" ] && grep -q 'com.chase.stayon17.plist' "$TWEAK/layout/DEBIAN/prerm"; }
fix_prerm_present(){
  mkdir -p "$TWEAK/layout/DEBIAN"
  printf '%s\n' '#!/bin/bash' 'set -e' 'rm -f /var/mobile/Library/Preferences/com.chase.stayon17.plist 2>/dev/null || true' 'exit 0' > "$TWEAK/layout/DEBIAN/prerm"
  chmod 0755 "$TWEAK/layout/DEBIAN/prerm"
}

check_postinst_present(){ [ -f "$TWEAK/layout/DEBIAN/postinst" ]; }
fix_postinst_present(){
  mkdir -p "$TWEAK/layout/DEBIAN"
  printf '%s\n' '#!/bin/bash' 'set -e' 'mkdir -p /var/mobile/Library/Logs/StayOn17' 'exit 0' > "$TWEAK/layout/DEBIAN/postinst"
  chmod 0755 "$TWEAK/layout/DEBIAN/postinst"
}

check_depends_complete(){ grep -q '^Depends:.*ellekit' "$TWEAK/control" && grep -q '^Depends:.*preferenceloader' "$TWEAK/control" && grep -q '^Depends:.*altlist' "$TWEAK/control"; }
fix_depends_complete(){ sed -i '' 's#^Depends:.*#Depends: firmware (>= 17.0), mobilesubstrate (>= 0.9.5000), ellekit, preferenceloader, com.opa334.altlist | firmware (>= 15.0)#' "$TWEAK/control"; }

check_version_consistent(){ grep -q '^Version: 1.0.0-3$' "$TWEAK/control"; }
fix_version_consistent(){ sed -i '' 's/^Version: .*/Version: 1.0.0-3/' "$TWEAK/control"; }

check_roothide_scheme(){ grep -q 'THEOS_PACKAGE_SCHEME = roothide' "$TWEAK/Makefile"; }
fix_roothide_scheme(){ true; }

check_gitignore(){ [ -f "$ROOT/.gitignore" ] && grep -q '.theos' "$ROOT/.gitignore" && grep -q 'packages/' "$ROOT/.gitignore"; }
fix_gitignore(){ printf '%s\n' '.theos/' '*.o' '*.Td' '*.dSYM' 'fakeroot' 'build_session' 'last_package' 'packages/' '*.deb' '.DS_Store' '*.swp' > "$ROOT/.gitignore"; }

check_plists_valid(){ /usr/bin/plutil -lint "$TWEAK/Prefs/Resources/Info.plist" >/dev/null 2>&1 && /usr/bin/plutil -lint "$TWEAK/Prefs/entry.plist" >/dev/null 2>&1; }
fix_plists_valid(){ /usr/bin/plutil -convert xml1 "$TWEAK/Prefs/entry.plist" 2>/dev/null || true; }

check_debian_scripts_exec(){ [ -x "$TWEAK/layout/DEBIAN/postinst" ] && [ -x "$TWEAK/layout/DEBIAN/prerm" ]; }
fix_debian_scripts_exec(){ chmod 0755 "$TWEAK/layout/DEBIAN/postinst" "$TWEAK/layout/DEBIAN/prerm" 2>/dev/null || true; }

check_control_fields(){ for f in Package Name Version Architecture Description Maintainer Author Section Depends; do grep -q "^$f:" "$TWEAK/control" || return 1; done; }
fix_control_fields(){ grep -q '^Architecture:' "$TWEAK/control" || printf 'Architecture: iphoneos-arm64\n' >> "$TWEAK/control"; }

check_control_trailing_newline(){ [ "$(tail -c1 "$TWEAK/control" | wc -l | tr -d ' ')" = "1" ]; }
fix_control_trailing_newline(){ printf '\n' >> "$TWEAK/control"; }

ITEMS="root_makefile_delegates no_stale_root_duplicates package_identity prerm_present postinst_present depends_complete version_consistent roothide_scheme gitignore plists_valid debian_scripts_exec control_fields control_trailing_newline"

while [ "$PASS" -lt "$MAX_PASSES" ]; do
  PASS=$((PASS + 1))
  printf "\n=== Pass %d ===\n" "$PASS"
  any_fail=0
  for id in $ITEMS; do
    if "check_$id" >/dev/null 2>&1; then
      if ! has "$PASSED" "$id"; then PASSED="$PASSED $id"; green "$id"; fi
    else
      any_fail=1
      red "$id"
      info "applying fix_$id ..."
      if "fix_$id" >/dev/null 2>&1 && "check_$id" >/dev/null 2>&1; then
        PASSED="$PASSED $id"; green "$id (fixed)"
      else
        red "$id (fix did not verify)"
      fi
    fi
  done
  [ "$any_fail" -eq 0 ] && break
done

printf "\n=== Summary ===\n"
p=0; f=0
for id in $ITEMS; do
  if has "$PASSED" "$id"; then p=$((p+1)); green "$id"; else f=$((f+1)); red "$id"; fi
done
printf "%d passed, %d failed after %d pass(es)\n" "$p" "$f" "$PASS"
if [ "$f" -eq 0 ]; then printf "\nPackaging pipeline PRODUCTION-READY: all %d checks green.\n" "$p"; exit 0; fi
printf "\n%d check(s) still failing -- needs human review.\n" "$f"
exit 1

