({
	doInit: function (component, event, helper) {
		helper.selectOptionHelper(component, 'Item 1', 'true');
	},

	openDropdown: function (component, event, helper) {
		$A.util.addClass(component.find('dropdown'), 'slds-is-open');
		$A.util.removeClass(component.find('dropdown'), 'slds-is-close');
	},

	closeDropDown: function (component, event, helper) {
		$A.util.addClass(component.find('dropdown'), 'slds-is-close');
		$A.util.removeClass(component.find('dropdown'), 'slds-is-open');
	},

	selectOption: function (component, event, helper) {
		let label = event.currentTarget.id.split('#BP#')[0];
		let isCheck = event.currentTarget.id.split('#BP#')[1];
		helper.selectOptionHelper(component, label, isCheck);

		if (component.get('v.onSelect')) {
			$A.enqueueAction(component.get('v.onSelect'));
		}
	}
});