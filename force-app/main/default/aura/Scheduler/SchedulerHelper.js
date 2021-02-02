({
	/**
	 * The main method returns the data from the component controller
	 * @param component
	 * @param event
	 * @param helper
	 * @returns {Promise<Object>}
	 */
	getData: function(component, event, helper) {
		return new Promise($A.getCallback((resolve, reject) => {
			try {
				const action = component.get('c.getData');

				const currentViewType = component.get('v.viewType');
				let currentDate = new Date(component.get('v.currentDate'));

				if (currentViewType === 'week') {
					currentDate.setDate(currentDate.getDate() - currentDate.getDay() + (currentDate.getDay() === 0 ? -6 : 1));
				} else if (currentViewType === 'month') {
					currentDate = new Date(currentDate.getFullYear(), currentDate.getMonth(), 1);
					currentDate.setHours(Math.abs(new Date().getTimezoneOffset()) / 60);
				}

				action.setParams({
					currentDate: currentDate.toISOString(),
					viewType: component.get('v.viewType'),
					fieldMappingMetadataId: component.get('v.fieldMappingMetadataId'),
					customFilter: component.get('v.customResourceFilter'),
					customEventFilter: component.get('v.customEventFilter'),
					hotels: component.get('v.selectedHotels'),
					types: component.get('v.selectedTypes')
				});

				action.setCallback(this, function(response) {
					if (response.getState() === 'SUCCESS') {
						resolve(response.getReturnValue());
					} else {
						reject(response.getError()[0].message);
					}
				});

				$A.enqueueAction(action);
			} catch (e) {
                console.error(e);
				reject(e);
			}
		}));
	},

	/**
	 * Parse a response from the controller to fill in the attributes on the component and move the data from Apex type to better looking in JS
	 * @param component
	 * @param event
	 * @param helper
	 * @param result
	 */
	parseDataResponse: function(component, event, helper, result) {
		result.allResources.map(resource => {
			if (result.resources[resource.Id]) {
				result.resources[resource.Id].isVisible = true;
			} else {
				result.resources[resource.Id] = resource;
				result.resources[resource.Id].isVisible = false;
			}
		});

		Object.keys(result.mapping).map(mappingKey => {
			let array = null;

			if (mappingKey.toLowerCase().startsWith('thn__event')) {
				array = result.events;
			} else if (mappingKey.toLowerCase().startsWith('thn__resource')) {
				array = result.resources;
			}

			if (!array || typeof result.mapping[mappingKey] !== 'string' || !result.mapping[mappingKey].toLowerCase().includes('__r')) {
				return;
			}

			Object.values(array).map(item => {
				let currentObject = item;

				result.mapping[mappingKey].split('.').map(pathPart => {
					if (!currentObject) {
						return;
					}

					currentObject = currentObject[pathPart];
				});

				array[item.Id][result.mapping[mappingKey]] = currentObject;
			});
		});

		component.set('v.data', result);

		const eventsWithoutResource = [];
		// const scale = component.get('v.scale');
		const mapping = result.mapping;

		Object.keys(mapping).map(key => {
			if (!key.startsWith('thn__')) {
				mapping['thn__' + key] = mapping[key];
			}
		});

		let resources = Object.assign({}, result.resources);
		let currentDate = new Date(component.get('v.currentDate'));
		const currentViewType = component.get('v.viewType');
		const events = [];

		if (!mapping.thn__Resource_Order_Rule__c) {
			mapping.thn__Resource_Order_Rule__c = 'Name ASC';
		} else {
			mapping.thn__Resource_Order_Rule__c = mapping.thn__Resource_Order_Rule__c.replace(/\s+/, ' ');
		}

		if (currentViewType === 'week') {
			currentDate.setDate(currentDate.getDate() - currentDate.getDay() + (currentDate.getDay() === 0 ? -6 : 1));
		} else if (currentViewType === 'month') {
			currentDate = new Date(currentDate.getFullYear(), currentDate.getMonth(), 1);
			currentDate.setHours(Math.abs(new Date().getTimezoneOffset()) / 60);
		}

		currentDate = currentDate.getTime();

		// Parse and convert to more pretty JS objects - events
		Object.keys(result.events).map(eventKey => {
			const eventItem = result.events[eventKey];

			eventItem.name = eventItem[mapping.thn__Event_Name_API_Field__c];
			eventItem.iconCls = eventItem[mapping.thn__Event_Icon_API_Field__c] || mapping.thn__Event_Icon__c;

			eventItem.startDate = new Date(eventItem[mapping.thn__Event_Start_Date_API_Field__c]);
			eventItem.endDate = new Date(eventItem[mapping.thn__Event_End_Date_API_Field__c]);

			eventItem.startDate.setHours(eventItem.startDate.getHours() + result.timezoneOffset + new Date().getTimezoneOffset() / 60);
			eventItem.endDate.setHours(eventItem.endDate.getHours() + result.timezoneOffset + new Date().getTimezoneOffset() / 60);

			eventItem.startDate = eventItem.startDate.toJSON();
			eventItem.endDate = eventItem.endDate.toJSON();

			eventItem.draggable = true;
			eventItem.resizable = true;

			eventItem.eventColor = eventItem[mapping.thn__Event_Color_API_Field__c] || mapping.thn__Event_Color__c;

			if (resources[result.events[eventKey][mapping.thn__Event_Parent_Resource_API_Field__c]]) {
				if (!resources[result.events[eventKey][mapping.thn__Event_Parent_Resource_API_Field__c]].events) {
					resources[result.events[eventKey][mapping.thn__Event_Parent_Resource_API_Field__c]].events = {};
				}

				resources[result.events[eventKey][mapping.thn__Event_Parent_Resource_API_Field__c]].events[eventKey] = result.events[eventKey];
				eventItem.resourceId = resources[result.events[eventKey][mapping.thn__Event_Parent_Resource_API_Field__c]].Id;

				events.push(eventItem);
			} else {
				eventItem.cls = 'event-column';

				events.push(eventItem);
				eventsWithoutResource.push(eventItem);
			}
		});

		let resourceTimeRanges = [];
		for (let resourceTimeRange of result.resourceTimeRanges){
			resourceTimeRange.startDate = new Date(resourceTimeRange['startDate']);
			resourceTimeRange.endDate = new Date(resourceTimeRange['endDate']);

			resourceTimeRange.startDate.setHours(resourceTimeRange.startDate.getHours() + result.timezoneOffset + new Date().getTimezoneOffset() / 60);
			resourceTimeRange.endDate.setHours(resourceTimeRange.endDate.getHours() + result.timezoneOffset + new Date().getTimezoneOffset() / 60);

			resourceTimeRange.startDate = resourceTimeRange.startDate.toJSON();
			resourceTimeRange.endDate = resourceTimeRange.endDate.toJSON();

			resourceTimeRanges.push(resourceTimeRange)
		}

		// Parse and convert to more pretty JS objects - resources
		Object.keys(resources).map(resourceKey => {
			const resource = result.resources[resourceKey];

			resource.Name = resource[mapping.thn__Resource_Name_API_Field__c];
			resource.Icon = resource[mapping.thn__Resource_Icon_API_Field__c] || mapping.thn__Resource_Icon__c;
			resource.iconCls = resource.Icon;
			resource.id = resource.Id;

			if (resource[mapping.thn__Resource_Parent_Resource_API_Field__c]) {
				let parentId = resource[mapping.thn__Resource_Parent_Resource_API_Field__c];

				while (!resources[parentId].isVisible) {
					if (!resources[parentId][mapping.thn__Resource_Parent_Resource_API_Field__c] && !resources[parentId].isVisible) {
						delete resource[mapping.thn__Resource_Parent_Resource_API_Field__c];
						return;
					}

					parentId = resources[parentId][mapping.thn__Resource_Parent_Resource_API_Field__c];
				}

				if (!resources[parentId].children) {
					resources[parentId].children = {};
				}

				if (resource.isVisible) {
					resources[parentId].children[resource.Id] = resource;
				}
			}
		});

		Object.keys(resources).map(resourceKey => {
			const resource = result.resources[resourceKey];

			if (resource.children && !Object.keys(resource.children).length) {
				delete resource.children;
			}

			if (resource[mapping.thn__Resource_Parent_Resource_API_Field__c] || !resource.isVisible) {
				delete resources[resource.Id];
			}
		});

		const convertToArray = (obj, deepIndex) => {
			deepIndex = deepIndex || 0;

			obj.map(item => {
				delete item.attributes;

				item.deepIndex = deepIndex;

				if (item.children && typeof item.children === 'object') {
					item.children = Object.values(item.children);

					item.children.sort((a, b) => {
						const field = mapping.thn__Resource_Order_Rule__c.split(' ')[0];
						const direction = mapping.thn__Resource_Order_Rule__c.split(' ')[1];

						let aValue = a[field] || {};
						let bValue = b[field] || {};

						if (aValue.toLowerCase) {
							aValue = aValue.toLowerCase();
						}

						if (bValue.toLowerCase) {
							bValue = bValue.toLowerCase();
						}

						let result = 0;

						if (aValue > bValue) {
							result = 1;
						} else if (aValue < bValue) {
							result = -1;
						}

						if (direction.toLowerCase() !== 'asc'){
							result *= -1;
						}

						return result;
					});

					convertToArray(item.children, deepIndex + 1);
				}

				if (item.events && typeof item.events === 'object') {
					item.events = Object.values(item.events);

					const checkLineAvailability = (eventItem) => {
						let eventAdded = false;

						item.events.map(line => {
							if (eventAdded) {
								return;
							}

							if (!line.length) {
								line.push(eventItem);
								eventAdded = true;
								return;
							}

							let addToCurrentLine = true;

							line.map(lineEvent => {
								if (!(lineEvent.visualStartPosition >= eventItem.visualStartPosition + eventItem.visualWidth ||
									lineEvent.visualStartPosition + lineEvent.visualWidth <= eventItem.visualStartPosition)) {
									addToCurrentLine = false;
								}
							});

							if (addToCurrentLine) {
								line.push(eventItem);
								eventAdded = true;
							}
						});

						if (!eventAdded) {
							item.events.push([eventItem]);
						}
					};

					const events = [...item.events];
					item.events = [[]];

					events.map(checkLineAvailability);

					convertToArray(item.events);
				}
			})
		};

		resources = Object.values(resources);

		resources.sort((a, b) => {
			const field = mapping.thn__Resource_Order_Rule__c.split(' ')[0];
			const direction = mapping.thn__Resource_Order_Rule__c.split(' ')[1];

			let aValue = a[field];
			let bValue = b[field];

			if (aValue.toLowerCase) {
				aValue = aValue.toLowerCase();
			}

			if (bValue.toLowerCase) {
				bValue = bValue.toLowerCase();
			}

			let result = 0;

			if (aValue > bValue) {
				result = 1;
			} else if (aValue < bValue) {
				result = -1;
			}

			if (direction.toLowerCase() !== 'asc'){
				result *= -1;
			}

			return result;
		});

		convertToArray(resources);

		eventsWithoutResource.map(event => {
			event.resourceId = resources[0].id
		});

		mapping.thn__Event_Edit_Mode_Fields__c = mapping.thn__Event_Edit_Mode_Fields__c.split(',');
		for (let i = 0; i < mapping.thn__Event_Edit_Mode_Fields__c.length; i++) {
			mapping.thn__Event_Edit_Mode_Fields__c[i] = mapping.thn__Event_Edit_Mode_Fields__c[i].trim();
		}

		result.resourceDisplayColumns.map(column => {
			column.sortable = false;
			column.width = parseInt(localStorage.getItem('columnWidth'))
		});

		component.set('v.resourceTimeRanges', result.resourceTimeRanges);
		component.set('v.schedulerMapping', mapping);
		component.set('v.resourceDisplayColumns', result.resourceDisplayColumns);
		component.set('v.schedulerData', resources);
		component.set('v.events', events);
		component.set('v.eventTooltipFields', result.eventTooltipFields);
	},

	/**
	 * Method to change the view type and recalculate the current date based on the changed view type
	 * @param component
	 * @param event
	 * @param helper
	 */
	setViewTypeSettings: function(component, event, helper) {
		const currentViewType = component.get('v.viewType');
		let currentDate = new Date(component.get('v.currentDate'));

		if (currentViewType === 'week') {
			currentDate.setDate(currentDate.getDate() - currentDate.getDay() + (currentDate.getDay() === 0 ? -6 : 1));
		} else if (currentViewType === 'month') {
			currentDate = new Date(currentDate.getFullYear(), currentDate.getMonth(), 1);
			currentDate.setHours(Math.abs(new Date().getTimezoneOffset()) / 60);
		}

		$A.enqueueAction(component.get('c.updateData'));
	}
});