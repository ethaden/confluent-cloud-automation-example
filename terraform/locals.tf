# Run the script to get the environment variables of interest.
# This is a data source, so it will run at plan time.
data "external" "env" {
  program = ["${path.module}/locals-from-env-api-key.sh"]

  # For Windows (or Powershell core on MacOS and Linux),
  # run a Powershell script instead
  #program = ["${path.module}/env.ps1"]
}

locals {
    # Comment the next four lines if this project is not using Confluent Cloud
    confluent_creds = {
        api_key = data.external.env.result["api_key"]
        api_secret = data.external.env.result["api_secret"]
    }
}

