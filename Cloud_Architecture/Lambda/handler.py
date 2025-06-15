import json
import uuid
import boto3
from decimal import Decimal                    # ← NEW

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table("ForzaRunLogs")

def handler(event, context):
    try:
        # Parse the JSON while converting *all* numbers to Decimal
        body = json.loads(
            event.get("body", "{}"),
            parse_float=Decimal,
            parse_int=Decimal,
        )

        item = {
            "run_id": str(uuid.uuid4()),
            "user": body.get("user"),
            "timestamp": body.get("timestamp"),
            "metrics": body.get("metrics"),
        }

        table.put_item(Item=item)

        return {
            "statusCode": 200,
            "body": json.dumps(item, default=str),   # Decimal → str for the response
        }

    except Exception as e:
        # CloudWatch will show the full error string
        print("❌ ERROR:", str(e))
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)}),
        }

