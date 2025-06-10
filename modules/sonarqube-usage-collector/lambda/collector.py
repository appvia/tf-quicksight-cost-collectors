import json
import boto3
import os
import datetime
import urllib3
import random
from typing import Dict, List, Any, Callable
import time


# Map metric types to their API endpoints
METRIC_ENDPOINTS = {
    "lines_of_code": "/api/projects/license_usage",
    "license_usage": "/api/projects/license_usage",
    "analyses": "/api/project_analyses",
}


def load_configuration() -> Dict[str, Any]:
    """Load and validate environment variables."""
    config = {
        "sonarqube_domain": os.environ.get("SONARQUBE_DOMAIN"),
        "sonarqube_port": os.environ.get("SONARQUBE_PORT"),
        "sonarqube_scheme": os.environ.get("SONARQUBE_SCHEME"),
        "sonarqube_token_secret_name": os.environ.get("SONARQUBE_TOKEN_SECRET_NAME"),
        "output_bucket": os.environ.get("OUTPUT_BUCKET"),
        "mock_mode": os.environ.get("MOCK_MODE", "false").lower() == "true",
        "athena_projects_table_name": os.environ.get("ATHENA_TABLE_NAME"),
    }

    # Validate required configuration (skip token validation in mock mode)
    required_fields = [
        "sonarqube_domain",
        "sonarqube_port",
        "sonarqube_scheme",
        "output_bucket",
        "sonarqube_token_secret_name",
        "athena_projects_table_name",
    ]

    missing_fields = [field for field in required_fields if not config[field]]

    if missing_fields and not config["mock_mode"]:
        raise ValueError(
            f"Missing required environment variables: {', '.join(missing_fields)}"
        )

    return config


def generate_mock_data(metric_type: str) -> Dict[str, List[Dict[str, Any]]]:
    """Generate mock project data for testing."""
    base_projects = [
        {
            "projectName": [f"mock-project-{i}", f"test-project-{i}"][
                random.randint(0, 1)
            ],
            "projectKey": f"PK-{i}",
        }
        for i in range(1, 6)
    ]

    # Add metric-specific data
    for project in base_projects:
        if metric_type == "lines_of_code":
            project["linesOfCode"] = random.randint(900, 99999)
        elif metric_type == "license_usage":
            project["licenseUsagePercentage"] = round(random.uniform(0, 3), 2)
        elif metric_type == "analyses":
            project["lastAnalysisDate"] = datetime.datetime.now().isoformat()
            project["analysisCount"] = random.randint(1, 100)
            project["lastAnalysisStatus"] = random.choice(
                ["SUCCESS", "FAILED", "IN_PROGRESS"]
            )

    return {"projects": base_projects}


def fetch_sonarqube_data(
    api_url: str, token: str, metric_type: str, project_key: str = None
) -> Dict[str, Any]:
    """Fetch project data from SonarQube API."""
    http = urllib3.PoolManager()

    endpoint = METRIC_ENDPOINTS[metric_type]
    full_url = f"{api_url}{endpoint}"

    # Add project key to URL if provided
    if project_key:
        full_url = f"{full_url}?project={project_key}"

    # Make request using basic auth (token as username, empty password)
    response = http.request(
        "GET",
        full_url,
        basic_auth=(token, ""),
    )

    if response.status != 200:
        raise Exception(f"Failed to fetch data from SonarQube API: {response.status}")

    return json.loads(response.data.decode("utf-8"))


def get_sonarqube_token(config: Dict[str, Any]) -> str:
    """Get SonarQube token from secrets manager."""
    try:
        secret_manager_client = boto3.client("secretsmanager")
        response = secret_manager_client.get_secret_value(
            SecretId=config["sonarqube_token_secret_name"]
        )
        sonarqube_token = response.get("SecretString")
        if not sonarqube_token:
            raise Exception("SonarQube token is empty")
        return sonarqube_token
    except Exception as e:
        raise Exception(f"Error getting SonarQube token from secrets manager: {str(e)}")


def get_projects(config: Dict[str, Any]) -> List[Dict[str, Any]]:
    """Get projects from Athena table."""
    athena_client = boto3.client("athena")
    # execute query
    try:
        response = athena_client.start_query_execution(
            QueryString=f"SELECT project_key, project_name FROM {config['athena_projects_table_name']}",
            ResultConfiguration={"OutputLocation": config["output_bucket"]},
        )
    except Exception as e:
        raise Exception(f"Error starting query execution: {str(e)}")
    # wait for query to complete
    while True:
        print(f"Waiting for query to complete: {response['QueryExecutionId']}")
        try:
            response = athena_client.get_query_execution(
                QueryExecutionId=response["QueryExecutionId"]
            )
        except Exception as e:
            raise Exception(f"Error getting query execution: {str(e)}")
        if response["QueryExecution"]["Status"]["State"] == "SUCCEEDED":
            break
        elif response["QueryExecution"]["Status"]["State"] == "FAILED":
            raise Exception(
                f"Query failed: {response['QueryExecution']['Status']['StateChangeReason']}"
            )
        time.sleep(1)
    print(f"Query completed: {response['QueryExecutionId']}")
    # get query results
    try:
        response = athena_client.get_query_results(
            QueryExecutionId=response["QueryExecutionId"]
        )
    except Exception as e:
        raise Exception(f"Error getting query results: {str(e)}")
    # return query results
    return response["ResultSet"]["Rows"]


