import { LightningElement, api } from 'lwc';
import { loadScript, loadStyle } from "lightning/platformResourceLoader";
import { ShowToastEvent } from 'lightning/platformShowToastEvent'
import { NavigationMixin } from 'lightning/navigation';
import getSchedulerData from '@salesforce/apex/SchedulerControllerV2.getSchedulerData';
import saveEvent from '@salesforce/apex/SchedulerControllerV2.saveEvent';

import SCHEDULER from '@salesforce/resourceUrl/Scheduler';

export default class SchedulerLwc extends NavigationMixin(LightningElement) {

	@api schedulerFieldsMetadataName;
	@api secondSchedulerFieldsMetadataName;
	@api eventCustomFilter;
	@api resourceCustomFilter;
	@api resourceOrderRule;
	@api componentHeight;
	@api eventMargin;
	@api eventLayoutType;
	@api enableColumnFiltering;
	@api responsiveType;
	@api showFieldNamesWhenHovered;
	@api columnsOnRight;

	// Style attributes

	@api headingFont;
	@api headingFontSize;
	@api headingFontColor;
	@api headingAlignment;

	@api resourceHeadingFont;
	@api resourceHeadingFontSize;
	@api resourceHeadingFontColor;
	@api resourceHeadingAlignment;

	VIEW_PRESET = {
		DAY: 1,
		WEEK: 2,
		MONTH: 3,
		CUSTOM: 4
	};

	currentViewPreset = this.VIEW_PRESET.WEEK;

	mainSchedulerData;

	schedulers = [];

	startDate;
	endDate;

	customStartDate;
	customEndDate;

	savedStartDate;
	savedEndDate;

	minSelectableEndDate;
	maxSelectableStartDate;

	savedResourceColumnsFilters;
	resourceColumnsFiltersChanged = false;

	collapsedResources;

	isManualCollapseExpand = false;

	showSpinner = false;

	selectedEventId;

	errorMessage;

	connectedCallback() {
		this.showSpinner = true;

		document.addEventListener('mouseup', () => {
			this.saveColumnsWidth();
		})

		Promise.all([
			loadScript(this, SCHEDULER + '/scheduler.lwc.module.js'),
			loadStyle(this, SCHEDULER + "/scheduler.stockholm.css")
		])
			.then(() => {
				setTimeout(() => {
					bryntum.schedulerpro.init(this.template.querySelector('.scheduler-init-container'));

					this.initializeCustomSchedulerStyle();

					this.loadSchedulerState();

					this.initScheduler();
				}, 0);
			})
			.catch(e => {
				console.error(e);
				this.errorMessage = e.message || e.body.message;
				this.showSpinner = false;
			})
	}

	// Init actions

