# locals
locals {
  environment = terraform.workspace == "default" ? "dev" : "${terraform.workspace}"
  project_id  = "${var.project_name}-${local.environment}-${var.postfix}"
  gcp_service_list = [
    "bigquerystorage.googleapis.com",
    "bigquery.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudbuild.googleapis.com",
  ]
}

# project
resource "google_project" "smartthings_logger" {
  name            = "${var.project_name}-${local.environment}"
  billing_account = var.billing_account
  project_id      = local.project_id
}

# APIs to enable
resource "google_project_service" "gcp_services" {
  for_each                   = toset(local.gcp_service_list)
  project                    = local.project_id
  service                    = each.key
  disable_dependent_services = true
}

# bq dataset and table
resource "google_bigquery_dataset" "smartthings" {
  dataset_id    = "smartthings"
  friendly_name = "smartthings"
  location      = var.region

  access {
    role          = "WRITER"
    user_by_email = google_service_account.bqowner.email
  }

  access {
    role          = "OWNER"
    user_by_email = var.owner_email
  }
}

resource "google_bigquery_table" "events" {
  dataset_id          = google_bigquery_dataset.smartthings.dataset_id
  table_id            = "events"
  deletion_protection = false
  schema              = file("events_schema.json")
}

# service account for functions to access bq
resource "google_service_account" "bqowner" {
  account_id = "bqowner"

  # settle to avoid eventual consistency errors
  provisioner "local-exec" {
    command = "sleep 10"
  }
}

# function
locals {
  timestamp = formatdate("YYMMDDhhmmss", timestamp())
  root_dir  = abspath("../function/src/")
}

# Compress source code
data "archive_file" "source" {
  type       = "zip"
  source_dir = local.root_dir

  output_path = "/tmp/function-${local.timestamp}.zip"
}

# Create bucket that will host the source code
resource "google_storage_bucket" "bucket" {
  name     = "${var.project_name}-function-${var.postfix}"
  location = var.region
}

# Add source code zip to bucket
resource "google_storage_bucket_object" "zip" {
  # Append file MD5 to force bucket to be recreated
  name   = "source.zip#${data.archive_file.source.output_md5}"
  bucket = google_storage_bucket.bucket.name
  source = data.archive_file.source.output_path
}

# create an API key for using the function
resource "random_id" "valid_api_key" {
  keepers = {
    # Generate a new id each time we switch to a new gcp project
    project_id = local.project_id
  }

  byte_length = 16
}

# Create Cloud Function
resource "google_cloudfunctions_function" "function" {
  name    = "events-logger"
  runtime = "python39"

  available_memory_mb   = 256
  source_archive_bucket = google_storage_bucket.bucket.name
  source_archive_object = google_storage_bucket_object.zip.name
  trigger_http          = true
  entry_point           = "event_post"

  environment_variables = {
    VALID_API_KEY = random_id.valid_api_key.hex
    TABLE_ID      = "${local.project_id}.${google_bigquery_dataset.smartthings.dataset_id}.${google_bigquery_table.events.table_id}"
  }

  service_account_email = google_service_account.bqowner.email
}

# Create IAM entry so all users can invoke the function
resource "google_cloudfunctions_function_iam_member" "invoker" {
  project        = google_cloudfunctions_function.function.project
  region         = google_cloudfunctions_function.function.region
  cloud_function = google_cloudfunctions_function.function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allUsers"
}
