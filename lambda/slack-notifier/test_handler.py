import contextlib
import io
import os
import unittest
from unittest.mock import Mock, patch

import handler


class ResolveEnvTests(unittest.TestCase):
    def setUp(self):
        handler._resolved_env.clear()
        handler._ssm_client = None

    def test_resolve_env_returns_plain_value(self):
        with patch.dict(os.environ, {"SLACK_WEBHOOK_URL": "https://example.com"}, clear=True):
            self.assertEqual(handler.resolve_env("SLACK_WEBHOOK_URL"), "https://example.com")

    def test_resolve_env_fetches_ssm_value_once(self):
        ssm = Mock()
        ssm.get_parameter.return_value = {
            "Parameter": {
                "Value": "https://hooks.slack.com/services/test",
            }
        }

        with patch.dict(os.environ, {"SLACK_WEBHOOK_URL": "ssm:///zuntalk/dev/slack-webhook-url"}, clear=True):
            with patch.object(handler, "_get_ssm_client", return_value=ssm):
                self.assertEqual(
                    handler.resolve_env("SLACK_WEBHOOK_URL"),
                    "https://hooks.slack.com/services/test",
                )
                self.assertEqual(
                    handler.resolve_env("SLACK_WEBHOOK_URL"),
                    "https://hooks.slack.com/services/test",
                )

        ssm.get_parameter.assert_called_once_with(
            Name="/zuntalk/dev/slack-webhook-url",
            WithDecryption=True,
        )

    def test_lambda_handler_returns_500_when_resolution_fails(self):
        with patch.dict(os.environ, {"SLACK_WEBHOOK_URL": "ssm:///zuntalk/dev/slack-webhook-url"}, clear=True):
            with patch.object(handler, "_get_ssm_client", side_effect=Exception("boom")):
                with contextlib.redirect_stdout(io.StringIO()):
                    response = handler.lambda_handler({}, None)

        self.assertEqual(response["statusCode"], 500)
        self.assertEqual(response["body"], "Failed to resolve SLACK_WEBHOOK_URL")


if __name__ == "__main__":
    unittest.main()
