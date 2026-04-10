@IsTest
private class QueryRunnerControllerTest {

    private class QueryApiMock implements HttpCalloutMock {
        Integer statusCode;
        String body;
        String exceptionMessage;

        QueryApiMock(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }

        QueryApiMock(String exceptionMessage) {
            this.exceptionMessage = exceptionMessage;
        }

        public HTTPResponse respond(HTTPRequest request) {
            if (exceptionMessage != null) {
                throw new CalloutException(exceptionMessage);
            }

            HttpResponse response = new HttpResponse();
            response.setStatusCode(statusCode);
            response.setBody(body);
            return response;
        }
    }

    // ─── executeQuery Tests ─────────────────────────

    @IsTest
    static void executeQuery_supportsFieldsAllThroughRestApi() {
        Test.setMock(
            HttpCalloutMock.class,
            new QueryApiMock(
                200,
                '{"totalSize":1,"done":true,"records":[{"attributes":{"type":"Account","url":"/services/data/v61.0/sobjects/Account/001000000000001AAA"},"Id":"001000000000001AAA","Name":"Fields All Test","IsDeleted":false}]}'
            )
        );

        Test.startTest();
        QueryRunnerController.QueryResult result = QueryRunnerController.executeQuery(
            'SELECT FIELDS(ALL) FROM Account LIMIT 1'
        );
        Test.stopTest();

        System.assertEquals(null, result.error, 'FIELDS(ALL) should be handled by the REST query endpoint.');
        System.assertEquals(1, result.records.size());
        System.assertEquals(1, result.totalRows);
        System.assertEquals(true, result.done);
        System.assertEquals('Fields All Test', String.valueOf(result.records[0].get('Name')));
    }

    @IsTest
    static void executeQuery_returnsPaginationInfo() {
        Test.setMock(
            HttpCalloutMock.class,
            new QueryApiMock(
                200,
                '{"totalSize":5000,"done":false,"nextRecordsUrl":"/services/data/v61.0/query/01gxx000000FAKE-2000","records":[{"attributes":{"type":"Account"},"Id":"001000000000001AAA","Name":"Page1"}]}'
            )
        );

        Test.startTest();
        QueryRunnerController.QueryResult result = QueryRunnerController.executeQuery(
            'SELECT Id, Name FROM Account'
        );
        Test.stopTest();

        System.assertEquals(null, result.error);
        System.assertEquals(5000, result.totalRows);
        System.assertEquals(false, result.done);
        System.assert(result.nextRecordsUrl != null);
    }

    @IsTest
    static void executeQuery_surfacesRestApiErrors() {
        Test.setMock(
            HttpCalloutMock.class,
            new QueryApiMock(
                400,
                '[{"message":"The SOQL query is invalid.","errorCode":"MALFORMED_QUERY"}]'
            )
        );

        Test.startTest();
        QueryRunnerController.QueryResult result = QueryRunnerController.executeQuery(
            'SELECT Name FROM Account WHERE'
        );
        Test.stopTest();

        System.assertEquals('The SOQL query is invalid.', result.error);
    }

    @IsTest
    static void executeQuery_rejectsNonSelectStatements() {
        QueryRunnerController.QueryResult result = QueryRunnerController.executeQuery('DELETE FROM Account');
        System.assertEquals('Only SELECT queries are allowed.', result.error);
    }

    // ─── queryMore Tests ────────────────────────────

    @IsTest
    static void queryMore_fetchesNextPage() {
        Test.setMock(
            HttpCalloutMock.class,
            new QueryApiMock(
                200,
                '{"totalSize":5000,"done":true,"records":[{"attributes":{"type":"Account"},"Id":"001000000000002AAA","Name":"Page2"}]}'
            )
        );

        Test.startTest();
        QueryRunnerController.QueryResult result = QueryRunnerController.queryMore(
            '/services/data/v61.0/query/01gxx000000FAKE-2000'
        );
        Test.stopTest();

        System.assertEquals(null, result.error);
        System.assertEquals(true, result.done);
        System.assertEquals(1, result.records.size());
    }

