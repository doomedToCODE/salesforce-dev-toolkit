import { LightningElement, track, wire } from 'lwc';
import getOrgLimits from '@salesforce/apex/QueryRunnerController.getOrgLimits';
import getOrgMetadataSummary from '@salesforce/apex/QueryRunnerController.getOrgMetadataSummary';
import clearCurrentUserApexLogs from '@salesforce/apex/QueryRunnerController.clearCurrentUserApexLogs';
import checkFieldUsage from '@salesforce/apex/QueryRunnerController.checkFieldUsage';
import getSObjects from '@salesforce/apex/QueryRunnerController.getSObjects';
import getObjectFields from '@salesforce/apex/QueryRunnerController.getObjectFields';

export default class OrgUtilities extends LightningElement {

    // ─── Active Utility ─────────────────────────────

    @track activeUtility = 'limits';

    // ─── API Limits ─────────────────────────────────

    @track limits = [];
    @track limitsLoading = false;
    @track limitsError = '';

    // ─── Org Metadata ───────────────────────────────

    @track metadata = null;
    @track metadataLoading = false;
    @track metadataError = '';

    // ─── Clear Logs ─────────────────────────────────

    @track logsClearing = false;
    @track logsMessage = '';
    @track logsError = '';
    @track showLogConfirm = false;

    // ─── Field Usage ────────────────────────────────

    @track objectOptions = [];
    @track fieldUsageObject = '';
    @track fieldOptions = [];
    @track fieldUsageFields = [];
    @track fieldUsageResult = null;
    @track fieldUsageLoading = false;
    @track fieldUsageError = '';

    // ─── Wire: SObjects for field usage ─────────────

    @wire(getSObjects)
    wiredObjects({ data, error }) {
        if (data) {
            this.objectOptions = data.map((o) => ({ label: o.label, value: o.value }));
        } else if (error) {
            this.fieldUsageError = error.body ? error.body.message : 'Failed to load objects.';
        }
    }

    @wire(getObjectFields, { objectName: '$fieldUsageObject' })
    wiredFields({ data, error }) {
        if (data) {
            this.fieldOptions = data.map((f) => ({ label: f.label, value: f.value }));
        } else if (error) {
            this.fieldOptions = [];
        }
    }

    // ─── Computed: Navigation ───────────────────────

    get isLimits() { return this.activeUtility === 'limits'; }
    get isMetadata() { return this.activeUtility === 'metadata'; }
    get isClearLogs() { return this.activeUtility === 'clearLogs'; }
    get isFieldUsage() { return this.activeUtility === 'fieldUsage'; }

    get limitsVariant() { return this.isLimits ? 'brand' : 'neutral'; }
    get metadataVariant() { return this.isMetadata ? 'brand' : 'neutral'; }
    get clearLogsVariant() { return this.isClearLogs ? 'brand' : 'neutral'; }
    get fieldUsageVariant() { return this.isFieldUsage ? 'brand' : 'neutral'; }

    // ─── Computed: API Limits ───────────────────────

    get hasLimits() {
        return this.limits && this.limits.length > 0;
    }

    get limitsColumns() {
        return [
            { label: 'Limit Name', fieldName: 'displayName', type: 'text', sortable: true },
            { label: 'Used', fieldName: 'used', type: 'number' },
            { label: 'Remaining', fieldName: 'remaining', type: 'number' },
            { label: 'Max', fieldName: 'max', type: 'number' },
            { label: '% Used', fieldName: 'percentUsed', type: 'text', sortable: true }
        ];
    }

    get limitsData() {
        return this.limits.map(l => ({
            ...l,
            displayName: this._formatLimitName(l.name)
        }));
    }

    // ─── Computed: Org Metadata ─────────────────────

    get hasMetadata() {
        return !!this.metadata;
    }

    get hasPackages() {
        return this.metadata && this.metadata.installedPackages && this.metadata.installedPackages.length > 0;
    }

    get packageColumns() {
        return [
            { label: 'Package Name', fieldName: 'name', type: 'text' },
            { label: 'Namespace', fieldName: 'namespace', type: 'text' },
            { label: 'Version', fieldName: 'version', type: 'text' }
        ];
    }

    // ─── Computed: Field Usage ──────────────────────

    get hasFieldUsageObject() {
        return !!this.fieldUsageObject;
    }

    get isFieldUsageCheckDisabled() {
        return !this.fieldUsageObject || this.fieldUsageFields.length === 0 || this.fieldUsageLoading;
    }

