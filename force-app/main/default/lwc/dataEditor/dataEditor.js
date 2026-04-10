import { LightningElement, track, wire } from 'lwc';
import getSObjects from '@salesforce/apex/QueryRunnerController.getSObjects';
import getObjectFields from '@salesforce/apex/QueryRunnerController.getObjectFields';
import executeQuery from '@salesforce/apex/QueryRunnerController.executeQuery';
import queryMore from '@salesforce/apex/QueryRunnerController.queryMore';
import bulkUpdateRecords from '@salesforce/apex/QueryRunnerController.bulkUpdateRecords';
import bulkDeleteRecords from '@salesforce/apex/QueryRunnerController.bulkDeleteRecords';

export default class DataEditor extends LightningElement {

    // ─── Object & Field Selection ───────────────────

    @track objectOptions = [];
    @track selectedObject = '';
    @track fieldOptions = [];
    @track selectedFields = [];

    // ─── Query & Results ────────────────────────────

    @track data = [];
    @track columns = [];
    @track totalRows = 0;
    @track isLoading = false;
    @track error = '';
    @track successMessage = '';
    @track nextRecordsUrl = null;
    @track allRecordsFetched = true;
    @track isLoadingMore = false;

    // ─── Edit Tracking ──────────────────────────────

    /** Map of recordId -> { fieldName: newValue } */
    _editedCells = {};
    @track editedCount = 0;

    /** Original data snapshot for diff */
    _originalData = {};

    // ─── Delete Tracking ────────────────────────────

    @track selectedRowIds = [];

    // ─── Confirmation Modals ────────────────────────

    @track showDeleteConfirm = false;
    @track showSaveConfirm = false;

    // ─── Wire: load SObjects ────────────────────────

    @wire(getSObjects)
    wiredObjects({ data, error }) {
        if (data) {
            this.objectOptions = data.map((o) => ({ label: o.label, value: o.value }));
        } else if (error) {
            this.error = error.body ? error.body.message : 'Failed to load objects.';
        }
    }

    // ─── Wire: load fields when object changes ──────

    @wire(getObjectFields, { objectName: '$selectedObject' })
    wiredFields({ data, error }) {
        if (data) {
            this.fieldOptions = data.map((f) => ({ label: f.label, value: f.value }));
        } else if (error) {
            this.fieldOptions = [];
        }
    }

    // ─── Computed ───────────────────────────────────

    get hasObject() {
        return !!this.selectedObject;
    }

    get hasData() {
        return this.data && this.data.length > 0;
    }

    get hasMoreRecords() {
        return !this.allRecordsFetched && this.nextRecordsUrl;
    }

    get isQueryDisabled() {
        return !this.selectedObject || this.selectedFields.length === 0 || this.isLoading;
    }

    get hasEdits() {
        return this.editedCount > 0;
    }

    get hasSelectedRows() {
        return this.selectedRowIds.length > 0;
    }

    get editCountLabel() {
        return `${this.editedCount} record${this.editedCount !== 1 ? 's' : ''} modified`;
    }

    get deleteCountLabel() {
        return `Delete ${this.selectedRowIds.length} record${this.selectedRowIds.length !== 1 ? 's' : ''}`;
    }

    get deleteConfirmMessage() {
        return `Are you sure you want to delete ${this.selectedRowIds.length} record${this.selectedRowIds.length !== 1 ? 's' : ''}? This action cannot be undone.`;
    }

    get saveConfirmMessage() {
        return `Save changes to ${this.editedCount} record${this.editedCount !== 1 ? 's' : ''}?`;
    }

    get loadedRecordCount() {
        return this.data ? this.data.length : 0;
    }

    get paginationLabel() {
        return `Showing ${this.loadedRecordCount} of ${this.totalRows} records`;
    }

    get exportFileName() {
        return `${this.selectedObject}_export.csv`;
    }

    get isSaveDisabled() {
        return !this.hasEdits;
    }

    get showEmptyState() {
        return !this.hasData && !this.isLoading && !this.error;
    }

    // ─── Handlers: Object & Fields ──────────────────

