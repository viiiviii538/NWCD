import unittest
from unittest.mock import patch, MagicMock
import network_speed

class NetworkSpeedTest(unittest.TestCase):
    @patch.object(network_speed, 'speedtest')
    def test_measure_speed(self, mock_speedtest):
        MockSpeedtest = MagicMock()
        mock_speedtest.Speedtest = MockSpeedtest
        inst = MockSpeedtest.return_value
        inst.download.return_value = 100_000_000
        inst.upload.return_value = 20_000_000
        inst.results = MagicMock(ping=15.0)
        inst.get_best_server.return_value = {}
        result = network_speed.measure_speed()
        self.assertAlmostEqual(result['download'], 100.0)
        self.assertAlmostEqual(result['upload'], 20.0)
        self.assertEqual(result['ping'], 15.0)

if __name__ == '__main__':
    unittest.main()
