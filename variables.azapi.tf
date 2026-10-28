variable "ignore_body_changes" {
  type = object({
    network_bastion_hosts          = optional(list(string), [])
    authorization_locks            = optional(list(string), [])
    authorization_role_assignments = optional(list(string), [])
    insights_diagnostic_settings   = optional(list(string), [])

    network_public_ip_addresses = optional(object({
      network_public_ip_addresses    = optional(list(string), [])
      authorization_locks            = optional(list(string), [])
      authorization_role_assignments = optional(list(string), [])
      insights_diagnostic_settings   = optional(list(string), [])
    }), {})
  })
  default     = {}
  description = <<DESCRIPTION
Paths in each resource's `body` whose changes the AzAPI provider ignores. Prefer Terraform's `lifecycle.ignore_changes` when the paths are static; use this variable when the paths must be derived from variables or other non-static values.

Paths use dot notation, for example `properties.scaleUnits`. Individual list items cannot be targeted; ignore the whole list property instead. Configuration changes at an ignored path are **not** sent to Azure until that path is removed from the list. Changes take effect only after an apply, because the value is held in provider-private state.

- `network_bastion_hosts` - Ignored body paths for the bastion host.
- `authorization_locks` - Ignored body paths for the bastion host's lock.
- `authorization_role_assignments` - Ignored body paths for the bastion host's role assignments.
- `insights_diagnostic_settings` - Ignored body paths for the bastion host's diagnostic settings.
- `network_public_ip_addresses` - Slot for the `az-tf-mlz-public-ip` call (its `network_public_ip_addresses` and interface keys).
DESCRIPTION
  nullable    = false
}

variable "resource_types" {
  type = object({
    network_bastion_hosts          = optional(string, "Microsoft.Network/bastionHosts@2025-07-01")
    authorization_locks            = optional(string, "Microsoft.Authorization/locks@2020-05-01")
    authorization_role_assignments = optional(string, "Microsoft.Authorization/roleAssignments@2022-04-01")
    insights_diagnostic_settings   = optional(string, "Microsoft.Insights/diagnosticSettings@2021-05-01-preview")

    network_public_ip_addresses = optional(object({
      network_public_ip_addresses    = optional(string)
      authorization_locks            = optional(string)
      authorization_role_assignments = optional(string)
      insights_diagnostic_settings   = optional(string)
    }), {})
  })
  default     = {}
  description = <<DESCRIPTION
Override the AzAPI `<provider>/<resource>@<api-version>` strings used by this module and the modules it calls. Each key defaults to a tested value; supply only the keys you want to override.

- `network_bastion_hosts` - The bastion host.
- `authorization_locks` - The lock on the bastion host.
- `authorization_role_assignments` - Role assignments on the bastion host.
- `insights_diagnostic_settings` - Diagnostic settings on the bastion host.
- `network_public_ip_addresses` - Slot for the `az-tf-mlz-public-ip` call. Defaults live in that module.
DESCRIPTION
  nullable    = false
}

variable "retry" {
  type = object({
    error_message_regex  = optional(list(string), ["AnotherOperationInProgress"])
    interval_seconds     = optional(number, 30)
    max_interval_seconds = optional(number, 300)
  })
  default     = {}
  description = <<DESCRIPTION
Retry configuration applied to every `azapi` resource managed by the module and the modules it calls. Defaults retry `AnotherOperationInProgress`, which Azure returns while another operation runs on the same network resources (in a composition, the virtual network being written at the same time); any field can be overridden.

- `error_message_regex`  - (Optional) A list of regex patterns matching error messages that trigger a retry. Defaults to `["AnotherOperationInProgress"]`.
- `interval_seconds`     - (Optional) Initial interval between retries in seconds. Defaults to `30`.
- `max_interval_seconds` - (Optional) Maximum interval between retries in seconds. Defaults to `300`.

See <https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource#retry> for full semantics.
DESCRIPTION
}

variable "timeouts" {
  type = object({
    create = optional(string)
    read   = optional(string)
    update = optional(string)
    delete = optional(string)
  })
  default     = null
  description = <<DESCRIPTION
Default per-operation timeouts applied to every `azapi` resource managed by the module and the modules it calls. Defaults to `null` (provider defaults). Each value is a Go duration string (e.g. `30m`, `1h`).

- `create` - (Optional) Timeout for create operations.
- `read`   - (Optional) Timeout for read operations.
- `update` - (Optional) Timeout for update operations.
- `delete` - (Optional) Timeout for delete operations.
DESCRIPTION
}
