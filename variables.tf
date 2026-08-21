variable "dashboard_name_prefix" {
  description = "Prefix used to name the tier1/tier2/tier3 dashboards, e.g. \"<prefix>-tier1\"."
  type        = string
}

# ---------------------------------------------------------------------------
# Tier 1 - executive health (composite alarm status grid, no graphs)
# ---------------------------------------------------------------------------

variable "tier1_composite_alarms" {
  description = <<-EOT
    Composite alarms (one per business service) to render as individual Alarm
    Status widgets on the Tier 1 executive dashboard. Leave empty to skip
    creating the Tier 1 dashboard entirely.
  EOT
  type = list(object({
    name  = string
    arn   = string
    label = string
  }))
  default = []
}

# ---------------------------------------------------------------------------
# Tier 2 - operational triage (scoped by service/env)
# ---------------------------------------------------------------------------

variable "tier2_service_values" {
  description = "Values offered by the $service dashboard variable dropdown on the Tier 2 dashboard. Leave empty to omit the $service variable."
  type        = list(string)
  default     = []
}

variable "tier2_default_service" {
  description = "Default value for the $service dashboard variable. Defaults to the first entry of tier2_service_values when unset."
  type        = string
  default     = ""
}

variable "tier2_env_values" {
  description = "Values offered by the $env dashboard variable dropdown on the Tier 2 dashboard. Leave empty to omit the $env variable."
  type        = list(string)
  default     = []
}

variable "tier2_default_env" {
  description = "Default value for the $env dashboard variable. Defaults to the first entry of tier2_env_values when unset."
  type        = string
  default     = ""
}

variable "tier2_metrics" {
  description = <<-EOT
    Metric (or metric-math) widgets rendered on the Tier 2 operational triage
    dashboard, e.g. error rate / latency / throughput trends.

    Set `expression` (with `using_metrics` supplying the underlying series) to
    render a metric-math widget, or leave `expression` null and populate
    `namespace`/`metric_name`/`dimensions`/`stat` to render a plain metric
    widget. Leave the whole list empty to omit metric widgets from Tier 2.
  EOT
  type = list(object({
    label       = string
    namespace   = optional(string)
    metric_name = optional(string)
    dimensions  = optional(map(string), {})
    stat        = optional(string, "Average")
    expression  = optional(string)
    using_metrics = optional(list(object({
      id          = string
      namespace   = string
      metric_name = string
      dimensions  = optional(map(string), {})
      stat        = optional(string, "Average")
    })), [])
  }))
  default = []
}

variable "tier2_alarms" {
  description = <<-EOT
    Alarms rendered as a single Alarm Status widget grid on the Tier 2
    dashboard, filtered to only display alarms currently in ALARM state.
    Leave empty to omit the alarm grid from Tier 2.
  EOT
  type = list(object({
    name  = string
    arn   = string
    label = string
  }))
  default = []
}

# ---------------------------------------------------------------------------
# Tier 3 - deep investigation (one dashboard per resource)
# ---------------------------------------------------------------------------

variable "tier3_resources" {
  description = <<-EOT
    One entry per resource that should get its own Tier 3 deep-investigation
    dashboard, combining metric widgets, a Logs Insights query widget, and
    (optionally) an X-Ray trace map widget. Leave empty to skip Tier 3
    entirely.
  EOT
  type = list(object({
    resource_name = string
    metrics = list(object({
      namespace   = string
      metric_name = string
      dimensions  = optional(map(string), {})
      stat        = optional(string, "Average")
      label       = string
    }))
    log_group_names = optional(list(string), [])
    has_xray        = optional(bool, false)
  }))
  default = []
}

variable "tier3_log_queries" {
  description = <<-EOT
    Map of tier3_resources[*].resource_name to the Logs Insights query string
    to run in that resource's Tier 3 log widget. Resources not present in
    this map fall back to a generic "most recent events" query.
  EOT
  type        = map(string)
  default     = {}
}

variable "tier3_default_log_query" {
  description = "Fallback Logs Insights query used for a Tier 3 resource with no entry in tier3_log_queries."
  type        = string
  default     = "fields @timestamp, @message | sort @timestamp desc | limit 100"
}

# ---------------------------------------------------------------------------
# Saved Logs Insights query definitions
# ---------------------------------------------------------------------------

variable "saved_log_insights_queries" {
  description = "Saved CloudWatch Logs Insights query definitions, reusable from Tier 3 dashboards and ad-hoc console use."
  type = list(object({
    name            = string
    query_string    = string
    log_group_names = optional(list(string), [])
  }))
  default = []
}