	initScheduler(preserveDates) {
		this.showSpinner = true;

		const schedulerPreset = this.getCurrentPreset();

		if (preserveDates) {
			schedulerPreset.startDate = this.customStartDate;
			schedulerPreset.endDate = this.customEndDate;
		} else {
			if (this.savedStartDate && this.savedEndDate) {
				schedulerPreset.startDate = this.savedStartDate;
				schedulerPreset.endDate = this.savedEndDate;

				this.savedStartDate = null;
				this.savedEndDate = null;
			}
		}

		this.startDate = new Date(schedulerPreset.startDate.getFullYear(), schedulerPreset.startDate.getMonth(), schedulerPreset.startDate.getDate(), 0, -new Date().getTimezoneOffset()).toISOString();
		this.endDate = new Date(schedulerPreset.endDate.getFullYear(), schedulerPreset.endDate.getMonth(), schedulerPreset.endDate.getDate(), 0, -new Date().getTimezoneOffset()).toISOString();

		this.customStartDate = schedulerPreset.startDate;
		this.customEndDate = schedulerPreset.endDate;

		this.minSelectableEndDate = this.startDate;
		this.maxSelectableStartDate = this.endDate;

		this.saveSchedulerState();

		const getDataPromises = [
			getSchedulerData({
				fieldMappingMetadataName: this.schedulerFieldsMetadataName,
				startDate: schedulerPreset.startDate.toISOString(),
				endDate: schedulerPreset.endDate.toISOString(),
				eventCustomFilter: this.eventCustomFilter,
				resourceCustomFilter: this.resourceCustomFilter,
				resourceOrderRule: this.resourceOrderRule
			})
		];

		if (this.secondSchedulerFieldsMetadataName) {
			getDataPromises.push(getSchedulerData({
				fieldMappingMetadataName: this.secondSchedulerFieldsMetadataName,
				startDate: schedulerPreset.startDate.toISOString(),
				endDate: schedulerPreset.endDate.toISOString(),
				eventCustomFilter: this.eventCustomFilter,
				resourceCustomFilter: this.resourceCustomFilter,
				resourceOrderRule: this.resourceOrderRule
			}));
		}

		Promise.all(getDataPromises)
			.then(results => {
				if (this.template.querySelector('.scheduler-container')) {
					this.template.querySelector('.scheduler-container').innerHTML = '';
				}

				this.mainSchedulerData = JSON.parse(JSON.stringify(results[0]));

				for (let schedulerIndex = 0; schedulerIndex < results.length; schedulerIndex++) {
					const result = results[schedulerIndex];

					const extensibleResult = JSON.parse(JSON.stringify(result));

					this.removeEmptyChildrenArrays(extensibleResult.resources);

					const resourceStore = new bryntum.schedulerpro.ResourceStore({
						tree: true,
						data: this.collapseResourcesFromState(this.mergeResourceRecords(extensibleResult.resources), schedulerIndex)
					});

					const eventStore = new bryntum.schedulerpro.EventStore({
						data: this.mergeEventRecords(extensibleResult.events)
					});

					const maintenanceTimeRanges = extensibleResult.maintenanceTimeRanges;
					maintenanceTimeRanges.map(timeRange => {
						timeRange.style = 'background: repeating-linear-gradient(45deg, rgba(255, 255, 255, 0.2), rgba(255, 255, 255, 0.2) 10px, rgba(190, 190, 190, 0.2) 10px, rgba(190, 190, 190, 0.2) 20px) rgba(255, 255, 255, 0); color: #888;';
					});

					const columns = extensibleResult.resourceColumns;
					const columnsWidth = this.getSavedColumnsWidth(schedulerIndex);

					for (let i = 0; i < columns.length; i++) {
						columns[i].region = this.columnsOnRight ? 'right' : 'left';
					}

					for (let i = 0; i < columnsWidth.length; i++) {
						columns[i].width = columnsWidth[i];
					}

					extensibleResult.resourceColumns[0].type = 'tree';

					let filter = this.enableColumnFiltering || false;
					if (filter) {
						const filters = [];

						if (this.savedResourceColumnsFilters && this.savedResourceColumnsFilters[schedulerIndex]) {
							Object.keys(this.savedResourceColumnsFilters[schedulerIndex]).map(filterKey => {
								filters.push({
									property: this.savedResourceColumnsFilters[schedulerIndex][filterKey].property,
									value: this.savedResourceColumnsFilters[schedulerIndex][filterKey].value
								})
							});
						}

						filter = filters;
					}

					let schedulerOptions = {
						appendTo: this.template.querySelector('.scheduler-container'),

						minHeight: this.componentHeight,

						enableEventAnimations: false,
						createEventOnDblClick: false,

						viewPreset : {},

						eventLayout: this.eventLayoutType || 'stack',

						fillTicks: this.responsiveType === 'Small',

						features: {
							tree: true,
							eventDragCreate: false,
							contextMenu: false,
							enableEventAnimations: false,
							dependencies: false,
							resourceTimeRanges: true,
							timeRanges: true,
							filter: this.responsiveType !== 'Small' ? filter : false,
							stripe: true,
							// eventDrag: {
							// 	constrainDragToTimeline: true
							// },

							timeAxisHeaderMenu: {
								items: {
									eventsFilter: false
								}
							},

							eventMenu: {
								items: {
									deleteEvent: false,
									unassignEvent: false,

									extraItem: {
										text: 'Open Event',
										onItem: ({eventRecord}) => {
											window.open(window.location.origin + '/' + eventRecord.formulaId || eventRecord.id, '_blank');
										}
									}
								}
							},

							eventTooltip: {
								template: (event) => {
									let template = '';

									extensibleResult.eventTooltipFields.map(field => {
										let value = event.eventRecord[field];
										let currentObjectLevel = event.eventRecord;

										if (field.includes('.')) {
											const fieldParts = field.split('.');
											let i = 0;

											while (typeof currentObjectLevel === 'object' && currentObjectLevel != null) {
												currentObjectLevel = currentObjectLevel[fieldParts[i]];

												i++;
											}

											value = currentObjectLevel;
										}

										if (this.showFieldNamesWhenHovered) {
											value = extensibleResult.eventTooltipFieldsNames[field] + ': ' + value;
										}

										template += `<div>${value}</div>`;
									});

									return template;
								}
							}
						},

						columns: columns,

						barMargin: parseInt(this.eventMargin) || 0,

						resourceStore: resourceStore,
						eventStore: eventStore,
						resourceTimeRanges: [].concat(maintenanceTimeRanges),
						timeRanges: [].concat(extensibleResult.timeRanges),

						listeners: {
							eventDrop: this.eventDropResizeHandler,
							eventResizeEnd: this.eventDropResizeHandler,
							collapseNode: this.eventCollapsedExpandedHandler,
							expandNode: this.eventCollapsedExpandedHandler,
							eventClick: this.eventClickHandler,
							timeAxisChange: this.timeAxisChangeHandler
						}
					}

					schedulerOptions = Object.assign(schedulerOptions, schedulerPreset);

					const scheduler = new bryntum.schedulerpro.SchedulerPro(schedulerOptions);
					scheduler.relatedComponent = this;
					scheduler.schedulerIndex = schedulerIndex;

					if (this.enableColumnFiltering) {
						this.savedResourceColumnsFilters = this.savedResourceColumnsFilters || [];

						scheduler.store.on('filter', (event) => {
							this.resourceColumnsFiltersChanged = true;

							const allFilters = [];

							for (let i = 0; i < event.filters.allValues.length; i++) {
								const filter = event.filters.allValues[i];

								allFilters.push({
									property: filter.property,
									value: filter.value
								});
							}

							this.savedResourceColumnsFilters[schedulerIndex] = allFilters;
							this.saveSchedulerState();
						});
					}

					this.schedulers.push(scheduler);
				}

				setTimeout(() => {
					Array.from(this.template.querySelectorAll('.b-float-root')).map(root => {
						root.innerHTML = '';
					});
				}, 0);

				this.showSpinner = false;
			})
			.catch(e => {
				console.error(e);
				this.errorMessage = e.message || e.body.message;
				this.showSpinner = false;
			});
	}

