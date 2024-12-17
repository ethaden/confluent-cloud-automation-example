# Confluent Cloud Environment
resource "confluent_environment" "example_env" {
  display_name = var.ccloud_environment_name

  stream_governance {
    package = "ESSENTIALS"
  }

  lifecycle {
    prevent_destroy = false
  }
}

data "confluent_schema_registry_cluster" "example_schema_registry" {
    environment {
      id = confluent_environment.example_env.id
    }
    # Using this dependency avoids a potential race condition where the schema registry is still created while terraform already tries to access it (which will fail)
    depends_on = [ confluent_kafka_cluster.example_cluster ]
}

resource "confluent_service_account" "example_env_admin" {
  display_name = "${var.resource_prefix}_example_sa_env_admin"
  description  = "Service Account Example Environment Admin (just for accessing Schema Registry)"
}

resource "confluent_api_key" "example_schema_registry_admin_api_key" {
  display_name = "${var.resource_prefix}_schema_registry_admin_api_key"
  description  = "Schema Registry API Key that is owned by '${var.resource_prefix}_example_sa_env_admin' service account"
  owner {
    id          = confluent_service_account.example_env_admin.id
    api_version = confluent_service_account.example_env_admin.api_version
    kind        = confluent_service_account.example_env_admin.kind
  }

  managed_resource {
    id          = data.confluent_schema_registry_cluster.example_schema_registry.id
    api_version = data.confluent_schema_registry_cluster.example_schema_registry.api_version
    kind        = data.confluent_schema_registry_cluster.example_schema_registry.kind

    environment {
      id = confluent_environment.example_env.id
    }
  }

  lifecycle {
    prevent_destroy = false
  }
}

resource "confluent_role_binding" "example_schema_registry_admin_role_binding" {
  principal   = "User:${confluent_service_account.example_env_admin.id}"
  role_name   = "ResourceOwner"
  crn_pattern = "${data.confluent_schema_registry_cluster.example_schema_registry.resource_name}/subject=*"
}

data "confluent_schema_registry_cluster_config" "example_schema_registry" {
  schema_registry_cluster {
    id = data.confluent_schema_registry_cluster.example_schema_registry.id
  }
  rest_endpoint = data.confluent_schema_registry_cluster.example_schema_registry.rest_endpoint
  credentials {
    key    = confluent_api_key.example_schema_registry_admin_api_key.id
    secret = confluent_api_key.example_schema_registry_admin_api_key.secret
  }
  depends_on = [ confluent_role_binding.example_schema_registry_admin_role_binding ]
}

# Confluent Cloud Kafka Cluster

# Set up a cluster (basic, standard, dedicated or enterprise, see below)
resource "confluent_kafka_cluster" "example_cluster" {
  display_name = var.ccloud_cluster_name
  availability = var.ccloud_cluster_availability
  cloud        = "AWS"
  region       = var.aws_region
  # Use standard if you want to have the ability to grant role bindings on topic scope
  # standard {}
  # For cost reasons, we use a basic cluster by default. However, you can choose a different type by setting the variable ccloud_cluster_type
  # As each different type is represented by a unique block in the cluster resource, we use dynamic blocks here.
  # Only exactly one can be active due to the way we've chosen the condition for "for_each"

  dynamic "standard" {
    for_each = var.ccloud_cluster_type=="standard" ? [true] : []
    content {
    }
  }
  dynamic "enterprise" {
    for_each = var.ccloud_cluster_type=="enterprise" ? [true] : []
    content {
    }
  }
  dynamic "dedicated" {
    for_each = var.ccloud_cluster_type=="dedicated" ? [true] : []
    content {
        cku = var.ccloud_cluster_ckus
        
    }
  }

  environment {
    id = confluent_environment.example_env.id
  }

  lifecycle {
    prevent_destroy = false
  }
}

# Service Account, API Key and role bindings for the cluster admin
resource "confluent_service_account" "example_sa_cluster_admin" {
  display_name = "${var.resource_prefix}_example_sa_cluster_admin"
  description  = "Service Account Example Cluster Admin"
}

