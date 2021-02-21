import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent'
import isResourceBookable from '@salesforce/apex/SchedulerControllerV2.isResourceBookable';
import getMaintenanceTimeRanges from '@salesforce/apex/SchedulerControllerV2.getMaintenanceTimeRanges';

export default class SchedulerEventCreateModal extends LightningElement {

	modalVisible = false;
	showSpinner = false;

	@api eventObjectName;
	@api fields;
	@api eventId;
	@api fieldMappingMetadataId;
	@api eventParentResourceFieldName;
	@api eventStartDateFieldName;
	@api eventEndDateFieldName;

	@api showModal() {
		this.modalVisible = true;
		this.showSpinner = false;
	}

	hideModal() {
		this.modalVisible = false;
	}

	formSubmitHandler(event) {
		event.preventDefault();

		this.showSpinner = true;

		isResourceBookable({
			fieldMappingMetadataId: this.fieldMappingMetadataId,
			resourceId: event.detail.fields[this.eventParentResourceFieldName]
		})
			.then(result => {
				if (result) {
					getMaintenanceTimeRanges({
						fieldMappingMetadataId: this.fieldMappingMetadataId,
						startTime: event.detail.fields[this.eventStartDateFieldName],
						endTime: event.detail.fields[this.eventEndDateFieldName],
						resources: [event.detail.fields[this.eventParentResourceFieldName]]
					})
						.then(result => {
							if (!result.length) {
								this.template.querySelector('.record-edit-form').submit();
							} else {
								this.showErrorToast('This resource is in maintenance for this dates');
							}
						});
				} else {
					this.showErrorToast('This resource isn\'t bookable');
				}
			})
			.catch(e => {
				console.error(e);
			})
			.finally(() => {
				this.showSpinner = false;
			});
	}

	formSuccessHandler() {
		this.hideModal();

		this.showSpinner = false;

		this.dispatchEvent(new CustomEvent('eventcreate'));
	}

	formErrorHandler() {
		this.showSpinner = false;
	}

	showErrorToast(message) {
		this.dispatchEvent(new ShowToastEvent({
			title: 'Error',
			variant: 'error',
			message: message
		}));
	}

}