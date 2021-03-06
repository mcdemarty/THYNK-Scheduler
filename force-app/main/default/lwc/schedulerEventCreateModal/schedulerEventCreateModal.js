import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent'
import { subscribe, unsubscribe, APPLICATION_SCOPE, publish, MessageContext } from 'lightning/messageService';
import schedulerEventChanged from '@salesforce/messageChannel/SchedulerEventChanged__c';
import isResourceBookable from '@salesforce/apex/SchedulerControllerV2.isResourceBookable';
import getMaintenanceTimeRanges from '@salesforce/apex/SchedulerControllerV2.getMaintenanceTimeRanges';
import getTimeRanges from '@salesforce/apex/SchedulerControllerV2.getTimeRanges';

export default class SchedulerEventCreateModal extends LightningElement {

	@wire(MessageContext)
	messageContext;

	modalVisible = false;
	showSpinner = false;

	@api eventObjectName;
	@api fields;
	@api eventId;
	@api fieldMappingMetadataName;
	@api eventParentResourceFieldName;
	@api eventStartDateFieldName;
	@api eventEndDateFieldName;
	@api useOverbookingFlow;

	@api showModal() {
		this.modalVisible = true;
		this.showSpinner = false;
	}

	@api setFieldValue(field, value) {
		const node = this.template.querySelector('lightning-input-field.' + field);

		if (node) {
			node.value = value;
		}
	}

	hideModal() {
		this.modalVisible = false;
	}

	formSubmitHandler(event) {
		event.preventDefault();

		this.showSpinner = true;

		isResourceBookable({
			fieldMappingMetadataName: this.fieldMappingMetadataName,
			resourceId: event.detail.fields[this.eventParentResourceFieldName]
		})
			.then(result => {
				if (result) {
					getMaintenanceTimeRanges({
						fieldMappingMetadataName: this.fieldMappingMetadataName,
						startTime: event.detail.fields[this.eventStartDateFieldName],
						endTime: event.detail.fields[this.eventEndDateFieldName],
						resources: [event.detail.fields[this.eventParentResourceFieldName]]
					})
						.then(result => {
							if (!result.length) {
								getTimeRanges({
									fieldMappingMetadataName: this.fieldMappingMetadataName,
									startTime: event.detail.fields[this.eventStartDateFieldName],
									endTime: event.detail.fields[this.eventEndDateFieldName],
								})
									.then(result => {
										if (!result.length) {
											this.template.querySelector('.record-edit-form').submit();
										} else {
											this.showErrorToast('This dates are in maintenance');
										}
									});
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

	formSuccessHandler(event) {
		if (this.useOverbookingFlow) {
			const fields = event.detail.fields;

			publish(this.messageContext, schedulerEventChanged, {
				eventId: event.detail.id,
				resourceId: fields[this.eventParentResourceFieldName].value,
				startDate: fields[this.eventStartDateFieldName].value,
				endDate: fields[this.eventEndDateFieldName].value,
				resourceChanged: true,
				propertyId: fields.thn__Property__c.value,
				isCreate: true
			});
		}

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

	get modalLabel() {
		return this.eventId ? 'Edit Event' : 'Create Event';
	}

}