# An API key with Cluster Admin access. Required for provisioning the cluster-specific resources such as our topic
resource "confluent_api_key" "example_api_key_sa_cluster_admin" {
  display_name = "${var.resource_prefix}_example_api_key_sa_cluster_admin"
  description  = "Kafka API Key that is owned by '${var.resource_prefix}_example_sa_cluster_admin' service account"
  owner {
    id          = confluent_service_account.example_sa_cluster_admin.id
    api_version = confluent_service_account.example_sa_cluster_admin.api_version
    kind        = confluent_service_account.example_sa_cluster_admin.kind
  }
  managed_resource {
    id          = confluent_kafka_cluster.example_cluster.id
    api_version = confluent_kafka_cluster.example_cluster.api_version
    kind        = confluent_kafka_cluster.example_cluster.kind

    environment {
      id = confluent_environment.example_env.id
    }
  }

  lifecycle {
    prevent_destroy = false
  }
}

# Assign the CloudClusterAdmin role to the cluster admin service account
resource "confluent_role_binding" "example_role_binding_cluster_admin" {
  principal   = "User:${confluent_service_account.example_sa_cluster_admin.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.example_cluster.rbac_crn
  lifecycle {
    prevent_destroy = false
  }
}

# Schema Registry API Key for the cluster admin (with full access to the environment's schema registry)
resource "confluent_api_key" "example_schema_registry_cluster_admin_api_key" {
  display_name = "${var.resource_prefix}_example_api_key_sa_cluster_admin_api_key"
  description  = "Schema Registry API Key that is owned by '${var.resource_prefix}_example_api_key_sa_cluster_admin' service account"
  owner {
    id          = confluent_service_account.example_sa_cluster_admin.id
    api_version = confluent_service_account.example_sa_cluster_admin.api_version
    kind        = confluent_service_account.example_sa_cluster_admin.kind
  }

  managed_resource {
    id          = data.confluent_schema_registry_cluster.example_schema_registry.id
    api_version = data.confluent_schema_registry_cluster.example_schema_registry.api_version
    kind        = data.confluent_schema_registry_cluster.example_schema_registry.kind

    environment {
      id = confluent_environment.example_env.id
    }
  }

  lifecycle {
    prevent_destroy = false
  }
}

resource "confluent_role_binding" "example_schema_registry_cluster_admin_role_binding" {
  principal   = "User:${confluent_service_account.example_sa_cluster_admin.id}"
  role_name   = "ResourceOwner"
  crn_pattern = "${data.confluent_schema_registry_cluster.example_schema_registry.resource_name}/subject=*"
}

# Service Account, API Key and role bindings for the producer
resource "confluent_service_account" "example_sa_producer" {
  display_name = "${var.resource_prefix}_example_sa_producer"
  description  = "Service Account Example Producer"
}

resource "confluent_api_key" "example_api_key_producer" {
  display_name = "${var.resource_prefix}_example_api_key_producer"
  description  = "Kafka API Key that is owned by '${var.resource_prefix}_example_sa' service account"
  owner {
    id          = confluent_service_account.example_sa_producer.id
    api_version = confluent_service_account.example_sa_producer.api_version
    kind        = confluent_service_account.example_sa_producer.kind
  }
  managed_resource {
    id          = confluent_kafka_cluster.example_cluster.id
    api_version = confluent_kafka_cluster.example_cluster.api_version
    kind        = confluent_kafka_cluster.example_cluster.kind

    environment {
      id = confluent_environment.example_env.id
    }
  }

  lifecycle {
    prevent_destroy = false
  }
}

# Assign DeveloperWrite to the demo producer for all topic prefixes in the variable
resource "confluent_role_binding" "example_role_binding_producer" {
  for_each = toset(var.ccloud_cluster_producer_write_topic_prefixes)
  principal   = "User:${confluent_service_account.example_sa_producer.id}"
  role_name   = "DeveloperWrite"
  crn_pattern = "${confluent_kafka_cluster.example_cluster.rbac_crn}/kafka=${confluent_kafka_cluster.example_cluster.id}/topic=${each.value}*"
  lifecycle {
    prevent_destroy = false
  }
}

# Schema Registry API Key for the example producer (with prefixed read access to the environment's schema registry)
resource "confluent_api_key" "example_schema_registry_producer_api_key" {
  display_name = "${var.resource_prefix}_example_sa_producer_sr_api_key"
  description  = "Schema Registry API Key that is owned by '${var.resource_prefix}_example_sa_producer_sr_api_key' service account"
  owner {
    id          = confluent_service_account.example_sa_producer.id
    api_version = confluent_service_account.example_sa_producer.api_version
    kind        = confluent_service_account.example_sa_producer.kind
  }

  managed_resource {
    id          = data.confluent_schema_registry_cluster.example_schema_registry.id
    api_version = data.confluent_schema_registry_cluster.example_schema_registry.api_version
    kind        = data.confluent_schema_registry_cluster.example_schema_registry.kind

    environment {
      id = confluent_environment.example_env.id
    }
  }

  lifecycle {
    prevent_destroy = false
  }
}

