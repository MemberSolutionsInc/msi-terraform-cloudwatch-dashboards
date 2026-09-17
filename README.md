# msi-terraform-cloudwatch-dashboards

CloudWatch dashboard module implementing the org's 3-tier observability model
(Tier 1 executive health, Tier 2 operational triage, Tier 3 deep
investigation). This module is one of several independently-versioned
CloudWatch modules split out of a single org-wide observability initiative,
so bumping a dashboard release doesn't force a version bump on sibling
modules such as `msi-terraform-cloudwatch-composite-alarms`.

## The 3-tier model

- **Tier 1 - executive health**: two independent modes, usable together or
  separately.
  - `tier1_composite_alarms`: a grid of Alarm Status widgets, one per
    composite alarm, all on a single combined dashboard. No graphs - just
    OK / ALARM / INSUFFICIENT_DATA per business service.
  - `tier1_applications`: one dashboard **per application**, opening with a
    severity-based status indicator - a `crit_alarm` and a `warn_alarm`
    rendered as Alarm Status widgets side by side (typically the warn/crit
    split of a composite alarm from the sibling
    `msi-terraform-cloudwatch-composite-alarms` module) - followed by every
    metric widget for that application. CloudWatch has no native "the whole
    dashboard is one color" widget, so this crit/warn pair is the closest
    equivalent: crit in `ALARM` reads as red, only warn in `ALARM` reads as
    yellow, neither reads as green.
- **Tier 2 - operational triage**: scoped by `$service` / `$env` dashboard
  variables, with metric widgets (`tier2_metrics`) for error rate / latency /
  throughput trends, plus a single Alarm Status widget grid filtered to
  alarms currently in `ALARM` state (`tier2_alarms`). Each `tier2_metrics`
  entry renders as a plain metric widget, a metric-math widget (set
  `expression` + `using_metrics`), or a `SEARCH()`-based widget (set
  `search_expression`) that combines one metric across many resources into a
  single graph - e.g. one "CPU - all instances" widget covering an entire
  fleet, one line per instance, without listing each instance by hand.
- **Tier 3 - deep investigation**: two independent modes, usable together or
  separately.
  - `tier3_resources`: one dashboard **per resource**, each combining metric
    widgets, a Logs Insights query widget (query text from
    `tier3_log_queries`), and - when `has_xray = true` for that resource - an
    X-Ray trace map widget.
  - `tier3_combined_resources`: every resource's metrics flattened onto a
    **single account-wide dashboard**, one widget per metric per resource
    (widget titles prefixed `<resource_name> - <metric label>` so metrics
    stay identifiable once combined).

Metrics in `tier1_applications` and `tier3_combined_resources` accept
`warn_threshold` / `crit_threshold` (rendered as horizontal reference lines),
and - like `tier2_metrics` - can be a metric-math widget instead of a plain
metric by setting `expression` + `using_metrics` (e.g. combining a "bytes in"
and "bytes out" metric into one "Network Errors" widget).

Each tier/mode is only created when its inputs are populated, so a caller
can adopt them incrementally: leave `tier1_composite_alarms` and
`tier1_applications` both empty and no Tier 1 dashboard is created, etc.

This module also creates one `aws_cloudwatch_query_definition` per entry in
`saved_log_insights_queries`, so useful Logs Insights queries can be reused
from Tier 3 dashboards or ad-hoc from the CloudWatch console.

## Usage

