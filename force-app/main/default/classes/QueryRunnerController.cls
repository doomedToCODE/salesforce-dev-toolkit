
public with sharing class QueryRunnerController {

    private static final String REST_API_VERSION = 'v61.0';
    private static final String QUERY_API_NAMED_CREDENTIAL = 'SalesforceQueryApi';
    private static final Pattern DATE_PATTERN = Pattern.compile('^\\d{4}-\\d{2}-\\d{2}$');
    private static final Pattern DATETIME_PATTERN = Pattern.compile('^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(?:\\.\\d{3})?(?:Z|[+-]\\d{2}:?\\d{2})$');

    // ─── Wrapper Classes ─────────────────────────────

    public class SObjectOption implements Comparable {
        @AuraEnabled public String label;
        @AuraEnabled public String value;

        public SObjectOption(String label, String value) {
            this.label = label;
            this.value = value;
        }

        public Integer compareTo(Object other) {
            SObjectOption that = (SObjectOption) other;
            if (this.label == that.label) return 0;
            return this.label > that.label ? 1 : -1;
        }
    }

    public class FieldOption implements Comparable {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public String type;

        public FieldOption(String label, String value, String type) {
            this.label = label;
            this.value = value;
            this.type = type;
        }

        public Integer compareTo(Object other) {
            FieldOption that = (FieldOption) other;
            if (this.label == that.label) return 0;
            return this.label > that.label ? 1 : -1;
        }
    }

    public class QueryResult {
        @AuraEnabled public List<Map<String, Object>> records;
        @AuraEnabled public List<ColumnDef> columns;
        @AuraEnabled public Integer totalRows;
        @AuraEnabled public String nextRecordsUrl;
        @AuraEnabled public Boolean done;
        @AuraEnabled public String error;

        public QueryResult() {
            this.records = new List<Map<String, Object>>();
            this.columns = new List<ColumnDef>();
            this.totalRows = 0;
            this.done = true;
        }
    }

    public class ColumnDef {
        @AuraEnabled public String label;
        @AuraEnabled public String fieldName;
        @AuraEnabled public String type;

        public ColumnDef(String label, String fieldName, String type) {
            this.label = label;
            this.fieldName = fieldName;
            this.type = type;
        }
    }

    public class FieldDetail {
        @AuraEnabled public String name;
        @AuraEnabled public String label;
        @AuraEnabled public String type;
        @AuraEnabled public Integer length;
        @AuraEnabled public Boolean nillable;
        @AuraEnabled public Boolean updateable;
        @AuraEnabled public Boolean createable;
        @AuraEnabled public String referenceTo;
        @AuraEnabled public String relationshipName;
        @AuraEnabled public List<PicklistEntry> picklistValues;
        @AuraEnabled public String inlineHelpText;
        @AuraEnabled public Boolean unique;
        @AuraEnabled public String defaultValue;
    }

    public class PicklistEntry {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public Boolean active;
        @AuraEnabled public Boolean defaultValue;
    }

    public class ObjectDescribeResult {
        @AuraEnabled public String name;
        @AuraEnabled public String label;
        @AuraEnabled public String labelPlural;
        @AuraEnabled public String keyPrefix;
        @AuraEnabled public Boolean queryable;
        @AuraEnabled public Boolean createable;
        @AuraEnabled public Boolean updateable;
        @AuraEnabled public Boolean deletable;
        @AuraEnabled public Integer recordCount;
        @AuraEnabled public List<FieldDetail> fields;
        @AuraEnabled public List<RelationshipInfo> childRelationships;
        @AuraEnabled public String error;
    }

    public class RelationshipInfo {
        @AuraEnabled public String childSObject;
        @AuraEnabled public String field;
        @AuraEnabled public String relationshipName;
    }

    public class RecordResult {
        @AuraEnabled public Map<String, Object> record;
        @AuraEnabled public List<FieldDetail> fieldMetadata;
        @AuraEnabled public String error;
    }

    public class SaveResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String recordId;
        @AuraEnabled public String error;
    }

    public class CompositeSaveResult {
        @AuraEnabled public Integer successCount;
        @AuraEnabled public Integer errorCount;
        @AuraEnabled public List<String> errors;

        public CompositeSaveResult() {
            this.successCount = 0;
            this.errorCount = 0;
            this.errors = new List<String>();
        }
    }

    public class LimitInfo {
        @AuraEnabled public String name;
        @AuraEnabled public Integer max;
        @AuraEnabled public Integer remaining;
        @AuraEnabled public Integer used;
        @AuraEnabled public String percentUsed;
    }

    public class OrgMetadataSummary {
        @AuraEnabled public Integer customObjectCount;
        @AuraEnabled public Integer apexClassCount;
        @AuraEnabled public Integer apexTriggerCount;
        @AuraEnabled public Integer lwcCount;
        @AuraEnabled public Integer auraCount;
        @AuraEnabled public Integer flowCount;
        @AuraEnabled public Integer installedPackageCount;
        @AuraEnabled public List<Map<String, String>> installedPackages;
        @AuraEnabled public String error;

        public OrgMetadataSummary() {
            this.installedPackages = new List<Map<String, String>>();
        }
    }

    public class FieldUsageInfo {
        @AuraEnabled public String fieldName;
        @AuraEnabled public String fieldLabel;
        @AuraEnabled public String fieldType;
        @AuraEnabled public Integer populatedCount;
        @AuraEnabled public Integer totalCount;
        @AuraEnabled public String percentPopulated;
    }

    public class FieldUsageResult {
        @AuraEnabled public List<FieldUsageInfo> fields;
        @AuraEnabled public Integer totalRecords;
        @AuraEnabled public String error;

        public FieldUsageResult() {
            this.fields = new List<FieldUsageInfo>();
            this.totalRecords = 0;
        }
    }

    // ─── SObject & Field Metadata (Schema-based) ─────

    @AuraEnabled(cacheable=true)
    public static List<SObjectOption> getSObjects() {
        List<SObjectOption> options = new List<SObjectOption>();
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();

        for (String key : globalDescribe.keySet()) {
            Schema.DescribeSObjectResult objDescribe = globalDescribe.get(key).getDescribe();
            if (objDescribe.isQueryable() && objDescribe.isAccessible()) {
                options.add(new SObjectOption(objDescribe.getLabel() + ' (' + objDescribe.getName() + ')', objDescribe.getName()));
            }
        }
        options.sort();
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<FieldOption> getObjectFields(String objectName) {
        List<FieldOption> fields = new List<FieldOption>();

        if (String.isBlank(objectName)) {
            return fields;
        }

        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);
        if (objType == null) {
            throw new AuraHandledException('Object not found: ' + objectName);
        }

        Map<String, Schema.SObjectField> fieldMap = objType.getDescribe().fields.getMap();
        for (String fieldKey : fieldMap.keySet()) {
            Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldKey).getDescribe();
            if (fieldDescribe.isAccessible()) {
                String fieldType = fieldDescribe.getType().name().toLowerCase();
                fields.add(new FieldOption(
                    fieldDescribe.getLabel() + ' (' + fieldDescribe.getName() + ')',
                    fieldDescribe.getName(),
                    fieldType
                ));
            }
        }
        fields.sort();
        return fields;
    }

    // ─── Query Execution (REST API) ──────────────────

    @AuraEnabled
    public static QueryResult executeQuery(String queryString) {
        QueryResult result = new QueryResult();

        if (String.isBlank(queryString)) {
            result.error = 'Query string cannot be empty.';
            return result;
        }

        String trimmed = queryString.trim();

        if (!trimmed.toUpperCase().startsWith('SELECT')) {
            result.error = 'Only SELECT queries are allowed.';
            return result;
        }

        if (!trimmed.toUpperCase().contains('FROM')) {
            result.error = 'Query must contain a FROM clause.';
            return result;
        }

        // Append default LIMIT of 2000 if not present (no more 200 cap)
     /*   if (!trimmed.toUpperCase().contains('LIMIT')) {
            trimmed += ' LIMIT 2000';
        } */

        try {
            HttpResponse response = runQueryRestCall(trimmed);
            if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
                result.error = extractErrorMessage(response.getBody());
                return result;
            }

            parseQueryResponse(response.getBody(), result);
        } catch (Exception e) {
            result.error = normalizeCalloutError(e);
        }

        return result;
    }

    @AuraEnabled
    public static QueryResult queryMore(String nextRecordsUrl) {
        QueryResult result = new QueryResult();

        if (String.isBlank(nextRecordsUrl)) {
            result.error = 'No more records URL provided.';
            return result;
        }

        try {
            HttpResponse response = runGenericRestCall('GET', nextRecordsUrl, null);
            if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
                result.error = extractErrorMessage(response.getBody());
                return result;
            }

            parseQueryResponse(response.getBody(), result);
        } catch (Exception e) {
            result.error = normalizeCalloutError(e);
        }

        return result;
    }

    // ─── Object Explorer (REST Describe) ─────────────

    @AuraEnabled(cacheable=true)
    public static ObjectDescribeResult describeObject(String objectName) {
        ObjectDescribeResult result = new ObjectDescribeResult();

        if (String.isBlank(objectName)) {
            result.error = 'Object name cannot be empty.';
            return result;
        }

        try {
            String endpoint = '/services/data/' + REST_API_VERSION + '/sobjects/' + EncodingUtil.urlEncode(objectName, 'UTF-8') + '/describe/';
            HttpResponse response = runGenericRestCall('GET', endpoint, null);

            if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
                result.error = extractErrorMessage(response.getBody());
                return result;
            }

            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());

            result.name = String.valueOf(payload.get('name'));
            result.label = String.valueOf(payload.get('label'));
            result.labelPlural = String.valueOf(payload.get('labelPlural'));
            result.keyPrefix = payload.get('keyPrefix') != null ? String.valueOf(payload.get('keyPrefix')) : '';
            result.queryable = (Boolean) payload.get('queryable');
            result.createable = (Boolean) payload.get('createable');
            result.updateable = (Boolean) payload.get('updateable');
            result.deletable = (Boolean) payload.get('deletable');

            // Parse fields
            result.fields = new List<FieldDetail>();
            List<Object> rawFields = (List<Object>) payload.get('fields');
            if (rawFields != null) {
                for (Object fieldObj : rawFields) {
                    Map<String, Object> fm = (Map<String, Object>) fieldObj;
                    FieldDetail fd = new FieldDetail();
                    fd.name = String.valueOf(fm.get('name'));
                    fd.label = String.valueOf(fm.get('label'));
                    fd.type = String.valueOf(fm.get('type'));
                    fd.length = fm.get('length') != null ? Integer.valueOf(String.valueOf(fm.get('length'))) : 0;
                    fd.nillable = (Boolean) fm.get('nillable');
                    fd.updateable = (Boolean) fm.get('updateable');
                    fd.createable = (Boolean) fm.get('createable');
                    fd.unique = fm.get('unique') != null ? (Boolean) fm.get('unique') : false;
                    fd.inlineHelpText = fm.get('inlineHelpText') != null ? String.valueOf(fm.get('inlineHelpText')) : '';
                    fd.defaultValue = fm.get('defaultValue') != null ? String.valueOf(fm.get('defaultValue')) : '';

                    // Reference fields
                    List<Object> refs = (List<Object>) fm.get('referenceTo');
                    if (refs != null && !refs.isEmpty()) {
                        fd.referenceTo = String.valueOf(refs[0]);
                    }
                    fd.relationshipName = fm.get('relationshipName') != null ? String.valueOf(fm.get('relationshipName')) : '';

                    // Picklist values
                    List<Object> rawPicklist = (List<Object>) fm.get('picklistValues');
                    if (rawPicklist != null && !rawPicklist.isEmpty()) {
                        fd.picklistValues = new List<PicklistEntry>();
                        for (Object plObj : rawPicklist) {
                            Map<String, Object> plMap = (Map<String, Object>) plObj;
                            PicklistEntry pe = new PicklistEntry();
                            pe.label = String.valueOf(plMap.get('label'));
                            pe.value = String.valueOf(plMap.get('value'));
                            pe.active = (Boolean) plMap.get('active');
                            pe.defaultValue = (Boolean) plMap.get('defaultValue');
                            fd.picklistValues.add(pe);
                        }
                    }

                    result.fields.add(fd);
                }
            }

            // Parse child relationships
            result.childRelationships = new List<RelationshipInfo>();
            List<Object> rawRels = (List<Object>) payload.get('childRelationships');
            if (rawRels != null) {
                for (Object relObj : rawRels) {
                    Map<String, Object> rm = (Map<String, Object>) relObj;
                    if (rm.get('relationshipName') != null) {
                        RelationshipInfo ri = new RelationshipInfo();
                        ri.childSObject = String.valueOf(rm.get('childSObject'));
                        ri.field = String.valueOf(rm.get('field'));
                        ri.relationshipName = String.valueOf(rm.get('relationshipName'));
                        result.childRelationships.add(ri);
                    }
                }
            }

        } catch (Exception e) {
            result.error = normalizeCalloutError(e);
        }

        return result;
    }

    // ─── Record Viewer (REST sObject Rows) ───────────

    @AuraEnabled
    public static RecordResult getRecord(String objectName, String recordId) {
        RecordResult result = new RecordResult();

        if (String.isBlank(objectName) || String.isBlank(recordId)) {
            result.error = 'Object name and Record ID are required.';
            return result;
        }

        // Validate recordId format (15 or 18 char alphanumeric Salesforce ID)
        if (!Pattern.matches('^[a-zA-Z0-9]{15,18}$', recordId)) {
            result.error = 'Invalid Record ID format.';
            return result;
        }

        try {
            // Fetch record via REST
            String endpoint = '/services/data/' + REST_API_VERSION + '/sobjects/'
                + EncodingUtil.urlEncode(objectName, 'UTF-8') + '/'
                + EncodingUtil.urlEncode(recordId, 'UTF-8');
            HttpResponse response = runGenericRestCall('GET', endpoint, null);

            if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
                result.error = extractErrorMessage(response.getBody());
                return result;
            }

            Map<String, Object> rawRecord = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            result.record = flattenRecord(rawRecord);

            // Fetch field metadata for the object
            ObjectDescribeResult descResult = describeObject(objectName);
            if (descResult.error != null) {
                result.fieldMetadata = new List<FieldDetail>();
            } else {
                result.fieldMetadata = descResult.fields;
            }

        } catch (Exception e) {
            result.error = normalizeCalloutError(e);
        }

        return result;
    }

    // ─── Record Editor (REST PATCH / Composite) ──────

    @AuraEnabled
    public static SaveResult updateRecord(String objectName, String recordId, String fieldsJson) {
        SaveResult result = new SaveResult();

        if (String.isBlank(objectName) || String.isBlank(recordId) || String.isBlank(fieldsJson)) {
            result.error = 'Object name, Record ID, and fields are required.';
            result.success = false;
            return result;
        }

        if (!Pattern.matches('^[a-zA-Z0-9]{15,18}$', recordId)) {
            result.error = 'Invalid Record ID format.';
            result.success = false;
            return result;
        }

        try {
            String endpoint = '/services/data/' + REST_API_VERSION + '/sobjects/'
                + EncodingUtil.urlEncode(objectName, 'UTF-8') + '/'
                + EncodingUtil.urlEncode(recordId, 'UTF-8');
            HttpResponse response = runGenericRestCall('PATCH', endpoint, fieldsJson);

            if (response.getStatusCode() == 204) {
                result.success = true;
                result.recordId = recordId;
            } else if (response.getStatusCode() >= 200 && response.getStatusCode() < 300) {
                result.success = true;
                result.recordId = recordId;
            } else {
                result.success = false;
                result.error = extractErrorMessage(response.getBody());
            }

        } catch (Exception e) {
            result.success = false;
            result.error = normalizeCalloutError(e);
        }

        return result;
    }

    @AuraEnabled
    public static SaveResult createRecord(String objectName, String fieldsJson) {
        SaveResult result = new SaveResult();

        if (String.isBlank(objectName) || String.isBlank(fieldsJson)) {
            result.error = 'Object name and fields are required.';
            result.success = false;
            return result;
        }

        try {
            String endpoint = '/services/data/' + REST_API_VERSION + '/sobjects/'
                + EncodingUtil.urlEncode(objectName, 'UTF-8') + '/';
            HttpResponse response = runGenericRestCall('POST', endpoint, fieldsJson);

            if (response.getStatusCode() == 201) {
                Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                result.success = (Boolean) body.get('success');
                result.recordId = String.valueOf(body.get('id'));
            } else {
                result.success = false;
                result.error = extractErrorMessage(response.getBody());
            }

        } catch (Exception e) {
            result.success = false;
            result.error = normalizeCalloutError(e);
        }

        return result;
    }

    @AuraEnabled
    public static SaveResult deleteRecord(String objectName, String recordId) {
        SaveResult result = new SaveResult();

        if (String.isBlank(objectName) || String.isBlank(recordId)) {
            result.error = 'Object name and Record ID are required.';
            result.success = false;
            return result;
        }

        if (!Pattern.matches('^[a-zA-Z0-9]{15,18}$', recordId)) {
            result.error = 'Invalid Record ID format.';
            result.success = false;
            return result;
        }

        try {
            String endpoint = '/services/data/' + REST_API_VERSION + '/sobjects/'
                + EncodingUtil.urlEncode(objectName, 'UTF-8') + '/'
                + EncodingUtil.urlEncode(recordId, 'UTF-8');
            HttpResponse response = runGenericRestCall('DELETE', endpoint, null);

            if (response.getStatusCode() == 204) {
                result.success = true;
                result.recordId = recordId;
            } else {
                result.success = false;
                result.error = extractErrorMessage(response.getBody());
            }

        } catch (Exception e) {
            result.success = false;
            result.error = normalizeCalloutError(e);
        }

        return result;
    }

    // ─── Bulk Operations (Composite SObject Collections) ─

    @AuraEnabled
    public static CompositeSaveResult bulkUpdateRecords(String objectName, String recordsJson) {
        CompositeSaveResult result = new CompositeSaveResult();

        if (String.isBlank(objectName) || String.isBlank(recordsJson)) {
            result.errors.add('Object name and records are required.');
            result.errorCount = 1;
            return result;
        }

        try {
            // recordsJson is an array of objects: [{ "Id": "001...", "Name": "Updated", ... }, ...]
            // We need to add "attributes" to each record for the Composite SObject Collections API
            List<Object> rawRecords = (List<Object>) JSON.deserializeUntyped(recordsJson);
            List<Map<String, Object>> enrichedRecords = new List<Map<String, Object>>();

            for (Object recObj : rawRecords) {
                Map<String, Object> rec = (Map<String, Object>) recObj;
                // Validate each record has an Id
                String recId = rec.containsKey('Id') ? String.valueOf(rec.get('Id')) : '';
                if (String.isBlank(recId) || !Pattern.matches('^[a-zA-Z0-9]{15,18}$', recId)) {
                    result.errors.add('Record missing valid Id field.');
                    result.errorCount++;
                    continue;
                }
                rec.put('attributes', new Map<String, Object>{ 'type' => objectName });
                enrichedRecords.add(rec);
            }

            if (enrichedRecords.isEmpty()) {
                return result;
            }

            // Composite SObject Collections: PATCH with allOrNone=false, max 200 per call
            Integer batchSize = 200;
            for (Integer i = 0; i < enrichedRecords.size(); i += batchSize) {
                Integer endIdx = Math.min(i + batchSize, enrichedRecords.size());
                List<Map<String, Object>> batch = new List<Map<String, Object>>();
                for (Integer j = i; j < endIdx; j++) {
                    batch.add(enrichedRecords[j]);
                }

                Map<String, Object> requestBody = new Map<String, Object>{
                    'allOrNone' => false,
                    'records' => batch
                };

                String endpoint = '/services/data/' + REST_API_VERSION + '/composite/sobjects';
                HttpResponse response = runGenericRestCall('PATCH', endpoint, JSON.serialize(requestBody));

                if (response.getStatusCode() >= 200 && response.getStatusCode() < 300) {
                    parseCompositeResponse(response.getBody(), result);
                } else {
                    result.errors.add(extractErrorMessage(response.getBody()));
                    result.errorCount += batch.size();
                }
            }

        } catch (Exception e) {
            result.errors.add(normalizeCalloutError(e));
            result.errorCount++;
        }

        return result;
    }

    @AuraEnabled
    public static CompositeSaveResult bulkDeleteRecords(String objectName, List<String> recordIds) {
        CompositeSaveResult result = new CompositeSaveResult();

        if (String.isBlank(objectName) || recordIds == null || recordIds.isEmpty()) {
            result.errors.add('Object name and record IDs are required.');
            result.errorCount = 1;
            return result;
        }

        // Validate all IDs
        List<String> validIds = new List<String>();
        for (String recId : recordIds) {
            if (Pattern.matches('^[a-zA-Z0-9]{15,18}$', recId)) {
                validIds.add(recId);
            } else {
                result.errors.add('Invalid Record ID: ' + recId);
                result.errorCount++;
            }
        }

        if (validIds.isEmpty()) {
            return result;
        }

        try {
            // Composite SObject Collections DELETE: pass IDs as query param, max 200 per call
            Integer batchSize = 200;
            for (Integer i = 0; i < validIds.size(); i += batchSize) {
                Integer endIdx = Math.min(i + batchSize, validIds.size());
                List<String> batch = new List<String>();
                for (Integer j = i; j < endIdx; j++) {
                    batch.add(validIds[j]);
                }

                String ids = String.join(batch, ',');
                String endpoint = '/services/data/' + REST_API_VERSION + '/composite/sobjects?ids=' + ids + '&allOrNone=false';
                HttpResponse response = runGenericRestCall('DELETE', endpoint, null);

                if (response.getStatusCode() >= 200 && response.getStatusCode() < 300) {
                    parseCompositeResponse(response.getBody(), result);
                } else {
                    result.errors.add(extractErrorMessage(response.getBody()));
                    result.errorCount += batch.size();
                }
            }

        } catch (Exception e) {
            result.errors.add(normalizeCalloutError(e));
            result.errorCount++;
        }

        return result;
    }

    private static void parseCompositeResponse(String responseBody, CompositeSaveResult result) {
        List<Object> results = (List<Object>) JSON.deserializeUntyped(responseBody);
        for (Object item : results) {
            Map<String, Object> itemMap = (Map<String, Object>) item;
            Boolean success = (Boolean) itemMap.get('success');
            if (success) {
                result.successCount++;
            } else {
                result.errorCount++;
                List<Object> errors = (List<Object>) itemMap.get('errors');
                if (errors != null) {
                    for (Object errObj : errors) {
                        Map<String, Object> errMap = (Map<String, Object>) errObj;
                        result.errors.add(String.valueOf(errMap.get('message')));
                    }
                }
            }
        }
    }

    // ─── Utilities ───────────────────────────────────

    @AuraEnabled
    public static List<LimitInfo> getOrgLimits() {
        List<LimitInfo> limits = new List<LimitInfo>();

        try {
            String endpoint = '/services/data/' + REST_API_VERSION + '/limits';
            HttpResponse response = runGenericRestCall('GET', endpoint, null);

            if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
                return limits;
            }

            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());

            // Key limits to surface
            List<String> importantKeys = new List<String>{
                'DailyApiRequests', 'DailyBulkApiRequests', 'DailyAsyncApexExecutions',
                'DailyWorkflowEmails', 'DailyStreamingApiEvents', 'DataStorageMB',
                'FileStorageMB', 'HourlyTimeBasedWorkflow', 'SingleEmail',
                'MassEmail', 'HourlyAsyncReportRuns', 'HourlySyncReportRuns',
                'HourlyDashboardResults', 'ConcurrentAsyncGetReportInstances',
                'ConcurrentSyncReportRuns', 'HourlyODataCallout', 'DailyGenericStreamingApiEvents',
                'PermissionSets', 'ActiveScratchOrgs', 'DailyScratchOrgs'
            };

            for (String key : importantKeys) {
                if (payload.containsKey(key)) {
                    Map<String, Object> limitData = (Map<String, Object>) payload.get(key);
                    LimitInfo li = new LimitInfo();
                    li.name = key;
                    li.max = Integer.valueOf(String.valueOf(limitData.get('Max')));
                    li.remaining = Integer.valueOf(String.valueOf(limitData.get('Remaining')));
                    li.used = li.max - li.remaining;
                    if (li.max > 0) {
                        Decimal pct = ((Decimal) li.used / li.max * 100).setScale(1);
                        li.percentUsed = String.valueOf(pct) + '%';
                    } else {
                        li.percentUsed = '0%';
                    }
                    limits.add(li);
                }
            }

        } catch (Exception e) {
            // Return empty list on failure — error shown in UI
        }

        return limits;
    }

    @AuraEnabled
    public static OrgMetadataSummary getOrgMetadataSummary() {
        OrgMetadataSummary summary = new OrgMetadataSummary();

        try {
            // Custom objects count
            summary.customObjectCount = countToolingRecords('CustomObject', 'DeveloperName != null');
            // Apex classes
            summary.apexClassCount = countToolingRecords('ApexClass', 'Status = \'Active\'');
            // Apex triggers
            summary.apexTriggerCount = countToolingRecords('ApexTrigger', 'Status = \'Active\'');
            // LWC bundles
            summary.lwcCount = countToolingRecords('LightningComponentBundle', 'DeveloperName != null');
            // Aura bundles
            summary.auraCount = countToolingRecords('AuraDefinitionBundle', 'DeveloperName != null');
            // Flows
            summary.flowCount = countToolingRecords('Flow', 'Status = \'Active\'');

            // Installed packages via REST
            String pkgEndpoint = '/services/data/' + REST_API_VERSION + '/tooling/query?q='
                + EncodingUtil.urlEncode(
                    'SELECT SubscriberPackage.Name, SubscriberPackage.NamespacePrefix, SubscriberPackageVersion.MajorVersion, SubscriberPackageVersion.MinorVersion, SubscriberPackageVersion.PatchVersion FROM InstalledSubscriberPackage',
                    'UTF-8'
                );
            HttpResponse pkgResponse = runGenericRestCall('GET', pkgEndpoint, null);

            if (pkgResponse.getStatusCode() >= 200 && pkgResponse.getStatusCode() < 300) {
                Map<String, Object> pkgPayload = (Map<String, Object>) JSON.deserializeUntyped(pkgResponse.getBody());
                List<Object> pkgRecords = (List<Object>) pkgPayload.get('records');
                summary.installedPackageCount = pkgRecords != null ? pkgRecords.size() : 0;

                if (pkgRecords != null) {
                    for (Object pkgObj : pkgRecords) {
                        Map<String, Object> pkg = (Map<String, Object>) pkgObj;
                        Map<String, Object> subPkg = (Map<String, Object>) pkg.get('SubscriberPackage');
                        Map<String, Object> subPkgVer = (Map<String, Object>) pkg.get('SubscriberPackageVersion');

                        Map<String, String> pkgInfo = new Map<String, String>();
                        pkgInfo.put('name', subPkg != null ? String.valueOf(subPkg.get('Name')) : 'Unknown');
                        pkgInfo.put('namespace', subPkg != null && subPkg.get('NamespacePrefix') != null
                            ? String.valueOf(subPkg.get('NamespacePrefix')) : '');
                        if (subPkgVer != null) {
                            pkgInfo.put('version',
                                String.valueOf(subPkgVer.get('MajorVersion')) + '.' +
                                String.valueOf(subPkgVer.get('MinorVersion')) + '.' +
                                String.valueOf(subPkgVer.get('PatchVersion'))
                            );
                        } else {
                            pkgInfo.put('version', '');
                        }
                        summary.installedPackages.add(pkgInfo);
                    }
                }
            } else {
                summary.installedPackageCount = 0;
            }

        } catch (Exception e) {
            summary.error = normalizeCalloutError(e);
        }

        return summary;
    }

    @AuraEnabled
    public static CompositeSaveResult clearCurrentUserApexLogs() {
        CompositeSaveResult result = new CompositeSaveResult();

        try {
            // Query ApexLog IDs for the current user via Tooling API
            String userId = UserInfo.getUserId();
            String logQuery = 'SELECT Id FROM ApexLog WHERE LogUserId = \'' + String.escapeSingleQuotes(userId) + '\' ORDER BY StartTime DESC';
            String endpoint = '/services/data/' + REST_API_VERSION + '/tooling/query?q='
                + EncodingUtil.urlEncode(logQuery, 'UTF-8');

            HttpResponse response = runGenericRestCall('GET', endpoint, null);

            if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
                result.errors.add(extractErrorMessage(response.getBody()));
                result.errorCount = 1;
                return result;
            }

            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            List<Object> logRecords = (List<Object>) payload.get('records');

            if (logRecords == null || logRecords.isEmpty()) {
                return result; // No logs to delete
            }

            // Delete logs in batches of 200 via Composite SObject Collections
            List<String> logIds = new List<String>();
            for (Object logObj : logRecords) {
                Map<String, Object> logMap = (Map<String, Object>) logObj;
                logIds.add(String.valueOf(logMap.get('Id')));
            }

            Integer batchSize = 200;
            for (Integer i = 0; i < logIds.size(); i += batchSize) {
                Integer endIdx = Math.min(i + batchSize, logIds.size());
                List<String> batch = new List<String>();
                for (Integer j = i; j < endIdx; j++) {
                    batch.add(logIds[j]);
                }

                String ids = String.join(batch, ',');
                String deleteEndpoint = '/services/data/' + REST_API_VERSION + '/composite/sobjects?ids=' + ids + '&allOrNone=false';
                HttpResponse delResponse = runGenericRestCall('DELETE', deleteEndpoint, null);

                if (delResponse.getStatusCode() >= 200 && delResponse.getStatusCode() < 300) {
                    parseCompositeResponse(delResponse.getBody(), result);
                } else {
                    result.errors.add(extractErrorMessage(delResponse.getBody()));
                    result.errorCount += batch.size();
                }
            }

        } catch (Exception e) {
            result.errors.add(normalizeCalloutError(e));
            result.errorCount++;
        }

        return result;
    }

    @AuraEnabled
    public static FieldUsageResult checkFieldUsage(String objectName, List<String> fieldNames) {
        FieldUsageResult result = new FieldUsageResult();

        if (String.isBlank(objectName) || fieldNames == null || fieldNames.isEmpty()) {
            result.error = 'Object name and field names are required.';
            return result;
        }

        // Get field metadata for labels/types
        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);
        if (objType == null) {
            result.error = 'Object not found: ' + objectName;
            return result;
        }

        Map<String, Schema.SObjectField> fieldMap = objType.getDescribe().fields.getMap();

        try {
            // First get total record count
            String countQuery = 'SELECT COUNT() FROM ' + objectName;
            HttpResponse countResponse = runQueryRestCall(countQuery);

            if (countResponse.getStatusCode() >= 200 && countResponse.getStatusCode() < 300) {
                Map<String, Object> countPayload = (Map<String, Object>) JSON.deserializeUntyped(countResponse.getBody());
                result.totalRecords = Integer.valueOf(String.valueOf(countPayload.get('totalSize')));
            } else {
                result.error = extractErrorMessage(countResponse.getBody());
                return result;
            }

            // For each field, count non-null records
            for (String fieldName : fieldNames) {
                // Validate the field exists and is accessible
                Schema.SObjectField fieldToken = fieldMap.get(fieldName.toLowerCase());
                if (fieldToken == null) {
                    continue;
                }

                Schema.DescribeFieldResult fieldDescribe = fieldToken.getDescribe();
                if (!fieldDescribe.isAccessible()) {
                    continue;
                }

                String fieldQuery = 'SELECT COUNT() FROM ' + objectName
                    + ' WHERE ' + fieldName + ' != null';

                HttpResponse fieldResponse = runQueryRestCall(fieldQuery);

                FieldUsageInfo fui = new FieldUsageInfo();
                fui.fieldName = fieldDescribe.getName();
                fui.fieldLabel = fieldDescribe.getLabel();
                fui.fieldType = fieldDescribe.getType().name().toLowerCase();

                if (fieldResponse.getStatusCode() >= 200 && fieldResponse.getStatusCode() < 300) {
                    Map<String, Object> fieldPayload = (Map<String, Object>) JSON.deserializeUntyped(fieldResponse.getBody());
                    fui.populatedCount = Integer.valueOf(String.valueOf(fieldPayload.get('totalSize')));
                } else {
                    fui.populatedCount = 0;
                }

                fui.totalCount = result.totalRecords;
                if (fui.totalCount > 0) {
                    Decimal pct = ((Decimal) fui.populatedCount / fui.totalCount * 100).setScale(1);
                    fui.percentPopulated = String.valueOf(pct) + '%';
                } else {
                    fui.percentPopulated = '0%';
                }

                result.fields.add(fui);
            }

        } catch (Exception e) {
            result.error = normalizeCalloutError(e);
        }

        return result;
    }

    @TestVisible
    private static Integer countToolingRecords(String objectType, String whereClause) {
        String soql = 'SELECT COUNT() FROM ' + objectType;
        if (String.isNotBlank(whereClause)) {
            soql += ' WHERE ' + whereClause;
        }

        String endpoint = '/services/data/' + REST_API_VERSION + '/tooling/query?q='
            + EncodingUtil.urlEncode(soql, 'UTF-8');

        HttpResponse response = runGenericRestCall('GET', endpoint, null);

        if (response.getStatusCode() >= 200 && response.getStatusCode() < 300) {
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            return payload.containsKey('totalSize')
                ? Integer.valueOf(String.valueOf(payload.get('totalSize')))
                : 0;
        }

        return 0;
    }

    // ─── HTTP Helpers ────────────────────────────────

    @TestVisible
    private static HttpResponse runQueryRestCall(String queryString) {
        HttpRequest request = new HttpRequest();
        request.setMethod('GET');
        request.setHeader('Accept', 'application/json');
        request.setTimeout(120000);
        request.setEndpoint(buildQueryEndpoint(queryString));

        Http http = new Http();
        return http.send(request);
    }

    @TestVisible
    private static HttpResponse runGenericRestCall(String method, String relativeUrl, String body) {
        HttpRequest request = new HttpRequest();
        request.setMethod(method);
        request.setHeader('Accept', 'application/json');
        request.setHeader('Content-Type', 'application/json');
        request.setTimeout(120000);
        request.setEndpoint('callout:' + QUERY_API_NAMED_CREDENTIAL + relativeUrl);

        if (body != null && (method == 'POST' || method == 'PATCH' || method == 'PUT')) {
            request.setBody(body);
        }

        Http http = new Http();
        return http.send(request);
    }

    @TestVisible
    private static String buildQueryEndpoint(String queryString) {
        return 'callout:'
            + QUERY_API_NAMED_CREDENTIAL
            + '/services/data/'
            + REST_API_VERSION
            + '/query?q='
            + EncodingUtil.urlEncode(queryString, 'UTF-8');
    }

    // ─── Response Parsing ────────────────────────────

    private static void parseQueryResponse(String responseBody, QueryResult result) {
        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        result.totalRows = payload.containsKey('totalSize')
            ? Integer.valueOf(String.valueOf(payload.get('totalSize')))
            : 0;

        result.done = payload.containsKey('done') ? (Boolean) payload.get('done') : true;

        if (!result.done && payload.containsKey('nextRecordsUrl')) {
            result.nextRecordsUrl = String.valueOf(payload.get('nextRecordsUrl'));
        }

        List<Object> rawRecords = (List<Object>) payload.get('records');
        if (rawRecords == null || rawRecords.isEmpty()) {
            return;
        }

        for (Object recordObj : rawRecords) {
            Map<String, Object> rawRecord = (Map<String, Object>) recordObj;
            result.records.add(flattenRecord(rawRecord));
        }

        Map<String, Object> firstRow = result.records[0];
        for (String fieldName : firstRow.keySet()) {
            result.columns.add(new ColumnDef(fieldName, fieldName, inferColumnType(firstRow.get(fieldName))));
        }
    }

    // ─── Error Handling ──────────────────────────────

    @TestVisible
    private static String normalizeCalloutError(Exception e) {
        String message = e.getMessage();

        if (String.isBlank(message)) {
            return 'Query request failed.';
        }

        if (
            message.contains('Couldn\'t access the credential') ||
            message.contains('couldn\'t access the credential') ||
            message.contains('We couldn\'t access the credential') ||
            message.contains('Unable to fetch the OAuth token')
        ) {
            return 'Named Credential setup is incomplete. Configure the SalesforceQueryApi External Credential principal, connect its authentication, and assign the QueryRunnerApiAccess permission set.';
        }

        return message;
    }

    private static Map<String, Object> flattenRecord(Map<String, Object> rawRecord) {
        Map<String, Object> flattened = new Map<String, Object>();
        for (String fieldName : rawRecord.keySet()) {
            if (fieldName == 'attributes') {
                continue;
            }

            Object value = rawRecord.get(fieldName);
            if (value instanceof Map<String, Object>) {
                Map<String, Object> nested = (Map<String, Object>) value;
                if (nested.containsKey('Id')) {
                    flattened.put(fieldName, nested.get('Id'));
                } else {
                    flattened.put(fieldName, JSON.serialize(nested));
                }
            } else {
                flattened.put(fieldName, value);
            }
        }

        return flattened;
    }

    private static String inferColumnType(Object value) {
        if (value instanceof Decimal || value instanceof Integer || value instanceof Long || value instanceof Double) {
            return 'number';
        }
        if (value instanceof Boolean) {
            return 'boolean';
        }
        if (value instanceof String) {
            String stringValue = (String) value;
            if (DATE_PATTERN.matcher(stringValue).matches() || DATETIME_PATTERN.matcher(stringValue).matches()) {
                return 'date';
            }
        }

        return 'text';
    }

    private static String extractErrorMessage(String responseBody) {
        if (String.isBlank(responseBody)) {
            return 'Query request failed.';
        }

        Object parsedBody = JSON.deserializeUntyped(responseBody);
        if (parsedBody instanceof List<Object>) {
            List<Object> errorList = (List<Object>) parsedBody;
            if (!errorList.isEmpty()) {
                Map<String, Object> firstError = (Map<String, Object>) errorList[0];
                if (firstError.containsKey('message')) {
                    return String.valueOf(firstError.get('message'));
                }
            }
        }

        if (parsedBody instanceof Map<String, Object>) {
            Map<String, Object> errorMap = (Map<String, Object>) parsedBody;
            if (errorMap.containsKey('message')) {
                return String.valueOf(errorMap.get('message'));
            }
        }

        return responseBody;
    }
}
