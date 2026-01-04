import base64
import gzip
import json
import os
import urllib.request


def lambda_handler(event, context):
    slack_webhook_url = os.environ.get("SLACK_WEBHOOK_URL")
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
