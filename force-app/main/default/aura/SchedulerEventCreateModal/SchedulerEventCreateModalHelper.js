({
	saveNewEvent: function (component, eventFields) {
		const action = component.get('c.checkResourceBookable');
		let resourceId = component.get('v.data').resources[component.get('v.newEventParentResource')];
		let endTime = eventFields[component.get('v.schedulerMapping').Event_End_Date_API_Field__c].toString();
		let startTime = eventFields[component.get('v.schedulerMapping').Event_Start_Date_API_Field__c].toString();

		console.log(eventFields);
		if (resourceId){
			resourceId = resourceId.Id;
		}
		action.setParams({
			endTime: endTime,
			startTime: startTime,
			resourceId: resourceId,
			fieldMappingMetadataId: component.get('v.schedulerMapping').Id
		});

		action.setCallback(this, function (response) {
			if (response.getState() === 'SUCCESS') {
				if (response.getReturnValue()) {
					const toastEvent = $A.get('e.force:showToast');
					toastEvent.setParams({
						title: 'Error!',
						message: response.getReturnValue(),
						type: 'error'
					});
					toastEvent.fire();

					return;
				}

				try {
					if (!component.get('v.data').resources[component.get('v.newEventParentResource')][component.get('v.schedulerMapping').Resource_Bookable_API_Field__c]) {
						const toastEvent = $A.get('e.force:showToast');
						toastEvent.setParams({
							title: 'Error!',
							message: 'This resource isn\'t bookable',
							type: 'error'
						});
						toastEvent.fire();

						return;
					}
				} catch (e) {

				}

				component.find('newEventForm').submit();
			} else {
				const toastEvent = $A.get('e.force:showToast');
				toastEvent.setParams({
					title: 'Error!',
					message: response.getError()[0].message,
					type: 'error'
				});
				toastEvent.fire();

				console.error(response.getError())
			}
		});

		$A.enqueueAction(action);

	}
});