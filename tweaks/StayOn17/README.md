# StayOn17

Per-app iOS version spoof for iOS 17 roothide. Enable specific bundle IDs to report iOS 18.x to apps and App Store daemons.

## Settings

Settings → StayOn17

## CLI

```bash
stayon17-scan scan --bundle-id com.example.app
stayon17-scan enable com.example.app --spoof 18.0
```

## Notes

- Red scan = likely needs real iOS 18 APIs; force enable at your own risk.
- Confirm `/var/mobile/Library/Logs/LowerInstall/installd.loaded` style injection via StayOn17 after install on Bootstrap.
