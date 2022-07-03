# smartthings-logger

A SmartThings Smart App and Google Cloud backend for storing SmartThings events.

# GCP Backend

When an event happens on SmartThings, it's pushed to a Google Cloud Function as an http
request, which writes it to BigQuery.

# SmartThings SmartApp

The SmartApp captures events and transmits them to the function. You will need to install
this on the web console, and on your device.
