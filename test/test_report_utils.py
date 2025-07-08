import unittest
import json
from pathlib import Path
import tempfile

from report_utils import generate_topology_diagram, generateTopologyDiagram


class ReportUtilsGenerateTopologyTest(unittest.TestCase):
    def test_generate_topology_diagram_creates_file(self):
        data = {"hosts": [{"ip": "192.168.1.2"}]}
        with tempfile.TemporaryDirectory() as tmpdir:
            input_path = Path(tmpdir) / "scan.json"
            output_path = Path(tmpdir) / "out.dot"
            with open(input_path, "w", encoding="utf-8") as f:
                json.dump(data, f)

            result = generate_topology_diagram(str(input_path), str(output_path))

            self.assertEqual(result, str(output_path))
            self.assertTrue(output_path.exists())
            self.assertGreater(output_path.stat().st_size, 0)

    def test_generateTopologyDiagram_alias(self):
        data = {"hosts": []}
        with tempfile.TemporaryDirectory() as tmpdir:
            input_path = Path(tmpdir) / "scan.json"
            output_path = Path(tmpdir) / "alias.dot"
            with open(input_path, "w", encoding="utf-8") as f:
                json.dump(data, f)

            result = generateTopologyDiagram(str(input_path), str(output_path))

            self.assertEqual(result, str(output_path))
            self.assertTrue(output_path.exists())


if __name__ == "__main__":
    unittest.main()

