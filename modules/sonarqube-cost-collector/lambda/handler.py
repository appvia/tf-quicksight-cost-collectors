import json
import boto3
import os
import datetime
import urllib3


def lambda_handler(event, context):
    # Initialize S3 client
    s3_client = boto3.client("s3")

    # Get environment variables
    sonarqube_domain = os.environ["SONARQUBE_DOMAIN"]
    sonarqube_port = os.environ["SONARQUBE_PORT"]
    sonarqube_scheme = os.environ["SONARQUBE_SCHEME"]
    sonarqube_token_secret_name = os.environ["SONARQUBE_TOKEN_SECRET_NAME"]
    output_bucket = os.environ["OUTPUT_BUCKET"]

    # Construct the API URL
    api_url = f"{sonarqube_scheme}://{sonarqube_domain}:{sonarqube_port}/api/projects/license_usage"

    # Get the SonarQube token from secretsmanager
    secret_manager_client = boto3.client("secretsmanager")
    response = secret_manager_client.get_secret_value(
        SecretId=sonarqube_token_secret_name
    )
    # the token is used as a basic auth username
    # for example with curl:
    # curl -u <token>: http://<sonarqube_domain>:<sonarqube_port>/api/projects/license_usage
    sonarqube_token = response["SecretString"]

    try:
        # Create a urllib3 PoolManager
        http = urllib3.PoolManager()

        # Make request to SonarQube API using urllib3's built-in basic_auth parameter
        # This automatically handles the base64 encoding for Basic Authentication
        response = http.request(
            "GET",
            api_url,
            basic_auth=(sonarqube_token, ""),  # username is token, password is empty
        )

        # Parse the JSON response
        data = json.loads(response.data.decode("utf-8"))

        # Generate timestamp in ISO format
        current_time = datetime.datetime.now()
        timestamp_iso = current_time.isoformat()
        timestamp_filename = current_time.strftime("%Y%m%d_%H%M%S")

        # Track successful uploads
        uploaded_files = []

        # Process each project individually
        for project in data["projects"]:
            # Extract only the required fields
            project_data = {
                "extractedTenant": project["projectName"].split("-")[
                    0
                ],  # TODO: make this more robust
                "projectKey": project["projectKey"],
                "projectName": project["projectName"],
                "linesOfCode": project["linesOfCode"],
                "licenseUsagePercentage": project["licenseUsagePercentage"],
                "timestamp": timestamp_iso,  # Use ISO format for the data
            }

            # Create a structured S3 key with project key as prefix
            # This helps with Athena partitioning
            s3_key = f"projects/{project['projectKey']}_{timestamp_filename}.json"  # Keep filename format for consistency

            # Upload individual project data to S3
            s3_client.put_object(
                Bucket=output_bucket, Key=s3_key, Body=json.dumps(project_data)
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
