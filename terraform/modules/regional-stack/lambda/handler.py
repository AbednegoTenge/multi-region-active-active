"""Placeholder regional service.

GET /health/deep  -> writes and reads a probe item in THIS region's copy of the
                     table, then checks the data is fresh: the other regions'
                     probe rows (which arrive here by replication) must be
                     recent. 200 if all of that works, 503 if not.
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

REGIONS = ["us-east-1", "us-west-2", "eu-west-1"]
PEERS = [r for r in REGIONS if r != REGION]

# Every region writes its probe row on each health check (every few seconds),
# so a healthy, replicating region always holds a peer row only seconds old.
# If even the NEWEST peer row is older than this, replication into this
# region has stopped and our data is stale.
MAX_STALENESS_SECONDS = 30

# Fail fast: the load balancer gives the health check 2 seconds, so a slow
# DynamoDB call must turn into a 503, not a timeout.
dynamodb = boto3.client(
    "dynamodb",
    region_name=REGION,
    config=Config(connect_timeout=0.5, read_timeout=1, retries={"max_attempts": 1}),
)


def respond(status, body):
    if status != 200:
        print(json.dumps(body))  # lands in CloudWatch Logs, so failed health checks explain themselves
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
        lag = replication_lag(float(now))
    except Exception as e:  # any DynamoDB problem means this region is not healthy
        return respond(503, {"region": REGION, "healthy": False, "reason": type(e).__name__})
    if lag > MAX_STALENESS_SECONDS:
        return respond(503, {"region": REGION, "healthy": False, "reason": "stale data", "lag_seconds": round(lag)})
    return respond(200, {"region": REGION, "healthy": True, "lag_seconds": round(lag)})


def replication_lag(now):
    """Seconds since the newest peer probe row was written.

    We use the NEWEST peer row, not the oldest. If another region is down, its
    row goes stale too, and every healthy region would fail its own check and
    take itself out. Only when ALL peer rows are old do we blame ourselves.
    """
    resp = dynamodb.batch_get_item(RequestItems={TABLE_NAME: {
        "Keys": [{"pk": {"S": f"HEALTH#{peer}"}, "sk": {"S": "probe"}} for peer in PEERS],
    }})
    items = resp["Responses"].get(TABLE_NAME, [])
    if not items:
        return 0  # first deploy: no peer has written yet, nothing to compare
    newest = max(float(i["checked_at"]["S"]) for i in items)
    return now - newest


def handler(event, context):
    if event.get("path") == "/health/deep":
        return deep_health()
    return respond(200, {"region": REGION, "message": "hello from " + REGION})
