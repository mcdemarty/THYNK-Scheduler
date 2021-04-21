({
	onMessage: function(component, event, helper) {
		const params = event.getParams();

		if (params.isSchedulerUpdate) {
			return;
		}

		component.set('v.showModal', true);

		const inputVariables = [{
			name: 'isSchedule',
			type: 'Boolean',
			value: true
		}, {
			name: 'ids',
			type: 'String',
			value: [params.eventId]
		}, {
			name: 'InputQMRoom',
			type: 'SObject',
			value: {
				'thn__Resource__c': params.resourceId,
				'thn__Start_Date_Time__c': new Date(params.startDate).toISOString(),
				'thn__End_Date_Time__c': new Date(params.endDate).toISOString(),
				'thn__Update_Prices__c': true,
				'thn__Property__c': params.propertyId,
			}
		}];

		component.set('v.isCreate', params.isCreate);
		component.set('v.eventId', params.eventId);

		component.find('flowContainer').startFlow('thn__Change_Resource', inputVariables);
	},

	onFlowStatusChanged: function(component, event, helper) {
		const status = event.getParam('status');
		const output = event.getParam('outputVariables');

		if (status === 'FINISHED' || status === 'FINISHED_SCREEN' || status === 'ERROR') {
			if (component.get('v.isCreate')) {
				let deleteEvent = false;

				for (let i = 0; i < output.length; i++) {
					if (output[i].name === 'ErrorMessages') {
						if (output[i].value) {
							deleteEvent = true;
						}
					}
				}

				if (deleteEvent) {
					const action = component.get('c.deleteEvent');

					action.setParams({
						eventId: component.get('v.eventId')
					});

					action.setCallback(this, function(response) {
						if (response.getState() === 'SUCCESS') {
							component.set('v.showModal', false);

							component.find('messageServiceContainer').publish({
								isSchedulerUpdate: true
							});
						} else {
							console.error(response.getError()[0].message);
						}
					});

					$A.enqueueAction(action);
				} else {
					component.set('v.showModal', false);

					component.find('messageServiceContainer').publish({
						isSchedulerUpdate: true
					});
				}
			} else {
				component.set('v.showModal', false);

				component.find('messageServiceContainer').publish({
					isSchedulerUpdate: true
				});
			}
		}
	}
});