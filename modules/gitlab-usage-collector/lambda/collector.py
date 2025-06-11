import json
import boto3
import os
import datetime
import urllib3
from typing import Dict, List, Any, Callable


# Map metric types to their API endpoints
METRIC_ENDPOINTS = {
    "users": "/api/v4/users",
    "ci_minutes": "/api/v4/groups",  # We'll iterate through groups to get CI usage quotas
}


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
        "user_data_dynamodb_table_name": os.environ.get(
            "USER_DATA_DYNAMODB_TABLE_NAME", "user-data-tenant-table"
        ),
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

    if missing_fields and not config["mock_mode"]:
        raise ValueError(
            f"Missing required environment variables: {', '.join(missing_fields)}"
        )

    return config


def generate_mock_data(metric_type: str) -> Dict[str, List[Dict[str, Any]]]:
    """Generate mock data for testing purposes."""
    if metric_type == "users":
        try:
            with open("example-response.json", "r") as f:
                return {"data": json.load(f)}
        except FileNotFoundError:
            # Fallback mock data if file doesn't exist
            return {
                "data": [
                    {
                        "id": 1,
                        "email": "user1@example.com",
                        "name": "Test User 1",
                        "username": "testuser1",
                        "state": "active",
                    },
                    {
                        "id": 2,
                        "email": "user2@example.com",
                        "name": "Test User 2",
                        "username": "testuser2",
                        "state": "active",
                    },
                ]
            }

    return {"data": []}


def get_gitlab_token(config: Dict[str, Any]) -> str:
    """Get GitLab token from secrets manager."""
    try:
        secrets_manager = boto3.client("secretsmanager")
        secret_value = secrets_manager.get_secret_value(
            SecretId=config["gitlab_token_secret_name"]
        )
        return secret_value["SecretString"]
    except Exception as e:
        raise Exception(f"Error getting GitLab token from secrets manager: {str(e)}")


def fetch_gitlab_data(
    api_url: str, token: str, metric_type: str, config: Dict[str, Any] = None
) -> List[Dict[str, Any]]:
    """Fetch data from GitLab API."""
    http = urllib3.PoolManager()

    endpoint = METRIC_ENDPOINTS[metric_type]
    full_url = f"{api_url}{endpoint}"

    # Add query parameters for users endpoint
    if metric_type == "users" and config:
        params = []
        params.append(f"active={str(config['gitlab_active_users_only']).lower()}")
        params.append(f"external={str(config['gitlab_external_users']).lower()}")
        if params:
            full_url = f"{full_url}?{'&'.join(params)}"

    response = http.request("GET", full_url, headers={"PRIVATE-TOKEN": token})

    if response.status != 200:
        raise Exception(
            f"Failed to fetch {metric_type} from GitLab API: {response.status} - {response.data.decode('utf-8')}"
        )

    data = json.loads(response.data.decode("utf-8"))
    if not data:
        print(f"No {metric_type} found in GitLab API response.")
        return []

    return data


def get_user_tenant(email: str, config: Dict[str, Any]) -> str:
    """Get user tenant from DynamoDB table."""
    try:
        dynamodb = boto3.resource("dynamodb")
        table = dynamodb.Table(config["user_data_dynamodb_table_name"])
        response = table.get_item(Key={"email": email})

        if "Item" not in response:
            raise ValueError(f"No tenant found for user with email: {email}")

        tenant = response["Item"].get("tenant")
        print(f"Tenant found for user {email}: {tenant}")
        return tenant
    except Exception as e:
        raise Exception(f"Error fetching tenant for user {email}: {str(e)}")


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