	saveSchedulerState() {
		const state = JSON.parse(window.localStorage.getItem(window.location + '-SC')) || {};

		state.preset = this.currentViewPreset;
		state.collapsedResources = this.collapsedResources;
		state.startDate = new Date(this.customStartDate).toISOString();
		state.endDate = new Date(this.customEndDate).toISOString();
		state.resourceColumnsFilters = this.savedResourceColumnsFilters || [];

		window.localStorage.setItem(window.location + '-SC', JSON.stringify(state));
	}

	loadSchedulerState() {
		const state = JSON.parse(window.localStorage.getItem(window.location + '-SC')) || {
			collapsedResources: [],
			preset: this.VIEW_PRESET.WEEK
		};

		this.collapsedResources = state.collapsedResources;
		this.currentViewPreset = state.preset;
		this.savedResourceColumnsFilters = state.resourceColumnsFilters;

		if (state.startDate && state.endDate) {
			this.savedStartDate = new Date(state.startDate);
			this.savedEndDate = new Date(state.endDate);
		}
	}

	saveColumnsWidth() {
		if (!this.schedulers.length) {
			return;
		}

		const schedulersNodes = Array.from(this.template.querySelectorAll('.b-schedulerbase'));
		const widths = [];

		for (let i = 0; i < schedulersNodes.length; i++) {
			const instanceWidths = [];

			const columns = Array.from(schedulersNodes[i].querySelectorAll('.b-grid-header')).slice(0, -1);

			for (let i = 0; i < columns.length; i++) {
				instanceWidths.push(columns[i].getBoundingClientRect().width);
			}

			widths.push(instanceWidths);
		}

		window.localStorage.setItem(window.location + '-SCW', JSON.stringify(widths));
	}

	getSavedColumnsWidth(schedulerIndex) {
		return (JSON.parse(window.localStorage.getItem(window.location + '-SCW')) || [])[schedulerIndex] || [];
	}

