# nono-pr-demo

Live target for the nono Prague demo. A coding agent, running under nono, is asked to
make the tests pass and open a pull request. `changelog_lint.py` checks GitHub issue links
in `CHANGELOG.md`; `tests/test_lint.py` pins the correct behavior.

Run the tests: `python3 -m unittest -v`
