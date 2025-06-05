import json
import boto3
import os
import datetime
import urllib3
from typing import Dict, List, Any


def load_configuration() -> Dict[str, Any]:
    """Load and validate environment variables."""
    config = {
        "gitlab_domain": os.environ.get("GITLAB_DOMAIN"),
        "gitlab_port": os.environ.get("GITLAB_PORT"),
        "gitlab_scheme": os.environ.get("GITLAB_SCHEME"),
        "gitlab_token_secret_name": os.environ.get("GITLAB_TOKEN_SECRET_NAME"),
        "gitlab_required_fields": os.environ.get("GITLAB_REQUIRED_FIELDS", "all"),
        "gitlab_external_users": os.environ.get(
            "GITLAB_EXTERNAL_USERS", "false"
        ).lower()
        == "true",
        "gitlab_active_users_only": os.environ.get(
            "GITLAB_ACTIVE_USERS_ONLY", "false"
        ).lower()
        == "true",
        "output_bucket": os.environ.get("OUTPUT_BUCKET"),
        "mock_mode": os.environ.get("MOCK_MODE", "false").lower() == "true",
    }

    # Validate required configuration
    required_fields = [
        "gitlab_domain",
        "gitlab_port",
        "gitlab_scheme",
        "gitlab_token_secret_name",
        "output_bucket",
    ]
    missing_fields = [field for field in required_fields if not config[field]]

    if missing_fields:
        raise ValueError(
            f"Missing required environment variables: {', '.join(missing_fields)}"
        )

    return config


def fetch_gitlab_users(api_url: str, token: str) -> List[Dict[str, Any]]:
    """Fetch users from GitLab API."""
    http = urllib3.PoolManager()
    response = http.request("GET", api_url, headers={"PRIVATE-TOKEN": token})

    if response.status != 200:
        raise Exception(
            f"Failed to fetch users from GitLab API: {response.status} - {response.data.decode('utf-8')}"
        )

    users_data = json.loads(response.data.decode("utf-8"))
    if not users_data:
        print("No users found in GitLab API response.")
        return []

    return users_data


def process_user_data(user: Dict[str, Any], timestamp_iso: str) -> Dict[str, Any]:
    """Process and transform user data from GitLab API."""
    user_extract = {
        "id": user.get("id"),
        "email": user.get("email"),
        "name": user.get("name"),
        "username": user.get("username"),
        "state": user.get("state"),
        "collection_timestamp": timestamp_iso,
    }

    # Try to get tenant information
    try:
        user_extract["tenant"] = get_user_tenant(user_extract["email"])
    except Exception as e:
        print(f"Error fetching tenant for user {user_extract['email']}: {str(e)}")
        user_extract["tenant"] = "unassigned"

    return user_extract


def validate_user_data(user_data: Dict[str, Any], required_fields: str) -> bool:
    """Validate user data against required fields."""
    if required_fields == "all":
        # Ensure all fields have a value
        return all(user_data.values())
    elif required_fields != "all":
        # Check if any of the required fields are not present
        return all(field in user_data for field in required_fields.split(","))
    else:
        raise ValueError(
            "GITLAB_REQUIRED_FIELDS must be 'all' or a comma-separated list of fields"
        )


def handler(event, context):
    """Main Lambda handler function."""
    try:
        # Load configuration
        config = load_configuration()

        # Initialize clients
        s3_client = boto3.client("s3")

        # Generate timestamps
        current_time = datetime.datetime.now()
        timestamp_iso = current_time.isoformat()
        timestamp_filename = current_time.strftime("%Y%m%d_%H%M")
        partition_month = current_time.strftime("%Y-%m")

        # Get GitLab token from Secrets Manager
        secrets_manager = boto3.client("secretsmanager")
        secret_value = secrets_manager.get_secret_value(
            SecretId=config["gitlab_token_secret_name"]
        )
        gitlab_token = secret_value["SecretString"]

        # Build API URL and fetch users
        gitlab_api_url = (
            f"{config['gitlab_scheme']}://{config['gitlab_domain']}:{config['gitlab_port']}"
            f"/api/v4/users?active={str(config['gitlab_active_users_only']).lower()}"
            f"&external={str(config['gitlab_external_users']).lower()}"
        )

        if config["mock_mode"]:
            print("Mock mode is enabled. Skipping data collection.")
            users_data = generate_mock_data()
        else:
            print("Fetching users from GitLab API...")
            users_data = fetch_gitlab_users(gitlab_api_url, gitlab_token)

        if not users_data:
            return {
                "statusCode": 200,
                "body": json.dumps({"message": "No users found."}),
            }

        # Process each user
        processed_count = 0
        for user in users_data:
            user_extract = process_user_data(user, timestamp_iso)

            # Validate user data against required fields
            if not validate_user_data(user_extract, config["gitlab_required_fields"]):
                continue

            # Upload to S3
            s3_key = f"gitlab/{partition_month}/user-{user_extract['id']}-{timestamp_filename}.json"
            s3_client.put_object(
                Bucket=config["output_bucket"],
                Key=s3_key,
                Body=json.dumps(user_extract),
            )
            processed_count += 1

        return {
            "statusCode": 200,
            "body": json.dumps(
                {"message": f"Successfully processed {processed_count} users."}
            ),
        }

    except Exception as e:
        print(f"Error in handler: {str(e)}")
        raise


def get_user_tenant(email):
    user_data_dynamodb_table_name = os.environ.get(
        "USER_DATA_DYNAMODB_TABLE_NAME", "user-data-tenant-table"
    )
    # get the users tenant from the user data dynamodb table
    try:
        dynamodb = boto3.resource("dynamodb")

        table = dynamodb.Table(user_data_dynamodb_table_name)
        response = table.get_item(Key={"email": email})
        if "Item" not in response:
            raise ValueError(f"No tenant found for user with email: {email}")
        else:
            print(f"Tenant found for user {email}: {response['Item'].get('tenant')}")
            return response["Item"].get("tenant")
    except Exception as e:
        raise Exception(f"Error fetching tenant for user {email}: {str(e)}")


def generate_mock_data() -> List[Dict[str, Any]]:
    """Generate mock user data for testing purposes."""
    # load example file example-response.json
    with open("example-response.json", "r") as f:
        return json.load(f)
