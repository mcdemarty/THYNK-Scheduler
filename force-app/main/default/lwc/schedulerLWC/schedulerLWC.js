import { LightningElement, api } from 'lwc';
import { loadScript, loadStyle } from "lightning/platformResourceLoader";
import { ShowToastEvent } from 'lightning/platformShowToastEvent'
import getSchedulerData from '@salesforce/apex/SchedulerControllerV2.getSchedulerData';
import saveEvent from '@salesforce/apex/SchedulerControllerV2.saveEvent';

import SCHEDULER from '@salesforce/resourceUrl/Scheduler';

export default class SchedulerLwc extends LightningElement {

	@api schedulerFieldsMetadataId;
	@api eventCustomFilter;
	@api resourceCustomFilter;
	@api resourceOrderRule;
	@api componentHeight;
	@api eventMargin;

	VIEW_PRESET = {
		DAY: 1,
		WEEK: 2,
		MONTH: 3,
		CUSTOM: 4
	};

	currentViewPreset = this.VIEW_PRESET.WEEK;

	scheduler;
	schedulerData;

	startDate;
	endDate;

	customStartDate;
	customEndDate;

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
				bryntum.scheduler.init(this.template);

				this.loadSchedulerState();

				this.initScheduler();
			})
			.catch(e => {
				console.error(e);
				this.errorMessage = e.message || e.body.message;
				this.showSpinner = false;
			})
	}

	// Init actions

	initScheduler() {
		this.showSpinner = true;

		const schedulerPreset = this.getCurrentPreset();

		this.startDate = new Date(schedulerPreset.startDate.getFullYear(), schedulerPreset.startDate.getMonth(), schedulerPreset.startDate.getDate(), 0, -new Date().getTimezoneOffset()).toISOString();
		this.endDate = new Date(schedulerPreset.endDate.getFullYear(), schedulerPreset.endDate.getMonth(), schedulerPreset.endDate.getDate(), 0, -new Date().getTimezoneOffset()).toISOString();

		this.customStartDate = schedulerPreset.startDate;
		this.customEndDate = schedulerPreset.endDate;

		getSchedulerData({
			fieldMappingMetadataId: this.schedulerFieldsMetadataId,
			startDate: schedulerPreset.startDate.toISOString(),
			endDate: schedulerPreset.endDate.toISOString(),
			eventCustomFilter: this.eventCustomFilter,
			resourceCustomFilter: this.resourceCustomFilter,
			resourceOrderRule: this.resourceOrderRule
		})
			.then(result => {
				const extensibleResult = JSON.parse(JSON.stringify(result));

				this.schedulerData = extensibleResult;

				this.removeEmptyChildrenArrays(extensibleResult.resources);

				const resourceStore = new bryntum.scheduler.ResourceStore({
					tree: true,
					data: this.collapseResourcesFromState(this.mergeResourceRecords(extensibleResult.resources))
				});

				const eventStore = new bryntum.scheduler.EventStore({
					data: this.mergeEventRecords(extensibleResult.events)
				});

				const columns = extensibleResult.resourceColumns;
				const columnsWidth = this.getSavedColumnsWidth();

				for (let i = 0; i < columnsWidth.length; i++) {
					columns[i].width = columnsWidth[i];
				}

				extensibleResult.resourceColumns[0].type = 'tree';

				let schedulerOptions = {
					appendTo: this.template.querySelector('.scheduler-container'),
					minHeight: this.componentHeight,
					enableEventAnimations: false,

					viewPreset : {},

					features: {
						tree: true,
						eventContextMenu: false,
						eventDragCreate: false,
						contextMenu: false,
						enableEventAnimations: false,

						eventTooltip: {
							template: (event) => {
								let template = '';

								this.schedulerData.eventTooltipFields.map(field => {
									template += `<div>${event.eventRecord[field]}</div>`;
								});

								return template;
							}
						}
					},

					columns: columns,

					barMargin: parseInt(this.eventMargin) || 0,

					resourceStore: resourceStore,
					eventStore: eventStore,

					listeners: {
						eventDrop: this.eventDropResizeHandler,
						eventResizeEnd: this.eventDropResizeHandler,
						collapseNode: this.eventCollapsedExpandedHandler,
						expandNode: this.eventCollapsedExpandedHandler,
						eventClick: this.eventClickHandler
					}
				}

				schedulerOptions = Object.assign(schedulerOptions, schedulerPreset);

				this.template.querySelector('.scheduler-container').innerHTML = '';
				this.template.querySelector('.b-float-root').innerHTML = '';

				this.scheduler = new bryntum.scheduler.Scheduler(schedulerOptions);

				this.scheduler.relatedComponent = this;

				this.showSpinner = false;
			})
			.catch(e => {
				console.error(e);
				this.errorMessage = e.message || e.body.message;
				this.showSpinner = false;
			});
	}

	saveSchedulerState() {
		const state = JSON.parse(window.localStorage.getItem(window.location + 'schedulerState')) || {};

		state.preset = this.currentViewPreset;
		state.collapsedResources = this.collapsedResources;

		window.localStorage.setItem(window.location + 'schedulerState', JSON.stringify(state));
	}

	loadSchedulerState() {
		const state = JSON.parse(window.localStorage.getItem(window.location + 'schedulerState')) || {
			collapsedResources: [],
			preset: this.VIEW_PRESET.WEEK
		};

		this.collapsedResources = state.collapsedResources;
		this.currentViewPreset = state.preset;
	}

	saveColumnsWidth() {
		if (!this.scheduler) {
			return;
		}

		const widths = [];
		const columns = Array.from(this.template.querySelectorAll('.b-grid-header')).slice(0, -1);

		for (let i = 0; i < columns.length; i++) {
			widths.push(columns[i].getBoundingClientRect().width);
		}

		window.localStorage.setItem(window.location + 'schedulerColumnsWidth', JSON.stringify(widths));

		console.log(widths);
	}

	getSavedColumnsWidth() {
		return JSON.parse(window.localStorage.getItem(window.location + 'schedulerColumnsWidth')) || [];
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

	collapseResourcesFromState(resources) {
		resources.map(resource => {
			if (this.collapsedResources.includes(resource.id)) {
				resource.expanded = false;
			}
		});

		return resources;
	}

	// Event Handlers

	expandAllClickHandler() {
		this.isManualCollapseExpand = true;

		this.scheduler.expandAll()
			.then(() => {
				this.isManualCollapseExpand = false;
			});

		console.log(this.scheduler);
		console.log(this.scheduler.columns);
	}

	collapseAllClickHandler() {
		this.isManualCollapseExpand = true;

		this.scheduler.collapseAll()
			.then(() => {
				this.isManualCollapseExpand = false;
			});
	}

	viewPresetPicklistChangeHandler(event) {
		this.currentViewPreset = parseInt(event.target.value);

		this.saveSchedulerState();
		this.initScheduler();
	}

	startDateInputChangeHandler(event) {
		this.currentViewPreset = this.VIEW_PRESET.CUSTOM;

		this.customStartDate = new Date(event.target.value);

		this.initScheduler();
	}

	endDateInputChangeHandler(event) {
		this.currentViewPreset = this.VIEW_PRESET.CUSTOM;

		this.customEndDate = new Date(event.target.value);

		this.initScheduler();
	}

	createEventClickHandler() {
		this.selectedEventId = null;

		this.template.querySelector('.scheduler-event-create-modal').showModal();
	}

	eventCreateHandler() {
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

		saveEvent({
			fieldMappingMetadataId: this.relatedComponent.schedulerFieldsMetadataId,
			eventJSON: JSON.stringify(changedEvent)
		})
			.then(() => {

			})
			.catch(e => {
				console.error(e);

				this.relatedComponent.showErrorToast(e.message || e.body.message);

				this.relatedComponent.initScheduler();
			});
	}

	eventCollapsedExpandedHandler(event) {
		if (this.relatedComponent.isManualCollapseExpand) {
			return;
		}

		if (event.type === 'collapsenode') {
			this.relatedComponent.collapsedResources.push(event.record.id);
		} else if (event.type === 'expandnode') {
			this.relatedComponent.collapsedResources.splice(this.relatedComponent.collapsedResources.indexOf(event.record.id), 1);
		}

		this.relatedComponent.saveSchedulerState.call(this.relatedComponent);
	}

	eventClickHandler(event) {
		this.relatedComponent.selectedEventId = event.eventRecord.id;
		this.relatedComponent.template.querySelector('.scheduler-event-create-modal').showModal();
	}

	showErrorToast(message) {
		this.dispatchEvent(new ShowToastEvent({
			title: 'Error',
			variant: 'error',
			message: message
		}));
	}

	get viewPresetPicklistValue() {
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

}