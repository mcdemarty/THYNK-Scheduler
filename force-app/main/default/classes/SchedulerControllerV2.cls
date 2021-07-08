public with sharing class SchedulerControllerV2 {

	private static Scheduler_Fields_V2__mdt schedulerFieldMapping;

	@AuraEnabled(Cacheable=false)
	public static SchedulerData getSchedulerData(String fieldMappingMetadataName, Datetime startDate, Datetime endDate, String eventCustomFilter, String resourceCustomFilter, String resourceOrderRule) {
		if (!FeatureManagement.checkPermission(getPackagedName('Scheduler')) && !Test.isRunningTest()) {
			throw new SchedulerException('No permissions to access the Scheduler');
		}

		Scheduler_Fields_V2__mdt schedulerFields = getSchedulerFieldMapping(fieldMappingMetadataName);

		SchedulerData schedulerData = new SchedulerData();

		schedulerData.resources = getResources(fieldMappingMetadataName, resourceCustomFilter, resourceOrderRule);
		schedulerData.events = getEvents(fieldMappingMetadataName, startDate, endDate, eventCustomFilter);
		schedulerData.resourceColumns = getResourceColumns(fieldMappingMetadataName);

		if (String.isNotEmpty(schedulerFields.Event_Edit_Mode_Fields__c)) {
			schedulerData.eventEditFields = schedulerFields.Event_Edit_Mode_Fields__c.replaceAll(' ', '').split(',');
		}

		if (String.isNotEmpty(schedulerFields.Event_Tooltip_Fields__c)) {
			schedulerData.eventTooltipFields = schedulerFields.Event_Tooltip_Fields__c.replaceAll(' ', '').split(',');
		}

		schedulerData.eventObjectName = schedulerFields.Event_API_Name__c;
		schedulerData.eventParentResourceFieldAPIName = schedulerFields.Event_Parent_Resource_API_Field__c;
		schedulerData.eventStartDateFieldAPIName = schedulerFields.Event_Start_Date_API_Field__c;
		schedulerData.eventEndDateFieldAPIName = schedulerFields.Event_End_Date_API_Field__c;

		if (!schedulerData.eventEditFields.isEmpty()) {
			Map<String, SObjectField> fieldMap = Schema.getGlobalDescribe().get(schedulerFields.Event_API_Name__c).getDescribe().fields.getMap();
			for (String fieldName : schedulerData.eventEditFields) {
				schedulerData.eventEditFieldData.put(fieldName, new FieldData(fieldMap.get(fieldName)));
			}
		}

		List<Id> resources = new List<Id>();

		for (SchedulerResource resource : schedulerData.resources) {
			resources.add(resource.id);
		}

		schedulerData.maintenanceTimeRanges = getMaintenanceTimeRanges(fieldMappingMetadataName, startDate, endDate, resources);
		schedulerData.timeRanges = getTimeRanges(fieldMappingMetadataName, startDate, endDate);

		if (String.isNotEmpty(schedulerFields.Event_Tooltip_Fields__c)) {
			SObjectType eventObjectType = Schema.getGlobalDescribe().get(schedulerFields.Event_API_Name__c);

			for (String field : schedulerFields.Event_Tooltip_Fields__c.replaceAll(' ', '').split(',')) {
				schedulerData.eventTooltipFieldsNames.put(field, checkFieldValidity(field, eventObjectType).getDescribe().getLabel());
			}
		}

		return schedulerData;
	}

	@AuraEnabled
	public static SObject getEventRecord(Id recordId, List<String> fields) {
		String query = 'SELECT Id, ' + String.join(fields, ', ') +
			' FROM ' + recordId.getSobjectType() +
			' WHERE Id = :recordId';
		return Database.query(query);
	}

	@AuraEnabled
	public static void saveEvent(String fieldMappingMetadataName, String eventJSON) {
		SchedulerEvent event = (SchedulerEvent)JSON.deserialize(eventJSON, SchedulerEvent.class);
		Scheduler_Fields_V2__mdt schedulerFields = getSchedulerFieldMapping(fieldMappingMetadataName);

		if (!Schema.getGlobalDescribe().get(schedulerFields.Event_API_Name__c).getDescribe().isCreateable()) {
			throw new SchedulerFieldMappingException('Not enough permissions to create ' + schedulerFields.Event_API_Name__c + ' record');
		}

		SObject eventRecord = Schema.getGlobalDescribe().get(schedulerFields.Event_API_Name__c).newSObject();

		eventRecord.Id = event.id;

		eventRecord.put(schedulerFields.Event_Start_Date_API_Field__c, event.startDate);
		eventRecord.put(schedulerFields.Event_End_Date_API_Field__c, event.endDate);
		eventRecord.put(schedulerFields.Event_Parent_Resource_API_Field__c, event.resourceId);

		if (!isResourceBookable(fieldMappingMetadataName, event.resourceId)) {
			throw new SchedulerException('This resource isn\'t bookable');
		}

		if (String.isNotEmpty(event.secondResourceId)) {
			if (!isResourceBookable(fieldMappingMetadataName, event.secondResourceId)) {
				throw new SchedulerException('This resource isn\'t bookable');
			}
		}

		if (!getMaintenanceTimeRanges(fieldMappingMetadataName, event.startDate, event.endDate, new List<Id> { event.resourceId }).isEmpty()) {
			throw new SchedulerException('This resource is in maintenance for this dates');
		}

		if (!getTimeRanges(fieldMappingMetadataName, event.startDate, event.endDate).isEmpty()) {
			throw new SchedulerException('This dates are in maintenance');
		}

		update eventRecord;
	}

	@AuraEnabled
	public static Boolean isResourceBookable(String fieldMappingMetadataName, Id resourceId) {
		Scheduler_Fields_V2__mdt schedulerFields = getSchedulerFieldMapping(fieldMappingMetadataName);

		List<SObject> resources = Database.query(String.format('SELECT {0} FROM {1} WHERE Id = :resourceId', new List<String> {
			schedulerFields.Resource_Bookable_API_Field__c,
			schedulerFields.Resource_API_Name__c
		}));

		return Boolean.valueOf(getSafeFieldValue(schedulerFields.Resource_Bookable_API_Field__c, resources[0]));
	}

	private static List<SchedulerResource> getResources(String fieldMappingMetadataName, String resourceCustomFilter, String resourceOrderRule) {
		Scheduler_Fields_V2__mdt schedulerFields = getSchedulerFieldMapping(fieldMappingMetadataName);

		Set<String> fieldsToRetrieve = new Set<String> {
			schedulerFields.Resource_Name_API_Field__c,
			schedulerFields.Resource_Parent_Resource_API_Field__c,
			schedulerFields.Resource_Icon_API_Field__c,
			schedulerFields.Resource_Bookable_API_Field__c
		};

		if (!String.isEmpty(schedulerFields.Resource_Display_Columns_API_Fields__c)) {
			fieldsToRetrieve.addAll(schedulerFields.Resource_Display_Columns_API_Fields__c.replaceAll(' ', '').split(','));
		}

		if (!String.isEmpty(schedulerFields.Resource_Hidden_Columns_API_Fields__c)) {
			fieldsToRetrieve.addAll(schedulerFields.Resource_Hidden_Columns_API_Fields__c.replaceAll(' ', '').split(','));
		}

		if (!String.isEmpty(schedulerFields.Resource_Image_API_Field__c)) {
			fieldsToRetrieve.add(schedulerFields.Resource_Image_API_Field__c);
		}

		Map<String, SObjectType> schemaGlobalDescribeResult = Schema.getGlobalDescribe();

		if (!schemaGlobalDescribeResult.containsKey(schedulerFields.Resource_API_Name__c)) {
			throw new SchedulerFieldMappingException('Resource object ' + schedulerFields.Resource_API_Name__c + ' not found');
		}

		for (String field : fieldsToRetrieve) {
			checkFieldValidity(field, schemaGlobalDescribeResult.get(schedulerFields.Resource_API_Name__c));
		}

		String query = 'SELECT ' + String.join(new List<String>(fieldsToRetrieve), ',') + ' FROM ' + schedulerFields.Resource_API_Name__c;

		if (String.isNotEmpty(resourceCustomFilter)) {
			query += ' WHERE ' + resourceCustomFilter + ' ';
		}

		query += ' ORDER BY ' + schedulerFields.Resource_Parent_Resource_API_Field__c + ' NULLS FIRST';

		if (String.isNotEmpty(resourceOrderRule)) {
			query += ', ' + resourceOrderRule;
		}

		List<SObject> queriedResources = Database.query(query);
		Map<Id, SchedulerResource> resources = new Map<Id, SchedulerResource>();
		Map<Id, ResourcePath> resourcesPaths = new Map<Id, ResourcePath>();

		for (SObject resource : queriedResources) {
			SchedulerResource schedulerResource = new SchedulerResource(resource, schedulerFields);

			resources.put(resource.Id, schedulerResource);
		}

		for (SchedulerResource resource : resources.values()) {
			if (resource.parentResource != null) {
				SchedulerResource currentResource = resource;

				while (currentResource.parentResource != null) {
					if (resourcesPaths.containsKey(resource.id)) {
						resourcesPaths.put(resource.id, new ResourcePath(resource.id, currentResource.parentResource + '_' + resourcesPaths.get(resource.id).path));
					} else {
						resourcesPaths.put(resource.id, new ResourcePath(resource.id, currentResource.parentResource));
					}

					currentResource = resources.get(currentResource.parentResource);
				}
			} else {
				resourcesPaths.put(resource.id, new ResourcePath(resource.id, ''));
			}
		}

		List<ResourcePath> sortedResourcePaths = new List<ResourcePath>(resourcesPaths.values());
		sortedResourcePaths.sort();

		for (ResourcePath resourcePath : sortedResourcePaths) {
			if (String.isEmpty(resourcePath.path)) {
				continue;
			}

			List<String> path = resourcePath.path.split('_');

			SchedulerResource currentResource = resources.get(path[0]);

			for (Integer i = 0; i < path.size(); i++) {
				if (i == 0) {
					currentResource = resources.get(path[i]);
					continue;
				}

				for (SchedulerResource childResource : currentResource.children) {
					if (childResource.id == path[i]) {
						currentResource = childResource;
						break;
					}
				}
			}

			currentResource.children.add(resources.get(resourcePath.resourceId));
		}

		Set<Id> resourceKeys = resources.keySet();

		for (Id resourceId : resourceKeys) {
			if (resources.get(resourceId).parentResource != null) {
				resources.remove(resourceId);
			}
		}

		return new List<SchedulerResource>(resources.values());
	}

	private static List<ResourceColumn> getResourceColumns(String fieldMappingMetadataName) {
		Scheduler_Fields_V2__mdt schedulerFields = getSchedulerFieldMapping(fieldMappingMetadataName);

		List<ResourceColumn> columns = new List<ResourceColumn>();

		List<String> fields = schedulerFields.Resource_Display_Columns_API_Fields__c.split(',');
		List<String> hiddenFields = new List<String>();

		if (String.isNotEmpty(schedulerFields.Resource_Hidden_Columns_API_Fields__c)) {
			hiddenFields = schedulerFields.Resource_Hidden_Columns_API_Fields__c.split(',');
		}

		if (fields.isEmpty()) {
			return columns;
		}

		SObjectType resourceObjectType = Schema.getGlobalDescribe().get(schedulerFields.Resource_API_Name__c);

		for (String field : fields) {
			String trimmedField = field.trim();

			DescribeFieldResult describeFieldResult = checkFieldValidity(trimmedField, resourceObjectType).getDescribe();

			ResourceColumn resourceColumn = new ResourceColumn();

			resourceColumn.text = describeFieldResult.getLabel();
			resourceColumn.field = trimmedField;
			resourceColumn.hidden = false;

			columns.add(resourceColumn);
		}

		for (String field : hiddenFields) {
			String trimmedField = field.trim();

			DescribeFieldResult describeFieldResult = checkFieldValidity(trimmedField, resourceObjectType).getDescribe();

			ResourceColumn resourceColumn = new ResourceColumn();

			resourceColumn.text = describeFieldResult.getLabel();
			resourceColumn.field = trimmedField;
			resourceColumn.hidden = true;

			columns.add(resourceColumn);
		}

		if (!columns.isEmpty()) {
			columns[0].type = 'resourceInfo';
		}

		return columns;
	}

	private static List<SchedulerEvent> getEvents(String fieldMappingMetadataName, Datetime startTime, Datetime endTime, String eventCustomFilter) {
		Scheduler_Fields_V2__mdt schedulerFields = getSchedulerFieldMapping(fieldMappingMetadataName);

		Set<String> fieldsToRetrieve = new Set<String> {
			schedulerFields.Event_Start_Date_API_Field__c,
			schedulerFields.Event_End_Date_API_Field__c,
			schedulerFields.Event_Name_API_Field__c,
			schedulerFields.Event_Parent_Resource_API_Field__c
		};

		if (String.isNotEmpty(schedulerFields.Event_Color_API_Field__c)) {
			fieldsToRetrieve.add(schedulerFields.Event_Color_API_Field__c);
		}

		if (String.isNotEmpty(schedulerFields.Event_Icon_API_Field__c)) {
			fieldsToRetrieve.add(schedulerFields.Event_Icon_API_Field__c);
		}

		if (String.isNotEmpty(schedulerFields.Event_Style_API_Field__c)) {
			fieldsToRetrieve.add(schedulerFields.Event_Style_API_Field__c);
		}

		if (String.isNotEmpty(schedulerFields.Event_Id_API_Field__c)) {
			fieldsToRetrieve.add(schedulerFields.Event_Id_API_Field__c);
		}

		if (String.isNotEmpty(schedulerFields.Event_Second_Parent_Resource_API_Field__c)) {
			fieldsToRetrieve.add(schedulerFields.Event_Second_Parent_Resource_API_Field__c);
		}

		if (String.isNotEmpty(schedulerFields.Event_Tooltip_Fields__c)) {
			fieldsToRetrieve.addAll(schedulerFields.Event_Tooltip_Fields__c.replaceAll(' ', '').split(','));
		}

		if (String.isNotEmpty(schedulerFields.Event_Previous_Event_API_Field__c)) {
			fieldsToRetrieve.add(schedulerFields.Event_Previous_Event_API_Field__c);
		}

		Map<String, SObjectType> schemaGlobalDescribeResult = Schema.getGlobalDescribe();

		if (schemaGlobalDescribeResult.get(schedulerFields.Event_API_Name__c).getDescribe().fields.getMap().containsKey('thn__Property__c')) {
			fieldsToRetrieve.add('thn__Property__c');
		}

		if (!schemaGlobalDescribeResult.containsKey(schedulerFields.Event_API_Name__c)) {
			throw new SchedulerFieldMappingException('Event object ' + schedulerFields.Event_API_Name__c + ' not found');
		}

		for (String field : fieldsToRetrieve) {
			checkFieldValidity(field, schemaGlobalDescribeResult.get(schedulerFields.Event_API_Name__c));
		}

		String query = 'SELECT ' + String.join(new List<String>(fieldsToRetrieve), ',') + ' FROM ' + schedulerFields.Event_API_Name__c + ' WHERE ';

		String startEndWhereClause = String.format('(({0} >= :startTime AND {0} <= :endTime) OR ({1} >= :startTime AND {1} <= :endTime) OR ({0} <= :startTime AND {1} >= :endTime))', new List<String> {
			schedulerFields.Event_Start_Date_API_Field__c,
			schedulerFields.Event_End_Date_API_Field__c
		});

		query += startEndWhereClause;

		if (String.isNotEmpty(eventCustomFilter)) {
			query += ' AND ' + eventCustomFilter;
		}

		List<SObject> queriedEvents = Database.query(query);

		List<SchedulerEvent> events = new List<SchedulerEvent>();

		for (SObject event : queriedEvents) {
			events.add(new SchedulerEvent(event, schedulerFields));
		}

		return events;
	}

	@AuraEnabled
	public static List<SchedulerResourceMaintenance> getMaintenanceTimeRanges(String fieldMappingMetadataName, Datetime startTime, Datetime endTime, List<Id> resources) {
		Scheduler_Fields_V2__mdt schedulerFields = getSchedulerFieldMapping(fieldMappingMetadataName);

		if (schedulerFields.Resource_Maintenance_API_Name__c == null) {
			return new List<SchedulerResourceMaintenance>();
		}

		Set<String> fieldsToRetrieve = new Set<String> {
			schedulerFields.Resource_Maintenance_Start_API_Field__c,
			schedulerFields.Resource_Maintenance_End_API_Field__c,
			schedulerFields.Resource_Maintenance_Resource_API_Field__c
		};

		String query = 'SELECT ' + String.join(new List<String>(fieldsToRetrieve), ',') + ' FROM ' + schedulerFields.Resource_Maintenance_API_Name__c + ' WHERE ' + schedulerFields.Resource_Maintenance_Resource_API_Field__c + ' IN :resources AND ';

		String startEndWhereClause = String.format('(({0} >= :startTime AND {0} <= :endTime) OR ({1} >= :startTime AND {1} <= :endTime) OR ({0} <= :startTime AND {1} >= :endTime))', new List<String> {
			schedulerFields.Resource_Maintenance_Start_API_Field__c,
			schedulerFields.Resource_Maintenance_End_API_Field__c
		});

		query += startEndWhereClause;

		List<SObject> queriedRanges = Database.query(query);

		List<SchedulerResourceMaintenance> result = new List<SchedulerResourceMaintenance>();

		for (SObject timeRangeRecord : queriedRanges) {
			SchedulerResourceMaintenance timeRange = new SchedulerResourceMaintenance(timeRangeRecord, schedulerFields);

			result.add(timeRange);
		}

		return result;
	}

	@AuraEnabled
	public static List<SchedulerTimeRange> getTimeRanges(String fieldMappingMetadataName, Datetime startTime, Datetime endTime) {
		Scheduler_Fields_V2__mdt schedulerFields = getSchedulerFieldMapping(fieldMappingMetadataName);

		if (schedulerFields.Time_Range_API_Name__c == null) {
			return new List<SchedulerTimeRange>();
		}

		Set<String> fieldsToRetrieve = new Set<String> {
			schedulerFields.Time_Range_Start_Date_API_Field__c,
			schedulerFields.Time_Range_End_Date_API_Field__c,
			schedulerFields.Time_Range_Name_API_Field__c,
			schedulerFields.Time_Range_Color_API_Field__c,
			schedulerFields.Time_Range_Icon_API_Field__c
		};

		String query = 'SELECT ' + String.join(new List<String>(fieldsToRetrieve), ',') + ' FROM ' + schedulerFields.Time_Range_API_Name__c + ' WHERE ';

		String startEndWhereClause = String.format('(({0} >= :startTime AND {0} <= :endTime) OR ({1} >= :startTime AND {1} <= :endTime) OR ({0} <= :startTime AND {1} >= :endTime))', new List<String> {
			schedulerFields.Time_Range_Start_Date_API_Field__c,
			schedulerFields.Time_Range_End_Date_API_Field__c
		});

		query += startEndWhereClause;

		List<SObject> queriedRanges = Database.query(query);

		List<SchedulerTimeRange> result = new List<SchedulerTimeRange>();

		for (SObject timeRangeRecord : queriedRanges) {
			SchedulerTimeRange timeRange = new SchedulerTimeRange(timeRangeRecord, schedulerFields);

			result.add(timeRange);
		}

		return result;
	}

	@AuraEnabled
	public static void deleteEvent(Id eventId) {
		delete eventId.getSobjectType().newSObject(eventId);
	}

	private static Scheduler_Fields_V2__mdt getSchedulerFieldMapping(String fieldMappingMetadataName) {
		if (schedulerFieldMapping != null) {
			return schedulerFieldMapping;
		}

		if (!Scheduler_Fields_V2__mdt.getSObjectType().getDescribe().isAccessible()) {
			throw new SchedulerFieldMappingException('Not enough access to Scheduler Fields custom metadata record');
		}

		Set<String> fieldsToRetrieve = new Set<String>();

		for (SObjectField field : Scheduler_Fields_V2__mdt.getSObjectType().getDescribe().fields.getMap().values()) {
			if (!field.getDescribe().isAccessible()) {
				throw new SchedulerFieldMappingException('Not enough access to ' + field.getDescribe().getName() + ' field on Scheduler Fields custom metadata record');
			} else {
				fieldsToRetrieve.add(field.getDescribe().getName());
			}
		}

		List<Scheduler_Fields_V2__mdt> schedulerFields = Database.query('SELECT ' + String.join(new List<String>(fieldsToRetrieve), ',') + ' FROM ' + Scheduler_Fields_V2__mdt.getSObjectType().getDescribe().getName() + ' WHERE DeveloperName = :fieldMappingMetadataName');

		if (schedulerFields.isEmpty()) {
			throw new SchedulerFieldMappingException('Scheduler Fields record with Name ' + fieldMappingMetadataName + ' not found');
		}

		schedulerFieldMapping = schedulerFields[0];

		return schedulerFieldMapping;
	}

	private static String getPackagedName(String name) {
		return (SchedulerControllerV2.class.getName().contains('.') ? SchedulerControllerV2.class.getName().substringBefore('.') + '__' : '') + name;
	}

	public static SObjectField checkFieldValidity(String fieldPath, SObjectType sObjectType) {
		if (!fieldPath.contains('.')) {
			if (sObjectType.getDescribe().fields.getMap().containsKey(fieldPath)) {
				if (sObjectType.getDescribe().fields.getMap().get(fieldPath).getDescribe().isAccessible()) {
					return sObjectType.getDescribe().fields.getMap().get(fieldPath);
				} else {
					throw new SchedulerFieldMappingException('Not enough access to ' + fieldPath + ' field on ' + sObjectType.getDescribe().getName() + ' object.');
				}
			} else {
				throw new SchedulerFieldMappingException('Field ' + fieldPath + ' not found on ' + sObjectType.getDescribe().getName() + ' object.');
			}
		} else {
			SObjectType currentSObjectType = sObjectType;

			for (String pathItem : fieldPath.split('\\.')) {
				DescribeSObjectResult sObjectTypeDescribeResult = currentSObjectType.getDescribe();

				if (pathItem.toLowerCase().contains('__r')) {
					pathItem = pathItem.toLowerCase().replace('__r', '__c');
				}

				if (sObjectTypeDescribeResult.fields.getMap().containsKey(pathItem + 'Id')) {
					pathItem = pathItem + 'Id';
				}

				if (!sObjectTypeDescribeResult.fields.getMap().containsKey(pathItem)) {
					throw new SchedulerFieldMappingException('Field ' + pathItem + ' not found on ' + sObjectTypeDescribeResult.getName() + ' object.');
				}

				if (!sObjectTypeDescribeResult.fields.getMap().get(pathItem).getDescribe().isAccessible()) {
					throw new SchedulerFieldMappingException('Not enough access to ' + pathItem + ' field on ' + sObjectTypeDescribeResult.getName() + ' object.');
				}

				if (sObjectTypeDescribeResult.fields.getMap().get(pathItem).getDescribe().getReferenceTo().isEmpty()) {
					return sObjectTypeDescribeResult.fields.getMap().get(pathItem);
				} else {
					currentSObjectType = sObjectTypeDescribeResult.fields.getMap().get(pathItem).getDescribe().getReferenceTo()[0];
				}
			}

			return null;
		}
	}

	private static Object getSafeFieldValue(String fieldPath, SObject parentObject) {
		if (String.isEmpty(fieldPath)) {
			return null;
		}

		if (!fieldPath.contains('.')) {
			return parentObject.get(fieldPath);
		} else {
			SObject currentSObject = parentObject;

			for (String pathItem : fieldPath.split('\\.')) {
				if (currentSObject == null) {
					return null;
				}

				if (pathItem.toLowerCase().contains('__r')) {
					currentSObject = currentSObject.getSObject(pathItem.toLowerCase().replace('__r', '__c'));

					continue;
				}

				if (currentSObject.getSObjectType().getDescribe().fields.getMap().containsKey(pathItem + 'Id')) {
					currentSObject = currentSObject.getSObject(pathItem);

					continue;
				}

				return currentSObject.get(pathItem);
			}
		}

		return null;
	}

	public class SchedulerData {
		@AuraEnabled
		public List<SchedulerResource> resources = new List<SchedulerResource>();
		@AuraEnabled
		public List<SchedulerEvent> events = new List<SchedulerEvent>();
		@AuraEnabled
		public List<ResourceColumn> resourceColumns = new List<ResourceColumn>();
		@AuraEnabled
		public List<SchedulerResourceMaintenance> maintenanceTimeRanges = new List<SchedulerResourceMaintenance>();
		@AuraEnabled
		public List<SchedulerTimeRange> timeRanges = new List<SchedulerTimeRange>();
		@AuraEnabled
		public List<String> eventEditFields = new List<String>();
		@AuraEnabled
		public Map<String, FieldData> eventEditFieldData = new Map<String, FieldData>();
		@AuraEnabled
		public List<String> eventTooltipFields = new List<String>();
		@AuraEnabled
		public String eventObjectName;
		@AuraEnabled
		public String eventParentResourceFieldAPIName;
		@AuraEnabled
		public String eventStartDateFieldAPIName;
		@AuraEnabled
		public String eventEndDateFieldAPIName;
		@AuraEnabled
		public Map<String, String> eventTooltipFieldsNames = new Map<String, String>();
		@AuraEnabled
		public Decimal gmtOffset = UserInfo.getTimeZone().getOffset(System.now()) / 1000 / 60 / 60;
	}

	public class SchedulerResource {
		@AuraEnabled
		public Id id;
		@AuraEnabled
		public String name;
		@AuraEnabled
		public Id parentResource;
		@AuraEnabled
		public Boolean expanded = true;
		@AuraEnabled
		public String iconCls;
		@AuraEnabled
		public String imageUrl;
		@AuraEnabled
		public Boolean bookable;

		@AuraEnabled
		public List<SchedulerEvent> events = new List<SchedulerEvent>();
		@AuraEnabled
		public List<SchedulerResource> children = new List<SchedulerResource>();

		@AuraEnabled
		public SObject resourceRecord;

		public SchedulerResource(SObject resource, Scheduler_Fields_V2__mdt schedulerFields) {
			id = resource.Id;
			name = String.valueOf(getSafeFieldValue(schedulerFields.Resource_Name_API_Field__c, resource));
			imageUrl = String.valueOf(getSafeFieldValue(schedulerFields.Resource_Image_API_Field__c, resource));
			bookable = Boolean.valueOf(getSafeFieldValue(schedulerFields.Resource_Bookable_API_Field__c, resource));

			if (getSafeFieldValue(schedulerFields.Resource_Parent_Resource_API_Field__c, resource) != null) {
				parentResource = String.valueOf(getSafeFieldValue(schedulerFields.Resource_Parent_Resource_API_Field__c, resource));
			}

			if (getSafeFieldValue(schedulerFields.Resource_Icon_API_Field__c, resource) != null) {
				iconCls = String.valueOf(getSafeFieldValue(schedulerFields.Resource_Icon_API_Field__c, resource));
			} else {
				iconCls = schedulerFields.Resource_Icon__c;
			}

			resourceRecord = resource;
		}
	}

	public class SchedulerEvent {
		@AuraEnabled
		public Id id;
		@AuraEnabled
		public String formulaId;
		@AuraEnabled
		public Datetime startDate;
		@AuraEnabled
		public Datetime endDate;
		@AuraEnabled
		public String name;
		@AuraEnabled
		public Id resourceId;
		@AuraEnabled
		public Id secondResourceId;
		@AuraEnabled
		public String eventColor;
		@AuraEnabled
		public String eventStyle;
		@AuraEnabled
		public String iconCls;
		@AuraEnabled
		public SObject eventRecord;
		@AuraEnabled
		public Id previousEvent;
		@AuraEnabled
		public Id property;

		public SchedulerEvent(SObject event, Scheduler_Fields_V2__mdt schedulerFields) {
			id = event.Id;
			formulaId = String.valueOf(getSafeFieldValue(schedulerFields.Event_Id_API_Field__c, event));
			startDate = Datetime.valueOf(getSafeFieldValue(schedulerFields.Event_Start_Date_API_Field__c, event));
			endDate = Datetime.valueOf(getSafeFieldValue(schedulerFields.Event_End_Date_API_Field__c, event));
			name = String.valueOf(getSafeFieldValue(schedulerFields.Event_Name_API_Field__c, event));
			resourceId = String.valueOf(getSafeFieldValue(schedulerFields.Event_Parent_Resource_API_Field__c, event));
			secondResourceId = String.valueOf(getSafeFieldValue(schedulerFields.Event_Second_Parent_Resource_API_Field__c, event));
			previousEvent = String.valueOf(getSafeFieldValue(schedulerFields.Event_Previous_Event_API_Field__c, event));

			if (event.getSObjectType().getDescribe().fields.getMap().containsKey('thn__Property__c')) {
				property = String.valueOf(getSafeFieldValue('thn__Property__c', event));
			}

			if (getSafeFieldValue(schedulerFields.Event_Color_API_Field__c, event) != null) {
				eventColor = String.valueOf(getSafeFieldValue(schedulerFields.Event_Color_API_Field__c, event));
			} else {
				eventColor = schedulerFields.Event_Color__c;
			}

			if (getSafeFieldValue(schedulerFields.Event_Icon_API_Field__c, event) != null) {
				iconCls = String.valueOf(getSafeFieldValue(schedulerFields.Event_Icon_API_Field__c, event));
			} else {
				iconCls = schedulerFields.Event_Icon__c;
			}

			if (getSafeFieldValue(schedulerFields.Event_Style_API_Field__c, event) != null) {
				eventStyle = String.valueOf(getSafeFieldValue(schedulerFields.Event_Style_API_Field__c, event)).toLowerCase();
			} else {
				eventStyle = 'plain';
			}

			eventRecord = event;
		}
	}

	public class FieldData {
		@AuraEnabled
		public String fieldName;

		@AuraEnabled
		public String fieldLabel;

		@AuraEnabled
		public String fieldType;

		@AuraEnabled
		public Boolean isTextField;

		@AuraEnabled
		public Boolean isTextAreaField;

		@AuraEnabled
		public Boolean isLookupField;

		@AuraEnabled
		public ObjectData referenceObject;

		@AuraEnabled
		public Boolean isPicklistField;

		@AuraEnabled
		public Boolean isDateField;

		@AuraEnabled
		public Boolean isTimeField;

		@AuraEnabled
		public Boolean isDateTimeField;

		@AuraEnabled
		public Boolean isNumberField;

		@AuraEnabled
		public Boolean isCurrencyField;

		@AuraEnabled
		public Boolean isPercentageField;

		@AuraEnabled
		public Double step;

		@AuraEnabled
		public Boolean isCheckboxField;

		@AuraEnabled
		public List<PicklistOption> picklistOptions = new List<PicklistOption>();

		public FieldData(SObjectField field) {
			DescribeFieldResult fieldDescription = field.getDescribe();
			this.fieldName = fieldDescription.name;
			this.fieldLabel = fieldDescription.label;
			this.fieldType = String.valueOf(fieldDescription.type);
			this.isTextField = this.fieldType == String.valueOf(DisplayType.STRING);
			this.isTextAreaField = this.fieldType == String.valueOf(DisplayType.TEXTAREA);
			this.isLookupField = this.fieldType == String.valueOf(DisplayType.REFERENCE);
			this.isPicklistField = this.fieldType == String.valueOf(DisplayType.PICKLIST);
			this.isDateField = this.fieldType == String.valueOf(DisplayType.DATE);
			this.isTimeField = this.fieldType == String.valueOf(DisplayType.TIME);
			this.isDateTimeField = this.fieldType == String.valueOf(DisplayType.DATETIME);
            		this.isCheckboxField = this.fieldType == String.valueOf(DisplayType.BOOLEAN);
            		this.isNumberField = this.fieldType == String.valueOf(DisplayType.DOUBLE);
			this.isCurrencyField = this.fieldType == String.valueOf(DisplayType.CURRENCY);
			this.isPercentageField = this.fieldType == String.valueOf(DisplayType.PERCENT);

            if (this.isNumberField || this.isCurrencyField || this.isPercentageField) {
                this.step = 1 / Math.pow(10, field.getDescribe().scale);
            }

            if (this.isLookupField) {
				this.referenceObject = new ObjectData(field.getDescribe().referenceTo[0]);
            }

            if (this.isPicklistField) {
                picklistOptions.add(new PicklistOption(null, '--- None ---'));
                for (Schema.PicklistEntry picklistEntry : field.getDescribe().picklistValues) {
                    picklistOptions.add(new PicklistOption(picklistEntry.value, picklistEntry.label));
                }
            }
		}
	}

	public class ObjectData {
		@AuraEnabled
		public String name;
		@AuraEnabled
		public String label;
		@AuraEnabled
		public String defaultRecordTypeId;

		public ObjectData(SObjectType sObjectType) {
			DescribeSObjectResult describeSObjectResult = sObjectType.getDescribe();

			this.name = describeSObjectResult.name;
			this.label = describeSObjectResult.label;
			for (Schema.RecordTypeInfo recordTypeInfo : describeSObjectResult.recordTypeInfos) {
				if (recordTypeInfo.isDefaultRecordTypeMapping()) {
					this.defaultRecordTypeId = recordTypeInfo.getRecordTypeId();
				}
			}
		}
	}

	public class SchedulerResourceMaintenance {
		@AuraEnabled
		public Id id;
		@AuraEnabled
		public Datetime startDate;
		@AuraEnabled
		public Datetime endDate;
		@AuraEnabled
		public Id resourceId;

		public SchedulerResourceMaintenance(SObject resourceTimeRange, Scheduler_Fields_V2__mdt schedulerFields) {
			id = resourceTimeRange.Id;
			startDate = Datetime.valueOf(resourceTimeRange.get(schedulerFields.Resource_Maintenance_Start_API_Field__c));
			endDate = Datetime.valueOf(resourceTimeRange.get(schedulerFields.Resource_Maintenance_End_API_Field__c));
			resourceId = String.valueOf(resourceTimeRange.get(schedulerFields.Resource_Maintenance_Resource_API_Field__c));
		}
	}

	public class SchedulerTimeRange {
		@AuraEnabled
		public Id id;
		@AuraEnabled
		public Datetime startDate;
		@AuraEnabled
		public Datetime endDate;
		@AuraEnabled
		public String name;
		@AuraEnabled
		public String iconCls;
		@AuraEnabled
		public String style;

		public SchedulerTimeRange(SObject timeRange, Scheduler_Fields_V2__mdt schedulerFields) {
			id = timeRange.Id;
			startDate = Datetime.valueOf(timeRange.get(schedulerFields.Time_Range_Start_Date_API_Field__c));
			endDate = Datetime.valueOf(timeRange.get(schedulerFields.Time_Range_End_Date_API_Field__c));
			name = String.valueOf(timeRange.get(schedulerFields.Time_Range_Name_API_Field__c));
			iconCls = String.valueOf(timeRange.get(schedulerFields.Time_Range_Icon_API_Field__c));

			style = String.format('opacity: 0.7; background: repeating-linear-gradient(-55deg, #ddd, #ddd 10px, {0} 5px, {0} 20px);', new List<String> {
				String.isEmpty(String.valueOf(timeRange.get(schedulerFields.Time_Range_Color_API_Field__c))) ?
					'#eee' :
					String.valueOf(timeRange.get(schedulerFields.Time_Range_Color_API_Field__c))
			});
		}
	}

	public class ResourceColumn {
		@AuraEnabled
		public String text;
		@AuraEnabled
		public String field;
		@AuraEnabled
		public Boolean sortable = true;
		@AuraEnabled
		public Boolean draggable = false;
		@AuraEnabled
		public Boolean hidden = false;
		@AuraEnabled
		public Boolean editor = false;
		@AuraEnabled
		public String type;
	}

	public class ResourcePath implements Comparable {
		public String path;
		public Id resourceId;

		public ResourcePath(Id resourceId, String path) {
			this.resourceId = resourceId;
			this.path = path;
		}

		public Integer compareTo(Object anotherPath) {
			return path.length() - ((ResourcePath)anotherPath).path.length();
		}
	}

	public class PicklistOption {
		@AuraEnabled
		public String value;

		@AuraEnabled
		public String label;

		@AuraEnabled
		public Boolean isDefault = false;

		public PicklistOption(String value, String label) {
			this.value = value;
			this.label = label;
		}
	}

	public class SchedulerFieldMappingException extends Exception {}
	public class SchedulerException extends Exception {}

}