def collect_lines_of_code(config: Dict[str, Any], timestamp_iso: str) -> List[str]:
    """Collect lines of code metric."""
    if config["mock_mode"]:
        data = generate_mock_data("lines_of_code")
    else:
        sonarqube_token = get_sonarqube_token(config)
        api_url = f"{config['sonarqube_scheme']}://{config['sonarqube_domain']}:{config['sonarqube_port']}"
        data = fetch_sonarqube_data(api_url, sonarqube_token, "lines_of_code")

    s3_client = boto3.client("s3")
    uploaded_files = []

    for project in data["projects"]:
        project_data = {
            "tenant": project["projectName"].split("-")[
                0
            ],  # TODO: make this more robust
            "project_key": project["projectKey"],
            "project_name": project["projectName"],
            "timestamp": timestamp_iso,
            "lines_of_code": project["linesOfCode"],
        }

        s3_key = f"sonarqube/lines_of_code/{timestamp_iso[:7]}/{project['projectKey']}_{timestamp_iso[11:16]}.json"
        upload_to_s3(config, s3_key, project_data)
        uploaded_files.append(s3_key)

    return uploaded_files


def collect_license_usage(config: Dict[str, Any], timestamp_iso: str) -> List[str]:
    """Collect license usage metric."""
    if config["mock_mode"]:
        data = generate_mock_data("license_usage")
    else:
        sonarqube_token = get_sonarqube_token(config)
        api_url = f"{config['sonarqube_scheme']}://{config['sonarqube_domain']}:{config['sonarqube_port']}"
        data = fetch_sonarqube_data(api_url, sonarqube_token, "license_usage")

    s3_client = boto3.client("s3")
    uploaded_files = []

    for project in data["projects"]:
        project_data = {
            "tenant": project["projectName"].split("-")[
                0
            ],  # TODO: make this more robust
            "project_key": project["projectKey"],
            "project_name": project["projectName"],
            "timestamp": timestamp_iso,
            "license_usage_percentage": project["licenseUsagePercentage"],
        }

        s3_key = f"sonarqube/license_usage/{timestamp_iso[:7]}/{project['projectKey']}_{timestamp_iso[11:16]}.json"
        upload_to_s3(config, s3_key, project_data)
        uploaded_files.append(s3_key)

    return uploaded_files


def collect_analyses(config: Dict[str, Any], timestamp_iso: str) -> List[str]:
    """Collect analyses metric."""
    if config["mock_mode"]:
        data = generate_mock_data("analyses")
        s3_client = boto3.client("s3")
        uploaded_files = []

        for project in data["projects"]:
            project_data = {
                "tenant": project["projectName"].split("-")[
                    0
                ],  # TODO: make this more robust
                "project_key": project["projectKey"],
                "project_name": project["projectName"],
                "timestamp": timestamp_iso,
                "last_analysis_date": project["lastAnalysisDate"],
                "analysis_count": project["analysisCount"],
                "last_analysis_status": project["lastAnalysisStatus"],
            }

            s3_key = f"sonarqube/analyses/{timestamp_iso[:7]}/{project['projectKey']}_{timestamp_iso[11:16]}.json"
            upload_to_s3(config, s3_key, project_data)
            uploaded_files.append(s3_key)

        return uploaded_files

    sonarqube_token = get_sonarqube_token(config)
    api_url = f"{config['sonarqube_scheme']}://{config['sonarqube_domain']}:{config['sonarqube_port']}"
    projects = get_projects(config)

    uploaded_files = []
    for project in projects:
        project_key = project["project_key"]
        project_name = project["project_name"]
        data = fetch_sonarqube_data(api_url, sonarqube_token, "analyses", project_key)

        project_data = {
            "tenant": project_name.split("-")[0],  # TODO: make this more robust
            "project_key": project_key,
            "project_name": project_name,
            "timestamp": timestamp_iso,
            "last_analysis_date": data["lastAnalysisDate"],
            "analysis_count": data["analysisCount"],
            "last_analysis_status": data["lastAnalysisStatus"],
        }

        s3_key = f"sonarqube/analyses/{timestamp_iso[:7]}/{project_key}_{timestamp_iso[11:16]}.json"
        upload_to_s3(config, s3_key, project_data)
        uploaded_files.append(s3_key)

    return uploaded_files


def upload_to_s3(config: Dict[str, Any], s3_key: str, data: Dict[str, Any]) -> None:
    """Upload data to S3."""
    s3_client = boto3.client("s3")
    s3_client.put_object(
        Bucket=config["output_bucket"],
        Key=s3_key,
        Body=json.dumps(data),
    )


def handler(event, context):
    """Main Lambda handler function."""
    try:
        # Load configuration
        config = load_configuration()

        # Get metric type from event, default to lines of code
        metric_type = event.get("metric_type", "lines_of_code")

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
                    "message": f"Successfully processed and uploaded {len(uploaded_files)} project files for metric {metric_type}",
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


# Map of metric types to their collection functions
METRIC_COLLECTORS: Dict[str, Callable] = {
    "lines_of_code": collect_lines_of_code,
    "license_usage": collect_license_usage,
    "analyses": collect_analyses,
}
