output "https_trigger_url" {
  value = google_cloudfunctions_function.function.https_trigger_url
}

output "api_key" {
  value = random_id.valid_api_key.hex
}
