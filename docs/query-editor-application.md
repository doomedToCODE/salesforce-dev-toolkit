# Query Editor Application Reference

## Overview

This project is a Salesforce developer toolkit centered on a query editor application built with Lightning Web Components and Apex.

The application provides:

- SOQL query building and direct query editing
- Query execution through the Salesforce REST API
- Query result pagination
- Object and field metadata exploration
- Single-record viewing and editing
- Bulk inline editing and bulk deletion
- Org utility actions such as API limit inspection, metadata summary, Apex log cleanup, and field usage analysis

The UI is exposed through the `Dev_Toolkit` Lightning tab and the backend is consolidated in `QueryRunnerController.cls`.

## Architecture

The runtime flow is:

1. A Lightning Web Component calls an `@AuraEnabled` Apex method in `QueryRunnerController`.
2. Apex performs a same-org callout through the `SalesforceQueryApi` named credential.
3. The callout targets Salesforce REST or Tooling API endpoints.
4. Apex normalizes the response and returns a UI-friendly payload.

Main layers:

- `devToolkit`: shell and navigation
- `queryRunner`, `queryBuilder`, `queryEditor`, `queryResults`: query workflow
- `objectExplorer`: object describe and field metadata exploration
- `recordViewer`: single-record inspection and editing
- `dataEditor`: bulk edit and bulk delete grid
- `orgUtilities`: org-level utilities
- `QueryRunnerController`: API facade for all features

## Functionalities

### 1. Dev Toolkit Shell

The shell provides a single-page application experience inside a custom Lightning tab.

Available views:

- Query Runner
- Object Explorer
- Record Viewer
- Data Editor
- Utilities

### 2. Query Runner

The query runner supports two modes:

- Builder mode for selecting an object, fields, and filters
- Query mode for writing raw SOQL directly

Core behaviors:

- Validates that the query starts with `SELECT`
- Validates that the query contains `FROM`
- Executes SOQL through the REST query endpoint
- Displays rows and inferred datatable columns
- Supports pagination through `nextRecordsUrl`

### 3. Query Builder

The query builder helps users assemble SOQL without hand-writing the query.

Supported actions:

- Load all queryable and accessible sObjects
- Load accessible fields for the selected object
- Select one or more fields
- Add or remove filters
- Generate a SOQL string with `WHERE` conditions

Supported filter operators:

- `=`
- `!=`
- `<`
- `>`
- `LIKE`
- `IN`

### 4. Query Editor

The query editor is a raw SOQL editor with field assistance.

Supported actions:

- Accept a query string from the parent component
- Detect the object name from the `FROM` clause
- Load fields for the detected object
- Search fields by label or API name
- Insert a single field into the `SELECT` clause
- Insert all visible fields into the `SELECT` clause
- Copy a field API name to the clipboard
- Emit `querychange` and `runquery` events to the parent

### 5. Query Results

The results component is a lightweight presentation component.

Supported actions:

- Render rows and columns in a `lightning-datatable`
- Show the row count
- Avoid flashing an empty state before the first completed run

### 6. Object Explorer

The object explorer allows metadata inspection for a selected object.

Supported actions:

- Load available objects
- Describe a selected object through the REST describe endpoint
- Display object capabilities such as queryable, createable, updateable, and deletable
- Search fields by label or API name
- View field metadata including type, length, required, editable, reference target, picklist values, help text, uniqueness, and default value
- View child relationship metadata

### 7. Record Viewer

The record viewer is a single-record inspection and editing tool.

Supported actions:

- Select an object
- Enter a record Id
- Fetch a record through the REST sObject row endpoint
- Render values with field metadata
- Toggle edit mode
- Edit text, boolean, and picklist fields
- Save changes through REST `PATCH`
- Delete a record through REST `DELETE`

### 8. Data Editor

The data editor is a bulk data maintenance tool.

Supported actions:

- Select an object and a set of fields
- Run a generated query that always includes `Id`
- Load additional result pages
- Edit cells inline in a datatable
- Track changed records only
- Bulk update edited rows through Composite SObject Collections API
- Bulk delete selected rows through Composite SObject Collections API
- Discard local edits and restore original values
- Export the current grid as CSV