def collect_users(config: Dict[str, Any], timestamp_iso: str) -> List[str]:
    """Collect GitLab users metric."""
    if config["mock_mode"]:
        data = generate_mock_data("users")["data"]
    else:
        gitlab_token = get_gitlab_token(config)
        api_url = f"{config['gitlab_scheme']}://{config['gitlab_domain']}:{config['gitlab_port']}"
        data = fetch_gitlab_data(api_url, gitlab_token, "users", config)

    if not data:
        return []

    s3_client = boto3.client("s3")
    uploaded_files = []
    processed_count = 0

    for user in data:
        # Process user data
        user_data = {
            "id": user.get("id"),
            "email": user.get("email"),
            "name": user.get("name"),
            "username": user.get("username"),
            "state": user.get("state"),
            "collection_timestamp": timestamp_iso,
        }

        # Try to get tenant information
        try:
            user_data["tenant"] = get_user_tenant(user_data["email"], config)
        except Exception as e:
            print(f"Error fetching tenant for user {user_data['email']}: {str(e)}")
            user_data["tenant"] = "unassigned"

        # Validate user data against required fields
        if not validate_user_data(user_data, config["gitlab_required_fields"]):
            continue

        # Upload to S3
        current_time = datetime.datetime.fromisoformat(timestamp_iso)
        timestamp_filename = current_time.strftime("%Y%m%d_%H%M")
        partition_month = current_time.strftime("%Y-%m")

        s3_key = f"gitlab/users/{partition_month}/user-{user_data['id']}-{timestamp_filename}.json"
        s3_client.put_object(
            Bucket=config["output_bucket"],
            Key=s3_key,
            Body=json.dumps(user_data),
        )
        uploaded_files.append(s3_key)
        processed_count += 1

    print(f"Successfully processed {processed_count} users.")
    return uploaded_files


