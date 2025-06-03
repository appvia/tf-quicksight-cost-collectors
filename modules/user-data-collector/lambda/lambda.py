import json
import boto3
import os
import urllib3
from urllib.parse import quote
from typing import Dict, Any


def load_configuration() -> Dict[str, Any]:
    """Load and validate environment variables."""
    config = {
        "dynamodb_table_name": os.environ.get(
            "DYNAMODB_TABLE_NAME", "user-tenant-table"
        ),
        "gitlab_base_url": os.environ.get(
            "GITLAB_BASE_URL", "https://gitlab.example.com"
        ),
        "gitlab_project_id": os.environ.get("GITLAB_PROJECT_ID", "13083"),
        "gitlab_access_token": os.environ.get("GITLAB_ACCESS_TOKEN"),
        "gitlab_file_path": os.environ.get("GITLAB_FILE_PATH", "users.json"),
        "gitlab_ref": os.environ.get("GITLAB_REF", "main"),
    }

    # Validate required configuration
    required_fields = ["gitlab_access_token"]
    missing_fields = [field for field in required_fields if not config[field]]

    if missing_fields:
        raise ValueError(
            f"Missing required environment variables: {', '.join(missing_fields)}"
        )

    return config


def fetch_user_data_from_gitlab(config: Dict[str, Any]):
    """Fetch user data from GitLab repository"""
    # URL encode the file path
    encoded_file_path = quote(config["gitlab_file_path"], safe="")

    # Construct the GitLab API URL
    url = f"{config['gitlab_base_url']}/api/v4/projects/{config['gitlab_project_id']}/repository/files/{encoded_file_path}/raw?ref={config['gitlab_ref']}"

    headers = {"PRIVATE-TOKEN": config["gitlab_access_token"]}

    http = urllib3.PoolManager()
    try:
        response = http.request("GET", url, headers=headers)
        if response.status == 200:
            return json.loads(response.data.decode("utf-8"))
        elif response.status == 401:
            raise Exception("Unauthorized: Check your GitLab access token")
        elif response.status == 404:
            raise Exception(
                f"File not found: {config['gitlab_file_path']} in project {config['gitlab_project_id']} at ref: {config['gitlab_ref']}"
            )
        else:
            raise Exception(
                f"GitLab API request failed with status {response.status}: {response.data.decode('utf-8')}"
            )

    except json.JSONDecodeError as e:
        raise Exception(f"Failed to parse JSON from GitLab response: {str(e)}")
    except Exception as e:
        raise Exception(f"Error fetching data from GitLab: {str(e)}")


def handler(event, context):
    """Main Lambda handler function."""
    try:
        # Load configuration
        config = load_configuration()

        # Initialize DynamoDB table
        dynamodb = boto3.resource("dynamodb")
        table = dynamodb.Table(config["dynamodb_table_name"])

        # Fetch user data from GitLab
        data = fetch_user_data_from_gitlab(config)
        print(
            f"Successfully fetched user data from GitLab: {config['gitlab_base_url']}/api/v4/projects/{config['gitlab_project_id']}/repository/files/{config['gitlab_file_path']}"
        )
    except Exception as e:
        print(f"Error fetching data from GitLab: {str(e)}")
        return {
            "statusCode": 500,
            "body": json.dumps(
                {"error": f"Failed to fetch data from GitLab: {str(e)}"}
            ),
        }

    users = data.get("users", [])
    success_count = 0
    failure_count = 0

    for user in users:
        email = user.get("email")
        tenant = user.get("tenant")

        if email and tenant:
            try:
                table.put_item(Item={"email": email, "tenant": tenant})
                print(f"Successfully stored user: {email}")
                success_count += 1
            except Exception as e:
                print(f"Error storing user {email}: {str(e)}")
                failure_count += 1
        else:
            print(f"Skipping user due to missing email or tenant: {user}")
            failure_count += 1

    response_body = {
        "message": f"Processed {len(users)} users. Succeeded: {success_count}, Failed: {failure_count}",
        "succeeded_count": success_count,
        "failed_count": failure_count,
    }
    print(response_body)

    return {
        "statusCode": 200
        if failure_count == 0
        else 207,  # 207 Multi-Status if there were failures
        "body": json.dumps(response_body),
    }


def generate_mock_data():
    """Generate mock user data for testing purposes."""
    # open file with example response
    with open("example-response.json", "r") as file:
        return json.load(file)
