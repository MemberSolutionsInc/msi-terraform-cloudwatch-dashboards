locals {
  # ---------------------------------------------------------------------
  # Tier 1 - one Alarm Status widget per composite alarm, 3 per row.
  # ---------------------------------------------------------------------
  tier1_widgets_per_row = 3
  tier1_widget_width    = 8
  tier1_widget_height   = 6

  tier1_alarm_widgets = [
    for idx, alarm in var.tier1_composite_alarms : {
      type   = "alarm"
      x      = (idx % local.tier1_widgets_per_row) * local.tier1_widget_width
      y      = floor(idx / local.tier1_widgets_per_row) * local.tier1_widget_height
      width  = local.tier1_widget_width
      height = local.tier1_widget_height
      properties = {
        title  = alarm.label
        alarms = [alarm.arn]
      }
    }
  ]

  # ---------------------------------------------------------------------
  # Tier 2 - $service/$env dashboard variables, metric(-math) widgets, and
  # a single Alarm Status widget grid filtered to ALARM state.
  # ---------------------------------------------------------------------
  tier2_service_variable = length(var.tier2_service_values) > 0 ? [{
    type         = "property"
    property     = "Service"
    inputType    = "select"
    id           = "service"
    label        = "service"
    defaultValue = var.tier2_default_service != "" ? var.tier2_default_service : var.tier2_service_values[0]
    visible      = true
    values       = [for v in var.tier2_service_values : { value = v, label = v }]
  }] : []

  tier2_env_variable = length(var.tier2_env_values) > 0 ? [{
    type         = "property"
    property     = "Environment"
    inputType    = "select"
    id           = "env"
    label        = "env"
    defaultValue = var.tier2_default_env != "" ? var.tier2_default_env : var.tier2_env_values[0]
    visible      = true
    values       = [for v in var.tier2_env_values : { value = v, label = v }]
  }] : []

  tier2_variables = concat(local.tier2_service_variable, local.tier2_env_variable)

  tier2_metrics_per_row = 2
  tier2_metric_width    = 12
  tier2_metric_height   = 6

  # Build the CloudWatch "metrics" array for a single tier2_metrics entry.
  # Plain metric:   [namespace, metric_name, dim, val, ..., {stat, label}]
  # Metric math:    underlying series (visible=false) + one [{expression,...}]
  #
  # NOTE: this is deliberately split into two separate for-expressions (one
  # per branch) rather than a single ternary. A ternary whose two branches
  # are tuples of different length/shape fails Terraform's "inconsistent
  # conditional result types" check as soon as any list entry takes the
  # "other" branch (e.g. a plain metric with 1 dimension vs. a metric-math
  # entry with 2 underlying metrics) - splitting and merging sidesteps that
  # entirely, since each for-expression only ever evaluates its own branch.
  tier2_plain_metric_rows = {
    for idx, m in var.tier2_metrics : idx => [
      concat(
        [m.namespace, m.metric_name],
        flatten([for k, v in m.dimensions : [k, v]]),
        [{ stat = m.stat, label = m.label }]
      )
    ]
    if m.expression == null
  }

  tier2_math_metric_rows = {
    for idx, m in var.tier2_metrics : idx => concat(
      [
        for um in m.using_metrics : concat(
          [um.namespace, um.metric_name],
          flatten([for k, v in um.dimensions : [k, v]]),
          [{ id = um.id, stat = um.stat, visible = false }]
        )
      ],
      [[{ expression = m.expression, label = m.label, id = "expr${idx}" }]]
    )
    if m.expression != null
  }

  tier2_metric_rows = merge(local.tier2_plain_metric_rows, local.tier2_math_metric_rows)

  tier2_metric_widgets = [
    for idx, m in var.tier2_metrics : {
      type   = "metric"
      x      = (idx % local.tier2_metrics_per_row) * local.tier2_metric_width
      y      = floor(idx / local.tier2_metrics_per_row) * local.tier2_metric_height
      width  = local.tier2_metric_width
      height = local.tier2_metric_height
      properties = {
        title   = m.label
        view    = "timeSeries"
        stacked = false
        region  = "$${AWS::Region}"
        metrics = local.tier2_metric_rows[idx]
      }
    }
  ]

  tier2_metric_rows_used = ceil(length(var.tier2_metrics) / local.tier2_metrics_per_row)
  tier2_alarm_grid_y     = local.tier2_metric_rows_used * local.tier2_metric_height

  tier2_alarm_widget = length(var.tier2_alarms) > 0 ? [{
    type   = "alarm"
    x      = 0
    y      = local.tier2_alarm_grid_y
    width  = 24
    height = 6
    properties = {
      title  = "Active Alarms (ALARM state)"
      alarms = [for a in var.tier2_alarms : a.arn]
      states = ["ALARM"]
    }
  }] : []

  tier2_widgets = concat(local.tier2_metric_widgets, local.tier2_alarm_widget)

  # ---------------------------------------------------------------------
  # Tier 3 - one dashboard per resource: metric widgets + a Logs Insights
  # widget + (optionally) an X-Ray trace map widget.
  # ---------------------------------------------------------------------
  tier3_resources_by_name = { for r in var.tier3_resources : r.resource_name => r }

  tier3_metrics_per_row = 2
  tier3_metric_width    = 12
  tier3_metric_height   = 6

  tier3_metric_widgets = {
    for name, r in local.tier3_resources_by_name : name => [
      for idx, m in r.metrics : {
        type   = "metric"
        x      = (idx % local.tier3_metrics_per_row) * local.tier3_metric_width
        y      = floor(idx / local.tier3_metrics_per_row) * local.tier3_metric_height
        width  = local.tier3_metric_width
        height = local.tier3_metric_height
        properties = {
          title   = m.label
          view    = "timeSeries"
          stacked = false
          region  = "$${AWS::Region}"
          metrics = [
            concat(
              [m.namespace, m.metric_name],
              flatten([for k, v in m.dimensions : [k, v]]),
              [{ stat = m.stat, label = m.label }]
            )
          ]
        }
      }
    ]
  }

  tier3_metric_rows_used = {
    for name, r in local.tier3_resources_by_name :
    name => ceil(max(length(r.metrics), 1) / local.tier3_metrics_per_row)
  }

  tier3_log_widgets = {
    for name, r in local.tier3_resources_by_name : name => {
      type   = "log"
      x      = 0
      y      = local.tier3_metric_rows_used[name] * local.tier3_metric_height
      width  = 24
      height = 6
      properties = {
        title  = "Logs - ${name}"
        view   = "table"
        region = "$${AWS::Region}"
        query = join(" | ", concat(
          [for lg in r.log_group_names : "SOURCE '${lg}'"],
          [lookup(var.tier3_log_queries, name, var.tier3_default_log_query)]
        ))
      }
    }
  }

  tier3_xray_widgets = {
    for name, r in local.tier3_resources_by_name : name => (
      r.has_xray ? [{
        type   = "xray"
        x      = 0
        y      = (local.tier3_metric_rows_used[name] * local.tier3_metric_height) + 6
        width  = 24
        height = 6
        properties = {
          title  = "X-Ray Trace Map - ${name}"
          region = "$${AWS::Region}"
          type   = "service_map"
          query  = "service(\"${name}\")"
        }
      }] : []
    )
  }

  tier3_widgets = {
    for name, r in local.tier3_resources_by_name :
    name => concat(local.tier3_metric_widgets[name], [local.tier3_log_widgets[name]], local.tier3_xray_widgets[name])
  }
}