def collect_ci_minutes(config: Dict[str, Any], timestamp_iso: str) -> List[str]:
    """Collect GitLab CI minutes usage per namespace via GraphQL."""
    if config["mock_mode"]:
        data = generate_mock_data("ci_minutes")["data"]
    else:
        gitlab_token = get_gitlab_token(config)
        api_url = f"{config['gitlab_scheme']}://{config['gitlab_domain']}:{config['gitlab_port']}"

        # First get all namespaces (groups and subgroups)
        namespaces = fetch_gitlab_data(api_url, gitlab_token, "ci_minutes")

        # Then get CI usage for each namespace via GraphQL
        data = []
        http = urllib3.PoolManager()

        # Get the first day of the current month for the GraphQL query
        current_time = datetime.datetime.fromisoformat(timestamp_iso)
        first_day_of_month = current_time.replace(day=1).strftime("%Y-%m-%d")

        graphql_url = f"{api_url}/api/graphql"

        for namespace in namespaces:
            namespace_id = namespace.get("id")
            namespace_full_path = namespace.get("full_path", namespace.get("path"))

            # Convert REST API ID to GraphQL Global ID format
            global_namespace_id = f"gid://gitlab/Group/{namespace_id}"

            # GraphQL query for CI minutes usage
            graphql_query = {
                "query": """
                    query($namespaceId: NamespaceID!, $date: Date!) {
                        ciMinutesUsage(namespaceId: $namespaceId, date: $date) {
                            nodes {
                                minutes
                                month
                                year
                                projects {
                                    nodes {
                                        name
                                        minutes
                                    }
                                }
                            }
                        }
                    }
                """,
                "variables": {
                    "namespaceId": global_namespace_id,
                    "date": first_day_of_month,
                },
            }

            try:
                response = http.request(
                    "POST",
                    graphql_url,
                    headers={
                        "PRIVATE-TOKEN": gitlab_token,
                        "Content-Type": "application/json",
                    },
                    body=json.dumps(graphql_query),
                )

                if response.status == 200:
                    graphql_response = json.loads(response.data.decode("utf-8"))

                    if "errors" in graphql_response:
                        print(
                            f"GraphQL errors for namespace {namespace_id}: {graphql_response['errors']}"
                        )
                        continue

                    usage_data = (
                        graphql_response.get("data", {})
                        .get("ciMinutesUsage", {})
                        .get("nodes", [])
                    )

                    # Process the usage data
                    total_minutes = 0
                    project_details = []

                    for usage_node in usage_data:
                        total_minutes += usage_node.get("minutes", 0)
                        projects = usage_node.get("projects", {}).get("nodes", [])
                        for project in projects:
                            project_details.append(
                                {
                                    "name": project.get("name"),
                                    "minutes": project.get("minutes", 0),
                                }
                            )

                    namespace_with_usage = {
                        "id": namespace.get("id"),
                        "name": namespace.get("name"),
                        "path_with_namespace": namespace_full_path,
                        "ci_minutes_used": total_minutes if total_minutes > 0 else None,
                        "usage_month": first_day_of_month,
                        "project_breakdown": project_details
                        if project_details
                        else None,
                        "last_activity_at": namespace.get("last_activity_at"),
                    }
                    data.append(namespace_with_usage)
                else:
                    print(
                        f"GraphQL request failed for namespace {namespace_id}: {response.status}"
                    )

            except Exception as e:
                print(f"Error fetching CI usage for namespace {namespace_id}: {str(e)}")
                continue

    if not data:
        return []

    s3_client = boto3.client("s3")
    uploaded_files = []

    for namespace in data:
        # Extract tenant from namespace path
        tenant = "unassigned"
        if namespace.get("path_with_namespace"):
            namespace_parts = namespace["path_with_namespace"].split("/")
            if len(namespace_parts) > 0:
                tenant = namespace_parts[0]  # Use the top-level group as tenant

        namespace_data = {
            "id": namespace.get("id"),
            "name": namespace.get("name"),
            "path_with_namespace": namespace.get("path_with_namespace"),
            "tenant": tenant,
            "ci_minutes_used": namespace.get("ci_minutes_used", None),
            "usage_month": namespace.get("usage_month"),
            "project_breakdown": namespace.get("project_breakdown"),
            "last_activity_at": namespace.get("last_activity_at"),
            "collection_timestamp": timestamp_iso,
        }

        # Upload to S3
        current_time = datetime.datetime.fromisoformat(timestamp_iso)
        timestamp_filename = current_time.strftime("%Y%m%d_%H%M")
        partition_month = current_time.strftime("%Y-%m")

        s3_key = f"gitlab/ci_minutes/{partition_month}/namespace-{namespace_data['id']}-{timestamp_filename}.json"
        s3_client.put_object(
            Bucket=config["output_bucket"],
            Key=s3_key,
            Body=json.dumps(namespace_data),
        )
        uploaded_files.append(s3_key)

    return uploaded_files


# Map of metric types to their collection functions
METRIC_COLLECTORS: Dict[str, Callable] = {
    "users": collect_users,
    "ci_minutes": collect_ci_minutes,
}


def handler(event, context):
    """Main Lambda handler function."""
    try:
        # Load configuration
        config = load_configuration()

        # Get metric type from event, default to users
        metric_type = event.get("metric_type", "users")

        if metric_type not in METRIC_ENDPOINTS:
            return {
                "statusCode": 400,
                "body": json.dumps(
                    {
                        "error": f"Invalid metric type: {metric_type}. Valid types are: {list(METRIC_ENDPOINTS.keys())}"
                    }
                ),
            }

        # Generate timestamps
        current_time = datetime.datetime.now()
        timestamp_iso = current_time.isoformat()

        # Get the appropriate collector function and execute it
        collector = METRIC_COLLECTORS[metric_type]
        uploaded_files = collector(config, timestamp_iso)

        return {
            "statusCode": 200,
            "body": json.dumps(
                {
                    "message": f"Successfully processed and uploaded {len(uploaded_files)} {metric_type} files",
                    "files": uploaded_files,
                }
            ),
        }

    except Exception as e:
        print(f"Error in handler: {str(e)}")
        return {
            "statusCode": 500,
            "body": json.dumps({"error": f"Error processing data: {str(e)}"}),
        }