### 9. Org Utilities

The utilities panel groups several admin-oriented helpers.

Supported actions:

- Load key org API and storage limits
- Load a metadata summary for custom objects, Apex classes, Apex triggers, LWC bundles, Aura bundles, flows, and installed packages
- Clear the current user's Apex debug logs
- Check field population percentages for selected fields on an object

## Component Methods

This section documents the meaningful client-side methods in each LWC.

### `devToolkit`

File: `force-app/main/default/lwc/devToolkit/devToolkit.js`

- `handleNavSelect(event)`: switches the active tool panel.
- `isQueryRunner`: true when the query runner is active.
- `isObjectExplorer`: true when the object explorer is active.
- `isRecordViewer`: true when the record viewer is active.
- `isDataEditor`: true when the data editor is active.
- `isUtilities`: true when the utilities panel is active.

### `queryRunner`

File: `force-app/main/default/lwc/queryRunner/queryRunner.js`

- `handleBuilderMode()`: switches to builder mode.
- `handleQueryMode()`: switches to raw query mode.
- `handleObjectChange(event)`: updates the selected object and resets builder state.
- `handleFieldsChange(event)`: updates the selected fields from the builder.
- `handleFiltersChange(event)`: updates filters from the builder.
- `handleGenerateQuery(event)`: accepts a generated SOQL string.
- `handleQueryChange(event)`: accepts edited SOQL text.
- `handleRunQuery()`: validates and executes the current SOQL string.
- `handleLoadMore()`: fetches the next result page.
- `clearResults()`: clears rows, columns, pagination state, and errors.

Computed getters:

- `isBuilderMode`
- `isQueryMode`
- `builderVariant`
- `queryVariant`
- `isRunDisabled`
- `hasMoreRecords`
- `loadedRecordCount`
- `paginationLabel`

### `queryBuilder`

File: `force-app/main/default/lwc/queryBuilder/queryBuilder.js`

- `wiredObjects({ data, error })`: loads available objects.
- `wiredFields({ data, error })`: loads fields for the selected object.
- `handleObjectSelect(event)`: resets builder state and emits `objectchange`.
- `handleFieldSelect(event)`: updates field selection and emits `fieldschange`.
- `handleAddFilter()`: appends a new filter row.
- `handleRemoveFilter(event)`: removes a filter row.
- `handleFilterChange(event)`: updates a filter row field, operator, or value.
- `_emitFilters()`: emits the normalized filter payload.
- `handleGenerate()`: builds the SOQL string and emits `generatequery`.
- `operatorOptions`: returns the supported filter operators.
- `hasObject`: true when an object has been selected.

### `queryEditor`

File: `force-app/main/default/lwc/queryEditor/queryEditor.js`

- `wiredFields({ data, error })`: loads field suggestions for the detected object.
- `renderedCallback()`: keeps the textarea in sync with internal state.
- `_syncTextarea()`: writes the internal query string to the DOM textarea when appropriate.
- `handleInput(event)`: updates internal state, parses the query, and emits `querychange`.
- `handleRun()`: emits `runquery`.
- `handleFieldSearch(event)`: updates the field search term.
- `handleFieldClick(event)`: inserts the clicked field into the query.
- `handleCopyField(event)`: copies a field API name to the clipboard.
- `handleInsertAllFields()`: inserts all currently visible, unselected fields.
- `_parseObjectFromQuery(query)`: extracts the object from the `FROM` clause.
- `_parseSelectedFields(query)`: detects selected fields between `SELECT` and `FROM`.
- `_insertFieldIntoQuery(fieldName)`: inserts a field into the current `SELECT` clause.
- `_clearSuggestions()`: resets the detected object and suggestion state.
- `filteredFields`: returns the filtered and selection-aware field list.
- `fieldCountLabel`: returns the field summary label.
- `hasSuggestions`: true when the suggestion panel should be shown.

### `queryResults`

File: `force-app/main/default/lwc/queryResults/queryResults.js`

- `hasData`: true when non-empty results are available.
- `showEmpty`: true when an empty-state message should be shown.
- `rowCountLabel`: returns the result count label.
- `renderedCallback()`: tracks whether the component has completed at least one run.

