({
    closeEventCreateModal: function (component, event, helper) {
        component.set('v.selectedEventId', null);
        component.set('v.newEventParentResource', null);
        component.set('v.eventCreateModalVisible', false);
    },
    onRecordSubmit: function (component, event, helper) {
        event.preventDefault();
        let newEvent = JSON.parse(JSON.stringify(event.getParam("fields")));

        newEvent[component.get('v.schedulerMapping').thn__Event_Start_Date_API_Field__c] = newEvent[component.get('v.schedulerMapping').thn__Event_Start_Date_API_Field__c].replace('T', ' ');
        newEvent[component.get('v.schedulerMapping').thn__Event_End_Date_API_Field__c] = newEvent[component.get('v.schedulerMapping').thn__Event_End_Date_API_Field__c].replace('T', ' ');
        helper.saveNewEvent(component, newEvent);
    },

    onFormSubmitSuccess: function (component, event, helper) {
        $A.enqueueAction(component.get('v.updateData'));

        component.set('v.selectedEventId', null);
        component.set('v.newEventParentResource', null);
        component.set('v.eventCreateModalVisible', false);
    },

    onFormSubmitError: function (component, event, helper) {
        let message = '';

        try {
            message = event.getParams().output.errors[0].message;
        } catch (e) {
            console.error(e);

            message = event.getParams().message;
        }

        const toastEvent = $A.get('e.force:showToast');
        toastEvent.setParams({
            title: 'Error!',
            message: message,
            type: 'error'
        });
        toastEvent.fire();
    }
});