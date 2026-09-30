# GitHub Copilot Instructions — Azure Policy Agents

This repository tests Azure Policy definitions using an agentic CI/CD pipeline. Every file under `policyDefinitions/` is validated, deployed, and tested automatically on pull request. These instructions apply to all Copilot code review and generation in this repository.

---

## 0. Security and Secret Handling (Applies to ALL Files)

This rule overrides scope: it applies to every file in the repository, including `policyDefinitions/`, `agentInstructions/`, `.github/`, `docs/`, test payloads, and any generated script or example.

Never write a real or realistic-looking credential into any file. This includes API keys, account keys, connection strings, SAS tokens, passwords, client secrets, bearer or JWT tokens, and private keys. Automated agents in this repo commit instruction and example content, and secret scanners flag credential-shaped strings even when the value is fake, so a realistic sample still generates security alerts and incident noise.

When an example needs a credential-shaped value, use an obvious placeholder that a scanner will not mistake for a real secret:

- Prefer an explicit non-secret token such as `REPLACE_WITH_FAKE_TEST_KEY_NOT_A_REAL_SECRET`, `EXAMPLE_PLACEHOLDER_KEY`, or `<your-key-here>`.
- Do not use hex-only strings of 32 characters or more (for example `0123456789abcdef0123456789abcdef`); these match key detectors.
- Do not paste any value copied from a live resource, a portal blade, or a CLI output, even from a test or sandbox subscription.
- Placeholder text should contain a word such as `FAKE`, `PLACEHOLDER`, `REPLACE`, `EXAMPLE`, or `REDACTED` so both humans and the CI secret guard recognise it as non-secret.

In code review, flag any of the following as a blocking security issue and request an obvious placeholder instead:

- A hex string of 32 or more characters used as a key, secret, token, or password value.
- Any assignment or JSON field named `key`, `apiKey`, `secret`, `password`, `token`, `clientSecret`, `accountKey`, `connectionString`, or `sasToken` whose value is not an obvious placeholder.
- A storage `AccountKey=...`, an `AKIA...` AWS key, or a `eyJ...` JWT anywhere in the diff.

The `instructions-agent.ps1` maintenance script enforces this with a secret guard that rejects any proposed patch whose content matches a credential pattern. Do not weaken or bypass that guard.

---

## Scope of These Instructions

These instructions apply specifically to JSON files in `policyDefinitions/`. Copilot should flag any deviation from the rules below as a review comment with a clear explanation of the correct approach.

