output "name" {
  description = "Cloud Scheduler job name."
  value       = google_cloud_scheduler_job.this.name
}
