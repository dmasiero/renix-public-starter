import time
import unittest

from custom_builds import SourceRuntime, check_all, discover_source, normalize, validate


class FakeRuntime(SourceRuntime):
    def __init__(self, response=None, delay=0, error=None):
        self.response = response or {}
        self.delay = delay
        self.error = error

    def _result(self):
        if self.delay:
            time.sleep(self.delay)
        if self.error:
            raise self.error
        return self.response

    def json(self, _url):
        return self._result()

    def redirected_url(self, _url):
        return self._result()["url"]

    def last_modified_date(self, _url):
        return self._result()["last-modified-date"]

    def flake_version(self, _flake, _path):
        return self._result()["version"]


class CustomBuildLifecycleTests(unittest.TestCase):
    def test_normalize_supplies_display_name_and_manual_update(self):
        build = normalize({"id": "tool", "attrName": "tool", "source": {"type": "pypi", "package": "tool"}})
        self.assertEqual("tool", build["displayName"])
        self.assertEqual("manual", build["update"]["type"])

    def test_manifest_rejects_missing_and_unsupported_source_fields(self):
        with self.assertRaisesRegex(ValueError, "requires attrName"):
            validate({"id": "tool", "source": {"type": "pypi", "package": "tool"}})
        with self.assertRaisesRegex(ValueError, "unsupported source type"):
            validate({"id": "tool", "attrName": "tool", "source": {"type": "mystery"}})
        with self.assertRaisesRegex(ValueError, "github-release source requires repo"):
            validate({"id": "tool", "attrName": "tool", "source": {"type": "github-release", "owner": "o"}})

    def test_source_adapters_read_expected_versions(self):
        cases = [
            ({"type": "github-release", "owner": "o", "repo": "r", "stripV": True}, {"tag_name": "v0.9"}, "0.9"),
            ({"type": "npm", "package": "p"}, {"dist-tags": {"latest": "1.0"}}, "1.0"),
            ({"type": "crates", "package": "p"}, {"crate": {"newest_version": "1.1"}}, "1.1"),
            ({"type": "pypi", "package": "p"}, {"info": {"version": "1.2"}}, "1.2"),
            ({"type": "http-redirect-regex", "url": "u", "regex": ".*/([0-9.]+)\\.deb"}, {"url": "https://x/1.3.deb"}, "1.3"),
            ({"type": "http-header-last-modified", "url": "u"}, {"last-modified-date": "2026-01-02"}, "2026-01-02"),
            ({"type": "flake-input", "flake": "f", "versionPath": "p"}, {"version": "1.4"}, "1.4"),
        ]
        for source, response, expected in cases:
            with self.subTest(source=source["type"]):
                build = normalize({"id": "tool", "attrName": "tool", "source": source})
                self.assertEqual(expected, discover_source(build, FakeRuntime(response)))

    def test_checks_concurrently_but_preserves_manifest_order(self):
        builds = [
            {"id": "slow", "attrName": "slow", "source": {"type": "pypi", "package": "slow"}},
            {"id": "fast", "attrName": "fast", "source": {"type": "pypi", "package": "fast"}},
        ]
        results = check_all(builds, lambda _attr: "1.0", FakeRuntime({"info": {"version": "2.0"}}, delay=0.05), workers=2)
        self.assertEqual(["slow", "fast"], [item["build"]["id"] for item in results])

    def test_four_network_bound_checks_take_less_than_half_sequential_time(self):
        builds = [
            {"id": str(index), "attrName": str(index), "source": {"type": "pypi", "package": str(index)}}
            for index in range(4)
        ]
        started = time.monotonic()
        check_all(builds, lambda _attr: "1.0", FakeRuntime({"info": {"version": "2.0"}}, delay=0.05), workers=4)
        self.assertLess(time.monotonic() - started, 0.1)

    def test_adapter_failure_becomes_unknown(self):
        build = {"id": "tool", "attrName": "tool", "source": {"type": "pypi", "package": "tool"}}
        result = check_all([build], lambda _: "1.0", FakeRuntime(error=TimeoutError()))[0]
        self.assertEqual("unknown", result["latest"])


if __name__ == "__main__":
    unittest.main()