### `querySuggestions`

File: `force-app/main/default/lwc/querySuggestions/querySuggestions.js`

- `hasSuggestions`: true when suggestions are present.
- `handleSelect(event)`: emits the selected suggestion value.

Note: this component is a scaffold and is not the primary query-assist UI used by `queryEditor`.

### `objectExplorer`

File: `force-app/main/default/lwc/objectExplorer/objectExplorer.js`

- `wiredObjects({ data, error })`: loads available objects.
- `handleObjectSelect(event)`: selects an object and starts describe loading.
- `handleFieldSearch(event)`: updates the field search term.
- `handleFieldsTab()`: activates the field tab.
- `handleRelationshipsTab()`: activates the child relationship tab.
- `loadDescribe()`: calls the Apex describe method and stores the result.
- `_formatFieldType(field)`: formats the field type label, including references.

Computed getters:

- `hasObject`
- `objectSummary`
- `fieldCount`
- `relationshipCount`
- `filteredFields`
- `childRelationships`
- `isFieldsTab`
- `isRelationshipsTab`
- `fieldsTabVariant`
- `relationshipsTabVariant`
- `fieldColumns`
- `relationshipColumns`

### `recordViewer`

File: `force-app/main/default/lwc/recordViewer/recordViewer.js`

- `wiredObjects({ data, error })`: loads available objects.
- `handleObjectSelect(event)`: selects an object and clears the current record state.
- `handleRecordIdChange(event)`: updates the entered record Id.
- `handleFetchRecord()`: loads the record and field metadata.
- `handleToggleEdit()`: toggles edit mode and clears pending edits when canceling.
- `handleFieldChange(event)`: updates a pending edited value.
- `handleBooleanChange(event)`: updates a pending boolean value.
- `handleSave()`: saves edited fields through Apex and refreshes the record.
- `handleDelete()`: deletes the selected record.
- `clearState()`: clears record data, edit state, errors, and success messages.

Computed getters:

- `hasRecord`
- `isFetchDisabled`
- `displayFields`
- `editButtonLabel`
- `editButtonVariant`
- `editButtonIcon`
- `hasEdits`
- `recordTitle`

### `dataEditor`

File: `force-app/main/default/lwc/dataEditor/dataEditor.js`

- `wiredObjects({ data, error })`: loads available objects.
- `wiredFields({ data, error })`: loads fields for the selected object.
- `handleObjectSelect(event)`: updates the selected object and clears result state.
- `handleFieldSelect(event)`: updates selected fields.
- `handleQuery()`: builds and executes a query for the selected object and fields.
- `handleLoadMore()`: fetches the next result page.
- `_processQueryResult(result, isFirstPage)`: stores records, pagination state, and editable column definitions.
- `handleCellChange(event)`: records inline draft edits.
- `handleRowSelection(event)`: tracks selected record Ids for deletion.
- `handleSaveClick()`: opens the save confirmation modal.
- `handleConfirmSave()`: confirms a bulk save.
- `handleCancelSave()`: closes the save confirmation modal.
- `_executeSave()`: sends edited rows to the bulk update Apex method.
- `_applyEditsToData()`: merges confirmed edits into the local grid state.
- `_clearDraftValues()`: clears datatable draft values.
- `handleDiscardEdits()`: discards pending edits and restores original values.
- `handleDeleteClick()`: opens the delete confirmation modal.
- `handleConfirmDelete()`: confirms a bulk delete.
- `handleCancelDelete()`: closes the delete confirmation modal.
- `_executeDelete()`: deletes selected rows and removes them from local state.
- `handleExportCsv()`: exports the current grid data as CSV.
- `clearState()`: clears query, edit, delete, and message state.

Computed getters:

- `hasObject`
- `hasData`
- `hasMoreRecords`
- `isQueryDisabled`
- `hasEdits`
- `hasSelectedRows`
- `editCountLabel`
- `deleteCountLabel`
- `deleteConfirmMessage`
- `saveConfirmMessage`
- `loadedRecordCount`
- `paginationLabel`
- `exportFileName`
- `isSaveDisabled`
- `showEmptyState`

### `orgUtilities`

