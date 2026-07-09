# Installing iOS 18+ apps when Bootstrap will not inject `installd`

## What we proved on your device

After LowerInstall 1.4.x, logs showed only:

```text
AppStore.loaded
status.txt
```

Missing:

```text
installd.loaded
appstored.loaded
```

That means:

| Process | Status | Role |
|---------|--------|------|
| App Store.app | Injected | UI only |
| `appstored` | Not injected | Store daemon / downloads |
| `installd` | Not injected | **Actually installs packages** |

So App Store updates **start** (UI) then **snap back** (`installd` still enforces real iOS).  
**No tweak that only loads in App Store.app can finish those updates.**

This is a **Bootstrap / semi-jailbreak injection limit**, not a spoof-string bug.

---

## Path A — Prefer this if available: full daemon injection

1. Update **Bootstrap** to latest **2.x** (daemon injection improved).
2. Bootstrap → re-bootstrap / rebuild if offered.
3. Reboot, open App Store, check again:
   `/var/mobile/Library/Logs/LowerInstall/installd.loaded`
4. If `installd.loaded` appears, LowerInstall can work on the App Store path.

If it **never** appears, stay on Path B.

---

## Path B — Bypass App Store installd entirely (works without installd injection)

You already have **TrollStore** (Bootstrap requires it). TrollStore installs IPAs **without** going through the same App Store → installd spoof path.

### High-level

```text
Own Apple ID → download IPA on Mac → patch MinimumOSVersion → TrollStore install
```

### 1) Download an IPA you own (Mac)

[`ipatool`](https://github.com/majd/ipatool) (official App Store download for **your** account):

```bash
brew install ipatool
ipatool auth login
ipatool download -b com.example.someapp -o SomeApp.ipa
```

Use the real bundle ID of the app you already own / are allowed to install.

### 2) Patch min OS (Mac)

From this repo:

```bash
chmod +x scripts/patch-ipa-minos.sh
./scripts/patch-ipa-minos.sh ./SomeApp.ipa 15.0
# → SomeApp-minos15.0.ipa
```

### 3) Install on phone

1. AirDrop / Files the patched IPA to the device  
2. Share → **TrollStore** → Install  
3. Open the app  

### Reality check

| Outcome | Meaning |
|---------|---------|
| Installs + opens | Good enough for that version |
| Installs, crashes on launch | Binary still requires newer OS APIs / Mach-O minos — **cannot force** with spoof alone |
| TrollStore refuses | IPA corrupt / not a valid package |

---

## Path C — Purchase / last compatible App Store build

[`AppStoreTroller`](https://github.com/mineek/appstoretroller) style flow:

1. Spoof long enough to **purchase** an incompatible app  
2. Turn spoof off  
3. Redownload → Apple may serve the **last compatible** build **if one exists**

Useful for **new** installs, not for forcing a **latest iOS 18-only** update.

---

## Path D — Full jailbreak (if your device/iOS supports it)

**Dopamine** / full rootless with real `installd` injection is what makes classic LowerInstall-style App Store spoofing reliable. Bootstrap alone often only covers **app** injection.

---

## What will *not* work

- More App Store UI spoofing without `installd.loaded`
- Enabling only App Store in Bootstrap App List
- Expecting every iOS 18-only binary to run on iOS 17 after install  

---

## Recommended order for you

1. Confirm Bootstrap version (update to 2.x if not).  
2. If still no `installd.loaded` → **stop fighting App Store updates**.  
3. Use **Path B (TrollStore + patched IPA)** for apps you care about.  
4. Only chase Path D if you want system-wide daemon tweaks long-term.
