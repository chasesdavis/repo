import importlib.util
from pathlib import Path
import plistlib
import tempfile
import unittest
import zipfile

spec = importlib.util.spec_from_file_location("inspect_ipa", Path(__file__).parents[1] / "tools/inspect_ipa.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class InspectionTests(unittest.TestCase):
    def inspect(self, entries):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "fixture.ipa"
            with zipfile.ZipFile(path, "w") as archive:
                for name, info in entries.items():
                    archive.writestr(name, plistlib.dumps(info))
            before = path.read_bytes()
            result = module.inspect(path)
            self.assertEqual(before, path.read_bytes())
            self.assertEqual(list(Path(temp).iterdir()), [path])
            return result

    def test_extension_can_require_newer_os(self):
        result = self.inspect({"Payload/Test.app/Info.plist": {"MinimumOSVersion": "17.0"},
            "Payload/Test.app/PlugIns/Widget.appex/Info.plist": {"MinimumOSVersion": "18.0"}})
        self.assertEqual([b["metadata_result"] for b in result["bundles"]], ["within_target", "above_target"])
        self.assertEqual(result["runtime_compatibility"], "not assessed")

    def test_missing_or_invalid_minimum_is_unknown(self):
        for value in [None, "garbage", 18]:
            info = {} if value is None else {"MinimumOSVersion": value}
            self.assertEqual(self.inspect({"Payload/Test.app/Info.plist": info})["bundles"][0]["metadata_result"], "unknown")

    def test_no_app_is_rejected(self):
        with self.assertRaises(ValueError):
            self.inspect({"Elsewhere/Info.plist": {}})

    def test_invalid_plist_root_is_rejected(self):
        with self.assertRaises(ValueError):
            self.inspect({"Payload/Test.app/Info.plist": []})


if __name__ == "__main__":
    unittest.main()
