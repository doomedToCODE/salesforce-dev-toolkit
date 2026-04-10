import { LightningElement, track, wire } from 'lwc';
import getSObjects from '@salesforce/apex/QueryRunnerController.getSObjects';
import describeObject from '@salesforce/apex/QueryRunnerController.describeObject';

export default class ObjectExplorer extends LightningElement {

    @track objectOptions = [];
    @track selectedObject = '';
    @track objectDescribe = null;
    @track isLoading = false;
    @track error = '';

    /** Active tab in the detail panel */
    @track activeTab = 'fields';

    /** Search filter for fields */
    @track fieldSearch = '';

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

    get hasObject() {
        return !!this.objectDescribe && !this.error;
    }

    get objectSummary() {
        if (!this.objectDescribe) return '';
        const d = this.objectDescribe;
        const caps = [];
        if (d.queryable) caps.push('Queryable');
        if (d.createable) caps.push('Createable');
        if (d.updateable) caps.push('Updateable');
        if (d.deletable) caps.push('Deletable');
        return caps.join(' · ');
    }

    get fieldCount() {
        return this.objectDescribe && this.objectDescribe.fields ? this.objectDescribe.fields.length : 0;
    }

    get relationshipCount() {
        return this.objectDescribe && this.objectDescribe.childRelationships
            ? this.objectDescribe.childRelationships.length : 0;
    }

    get filteredFields() {
        if (!this.objectDescribe || !this.objectDescribe.fields) return [];
        const search = this.fieldSearch.toLowerCase();
        const fields = search
            ? this.objectDescribe.fields.filter(
                f => f.name.toLowerCase().includes(search) || f.label.toLowerCase().includes(search)
            )
            : this.objectDescribe.fields;

        return fields.map(f => ({
            ...f,
            typeLabel: this._formatFieldType(f),
            requiredLabel: f.nillable ? 'No' : 'Yes',
            editableLabel: f.updateable ? 'Yes' : 'No',
            hasPicklist: f.picklistValues && f.picklistValues.length > 0,
            isReference: !!f.referenceTo
        }));
    }

    get childRelationships() {
        if (!this.objectDescribe || !this.objectDescribe.childRelationships) return [];
        return this.objectDescribe.childRelationships;
    }

    get isFieldsTab() {
        return this.activeTab === 'fields';
    }

    get isRelationshipsTab() {
        return this.activeTab === 'relationships';
    }

    get fieldsTabVariant() {
        return this.activeTab === 'fields' ? 'brand' : 'neutral';
    }

    get relationshipsTabVariant() {
        return this.activeTab === 'relationships' ? 'brand' : 'neutral';
    }

    get fieldColumns() {
        return [
            { label: 'API Name', fieldName: 'name', type: 'text', sortable: true },
            { label: 'Label', fieldName: 'label', type: 'text', sortable: true },
            { label: 'Type', fieldName: 'typeLabel', type: 'text', sortable: true },
            { label: 'Length', fieldName: 'length', type: 'number' },
            { label: 'Required', fieldName: 'requiredLabel', type: 'text' },
            { label: 'Editable', fieldName: 'editableLabel', type: 'text' },
            { label: 'Reference To', fieldName: 'referenceTo', type: 'text' }
        ];
    }

    get relationshipColumns() {
        return [
            { label: 'Relationship Name', fieldName: 'relationshipName', type: 'text', sortable: true },
            { label: 'Child Object', fieldName: 'childSObject', type: 'text', sortable: true },
            { label: 'Field', fieldName: 'field', type: 'text' }
        ];
    }

    // ─── Handlers ───────────────────────────────────

    handleObjectSelect(event) {
        this.selectedObject = event.detail.value;
        this.loadDescribe();
    }

    handleFieldSearch(event) {
        this.fieldSearch = event.target.value;
    }

    handleFieldsTab() {
        this.activeTab = 'fields';
    }

    handleRelationshipsTab() {
        this.activeTab = 'relationships';
    }

    loadDescribe() {
        if (!this.selectedObject) return;

        this.isLoading = true;
        this.error = '';
        this.objectDescribe = null;

        describeObject({ objectName: this.selectedObject })
            .then((result) => {
                if (result.error) {
                    this.error = result.error;
                } else {
                    this.objectDescribe = result;
                }
            })
            .catch((err) => {
                this.error = err.body ? err.body.message : err.message;
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    _formatFieldType(field) {
        let t = field.type || '';
        if (field.isReference && field.referenceTo) {
            t += ' → ' + field.referenceTo;
        }
        return t;
    }
}
