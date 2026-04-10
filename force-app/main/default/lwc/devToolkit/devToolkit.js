import { LightningElement, track } from 'lwc';

/**
 * DevToolkit - Main app shell for the Salesforce Developer Toolkit.
 *
 * Acts as a single-page container that renders child tool views
 * based on sidebar navigation selection. Designed for use inside
 * a Custom Lightning Tab as a full-page application.
 */
export default class DevToolkit extends LightningElement {
    /**
     * Tracks the currently selected navigation item.
     * Drives conditional rendering in the template.
     */
    @track currentView = 'queryRunner';

    // ───────────────────────────────────────────────
    // Navigation handler
    // ───────────────────────────────────────────────

    /**
     * Handles sidebar navigation item selection.
     * Updates currentView to trigger reactive re-render.
     * @param {CustomEvent} event - select event from lightning-vertical-navigation
     */
    handleNavSelect(event) {
        this.currentView = event.detail.name;
    }

    // ───────────────────────────────────────────────
    // Computed getters for conditional rendering
    // ───────────────────────────────────────────────

    get isQueryRunner() {
        return this.currentView === 'queryRunner';
    }

    get isObjectExplorer() {
        return this.currentView === 'objectExplorer';
    }

    get isRecordViewer() {
        return this.currentView === 'recordViewer';
    }

    get isDataEditor() {
        return this.currentView === 'dataEditor';
    }

    get isUtilities() {
        return this.currentView === 'utilities';
    }
}
