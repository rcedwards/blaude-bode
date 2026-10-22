import pathlib
import subprocess
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
HELPER = ROOT / "bin/lib/frontmatter.sh"


class FrontmatterTests(unittest.TestCase):
    def parse(self, contents, key):
        with tempfile.NamedTemporaryFile(mode="w") as source:
            source.write(contents)
            source.flush()
            return subprocess.check_output(
                ["bash", "-c", 'source "$1"; frontmatter_get "$2" "$3"',
                 "frontmatter-test", str(HELPER), source.name, key], text=True,
            ).rstrip("\n")

    def test_block_chomping_indicators_preserve_content(self):
        for style in (">", ">-", ">+", "|", "|-", "|+"):
            with self.subTest(style=style):
                separator = " " if style.startswith(">") else "\n"
                expected = separator.join(("First line", "Second line"))
                self.assertEqual(self.parse(
                    f"---\ndescription: {style}\n  First line\n  Second line\n"
                    "name: example\n---\nBody\n", "description"), expected)
                self.assertEqual(self.parse(
                    f"---\nhooks:\n  pre-invoke: {style}\n    First line\n"
                    "    Second line\n---\n", "hooks.pre-invoke"), expected)

    def test_installed_skill_descriptions_remain_discoverable(self):
        for name, phrase in (("git-conventions", "commit"),
                             ("learn-by-doing", "learn")):
            with self.subTest(name=name):
                contents = (ROOT / "skills" / name / "SKILL.md").read_text()
                description = self.parse(contents, "description")
                self.assertIn(phrase, description.lower())
                self.assertGreater(len(description), 30)


if __name__ == "__main__":
    unittest.main()
