import sys
import unittest
from pathlib import Path
from unittest.mock import patch


sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import meowart_api


class CliDefaultsTest(unittest.TestCase):
    def test_character_multi_view_run_has_optional_context_defaults(self):
        argv = [
            "meowart_api.py",
            "character-multi-view-run",
            "--reference-image",
            "character.png",
        ]

        with patch.object(sys, "argv", argv):
            args = meowart_api.parse_args()

        self.assertIsNone(args.project_id)
        self.assertIsNone(args.thread_id)


if __name__ == "__main__":
    unittest.main()