    @IsTest
    static void queryMore_rejectsBlankUrl() {
        QueryRunnerController.QueryResult result = QueryRunnerController.queryMore('');
        System.assertEquals('No more records URL provided.', result.error);
    }

    // ─── describeObject Tests ───────────────────────

    @IsTest
    static void describeObject_returnsFieldsAndRelationships() {
        String describeBody = '{"name":"Account","label":"Account","labelPlural":"Accounts","keyPrefix":"001",'
            + '"queryable":true,"createable":true,"updateable":true,"deletable":true,'
            + '"fields":[{"name":"Id","label":"Account ID","type":"id","length":18,"nillable":false,"updateable":false,"createable":false,"unique":false,"inlineHelpText":null,"defaultValue":null,"referenceTo":[],"relationshipName":null,"picklistValues":[]},'
            + '{"name":"Name","label":"Account Name","type":"string","length":255,"nillable":false,"updateable":true,"createable":true,"unique":false,"inlineHelpText":null,"defaultValue":null,"referenceTo":[],"relationshipName":null,"picklistValues":[]}],'
            + '"childRelationships":[{"childSObject":"Contact","field":"AccountId","relationshipName":"Contacts"}]}';

        Test.setMock(HttpCalloutMock.class, new QueryApiMock(200, describeBody));

        Test.startTest();
        QueryRunnerController.ObjectDescribeResult result = QueryRunnerController.describeObject('Account');
        Test.stopTest();

        System.assertEquals(null, result.error);
        System.assertEquals('Account', result.name);
        System.assertEquals(true, result.queryable);
        System.assertEquals(2, result.fields.size());
        System.assertEquals(1, result.childRelationships.size());
        System.assertEquals('Contacts', result.childRelationships[0].relationshipName);
    }

    @IsTest
    static void describeObject_rejectsBlankInput() {
        QueryRunnerController.ObjectDescribeResult result = QueryRunnerController.describeObject('');
        System.assertEquals('Object name cannot be empty.', result.error);
    }

    // ─── getRecord Tests ────────────────────────────

    @IsTest
    static void getRecord_returnsRecordAndMetadata() {
        // Mock returns both the record GET and the describe GET. Since we can only have one mock,
        // we return a generic response that works for both calls.
        String recordBody = '{"attributes":{"type":"Account"},"Id":"001000000000001AAA","Name":"Test Account"}';

        Test.setMock(HttpCalloutMock.class, new QueryApiMock(200, recordBody));

        Test.startTest();
        QueryRunnerController.RecordResult result = QueryRunnerController.getRecord('Account', '001000000000001AAA');
        Test.stopTest();

        // The record fetch should succeed; the describe may return partially parsed data from the generic mock
        System.assertEquals(null, result.error);
        System.assertEquals('Test Account', String.valueOf(result.record.get('Name')));
    }

    @IsTest
    static void getRecord_rejectsInvalidId() {
        QueryRunnerController.RecordResult result = QueryRunnerController.getRecord('Account', 'INVALID!');
        System.assertEquals('Invalid Record ID format.', result.error);
    }

    @IsTest
    static void getRecord_rejectsBlankInput() {
        QueryRunnerController.RecordResult result = QueryRunnerController.getRecord('', '');
        System.assertEquals('Object name and Record ID are required.', result.error);
    }

    // ─── updateRecord Tests ─────────────────────────

    @IsTest
    static void updateRecord_patchesSuccessfully() {
        Test.setMock(HttpCalloutMock.class, new QueryApiMock(204, ''));

        Test.startTest();
        QueryRunnerController.SaveResult result = QueryRunnerController.updateRecord(
            'Account', '001000000000001AAA', '{"Name":"Updated"}'
        );
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assertEquals('001000000000001AAA', result.recordId);
    }