    get hasFieldUsageResult() {
        return this.fieldUsageResult && this.fieldUsageResult.fields && this.fieldUsageResult.fields.length > 0;
    }

    get fieldUsageColumns() {
        return [
            { label: 'Field API Name', fieldName: 'fieldName', type: 'text', sortable: true },
            { label: 'Label', fieldName: 'fieldLabel', type: 'text' },
            { label: 'Type', fieldName: 'fieldType', type: 'text' },
            { label: 'Populated', fieldName: 'populatedCount', type: 'number' },
            { label: 'Total Records', fieldName: 'totalCount', type: 'number' },
            { label: '% Populated', fieldName: 'percentPopulated', type: 'text', sortable: true }
        ];
    }

    // ─── Navigation Handlers ────────────────────────

    handleLimitsTab() { this.activeUtility = 'limits'; }
    handleMetadataTab() { this.activeUtility = 'metadata'; }
    handleClearLogsTab() { this.activeUtility = 'clearLogs'; }
    handleFieldUsageTab() { this.activeUtility = 'fieldUsage'; }

    // ─── API Limits Handlers ────────────────────────

    handleRefreshLimits() {
        this.limitsLoading = true;
        this.limitsError = '';

        getOrgLimits()
            .then((result) => {
                this.limits = result || [];
            })
            .catch((err) => {
                this.limitsError = err.body ? err.body.message : err.message;
            })
            .finally(() => {
                this.limitsLoading = false;
            });
    }

    // ─── Org Metadata Handlers ──────────────────────

    handleRefreshMetadata() {
        this.metadataLoading = true;
        this.metadataError = '';

        getOrgMetadataSummary()
            .then((result) => {
                if (result.error) {
                    this.metadataError = result.error;
                } else {
                    this.metadata = result;
                }
            })
            .catch((err) => {
                this.metadataError = err.body ? err.body.message : err.message;
            })
            .finally(() => {
                this.metadataLoading = false;
            });
    }

    // ─── Clear Logs Handlers ────────────────────────

    handleClearLogsClick() {
        this.showLogConfirm = true;
    }

    handleConfirmClearLogs() {
        this.showLogConfirm = false;
        this._executeClearLogs();
    }

    handleCancelClearLogs() {
        this.showLogConfirm = false;
    }

    _executeClearLogs() {
        this.logsClearing = true;
        this.logsError = '';
        this.logsMessage = '';

        clearCurrentUserApexLogs()
            .then((result) => {
                if (result.errorCount > 0 && result.errors.length > 0) {
                    this.logsError = result.errors.join('; ');
                }
                if (result.successCount > 0) {
                    this.logsMessage = `${result.successCount} debug log${result.successCount !== 1 ? 's' : ''} deleted.`;
                } else if (result.errorCount === 0) {
                    this.logsMessage = 'No debug logs found for your user.';
                }
            })
            .catch((err) => {
                this.logsError = err.body ? err.body.message : err.message;
            })
            .finally(() => {
                this.logsClearing = false;
            });
    }

    // ─── Field Usage Handlers ───────────────────────

    handleFieldUsageObjectSelect(event) {
        this.fieldUsageObject = event.detail.value;
        this.fieldUsageFields = [];
        this.fieldUsageResult = null;
        this.fieldUsageError = '';
    }

    handleFieldUsageFieldSelect(event) {
        this.fieldUsageFields = event.detail.value;
    }

    handleCheckFieldUsage() {
        if (this.isFieldUsageCheckDisabled) return;

        this.fieldUsageLoading = true;
        this.fieldUsageError = '';
        this.fieldUsageResult = null;

        checkFieldUsage({
            objectName: this.fieldUsageObject,
            fieldNames: this.fieldUsageFields
        })
            .then((result) => {
                if (result.error) {
                    this.fieldUsageError = result.error;
                } else {
                    this.fieldUsageResult = result;
                }
            })
            .catch((err) => {
                this.fieldUsageError = err.body ? err.body.message : err.message;
            })
            .finally(() => {
                this.fieldUsageLoading = false;
            });
    }

    // ─── Utility ────────────────────────────────────

    _formatLimitName(name) {
        // Convert camelCase/PascalCase to readable: "DailyApiRequests" → "Daily Api Requests"
        return name.replace(/([A-Z])/g, ' $1').trim();
    }
}
