"""Placeholder regional service.

GET /health/deep  -> writes and reads a probe item in THIS region's copy of the
                     table. 200 if both work, 503 if not. Checks in-region
                     dependencies only (design decision D4).
anything else     -> 200 with the region name, so you can see which region
                     served you.
"""
import json
import os
import time

import boto3
from botocore.config import Config

TABLE_NAME = os.environ["TABLE_NAME"]
REGION = os.environ["AWS_REGION"]  # set automatically by Lambda

# Fail fast: the load balancer gives the health check 5 seconds, so a slow
# DynamoDB call must turn into a 503, not a timeout.
dynamodb = boto3.client(
    "dynamodb",
    region_name=REGION,
    config=Config(connect_timeout=1, read_timeout=2, retries={"max_attempts": 1}),
)


def respond(status, body):
    # Response shape the Application Load Balancer expects from a Lambda.
    return {
        "statusCode": status,
        "statusDescription": f"{status} {'OK' if status == 200 else 'Service Unavailable'}",
        "isBase64Encoded": False,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }


def deep_health():
    now = str(time.time())
    key = {"pk": {"S": f"HEALTH#{REGION}"}, "sk": {"S": "probe"}}
    try:
        dynamodb.put_item(
            TableName=TABLE_NAME,
            Item={**key, "checked_at": {"S": now}, "writer_region": {"S": REGION}},
        )
        item = dynamodb.get_item(TableName=TABLE_NAME, Key=key, ConsistentRead=True).get("Item")
        if not item or item["checked_at"]["S"] != now:
            return respond(503, {"region": REGION, "healthy": False, "reason": "read did not return the write"})
    except Exception as e:  # any DynamoDB problem means this region is not healthy
        return respond(503, {"region": REGION, "healthy": False, "reason": type(e).__name__})
    return respond(200, {"region": REGION, "healthy": True})


def handler(event, context):
    if event.get("path") == "/health/deep":
        return deep_health()
    return respond(200, {"region": REGION, "message": "hello from " + REGION})