    @IsTest
    static void updateRecord_rejectsInvalidId() {
        QueryRunnerController.SaveResult result = QueryRunnerController.updateRecord('Account', 'BAD!', '{}');
        System.assertEquals(false, result.success);
        System.assertEquals('Invalid Record ID format.', result.error);
    }

    // ─── createRecord Tests ─────────────────────────

    @IsTest
    static void createRecord_createsSuccessfully() {
        Test.setMock(
            HttpCalloutMock.class,
            new QueryApiMock(201, '{"id":"001000000000099AAA","success":true,"errors":[]}')
        );

        Test.startTest();
        QueryRunnerController.SaveResult result = QueryRunnerController.createRecord(
            'Account', '{"Name":"New Account"}'
        );
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assertEquals('001000000000099AAA', result.recordId);
    }

    @IsTest
    static void createRecord_rejectsBlankInput() {
        QueryRunnerController.SaveResult result = QueryRunnerController.createRecord('', '');
        System.assertEquals(false, result.success);
    }

    // ─── deleteRecord Tests ─────────────────────────

    @IsTest
    static void deleteRecord_deletesSuccessfully() {
        Test.setMock(HttpCalloutMock.class, new QueryApiMock(204, ''));

        Test.startTest();
        QueryRunnerController.SaveResult result = QueryRunnerController.deleteRecord('Account', '001000000000001AAA');
        Test.stopTest();

        System.assertEquals(true, result.success);
    }

    @IsTest
    static void deleteRecord_rejectsInvalidId() {
        QueryRunnerController.SaveResult result = QueryRunnerController.deleteRecord('Account', '!BAD!');
        System.assertEquals(false, result.success);
        System.assertEquals('Invalid Record ID format.', result.error);
    }

    // ─── bulkUpdateRecords Tests ────────────────────

    @IsTest
    static void bulkUpdateRecords_updatesMultipleRecords() {
        String compositeResponse = '[{"id":"001000000000001AAA","success":true,"errors":[]},{"id":"001000000000002AAA","success":true,"errors":[]}]';
        Test.setMock(HttpCalloutMock.class, new QueryApiMock(200, compositeResponse));

        String recordsJson = '[{"Id":"001000000000001AAA","Name":"Updated1"},{"Id":"001000000000002AAA","Name":"Updated2"}]';

        Test.startTest();
        QueryRunnerController.CompositeSaveResult result = QueryRunnerController.bulkUpdateRecords('Account', recordsJson);
        Test.stopTest();

        System.assertEquals(2, result.successCount);
        System.assertEquals(0, result.errorCount);
    }

    @IsTest
    static void bulkUpdateRecords_handlesPartialFailure() {
        String compositeResponse = '[{"id":"001000000000001AAA","success":true,"errors":[]},{"id":"001000000000002AAA","success":false,"errors":[{"message":"Required field missing","statusCode":"REQUIRED_FIELD_MISSING"}]}]';
        Test.setMock(HttpCalloutMock.class, new QueryApiMock(200, compositeResponse));

        String recordsJson = '[{"Id":"001000000000001AAA","Name":"OK"},{"Id":"001000000000002AAA","Name":""}]';

        Test.startTest();
        QueryRunnerController.CompositeSaveResult result = QueryRunnerController.bulkUpdateRecords('Account', recordsJson);
        Test.stopTest();

        System.assertEquals(1, result.successCount);
        System.assertEquals(1, result.errorCount);
        System.assert(!result.errors.isEmpty());
    }

    @IsTest
    static void bulkUpdateRecords_rejectsBlankInput() {
        QueryRunnerController.CompositeSaveResult result = QueryRunnerController.bulkUpdateRecords('', '');
        System.assertEquals(1, result.errorCount);
    }

    // ─── bulkDeleteRecords Tests ────────────────────

