import datetime as dt
import importlib.util
import sys
import unittest
from pathlib import Path


SCRIPT = Path(__file__).parents[1] / "scripts/publication_expiry.py"
SPEC = importlib.util.spec_from_file_location("publication_expiry", SCRIPT)
expiry = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = expiry
SPEC.loader.exec_module(expiry)


class FakeClient:
    def __init__(self, record, config):
        self.record = record
        self.config = config
        self.deleted = False
        self.puts = []

    def dns_record(self, zone_id, record_id):
        return None if self.deleted else self.record

    def delete_dns(self, zone_id, record_id):
        self.deleted = True

    def tunnel_config(self, tunnel_id):
        return self.config

    def put_tunnel_config(self, tunnel_id, config):
        self.config = config
        self.puts.append(config)


class ExpiryTests(unittest.TestCase):
    def setUp(self):
        self.state = {
            "hostname": "review.bekkevard.me",
            "zone_id": "zone",
            "tunnel_id": "tunnel",
            "dns_record_id": "record",
            "dns_content": "tunnel.cfargotunnel.com",
            "service": "http://localhost:8766",
            "origin_host": "europa",
            "origin_unit": "personal-edge-review-origin.service",
            "created_at": "2026-08-16T00:00:00Z",
            "expires_at": "2026-08-17T00:00:00Z",
        }
        self.record = {
            "type": "CNAME",
            "name": "review.bekkevard.me",
            "content": "tunnel.cfargotunnel.com",
        }
        self.config = {
            "ingress": [
                {"hostname": "odin.bekkevard.me", "service": "http://localhost:8080"},
                {"hostname": "review.bekkevard.me", "service": "http://localhost:8766"},
                {"service": "http_status:404"},
            ],
            "warp-routing": {"enabled": False},
        }

    def test_default_expiry_is_24_hours(self):
        now = dt.datetime(2026, 8, 17, tzinfo=dt.timezone.utc)
        self.assertEqual(expiry.parse_instant(None, now), now + dt.timedelta(hours=24))

    def test_cleanup_preserves_unrelated_ingress_and_fallback(self):
        client = FakeClient(self.record, self.config)
        stopped = []
        expiry.process_record(client, self.state, lambda host, unit: stopped.append((host, unit)))
        self.assertTrue(client.deleted)
        self.assertEqual(
            client.config["ingress"],
            [
                {"hostname": "odin.bekkevard.me", "service": "http://localhost:8080"},
                {"service": "http_status:404"},
            ],
        )
        self.assertEqual(stopped, [("europa", "personal-edge-review-origin.service")])

    def test_cleanup_is_idempotent_after_provider_removal(self):
        config = {
            "ingress": [
                {"hostname": "odin.bekkevard.me", "service": "http://localhost:8080"},
                {"service": "http_status:404"},
            ]
        }
        client = FakeClient(None, config)
        stopped = []
        expiry.process_record(client, self.state, lambda host, unit: stopped.append((host, unit)))
        self.assertEqual(client.puts, [])
        self.assertEqual(stopped, [("europa", "personal-edge-review-origin.service")])

    def test_dns_ownership_mismatch_fails_before_mutation(self):
        record = {**self.record, "content": "somewhere-else.example"}
        client = FakeClient(record, self.config)
        with self.assertRaisesRegex(expiry.ExpiryError, "DNS ownership mismatch"):
            expiry.process_record(client, self.state)
        self.assertFalse(client.deleted)
        self.assertEqual(client.puts, [])

    def test_ingress_ownership_mismatch_fails_before_dns_delete(self):
        config = {
            **self.config,
            "ingress": [
                {"hostname": "review.bekkevard.me", "service": "http://localhost:9999"},
                {"service": "http_status:404"},
            ],
        }
        client = FakeClient(self.record, config)
        with self.assertRaisesRegex(expiry.ExpiryError, "ingress ownership mismatch"):
            expiry.process_record(client, self.state)
        self.assertFalse(client.deleted)

    def test_invalid_origin_unit_is_rejected(self):
        with self.assertRaisesRegex(expiry.ExpiryError, "unsafe origin unit"):
            expiry.validate_origin("europa", "review.service; reboot")


if __name__ == "__main__":
    unittest.main()
