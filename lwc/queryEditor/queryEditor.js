import { LightningElement, api, track, wire } from 'lwc';
import getObjectFields from '@salesforce/apex/QueryRunnerController.getObjectFields';


export default class QueryEditor extends LightningElement {

    @api
    get queryString() {
        return this._queryString;
    }
    set queryString(value) {
        this._queryString = value || '';
        this.internalQuery = this._queryString;
        this._syncTextarea();
        this._parseObjectFromQuery(this._queryString);
    }

    @track internalQuery = '';
    _queryString = '';

    /** Detected SObject name from the FROM clause */
    @track detectedObject = '';

    /** All fields for the detected object */
    @track allFields = [];

    /** Filtered fields based on search input */
    @track fieldSearch = '';

    /** Tracks which fields are already in the SELECT clause */
    @track selectedFieldSet = new Set();

    /** Controls visibility of the suggestion panel */
    @track showSuggestions = false;

    // ─── Wire: fetch fields when detectedObject changes ──

    @wire(getObjectFields, { objectName: '$detectedObject' })
    wiredFields({ data, error }) {
        if (data) {
            this.allFields = data.map((f) => ({
                apiName: f.value,
                label: f.label,
                type: f.type
            }));
            this.showSuggestions = this.allFields.length > 0;
        } else if (error) {
            this.allFields = [];
            this.showSuggestions = false;
        }
    }

    // ─── Computed ───────────────────────────────────

    get filteredFields() {
        const search = (this.fieldSearch || '').toLowerCase();
        const fields = search
            ? this.allFields.filter(
                f => f.apiName.toLowerCase().includes(search) || f.label.toLowerCase().includes(search)
            )
            : this.allFields;

        return fields.map(f => ({
            ...f,
            isSelected: this.selectedFieldSet.has(f.apiName.toLowerCase()),
            pillClass: this.selectedFieldSet.has(f.apiName.toLowerCase())
                ? 'slds-badge slds-badge_inverse field-pill field-pill_selected'
                : 'slds-badge field-pill'
        }));
    }

    get fieldCountLabel() {
        if (!this.detectedObject) return '';
        const selected = this.selectedFieldSet.size;
        const total = this.allFields.length;
        return `${this.detectedObject} · ${total} fields` + (selected > 0 ? ` · ${selected} in query` : '');
    }

    get hasSuggestions() {
        return this.showSuggestions && this.filteredFields.length > 0;
    }

    // ─── Lifecycle ──────────────────────────────────

    renderedCallback() {
        this._syncTextarea();
    }

    _syncTextarea() {
        const ta = this.template?.querySelector('[data-id="soqlTextarea"]');
        if (ta && ta !== this.template.activeElement) {
            ta.value = this.internalQuery;
        }
    }

    // ─── Handlers ───────────────────────────────────

    handleInput(event) {
        this.internalQuery = event.target.value;
        this._parseObjectFromQuery(this.internalQuery);
        this._parseSelectedFields(this.internalQuery);
        this.dispatchEvent(new CustomEvent('querychange', {
            detail: { value: this.internalQuery }
        }));
    }

    handleRun() {
        this.dispatchEvent(new CustomEvent('runquery'));
    }

    handleFieldSearch(event) {
        this.fieldSearch = event.target.value;
    }

    handleFieldClick(event) {
        const fieldName = event.currentTarget.dataset.field;
        if (!fieldName) return;

        this._insertFieldIntoQuery(fieldName);
    }

    handleCopyField(event) {
        event.stopPropagation();
        const fieldName = event.currentTarget.dataset.field;
        if (fieldName && navigator.clipboard) {
            navigator.clipboard.writeText(fieldName);
        }
    }

    handleInsertAllFields() {
        // Build comma-separated list of all visible filtered fields
        const fieldsToInsert = this.filteredFields
            .filter(f => !f.isSelected)
            .map(f => f.apiName);

        if (fieldsToInsert.length === 0) return;

        for (const field of fieldsToInsert) {
            this._insertFieldIntoQuery(field);
        }
    }

    // ─── Query Parsing ──────────────────────────────

    _parseObjectFromQuery(query) {
        if (!query) {
            this._clearSuggestions();
            return;
        }

        // Extract object name from "FROM ObjectName" (case-insensitive)
        const match = query.match(/\bFROM\s+(\w+)/i);
        if (match && match[1]) {
            const objectName = match[1];
            if (objectName.toUpperCase() !== this.detectedObject?.toUpperCase() || this.detectedObject !== objectName) {
                this.detectedObject = objectName;
                this.fieldSearch = '';
            }
            this._parseSelectedFields(query);
        } else {
            this._clearSuggestions();
        }
    }

    _parseSelectedFields(query) {
        if (!query) {
            this.selectedFieldSet = new Set();
            return;
        }

        // Extract fields between SELECT and FROM
        const selectMatch = query.match(/\bSELECT\s+([\s\S]*?)\bFROM\b/i);
        if (selectMatch && selectMatch[1]) {
            const fieldsPart = selectMatch[1];
            const fields = fieldsPart
                .split(',')
                .map(f => f.trim().toLowerCase())
                .filter(f => f.length > 0);
            this.selectedFieldSet = new Set(fields);
        } else {
            this.selectedFieldSet = new Set();
        }
    }

    _insertFieldIntoQuery(fieldName) {
        const query = this.internalQuery || '';

        // Find the SELECT ... FROM boundary
        const selectMatch = query.match(/\bSELECT\s+([\s\S]*?)\bFROM\b/i);

        if (selectMatch) {
            const currentFields = selectMatch[1].trim();
            const fromIndex = query.toUpperCase().indexOf('FROM');

            // Add field before FROM
            let newFields;
            if (!currentFields || currentFields === '') {
                newFields = fieldName;
            } else {
                newFields = currentFields + ', ' + fieldName;
            }

            const updatedQuery = query.substring(0, query.toUpperCase().indexOf('SELECT') + 7)
                + newFields + ' '
                + query.substring(fromIndex);

            this.internalQuery = updatedQuery;
            this._syncTextarea();
            this._parseSelectedFields(updatedQuery);
            this.dispatchEvent(new CustomEvent('querychange', {
                detail: { value: this.internalQuery }
            }));
        } else if (query.toUpperCase().includes('SELECT')) {
            // SELECT exists but no FROM yet — append to end
            const updatedQuery = query.trimEnd() + (query.trimEnd().toUpperCase().endsWith('SELECT') ? ' ' : ', ') + fieldName;
            this.internalQuery = updatedQuery;
            this._syncTextarea();
            this.dispatchEvent(new CustomEvent('querychange', {
                detail: { value: this.internalQuery }
            }));
        }
    }

    _clearSuggestions() {
        this.detectedObject = '';
        this.allFields = [];
        this.showSuggestions = false;
        this.selectedFieldSet = new Set();
    }
}
