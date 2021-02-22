public with sharing class SchedulerControllerV2 {

	private static Scheduler_Fields__mdt schedulerFieldMapping;

	@AuraEnabled(Cacheable=false)
	public static SchedulerData getSchedulerData(String fieldMappingMetadataName, Datetime startDate, Datetime endDate, String eventCustomFilter, String resourceCustomFilter, String resourceOrderRule) {
		if (!FeatureManagement.checkPermission(getPackagedName('Scheduler')) && !Test.isRunningTest()) {
			throw new SchedulerException('No permissions to access the Scheduler');
		}

		Scheduler_Fields__mdt schedulerFields = getSchedulerFieldMapping(fieldMappingMetadataName);

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

		List<Id> resources = new List<Id>();

		for (SchedulerResource resource : schedulerData.resources) {
			resources.add(resource.id);
		}

		schedulerData.maintenanceTimeRanges = getMaintenanceTimeRanges(fieldMappingMetadataName, startDate, endDate, resources);

		return schedulerData;
	}

	@AuraEnabled
	public static void saveEvent(String fieldMappingMetadataName, String eventJSON) {
		SchedulerEvent event = (SchedulerEvent)JSON.deserialize(eventJSON, SchedulerEvent.class);
		Scheduler_Fields__mdt schedulerFields = getSchedulerFieldMapping(fieldMappingMetadataName);

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

		if (!getMaintenanceTimeRanges(fieldMappingMetadataName, event.startDate, event.endDate, new List<Id> { event.resourceId }).isEmpty()) {
			throw new SchedulerException('This resource is in maintenance for this dates');
		}

		update eventRecord;
	}

	@AuraEnabled
	public static Boolean isResourceBookable(String fieldMappingMetadataName, Id resourceId) {
		Scheduler_Fields__mdt schedulerFields = getSchedulerFieldMapping(fieldMappingMetadataName);

		List<SObject> resources = Database.query(String.format('SELECT {0} FROM {1} WHERE Id = :resourceId', new List<String> {
			schedulerFields.Resource_Bookable_API_Field__c,
			schedulerFields.Resource_API_Name__c
		}));

		return Boolean.valueOf(resources[0].get(schedulerFields.Resource_Bookable_API_Field__c));
	}

	private static List<SchedulerResource> getResources(String fieldMappingMetadataName, String resourceCustomFilter, String resourceOrderRule) {
		Scheduler_Fields__mdt schedulerFields = getSchedulerFieldMapping(fieldMappingMetadataName);

		Set<String> fieldsToRetrieve = new Set<String> {
			schedulerFields.Resource_Name_API_Field__c,
			schedulerFields.Resource_Parent_Resource_API_Field__c,
			schedulerFields.Resource_Icon_API_Field__c
		};

		if (!String.isEmpty(schedulerFields.Resource_Display_Columns_API_Fields__c)) {
			fieldsToRetrieve.addAll(schedulerFields.Resource_Display_Columns_API_Fields__c.replaceAll(' ', '').split(','));
		}

		Map<String, SObjectType> schemaGlobalDescribeResult = Schema.getGlobalDescribe();

		if (!schemaGlobalDescribeResult.containsKey(schedulerFields.Resource_API_Name__c)) {
			throw new SchedulerFieldMappingException('Resource object ' + schedulerFields.Resource_API_Name__c + ' not found');
		}

		Map<String, SObjectField> resourceObjectFields = schemaGlobalDescribeResult.get(schedulerFields.Resource_API_Name__c).getDescribe().fields.getMap();

		for (String field : fieldsToRetrieve) {
			if (!resourceObjectFields.containsKey(field)) {
				throw new SchedulerFieldMappingException('Field ' + field + ' not found on ' + schedulerFields.Resource_API_Name__c + ' object');
			}

			if (!resourceObjectFields.get(field).getDescribe().isAccessible()) {
				throw new SchedulerFieldMappingException('Not enough access to a field ' + field + ' on ' + schedulerFields.Resource_API_Name__c + ' object');
			}
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

		for (SObject resource : queriedResources) {
			SchedulerResource schedulerResource = new SchedulerResource(resource, schedulerFields);

			resources.put(resource.Id, schedulerResource);

			if (schedulerResource.parentResource != null) {
				resources.get(schedulerResource.parentResource).children.add(schedulerResource);
			}
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
		Scheduler_Fields__mdt schedulerFields = getSchedulerFieldMapping(fieldMappingMetadataName);

		List<ResourceColumn> columns = new List<ResourceColumn>();

		List<String> fields = schedulerFields.Resource_Display_Columns_API_Fields__c.toLowerCase().split(',');

		if (fields.isEmpty()) {
			return columns;
		}

		Map<String, SObjectField> fieldsDescribeSource = Schema.getGlobalDescribe().get(schedulerFields.Resource_API_Name__c).getDescribe().fields.getMap();

		for (String field : fields) {
			String trimmedField = field.trim();

			if (!fieldsDescribeSource.containsKey(trimmedField)) {
				throw new SchedulerFieldMappingException('Field ' + trimmedField + ' not found');
			}

			DescribeFieldResult describeFieldResult = fieldsDescribeSource.get(trimmedField).getDescribe();

			ResourceColumn resourceColumn = new ResourceColumn();

			resourceColumn.text = describeFieldResult.getLabel();
			resourceColumn.field = describeFieldResult.getName();

			columns.add(resourceColumn);
		}

		return columns;
	}

	private static List<SchedulerEvent> getEvents(String fieldMappingMetadataName, Datetime startTime, Datetime endTime, String eventCustomFilter) {
		Scheduler_Fields__mdt schedulerFields = getSchedulerFieldMapping(fieldMappingMetadataName);

		Set<String> fieldsToRetrieve = new Set<String> {
			schedulerFields.Event_Start_Date_API_Field__c,
			schedulerFields.Event_End_Date_API_Field__c,
			schedulerFields.Event_Name_API_Field__c,
			schedulerFields.Event_Parent_Resource_API_Field__c,
			schedulerFields.Event_Color_API_Field__c,
			schedulerFields.Event_Icon_API_Field__c
		};

		if (String.isNotEmpty(schedulerFields.Event_Tooltip_Fields__c)) {
			fieldsToRetrieve.addAll(schedulerFields.Event_Tooltip_Fields__c.replaceAll(' ', '').split(','));
		}

		Map<String, SObjectType> schemaGlobalDescribeResult = Schema.getGlobalDescribe();

		if (!schemaGlobalDescribeResult.containsKey(schedulerFields.Event_API_Name__c)) {
			throw new SchedulerFieldMappingException('Event object ' + schedulerFields.Event_API_Name__c + ' not found');
		}

		Map<String, SObjectField> eventObjectFields = schemaGlobalDescribeResult.get(schedulerFields.Event_API_Name__c).getDescribe().fields.getMap();

		for (String field : fieldsToRetrieve) {
			if (!eventObjectFields.containsKey(field)) {
				throw new SchedulerFieldMappingException('Field ' + field + ' not found on ' + schedulerFields.Event_API_Name__c + ' object');
			}

			if (!eventObjectFields.get(field).getDescribe().isAccessible()) {
				throw new SchedulerFieldMappingException('Not enough access to a field ' + field + ' on ' + schedulerFields.Event_API_Name__c + ' object');
			}
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
	public static List<SchedulerTimeRange> getMaintenanceTimeRanges(String fieldMappingMetadataName, Datetime startTime, Datetime endTime, List<Id> resources) {
		Scheduler_Fields__mdt schedulerFields = getSchedulerFieldMapping(fieldMappingMetadataName);

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

		List<SchedulerTimeRange> result = new List<SchedulerTimeRange>();

		for (SObject timeRangeRecord : queriedRanges) {
			SchedulerTimeRange timeRange = new SchedulerTimeRange(timeRangeRecord, schedulerFields);

			result.add(timeRange);
		}

		return result;
	}

	private static Scheduler_Fields__mdt getSchedulerFieldMapping(String fieldMappingMetadataName) {
		if (schedulerFieldMapping != null) {
			return schedulerFieldMapping;
		}

		if (!Scheduler_Fields__mdt.getSObjectType().getDescribe().isAccessible()) {
			throw new SchedulerFieldMappingException('Not enough access to Scheduler Fields custom metadata record');
		}

		Set<String> fieldsToRetrieve = new Set<String>();

		for (SObjectField field : Scheduler_Fields__mdt.getSObjectType().getDescribe().fields.getMap().values()) {
			if (!field.getDescribe().isAccessible()) {
				throw new SchedulerFieldMappingException('Not enough access to ' + field.getDescribe().getName() + ' field on Scheduler Fields custom metadata record');
			} else {
				fieldsToRetrieve.add(field.getDescribe().getName());
			}
		}

		List<Scheduler_Fields__mdt> schedulerFields = Database.query('SELECT ' + String.join(new List<String>(fieldsToRetrieve), ',') + ' FROM ' + Scheduler_Fields__mdt.getSObjectType().getDescribe().getName() + ' WHERE DeveloperName = :fieldMappingMetadataName');

		if (schedulerFields.isEmpty()) {
			throw new SchedulerFieldMappingException('Scheduler Fields record with Name ' + fieldMappingMetadataName + ' not found');
		}

		schedulerFieldMapping = schedulerFields[0];

		return schedulerFieldMapping;
	}

	private static String getPackagedName(String name) {
		return (SchedulerControllerV2.class.getName().contains('.') ? SchedulerControllerV2.class.getName().substringBefore('.') + '__' : '') + name;
	}

	public class SchedulerData {
		@AuraEnabled
		public List<SchedulerResource> resources = new List<SchedulerResource>();
		@AuraEnabled
		public List<SchedulerEvent> events = new List<SchedulerEvent>();
		@AuraEnabled
		public List<ResourceColumn> resourceColumns = new List<ResourceColumn>();
		@AuraEnabled
		public List<SchedulerTimeRange> maintenanceTimeRanges = new List<SchedulerTimeRange>();
		@AuraEnabled
		public List<String> eventEditFields = new List<String>();
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
		public List<SchedulerEvent> events = new List<SchedulerEvent>();
		@AuraEnabled
		public List<SchedulerResource> children = new List<SchedulerResource>();

		@AuraEnabled
		public SObject resourceRecord;

		public SchedulerResource(SObject resource, Scheduler_Fields__mdt schedulerFields) {
			id = resource.Id;
			name = String.valueOf(resource.get(schedulerFields.Event_Name_API_Field__c));

			if (resource.get(schedulerFields.Resource_Parent_Resource_API_Field__c) != null) {
				parentResource = String.valueOf(resource.get(schedulerFields.Resource_Parent_Resource_API_Field__c));
			}

			if (resource.get(schedulerFields.Resource_Icon_API_Field__c) != null) {
				iconCls = String.valueOf(resource.get(schedulerFields.Resource_Icon_API_Field__c));
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
		public Datetime startDate;
		@AuraEnabled
		public Datetime endDate;
		@AuraEnabled
		public String name;
		@AuraEnabled
		public Id resourceId;
		@AuraEnabled
		public String eventColor;
		@AuraEnabled
		public String iconCls;
		@AuraEnabled
		public SObject eventRecord;

		public SchedulerEvent(SObject event, Scheduler_Fields__mdt schedulerFields) {
			id = event.Id;
			startDate = Datetime.valueOf(event.get(schedulerFields.Event_Start_Date_API_Field__c));
			endDate = Datetime.valueOf(event.get(schedulerFields.Event_End_Date_API_Field__c));
			name = String.valueOf(event.get(schedulerFields.Event_Name_API_Field__c));
			resourceId = String.valueOf(event.get(schedulerFields.Event_Parent_Resource_API_Field__c));

			if (event.get(schedulerFields.Event_Color_API_Field__c) != null) {
				eventColor = String.valueOf(event.get(schedulerFields.Event_Color_API_Field__c));
			} else {
				eventColor = schedulerFields.Event_Color__c;
			}

			if (event.get(schedulerFields.Event_Icon_API_Field__c) != null) {
				iconCls = String.valueOf(event.get(schedulerFields.Event_Icon_API_Field__c));
			} else {
				iconCls = schedulerFields.Event_Icon__c;
			}

			eventRecord = event;
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
		public Id resourceId;

		public SchedulerTimeRange(SObject resourceTimeRange, Scheduler_Fields__mdt schedulerFields) {
			id = resourceTimeRange.Id;
			startDate = Datetime.valueOf(resourceTimeRange.get(schedulerFields.Resource_Maintenance_Start_API_Field__c));
			endDate = Datetime.valueOf(resourceTimeRange.get(schedulerFields.Resource_Maintenance_End_API_Field__c));
			resourceId = String.valueOf(resourceTimeRange.get(schedulerFields.Resource_Maintenance_Resource_API_Field__c));
		}
	}

	public class ResourceColumn {
		@AuraEnabled
		public String text;
		@AuraEnabled
		public String field;
		@AuraEnabled
		public Boolean sortable = false;
		@AuraEnabled
		public Boolean draggable = false;
	}

	public class SchedulerFieldMappingException extends Exception {}
	public class SchedulerException extends Exception {}

}