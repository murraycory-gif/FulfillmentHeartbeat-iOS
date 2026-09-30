"""Opt-out skip for the cook sender. Stdlib only."""

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from send_push import should_deliver


class OptOutSkip(unittest.TestCase):
    def test_skips_opted_out_token(self):
        self.assertFalse(should_deliver({"token": "ab" * 32, "optedOut": True}))

    def test_sends_when_opted_in_or_unset(self):
        token = "ab" * 32
        self.assertTrue(should_deliver({"token": token, "optedOut": False}))
        self.assertTrue(should_deliver({"token": token}))

    def test_skips_blank_token(self):
        self.assertFalse(should_deliver({"token": "  ", "optedOut": False}))
        self.assertFalse(should_deliver({}))


if __name__ == "__main__":
    unittest.main()