**Reference documentation:**
- [Definition structure basics](https://learn.microsoft.com/en-us/azure/governance/policy/concepts/definition-structure-basics)
- [Parameters](https://learn.microsoft.com/en-us/azure/governance/policy/concepts/definition-structure-parameters)
- [Policy rule](https://learn.microsoft.com/en-us/azure/governance/policy/concepts/definition-structure-policy-rule)
- [Aliases](https://learn.microsoft.com/en-us/azure/governance/policy/concepts/definition-structure-alias)
- [Authoring policies for arrays](https://learn.microsoft.com/en-us/azure/governance/policy/how-to/author-policies-for-arrays)
- [Troubleshooting](https://learn.microsoft.com/en-us/azure/governance/policy/troubleshoot/general)

---

## 1. Top-Level JSON Structure

Every policy definition file must be valid JSON and follow this exact structure:

```json
{
  "name": "<unique-policy-name>",
  "type": "Microsoft.Authorization/policyDefinitions",
  "apiVersion": "2021-06-01",
  "scope": null,
  "properties": {
    "displayName": "...",
    "description": "...",
    "policyType": "Custom",
    "mode": "Indexed | All",
    "metadata": { ... },
    "parameters": { ... },
    "policyRule": {
      "if": { ... },
      "then": { ... }
    }
  }
}
```

### Required checks:

- **Exact key spelling**: All keys under `properties` must be spelled correctly. Common typos to reject:
  - `parameterss` instead of `parameters`
  - `policyRules` instead of `policyRule`
  - `displayname` instead of `displayName`
  - `policytype` instead of `policyType`
  - Any key that does not match the schema exactly — JSON parsers accept arbitrary keys silently; this repo's validation script performs explicit string matching to catch these.
- **`type` must be** `"Microsoft.Authorization/policyDefinitions"` — no other value is valid for standalone policy definitions.
- **`scope` must be** `null` for subscription/management-group-scoped deployments from this repo.
- **`displayName`** max 128 characters. **`description`** max 512 characters.
- **`policyType`** must be `"Custom"` for all definitions in this repo.

---

## 2. Mode Selection

| Scenario | Correct `mode` |
|---|---|
| Policy checks tags or location | `"Indexed"` |
| Policy targets resource groups or subscriptions | `"All"` |
| Policy targets all resource types without exception | `"All"` |
| Kubernetes, Key Vault Data, Network Manager policies | Use the appropriate Resource Provider mode string |

**Common mistake**: Using `"Indexed"` for a policy that applies to resource groups — resource groups are not evaluated in `Indexed` mode. Use `"All"` and add an explicit `type` condition in the `if` block.

---

## 3. Parameters

Parameters live at `properties.parameters`, **not** at any other level. Each parameter must have:

```json
"parameters": {
  "<parameterName>": {
    "type": "String | Array | Object | Boolean | Integer | Float | DateTime",
    "metadata": {
      "displayName": "...",
      "description": "..."
    },
    "defaultValue": <value>,
    "allowedValues": [...]
  }
}
```

### Rules:

- **`type`** is required and immutable after creation. Azure Policy parameter types are case-insensitive; this repo uses capitalized forms (e.g. `"Array"`, `"String"`). Use `"Array"` (not `"String"`) when the parameter needs to hold multiple values.
- **`defaultValue`** must be provided when adding a parameter to an existing assigned definition, to prevent assignment invalidation.
- **`allowedValues`** comparisons are case-sensitive during assignment but case-insensitive during rule evaluation — document this if relying on casing.
- **`strongType`** in `metadata` is a portal UI hint only. Accepted values: `"location"`, `"resourceTypes"`, `"storageSkus"`, `"vmSKUs"`, `"existingResourceGroups"`, or a resource type like `"Microsoft.Network/virtualNetworks/subnets"`. A misspelled `strongType` key (e.g. `strongTypee`) is harmless to policy enforcement but should be flagged as a typo in review.
- **Parameter references in `policyRule`** must exactly match a name defined in `properties.parameters`. Use the single-quoted form `[parameters('x')]`; each such expression must have a corresponding key `x` in `properties.parameters`. This single-quoted form is validated by the CI pipeline and will cause `exit 1` if violated.
- Parameters cannot be removed from a definition that has existing assignments.

---

## 4. Policy Rule — `if` Block

The `if` block defines when the policy effect is triggered.

### Logical Operators

Only these are valid at the top level of `if` or within nested conditions:
- `"not": { <condition> }` — inverts the result
- `"allOf": [ <condition>, ... ]` — all must be true (logical AND)
- `"anyOf": [ <condition>, ... ]` — at least one must be true (logical OR)

**Syntax check**: `allOf` and `anyOf` take **arrays** — every element must be separated by a comma. A missing comma between array elements produces invalid JSON and will fail the CI pipeline immediately.

### Conditions

Every condition is an object with exactly one `field`/`value`/`count` expression plus one condition operator. Valid operators:

`equals`, `notEquals`, `like`, `notLike`, `match`, `matchInsensitively`, `notMatch`, `notMatchInsensitively`, `contains`, `notContains`, `in`, `notIn`, `containsKey`, `notContainsKey`, `less`, `lessOrEquals`, `greater`, `greaterOrEquals`, `exists`

**Important behaviours:**
- All string comparisons (except `match`/`notMatch`) are **case-insensitive**.
- `match`/`notMatch` use: `#` = digit, `?` = letter, `.` = any character.
- `like`/`notLike` accept exactly **one** `*` wildcard.
- `contains`/`notContains` do **not** support wildcards.
- `in`/`notIn` require an array value — can be a literal array or `[parameters('x')]` where `x` is an array-type parameter.

### Field Expressions

Use `"field": "<alias>"` to reference a resource property. Common built-in fields:
- `"name"`, `"fullName"`, `"type"`, `"location"`, `"kind"`, `"id"`, `"identity.type"`
- `"tags['<tagName>']"` — use bracket syntax for tag names with special characters
- Property aliases (e.g. `"Microsoft.Storage/storageAccounts/networkAcls.bypass"`)

**Do not** use the legacy `"source": "action"` syntax — it is no longer supported.

**Type condition best practice**: When using a resource-type-specific alias, always add a `type` condition first to scope the rule to only that resource type. Without it, the definition may fail validation with "targets multiple resource types".

```json
{
  "allOf": [
    {
      "field": "type",
      "equals": "Microsoft.Storage/storageAccounts"
    },
    {
      "field": "Microsoft.Storage/storageAccounts/networkAcls.bypass",
      "notEquals": "AzureServices"
    }
  ]
}
```

### Value Expressions

Use `"value": "[<template-function>]"` to evaluate the result of a function:

```json
{
  "value": "[resourceGroup().name]",
  "like": "*-prod"
}
```

**Avoiding template failures**: If a template function can produce an error (e.g. `substring()` on a string shorter than the requested length), wrap it in `if()` to guard against the error. A failed template function evaluation becomes an implicit **deny** — this can silently block legitimate resources.

```json
{
  "value": "[if(greaterOrEquals(length(field('name')), 3), substring(field('name'), 0, 3), 'N/A')]",
  "equals": "abc"
}
```

---

## 5. Policy Rule — `then` Block / Effects

The `then` block must specify an `effect`. Valid effects for custom policies in this repo:

| Effect | Use case |
|---|---|
| `deny` | Block non-compliant resource creation/update |
| `audit` | Log non-compliance without blocking |
| `auditIfNotExists` | Audit when a related resource does not exist |
| `deployIfNotExists` (DINE) | Deploy a related resource if it does not exist |
| `modify` | Add/replace/remove tags or properties |
| `append` | Add fields to a resource |
| `disabled` | Turn off the policy without removing it |

**Effect as a parameter** (best practice for reusability):
```json
"then": {
  "effect": "[parameters('effect')]"
}
```
When parameterising the effect, provide `allowedValues` and a sensible `defaultValue`.

### `auditIfNotExists` / `deployIfNotExists` Requirements
Both require a `details` block in `then`:
```json
"then": {
  "effect": "deployIfNotExists",
  "details": {
    "type": "Microsoft.Insights/diagnosticSettings",
    "existenceCondition": { ... },
    "roleDefinitionIds": [ "/providers/Microsoft.Authorization/roleDefinitions/..." ],
    "deployment": { ... }
  }
}
```
- `type` is required.
- `roleDefinitionIds` must list every role the managed identity needs. Use full resource IDs, not role names.
- For DINE policies: the managed identity is automatically created at assignment time (`--assign-identity`) — ensure `roleDefinitionIds` is complete.

### `modify` Requirements
```json
"then": {
  "effect": "modify",
  "details": {
    "roleDefinitionIds": [ "..." ],
    "operations": [
      {
        "operation": "add | addOrReplace | remove",
        "field": "tags['<tagName>']",
        "value": "..."
      }
    ]
  }
}
```
- `operations` array is required.
- `roleDefinitionIds` is required.

---

## 6. Aliases

Use aliases to reference resource-type-specific properties. Find aliases using:
- Azure Policy extension for VS Code (recommended)
- `Get-AzPolicyAlias -NamespaceMatch '<namespace>'` in PowerShell
- `az provider show --namespace <ns> --expand "resourceTypes/aliases" --query "resourceTypes[].aliases[].name"`

### Array Aliases

Two alias forms exist for array properties:
- `Microsoft.Storage/storageAccounts/networkAcls.ipRules` — the whole array (use with `exists`)
- `Microsoft.Storage/storageAccounts/networkAcls.ipRules[*]` — each element individually

**Behaviour of `[*]` aliases in `field` conditions**: The condition applies to **all** elements with implicit `allOf`. An empty array evaluates as **true** (no element violates). Use `count` expressions when you need "at least one", "none", or "exactly N" semantics.

```json
{
  "count": {
    "field": "Microsoft.Network/networkSecurityGroups/securityRules[*]",
    "where": {
      "allOf": [
        { "field": "Microsoft.Network/networkSecurityGroups/securityRules[*].direction", "equals": "Inbound" },
        { "field": "Microsoft.Network/networkSecurityGroups/securityRules[*].access", "equals": "Allow" },
        { "field": "Microsoft.Network/networkSecurityGroups/securityRules[*].destinationPortRange", "equals": "3389" }
      ]
    }
  },
  "greater": 0
}
```

**Limits**: Max 5 `field count` expressions and 10 `value count` expressions per policy rule.

---

## 7. Arrays in Parameters and Conditions

- Use `"type": "array"` parameters (not `"string"`) whenever the policy needs multiple values.
- Once a parameter `type` is set and the policy is deployed, it **cannot be changed**.
- `in` / `notIn` conditions reference array parameters: `"in": "[parameters('allowedLocations')]"`.
- Use `count` with `value` to iterate over a parameter array:
  ```json
  {
    "count": {
      "value": "[parameters('namePatterns')]",
      "name": "pattern",
      "where": { "field": "name", "like": "[current('pattern')]" }
    },
    "greater": 0
  }
  ```

---

## 8. Policy Functions

Most ARM template functions are available in policy rules. **Not supported** in policy rules:
`copyIndex()`, `deployment()`, `environment()`, `extensionResourceId()`, `listKeys()`, `listSecrets()`, `list*`, `managementGroup()`, `newGuid()`, `providers()`, `reference()`, `resourceId()`, `variables()`

> Exception: The functions above **are** available inside `then.details.deployment.properties.template` in DINE policies.

**Policy-only functions**: `field()`, `addDays()`, `utcNow()`, `ipRangeContains()`, `current()`, `requestContext()`, `policy()`

**Template function in ARM deployment context**: If a policy function appears in an ARM template being deployed by the CI infrastructure (not in the policy rule itself), prefix it with an extra `[` to escape evaluation: `[[parameters('myParam')]`.

---

## 9. Policy Rule Limits

Flag any policy that approaches these authoring limits:

| Limit | Value |
|---|---|
| Condition expressions in `if` block | 4,096 |
| Condition expressions in `then` block | 128 |
| Policy functions per rule | 2,048 |
| Nested function depth | 64 |
| Function expression string length | 81,920 characters |
| `field count` expressions per array | 5 |
| `value count` expressions per rule | 10 |
| Value count iteration count | 100 |

Policies exceeding evaluation-time limits (e.g. concat producing a string > 131,072 chars) become an implicit **deny** without warning.

---

## 10. This Repository's Validation Rules

The CI pipeline (`validate-policies.ps1`) enforces additional checks beyond JSON syntax:

1. **Invalid JSON** — `ConvertFrom-Json` failure → `exit 1`, PR blocked.
2. **Misspelled `parameterss`** — raw string match → `exit 1`, PR blocked.
3. **Undefined parameter references** — every `[parameters('x')]` in `policyRule` must have a matching key in `properties.parameters` → `exit 1`, PR blocked.
4. **Missing `policyRule.if` or `policyRule.then`** → `exit 1`, PR blocked.
5. **Effect-specific structure missing** — `auditIfNotExists`/`deployIfNotExists` without `details.type`, or `modify` without `details.operations` → `exit 1`, PR blocked.

Copilot should proactively catch all of the above **before** the CI pipeline runs.

---

## 11. Common Mistakes to Flag in Review

| Mistake | Impact | Correct approach |
|---|---|---|
| Misspelled key under `properties` (e.g. `parameterss`) | CI `exit 1` — policy not tested | Correct the spelling |
| Missing comma between `allOf`/`anyOf` array elements | Invalid JSON — CI `exit 1` | Add comma |
| `[parameters('x')]` reference with no matching key in `properties.parameters` | CI `exit 1` | Ensure parameter is defined |
| Using `"mode": "Indexed"` for resource group targeting | Resource groups not evaluated | Use `"mode": "All"` |
| Array alias without `[*]` used where element-level check is intended | Compares whole array to scalar — always false | Add `[*]` suffix |
| Empty array evaluates as true with `field` + `[*]` alias | Policy ineffective on empty arrays | Use `count greaterOrEquals 1` instead |
| `substring()` without length guard | Implicit deny on short strings | Wrap with `if(greaterOrEquals(length(...)))` |
| DINE/modify policy missing `roleDefinitionIds` | Remediation task fails with permissions error | Add all required role IDs |
| `"type": "string"` parameter for multi-value input | Cannot accept multiple values | Use `"type": "array"` |
| Legacy `"source": "action"` syntax in `if` | Not supported, causes evaluation error | Use `"field": "type"` with `equals` |
| ARM template function passed through without `[[` escape | Function evaluated at deploy time, not by policy engine | Prefix with extra `[` |
| `strongTypee` or other misspelled `metadata` keys | Portal UX degraded; not enforced by CI | Fix the typo (warning, not blocking) |

---

## 12. Effect-Specific Test Routing

The CI pipeline routes each policy to a specialised testing agent based on its `effect`:

| Effect value | Agent |
|---|---|
| `deny` | Deny Policy Agent |
| `audit`, `auditIfNotExists` | Audit Policy Agent |
| `deployIfNotExists`, `dine` | DINE Policy Agent |
| `modify` | Modify Policy Agent |

If the effect is parameterised, the agent uses the `defaultValue` to determine routing. Ensure `defaultValue` reflects the intended primary effect.

---

## 13. Azure Policy Known Issues — Resource Type Limitations

> Source: [Azure/azure-policy known issues](https://github.com/Azure/azure-policy?tab=readme-ov-file#known-issues)

When a policy targets one of the resource types listed below, Copilot **must flag it with a warning comment** explaining the specific limitation. The policy may still be technically valid JSON, but its runtime behaviour will be unreliable or incorrect.

### 13.1 Resource Types with Incomplete/Non-Standard Query Results

These types return incomplete, missing, or non-standard data to the policy engine. Compliance audits will be inaccurate; `deny` may work but is unreliable.

| Resource type | Limitation |
|---|---|
| `Microsoft.Web/sites/config/*` (except `.../config/web`) | Query results incomplete — compliance results unreliable |
| `Microsoft.Web/sites/slots/config/*` (except `.../config/web`) | Query results incomplete — compliance results unreliable |
| `Microsoft.HDInsights/clusters/computeProfile.roles[*].scriptActions` | Query results incomplete |
| `Microsoft.Sql/servers/auditingSettings` | Use only in `auditIfNotExists`/`deployIfNotExists` with `"name": "default"` in `details` |
| `Microsoft.DataLakeStore/accounts` | Use only in `auditIfNotExists`/`deployIfNotExists` |
| `Microsoft.DataLakeStore/accounts/encryptionState` | Property populated differently on read vs write — deny works, compliance audits incorrect |
| `Microsoft.Sql` 'master' database | Use only in `auditIfNotExists`/`deployIfNotExists` |
| `Microsoft.Compute/virtualMachines/instanceView` | Collection query missing many properties — compliance may fail |
| `Microsoft.Network/virtualNetworks/subnets` | `routeTable` property differs on read vs write — deny works, compliance audits incorrect |
| `Microsoft.Insights/workbooks` | Collection GET does not return all workbooks — false non-compliance possible |
| `Microsoft.Maintenance/configurationAssignments` | No LIST API — compliance cannot be populated |
| `Microsoft.Maintenance/applyUpdates` | No LIST API — compliance cannot be populated |
| `Microsoft.Cdn/CdnWebApplicationFirewallPolicies` | No LIST or subscription-scope GET — compliance results may degrade over time |
| `Microsoft.EventGrid/eventSubscriptions` | No LIST API — compliance cannot be populated |
| `Microsoft.AppConfiguration/configurationStores/*` | No LIST API — compliance cannot be populated |
| `Microsoft.OperationalInsights/workspaces/tables` | Case-sensitive type — use lower-case resource names to avoid evaluation/remediation failures |
| `Microsoft.Advisor/Configurations` | No GET API — aliases cannot be generated |

**Flag guidance**: For `auditIfNotExists`/`deployIfNotExists` policies targeting `Microsoft.Sql/servers/auditingSettings`, `Microsoft.DataLakeStore/accounts`, or the SQL master database, verify that `details.name` is specified:
```json
"details": {
  "type": "Microsoft.Sql/servers/auditingSettings",
  "name": "default"
}
```

### 13.2 Resource Types Not Correctly Published by Resource Provider

These types are implemented by a RP but not correctly published to ARM. Deny policies may work; compliance results will usually be incorrect.

- `Microsoft.DBforPostgreSQL/serverGroupsv2`
- `Microsoft.AppConfiguration/ConfigurationStores`

**Flag guidance**: Warn that compliance results for this type will be incorrect. Recommend against audit/compliance-oriented policies unless the type is the `details.type` in an `auditIfNotExists`/`deployIfNotExists` block.

### 13.3 Resource Management that Bypasses Azure Resource Manager

Operations on these types can occur outside ARM (dataplane operations), making them invisible to Azure Policy. Policy enforcement is **incomplete** — resources can be created/modified without triggering policy.

| Resource type | Bypass mechanism |
|---|---|
| `Microsoft.Storage/storageAccounts/blobServices/containers` | Direct blob API calls bypass ARM. Use `Microsoft.Storage/storageAccounts/allowBlobPublicAccess` instead for public access control. |
| `Microsoft.Sql/servers/firewallRules` | T-SQL commands bypass ARM — no plan to fix |
| `Microsoft.ServiceFabric/clusters/applications` | Created via Service Fabric cluster API (e.g. `New-ServiceFabricApplication`) — not visible to ARM |

**Flag guidance**: Policy targeting these types will not block or audit resources created via dataplane APIs. Recommend an alternative approach or add a comment noting the enforcement gap.

### 13.4 Nonstandard Creation Pattern

For these types, a resource provider may accept a PUT with only a subset of properties, filling in the rest itself. A non-compliant value may be set by the RP **after** the deny check passes.

- `Microsoft.Automation/certificates`
- `Microsoft.Security/securityContacts`

**Flag guidance**: Warn that deny policies on these types may not prevent all non-compliant resources because the RP can set property values after the ARM PUT is evaluated.

### 13.5 Nonstandard Update Pattern via Azure Portal

The portal issues a partial PUT (instead of PATCH) for this type, causing the policy engine to evaluate as if some properties have no value:

- `Microsoft.Web/sites`

**Flag guidance**: Policies auditing or denying specific properties of `Microsoft.Web/sites` may produce incorrect results when resources are updated through the Azure portal.

### 13.6 Resource Types Exempt from Policy Evaluation

The following resource types are **never evaluated** by Azure Policy regardless of assignment scope:

- `Microsoft.Resources/*` — except resource groups and subscriptions (e.g. `Microsoft.Resources/deployments` and `Microsoft.Resources/templateSpecs` are exempt)
- `Microsoft.Billing/*`
- `Microsoft.Capacity/reservationOrders/*`
- `Microsoft.Help/*`
- `Microsoft.Diagnostics/*`

**Flag guidance**: A policy targeting any of these types will never match any resource and should be rejected as ineffective. Note that `Microsoft.Resources/deployments` is explicitly excluded — this is intentional (DINE policies themselves use deployments).

### 13.7 Optional or Auto-Generated Properties that Bypass Policy Evaluation

When these properties are absent from the PUT request payload (e.g. portal-created resources), the policy engine cannot evaluate them. **Audit/deny/append** effects will not fire at create time for resources created via the portal or SDKs that omit these fields. `auditIfNotExists`/`deployIfNotExists` **works correctly** because it uses the full GET response.

Known affected aliases:
- `Microsoft.Storage/storageAccounts/networkAcls.defaultAction`
- `Microsoft.Authorization/roleAssignments/principalType`
- `Microsoft.Compute/virtualMachines/storageProfile.osDisk.osType`
- `Microsoft.Compute/virtualMachines/storageProfile.osDisk.diskSizeGB`
- `Microsoft.Compute/virtualMachineScaleSets/virtualMachineProfile.storageProfile.osDisk.diskSizeGB`
- `Microsoft.Authorization/roleAssignmentScheduleInstances/*` (all aliases)
- `Microsoft.Cache/Redis/privateEndpointConnections[*]` and sub-aliases

**Flag guidance**: If a `deny`, `audit`, or `append` policy uses any of these aliases in its `if` condition, warn that the policy will not enforce at resource creation time when the property is omitted from the request. Recommend switching to `auditIfNotExists` or `deployIfNotExists` if enforcement is required.

### 13.8 Read-Only Aliases

These aliases refer to properties that cannot be modified. Using them with `modify` or `deployIfNotExists` effects will produce non-compliance results that cannot be remediated — the resource will show as non-compliant even after remediation is triggered.

Notable read-only aliases (flag if used with `modify` or DINE effects):
- `Microsoft.Authorization/roleAssignmentScheduleInstances/*`
- `Microsoft.Cache/Redis/privateEndpointConnections[*]` and sub-aliases
- `Microsoft.Compute/virtualMachines/provisioningState`
- `Microsoft.Storage/storageAccounts/primaryEndpoints` and sub-aliases (`.web`, `.blob`, `.queue`, `.table`, `.file`)
- `Microsoft.DocumentDB/databaseAccounts/networkSecurityPerimeterConfigurations/*`
- `Microsoft.EventHub/namespaces/networkSecurityPerimeterConfigurations/*`
- `Microsoft.KeyVault/vaults/networkSecurityPerimeterConfigurations/*`
- `Microsoft.Sql/servers/networkSecurityPerimeterConfigurations/*`
- `Microsoft.Storage/storageAccounts/networkSecurityPerimeterConfigurations/*`

**Flag guidance**: These aliases are valid only for `audit` effect policies. Flag any policy that uses a read-only alias with `modify`, `deployIfNotExists`, or `append` as incorrect — remediation will silently fail.

### 13.9 Legacy or Incorrect Aliases

Some aliases refer to wrong or outdated information. A corrected `.v2` alias exists for known bad aliases. Always use the `.v2` (or `.v3`) version where one exists.

Known bad alias → use instead:
- `Microsoft.Sql/servers/databases/requestedServiceObjectiveName` → use `.v2`
- For SQL transparent data encryption: use **both** `Microsoft.Sql/transparentDataEncryption.status` (API versions 2014-04-01 to 2022-05-01-preview) **and** `Microsoft.Sql/servers/databases/transparentDataEncryption/state` (post 2022-05-01-preview) to cover all API versions.

**Flag guidance**: Flag use of any known-bad alias. Flag any alias for a property whose name contains dashes (`-`) or slashes (`/`) — aliases are not generated for property names containing non-alphanumeric characters (e.g. `Microsoft.Cache/Redis/redisConfiguration.rdb-backup-enabled` has no alias and cannot be targeted).

### 13.10 Resource Types that Exceed Policy Scale

These types are generated at very high scale and are **not supported** by Azure Policy:

- `Microsoft.ServiceBus/namespaces/topics`
- `Microsoft.ServiceBus/namespaces/topics/authorizationRules`
- `Microsoft.ServiceBus/namespaces/topics/subscriptions`
- `Microsoft.ServiceBus/namespaces/topics/subscriptions/rules`

**Flag guidance**: Reject policies targeting these types — enforcement and compliance scans at this scale negatively impact API performance and are not supported.

### 13.11 Resource Types Where Policy Exemptions Are Not Supported

Exemptions cannot be created on these resource types due to deny assignments. Use assignment-level exclusions instead:

- `Microsoft.Databricks/*`

**Flag guidance**: If a policy targets `Microsoft.Databricks/*` resources and the author mentions exemptions, note that exemptions are not supported — use `excludedScopes` in the assignment instead.

