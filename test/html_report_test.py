import unittest
from generate_html_report import generate_html_report


class HtmlReportGeneratorTest(unittest.TestCase):
    def test_basic_structure(self):
        devices = [
            {"device": "dev1", "open_ports": ["80"], "countries": ["US"]},
            {"device": "dev2", "open_ports": [], "countries": []},
        ]
        html = generate_html_report(devices)
        self.assertTrue(html.startswith("<html>"))
        self.assertIn("<table>", html)
        self.assertIn("<td>dev1</td>", html)
        self.assertIn("<td>9.8</td>", html)  # score for dev1
        self.assertTrue(html.endswith("</html>"))


if __name__ == "__main__":
    unittest.main()
