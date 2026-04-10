import { LightningElement, track } from 'lwc';
import executeQuery from '@salesforce/apex/QueryRunnerController.executeQuery';
import queryMore from '@salesforce/apex/QueryRunnerController.queryMore';


export default class QueryRunner extends LightningElement {

    @track currentMode = 'builder';

    /** Raw SOQL string shared across modes */
    @track queryString = '';

    /** Selected SObject API name */
    @track selectedObject = '';

    /** Selected field API names */
    @track selectedFields = [];

    /** Array of filter objects { field, operator, value } */
    @track filters = [];

    /** Query result rows */
    @track data = [];

    /** Dynamic datatable column definitions */
    @track columns = [];

    /** Total row count from last execution */
    @track totalRows = 0;

    /** Error message string */
    @track error = '';

    /** Loading spinner flag */
    @track isLoading = false;

    /** URL for next page of results (pagination) */
    @track nextRecordsUrl = null;

    /** Whether all records have been fetched */
    @track allRecordsFetched = true;

    /** Loading more records flag */
    @track isLoadingMore = false;


    get isBuilderMode() {
        return this.currentMode === 'builder';
    }

    get isQueryMode() {
        return this.currentMode === 'query';
    }

    get builderVariant() {
        return this.currentMode === 'builder' ? 'brand' : 'neutral';
    }

    get queryVariant() {
        return this.currentMode === 'query' ? 'brand' : 'neutral';
    }

    get isRunDisabled() {
        return !this.queryString || this.isLoading;
    }

    get hasMoreRecords() {
        return !this.allRecordsFetched && this.nextRecordsUrl;
    }

    get loadedRecordCount() {
        return this.data ? this.data.length : 0;
    }

    get paginationLabel() {
        return `Showing ${this.loadedRecordCount} of ${this.totalRows} records`;
    }

    handleBuilderMode() {
        this.currentMode = 'builder';
    }

    handleQueryMode() {
        this.currentMode = 'query';
    }

    handleObjectChange(event) {
        this.selectedObject = event.detail.value;
        this.selectedFields = [];
        this.filters = [];
        this.queryString = '';
        this.clearResults();
    }

    handleFieldsChange(event) {
        this.selectedFields = event.detail.value;
    }

    handleFiltersChange(event) {
        this.filters = event.detail.value;
    }

    handleGenerateQuery(event) {
        this.queryString = event.detail.value;
    }

    handleQueryChange(event) {
        this.queryString = event.detail.value;
    }


    handleRunQuery() {
        const soql = this.queryString ? this.queryString.trim() : '';
        if (!soql) {
            this.error = 'Please enter or generate a SOQL query first.';
            return;
        }

        const upper = soql.toUpperCase();
        if (!upper.startsWith('SELECT')) {
            this.error = 'Query must start with SELECT.';
            return;
        }
        if (!upper.includes('FROM')) {
            this.error = 'Query must contain a FROM clause.';
            return;
        }

        this.isLoading = true;
        this.error = '';
        this.data = [];
        this.columns = [];
        this.nextRecordsUrl = null;
        this.allRecordsFetched = true;

        executeQuery({ queryString: soql })
            .then((result) => {
                if (result.error) {
                    this.error = result.error;
                    this.data = [];
                    this.columns = [];
                    this.totalRows = 0;
                } else {
                    this.columns = result.columns || [];
                    this.data = result.records || [];
                    this.totalRows = result.totalRows || 0;
                    this.allRecordsFetched = result.done !== false;
                    this.nextRecordsUrl = result.nextRecordsUrl || null;
                    this.error = '';
                }
            })
            .catch((err) => {
                this.error = err.body ? err.body.message : err.message;
                this.data = [];
                this.columns = [];
                this.totalRows = 0;
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleLoadMore() {
        if (!this.nextRecordsUrl || this.isLoadingMore) {
            return;
        }

        this.isLoadingMore = true;

        queryMore({ nextRecordsUrl: this.nextRecordsUrl })
            .then((result) => {
                if (result.error) {
                    this.error = result.error;
                } else {
                    this.data = [...this.data, ...(result.records || [])];
                    this.allRecordsFetched = result.done !== false;
                    this.nextRecordsUrl = result.nextRecordsUrl || null;
                }
            })
            .catch((err) => {
                this.error = err.body ? err.body.message : err.message;
            })
            .finally(() => {
                this.isLoadingMore = false;
            });
    }


    clearResults() {
        this.data = [];
        this.columns = [];
        this.totalRows = 0;
        this.error = '';
        this.nextRecordsUrl = null;
        this.allRecordsFetched = true;
    }
}