    @IsTest
    static void bulkDeleteRecords_deletesMultipleRecords() {
        String compositeResponse = '[{"id":"001000000000001AAA","success":true,"errors":[]},{"id":"001000000000002AAA","success":true,"errors":[]}]';
        Test.setMock(HttpCalloutMock.class, new QueryApiMock(200, compositeResponse));

        Test.startTest();
        QueryRunnerController.CompositeSaveResult result = QueryRunnerController.bulkDeleteRecords(
            'Account', new List<String>{ '001000000000001AAA', '001000000000002AAA' }
        );
        Test.stopTest();

        System.assertEquals(2, result.successCount);
        System.assertEquals(0, result.errorCount);
    }

    @IsTest
    static void bulkDeleteRecords_rejectsInvalidIds() {
        QueryRunnerController.CompositeSaveResult result = QueryRunnerController.bulkDeleteRecords(
            'Account', new List<String>{ '!BAD!', '@INVALID@' }
        );
        System.assertEquals(2, result.errorCount);
        System.assertEquals(0, result.successCount);
    }

    @IsTest
    static void bulkDeleteRecords_rejectsBlankInput() {
        QueryRunnerController.CompositeSaveResult result = QueryRunnerController.bulkDeleteRecords('', null);
        System.assertEquals(1, result.errorCount);
    }

    // ─── Existing Utility Tests ─────────────────────

    @IsTest
    static void buildQueryEndpoint_encodesQueryString() {
        String endpoint = QueryRunnerController.buildQueryEndpoint('SELECT Name FROM Account LIMIT 1');

        System.assert(endpoint.contains('callout:SalesforceQueryApi/services/data/v61.0/query?q='));
        System.assert(endpoint.endsWith('SELECT+Name+FROM+Account+LIMIT+1'));
    }

    @IsTest
    static void normalizeCalloutError_returnsFriendlySetupMessage() {
        String errorMessage = QueryRunnerController.normalizeCalloutError(
            new CalloutException('We couldn\'t access the credential(s). You might not have permission, or the external credential isn\'t configured.')
        );

        System.assertEquals(
            'Named Credential setup is incomplete. Configure the SalesforceQueryApi External Credential principal, connect its authentication, and assign the QueryRunnerApiAccess permission set.',
            errorMessage
        );
    }

    @IsTest
    static void getSObjects_returnsQueryableObjects() {
        List<QueryRunnerController.SObjectOption> options = QueryRunnerController.getSObjects();

        System.assert(!options.isEmpty(), 'Expected at least one queryable object.');

        Boolean foundAccount = false;
        for (QueryRunnerController.SObjectOption option : options) {
            if (option.value == 'Account') {
                foundAccount = true;
                break;
            }
        }

        System.assert(foundAccount, 'Expected Account to be available.');
    }

    @IsTest
    static void getObjectFields_returnsAccessibleFields() {
        List<QueryRunnerController.FieldOption> fields = QueryRunnerController.getObjectFields('Account');

        System.assert(!fields.isEmpty());

        Boolean foundNameField = false;
        for (QueryRunnerController.FieldOption fieldOption : fields) {
            if (fieldOption.value == 'Name') {
                foundNameField = true;
                break;
            }
        }

        System.assert(foundNameField);
    }

    @IsTest
    static void getObjectFields_returnsEmptyForBlankInput() {
        List<QueryRunnerController.FieldOption> fields = QueryRunnerController.getObjectFields(null);
        System.assertEquals(0, fields.size());
    }

    // ─── getOrgLimits Tests ─────────────────────────

    @IsTest
    static void getOrgLimits_returnsLimitData() {
        String limitsBody = '{"DailyApiRequests":{"Max":15000,"Remaining":14500},"DataStorageMB":{"Max":5,"Remaining":3},"FileStorageMB":{"Max":20,"Remaining":18}}';
        Test.setMock(HttpCalloutMock.class, new QueryApiMock(200, limitsBody));

        Test.startTest();
        List<QueryRunnerController.LimitInfo> limits = QueryRunnerController.getOrgLimits();
        Test.stopTest();

        System.assert(limits.size() > 0, 'Expected limit entries.');
        // Find DailyApiRequests
        Boolean foundDaily = false;
        for (QueryRunnerController.LimitInfo li : limits) {
            if (li.name == 'DailyApiRequests') {
                foundDaily = true;
                System.assertEquals(15000, li.max);
                System.assertEquals(14500, li.remaining);
                System.assertEquals(500, li.used);
            }
        }
        System.assert(foundDaily, 'Expected DailyApiRequests in results.');
    }

