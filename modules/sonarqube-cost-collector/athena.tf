# Athena named query for SonarQube cost analysis
resource "aws_athena_named_query" "sonarqube_cost_analysis" {
  name        = "sonarqube_cost_analysis_query"
  workgroup   = var.athena_workgroup_name
  database    = var.athena_database_name
  description = "Query for SonarQube cost analysis"
  query       = <<-EOF
    CREATE EXTERNAL TABLE IF NOT EXISTS sonarqube_cost_data (
      projectKey string,
      projectName string,
      linesOfCode int,
      licenseUsagePercentage double,
      timestamp string
    )
    ROW FORMAT SERDE 'org.openx.data.jsonserde.JsonSerDe'
    LOCATION 's3://${var.bucket_name}/projects/'
    TBLPROPERTIES ('ignore.malformed.json'='true');
  EOF
}
