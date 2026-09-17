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

variable "tier1_applications" {
  description = <<-EOT
    One entry per application/service that should get its own per-application
    Tier 1 health dashboard (separate from, and independent of, the combined
    grid created by tier1_composite_alarms). Each dashboard opens with a
    severity-based status indicator - a crit_alarm and a warn_alarm rendered
    as Alarm Status widgets - followed by every metric widget for that
    application. There is no single "the whole dashboard is one color"
    CloudWatch primitive, so the status indicator is the crit/warn pair: crit
    in ALARM reads as red, only warn in ALARM reads as yellow, neither reads
    as green.

    Set warn_threshold and/or crit_threshold on a metric to draw horizontal
    reference lines at those values.

    Leave the whole list empty to skip this mode entirely.
  EOT
  type = list(object({
    name = string
    crit_alarm = optional(object({
      name = string
      arn  = string
    }))
    warn_alarm = optional(object({
      name = string
      arn  = string
    }))
    metrics = optional(list(object({
      namespace      = optional(string)
      metric_name    = optional(string)
      dimensions     = optional(map(string), {})
      stat           = optional(string, "Average")
      label          = string
      warn_threshold = optional(number)
      crit_threshold = optional(number)
      expression     = optional(string)
      using_metrics = optional(list(object({
        id          = string
        namespace   = string
        metric_name = string
        dimensions  = optional(map(string), {})
        stat        = optional(string, "Average")
      })), [])
    })), [])
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
    render a metric-math widget, `search_expression` to render a single
    widget covering many resources at once via CloudWatch's native SEARCH()
    (e.g. combining one metric across every instance in a fleet into one
    graph, one line per instance, without listing each instance by hand), or
    leave both null and populate `namespace`/`metric_name`/`dimensions`/`stat`
    to render a plain metric widget. Leave the whole list empty to omit
    metric widgets from Tier 2.
  EOT
  type = list(object({
    label             = string
    namespace         = optional(string)
    metric_name       = optional(string)
    dimensions        = optional(map(string), {})
    stat              = optional(string, "Average")
    expression        = optional(string)
    search_expression = optional(string)
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

variable "tier3_combined_resources" {
  description = <<-EOT
    Resources whose metrics should be combined onto a single account-wide
    Tier 3 dashboard - one widget per metric per resource - instead of each
    resource getting its own dashboard the way tier3_resources does. Widget
    titles are "<resource_name> - <metric label>" so metrics stay
    identifiable once many resources are combined onto one board.

    Set warn_threshold and/or crit_threshold on a metric to draw horizontal
    reference lines at those values.

    This is independent of tier3_resources - use one, the other, or both.
    Leave empty to skip the combined dashboard.
  EOT
  type = list(object({
    resource_name = string
    metrics = list(object({
      namespace      = optional(string)
      metric_name    = optional(string)
      dimensions     = optional(map(string), {})
      stat           = optional(string, "Average")
      label          = string
      warn_threshold = optional(number)
      crit_threshold = optional(number)
      expression     = optional(string)
      using_metrics = optional(list(object({
        id          = string
        namespace   = string
        metric_name = string
        dimensions  = optional(map(string), {})
        stat        = optional(string, "Average")
      })), [])
    }))
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
