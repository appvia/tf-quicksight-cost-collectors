import boto3
import os
import time
import logging
from urllib.parse import unquote_plus

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
s3_client = boto3.client("s3")
athena_client = boto3.client("athena")

# Get environment variables
ATHENA_WORKGROUP = os.environ.get("ATHENA_WORKGROUP")
ATHENA_DATABASE = os.environ.get("ATHENA_DATABASE")


def lambda_handler(event, context):
    """
    Lambda function handler that processes S3 events.
    For each SQL file created or updated, execute it in Athena to create or update views.
    """
    logger.info("Event received: %s", event)

    # Check if the environment variables are set
    if not ATHENA_DATABASE or not ATHENA_WORKGROUP:
        logger.error(
            "ATHENA_WORKGROUP or ATHENA_DATABASE environment variable is not set"
        )
        return {
            "statusCode": 500,
            "body": "ATHENA_WORKGROUP or ATHENA_DATABASE environment variable is not set",
        }

    # Process each record in the event
    for record in event.get("Records", []):
        # Get S3 bucket and key
        bucket = record["s3"]["bucket"]["name"]
        key = unquote_plus(record["s3"]["object"]["key"])
        event_name = record["eventName"]

        logger.info(f"Processing: {key} from bucket: {bucket}, event: {event_name}")

        # Skip if not a .sql file
        if not key.endswith(".sql"):
            logger.info(f"Skipping non-SQL file: {key}")
            continue

        # Handle file deletion
        if "ObjectRemoved" in event_name:
            handle_file_deletion(key)
            continue

        # Get the SQL file content
        try:
            response = s3_client.get_object(Bucket=bucket, Key=key)
            sql_content = response["Body"].read().decode("utf-8")
            logger.info(f"Retrieved SQL content from {key}")
        except Exception as e:
            logger.error(f"Error retrieving SQL file {key}: {str(e)}")
            continue

        # Execute the SQL in Athena
        execute_athena_query(sql_content, key)

    return {"statusCode": 200, "body": "Successfully processed SQL files"}


def handle_file_deletion(key):
    """
    Handle deletion of an SQL file.
    Determine the view name from the file name and drop the view if it exists.

    For files in subdirectories, we flatten the path structure to create a view name:
    - For 'my_view.sql', view_name = 'my_view'
    - For 'path/to/my_view.sql', view_name = 'path_to_my_view'
    """
    # Extract view name from file key
    file_name = os.path.splitext(key)[0]  # Remove .sql extension but keep the path

    # Replace path separators with underscores to flatten directory structure
    view_name = file_name.replace("/", "_")

    logger.info(f"Processing deletion of view: {view_name}")

    # Create DROP VIEW statement
    drop_sql = f"DROP VIEW IF EXISTS {ATHENA_DATABASE}.{view_name}"

    # Execute the DROP statement
    execute_athena_query(drop_sql, key, is_deletion=True)


def execute_athena_query(sql, file_key, is_deletion=False):
    """
    Execute an Athena query and wait for it to complete.

    Args:
        sql (str): The SQL statement to execute
        file_key (str): The S3 key of the SQL file (for logging)
        is_deletion (bool): Whether this is a view deletion operation
    """
    logger.info(
        f"Executing{'' if is_deletion else ' view creation'} SQL from {file_key}"
    )
    logger.info(f"SQL: {sql}")

    try:
        # Start query execution
        response = athena_client.start_query_execution(
            QueryString=sql,
            QueryExecutionContext={"Database": ATHENA_DATABASE},
            WorkGroup=ATHENA_WORKGROUP,
        )

        query_execution_id = response["QueryExecutionId"]
        logger.info(f"Query execution ID: {query_execution_id}")

        # Wait for query to complete
        state = "RUNNING"
        max_retries = 10
        retry_count = 0

        while state == "RUNNING" and retry_count < max_retries:
            response = athena_client.get_query_execution(
                QueryExecutionId=query_execution_id
            )
            state = response["QueryExecution"]["Status"]["State"]

            if state == "RUNNING":
                retry_count += 1
                logger.info(
                    f"Query still running. Retry count: {retry_count}/{max_retries}"
                )
                time.sleep(3)  # Wait 3 seconds before checking again

        # Check final query state
        if state == "SUCCEEDED":
            logger.info(f"Query succeeded: {query_execution_id}")
        else:
            error_message = response["QueryExecution"]["Status"].get(
                "StateChangeReason", "Unknown error"
            )
            logger.error(f"Query failed with state {state}: {error_message}")

    except Exception as e:
        logger.error(f"Error executing Athena query: {str(e)}")
        raise
