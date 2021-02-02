({
	/**
	 * Throws when the component retrieve any information from the container with Scheduler
	 * @param component
	 * @param message
	 * @param helper
	 */
	containerMessageHandler: function(component, message, helper) {

		$A.getCallback(() => {
			const payload = message.getParams();

			if (payload === 'schedulerInit') {
				const getPicklistDataAction = component.get('c.getPicklistData');

				getPicklistDataAction.setParams({
					fieldMappingMetadataId: component.get('v.fieldMappingMetadataId')
				});

				getPicklistDataAction.setCallback(this, function(response) {
					if (response.getState() === 'SUCCESS') {
						const result = JSON.parse(response.getReturnValue());

						const hotels = [];

						result.hotels.map(hotel => {
							hotels.push({
								value: hotel.Id,
								label: hotel.Name
							})
						});

						component.set('v.hotels', hotels);
						component.set('v.types', result.types);

						if (window.localStorage.getItem('scheduler--date')) {
							component.set('v.currentDate', new Date(window.localStorage.getItem('scheduler--date')).toISOString().replace(/T.*Z/, ''));
						} else {
							component.set('v.currentDate', new Date().toISOString().replace(/T.*Z/, ''));
						}

						component.set('v.viewType', window.localStorage.getItem('scheduler--view') || 'day');
					} else {
						console.error(response.getError()[0].message);
					}
				});

				$A.enqueueAction(getPicklistDataAction);
			} else if (payload.name === 'navigation') {
				window.open(payload.href, '_blank');
			} else if (payload.name === 'addEventContextMenuClick') {
				const resourceRecord = payload.data.resourceRecord;

				if (!resourceRecord[component.get('v.schedulerMapping').thn__Resource_Bookable_API_Field__c]) {
					const toastEvent = $A.get('e.force:showToast');
					toastEvent.setParams({
						title: 'Error!',
						message: 'This resource isn\'t bookable',
						type: 'error'
					});
					toastEvent.fire();

					return;
				}

				component.set('v.newEventParentResource', resourceRecord.Id);
				component.find('eventCreateModal').set('v.eventCreateModalVisible', true);
			} else if (payload.name === 'schedulerListenerEventClick') {
				component.set('v.newEventParentResource', payload.data.eventResourceId);
				component.set('v.selectedEventId', payload.data.eventId);
				component.find('eventCreateModal').set('v.eventCreateModalVisible', true);
			} else if (payload.name === 'schedulerListenerCellDblClick') {
				if (!payload.data[component.get('v.schedulerMapping').thn__Resource_Bookable_API_Field__c]) {
					return;
				}

				component.set('v.newEventParentResource', payload.data.Id);
				component.find('eventCreateModal').set('v.eventCreateModalVisible', true);
			} else if (payload.name === 'schedulerListenerEventDrop') {
				// const resourceId = payload.data.targetResourceRecord.data.id;
				let resourceId = payload.data.eventRecords[0].data[component.get('v.schedulerMapping').thn__Event_Parent_Resource_API_Field__c];

				if (resourceId){
					if (resourceId !== payload.data.targetResourceRecord.data.id){
						resourceId = payload.data.targetResourceRecord.data.id;
					}
					if (!component.get('v.data').resources[resourceId][component.get('v.schedulerMapping').thn__Resource_Bookable_API_Field__c]) {
						const toastEvent = $A.get('e.force:showToast');
						toastEvent.setParams({
							title: 'Error!',
							message: 'This resource isn\'t bookable',
							type: 'error'
						});
						toastEvent.fire();

						$A.enqueueAction(component.get('c.updateData'));

						return;
					}
				}

				const action = component.get('c.updateEvent');
				const newEvent = {
					Id: payload.data.eventRecords[0].Id
				};

				let startDate = new Date(payload.data.eventRecords[0].data.startDate);
				let endDate = new Date(payload.data.eventRecords[0].data.endDate);

				startDate.setHours(startDate.getHours() - new Date().getTimezoneOffset() / 60);
				endDate.setHours(endDate.getHours() - new Date().getTimezoneOffset() / 60);

				newEvent[component.get('v.schedulerMapping').thn__Event_Start_Date_API_Field__c] = startDate.toJSON().replace('T', ' ');
				newEvent[component.get('v.schedulerMapping').thn__Event_End_Date_API_Field__c] = endDate.toJSON().replace('T', ' ');
				if (resourceId){
					newEvent[component.get('v.schedulerMapping').thn__Event_Parent_Resource_API_Field__c] = resourceId;
				}
				console.log(newEvent);
				action.setParams({
					eventData: newEvent,
					fieldMappingMetadataId: component.get('v.fieldMappingMetadataId')
				});

				action.setCallback(this, $A.getCallback(function(response) {
					if (response.getState() === 'SUCCESS' && !response.getReturnValue()) {
					} else {
						const toastEvent = $A.get('e.force:showToast');

						let message = response.getReturnValue() || response.getError()[0].message;

						if (message.toLowerCase().includes('FIELD_CUSTOM_VALIDATION_EXCEPTION'.toLowerCase())) {
							message = message.substring(message.indexOf('FIELD_CUSTOM_VALIDATION_EXCEPTION') + 35, message.length - 4);
						}

						toastEvent.setParams({
							title: 'Error!',
							message: message,
							type: 'error'
						});
						toastEvent.fire();

						$A.enqueueAction(component.get('c.updateData'));
					}
					component.set('v.showSpinner', false);
				}));

				component.set('v.showSpinner', true);

				$A.enqueueAction(action);
			} else if (payload.name === 'schedulerListenerEventResizeEnd') {
				const action = component.get('c.updateEvent');

				const newEvent = {
					Id: payload.data.Id
				};

				let startDate = new Date(payload.data.startDate);
				let endDate = new Date(payload.data.endDate);

				startDate.setHours(startDate.getHours() - new Date().getTimezoneOffset() / 60);
				endDate.setHours(endDate.getHours() - new Date().getTimezoneOffset() / 60);

				newEvent[component.get('v.schedulerMapping').thn__Event_Start_Date_API_Field__c] = startDate.toJSON().replace('T', ' ');
				newEvent[component.get('v.schedulerMapping').thn__Event_End_Date_API_Field__c] = endDate.toJSON().replace('T', ' ');
				console.log(newEvent);

				action.setParams({
					eventData: newEvent,
					fieldMappingMetadataId: component.get('v.fieldMappingMetadataId')
				});

				action.setCallback(this, $A.getCallback(function(response) {
					if (response.getState() === 'SUCCESS' && !response.getReturnValue()) {
					} else {
						const toastEvent = $A.get('e.force:showToast');

						let message = response.getReturnValue() || response.getError()[0].message;

						if (message.toLowerCase().includes('FIELD_CUSTOM_VALIDATION_EXCEPTION'.toLowerCase())) {
							message = message.substring(message.indexOf('FIELD_CUSTOM_VALIDATION_EXCEPTION') + 35, message.length - 4);
						}

						toastEvent.setParams({
							title: 'Error!',
							message: message,
							type: 'error'
						});
						toastEvent.fire();

						$A.enqueueAction(component.get('c.updateData'));
					}

					component.set('v.showSpinner', false);
				}));

				component.set('v.showSpinner', true);

				$A.enqueueAction(action);
			}
		})();
	},

	/**
	 * Update the events and resources based on changed dates or view type
	 * @param component
	 * @param event
	 * @param helper
	 */
	updateData: function(component, event, helper) {

		if (window.viewParamsUpdateInterval) {
			clearInterval(window.viewParamsUpdateInterval);
		}

		component.set('v.showSpinner', true);

		window.localStorage.setItem('scheduler--date', new Date(component.get('v.currentDate')).toJSON());

		helper.getData(component, event, helper).then($A.getCallback(result => {
			result = JSON.parse(result);
			helper.parseDataResponse(component, event, helper, result);

			const currentViewType = component.get('v.viewType');
			let currentDate = new Date(component.get('v.currentDate'));

			if (currentViewType === 'week') {
				currentDate.setDate(currentDate.getDate() - currentDate.getDay() + (currentDate.getDay() === 0 ? -6 : 1));
			} else if (currentViewType === 'month') {
				currentDate = new Date(currentDate.getFullYear(), currentDate.getMonth(), 1);
				currentDate.setHours(Math.abs(new Date().getTimezoneOffset()) / 60);
			}

			const resourceFields = [];
			component.get('v.resourceDisplayColumns').map(column => {
				resourceFields.push({
					dataSource: column.field,
					name: column.text
				})
			});

			const columns = component.get('v.resourceDisplayColumns');
			columns[0].type = 'tree';

			columns.map(column => {
				column.editor = false;
				column.enableHeaderContextMenu = false;
				column.enableCellContextMenu = false;
			});

			const collapsedResources = [];

			const existingScheduler = component.get('v.scheduler');

			if (existingScheduler && existingScheduler.resourceStore.rootNode) {
				existingScheduler.resourceStore.rootNode.allChildren.map(item => {
					collapsedResources.push(item.isExpanded(existingScheduler.resourceStore));
				});
			}
			component.find('schedulerContainer').message({
				name: 'init',
				value: {
					viewPreset: {
						'day': 'day',
						'week': 'dayAndWeek',
						'month': 'dayAndWeek'
					}[component.get('v.viewType')],
					viewType: component.get('v.viewType'),
					currentDate: currentDate,
					endDate: currentDate,
					columns: columns,
					resourceStore: {
						fields: resourceFields,
						data: component.get('v.schedulerData')
					},
					resourceTimeRanges: component.get('v.resourceTimeRanges'),
					events: component.get('v.events'),
					eventTooltipFields: component.get('v.eventTooltipFields')
				}
			});

			component.set('v.showSpinner', false);
		})).catch($A.getCallback(reason => {
			component.set('v.errorMessage', reason);

			component.set('v.showSpinner', false);
		}));
	},

	/**
	 * Handle press on next day (week, month)
	 * @param component
	 * @param event
	 * @param helper
	 */
	moveToNextPage: function(component, event, helper) {
		const date = new Date(component.get('v.currentDate'));
		const viewType = component.get('v.viewType');

		if (viewType === 'day') {
			date.setDate(date.getDate() + 1);
		} else if (viewType === 'week') {
			date.setDate(date.getDate() + 7);
		} else if (viewType === 'month') {
			date.setMonth(date.getMonth() + 1);
		}

		component.set('v.currentDate', date.toISOString().replace(/T.*Z/, ''));
	},

	/**
	 * Handle press on previous day (week, month)
	 * @param component
	 * @param event
	 * @param helper
	 */
	moveToPrevPage: function(component, event, helper) {
		const date = new Date(component.get('v.currentDate'));
		const viewType = component.get('v.viewType');

		if (viewType === 'day') {
			date.setDate(date.getDate() - 1);
		} else if (viewType === 'week') {
			date.setDate(date.getDate() - 7);
		} else if (viewType === 'month') {
			date.setMonth(date.getMonth() - 1);
		}

		component.set('v.currentDate', date.toISOString().replace(/T.*Z/, ''));
	},

	/**
	 * Handle press on next Today button (returns the user to current day)
	 * @param component
	 * @param event
	 * @param helper
	 */
	moveToToday: function(component, event, helper) {
		window.localStorage.removeItem('scheduler--date');

		component.set('v.currentDate', new Date().toISOString().replace(/T.*Z/, ''));
	},

	/**
	 * Handle press on any view type button which throws change view event
	 * @param component
	 * @param event
	 * @param helper
	 */
	changeViewTypeButtonHandler: function(component, event, helper) {
		component.set('v.viewType', event.getSource().get('v.name'));

		window.localStorage.setItem('scheduler--view', component.get('v.viewType'));
	},

	/**
	 * Handle changing View Type property on the component to call the helper method to change the view type
	 * @param component
	 * @param event
	 * @param helper
	 */
	changeViewType: function(component, event, helper) {
		helper.setViewTypeSettings(component, event, helper);
	},

	/**
	 * Handle press on plus (new event) button
	 * @param component
	 * @param event
	 * @param helper
	 */
	openCreateEventModal: function(component, event, helper) {
		component.set('v.selectedEventId', null);
		component.find('eventCreateModal').set('v.eventCreateModalVisible', true);
	},

	expandAllHandler: function(component, event, helper) {
		component.find('schedulerContainer').message({
			name: 'expandAll',
			value: {}
		});
	},

	collapseAllHandler: function(component, event, helper) {
		component.find('schedulerContainer').message({
			name: 'collapseAll',
			value: {}
		});
	},

	onHotelSelected: function (component, event, helper) {
		component.set('v.selectedHotels', component.find('hotelSelector').get('v.selectedOptions'));

		$A.enqueueAction(component.get('c.updateData'));
	},

	onTypeSelected: function(component, event, helper) {
		component.set('v.selectedTypes', component.find('typeSelector').get('v.selectedOptions'));

		$A.enqueueAction(component.get('c.updateData'));
	}

});