File: `force-app/main/default/lwc/orgUtilities/orgUtilities.js`

- `wiredObjects({ data, error })`: loads available objects for field usage analysis.
- `wiredFields({ data, error })`: loads fields for the selected field-usage object.
- `handleLimitsTab()`: activates API limits view.
- `handleMetadataTab()`: activates metadata summary view.
- `handleClearLogsTab()`: activates log cleanup view.
- `handleFieldUsageTab()`: activates field usage view.
- `handleRefreshLimits()`: loads org limit data.
- `handleRefreshMetadata()`: loads metadata summary data.
- `handleClearLogsClick()`: opens the log cleanup confirmation modal.
- `handleConfirmClearLogs()`: confirms debug log deletion.
- `handleCancelClearLogs()`: closes the log cleanup modal.
- `_executeClearLogs()`: deletes Apex logs for the running user.
- `handleFieldUsageObjectSelect(event)`: selects the object used for field usage analysis.
- `handleFieldUsageFieldSelect(event)`: selects the fields used for field usage analysis.
- `handleCheckFieldUsage()`: loads field usage data.
- `_formatLimitName(name)`: converts compact API limit names to readable labels.

Computed getters:

- `isLimits`
- `isMetadata`
- `isClearLogs`
- `isFieldUsage`
- `limitsVariant`
- `metadataVariant`
- `clearLogsVariant`
- `fieldUsageVariant`
- `hasLimits`
- `limitsColumns`
- `limitsData`
- `hasMetadata`
- `hasPackages`
- `packageColumns`
- `hasFieldUsageObject`
- `isFieldUsageCheckDisabled`
- `hasFieldUsageResult`
- `fieldUsageColumns`

## Apex Methods

File: `force-app/main/default/classes/QueryRunnerController.cls`

### Public `@AuraEnabled` methods

- `getSObjects()`: returns queryable, accessible objects from schema describe.
- `getObjectFields(String objectName)`: returns accessible fields for the provided object.
- `executeQuery(String queryString)`: validates and runs a SOQL query through the REST query endpoint.
- `queryMore(String nextRecordsUrl)`: fetches additional query results using the REST pagination URL.
- `describeObject(String objectName)`: returns object describe metadata through the REST describe endpoint.
- `getRecord(String objectName, String recordId)`: fetches a record and its field metadata.
- `updateRecord(String objectName, String recordId, String fieldsJson)`: updates a single record through REST `PATCH`.
- `createRecord(String objectName, String fieldsJson)`: creates a record through REST `POST`.
- `deleteRecord(String objectName, String recordId)`: deletes a record through REST `DELETE`.
- `bulkUpdateRecords(String objectName, String recordsJson)`: bulk-updates records through Composite SObject Collections API.
- `bulkDeleteRecords(String objectName, List<String> recordIds)`: bulk-deletes records through Composite SObject Collections API.
- `getOrgLimits()`: returns selected org limit metrics from the REST `/limits` endpoint.
- `getOrgMetadataSummary()`: returns counts and installed package metadata through Tooling API queries.
- `clearCurrentUserApexLogs()`: deletes Apex logs for the current user through Tooling API and composite deletion.
- `checkFieldUsage(String objectName, List<String> fieldNames)`: returns population counts and percentages for selected fields.

### Internal helper methods

- `parseCompositeResponse(String responseBody, CompositeSaveResult result)`: accumulates composite success and error counts.
- `countToolingRecords(String objectType, String whereClause)`: returns Tooling API record counts for metadata summary cards.
- `runQueryRestCall(String queryString)`: sends REST query requests.
- `runGenericRestCall(String method, String relativeUrl, String body)`: sends generic callouts through the named credential.
- `buildQueryEndpoint(String queryString)`: builds the encoded REST query endpoint.
- `parseQueryResponse(String responseBody, QueryResult result)`: normalizes REST query responses into rows and columns.
- `normalizeCalloutError(Exception e)`: converts low-level callout failures into user-facing messages.
- `flattenRecord(Map<String, Object> rawRecord)`: flattens REST record payloads for UI consumption.
- `inferColumnType(Object value)`: infers datatable column types.
- `extractErrorMessage(String responseBody)`: extracts API error messages from JSON response bodies.

