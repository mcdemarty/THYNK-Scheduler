(() => {
	let isTechnicalCollapse = false;

	const sendMessage = (message) => {
		LCC.onlineSupport.sendMessage('containerUserMessage', message);
	};

	LCC.onlineSupport.addMessageHandler(message => {
		document.querySelectorAll('.b-popup').forEach(el => {el.remove()});
		const actions = {
			'init': (payload) => {
				document.addEventListener('click', (e) => {
					if (e.target.tagName === 'BUTTON') {
						sendMessage({
							name: 'navigation',
							href: e.target.parentNode.getAttribute('href')
						})

						e.preventDefault();
						e.stopPropagation();
						return false;
					}
				});

				const DH = bryntum.scheduler.DateHelper;

				payload.endDate = DH.add(payload.currentDate, 1, payload.viewType.substring(0, 1) === 'm' ? 'M' : payload.viewType.substring(0, 1));

				if (payload.viewType === 'month') {
					payload.endDate = DH.add(payload.endDate, -1, 'd');
				} else {
					if (payload.viewType === 'week') {
						payload.currentDate = DH.add(payload.currentDate, -Math.abs(new Date().getTimezoneOffset()) / 60, 'h');
					}
					
					payload.endDate = DH.add(payload.endDate, -Math.abs(new Date().getTimezoneOffset()) / 60, 'h');
				}

				if (window.viewParamsUpdateInterval) {
					clearInterval(window.viewParamsUpdateInterval);
				}

				bryntum.scheduler.DomHelper.supportsTemplate = false;

				document.body.innerHTML = '';
				document.querySelector('.b-float-root') ? document.querySelector('.b-float-root').remove() : null;

				const collapsedResources = [];
				const collapsedNodes = JSON.parse(localStorage.getItem('collapsedResources')) || [];

				if (window.scheduler && window.scheduler.resourceStore.rootNode) {
					window.scheduler.resourceStore.rootNode.allChildren.map(item => {
						if (collapsedNodes.includes(item.Id)) {
							collapsedResources.push(false);
						} else {
							collapsedResources.push(item.isExpanded(window.scheduler.resourceStore));
						}
					});
				}

				payload.columns.map(column => {
					column.width = parseInt(localStorage.getItem('columnWidth'));
				});

				isTechnicalCollapse = true;

				window.scheduler = new bryntum.scheduler.Scheduler({
					appendTo: document.body,
					minHeight: 'calc(100% - 10px)',

					startDate: payload.currentDate,
					endDate: payload.endDate,

					viewPreset: payload.viewPreset,

					features: {
						tree: true,
						eventContextMenu: false,
						eventDragCreate: false,
						contextMenu: false,
						resourceTimeRanges : true,

						scheduleContextMenu: {
							items: {
								extraItem: {
									text: 'Add event',
									icon: 'b-fa b-fa-fw b-fa-plus',
									onItem: ({date, resourceRecord, items}) => {
										(document.querySelector('.b-menu-content') || {remove: () => {}}).remove();

										sendMessage({
											name: 'addEventContextMenuClick',
											data: {
												date: date,
												resourceRecord: resourceRecord,
												items: items
											}
										});
									}
								},
								addEvent: false
							}
						},
						eventTooltip: {
							template: data => {
								const getField = field => {
									let obj = data.eventRecord;
									let path = field.split('.');

									path.map(pathItem => {
										if (!obj) {
											return;
										}

										obj = obj[pathItem];
									});

									if (!obj) {
										return '';
									}

									if (field.toLowerCase().includes('date') || field.toLowerCase().includes('time')) {
										return new Date(obj).toLocaleString();
									}

									return obj;
								};

								let html = '';

								payload.eventTooltipFields.map(field => {
									html += `<div>${getField(field)}</div>`;
								});

								html += `<div style="margin-top: 0.5rem;"><a href="/${data.eventRecord.Id}" target="_top"><button class="slds-button">Open Event</button></a></div>`;

								return html;
							}
						}
					},

					readOnly: false,
					createEventOnDblClick: false,
					enableEventAnimations: false,

					columns: payload.columns,
					resourceStore: {
						fields: payload.resourceStore.fields,
						data: payload.resourceStore.data
					},
                    
					events: payload.events,
					resourceTimeRanges: payload.resourceTimeRanges,
					listeners: {
						eventClick: (e) => {
						document.querySelectorAll('.b-popup').forEach(el => {el.remove()});
							sendMessage({
								name: 'schedulerListenerEventClick',
								data: {
									eventId: e.eventRecord.Id,
									eventResourceId: e.eventRecord.resourceId
								}
							});
						},

						cellDblClick: (e) => {
						document.querySelectorAll('.b-popup').forEach(el => {el.remove()});
							sendMessage({
								name: 'schedulerListenerCellDblClick',
								data: e.record
							});
						},

						eventDrop: (e) => {
						document.querySelectorAll('.b-popup').forEach(el => {el.remove()});
							e.targetResourceRecord = Object.assign({}, e.targetResourceRecord);
							e.eventRecords[0] = Object.assign({
								Id: e.eventRecords[0].Id
							}, e.eventRecords[0]);
							
							sendMessage({
								name: 'schedulerListenerEventDrop',
								data: {
									targetResourceRecord: e.targetResourceRecord,
									eventRecords: e.eventRecords
								}
							});
						},

						eventResizeEnd: (e) => {
						document.querySelectorAll('.b-popup').forEach(el => {el.remove()});
							sendMessage({
								name: 'schedulerListenerEventResizeEnd',
								data: e.eventRecord
							})
						},

						collapseNode: (e) => {
						document.querySelectorAll('.b-popup').forEach(el => {el.remove()});
							if (isTechnicalCollapse) {
								return;
							}

							const nodes = JSON.parse(localStorage.getItem('collapsedResources')) || [];
							nodes.push(e.record.Id);
							localStorage.setItem('collapsedResources', JSON.stringify(nodes));
						},

						expandNode: (e) => {
						document.querySelectorAll('.b-popup').forEach(el => {el.remove()});
							if (isTechnicalCollapse) {
								return;
							}

							const nodes = JSON.parse(localStorage.getItem('collapsedResources')) || [];

							if (nodes.includes(e.record.Id)) {
								nodes.splice(nodes.indexOf(e.record.Id), 1);
							}

							localStorage.setItem('collapsedResources', JSON.stringify(nodes));
						}
					}
				});

				window.scheduler.rowHeight = parseInt(new URL(window.location).searchParams.get('rowHeight'));

				window.scheduler.collapseAll();
				window.scheduler.expandAll();

				for (let i = 0; i < collapsedResources.length; i++) {
					if (!collapsedResources[i]) {
						window.scheduler.collapse(scheduler.resourceStore.rootNode.allChildren[i]);
					}
				}

				clearInterval(window.columnEventInterval);

				window.columnEventInterval = setInterval(() => {
					Array.from(document.querySelectorAll('.event-column')).map(event => {
						event.parentNode.classList.add('event-column-container');
					});
				}, 100);

				setTimeout(() => {
					(document.querySelector('.b-grid-body-container') || {scroll: () => {}}).scroll(0, parseInt(localStorage.getItem('scrollTop')));
					(document.querySelector('.b-grid-subgrid:last-of-type') || {scroll: () => {}}).scroll(parseInt(localStorage.getItem('scrollLeft')), 0);

					window.viewParamsUpdateInterval = setInterval(() => {
						if (document.querySelector('.b-grid-subgrid:first-of-type')) {
							localStorage.setItem('columnWidth', document.querySelector('.b-grid-subgrid:first-of-type').offsetWidth);
						}
					}, 250);
				}, 0);

				document.querySelector('.b-grid-body-container').onscroll = () => {
					localStorage.setItem('scrollTop', (document.querySelector('.b-grid-body-container') || {}).scrollTop);
				};

				document.querySelector('.b-grid-subgrid:last-of-type').onscroll = () => {
					localStorage.setItem('scrollLeft', (document.querySelector('.b-grid-subgrid:last-of-type') || {}).scrollLeft);
				};

				setTimeout(() => {
					isTechnicalCollapse = false;
				}, 0);
			},
			'expandAll': (payload) => {
				isTechnicalCollapse = true;

				window.scheduler.expandAll();

				setTimeout(() => {
					isTechnicalCollapse = false;
				}, 0);
			},
			'collapseAll': (payload) => {
				isTechnicalCollapse = true;

				window.scheduler.collapseAll();

				setTimeout(() => {
					isTechnicalCollapse = false;
				}, 0);
			}
		};

		(actions[message.name] || function() { console.error(`Scheduler action ${message.name} not found`) })(message.value);
	});
})();

window.addEventListener('load', () => {
	LCC.onlineSupport.sendMessage('containerUserMessage', 'schedulerInit');

	document.addEventListener('click', () => {
		(document.querySelector('.b-menu-content') || {remove: () => {}}).remove();
	});
});
