output "tier1_dashboard_name" {
  description = "Name of the Tier 1 executive dashboard, or null if it was not created."
  value       = try(aws_cloudwatch_dashboard.tier1[0].dashboard_name, null)
}

output "tier1_dashboard_arn" {
  description = "ARN of the Tier 1 executive dashboard, or null if it was not created."
  value       = try(aws_cloudwatch_dashboard.tier1[0].dashboard_arn, null)
}

output "tier2_dashboard_name" {
  description = "Name of the Tier 2 operational triage dashboard, or null if it was not created."
  value       = try(aws_cloudwatch_dashboard.tier2[0].dashboard_name, null)
}

output "tier2_dashboard_arn" {
  description = "ARN of the Tier 2 operational triage dashboard, or null if it was not created."
  value       = try(aws_cloudwatch_dashboard.tier2[0].dashboard_arn, null)
}

output "tier3_dashboard_names" {
  description = "Map of resource_name => Tier 3 dashboard name, for every entry in tier3_resources."
  value       = { for k, v in aws_cloudwatch_dashboard.tier3 : k => v.dashboard_name }
}

output "tier3_dashboard_arns" {
  description = "Map of resource_name => Tier 3 dashboard ARN, for every entry in tier3_resources."
  value       = { for k, v in aws_cloudwatch_dashboard.tier3 : k => v.dashboard_arn }
}

output "query_definition_ids" {
  description = "Map of saved_log_insights_queries[*].name => CloudWatch Logs Insights query definition ID."
  value       = { for k, v in aws_cloudwatch_query_definition.saved : k => v.id }
}
