import unittest
from unittest.mock import patch
from pathlib import Path
import tempfile

import pytest
pytest.importorskip("graphviz")

import generate_topology


class GenerateTopologyTest(unittest.TestCase):
    def test_build_graph_from_discover_hosts(self):
        data = {"hosts": [{"ip": "192.168.1.2", "vendor": "X"}]}
        g = generate_topology.build_graph(data)
        src = g.source
        self.assertIn("192.168.1.2", src)
        self.assertIn('LAN -- "192.168.1.2"', src)

    def test_save_graph_dot(self):
        g = generate_topology.Graph("test")
        with tempfile.TemporaryDirectory() as tmpdir:
            path = Path(tmpdir) / "out.dot"
            generate_topology.save_graph(g, str(path))
            self.assertTrue(path.exists())
            self.assertGreater(path.stat().st_size, 0)

    @patch.object(generate_topology.Graph, "render")
    def test_save_graph_png_calls_render(self, mock_render):
        g = generate_topology.Graph("test")
        generate_topology.save_graph(g, "out.png")
        mock_render.assert_called_once()


if __name__ == "__main__":
    unittest.main()
