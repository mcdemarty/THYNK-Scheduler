import { LightningElement, api, wire, track } from 'lwc';

export default class FieldCcomponent extends LightningElement {

	@api eventToHandle;
	@api fieldMap;
	@api fieldName;
	@track field;

	connectedCallback() {
		this.field = this.fieldMap[this.fieldName];
	}

	handleChangeText(event) {
		const fieldValue = event.target.value;
		this.updateField(fieldValue);
	}

	handleChangeCheckbox(event) {
		const fieldValue = event.target.checked;
		this.updateField(fieldValue);
	}

	handleChangeDate(event) {
		const fieldValue = event.target.value;
		this.updateField(fieldValue);
	}

	handleChangeNumber(event) {
		const fieldValue = event.target.value;
		this.updateField(fieldValue);
	}

	handleChangePicklist(event) {
		const fieldValue = event.detail.value;
		this.updateField(fieldValue);
	}

	handleLookupSelection(event) {
		const fieldValue = event.detail;
		this.updateField(fieldValue);
	}

	updateField(value) {
		this.dispatchEvent(
			new CustomEvent(
				'updaterecord',
				{
					bubbles: true,
					composed: true,
					detail: {
						fieldName: this.fieldName,
						fieldValue: value
					}
				}
			)
		);
	}

	get fieldLabel() {
		return this.fieldMap[this.fieldName].fieldLabel;
	}

	get fieldValue() {
		return this.eventToHandle[this.fieldName] || null;
	}

	get isLookupField() {
		return this.fieldMap[this.fieldName].isLookupField;
	}

	get isTextField() {
		return this.fieldMap[this.fieldName].isTextField;
	}

	get isTextAreaField() {
		return this.fieldMap[this.fieldName].isTextAreaField;
	}

	get isCheckboxField() {
		return this.fieldMap[this.fieldName].isCheckboxField;
	}

	get isDateField() {
		return this.fieldMap[this.fieldName].isDateField;
	}

	get isTimeField() {
		return this.fieldMap[this.fieldName].isTimeField;
	}

	get isDateTimeField() {
		return this.fieldMap[this.fieldName].isDateTimeField;
	}

	get isNumberField() {
		return this.fieldMap[this.fieldName].isNumberField;
	}

	get isCurrencyField() {
		return this.fieldMap[this.fieldName].isCurrencyField;
	}

	get isPercentageField() {
		return this.fieldMap[this.fieldName].isPercentageField;
	}

	get isPicklistField() {
		return this.fieldMap[this.fieldName].isPicklistField;
	}

	get step() {
		return this.fieldMap[this.fieldName].step;
	}

	get referenceObject() {
		return this.fieldMap[this.fieldName].referenceObject ? this.fieldMap[this.fieldName].referenceObject.name : '';
	}

	get referenceObjectLabel() {
		return this.fieldMap[this.fieldName].referenceObject ? this.fieldMap[this.fieldName].referenceObject.label : '';
	}

	get referenceObjectRecordTypeId() {
		return this.fieldMap[this.fieldName].referenceObject ? this.fieldMap[this.fieldName].referenceObject.defaultRecordTypeId : '';
	}

	get picklistOptions() {
		const options = [];
		for (let picklistOption of this.fieldMap[this.fieldName].picklistOptions) {
			let option = Object.assign({}, picklistOption);
			if (!option.value) {
				option.value = null;
			}
			options.push(option);
		}
		return options
	}

	display(objectToDisplay, name) {
		console.log(name || '', objectToDisplay ? JSON.parse(JSON.stringify(objectToDisplay)) : null);
	}
}