# In this demo setup, we provide write access to schema registry to the producer. Note: This is not recommended for production environments. Please manage schemas via CI/CD explicitly there.
resource "confluent_role_binding" "example_schema_registry_producer_role_binding" {
  for_each = toset(var.ccloud_cluster_producer_write_topic_prefixes)
  principal   = "User:${confluent_service_account.example_sa_producer.id}"
  role_name   = "DeveloperWrite"
  crn_pattern = "${data.confluent_schema_registry_cluster.example_schema_registry.resource_name}/subject=${each.key}"
}

# resource "confluent_kafka_acl" "example_acl_producer" {
#   kafka_cluster {
#      id = confluent_kafka_cluster.example_cluster.id
#   }
#   rest_endpoint  = confluent_kafka_cluster.example_cluster.rest_endpoint
#   resource_type = "TOPIC"
#   resource_name = confluent_kafka_topic.example_topic_test.topic_name
#   pattern_type  = "LITERAL"
#   principal     = "User:${confluent_service_account.example_sa_producer.id}"
#   host          = "*"
#   operation     = "WRITE"
#   permission    = "ALLOW"
#   credentials {
#     key    = confluent_api_key.example_api_key_sa_cluster_admin.id
#     secret = confluent_api_key.example_api_key_sa_cluster_admin.secret
#   }
#   lifecycle {
#     prevent_destroy = false
#   }
# }

# Service Account, API Key and role bindings for the consumer
resource "confluent_service_account" "example_sa_consumer" {
  display_name = "${var.resource_prefix}_example_sa_consumer"
  description  = "Service Account Example Consumer"
}

resource "confluent_api_key" "example_api_key_consumer" {
  display_name = "${var.resource_prefix}_example_api_key_consumer"
  description  = "Kafka API Key that is owned by '${var.resource_prefix}_example_sa_consumer' service account"
  owner {
    id          = confluent_service_account.example_sa_consumer.id
    api_version = confluent_service_account.example_sa_consumer.api_version
    kind        = confluent_service_account.example_sa_consumer.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.example_cluster.id
    api_version = confluent_kafka_cluster.example_cluster.api_version
    kind        = confluent_kafka_cluster.example_cluster.kind

    environment {
      id = confluent_environment.example_env.id
    }
  }

  lifecycle {
    prevent_destroy = false
  }
}

resource "confluent_role_binding" "example_role_binding_consumer" {
  for_each = toset(var.ccloud_cluster_consumer_read_topic_prefixes)
  principal   = "User:${confluent_service_account.example_sa_consumer.id}"
  role_name   = "DeveloperRead"
  crn_pattern = "${confluent_kafka_cluster.example_cluster.rbac_crn}/kafka=${confluent_kafka_cluster.example_cluster.id}/topic=${each.value}*"
  lifecycle {
    prevent_destroy = false
  }
}
resource "confluent_role_binding" "example_role_binding_consumer_group" {
  for_each = toset(var.ccloud_cluster_consumer_group_prefixes)
  principal   = "User:${confluent_service_account.example_sa_consumer.id}"
  role_name   = "DeveloperRead"
  crn_pattern = "${confluent_kafka_cluster.example_cluster.rbac_crn}/kafka=${confluent_kafka_cluster.example_cluster.id}/group=${each.value}*"
  lifecycle {
    prevent_destroy = false
  }
}

# Schema Registry API Key for the example consumer (with prefixed read access to the environment's schema registry)
resource "confluent_api_key" "example_schema_registry_consumer_api_key" {
  display_name = "${var.resource_prefix}_example_api_key_sa_consumer_sr_api_key"
  description  = "Schema Registry API Key that is owned by '${var.resource_prefix}_example_api_key_sa_cluster_admin' service account"
  owner {
    id          = confluent_service_account.example_sa_consumer.id
    api_version = confluent_service_account.example_sa_consumer.api_version
    kind        = confluent_service_account.example_sa_consumer.kind
  }

  managed_resource {
    id          = data.confluent_schema_registry_cluster.example_schema_registry.id
    api_version = data.confluent_schema_registry_cluster.example_schema_registry.api_version
    kind        = data.confluent_schema_registry_cluster.example_schema_registry.kind

    environment {
      id = confluent_environment.example_env.id
    }
  }

  lifecycle {
    prevent_destroy = false
  }
}

