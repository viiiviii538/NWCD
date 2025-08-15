import unittest
from unittest.mock import patch, MagicMock
import system_utils as network_speed


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

    @patch.object(network_speed, 'speedtest')
    def test_measure_speed_config_error(self, mock_speedtest):
        class DummyErr(Exception):
            pass
        mock_speedtest.ConfigRetrievalError = DummyErr
        inst = MagicMock()
        inst.get_best_server.side_effect = DummyErr('err')
        mock_speedtest.Speedtest.return_value = inst
        result = network_speed.measure_speed()
        self.assertIsNone(result)

    @patch.object(network_speed, 'speedtest')
    def test_measure_speed_generic_error(self, mock_speedtest):
        class DummyErr(Exception):
            pass
        mock_speedtest.ConfigRetrievalError = DummyErr
        inst = MagicMock()
        inst.get_best_server.side_effect = Exception('fail')
        mock_speedtest.Speedtest.return_value = inst
        result = network_speed.measure_speed()
        self.assertIsNone(result)


if __name__ == '__main__':
    unittest.main()
