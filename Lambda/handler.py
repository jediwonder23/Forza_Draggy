import json, boto3, uuid

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('ForzaRunLogs')

def handler(event, context):
    body = json.loads(event.get('body', '{}'))
    item = {
        'run_id': str(uuid.uuid4()),
        'user': body.get('user'),
        'timestamp': body.get('timestamp'),
        'metrics': body.get('metrics'),
    }
    table.put_item(Item=item)
    return { 'statusCode': 200, 'body': json.dumps(item) }
