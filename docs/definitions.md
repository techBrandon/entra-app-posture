# Definitions

This file pins the term-of-art definitions used by `entra-app-posture`. Many checks share the same underlying concepts — defining them in one place keeps related checks consistent and makes the spirit of each `MSR-NN` control auditable.

Each entry below tracks:

- The term as it appears in check titles and `docs/controls.md`
- Its authoritative source (Microsoft Graph API, MS docs, or organizational policy)
- The definition itself
- Which checks rely on it

## Dedicated administrative account

**Status:** _TBD_

**Source:** _TBD — typically some combination of: cloud-only (no on-prem sync), no licensed mailbox, MFA-enforced via Conditional Access, dedicated admin UPN suffix or naming convention, restricted from interactive sign-in to non-admin apps._

**Definition:** _TBD_

**Used by:** EAPC-003, EAPC-004, EAPC-005, EAPC-006

## Inactive application

**Status:** _TBD_

**Source:** Microsoft's [`directoryRecommendation`](https://learn.microsoft.com/en-us/graph/api/resources/directoryrecommendation) API — specifically the inactive-application recommendation surface.

**Definition:** _TBD — adopt from the recommendation's criteria once confirmed._

**Used by:** EAPC-007, EAPC-009

## Disabled service principal

**Status:** Defined.

**Source:** `servicePrincipal.accountEnabled = false` ([Microsoft Graph](https://learn.microsoft.com/en-us/graph/api/resources/serviceprincipal)).

**Definition:** A service principal whose `accountEnabled` property is `false`. Distinct from "inactive" — a disabled service principal has been explicitly turned off, while an inactive one simply hasn't been used recently.

**Used by:** EAPC-008, EAPC-010

## Highly privileged Microsoft Graph permission

**Status:** _TBD_

**Source:** _TBD — candidates include Microsoft's high-privilege classification in the [permissions reference](https://learn.microsoft.com/en-us/graph/permissions-reference) and the [least-privileged permissions guidance](https://learn.microsoft.com/en-us/graph/permissions-overview). Common examples cited by Microsoft: `RoleManagement.ReadWrite.Directory`, `Application.ReadWrite.All`, `Directory.ReadWrite.All`._

**Definition:** _TBD — likely a curated list shipped with the module._

**Used by:** EAPC-007, EAPC-008

## Reclaimable shared hosting domain

**Status:** _TBD — starter list below is taken from prior work and needs review for accuracy and completeness._

**Source:** Common-knowledge list of platform-as-a-service / shared-hosting providers where subdomains are granted on a first-come basis and freed for re-registration when the original deployment is deleted or expires. This is the class of domain Microsoft singles out in [Zero Trust — Protect engineering systems](https://learn.microsoft.com/en-us/entra/fundamentals/zero-trust-protect-engineering-systems) (specifically `*.azurewebsites.net`) due to subdomain-takeover risk.

**Definition:** A domain on a multi-tenant cloud-hosting platform where (a) subdomain ownership is granted to whoever first claims it, and (b) deleting or abandoning the underlying deployment frees the subdomain for re-registration by an unrelated party.

**Starter list (subject to review):**

| Domain suffix | Platform | Notes |
|---|---|---|
| `azurewebsites.net` | Azure App Service | |
| `cloudapp.net` | Azure Cloud Services (classic) | |
| `azurefd.net` | Azure Front Door | |
| `azurestaticapps.net` | Azure Static Web Apps | |
| `appspot.com` | Google App Engine | |
| `cloudfront.net` | AWS CloudFront | |
| `elasticbeanstalk.com` | AWS Elastic Beanstalk | |
| `herokuapp.com` | Heroku | |
| `netlify.app` | Netlify | |
| `vercel.app` | Vercel | |
| `ngrok.io` | ngrok | _Verify: modern ngrok uses `ngrok.app` / `ngrok-free.app`. `ngrok.io` may be legacy-only — confirm whether it still issues new tunnels before treating as authoritative._ |

**Used by:** EAPC-012, EAPC-016

## Highly privileged built-in role

**Status:** _TBD_

**Source:** Likely Microsoft's privileged-role classification — the `isPrivileged` property on `unifiedRoleDefinition` in Graph, plus the curated list in the [privileged roles documentation](https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/privileged-roles-permissions).

**Definition:** _TBD — most likely "any directory role with `isPrivileged = true`"._

**Used by:** EAPC-009, EAPC-010
