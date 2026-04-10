# Same-Org OAuth Setup For Query Runner

This document is written for open-source distribution.

All org domains, callback values, and contact details below should be treated as placeholders unless explicitly generated in your own Salesforce org.

This project already contains the source scaffold for these components:

- External Credential: `SalesforceQueryApi`
- Named Credential: `SalesforceQueryApi`
- Permission Set: `QueryRunnerApiAccess`

This guide turns that scaffold into a concrete same-org OAuth setup pattern using:

- A same-org Connected App
- A Salesforce Auth Provider
- A named principal on the external credential
- A named credential used by Apex as `callout:SalesforceQueryApi`

## Target Architecture

The runtime flow is:

1. Apex calls `callout:SalesforceQueryApi/...`
2. The named credential uses the external credential
3. The external credential uses OAuth against the same Salesforce org
4. Salesforce stores the token for the named principal
5. The REST API call runs with that OAuth access token

## Current Source Components

These files already exist in the repo:

- [force-app/main/default/externalCredentials/SalesforceQueryApi.externalCredential-meta.xml](force-app/main/default/externalCredentials/SalesforceQueryApi.externalCredential-meta.xml)
- [force-app/main/default/namedCredentials/SalesforceQueryApi.namedCredential-meta.xml](force-app/main/default/namedCredentials/SalesforceQueryApi.namedCredential-meta.xml)
- [force-app/main/default/permissionsets/QueryRunnerApiAccess.permissionset-meta.xml](force-app/main/default/permissionsets/QueryRunnerApiAccess.permissionset-meta.xml)
- [force-app/main/default/classes/QueryRunnerController.cls](force-app/main/default/classes/QueryRunnerController.cls)

You must still finish the auth configuration in Setup.

## Recommended Names

Use these names exactly to stay aligned with the source scaffold:

- Connected App label: `Salesforce Query API Connected App`
- Connected App API name: `Salesforce_Query_API_Connected_App`
- Auth Provider label: `Salesforce Query API Auth Provider`
- Auth Provider API name: `Salesforce_Query_API_AuthProvider`
- External Credential: `SalesforceQueryApi`
- Principal name: `SalesforceNamedPrincipal`
- Named Credential: `SalesforceQueryApi`
- Permission Set: `QueryRunnerApiAccess`

## Step 1: Deploy The Scaffold

Deploy these components first.

```powershell
sf project deploy start --source-dir force-app/main/default/classes/QueryRunnerController.cls --source-dir force-app/main/default/classes/QueryRunnerControllerTest.cls --source-dir force-app/main/default/classes/QueryRunnerControllerTest.cls-meta.xml --source-dir force-app/main/default/externalCredentials/SalesforceQueryApi.externalCredential-meta.xml --source-dir force-app/main/default/namedCredentials/SalesforceQueryApi.namedCredential-meta.xml --source-dir force-app/main/default/permissionsets/QueryRunnerApiAccess.permissionset-meta.xml
```

## Step 2: Create The Connected App

In Setup:

1. Go to `App Manager`
2. Click `New Connected App`
3. Enter:
   - Connected App Name: `Salesforce Query API Connected App`
   - API Name: `Salesforce_Query_API_Connected_App`
   - Contact Email: your admin email
4. Enable `OAuth Settings`
5. For callback URL, enter a temporary value for now:
   - `https://login.salesforce.com/services/oauth2/success`
6. Add OAuth scopes:
   - `Access and manage your data (api)`
   - `Perform requests at any time (refresh_token, offline_access)`
   - `Access your basic information (id, profile, email, address, phone)`
7. Save the connected app

After saving:

1. Open the connected app details
2. Copy the `Consumer Key`
3. Click `Manage Consumer Details` and reveal the `Consumer Secret`
4. Keep both values available for the Auth Provider step

## Step 2A: Configure Connected App OAuth Policies

This is the step most likely missing when you get `OAUTH_APPROVAL_ERROR_GENERIC`.

In Setup:

1. Go back to `App Manager`
2. Open `Salesforce Query API Connected App`
3. Click `Manage`
4. Click `Edit Policies`
5. Set `Permitted Users` to one of these:
   - `All users may self-authorize` for the fastest setup
   - `Admin approved users are pre-authorized` if you want tighter control
6. If you choose `Admin approved users are pre-authorized`:
   - add the user’s profile, permission set, or permission set group under connected app access
7. Choose the narrowest `IP Relaxation` setting that works in your environment
8. Save

Important:

- After changing connected app policies, wait 2 to 10 minutes before retrying the OAuth flow.
- If you retry immediately, Salesforce can still return `OAUTH_APPROVAL_ERROR_GENERIC` while policies are propagating.
- For public or shared documentation, prefer describing the policy tradeoff rather than prescribing the loosest setting as the default.

## Step 3: Create The Auth Provider

In Setup:

1. Go to `Auth. Providers`
2. Click `New`
3. Set `Provider Type` to `Salesforce`
4. Enter:
   - Name: `Salesforce Query API Auth Provider`
   - URL Suffix: `Salesforce_Query_API_AuthProvider`
   - Consumer Key: paste the connected app consumer key
   - Consumer Secret: paste the connected app consumer secret