```hcl
module "dashboards" {
  source = "git::https://github.com/MemberSolutionsInc/msi-terraform-cloudwatch-dashboards.git?ref=v0.1.0"

  dashboard_name_prefix = "checkout-prod"

  # Tier 1 - executive health
  tier1_composite_alarms = [
    {
      name  = "checkout-service-health"
      arn   = "arn:aws:cloudwatch:us-east-1:123456789012:alarm:checkout-service-health"
      label = "Checkout"
    },
    {
      name  = "payments-service-health"
      arn   = "arn:aws:cloudwatch:us-east-1:123456789012:alarm:payments-service-health"
      label = "Payments"
    },
    {
      name  = "billing-service-health"
      arn   = "arn:aws:cloudwatch:us-east-1:123456789012:alarm:billing-service-health"
      label = "Billing"
    },
  ]

  # Tier 2 - operational triage
  tier2_service_values  = ["checkout", "payments", "billing"]
  tier2_env_values      = ["prod", "staging"]
  tier2_default_service = "checkout"
  tier2_default_env     = "prod"

  tier2_metrics = [
    {
      label       = "5xx Error Count"
      namespace   = "AWS/ApplicationELB"
      metric_name = "HTTPCode_Target_5XX_Count"
      dimensions  = { LoadBalancer = "app/checkout-prod/abc123" }
      stat        = "Sum"
    },
    {
      label       = "p99 Latency"
      namespace   = "AWS/ApplicationELB"
      metric_name = "TargetResponseTime"
      dimensions  = { LoadBalancer = "app/checkout-prod/abc123" }
      stat        = "p99"
    },
    {
      label      = "Error Rate (%)"
      expression = "(errors / requests) * 100"
      using_metrics = [
        { id = "errors", namespace = "AWS/ApplicationELB", metric_name = "HTTPCode_Target_5XX_Count", dimensions = { LoadBalancer = "app/checkout-prod/abc123" }, stat = "Sum" },
        { id = "requests", namespace = "AWS/ApplicationELB", metric_name = "RequestCount", dimensions = { LoadBalancer = "app/checkout-prod/abc123" }, stat = "Sum" },
      ]
    },
  ]

  tier2_alarms = [
    {
      name  = "checkout-high-error-rate"
      arn   = "arn:aws:cloudwatch:us-east-1:123456789012:alarm:checkout-high-error-rate"
      label = "Checkout high error rate"
    },
    {
      name  = "checkout-high-latency"
      arn   = "arn:aws:cloudwatch:us-east-1:123456789012:alarm:checkout-high-latency"
      label = "Checkout high latency"
    },
  ]
}
```

Tier 3 (per-resource deep investigation) can be added the same way:

```hcl
  tier3_resources = [
    {
      resource_name = "checkout-api"
      metrics = [
        { namespace = "AWS/Lambda", metric_name = "Duration", label = "Duration", stat = "Average", dimensions = { FunctionName = "checkout-api" } },
        { namespace = "AWS/Lambda", metric_name = "Errors", label = "Errors", stat = "Sum", dimensions = { FunctionName = "checkout-api" } },
      ]
      log_group_names = ["/aws/lambda/checkout-api"]
      has_xray        = true
    },
  ]

  tier3_log_queries = {
    checkout-api = "fields @timestamp, @message | filter @message like /ERROR/ | sort @timestamp desc | limit 50"
  }

  saved_log_insights_queries = [
    {
      name            = "checkout-api-errors"
      query_string    = "fields @timestamp, @message | filter @message like /ERROR/ | sort @timestamp desc | limit 100"
      log_group_names = ["/aws/lambda/checkout-api"]
    },
  ]
```

Tier 1 per-application and Tier 2's combined-metric widget:

```hcl
  # Tier 1 - one dashboard per application, severity-based status
  tier1_applications = [
    {
      name = "checkout-api"
      crit_alarm = {
        name = "checkout-api-crit"
        arn  = "arn:aws:cloudwatch:us-east-1:123456789012:alarm:checkout-api-crit"
      }
      warn_alarm = {
        name = "checkout-api-warn"
        arn  = "arn:aws:cloudwatch:us-east-1:123456789012:alarm:checkout-api-warn"
      }
      metrics = [
        {
          namespace      = "AWS/Lambda"
          metric_name    = "Duration"
          dimensions     = { FunctionName = "checkout-api" }
          label          = "Duration"
          warn_threshold = 1000
          crit_threshold = 3000
        },
      ]
    },
  ]

  # Tier 2 - one metric combined across an entire fleet via SEARCH()
  tier2_metrics = [
    {
      label             = "CPU - all instances"
      search_expression = "SEARCH('{AWS/EC2,InstanceId} MetricName=\"CPUUtilization\"', 'Average', 300)"
    },
  ]
```

Tier 3 combined mode (one account-wide dashboard instead of one per resource):

