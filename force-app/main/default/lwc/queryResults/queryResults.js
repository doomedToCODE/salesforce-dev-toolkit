import { LightningElement, api } from 'lwc';

/**
 * queryResults – Displays SOQL query results in a lightning-datatable.
 *
 * Receives records, columns, totalRows, isLoading, and error from
 * the parent queryRunner component.
 */
export default class QueryResults extends LightningElement {

    /** Array of row objects */
    @api records = [];

    /** Datatable column definitions */
    @api columns = [];

    /** Total number of rows returned by the query */
    @api totalRows = 0;

    /** True when query is in flight */
    @api isLoading = false;

    /** Error message (displayed by parent; kept here for future use) */
    @api error = '';

    // ───────────────────────────────────────────────
    // Computed properties
    // ───────────────────────────────────────────────

    get hasData() {
        return !this.isLoading && this.records && this.records.length > 0;
    }

    /** Show "no records" only after a query has been run (totalRows === 0) and there is no error */
    get showEmpty() {
        return (
            !this.isLoading &&
            (!this.records || this.records.length === 0) &&
            this.totalRows === 0 &&
            !this.error &&
            this._hasRun
        );
    }

    /** Label badge text */
    get rowCountLabel() {
        return `${this.totalRows} record${this.totalRows !== 1 ? 's' : ''}`;
    }

    /**
     * Track whether the component has rendered with real data at least once.
     * This prevents the empty state from flashing on first load.
     */
    _hasRun = false;

    renderedCallback() {
        if (this.totalRows > 0 || (this.records && this.records.length > 0)) {
            this._hasRun = true;
        }
        // Also mark as run if loading has completed at least once
        if (!this.isLoading && this._wasLoading) {
            this._hasRun = true;
        }
        this._wasLoading = this.isLoading;
    }

    _wasLoading = false;
}
