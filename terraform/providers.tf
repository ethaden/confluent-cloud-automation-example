terraform {
  required_providers {
    confluent = {
      source = "confluentinc/confluent"
      # we are using the latest version by leaving the next line commented. For production, fix the version!
      #version = "2.00.0"
    }
  }
}

provider "confluent" {
  cloud_api_key    = local.confluent_creds.api_key
  cloud_api_secret = local.confluent_creds.api_secret
}
