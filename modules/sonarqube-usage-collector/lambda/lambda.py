import json
import boto3
import os
import datetime
import urllib3
import random
from typing import Dict, List, Any


def load_configuration() -> Dict[str, Any]:
    """Load and validate environment variables."""
    config = {
        "sonarqube_domain": os.environ.get("SONARQUBE_DOMAIN"),
        "sonarqube_port": os.environ.get("SONARQUBE_PORT"),
        "sonarqube_scheme": os.environ.get("SONARQUBE_SCHEME"),
        "sonarqube_token_secret_name": os.environ.get("SONARQUBE_TOKEN_SECRET_NAME"),
        "output_bucket": os.environ.get("OUTPUT_BUCKET"),
        "mock_mode": os.environ.get("MOCK_MODE", "false").lower() == "true",
    }

    # Validate required configuration (skip token validation in mock mode)
    required_fields = [
        "sonarqube_domain",
        "sonarqube_port",
        "sonarqube_scheme",
        "output_bucket",
    ]
    if not config["mock_mode"]:
        required_fields.append("sonarqube_token_secret_name")

    missing_fields = [field for field in required_fields if not config[field]]

    if missing_fields:
        raise ValueError(
            f"Missing required environment variables: {', '.join(missing_fields)}"
        )

    return config


def generate_mock_data() -> Dict[str, List[Dict[str, Any]]]:
    """Generate mock project data for testing."""
    return {
        "projects": [
            {
                "projectName": [f"mock-project-{i}", f"test-project-{i}"][
                    random.randint(0, 1)
                ],
                "projectKey": f"PK-{i}",
                "linesOfCode": random.randint(900, 99999),
                "licenseUsagePercentage": round(random.uniform(0, 3), 2),
            }
            for i in range(1, 6)
        ]
    }


def fetch_sonarqube_data(api_url: str, token: str) -> Dict[str, Any]:
    """Fetch project data from SonarQube API."""
    http = urllib3.PoolManager()

    # Make request using basic auth (token as username, empty password)
    response = http.request(
        "GET",
        api_url,
        basic_auth=(token, ""),
    )

    if response.status != 200:
        raise Exception(f"Failed to fetch data from SonarQube API: {response.status}")

    return json.loads(response.data.decode("utf-8"))


def process_project_data(project: Dict[str, Any], timestamp_iso: str) -> Dict[str, Any]:
    """Process and transform project data from SonarQube API."""
    return {
        "extracted_tenant": project["projectName"].split("-")[
            0
        ],  # TODO: make this more robust
        "project_key": project["projectKey"],
        "project_name": project["projectName"],
        "lines_of_code": project["linesOfCode"],
        "license_usage_percentage": project["licenseUsagePercentage"],
        "timestamp": timestamp_iso,
    }


def handler(event, context):
    """Main Lambda handler function."""
    try:
        # Load configuration
        config = load_configuration()

        # Generate timestamps
        current_time = datetime.datetime.now()
        timestamp_iso = current_time.isoformat()
        timestamp_filename = current_time.strftime("%Y%m%d_%H%M")
        partition_month = current_time.strftime("%Y-%m")

        # Get project data (either mock or from API)
        if config["mock_mode"]:
            data = generate_mock_data()
        else:
            # Get SonarQube token from secrets manager
            secret_manager_client = boto3.client("secretsmanager")
            response = secret_manager_client.get_secret_value(
                SecretId=config["sonarqube_token_secret_name"]
            )
            sonarqube_token = response["SecretString"]

            # Construct API URL and fetch data
            api_url = f"{config['sonarqube_scheme']}://{config['sonarqube_domain']}:{config['sonarqube_port']}/api/projects/license_usage"
            data = fetch_sonarqube_data(api_url, sonarqube_token)

        # Initialize S3 client and process projects
        s3_client = boto3.client("s3")
        uploaded_files = []

        # Process each project individually
        for project in data["projects"]:
            project_data = process_project_data(project, timestamp_iso)

            # Upload to S3
            s3_key = f"sonarqube/{partition_month}/{project['projectKey']}_{timestamp_filename}.json"
            s3_client.put_object(
                Bucket=config["output_bucket"],
                Key=s3_key,
                Body=json.dumps(project_data),
            )
            uploaded_files.append(s3_key)

        return {
            "statusCode": 200,
            "body": json.dumps(
                {
                    "message": f"Successfully processed and uploaded {len(uploaded_files)} project files",
                    "files": uploaded_files,
                }
            ),
        }

    except urllib3.exceptions.HTTPError as e:
        return {
            "statusCode": 500,
            "body": json.dumps(
                {"error": f"Error fetching data from SonarQube: {str(e)}"}
            ),
        }
    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps({"error": f"Error processing data: {str(e)}"}),
        }
