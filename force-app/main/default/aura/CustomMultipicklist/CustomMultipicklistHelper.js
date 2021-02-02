({
	selectOptionHelper: function (component, label, isCheck) {
		if (!component.get('v.options')) {
			return;
		}

		let selectedOption = '';
		let selectedOptions = [];
		let showedText = '';
		let allOptions = component.get('v.options');
		let count = 0;
		for (let i = 0; i < allOptions.length; i++) {
			if (allOptions[i].value === label) {
				if (isCheck === 'true') {
					allOptions[i].isChecked = false;
				} else {
					allOptions[i].isChecked = true;
				}
			}
			if (allOptions[i].isChecked) {
				showedText = allOptions[i].label;
				count++;

				selectedOptions.push(allOptions[i].value);
			}
		}
		if (count > 1) {
			showedText = count + ' items selected';
		}
		component.set('v.showedText', showedText);
		component.set('v.selectedOptions', selectedOptions);
		component.set('v.options', allOptions);
	}
});