resource "confluent_role_binding" "example_schema_registry_consumer_role_binding" {
  for_each = toset(var.ccloud_cluster_consumer_read_topic_prefixes)
  principal   = "User:${confluent_service_account.example_sa_consumer.id}"
  role_name   = "DeveloperRead"
  crn_pattern = "${data.confluent_schema_registry_cluster.example_schema_registry.resource_name}/subject=${each.key}"
}


# resource "confluent_kafka_acl" "example_acl_consumer" {
#   kafka_cluster {
#      id = confluent_kafka_cluster.example_cluster.id
#   }
#   rest_endpoint  = confluent_kafka_cluster.example_cluster.rest_endpoint
#   resource_type = "TOPIC"
#   resource_name = confluent_kafka_topic.example_topic_test.topic_name
#   pattern_type  = "LITERAL"
#   principal     = "User:${confluent_service_account.example_sa_consumer.id}"
#   host          = "*"
#   operation     = "READ"
#   permission    = "ALLOW"
#   credentials {
#     key    = confluent_api_key.example_api_key_sa_cluster_admin.id
#     secret = confluent_api_key.example_api_key_sa_cluster_admin.secret
#   }
#   lifecycle {
#     prevent_destroy = false
#   }
# }

# resource "confluent_kafka_acl" "example_acl_consumer_group" {
#   kafka_cluster {
#     id = confluent_kafka_cluster.example_cluster.id
#   }
#   rest_endpoint  = confluent_kafka_cluster.example_cluster.rest_endpoint
#   resource_type = "GROUP"
#   resource_name = var.ccloud_cluster_consumer_group_prefix
#   pattern_type  = "PREFIXED"
#   principal     = "User:${confluent_service_account.example_sa_consumer.id}"
#   host          = "*"
#   operation     = "READ"
#   permission    = "ALLOW"
#   credentials {
#     key    = confluent_api_key.example_api_key_sa_cluster_admin.id
#     secret = confluent_api_key.example_api_key_sa_cluster_admin.secret
#   }
#   lifecycle {
#     prevent_destroy = false
#   }
# }

# Topic with configured name
resource "confluent_kafka_topic" "example_topic" {
  for_each = toset(var.ccloud_cluster_topics)
  kafka_cluster {
    id = confluent_kafka_cluster.example_cluster.id
  }
  topic_name         = each.key
  rest_endpoint      = confluent_kafka_cluster.example_cluster.rest_endpoint
  partitions_count = var.ccloud_cluster_topic_partitions
  credentials {
    key    = confluent_api_key.example_api_key_sa_cluster_admin.id
    secret = confluent_api_key.example_api_key_sa_cluster_admin.secret
  }

  # Required to make sure the role binding is created before trying to create a topic using these credentials
  depends_on = [ 
    confluent_role_binding.example_role_binding_cluster_admin 
    ]

  lifecycle {
    prevent_destroy = false
  }
}

###### Regular users
# For DeveloperRead: A user account can have read access to multiple prefixes. We need to generate all allowed combinations
# Note: The result will look like this: {"u-1234__prefix1": {"userid": "u-1234", "prefix": "prefix1"}, "u-5678__prefix2": {"userid": "u-5678", "prefix": "prefix2"}}
# The three dots are actually part of the syntax (see below)
locals {
    user_prefix_developerread_map = merge([
        for userid, prefix_list in var.ccloud_cluster_prefix_mappings_read : {
            for prefix in prefix_list: "${userid}__${prefix}" => {
                userid = userid
                prefix = prefix
            }
        }]...)
}

# Assign DeveloperRead to all (user, prefix) combinations for our cluster
resource "confluent_role_binding" "example_role_binding_user_developer_read" {
  for_each = local.user_prefix_developerread_map
  principal   = "User:${each.value.userid}"
  role_name   = "DeveloperRead"
  crn_pattern = "${confluent_kafka_cluster.example_cluster.rbac_crn}/kafka=${confluent_kafka_cluster.example_cluster.id}/topic=${each.value.prefix}*"
  lifecycle {
    prevent_destroy = false
  }
}
# Assign DeveloperRead to all (user, prefix) combinations for our cluster for groups
resource "confluent_role_binding" "example_role_binding_user_developer_group_read" {
  for_each = local.user_prefix_developerread_map
  principal   = "User:${each.value.userid}"
  role_name   = "DeveloperRead"
  crn_pattern = "${confluent_kafka_cluster.example_cluster.rbac_crn}/kafka=${confluent_kafka_cluster.example_cluster.id}/group=${each.value.prefix}*"
  lifecycle {
    prevent_destroy = false
  }
}


