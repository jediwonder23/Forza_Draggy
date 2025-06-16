import boto3
import json
from boto3.dynamodb.conditions import Attr

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table("ForzaRunLogs")

def handler(event, context):
    try:
        user = event["requestContext"]["authorizer"]["jwt"]["claims"]["email"]
        response = table.scan(
            FilterExpression=Attr("user").eq(user)
        )
        return {
            "statusCode": 200,
            "body": json.dumps(response["Items"], default=str)
        }
    except Exception as e:
        print("ERROR:", e)
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)})
        }
