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

    def test_build_graph_with_paths(self):
        data = {
            "hosts": [
                {
                    "ip": "192.168.1.3",
                    "hostname": "Host",
                    "vendor": "V",
                    "paths": [["LAN", "Switch1"]],
                }
            ]
        }
        g = generate_topology.build_graph(data)
        src = g.source
        self.assertIn('LAN -- Switch1', src)
        self.assertIn('Switch1 -- "192.168.1.3"', src)
        self.assertIn('label="192.168.1.3\nHost\nV"', src)

    def test_build_graph_multiple_paths_and_shape(self):
        data = {
            "hosts": [
                {
                    "ip": "192.168.1.4",
                    "hostname": "Host2",
                    "vendor": "Vendor2",
                    "paths": [
                        ["LAN", "SwitchA", "RouterA"],
                        ["LAN", "SwitchB"],
                    ],
                }
            ]
        }
        g = generate_topology.build_graph(data)
        src = g.source
        self.assertIn('LAN -- SwitchA', src)
        self.assertIn('SwitchA -- RouterA', src)
        self.assertIn('RouterA -- "192.168.1.4"', src)
        self.assertIn('LAN -- SwitchB', src)
        self.assertIn('SwitchB -- "192.168.1.4"', src)
        self.assertIn('node [shape=ellipse]', src)

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
