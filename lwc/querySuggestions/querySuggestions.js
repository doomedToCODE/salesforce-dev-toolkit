import { LightningElement, api } from 'lwc';

/**
 * querySuggestions – V2 scaffold for field/object auto-complete dropdown.
 *
 * Displays a list of suggestion items and fires a 'select' event when
 * the user clicks one. Designed to be positioned alongside the query editor.
 */
export default class QuerySuggestions extends LightningElement {

    /** Array of { label, value } suggestion items */
    @api suggestions = [];

    get hasSuggestions() {
        return this.suggestions && this.suggestions.length > 0;
    }

    handleSelect(event) {
        const value = event.currentTarget.dataset.value;
        this.dispatchEvent(new CustomEvent('select', {
            detail: { value }
        }));
    }
}
