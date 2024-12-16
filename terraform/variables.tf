
# Recommendation: Overwrite the default in tfvars or stick with the automatic default
variable "resource_prefix" {
    type = string
    description = "A prefix used for certain resources such as service accounts"
}

variable "generated_files_path" {
    description = "The main path to write generated files to"
    type = string
    default = "./generated"
}

variable "ccloud_environment_name" {
    type = string
    description = "Name of the Confluent Cloud environment to create"
}

variable "ccloud_cluster_name" {
    type = string
    description = "Name of the cluster to be created"
}

variable "aws_region" {
    type = string
    default = "eu-central-1"
    description = "The region used to deploy the AWS resources and Confluent Cloud Kafka cluster"
}

variable "ccloud_cluster_type" {
    type = string
    default = "standard"
    description = "The cluster type of the Confluent Cloud Kafka cluster. Valid values are \"standard\", \"dedicated\", \"enterprise\", \"freight\""
    validation {
        condition = var.ccloud_cluster_type=="standard" || var.ccloud_cluster_type=="dedicated" || var.ccloud_cluster_type=="enterprise" || var.ccloud_cluster_type=="freight"
        error_message = "Valid Confluent Cloud cluster types are \"standard\", \"dedicated\", \"enterprise\", \"enterprise\", \"freight\""
    }
}

variable "ccloud_cluster_availability" {
    type = string
    default = "SINGLE_ZONE"
    description = "The availability of the Confluent Cloud Kafka cluster"
    validation {
        condition = var.ccloud_cluster_availability=="SINGLE_ZONE" || var.ccloud_cluster_availability=="MULTI_ZONE"
        error_message = "The availability of the Confluent Cloud cluster must either by \"SINGLE_ZONE\" or \"MULTI_ZONE\""
    }
}

variable "ccloud_cluster_ckus" {
    type = number
    default = 1
    description = "The number of CKUs to use if the Confluent Cloud Kafka cluster is \"dedicated\"."
    validation {
        condition = var.ccloud_cluster_ckus>=1
        error_message = "The minimum number of CKUs for a dedicated cluster is 2"
    }
}

variable "ccloud_cluster_topics" {
    type = list
    default = ["prefix1.test", "prefix1.abcd", "prefix2.test", "prefix2.xyz"]
    description = "A list of Kafka topics to create"
}

variable "ccloud_cluster_topic_partitions" {
    type = number
    default = 1
    description = "The number of partitions to create per topic"
}

#variable "ccloud_existing_users" {
#    type = string
#    description = "A list of existing user IDs to import"
#}

variable "ccloud_cluster_prefix_mappings_read" {
    type = map
    description = "A mapping of user ids to prefixes with read access"
}

variable "ccloud_cluster_prefix_mappings_write" {
    type = map
    description = "A mapping of user ids to prefixes with write access"
}

variable "ccloud_cluster_producer_write_topic_prefixes" {
    type = list
    description = "A list of Kafka topic prefixes to grant write access to the example producer"
}

variable "ccloud_cluster_consumer_read_topic_prefixes" {
    type = list
    description = "A list of Kafka topic prefixes to grant read access to the example consumer"
}

variable "ccloud_cluster_consumer_group_prefixes" {
    type = list
    description = "A list of Kafka consumer group prefixes to grant read access to the example consumer"
}

variable "ccloud_cluster_generate_client_config_files" {
    type = bool
    default = false
    description = "Set to true if you want to generate client configs with the created API keys under subfolder \"generated/client-configs\""
}