```hcl
  tier3_combined_resources = [
    {
      resource_name = "checkout-api"
      metrics = [
        { namespace = "AWS/Lambda", metric_name = "Duration", label = "Duration", stat = "Average", dimensions = { FunctionName = "checkout-api" } },
        { namespace = "AWS/Lambda", metric_name = "Errors", label = "Errors", stat = "Sum", dimensions = { FunctionName = "checkout-api" } },
      ]
    },
    {
      resource_name = "payments-api"
      metrics = [
        { namespace = "AWS/Lambda", metric_name = "Duration", label = "Duration", stat = "Average", dimensions = { FunctionName = "payments-api" } },
      ]
    },
  ]
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `dashboard_name_prefix` | `string` | n/a | Prefix used to name the tier1/tier2/tier3 dashboards. |
| `tier1_composite_alarms` | `list(object({ name, arn, label }))` | `[]` | Composite alarms rendered as Tier 1 Alarm Status widgets on one combined dashboard. Empty skips this mode. |
| `tier1_applications` | `list(object({ name, crit_alarm, warn_alarm, metrics }))` | `[]` | One entry per application/service, each getting its own Tier 1 dashboard with a severity-based status indicator plus that application's metric (or metric-math) widgets. Independent of `tier1_composite_alarms`. Empty skips this mode. |
| `tier2_service_values` | `list(string)` | `[]` | Dropdown values for the Tier 2 `$service` dashboard variable. |
| `tier2_default_service` | `string` | `""` | Default `$service` value; falls back to the first `tier2_service_values` entry. |
| `tier2_env_values` | `list(string)` | `[]` | Dropdown values for the Tier 2 `$env` dashboard variable. |
| `tier2_default_env` | `string` | `""` | Default `$env` value; falls back to the first `tier2_env_values` entry. |
| `tier2_metrics` | `list(object({ label, namespace, metric_name, dimensions, stat, expression, search_expression, using_metrics }))` | `[]` | Metric / metric-math / SEARCH() widgets on the Tier 2 dashboard. |
| `tier2_alarms` | `list(object({ name, arn, label }))` | `[]` | Alarms rendered in the Tier 2 ALARM-state widget grid. |
| `tier3_resources` | `list(object({ resource_name, metrics, log_group_names, has_xray }))` | `[]` | One entry per Tier 3 per-resource dashboard. Empty skips this mode. |
| `tier3_combined_resources` | `list(object({ resource_name, metrics }))` | `[]` | Resources whose metric (or metric-math) widgets are combined onto one account-wide Tier 3 dashboard instead of one dashboard each. Independent of `tier3_resources`. Empty skips this mode. |
| `tier3_log_queries` | `map(string)` | `{}` | `resource_name => Logs Insights query string` for each Tier 3 dashboard. |
| `tier3_default_log_query` | `string` | `"fields @timestamp, @message | sort @timestamp desc | limit 100"` | Fallback query for a Tier 3 resource missing from `tier3_log_queries`. |
| `saved_log_insights_queries` | `list(object({ name, query_string, log_group_names }))` | `[]` | Saved `aws_cloudwatch_query_definition` entries. |

## Outputs

| Name | Description |
|---|---|
| `tier1_dashboard_name` | Tier 1 combined dashboard name, or `null` if not created. |
| `tier1_dashboard_arn` | Tier 1 combined dashboard ARN, or `null` if not created. |
| `tier1_application_dashboard_names` | Map of application name => Tier 1 per-application dashboard name, for every `tier1_applications` entry. |
| `tier1_application_dashboard_arns` | Map of application name => Tier 1 per-application dashboard ARN, for every `tier1_applications` entry. |
| `tier2_dashboard_name` | Tier 2 dashboard name, or `null` if not created. |
| `tier2_dashboard_arn` | Tier 2 dashboard ARN, or `null` if not created. |
| `tier3_dashboard_names` | Map of `resource_name => dashboard name` for every `tier3_resources` entry. |
| `tier3_dashboard_arns` | Map of `resource_name => dashboard ARN` for every `tier3_resources` entry. |
| `tier3_combined_dashboard_name` | Tier 3 combined (account-wide) dashboard name, or `null` if not created. |
| `tier3_combined_dashboard_arn` | Tier 3 combined (account-wide) dashboard ARN, or `null` if not created. |
| `query_definition_ids` | Map of saved query `name => query definition ID`. |

## Notes / caveats

- `region` fields in generated widgets use the CloudWatch dashboard macro
  `${AWS::Region}` so dashboards render correctly regardless of which region
  they're deployed into.
- The Tier 3 X-Ray widget uses `"type": "xray"` with a `service_map` query
  scoped to the resource name. Verify the rendered widget in the console
  after first apply, since AWS's dashboard JSON schema for X-Ray widgets is
  less thoroughly documented than metric/alarm/log widgets.