    handleObjectSelect(event) {
        this.selectedObject = event.detail.value;
        this.selectedFields = [];
        this.clearState();
    }

    handleFieldSelect(event) {
        this.selectedFields = event.detail.value;
    }

    // ─── Query Execution ────────────────────────────

    handleQuery() {
        if (this.isQueryDisabled) return;

        // Always include Id for editing
        let fields = [...this.selectedFields];
        if (!fields.includes('Id')) {
            fields.unshift('Id');
        }

        const soql = `SELECT ${fields.join(', ')} FROM ${this.selectedObject}`;

        this.isLoading = true;
        this.error = '';
        this.successMessage = '';
        this.data = [];
        this._editedCells = {};
        this._originalData = {};
        this.editedCount = 0;
        this.selectedRowIds = [];
        this.nextRecordsUrl = null;
        this.allRecordsFetched = true;

        executeQuery({ queryString: soql })
            .then((result) => {
                if (result.error) {
                    this.error = result.error;
                } else {
                    this._processQueryResult(result, true);
                }
            })
            .catch((err) => {
                this.error = err.body ? err.body.message : err.message;
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleLoadMore() {
        if (!this.nextRecordsUrl || this.isLoadingMore) return;

        this.isLoadingMore = true;

        queryMore({ nextRecordsUrl: this.nextRecordsUrl })
            .then((result) => {
                if (result.error) {
                    this.error = result.error;
                } else {
                    this._processQueryResult(result, false);
                }
            })
            .catch((err) => {
                this.error = err.body ? err.body.message : err.message;
            })
            .finally(() => {
                this.isLoadingMore = false;
            });
    }

    _processQueryResult(result, isFirstPage) {
        const records = result.records || [];

        // Store original values for diff
        for (const rec of records) {
            if (rec.Id) {
                this._originalData[rec.Id] = { ...rec };
            }
        }

        if (isFirstPage) {
            this.data = records;
            this.totalRows = result.totalRows || 0;

            // Build editable columns (all except Id)
            this.columns = (result.columns || []).map(col => {
                if (col.fieldName === 'Id') {
                    return { ...col, editable: false };
                }
                return { ...col, editable: true };
            });
        } else {
            this.data = [...this.data, ...records];
        }

        this.allRecordsFetched = result.done !== false;
        this.nextRecordsUrl = result.nextRecordsUrl || null;
    }

    // ─── Inline Editing ─────────────────────────────

    handleCellChange(event) {
        const draftValues = event.detail.draftValues;

        for (const draft of draftValues) {
            const recordId = draft.Id;
            if (!this._editedCells[recordId]) {
                this._editedCells[recordId] = {};
            }
            // Merge changed fields
            for (const field of Object.keys(draft)) {
                if (field === 'Id') continue;
                this._editedCells[recordId][field] = draft[field];
            }
        }

        this.editedCount = Object.keys(this._editedCells).length;
    }

    // ─── Row Selection (for delete) ─────────────────

    handleRowSelection(event) {
        const selectedRows = event.detail.selectedRows;
        this.selectedRowIds = selectedRows.map(row => row.Id);
    }

    // ─── Save (Bulk Update) ─────────────────────────

    handleSaveClick() {
        if (!this.hasEdits) return;
        this.showSaveConfirm = true;
    }

    handleConfirmSave() {
        this.showSaveConfirm = false;
        this._executeSave();
    }

    handleCancelSave() {
        this.showSaveConfirm = false;
    }

    _executeSave() {
        this.isLoading = true;
        this.error = '';
        this.successMessage = '';

        // Build records array with Id + changed fields
        const recordsToUpdate = [];
        for (const [recordId, fields] of Object.entries(this._editedCells)) {
            recordsToUpdate.push({ Id: recordId, ...fields });
        }

        bulkUpdateRecords({
            objectName: this.selectedObject,
            recordsJson: JSON.stringify(recordsToUpdate)
        })
            .then((result) => {
                if (result.errorCount > 0 && result.errors.length > 0) {
                    this.error = `${result.errorCount} error(s): ${result.errors.join('; ')}`;
                }
                if (result.successCount > 0) {
                    this.successMessage = `${result.successCount} record${result.successCount !== 1 ? 's' : ''} updated successfully.`;

                    // Apply edits to local data & clear drafts
                    this._applyEditsToData();
                    this._editedCells = {};
                    this.editedCount = 0;
                    this._clearDraftValues();
                }
            })
            .catch((err) => {
                this.error = err.body ? err.body.message : err.message;
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    _applyEditsToData() {
        this.data = this.data.map(row => {
            const edits = this._editedCells[row.Id];
            if (edits) {
                const updated = { ...row, ...edits };
                this._originalData[row.Id] = { ...updated };
                return updated;
            }
            return row;
        });
    }

    _clearDraftValues() {
        const datatable = this.template.querySelector('lightning-datatable');
        if (datatable) {
            datatable.draftValues = [];
        }
    }

    handleDiscardEdits() {
        this._editedCells = {};
        this.editedCount = 0;
        this._clearDraftValues();

        // Restore original data
        this.data = this.data.map(row => {
            return this._originalData[row.Id] ? { ...this._originalData[row.Id] } : row;
        });
    }

    // ─── Bulk Delete ────────────────────────────────

    handleDeleteClick() {
        if (!this.hasSelectedRows) return;
        this.showDeleteConfirm = true;
    }

    handleConfirmDelete() {
        this.showDeleteConfirm = false;
        this._executeDelete();
    }

    handleCancelDelete() {
        this.showDeleteConfirm = false;
    }

    _executeDelete() {
        this.isLoading = true;
        this.error = '';
        this.successMessage = '';

        bulkDeleteRecords({
            objectName: this.selectedObject,
            recordIds: this.selectedRowIds
        })
            .then((result) => {
                if (result.errorCount > 0 && result.errors.length > 0) {
                    this.error = `${result.errorCount} error(s): ${result.errors.join('; ')}`;
                }
                if (result.successCount > 0) {
                    this.successMessage = `${result.successCount} record${result.successCount !== 1 ? 's' : ''} deleted successfully.`;

                    // Remove deleted rows from local data
                    const deletedSet = new Set(this.selectedRowIds);
                    this.data = this.data.filter(row => !deletedSet.has(row.Id));
                    this.totalRows = Math.max(0, this.totalRows - result.successCount);

                    // Clean up tracking
                    for (const id of this.selectedRowIds) {
                        delete this._editedCells[id];
                        delete this._originalData[id];
                    }
                    this.editedCount = Object.keys(this._editedCells).length;
                    this.selectedRowIds = [];
                }
            })
            .catch((err) => {
                this.error = err.body ? err.body.message : err.message;
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // ─── CSV Export ─────────────────────────────────

    handleExportCsv() {
        if (!this.hasData) return;

        // Get field names from columns (excluding row number etc.)
        const fieldNames = this.columns.map(col => col.fieldName);
        const headers = fieldNames.join(',');

        const rows = this.data.map(row => {
            return fieldNames.map(field => {
                let val = row[field];
                if (val === null || val === undefined) {
                    return '';
                }
                val = String(val);
                // Escape CSV: wrap in quotes if contains comma, quote, or newline
                if (val.includes(',') || val.includes('"') || val.includes('\n')) {
                    val = '"' + val.replace(/"/g, '""') + '"';
                }
                return val;
            }).join(',');
        });

        const csvContent = headers + '\n' + rows.join('\n');

        // Create and download file
        const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
        const link = document.createElement('a');
        link.href = URL.createObjectURL(blob);
        link.download = this.exportFileName;
        link.click();

        // Cleanup
        setTimeout(() => URL.revokeObjectURL(link.href), 100);
    }

    // ─── Utility ────────────────────────────────────

    clearState() {
        this.data = [];
        this.columns = [];
        this.totalRows = 0;
        this.error = '';
        this.successMessage = '';
        this._editedCells = {};
        this._originalData = {};
        this.editedCount = 0;
        this.selectedRowIds = [];
        this.nextRecordsUrl = null;
        this.allRecordsFetched = true;
        this.showDeleteConfirm = false;
        this.showSaveConfirm = false;
    }
}
