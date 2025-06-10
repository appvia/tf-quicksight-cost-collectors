import os
import json
from unittest.mock import patch, MagicMock
from collector import handler
import pathlib


def test_lambda_locally():
    # Get the real token from environment variable if it exists
    real_token = os.environ.get("SONARQUBE_TOKEN")

    # Create local output directory
    output_dir = pathlib.Path("test_output")
    output_dir.mkdir(exist_ok=True)

    # Set up environment variables for testing
    os.environ.update(
        {
            "SONARQUBE_DOMAIN": os.environ.get("SONARQUBE_DOMAIN", "localhost"),
            "SONARQUBE_PORT": os.environ.get("SONARQUBE_PORT", "9000"),
            "SONARQUBE_SCHEME": os.environ.get("SONARQUBE_SCHEME", "http"),
            "SONARQUBE_TOKEN_SECRET_NAME": "test/sonarqube/token",
            "OUTPUT_BUCKET": str(
                output_dir
            ),  # Use local directory instead of S3 bucket
            "MOCK_MODE": "false"
            if real_token
            else "true",  # Disable mock mode if we have a real token
        }
    )

    # Mock the AWS services
    with patch("boto3.client") as mock_boto3:
        # Mock Secrets Manager
        mock_secrets = MagicMock()
        mock_secrets.get_secret_value.return_value = {
            "SecretString": real_token if real_token else "test-token"
        }

        # Mock S3 with local file saving
        mock_s3 = MagicMock()

        def put_object(Bucket, Key, Body):
            # Create the full path
            file_path = output_dir / Key
            # Create parent directories if they don't exist
            file_path.parent.mkdir(parents=True, exist_ok=True)
            # Write the file
            with open(file_path, "w") as f:
                f.write(Body)
            return {}

        mock_s3.put_object.side_effect = put_object

        # Configure the mock to return different clients based on service name
        def get_client(service_name, *args, **kwargs):
            if service_name == "secretsmanager":
                return mock_secrets
            elif service_name == "s3":
                return mock_s3
            return MagicMock()

        mock_boto3.side_effect = get_client

        # Call the handler
        response = handler({}, None)

        # Print the response
        print("\nLambda Response:")
        print(json.dumps(response, indent=2))

        # Print the files that were created
        print("\nCreated files:")
        for file_path in output_dir.rglob("*.json"):
            print(f"- {file_path}")


if __name__ == "__main__":
    test_lambda_locally()