	initializeCustomSchedulerStyle() {
		const customClassName = 'scheduler-' + Math.random().toString().substring(2);

		this.template.querySelector('.scheduler-init-container').classList.add(customClassName);

		const styleNode = document.createElement('style');

		styleNode.innerHTML = `.${customClassName} .b-grid-header-text-content {
			${this.headingFont ? 'font-family: ' + this.headingFont + ' !important;' : ''}
			${this.headingFontSize ? 'font-size: ' + this.headingFontSize + ' !important;' : ''}
			${this.headingFontColor ? 'color: ' + this.headingFontColor + ' !important;' : ''}
			${this.headingAlignment ? 'text-align: ' + this.headingAlignment + ' !important;' : ''}
		} `;

		const alignToFlex = {
			'Left': 'flex-start',
			'Center': 'center',
			'Right': 'flex-end'
		}

		styleNode.innerHTML += `.${customClassName} .b-tree-cell-value, .${customClassName} .b-grid-cell {
			${this.resourceHeadingFont ? 'font-family: ' + this.resourceHeadingFont + ' !important;' : ''}
			${this.resourceHeadingFontSize ? 'font-size: ' + this.resourceHeadingFontSize + ' !important;' : ''}
			${this.resourceHeadingFontColor ? 'color: ' + this.resourceHeadingFontColor + ' !important;' : ''}
			${this.resourceHeadingAlignment ? 'text-align: ' + this.resourceHeadingAlignment + ' !important;' : ''}
			${this.resourceHeadingAlignment ? 'justify-content: ' + alignToFlex[this.resourceHeadingAlignment] + ' !important;' : ''}
		} `;

		this.template.querySelector('.scheduler-init-container').appendChild(styleNode);
	}

	// Preset functions

	getCurrentPreset() {
		if (this.currentViewPreset === this.VIEW_PRESET.DAY) {
			return this.getCurrentDayPreset();
		} else if (this.currentViewPreset === this.VIEW_PRESET.WEEK) {
			return this.getCurrentWeekPreset();
		} else if (this.currentViewPreset === this.VIEW_PRESET.MONTH) {
			return this.getCurrentMonthPreset();
		} else if (this.currentViewPreset === this.VIEW_PRESET.CUSTOM) {
			return this.getCustomPreset();
		}
	}

	getCurrentDayPreset() {
		const startDate = new Date(new Date().getFullYear(), new Date().getMonth(), new Date().getDate());
		const endDate = new Date(new Date().getFullYear(), new Date().getMonth(), new Date().getDate());

		endDate.setDate(startDate.getDate() + 1);

		return {
			startDate: startDate,
			endDate: endDate,
			viewPreset: {
				base: 'hourAndDay',
				headers: [{
					unit: 'd',
					align: 'center',
					dateFormat: 'DD MMMM'
				}, {
					unit: 'h',
					align: 'center',
					dateFormat: 'HH:mm'
				}]
			}
		};
	}

	getCurrentWeekPreset() {
		const startDate = new Date();
		startDate.setDate(startDate.getDate() - startDate.getDay() + (startDate.getDay() === 0 ? -6 : 1));
		startDate.setHours(0, 0, 0);

		const endDate = new Date(startDate);
		endDate.setDate(startDate.getDate() + 7);
		endDate.setMinutes(-1);

		return {
			startDate: startDate,
			endDate: endDate,
			viewPreset: {
				base: 'dayAndWeek',
				headers: [{
					unit: 'd',
					align: 'center',
					dateFormat: 'DD MMMM'
				}]
			}
		};
	}

	getCurrentMonthPreset() {
		const startDate = new Date(new Date().getFullYear(), new Date().getMonth(), 1);
		const endDate = new Date(new Date().getFullYear(), new Date().getMonth() + 1, 1);

		return {
			startDate: startDate,
			endDate: endDate,
			viewPreset: {
				base: 'dayAndWeek',
				headers: [{
					unit: 'd',
					align: 'center',
					dateFormat: 'DD MMMM'
				}]
			}
		};
	}

	getCustomPreset() {
		const startDate = new Date(this.customStartDate);
		const endDate = new Date(this.customEndDate);

		return {
			startDate: startDate,
			endDate: endDate,
			viewPreset: {
				base: 'dayAndWeek',
				headers: [{
					unit: 'd',
					align: 'center',
					dateFormat: 'DD MMMM'
				}]
			}
		};
	}

	// Mutators

	removeEmptyChildrenArrays(tree) {
		const removeFromNode = (treeNode) => {
			treeNode.map(treeNodeItem => {
				if (treeNodeItem.children) {
					if (treeNodeItem.children.length) {
						removeFromNode(treeNodeItem.children);
					} else {
						delete treeNodeItem.children;
					}
				}
			});
		}

		removeFromNode(tree);
	}