# For DeveloperWrite: A user account can have read access to multiple prefixes. We need to generate all allowed combinations
# Note: The result will look like this: {"u-1234__prefix1": {"userid": "u-1234", "prefix": "prefix1"}, "u-5678__prefix2": {"userid": "u-5678", "prefix": "prefix2"}}
# The three dots are actually part of the syntax (see below)
locals {
    user_prefix_developerwrite_map = merge([
        for userid, prefix_list in var.ccloud_cluster_prefix_mappings_write : {
            for prefix in prefix_list: "${userid}__${prefix}" => {
                userid = userid
                prefix = prefix
            }
        }]...)
}

# Assign DeveloperWrite to all (user, prefix) combinations for our cluster
resource "confluent_role_binding" "example_role_binding_user_developer_write" {
  for_each = local.user_prefix_developerwrite_map
  principal   = "User:${each.value.userid}"
  role_name   = "DeveloperWrite"
  crn_pattern = "${confluent_kafka_cluster.example_cluster.rbac_crn}/kafka=${confluent_kafka_cluster.example_cluster.id}/topic=${each.value.prefix}*"
  lifecycle {
    prevent_destroy = false
  }
}


### Some outputs

output "cluster_bootstrap_server" {
   value = confluent_kafka_cluster.example_cluster.bootstrap_endpoint
}
output "cluster_rest_endpoint" {
    value = confluent_kafka_cluster.example_cluster.rest_endpoint
}

output "example_schema_registry_rest_endpoint" {
  value = data.confluent_schema_registry_cluster.example_schema_registry.rest_endpoint
}

output "example_schema_registry_admin_api_key" {
  value = nonsensitive("Key: ${confluent_api_key.example_schema_registry_admin_api_key.id}\nSecret: ${confluent_api_key.example_schema_registry_admin_api_key.secret}")
}

output "compatibility_level" {
  value = data.confluent_schema_registry_cluster_config.example_schema_registry.compatibility_level
}

# The next entries demonstrate how to output the generated API keys to the console even though they are considered to be sensitive data by Terraform
# Uncomment these lines if you want to generate that output
# output "cluster_api_key_admin" {
#     value = nonsensitive("Key: ${confluent_api_key.example_api_key_sa_cluster_admin.id}\nSecret: ${confluent_api_key.example_api_key_sa_cluster_admin.secret}")
# }

# output "cluster_api_key_producer" {
#     value = nonsensitive("Key: ${confluent_api_key.example_api_key_producer.id}\nSecret: ${confluent_api_key.example_api_key_producer.secret}")
# }

# output "cluster_api_key_consumer" {
#     value = nonsensitive("Key: ${confluent_api_key.example_api_key_consumer.id}\nSecret: ${confluent_api_key.example_api_key_consumer.secret}")
# }

# Generate console client configuration files for testing in subfolder "generated/client-configs"
# PLEASE NOTE THAT THESE FILES CONTAIN SENSITIVE CREDENTIALS
resource "local_sensitive_file" "client_config_files" {
  # Do not generate any files if var.ccloud_cluster_generate_client_config_files is false
  for_each = var.ccloud_cluster_generate_client_config_files ? {
    "admin" = { "cluster_api_key" = confluent_api_key.example_api_key_sa_cluster_admin, "sr_api_key" = confluent_api_key.example_schema_registry_cluster_admin_api_key},
    "producer" = { "cluster_api_key" = confluent_api_key.example_api_key_producer, "sr_api_key" = confluent_api_key.example_schema_registry_producer_api_key},
    "consumer" = { "cluster_api_key" = confluent_api_key.example_api_key_consumer, "sr_api_key" = confluent_api_key.example_schema_registry_consumer_api_key}} : {}

  content = templatefile("${path.module}/templates/client.conf.tpl",
  {
    client_name = "${each.key}"
    cluster_bootstrap_server = trimprefix("${confluent_kafka_cluster.example_cluster.bootstrap_endpoint}", "SASL_SSL://")
    api_key = "${each.value["cluster_api_key"].id}"
    api_secret = "${each.value["cluster_api_key"].secret}"
    consumer_group_prefix = "${var.ccloud_cluster_consumer_group_prefixes[0]}.demo"
    schema_registry_url = data.confluent_schema_registry_cluster.example_schema_registry.rest_endpoint
    schema_registry_user = "${each.value["sr_api_key"].id}"
    schema_registry_password = "${each.value["sr_api_key"].secret}"
  }
  )
  filename = "${var.generated_files_path}/client-${each.key}.conf"
}
