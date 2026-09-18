import unittest

from changelog_lint import lint

GOOD = "- Fixed retry ([#12](https://github.com/Salkimmich/nono-pr-demo/issues/12))\n"
BAD = "- Fixed retry ([#12](https://github.com/Salkimmich/nono-pr-demo/issue/12))\n"


class LintTests(unittest.TestCase):
    def test_plural_issues_path_is_accepted(self):
        self.assertEqual(lint(GOOD), [])

    def test_singular_issue_path_is_reported(self):
        problems = lint(BAD)
        self.assertEqual(len(problems), 1)
        self.assertIn("issue/12", problems[0])


if __name__ == "__main__":
    unittest.main()
