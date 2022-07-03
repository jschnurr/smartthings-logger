terraform {
  backend "gcs" {
    bucket = "state-2222"         # global bucket for all projects
    prefix = "smartthings-logger" # folder for all workspace state files.
  }
}
