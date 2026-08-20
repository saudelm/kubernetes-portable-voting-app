import sys
import unittest
from pathlib import Path

VOTE_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(VOTE_DIR))

import app as vote_app  # noqa: E402


class FakeRedis:
    def __init__(self):
        self.items = []

    def ping(self):
        return True

    def rpush(self, key, value):
        self.items.append((key, value))


class VoteAppTest(unittest.TestCase):
    def setUp(self):
        self.redis = FakeRedis()
        vote_app.get_redis = lambda: self.redis
        self.client = vote_app.app.test_client()

    def test_health_and_readiness(self):
        self.assertEqual(self.client.get("/healthz").status_code, 200)
        self.assertEqual(self.client.get("/readyz").status_code, 200)

    def test_page_uses_only_local_assets(self):
        response = self.client.get("/")
        self.assertEqual(response.status_code, 200)
        self.assertNotIn(b"code.jquery.com", response.data)
        self.assertNotIn(b"cdnjs", response.data)

    def test_vote_validation_and_cookie_flags(self):
        invalid = self.client.post("/", data={"vote": "x"})
        self.assertEqual(invalid.status_code, 400)

        valid = self.client.post("/", data={"vote": "a"})
        self.assertEqual(valid.status_code, 200)
        self.assertEqual(len(self.redis.items), 1)
        cookie = valid.headers.get("Set-Cookie", "")
        self.assertIn("HttpOnly", cookie)
        self.assertIn("SameSite=Lax", cookie)


if __name__ == "__main__":
    unittest.main()