5. Save

After saving:

1. Copy the generated `Callback URL` from the Auth Provider
2. Return to the connected app
3. Edit the connected app OAuth settings
4. Replace the temporary callback URL with the Auth Provider callback URL
5. Save the connected app again

This callback update matters. If you skip it, the OAuth handshake won’t complete.

Double-check these before moving on:

1. The connected app callback URL exactly matches the Auth Provider callback URL
2. The consumer key in the Auth Provider exactly matches the connected app consumer key
3. The consumer secret in the Auth Provider exactly matches the connected app consumer secret

## Step 4: Convert The External Credential To OAuth In Setup

The source scaffold gives you the component name, but the OAuth wiring should be finished in Setup.

In Setup:

1. Go to `External Credentials`
2. Open `SalesforceQueryApi`
3. Edit it
4. Set authentication protocol to `OAuth 2.0`
5. Set the authentication provider to `Salesforce Query API Auth Provider`
6. Keep identity type as `Named Principal`
7. Ensure the principal name is `SalesforceNamedPrincipal`
8. Set scopes to:
   - `api refresh_token offline_access`
9. Save

Notes:

- Use the same scopes here that your connected app expects.
- If Setup shows separate principal-level scope fields, put `api refresh_token offline_access` on the named principal.
- The scope string in the connected app and the external credential must be compatible.

## Step 5: Update The Named Credential Endpoint

In Setup:

1. Go to `Named Credentials`
2. Open `SalesforceQueryApi`
3. Edit it
4. Set URL to your My Domain root, for example:
   - `https://your-domain.my.salesforce.com`
5. Ensure it references the `SalesforceQueryApi` external credential
6. Save

The source file in [force-app/main/default/namedCredentials/SalesforceQueryApi.namedCredential-meta.xml](force-app/main/default/namedCredentials/SalesforceQueryApi.namedCredential-meta.xml) should remain a placeholder in source control. Set the real domain in the target org or deployment process.

## Step 6: Grant Principal Access

Users must be allowed to use the named principal.

In Setup:

1. Open the permission set `Query Runner API Access`
2. Confirm it grants access to the external credential principal for `SalesforceQueryApi`
3. Assign this permission set to each user who should run the query tool

If the principal is not granted to the running user, the named credential callout fails even if the OAuth configuration is otherwise correct.

## Step 7: Authenticate The Named Principal

In Setup:

1. Open `External Credentials`
2. Open `SalesforceQueryApi`
3. Find the named principal `SalesforceNamedPrincipal`
4. Start the authentication flow
5. Log in with the integration user or the org user you want this shared principal to represent
6. Approve the connected app scopes

Use a user that has all of the following:

- `API Enabled`
- access to the objects you want to query
- access to the connected app if the app is admin pre-authorized

After this step, Salesforce stores the token for the named principal.

## Step 8: Verify The Callout

Use Execute Anonymous or your LWC.

Anonymous Apex check:

```apex
QueryRunnerController.QueryResult result = QueryRunnerController.executeQuery(
    'SELECT Id, Name FROM Account LIMIT 5'
);
System.debug(result.error);
System.debug(result.totalRows);
System.debug(result.records);
```

Expected result:

- `result.error` is null
- `result.records` contains Account rows

## Common Failure Modes

### We couldn't access the credential(s)

Cause:

- External credential not authenticated
- User missing permission set assignment
- Principal access not granted

Fix:

1. Re-open the external credential principal
2. Complete authentication
3. Reassign `QueryRunnerApiAccess`

### invalid_client or invalid_grant

Cause:

- Connected app consumer key or secret mismatch
- Callback URL mismatch between connected app and auth provider

Fix:

1. Re-copy the consumer key and secret into the auth provider
2. Re-copy the auth provider callback URL into the connected app

### OAUTH_APPROVAL_ERROR_GENERIC

Cause:

- connected app `Permitted Users` policy blocks self-approval
- connected app access was not granted to the authenticating user
- connected app policy changes have not propagated yet
- integration user is missing `API Enabled`

Fix:

1. Open the connected app and set `Permitted Users` to `All users may self-authorize`
2. If you must use admin pre-authorization, explicitly grant connected app access to the authenticating user
3. Adjust `IP Relaxation` only as far as your environment requires
4. Wait at least 5 minutes after saving policy changes
5. Retry the principal authentication flow

### redirect_uri_mismatch

Cause:

- Connected app callback URL does not exactly match the Auth Provider callback URL

Fix:

1. Open the auth provider
2. Copy the generated callback URL exactly
3. Paste it into the connected app callback field

### insufficient access rights on cross-reference id

Cause:

- The authenticated principal user does not have API/object access needed for the query

Fix:

1. Log in as a user with the correct API and object permissions when authenticating the named principal

## What Stays In Source Control

Keep these in source control:

- Named Credential metadata
- External Credential metadata
- Permission Set metadata
- Apex using `callout:SalesforceQueryApi`

Do not expect these to be fully portable through source control alone:

- OAuth consumer secret
- token handshake state
- named principal token storage

## Recommended Next Cleanup

After you finish setup in the org, keep the source metadata generic and document any org-specific values in deployment notes or environment setup instructions rather than committing them to the repository.