## Data Contracts

Key Apex return types used by the UI:

- `SObjectOption`: object picklist entries
- `FieldOption`: field picklist entries with type
- `QueryResult`: query rows, columns, total size, pagination state, and error
- `ObjectDescribeResult`: object metadata, field metadata, child relationships, and error
- `RecordResult`: single record payload, field metadata, and error
- `SaveResult`: single-record operation success, record Id, and error
- `CompositeSaveResult`: bulk operation success count, error count, and error list
- `LimitInfo`: org limit values and percent used
- `OrgMetadataSummary`: metadata totals and installed packages
- `FieldUsageInfo` and `FieldUsageResult`: field population analysis

## Dos And Don'ts

### For Users

Do:

- Use `SELECT` queries only.
- Use Object Explorer before writing queries against unfamiliar objects.
- Include only fields you actually need when working with large objects.
- Use Data Editor for controlled bulk maintenance, not for mass migration jobs.
- Review pagination state before assuming you are looking at the full dataset.
- Assign the `QueryRunnerApiAccess` permission set to users who will run the app.

Do not:

- Expect non-`SELECT` SOQL to run in the query runner.
- Paste invalid record Ids into Record Viewer.
- Assume all query results are loaded after the first execution response.
- Expect bulk updates and deletes to behave as a single transaction; partial success is possible.
- Use this UI as a replacement for dedicated ETL tooling when handling very large data volumes.

### For Maintainers

Do:

- Keep the named credential and external credential setup documented and current.
- Treat the current org-specific metadata values as placeholders before publishing.
- Validate changes against `QueryRunnerControllerTest.cls` and manual UI smoke checks.
- Update this document when adding a new LWC view, Apex method, or API dependency.
- Keep error handling user-facing and actionable.

Do not:

- Commit production-specific domains, org identifiers, personal email addresses, or OAuth secrets into the open-source repository.
- Hard-code assumptions about one specific org shape unless they are documented as examples.
- Expand permissions casually; this app can read and mutate real org data.
- Ignore API limit impact when adding more polling, batching, or metadata scans.

### For Contributors

Do:

- Reuse `QueryRunnerController` instead of creating parallel callout controllers without a strong reason.
- Keep UI event contracts explicit and minimal.
- Preserve the current pattern of returning structured result objects with `error` fields for the UI.
- Prefer accessible, queryable schema metadata checks before exposing new objects or fields.

Do not:

- Bypass field or object accessibility checks.
- Assume nested REST objects can be rendered directly without normalization.
- Return raw exception stacks to the UI.
- Add client-only validation while skipping server-side validation for record Ids or payloads.

## Known Constraints

- REST API version is currently hard-coded to `v61.0`.
- Query pagination depends on the opaque `nextRecordsUrl` returned by Salesforce.
- `executeQuery()` currently does not inject a default `LIMIT`.
- Bulk operations are batched in chunks of 200 records.
- Composite bulk operations use `allOrNone=false`, so partial success is expected behavior.
- Record Ids must be 15 or 18 character alphanumeric Salesforce Ids.
- Relationship values are flattened to the nested record Id when available; more complex nested objects are serialized as JSON strings.
- `querySuggestions` exists as a scaffold and is not the primary suggestion implementation.

## Open-Source Publishing Checklist

Before publishing this project publicly:

1. Replace org-specific URLs in named credential and external credential metadata with clear placeholders or environment-specific setup instructions.
2. Remove or replace any personal contact email addresses in source metadata that should not be public.
3. Verify that no consumer keys, consumer secrets, session details, or authenticated principal data are present in the repo.
4. Add a `LICENSE` file if the repository will be published as open source.
5. Review setup docs so they describe the pattern without depending on one personal org.
6. Smoke-test the app in a clean org using only documented setup steps.

## Recommended Companion Documents

- `README.md`: high-level project introduction and quick start
- `docs/same-org-oauth-setup.md`: credential setup instructions
- `force-app/main/default/classes/QueryRunnerControllerTest.cls`: backend behavior coverage

If you extend the application with create-record UI, saved queries, query history, or richer autocomplete, update this document at the same time.