import unittest
from unittest.mock import patch
import scanner_check

class ScannerCheckTest(unittest.TestCase):
    def test_missing_tools(self):
        with patch('scanner_check.shutil.which', return_value=None):
            missing = scanner_check.check_missing_tools()
            self.assertEqual(set(missing), {'nmap'})

def load_tests(loader, tests, pattern):
    suite = unittest.TestSuite()
    suite.addTests(loader.loadTestsFromTestCase(ScannerCheckTest))
    return suite

if __name__ == '__main__':
    unittest.main()
