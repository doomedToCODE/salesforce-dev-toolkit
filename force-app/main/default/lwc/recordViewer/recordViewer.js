import { LightningElement, track, wire } from 'lwc';
import getSObjects from '@salesforce/apex/QueryRunnerController.getSObjects';
import getRecord from '@salesforce/apex/QueryRunnerController.getRecord';
import updateRecord from '@salesforce/apex/QueryRunnerController.updateRecord';
import deleteRecord from '@salesforce/apex/QueryRunnerController.deleteRecord';

export default class RecordViewer extends LightningElement {

    @track objectOptions = [];
    @track selectedObject = '';
    @track recordId = '';
    @track record = null;
    @track fieldMetadata = [];
    @track isLoading = false;
    @track isSaving = false;
    @track error = '';
    @track successMessage = '';

    /** Editing mode toggle */
    @track isEditing = false;

    /** Fields being edited: { fieldName: newValue } */
    @track editedFields = {};

    // ─── Wire: load SObjects list ───────────────────

    @wire(getSObjects)
    wiredObjects({ data, error }) {
        if (data) {
            this.objectOptions = data.map((o) => ({ label: o.label, value: o.value }));
        } else if (error) {
            this.error = error.body ? error.body.message : 'Failed to load objects.';
        }
    }

    // ─── Computed ───────────────────────────────────

    get hasRecord() {
        return !!this.record && !this.error;
    }

    get isFetchDisabled() {
        return !this.selectedObject || !this.recordId || this.isLoading;
    }

    get displayFields() {
        if (!this.record) return [];

        const metaMap = {};
        if (this.fieldMetadata) {
            for (const fm of this.fieldMetadata) {
                metaMap[fm.name] = fm;
            }
        }

        return Object.keys(this.record).map(key => {
            const meta = metaMap[key] || {};
            const rawValue = this.record[key];
            const editedValue = this.editedFields.hasOwnProperty(key)
                ? this.editedFields[key]
                : rawValue;

            return {
                fieldName: key,
                label: meta.label || key,
                value: rawValue != null ? String(rawValue) : '',
                editValue: editedValue != null ? String(editedValue) : '',
                type: meta.type || 'string',
                updateable: meta.updateable === true,
                isEditable: this.isEditing && meta.updateable === true,
                isBoolean: (meta.type || '').toLowerCase() === 'boolean',
                isPicklist: (meta.type || '').toLowerCase() === 'picklist',
                picklistOptions: meta.picklistValues
                    ? meta.picklistValues
                        .filter(p => p.active)
                        .map(p => ({ label: p.label, value: p.value }))
                    : [],
                booleanChecked: editedValue === true || editedValue === 'true',
                isTextField: !['boolean', 'picklist'].includes((meta.type || '').toLowerCase()),
                isModified: this.editedFields.hasOwnProperty(key)
            };
        });
    }

    get editButtonLabel() {
        return this.isEditing ? 'Cancel Edit' : 'Edit Record';
    }

    get editButtonVariant() {
        return this.isEditing ? 'destructive-text' : 'neutral';
    }

    get editButtonIcon() {
        return this.isEditing ? 'utility:close' : 'utility:edit';
    }

    get hasEdits() {
        return Object.keys(this.editedFields).length > 0;
    }

    get recordTitle() {
        if (!this.record) return '';
        return this.record.Name || this.record.Id || this.recordId;
    }

    // ─── Handlers ───────────────────────────────────

    handleObjectSelect(event) {
        this.selectedObject = event.detail.value;
        this.clearState();
    }

    handleRecordIdChange(event) {
        this.recordId = event.detail.value;
    }

    handleFetchRecord() {
        if (!this.selectedObject || !this.recordId) return;

        this.isLoading = true;
        this.error = '';
        this.successMessage = '';
        this.record = null;
        this.isEditing = false;
        this.editedFields = {};

        getRecord({ objectName: this.selectedObject, recordId: this.recordId.trim() })
            .then((result) => {
                if (result.error) {
                    this.error = result.error;
                } else {
                    this.record = result.record;
                    this.fieldMetadata = result.fieldMetadata || [];
                }
            })
            .catch((err) => {
                this.error = err.body ? err.body.message : err.message;
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleToggleEdit() {
        if (this.isEditing) {
            // Cancel — discard edits
            this.isEditing = false;
            this.editedFields = {};
        } else {
            this.isEditing = true;
        }
    }

    handleFieldChange(event) {
        const fieldName = event.currentTarget.dataset.field;
        let value;

        if (event.detail && event.detail.value !== undefined) {
            value = event.detail.value;
        } else if (event.detail && event.detail.checked !== undefined) {
            value = event.detail.checked;
        } else {
            value = event.target.value;
        }

        this.editedFields = { ...this.editedFields, [fieldName]: value };
    }

    handleBooleanChange(event) {
        const fieldName = event.currentTarget.dataset.field;
        const value = event.detail.checked;
        this.editedFields = { ...this.editedFields, [fieldName]: value };
    }

    handleSave() {
        if (!this.hasEdits) return;

        this.isSaving = true;
        this.error = '';
        this.successMessage = '';

        const fieldsJson = JSON.stringify(this.editedFields);

        updateRecord({
            objectName: this.selectedObject,
            recordId: this.recordId.trim(),
            fieldsJson: fieldsJson
        })
            .then((result) => {
                if (result.success) {
                    this.successMessage = 'Record updated successfully.';
                    this.isEditing = false;
                    this.editedFields = {};
                    // Refresh the record
                    this.handleFetchRecord();
                } else {
                    this.error = result.error || 'Update failed.';
                }
            })
            .catch((err) => {
                this.error = err.body ? err.body.message : err.message;
            })
            .finally(() => {
                this.isSaving = false;
            });
    }

    handleDelete() {
        if (!this.selectedObject || !this.recordId) return;

        this.isSaving = true;
        this.error = '';
        this.successMessage = '';

        deleteRecord({ objectName: this.selectedObject, recordId: this.recordId.trim() })
            .then((result) => {
                if (result.success) {
                    this.successMessage = 'Record deleted successfully.';
                    this.record = null;
                    this.isEditing = false;
                    this.editedFields = {};
                } else {
                    this.error = result.error || 'Delete failed.';
                }
            })
            .catch((err) => {
                this.error = err.body ? err.body.message : err.message;
            })
            .finally(() => {
                this.isSaving = false;
            });
    }

    clearState() {
        this.record = null;
        this.fieldMetadata = [];
        this.error = '';
        this.successMessage = '';
        this.isEditing = false;
        this.editedFields = {};
    }
}
