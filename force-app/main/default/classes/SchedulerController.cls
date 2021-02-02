/**
* Controller for the Scheduler component which returns the dynamic field mapping, resources and events
*/
public with sharing class SchedulerController {

	@AuraEnabled
	public static String getPicklistData(String fieldMappingMetadataId) {
		SchedulerMappingException schedulerMappingException = new SchedulerMappingException();

		if (!Scheduler_Fields__mdt.getSObjectType().getDescribe().isAccessible()) {
			schedulerMappingException.setMessage('No read access for Scheduler_Fields__mdt object');
			throw schedulerMappingException;
		}

		for (String field : new Set<String> {'Id', 'Resource_API_Name__c', 'Resource_Parent_Resource_API_Field__c', 'Event_API_Name__c', 'Event_Parent_Resource_API_Field__c', 'Resource_Name_API_Field__c', 'Event_Start_Date_API_Field__c', 'Event_End_Date_API_Field__c', 'Event_Name_API_Field__c', 'Event_Color__c', 'Event_Icon__c', 'Resource_Icon__c', 'Event_Icon_API_Field__c', 'Resource_Icon_API_Field__c', 'Resource_Display_Columns_API_Fields__c', 'Event_Edit_Mode_Fields__c', 'Resource_Bookable_API_Field__c', 'Event_Color_API_Field__c', 'Resource_Order_Rule__c', 'Event_Tooltip_Fields__c'}) {
			if (!Scheduler_Fields__mdt.getSObjectType().getDescribe().fields.getMap().get(field).getDescribe().isAccessible()) {
				schedulerMappingException.setMessage('No read access for ' + field + ' field on Scheduler_Fields__mdt object');
				throw schedulerMappingException;
			}
		}

		if (String.isEmpty(fieldMappingMetadataId)) {
			fieldMappingMetadataId = [
				SELECT Id
				FROM Scheduler_Fields__mdt
				WHERE DeveloperName = 'Default'
			].Id;
		}

		Scheduler_Fields__mdt schedulerFields = [
			SELECT Id, Resource_API_Name__c, Resource_Parent_Resource_API_Field__c, Event_API_Name__c, Event_Parent_Resource_API_Field__c,
				Resource_Name_API_Field__c, Event_Start_Date_API_Field__c, Event_End_Date_API_Field__c, Event_Name_API_Field__c, Event_Color__c, Event_Icon__c,
				Resource_Icon__c, Event_Icon_API_Field__c, Resource_Icon_API_Field__c, Resource_Display_Columns_API_Fields__c, Event_Edit_Mode_Fields__c,
				Resource_Bookable_API_Field__c, Event_Color_API_Field__c, Resource_Order_Rule__c, Event_Tooltip_Fields__c, Resource_Hotel_API_Name__c,
				Hotel_API_Name__c, Resource_Type_API_Name__c
			FROM Scheduler_Fields__mdt
			WHERE Id = :fieldMappingMetadataId
		];

		List<Map<String, String>> types = new List<Map<String, String>>();

		for (PicklistEntry picklistEntry : Schema.getGlobalDescribe().get(schedulerFields.Resource_API_Name__c).getDescribe().fields.getMap().get(schedulerFields.Resource_Type_API_Name__c).getDescribe().getPicklistValues()) {
			types.add(new Map<String, String> {
				'label' => picklistEntry.getLabel(),
				'value' => picklistEntry.getValue()
			});
		}

		Map<String, Object> result = new Map<String, Object> {
			'hotels' => Database.query('SELECT Id, Name FROM ' + schedulerFields.Hotel_API_Name__c + ' ORDER BY Name ASC'),
			'types' => types
		};

		return JSON.serialize(result);
	}

	/**
	* Returns the JSON string which contains dynamic field mapping, events for the provided dates and all resources
	*
	* @param {Datetime} currentDate
	* @param {String} viewType
	* @param {Id} fieldMappingMetadataId
	*
	* @return {String} JSON string with events, resources and mapping
	*/
	@AuraEnabled
	public static String getData(Datetime currentDate, String viewType, String fieldMappingMetadataId, String customFilter, String customEventFilter, List<Id> hotels, List<String> types) {
		SchedulerMappingException schedulerMappingException = new SchedulerMappingException();

		if (!Scheduler_Fields__mdt.getSObjectType().getDescribe().isAccessible()) {
			schedulerMappingException.setMessage('No read access for Scheduler_Fields__mdt object');
			throw schedulerMappingException;
		}

		for (String field : new Set<String> {'Id', 'Resource_API_Name__c', 'Resource_Parent_Resource_API_Field__c', 'Event_API_Name__c', 'Event_Parent_Resource_API_Field__c', 'Resource_Name_API_Field__c', 'Event_Start_Date_API_Field__c', 'Event_End_Date_API_Field__c', 'Event_Name_API_Field__c', 'Event_Color__c', 'Event_Icon__c', 'Resource_Icon__c', 'Event_Icon_API_Field__c', 'Resource_Icon_API_Field__c', 'Resource_Display_Columns_API_Fields__c', 'Event_Edit_Mode_Fields__c', 'Resource_Bookable_API_Field__c', 'Event_Color_API_Field__c', 'Resource_Order_Rule__c', 'Event_Tooltip_Fields__c'}) {
			if (!Scheduler_Fields__mdt.getSObjectType().getDescribe().fields.getMap().get(field).getDescribe().isAccessible()) {
				schedulerMappingException.setMessage('No read access for ' + field + ' field on Scheduler_Fields__mdt object');
				throw schedulerMappingException;
			}
		}

		if (String.isEmpty(fieldMappingMetadataId)) {
			fieldMappingMetadataId = [
				SELECT Id
				FROM Scheduler_Fields__mdt
				WHERE DeveloperName = 'Default'
			].Id;
		}

		Scheduler_Fields__mdt schedulerFields = [
			SELECT Id, Resource_API_Name__c, Resource_Parent_Resource_API_Field__c, Event_API_Name__c, Event_Parent_Resource_API_Field__c,
					Resource_Name_API_Field__c, Event_Start_Date_API_Field__c, Event_End_Date_API_Field__c, Event_Name_API_Field__c, Event_Color__c, Event_Icon__c,
					Resource_Icon__c, Event_Icon_API_Field__c, Resource_Icon_API_Field__c, Resource_Display_Columns_API_Fields__c, Event_Edit_Mode_Fields__c,
					Resource_Bookable_API_Field__c, Event_Color_API_Field__c, Resource_Order_Rule__c, Event_Tooltip_Fields__c, Resource_Hotel_API_Name__c,
					Hotel_API_Name__c, Resource_Type_API_Name__c, Resource_Opening_Hours_API_Name__c, Resource_Opening_Hours_Resource__c, Resource_Opening_Hours_Start_Time__c,
					Resource_Opening_Hours_End_Time__c, Resource_Opening_Hours_Days_API_Field__c
			FROM Scheduler_Fields__mdt
			WHERE Id = :fieldMappingMetadataId
		];

		if (!FeatureManagement.checkPermission((SchedulerController.class.getName().contains('.') ? SchedulerController.class.getName().substringBefore('.') + '__' : '') + 'Scheduler') && !Test.isRunningTest()) {
			schedulerMappingException.setMessage('No permissions to access the Scheduler');
			throw schedulerMappingException;
		}

		if ((String.isBlank(schedulerFields.Resource_API_Name__c) || !Schema.getGlobalDescribe().containsKey(schedulerFields.Resource_API_Name__c)) ||
			(String.isBlank(schedulerFields.Event_API_Name__c) || !Schema.getGlobalDescribe().containsKey(schedulerFields.Event_API_Name__c))) {
			schedulerMappingException.setMessage('Object ' + schedulerFields.Resource_API_Name__c + ' or ' + schedulerFields.Event_API_Name__c + ' not found');
			throw schedulerMappingException;
		}

		List<String> resourceMappingFields = new List<String> {
			schedulerFields.Resource_Parent_Resource_API_Field__c,
			schedulerFields.Resource_Name_API_Field__c,
			schedulerFields.Resource_Icon_API_Field__c,
			schedulerFields.Resource_Bookable_API_Field__c
		};

		if (schedulerFields.Resource_Order_Rule__c != null) {
			resourceMappingFields.add(schedulerFields.Resource_Order_Rule__c.substringBefore(' '));
		}

		if (Test.isRunningTest()) {
			String namespace = SchedulerController.class.getName().contains('.') ? SchedulerController.class.getName().substringBefore('.') + '__' : '';

			resourceMappingFields.add(String.format('{0}Parent_Resource__r.Name', new List<String> {
				namespace
			}));
			resourceMappingFields.add(String.format('{0}Parent_Resource__r.{0}Parent_Resource__r.Name', new List<String> {
				namespace
			}));
		}

		Map<String, SObjectField> resourceObjectFields = Schema.getGlobalDescribe().get(schedulerFields.Resource_API_Name__c).getDescribe().fields.getMap();

		// Validate the we have correct field naming for resources
		for (String fieldName : resourceMappingFields) {
			if (fieldName.toLowerCase().contains('__r')) {
				SObjectType currentSObjectType = Schema.getGlobalDescribe().get(schedulerFields.Resource_API_Name__c);

				for (String relativeFieldName : fieldName.split('\\.')) {
					if (relativeFieldName.toLowerCase().contains('__r')) {
						if (currentSObjectType.getDescribe().fields.getMap().containsKey(relativeFieldName.replace('__r', '__c'))) {
							currentSObjectType = currentSObjectType.getDescribe().fields.getMap().get(relativeFieldName.replace('__r', '__c')).getDescribe().getReferenceTo()[0];
						} else {
							schedulerMappingException.setMessage('Field ' + relativeFieldName + ' not found on ' + currentSObjectType.getDescribe().getName() + ' object');
						}
					} else {
						if (!currentSObjectType.getDescribe().fields.getMap().containsKey(relativeFieldName)) {
							schedulerMappingException.setMessage('Field ' + relativeFieldName + ' not found on ' + currentSObjectType.getDescribe().getName() + ' object');
						}
					}
				}

				break;
			}

			if (String.isBlank(fieldName) || !resourceObjectFields.containsKey(fieldName)) {
				schedulerMappingException.setMessage('Field ' + fieldName + ' not found on ' + schedulerFields.Resource_API_Name__c + ' object');
				break;
			}
		}

		List<String> eventMappingFields = new List<String> {
			schedulerFields.Event_Start_Date_API_Field__c,
			schedulerFields.Event_End_Date_API_Field__c,
			schedulerFields.Event_Name_API_Field__c,
			schedulerFields.Event_Icon_API_Field__c,
			schedulerFields.Event_Color_API_Field__c
		};

		List<String> eventTooltipFields = schedulerFields.Event_Tooltip_Fields__c != null ? schedulerFields.Event_Tooltip_Fields__c.replaceAll(' ', '').split(',') : new List<String>();
		eventMappingFields.addAll(eventTooltipFields);

		if (Test.isRunningTest()) {
			String namespace = SchedulerController.class.getName().contains('.') ? SchedulerController.class.getName().substringBefore('.') + '__' : '';

			eventMappingFields.add(String.format('{0}Parent_Resource__r.Name', new List<String> {
				namespace
			}));
			eventMappingFields.add(String.format('{0}Parent_Resource__r.{0}Parent_Resource__r.Name', new List<String> {
				namespace
			}));
		}

		Map<String, SObjectField> eventObjectFields = Schema.getGlobalDescribe().get(schedulerFields.Event_API_Name__c).getDescribe().fields.getMap();

		// Validate the we have correct field naming for events
		for (String fieldName : eventMappingFields) {
			if (fieldName.toLowerCase().contains('__r')) {
				SObjectType currentSObjectType = Schema.getGlobalDescribe().get(schedulerFields.Event_API_Name__c);

				for (String relativeFieldName : fieldName.split('\\.')) {
					if (relativeFieldName.toLowerCase().contains('__r')) {
						if (currentSObjectType.getDescribe().fields.getMap().containsKey(relativeFieldName.replace('__r', '__c'))) {
							currentSObjectType = currentSObjectType.getDescribe().fields.getMap().get(relativeFieldName.replace('__r', '__c')).getDescribe().getReferenceTo()[0];
						} else {
							schedulerMappingException.setMessage('Field ' + relativeFieldName + ' not found on ' + currentSObjectType.getDescribe().getName() + ' object');
						}
					} else {
						if (!currentSObjectType.getDescribe().fields.getMap().containsKey(relativeFieldName)) {
							schedulerMappingException.setMessage('Field ' + relativeFieldName + ' not found on ' + currentSObjectType.getDescribe().getName() + ' object');
						}
					}
				}

				break;
			}

			if (String.isBlank(fieldName) || !eventObjectFields.containsKey(fieldName)) {
				schedulerMappingException.setMessage('Field ' + fieldName + ' not found on ' + schedulerFields.Event_API_Name__c + ' object');
				break;
			}
		}

		if (String.isNotBlank(schedulerMappingException.getMessage()) && schedulerMappingException.getMessage() != 'Script-thrown exception') {
			throw schedulerMappingException;
		}

		Set<String> resourceFields = new Set<String> {
			'Id', schedulerFields.Resource_Parent_Resource_API_Field__c, schedulerFields.Resource_Name_API_Field__c, schedulerFields.Resource_Icon_API_Field__c, schedulerFields.Resource_Bookable_API_Field__c
		};

		if (schedulerFields.Resource_Order_Rule__c != null) {
			resourceFields.add(schedulerFields.Resource_Order_Rule__c.substringBefore(' '));
		}

		Map<String, SObjectType> schemaDescription = Schema.getGlobalDescribe();

		for (String field : resourceFields) {
			if (!schemaDescription.get(schedulerFields.Resource_API_Name__c).getDescribe().fields.getMap().get(field).getDescribe().isAccessible()) {
				schedulerMappingException.setMessage('No read access for ' + field + ' field on ' + schedulerFields.Resource_API_Name__c + ' object');
				throw schedulerMappingException;
			}
		}

		List<Object> resourceDisplayColumns = new List<Object>();
		DescribeSObjectResult resourceObjectDescription = Schema.getGlobalDescribe().get(schedulerFields.Resource_API_Name__c).getDescribe();

		for (String fieldName : schedulerFields.Resource_Display_Columns_API_Fields__c.replaceAll('\\s', '').split(',')) {
			resourceDisplayColumns.add(new Map<String, Object> {
				'field' => fieldName,
				'text' => resourceObjectDescription.fields.getMap().get(fieldName).getDescribe().getLabel()
			});

			resourceFields.add(fieldName);
		}

		// Retrieve all resources
		List<SObject> allResources = Database.query(String.format('SELECT {0} FROM {1} {2} LIMIT 10000', new List<String> {
			String.join(new List<String>(resourceFields), ','),
			schedulerFields.Resource_API_Name__c,
			String.isNotBlank(schedulerFields.Resource_Order_Rule__c) ? 'ORDER BY ' + schedulerFields.Resource_Order_Rule__c : ''
		}));
		List<SObject> resources = Database.query(String.format('SELECT {0} FROM {1} WHERE Id != null {2} {3} {4} {5} LIMIT 10000', new List<String> {
			String.join(new List<String>(resourceFields), ','),
			schedulerFields.Resource_API_Name__c,
			String.isNotBlank(customFilter) ? ' AND ' + customFilter : '',
			!hotels.isEmpty() ? ' AND ' + schedulerFields.Resource_Hotel_API_Name__c + ' IN :hotels' : '',
			!types.isEmpty() ? ' AND ' + schedulerFields.Resource_Type_API_Name__c + ' IN :types' : '',
			String.isNotBlank(schedulerFields.Resource_Order_Rule__c) ? 'ORDER BY ' + schedulerFields.Resource_Order_Rule__c : ''
		}));

		Datetime startDate = currentDate;
		Datetime endDate = currentDate;

		if (viewType == 'week') {
			endDate = startDate.addDays(7);
		} else if (viewType == 'month') {
			endDate = Datetime.newInstance(startDate.date().addMonths(1).toStartOfMonth(), Time.newInstance(0, 0, 0, 0));
		}

		Set<String> eventFields = new Set<String> {
			'Id', schedulerFields.Event_Parent_Resource_API_Field__c, schedulerFields.Event_Start_Date_API_Field__c, schedulerFields.Event_End_Date_API_Field__c,
			schedulerFields.Event_Name_API_Field__c, schedulerFields.Event_Icon_API_Field__c, schedulerFields.Event_Color_API_Field__c
		};

		for (String field : resourceFields) {
			if (!schemaDescription.get(schedulerFields.Resource_API_Name__c).getDescribe().fields.getMap().get(field).getDescribe().isAccessible()) {
				schedulerMappingException.setMessage('No read access for ' + field + ' field on ' + schedulerFields.Resource_API_Name__c + ' object');
				throw schedulerMappingException;
			}
		}

		if (String.isEmpty(customEventFilter) || customEventFilter == null) {
			customEventFilter = 'IsDeleted = false';
		}

		eventFields.addAll(eventTooltipFields);

		// Retrieve all events
		List<SObject> events = Database.query(String.format('SELECT {0} FROM {1} WHERE ((DAY_ONLY({2}) >= ' + String.valueOf(startDate.date()) + ' AND DAY_ONLY({2}) <= ' + String.valueOf(endDate.date()) + ') OR (DAY_ONLY({3}) >= ' + String.valueOf(startDate.date()) + ' AND DAY_ONLY({3}) <= ' + String.valueOf(endDate.date()) + ') OR (DAY_ONLY({2}) <= ' + String.valueOf(startDate.date()) + ' AND DAY_ONLY({3}) >= ' + String.valueOf(endDate.date()) + ')) AND ({5}) ORDER BY {4} ASC LIMIT 10000', new List<String> {
			String.join(new List<String>(eventFields), ','),
			schedulerFields.Event_API_Name__c,
			schedulerFields.Event_Start_Date_API_Field__c,
			schedulerFields.Event_End_Date_API_Field__c,
			schedulerFields.Event_Name_API_Field__c,
			customEventFilter
		}));

		List<Map<String, Object>> eventEditFields = new List<Map<String, Object>>();
		DescribeSObjectResult eventDescribeSObjectResult = Schema.getGlobalDescribe().get(schedulerFields.Event_API_Name__c).getDescribe();

		for (String fieldName : schedulerFields.Event_Edit_Mode_Fields__c.split(',')) {
			if (!eventDescribeSObjectResult.fields.getMap().containsKey(fieldName.trim())) {
				continue;
			}

			List<String> referenceToNames = new List<String>();

			for (SObjectType sObjectType : eventDescribeSObjectResult.fields.getMap().get(fieldName.trim()).getDescribe().referenceTo) {
				referenceToNames.add(sObjectType.getDescribe().getName());
			}

			eventEditFields.add(new Map<String, Object> {
				'apiName' => eventDescribeSObjectResult.fields.getMap().get(fieldName.trim()).getDescribe().getName(),
				'label' => eventDescribeSObjectResult.fields.getMap().get(fieldName.trim()).getDescribe().getLabel(),
				'type' => eventDescribeSObjectResult.fields.getMap().get(fieldName.trim()).getDescribe().getType(),
				'referenceTo' => referenceToNames,
				'picklistValues' => eventDescribeSObjectResult.fields.getMap().get(fieldName.trim()).getDescribe().getPicklistValues()
			});
		}

		List<resourceTimeRange> resourceTimeRangeList = new List<SchedulerController.resourceTimeRange>();

		List<SObject> timeRanges = Database.query(String.format('SELECT {1}, {2}, {3}, {4} FROM {0} LIMIT 10000', new List<String> {
				schedulerFields.Resource_Opening_Hours_API_Name__c,
				schedulerFields.Resource_Opening_Hours_End_Time__c,
				schedulerFields.Resource_Opening_Hours_Start_Time__c,
				schedulerFields.Resource_Opening_Hours_Days_API_Field__c,
				schedulerFields.Resource_Opening_Hours_Resource__c
		}));


		for (SObject timeRange: timeRanges){
			String resIdTimeRange = (String) timeRange.get(schedulerFields.Resource_Opening_Hours_Resource__c);
			Time endTimeRange = (Time) timeRange.get(schedulerFields.Resource_Opening_Hours_End_Time__c);
			Time startTimeRange = (Time) timeRange.get(schedulerFields.Resource_Opening_Hours_Start_Time__c);
			String daysTimeRange = (String) timeRange.get(schedulerFields.Resource_Opening_Hours_Days_API_Field__c);

			if (resIdTimeRange != null && daysTimeRange != null && (endTimeRange != null || startTimeRange != null) && startTimeRange != endTimeRange) {
				List<String> daysTimeRangeList = daysTimeRange.split(';');

				for (Date dayTimeRange = startDate.date().addDays(-1); dayTimeRange <= endDate.date(); dayTimeRange = dayTimeRange.addDays(1)){
					if (daysTimeRangeList.contains(Datetime.newInstance(dayTimeRange, Time.newInstance(0, 0, 0, 0)).format('EEEE'))) {
						if (startTimeRange != null && startTimeRange != Time.newInstance(0, 0, 0, 0)) {
							resourceTimeRangeList.add(new resourceTimeRange(
									resIdTimeRange,
									Datetime.newInstance(dayTimeRange, Time.newInstance(0, 0, 0, 0)),
									Datetime.newInstance(dayTimeRange, startTimeRange)
							));
						}
						if (endTimeRange != null && endTimeRange != Time.newInstance(0, 0, 0, 0)) {
							resourceTimeRangeList.add(new resourceTimeRange(
									resIdTimeRange,
									Datetime.newInstance(dayTimeRange, endTimeRange),
									Datetime.newInstance(dayTimeRange.addDays(1), Time.newInstance(0, 0, 0, 0))
							));
						}
					}else {
						resourceTimeRangeList.add(new resourceTimeRange(
								resIdTimeRange,
								Datetime.newInstance(dayTimeRange, Time.newInstance(0, 0, 0, 0)),
								Datetime.newInstance(dayTimeRange.addDays(1), Time.newInstance(0, 0, 0, 0))
						));
					}
				}

			}
		}

		Map<String, Object> result = new Map<String, Object> {
			'namespace' => SchedulerController.class.getName().contains('.') ? SchedulerController.class.getName().substringBefore('.') : '',
			'mapping' => schedulerFields,
			'resources' => new Map<Id, SObject>(resources),
			'events' => new Map<Id, SObject>(events),
			'resourceTimeRanges' => resourceTimeRangeList,
			'resourceDisplayColumns' => resourceDisplayColumns,
			'eventEditFields' => eventEditFields,
			'timezoneOffset' => UserInfo.getTimeZone().getOffset(Datetime.now()) / 1000 / 60 / 60,
			'allResources' => allResources,
			'eventTooltipFields' => eventTooltipFields
		};

		return JSON.serialize(result);
	}
	public class resourceTimeRange {
		@AuraEnabled
		public String resourceId{get;set;}
		@AuraEnabled
		public Datetime startDate{get;set;}
		@AuraEnabled
		public Datetime endDate{get;set;}
		@AuraEnabled
		public String cls{get;set;}

		public resourceTimeRange (String resourceId, Datetime startDate, Datetime endDate){
			this.resourceId = resourceId;
			this.startDate = startDate;
			this.endDate = endDate;
			this.cls = 'resourceTimeRangeColor';
		}
	}
	/**
	* Method to update an event from UI based on passed fields
	*
	* @param {Map.<String, Object>} eventData
	* @param {String} fieldMappingMetadataId
	*
	* @return String
	*/
	@AuraEnabled
	public static String updateEvent(Map<String, Object> eventData, String fieldMappingMetadataId) {
		SchedulerMappingException schedulerMappingException = new SchedulerMappingException();
		System.debug('updateEvent');

		if (!Scheduler_Fields__mdt.getSObjectType().getDescribe().isAccessible()) {
			schedulerMappingException.setMessage('No read access for Scheduler_Fields__mdt object');
			throw schedulerMappingException;
		}

		for (String field : new Set<String> {'Id', 'Resource_API_Name__c', 'Resource_Parent_Resource_API_Field__c', 'Event_API_Name__c', 'Event_Parent_Resource_API_Field__c', 'Resource_Name_API_Field__c', 'Event_Start_Date_API_Field__c', 'Event_End_Date_API_Field__c', 'Event_Name_API_Field__c', 'Event_Color__c', 'Event_Icon__c', 'Resource_Icon__c', 'Event_Icon_API_Field__c', 'Resource_Icon_API_Field__c', 'Resource_Display_Columns_API_Fields__c', 'Event_Edit_Mode_Fields__c', 'Resource_Bookable_API_Field__c', 'Event_Color_API_Field__c', 'Resource_Order_Rule__c' , 'Resource_Opening_Hours_API_Name__c', 'Resource_Opening_Hours_Resource__c', 'Resource_Opening_Hours_Start_Time__c', 'Resource_Opening_Hours_End_Time__c', 'Resource_Opening_Hours_Days_API_Field__c'}) {
			if (!Scheduler_Fields__mdt.getSObjectType().getDescribe().fields.getMap().get(field).getDescribe().isAccessible()) {
				schedulerMappingException.setMessage('No read access for ' + field + ' field on Scheduler_Fields__mdt object');
				throw schedulerMappingException;
			}
		}

		if (String.isEmpty(fieldMappingMetadataId)) {
			fieldMappingMetadataId = [
				SELECT Id
				FROM Scheduler_Fields__mdt
				WHERE DeveloperName = 'Default'
			].Id;
		}

        Scheduler_Fields__mdt schedulerFields = [
            SELECT Id, Resource_API_Name__c, Resource_Parent_Resource_API_Field__c, Event_API_Name__c, Event_Parent_Resource_API_Field__c, Resource_Name_API_Field__c,
					Event_Start_Date_API_Field__c, Event_End_Date_API_Field__c, Event_Name_API_Field__c, Event_Color__c, Event_Icon__c, Resource_Icon__c, Event_Icon_API_Field__c,
					Resource_Icon_API_Field__c, Resource_Display_Columns_API_Fields__c, Event_Edit_Mode_Fields__c, Resource_Bookable_API_Field__c, Event_Color_API_Field__c, Resource_Order_Rule__c,
					Resource_Opening_Hours_API_Name__c, Resource_Opening_Hours_Resource__c, Resource_Opening_Hours_Start_Time__c, Resource_Opening_Hours_End_Time__c, Resource_Opening_Hours_Days_API_Field__c
            FROM Scheduler_Fields__mdt
            WHERE Id = :fieldMappingMetadataId
        ];

		if (!Schema.getGlobalDescribe().get(schedulerFields.Event_API_Name__c).getDescribe().isAccessible() || !Schema.getGlobalDescribe().get(schedulerFields.Event_API_Name__c).getDescribe().isUpdateable()) {
			return 'Not enough access to ' + schedulerFields.Event_API_Name__c + ' object';
		}

		try {
	        Id resourceId;

	        if (eventData.containsKey(schedulerFields.Event_Parent_Resource_API_Field__c)) {
		        resourceId = Id.valueOf(String.valueOf(eventData.get(schedulerFields.Event_Parent_Resource_API_Field__c)));
	        } else {
		        if (!Schema.getGlobalDescribe().get(schedulerFields.Event_API_Name__c).getDescribe().fields.getMap().get(schedulerFields.Event_Parent_Resource_API_Field__c).getDescribe().isAccessible()) {
			        return 'Not enough access to ' + schedulerFields.Event_Parent_Resource_API_Field__c + ' field';
		        }

		        String resourceIdString = String.valueOf(Database.query('SELECT ' + schedulerFields.Event_Parent_Resource_API_Field__c + ' FROM ' + schedulerFields.Event_API_Name__c + ' WHERE Id = \'' + eventData.get('Id') + '\'')[0].get(schedulerFields.Event_Parent_Resource_API_Field__c));

		        if (resourceIdString != null) {
			        resourceId = Id.valueOf(resourceIdString);
		        }
	        }

			String bookableDecision = checkResourceBookable(resourceId, fieldMappingMetadataId, String.valueOf(eventData.get(schedulerFields.Event_End_Date_API_Field__c)), String.valueOf(eventData.get(schedulerFields.Event_Start_Date_API_Field__c)));

			if (String.isNotBlank(bookableDecision)) {
				return bookableDecision;
			}

            SObject event = Schema.getGlobalDescribe().get(schedulerFields.Event_API_Name__c).newSObject();
            DescribeSObjectResult eventDescribeSObjectResult = event.getSObjectType().getDescribe();
            
            for (String key : eventData.keySet()) {
                if (!eventDescribeSObjectResult.isAccessible() || !eventDescribeSObjectResult.isUpdateable()) {
                    return 'Not enough access to ' + key + ' field';
                }
                
                if (eventDescribeSObjectResult.fields.getMap().get(key).getDescribe().type == DisplayType.DATETIME) {
                    event.put(key, Datetime.valueOf(String.valueOf(eventData.get(key))));
                } else {
                    event.put(key, eventData.get(key));
                }
                
            }
            
            update event;
		} catch (Exception e) {
			System.debug('e ' + e + ' ' + e.getLineNumber() + ' ' + e.getStackTraceString());
			return e.getMessage();
		}

		return '';
	}

	@AuraEnabled
	public static String checkResourceBookable(Id resourceId, String fieldMappingMetadataId, String endTime, String startTime) {

		Datetime endDateTime = Datetime.valueOfGmt(endTime);
		Datetime startDateTime = Datetime.valueOfGmt(startTime);

		Scheduler_Fields__mdt schedulerFields = [
				SELECT Id, Resource_API_Name__c, Resource_Parent_Resource_API_Field__c, Event_API_Name__c, Event_Parent_Resource_API_Field__c, Resource_Name_API_Field__c,
						Event_Start_Date_API_Field__c, Event_End_Date_API_Field__c, Event_Name_API_Field__c, Event_Color__c, Event_Icon__c, Resource_Icon__c, Event_Icon_API_Field__c,
						Resource_Icon_API_Field__c, Resource_Display_Columns_API_Fields__c, Event_Edit_Mode_Fields__c, Resource_Bookable_API_Field__c, Event_Color_API_Field__c, Resource_Order_Rule__c,
						Resource_Opening_Hours_API_Name__c, Resource_Opening_Hours_Resource__c, Resource_Opening_Hours_Start_Time__c, Resource_Opening_Hours_End_Time__c, Resource_Opening_Hours_Days_API_Field__c
				FROM Scheduler_Fields__mdt
				WHERE Id = :fieldMappingMetadataId
		];

		if (String.isBlank(schedulerFields.Resource_Opening_Hours_API_Name__c) ||
				String.isBlank(schedulerFields.Resource_Opening_Hours_Resource__c) ||
				String.isBlank(schedulerFields.Resource_Opening_Hours_Start_Time__c) ||
				String.isBlank(schedulerFields.Resource_Opening_Hours_End_Time__c) ||
				String.isBlank(schedulerFields.Resource_Opening_Hours_Days_API_Field__c) ||
				resourceId == null) {
			return '';
		}

		if (!Schema.getGlobalDescribe().get(schedulerFields.Resource_Opening_Hours_API_Name__c).getDescribe().isAccessible()) {
			return 'Not enough access to ' + schedulerFields.Resource_Opening_Hours_API_Name__c + ' object';
		}

		for (String field : new Set<String> {
				schedulerFields.Resource_Opening_Hours_Resource__c,
				schedulerFields.Resource_Opening_Hours_Start_Time__c,
				schedulerFields.Resource_Opening_Hours_End_Time__c,
				schedulerFields.Resource_Opening_Hours_Days_API_Field__c
		}) {
			if (!Schema.getGlobalDescribe().get(schedulerFields.Resource_Opening_Hours_API_Name__c).getDescribe().fields.getMap().get(field).getDescribe().isAccessible()) {
				return 'Not enough access to ' + field + ' field';
			}
		}
		String openingDays = '\'' + startDateTime.format('EEEE') + '\'';

		Boolean allDay = false;
		for (Integer i = 0; i <= 5; i++){
			if (Date.newInstance(startDateTime.year(), startDateTime.month(), startDateTime.day()) == Date.newInstance(endDateTime.year(), endDateTime.month(), endDateTime.day())) {
				break;
			}else {
				startDateTime = startDateTime.addDays(1);
				openingDays += ', \'' +  startDateTime.format('EEEE') + '\'';
				allDay = true;
			}
		}

		if (Database.countQuery('SELECT COUNT() FROM ' + schedulerFields.Resource_Opening_Hours_API_Name__c + ' WHERE ' + schedulerFields.Resource_Opening_Hours_Resource__c + ' = \'' + resourceId + '\'') > 0) {
			System.debug(allDay);

			if (!allDay) {
				if (Database.countQuery(String.format('SELECT COUNT() FROM {0} WHERE {1} = {2} AND {3} <= {8} AND {4} >= {7} AND {5} INCLUDES ({6})', new List<String> {
						schedulerFields.Resource_Opening_Hours_API_Name__c,
						schedulerFields.Resource_Opening_Hours_Resource__c,
						'\''+ resourceId + '\'',
						schedulerFields.Resource_Opening_Hours_Start_Time__c,
						schedulerFields.Resource_Opening_Hours_End_Time__c,
						schedulerFields.Resource_Opening_Hours_Days_API_Field__c,
						openingDays,
						String.valueOf(endDateTime.time()),
						String.valueOf(startDateTime.time())
				})) == 0) {

					return 'This resource isn\'t bookable';
				}
			}else {
				if (Database.countQuery(String.format('SELECT COUNT() FROM {0} WHERE {1} = {2} AND {3} = {7} AND {4} = {7} AND {5} INCLUDES ({6})', new List<String> {
						schedulerFields.Resource_Opening_Hours_API_Name__c,
						schedulerFields.Resource_Opening_Hours_Resource__c,
						'\''+ resourceId + '\'',
						schedulerFields.Resource_Opening_Hours_Start_Time__c,
						schedulerFields.Resource_Opening_Hours_End_Time__c,
						schedulerFields.Resource_Opening_Hours_Days_API_Field__c,
						openingDays,
						String.valueOf(Time.newInstance(0,0,0,0))
				})) == 0) {

					return 'This resource isn\'t bookable';
				}
			}
		}

		return '';
	}

	public class SchedulerMappingException extends Exception {
	}

}