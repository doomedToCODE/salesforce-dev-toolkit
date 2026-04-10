import { LightningElement, api, track, wire } from 'lwc';
import getSObjects from '@salesforce/apex/QueryRunnerController.getSObjects';
import getObjectFields from '@salesforce/apex/QueryRunnerController.getObjectFields';

/**
 * queryBuilder – UI-based query construction panel.
 *
 * Lets the user pick an object, select fields, define filters,
 * and generate a SOQL string sent back to the parent queryRunner.
 */
export default class QueryBuilder extends LightningElement {

    // ───────────────────────────────────────────────
    // Public API (props from parent)
    // ───────────────────────────────────────────────

    @api selectedObject = '';
    @api selectedFields = [];
    @api filters = [];

    // ───────────────────────────────────────────────
    // Internal tracked state
    // ───────────────────────────────────────────────

    @track objectOptions = [];
    @track fieldOptions = [];
    @track internalSelectedFields = [];
    @track internalFilters = [];

    /** Counter used for unique filter row keys */
    _filterIdCounter = 0;

    /** Standard SOQL operators */
    get operatorOptions() {
        return [
            { label: 'Equals (=)', value: '=' },
            { label: 'Not Equals (!=)', value: '!=' },
            { label: 'Less Than (<)', value: '<' },
            { label: 'Greater Than (>)', value: '>' },
            { label: 'LIKE', value: 'LIKE' },
            { label: 'IN', value: 'IN' }
        ];
    }

    get hasObject() {
        return !!this.selectedObject;
    }

    // ───────────────────────────────────────────────
    // Wire: load SObjects list
    // ───────────────────────────────────────────────

    @wire(getSObjects)
    wiredObjects({ data, error }) {
        if (data) {
            this.objectOptions = data.map((o) => ({ label: o.label, value: o.value }));
        } else if (error) {
            console.error('Error loading SObjects', error);
        }
    }

    // ───────────────────────────────────────────────
    // Wire: load fields when object changes
    // ───────────────────────────────────────────────

    @wire(getObjectFields, { objectName: '$selectedObject' })
    wiredFields({ data, error }) {
        if (data) {
            this.fieldOptions = data.map((f) => ({ label: f.label, value: f.value }));
        } else if (error) {
            console.error('Error loading fields', error);
            this.fieldOptions = [];
        }
    }

    // ───────────────────────────────────────────────
    // Handlers
    // ───────────────────────────────────────────────

    handleObjectSelect(event) {
        this.internalSelectedFields = [];
        this.internalFilters = [];
        this.dispatchEvent(new CustomEvent('objectchange', { detail: { value: event.detail.value } }));
    }

    handleFieldSelect(event) {
        this.internalSelectedFields = event.detail.value;
        this.dispatchEvent(new CustomEvent('fieldschange', { detail: { value: [...event.detail.value] } }));
    }

    // ── Filter management ──

    handleAddFilter() {
        this._filterIdCounter += 1;
        this.internalFilters = [
            ...this.internalFilters,
            { id: this._filterIdCounter, field: '', operator: '=', value: '' }
        ];
        this._emitFilters();
    }

    handleRemoveFilter(event) {
        const idx = parseInt(event.currentTarget.dataset.index, 10);
        this.internalFilters = this.internalFilters.filter((_, i) => i !== idx);
        this._emitFilters();
    }

    handleFilterChange(event) {
        const idx = parseInt(event.currentTarget.dataset.index, 10);
        const prop = event.currentTarget.dataset.prop;
        const val = event.detail.value !== undefined ? event.detail.value : event.target.value;

        // Immutable update
        this.internalFilters = this.internalFilters.map((f, i) => {
            if (i === idx) {
                return { ...f, [prop]: val };
            }
            return f;
        });
        this._emitFilters();
    }

    _emitFilters() {
        this.dispatchEvent(new CustomEvent('filterschange', {
            detail: { value: this.internalFilters.map(({ field, operator, value }) => ({ field, operator, value })) }
        }));
    }

    // ── SOQL generation ──

    handleGenerate() {
        const fields = this.internalSelectedFields.length > 0
            ? this.internalSelectedFields.join(', ')
            : 'Id';

        let soql = `SELECT ${fields} FROM ${this.selectedObject}`;

        // Build WHERE clause from complete filters
        const validFilters = this.internalFilters.filter((f) => f.field && f.operator && f.value);
        if (validFilters.length > 0) {
            const conditions = validFilters.map((f) => {
                if (f.operator === 'LIKE') {
                    return `${f.field} LIKE '${f.value}'`;
                }
                if (f.operator === 'IN') {
                    return `${f.field} IN (${f.value})`;
                }
                // Wrap value in quotes for string comparison
                const isNumeric = !isNaN(f.value) && f.value.trim() !== '';
                const val = isNumeric ? f.value : `'${f.value}'`;
                return `${f.field} ${f.operator} ${val}`;
            });
            soql += ` WHERE ${conditions.join(' AND ')}`;
        }

        this.dispatchEvent(new CustomEvent('generatequery', { detail: { value: soql } }));
    }
}