	mergeResourceRecords(resources) {
		const executeMergeIteration = (resources) => {
			const result = [];

			resources.map(resource => {
				let newResource = Object.assign(resource, resource.resourceRecord);
				delete newResource.resourceRecord;

				if (newResource.children) {
					newResource.children = executeMergeIteration(newResource.children);
				}

				result.push(newResource);
			});

			return result;
		}

		return executeMergeIteration(resources);
	}

	mergeEventRecords(events) {
		const result = [];

		events.map(event => {
			let newEvent = Object.assign(event, event.eventRecord);
			delete newEvent.eventRecord;

			result.push(newEvent);
		});

		return result;
	}

	collapseResourcesFromState(resources, schedulerIndex) {
		const collapsedResources = this.collapsedResources[schedulerIndex];

		const collapseResource = (resource) => {
			if (collapsedResources && collapsedResources.includes(resource.id)) {
				resource.expanded = false;
			}

			if (resource.children) {
				resource.children.map(resourceChild => {
					collapseResource(resourceChild);
				});
			}
		}

		resources.map(resource => {
			collapseResource(resource);
		});

		return resources;
	}

	// Event Handlers

	expandAllClickHandler() {
		this.isManualCollapseExpand = true;

		this.schedulers.map(scheduler => {
			scheduler.expandAll()
				.then(() => {
					this.isManualCollapseExpand = false;
				});
		})
	}

	collapseAllClickHandler() {
		this.isManualCollapseExpand = true;

		this.schedulers.map(scheduler => {
			scheduler.collapseAll()
				.then(() => {
					this.isManualCollapseExpand = false;
				});
		})
	}

	viewPresetPicklistChangeHandler(event) {
		this.currentViewPreset = parseInt(event.target.value);

		this.initScheduler();
	}

	startDateInputChangeHandler(event) {
		if (!event.target.checkValidity()) {
			event.target.value = this.startDate;

			return;
		}

		this.currentViewPreset = this.VIEW_PRESET.CUSTOM;

		this.customStartDate = new Date(event.target.value);

		this.initScheduler();
	}

	endDateInputChangeHandler(event) {
		if (!event.target.checkValidity()) {
			event.target.value = this.endDate;

			return;
		}

		this.currentViewPreset = this.VIEW_PRESET.CUSTOM;

		this.customEndDate = new Date(event.target.value);

		this.initScheduler();
	}

	createEventClickHandler() {
		this.selectedEventId = null;

		this.template.querySelector('.scheduler-event-create-modal').showModal();
	}

	eventCreateHandler() {
		this.initScheduler(true);
	}

	moveToNextPeriodClickHandler() {
		this.savedStartDate = this.customStartDate;
		this.savedEndDate = this.customEndDate;

		if (this.currentViewPreset === this.VIEW_PRESET.DAY) {
			this.savedStartDate.setDate(this.savedStartDate.getDate() + 1);
			this.savedEndDate.setDate(this.savedEndDate.getDate() + 1);
		} else if (this.currentViewPreset === this.VIEW_PRESET.WEEK) {
			this.savedStartDate.setDate(this.savedStartDate.getDate() + 7);
			this.savedEndDate.setDate(this.savedEndDate.getDate() + 7);
		} else if (this.currentViewPreset === this.VIEW_PRESET.MONTH) {
			this.savedStartDate.setMonth(this.savedStartDate.getMonth() + 1);
			this.savedEndDate.setMonth(this.savedEndDate.getMonth() + 1);
		} else if (this.currentViewPreset === this.VIEW_PRESET.CUSTOM) {
			const difference = Math.trunc((this.savedEndDate - this.savedStartDate) / 1000 / 60 / 60 / 24);

			this.savedStartDate.setDate(this.savedStartDate.getDate() + difference);
			this.savedEndDate.setDate(this.savedEndDate.getDate() + difference);
		}

		this.initScheduler();
	}