# ---------------------------------------------------------------------------
# Tier 1 - executive health dashboard
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_dashboard" "tier1" {
  count = length(var.tier1_composite_alarms) > 0 ? 1 : 0

  dashboard_name = "${var.dashboard_name_prefix}-tier1"
  dashboard_body = jsonencode({
    widgets = local.tier1_alarm_widgets
  })
}

# ---------------------------------------------------------------------------
# Tier 2 - operational triage dashboard
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_dashboard" "tier2" {
  count = (length(var.tier2_metrics) > 0 || length(var.tier2_alarms) > 0) ? 1 : 0

  dashboard_name = "${var.dashboard_name_prefix}-tier2"
  dashboard_body = jsonencode(merge(
    { widgets = local.tier2_widgets },
    length(local.tier2_variables) > 0 ? { variables = local.tier2_variables } : {}
  ))
}

# ---------------------------------------------------------------------------
# Tier 3 - deep investigation dashboards (one per resource)
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_dashboard" "tier3" {
  for_each = local.tier3_resources_by_name

  dashboard_name = "${var.dashboard_name_prefix}-tier3-${each.key}"
  dashboard_body = jsonencode({
    widgets = local.tier3_widgets[each.key]
  })
}

# ---------------------------------------------------------------------------
# Saved Logs Insights query definitions
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_query_definition" "saved" {
  for_each = { for q in var.saved_log_insights_queries : q.name => q }

  name            = each.value.name
  query_string    = each.value.query_string
  log_group_names = each.value.log_group_names
}