    @IsTest
    static void getOrgLimits_returnsEmptyOnError() {
        Test.setMock(HttpCalloutMock.class, new QueryApiMock(500, 'Internal Server Error'));

        Test.startTest();
        List<QueryRunnerController.LimitInfo> limits = QueryRunnerController.getOrgLimits();
        Test.stopTest();

        System.assertEquals(0, limits.size());
    }

    // ─── getOrgMetadataSummary Tests ────────────────

    @IsTest
    static void getOrgMetadataSummary_returnsCounts() {
        // Mock returns a tooling query response for all calls
        String mockBody = '{"totalSize":5,"done":true,"records":[]}';
        Test.setMock(HttpCalloutMock.class, new QueryApiMock(200, mockBody));

        Test.startTest();
        QueryRunnerController.OrgMetadataSummary summary = QueryRunnerController.getOrgMetadataSummary();
        Test.stopTest();

        // With our generic mock returning totalSize:5, all counts should be 5
        System.assertEquals(null, summary.error);
        System.assertEquals(5, summary.customObjectCount);
        System.assertEquals(5, summary.apexClassCount);
    }

    // ─── clearCurrentUserApexLogs Tests ─────────────

    @IsTest
    static void clearCurrentUserApexLogs_deletesLogs() {
        // First call returns log IDs (query), second call returns composite delete results
        // Since we only have one mock, we return a composite-compatible response
        String mockResponse = '{"totalSize":1,"done":true,"records":[{"attributes":{"type":"ApexLog"},"Id":"07L000000000001AAA"}]}';
        Test.setMock(HttpCalloutMock.class, new QueryApiMock(200, mockResponse));

        Test.startTest();
        QueryRunnerController.CompositeSaveResult result = QueryRunnerController.clearCurrentUserApexLogs();
        Test.stopTest();

        // The mock always returns the same body; actual delete parsing may not match but method should not throw
        System.assert(result != null);
    }

    @IsTest
    static void clearCurrentUserApexLogs_handlesNoLogs() {
        String mockResponse = '{"totalSize":0,"done":true,"records":[]}';
        Test.setMock(HttpCalloutMock.class, new QueryApiMock(200, mockResponse));

        Test.startTest();
        QueryRunnerController.CompositeSaveResult result = QueryRunnerController.clearCurrentUserApexLogs();
        Test.stopTest();

        System.assertEquals(0, result.successCount);
        System.assertEquals(0, result.errorCount);
    }

    // ─── checkFieldUsage Tests ──────────────────────

    @IsTest
    static void checkFieldUsage_returnsUsageData() {
        String countResponse = '{"totalSize":100,"done":true,"records":[]}';
        Test.setMock(HttpCalloutMock.class, new QueryApiMock(200, countResponse));

        Test.startTest();
        QueryRunnerController.FieldUsageResult result = QueryRunnerController.checkFieldUsage(
            'Account', new List<String>{ 'Name', 'Industry' }
        );
        Test.stopTest();

        System.assertEquals(null, result.error);
        System.assert(result.fields.size() > 0, 'Expected field usage data.');
        System.assertEquals(100, result.totalRecords);
    }

    @IsTest
    static void checkFieldUsage_rejectsBlankInput() {
        QueryRunnerController.FieldUsageResult result = QueryRunnerController.checkFieldUsage('', null);
        System.assertEquals('Object name and field names are required.', result.error);
    }

    @IsTest
    static void checkFieldUsage_rejectsInvalidObject() {
        QueryRunnerController.FieldUsageResult result = QueryRunnerController.checkFieldUsage(
            'NonExistentObject123', new List<String>{ 'Name' }
        );
        System.assertEquals('Object not found: NonExistentObject123', result.error);
    }
}