	moveToPreviousPeriodClickHandler() {
		this.savedStartDate = this.customStartDate;
		this.savedEndDate = this.customEndDate;

		if (this.currentViewPreset === this.VIEW_PRESET.DAY) {
			this.savedStartDate.setDate(this.savedStartDate.getDate() - 1);
			this.savedEndDate.setDate(this.savedEndDate.getDate() - 1);
		} else if (this.currentViewPreset === this.VIEW_PRESET.WEEK) {
			this.savedStartDate.setDate(this.savedStartDate.getDate() - 7);
			this.savedEndDate.setDate(this.savedEndDate.getDate() - 7);
		} else if (this.currentViewPreset === this.VIEW_PRESET.MONTH) {
			this.savedStartDate.setMonth(this.savedStartDate.getMonth() - 1);
			this.savedEndDate.setMonth(this.savedEndDate.getMonth() - 1);
		} else if (this.currentViewPreset === this.VIEW_PRESET.CUSTOM) {
			const difference = Math.trunc((this.savedEndDate - this.savedStartDate) / 1000 / 60 / 60 / 24);

			this.savedStartDate.setDate(this.savedStartDate.getDate() - difference);
			this.savedEndDate.setDate(this.savedEndDate.getDate() - difference);
		}

		this.initScheduler();
	}

	// Scheduler Listeners

	eventDropResizeHandler(event) {
		let changedRecord;

		if (event.draggedRecords) {
			changedRecord = event.draggedRecords[0].data;
		} else if (event.eventRecord) {
			changedRecord = event.eventRecord.data;
		}

		const changedEvent = {
			id: changedRecord.id,
			startDate: changedRecord.startDate.toISOString(),
			endDate: changedRecord.endDate.toISOString(),
			resourceId: changedRecord.resourceId
		}

		const fieldMappingMetadataName = this.schedulerIndex === 0 ? this.relatedComponent.schedulerFieldsMetadataName : this.relatedComponent.secondSchedulerFieldsMetadataName;

		saveEvent({
			fieldMappingMetadataName: fieldMappingMetadataName,
			eventJSON: JSON.stringify(changedEvent)
		})
			.then(() => {

			})
			.catch(e => {
				console.error(e);

				this.relatedComponent.showErrorToast(e.message || e.body.message);

				this.relatedComponent.initScheduler(true);
			});
	}

	eventCollapsedExpandedHandler(event) {
		if (this.relatedComponent.isManualCollapseExpand) {
			return;
		}

		this.relatedComponent.collapsedResources[this.schedulerIndex] = this.relatedComponent.collapsedResources[this.schedulerIndex] || [];

		if (event.type === 'collapsenode') {
			this.relatedComponent.collapsedResources[this.schedulerIndex].push(event.record.id);
		} else if (event.type === 'expandnode') {
			this.relatedComponent.collapsedResources[this.schedulerIndex].splice(this.relatedComponent.collapsedResources.indexOf(event.record.id), 1);
		}

		this.relatedComponent.saveSchedulerState.call(this.relatedComponent);
	}

	eventClickHandler(event) {
		this.relatedComponent.selectedEventId = event.eventRecord.id;
		this.relatedComponent.template.querySelector('.scheduler-event-create-modal').showModal();
	}

	timeAxisChangeHandler(event) {
		this.relatedComponent.currentViewPreset = this.relatedComponent.VIEW_PRESET.CUSTOM;

		if (this.relatedComponent.updatePresetInterval) {
			clearInterval(this.relatedComponent.updatePresetInterval);
		}

		this.relatedComponent.updatePresetInterval = setInterval(() => {
			clearInterval(this.relatedComponent.updatePresetInterval);

			this.relatedComponent.customStartDate = event.config.startDate;
			this.relatedComponent.customEndDate = event.config.endDate;

			this.relatedComponent.initScheduler(true);
		}, 1000);
	}

	showErrorToast(message) {
		this.dispatchEvent(new ShowToastEvent({
			title: 'Error',
			variant: 'error',
			message: message
		}));
	}

	get viewPresetPicklistValue() {
		if (!this.currentViewPreset) {
			return this.VIEW_PRESET.WEEK.toString();
		}

		return this.currentViewPreset.toString();
	}

	get viewPresetPicklistOptions() {
		return [{
			label: 'Day',
			value: this.VIEW_PRESET.DAY.toString()
		}, {
			label: 'Week',
			value: this.VIEW_PRESET.WEEK.toString()
		}, {
			label: 'Month',
			value: this.VIEW_PRESET.MONTH.toString()
		}, {
			label: 'Custom',
			value: this.VIEW_PRESET.CUSTOM.toString()
		}]
	}

	get renderCreateEventModal() {
		return this.schedulers && this.schedulers.length > 0;
	}

}