import base64
import gzip
import json
import os
import urllib.request


SSM_PREFIX = "ssm://"
_ssm_client = None
_resolved_env = {}


def _get_ssm_client():
    global _ssm_client
    if _ssm_client is None:
        import boto3

        _ssm_client = boto3.client("ssm")
    return _ssm_client


def resolve_env(name):
    value = os.environ.get(name)
    if not value:
        return None
    if not value.startswith(SSM_PREFIX):
        return value
    if name in _resolved_env:
        return _resolved_env[name]

    parameter_name = value.removeprefix(SSM_PREFIX)
    if not parameter_name:
        raise ValueError(f"{name} has empty SSM parameter name")

    response = _get_ssm_client().get_parameter(
        Name=parameter_name,
        WithDecryption=True,
    )
    resolved = response["Parameter"]["Value"]
    _resolved_env[name] = resolved
    return resolved


def lambda_handler(event, context):
    try:
        slack_webhook_url = resolve_env("SLACK_WEBHOOK_URL")
    except Exception as e:
        print(f"Failed to resolve SLACK_WEBHOOK_URL: {type(e).__name__}")
        return {"statusCode": 500, "body": "Failed to resolve SLACK_WEBHOOK_URL"}

    if not slack_webhook_url:
        print("SLACK_WEBHOOK_URL is not set")
        return {"statusCode": 500, "body": "SLACK_WEBHOOK_URL is not set"}

    # CloudWatch Logs Subscription Filter sends base64 encoded gzipped data
    compressed_payload = base64.b64decode(event["awslogs"]["data"])
    uncompressed_payload = gzip.decompress(compressed_payload)
    log_data = json.loads(uncompressed_payload)

    log_group = log_data.get("logGroup", "Unknown")
    log_stream = log_data.get("logStream", "Unknown")
    log_events = log_data.get("logEvents", [])

    for log_event in log_events:
        message = log_event.get("message", "")
        timestamp = log_event.get("timestamp", 0)

        slack_message = {
            "attachments": [
                {
                    "color": "danger",
                    "title": f":rotating_light: Error detected in {log_group}",
                    "fields": [
                        {"title": "Log Group", "value": log_group, "short": True},
                        {"title": "Log Stream", "value": log_stream, "short": True},
                        {"title": "Message", "value": message[:1000], "short": False},
                    ],
                    "footer": "CloudWatch Logs",
                    "ts": timestamp // 1000,
                }
            ]
        }

        req = urllib.request.Request(
            slack_webhook_url,
            data=json.dumps(slack_message).encode("utf-8"),
            headers={"Content-Type": "application/json"},
            method="POST",
        )

        try:
            with urllib.request.urlopen(req) as response:
                print(f"Slack notification sent: {response.status}")
        except Exception as e:
            print(f"Failed to send Slack notification: {e}")

    return {"statusCode": 200, "body": f"Processed {len(log_events)} log events"}
