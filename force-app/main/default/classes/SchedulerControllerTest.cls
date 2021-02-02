@IsTest
public without sharing class SchedulerControllerTest {

	@TestSetup
	private static void createTestData() {
		List<PermissionSetAssignment> assignments = [
			SELECT Id
			FROM PermissionSetAssignment
			WHERE AssigneeId = :UserInfo.getUserId()
			AND PermissionSetId = :[
				SELECT Id
				FROM PermissionSet
				WHERE Name LIKE '%MYCE_Admin%'
			].Id
		];

		if (assignments.isEmpty()) {
			insert new PermissionSetAssignment(
				AssigneeId = UserInfo.getUserId(),
				PermissionSetId = [
					SELECT Id
					FROM PermissionSet
					WHERE Name LIKE '%MYCE_Admin%'
				].Id
			);
		}

		System.runAs([
				SELECT Id
				FROM User
				WHERE Id = :UserInfo.getUserId()
		][0]) {
			SP_Resource__c resource = new SP_Resource__c(
					Name = 'Test'
			);
			insert resource;

			SP_Event__c event = new SP_Event__c(
					Parent_Resource__c = resource.Id,
					Start_Date__c = System.now(),
					End_Date__c = System.now().addHours(1)
			);
			insert event;
		}
	}

	@IsTest
	private static void testGetData() {
		System.runAs([
				SELECT Id
				FROM User
				WHERE Id = :UserInfo.getUserId()
		][0]) {
			String dataJSON = SchedulerController.getData(System.now(), 'day', null, '', '', new List<Id>(), new List<String>());
			Map<String, Object> data = (Map<String, Object>)JSON.deserializeUntyped(dataJSON);

			System.assert(data.containsKey('namespace'));
			System.assert(data.containsKey('mapping'));
			System.assert(data.containsKey('resources'));
			System.assert(data.containsKey('events'));
			System.assert(data.containsKey('resourceDisplayColumns'));

			System.assertEquals(1, ((Map<String, Object>)data.get('events')).keySet().size());
			System.assertEquals(1, ((Map<String, Object>)data.get('resources')).keySet().size());

			System.assertEquals(SchedulerControllerTest.class.getName().contains('.') ? SchedulerControllerTest.class.getName().substringBefore('.') : '', data.get('namespace'));
		}
	}
	@IsTest
	private static void testGetData_week() {
		System.runAs([
				SELECT Id
				FROM User
				WHERE Id = :UserInfo.getUserId()
		][0]) {
			String dataJSON = SchedulerController.getData(System.now(), 'week', null, '', '', new List<Id>(), new List<String>());
			Map<String, Object> data = (Map<String, Object>)JSON.deserializeUntyped(dataJSON);

			System.assert(data.containsKey('namespace'));
			System.assert(data.containsKey('mapping'));
			System.assert(data.containsKey('resources'));
			System.assert(data.containsKey('events'));
			System.assert(data.containsKey('resourceDisplayColumns'));

			System.assertEquals(1, ((Map<String, Object>)data.get('events')).keySet().size());
			System.assertEquals(1, ((Map<String, Object>)data.get('resources')).keySet().size());

			System.assertEquals(SchedulerControllerTest.class.getName().contains('.') ? SchedulerControllerTest.class.getName().substringBefore('.') : '', data.get('namespace'));
		}
	}

	@IsTest
	private static void testGetData_month() {
		System.runAs([
				SELECT Id
				FROM User
				WHERE Id = :UserInfo.getUserId()
		][0]) {
			String dataJSON = SchedulerController.getData(System.now(), 'month', null, '', '', new List<Id>(), new List<String>());
			Map<String, Object> data = (Map<String, Object>)JSON.deserializeUntyped(dataJSON);

			System.assert(data.containsKey('namespace'));
			System.assert(data.containsKey('mapping'));
			System.assert(data.containsKey('resources'));
			System.assert(data.containsKey('events'));
			System.assert(data.containsKey('resourceDisplayColumns'));

			System.assertEquals(1, ((Map<String, Object>)data.get('events')).keySet().size());
			System.assertEquals(1, ((Map<String, Object>)data.get('resources')).keySet().size());

			System.assertEquals(SchedulerControllerTest.class.getName().contains('.') ? SchedulerControllerTest.class.getName().substringBefore('.') : '', data.get('namespace'));
		}
	}

	@IsTest
	private static void testUpdateEvent() {
		SP_Event__c event = new SP_Event__c(
			Name = 'Test'
		);

		insert event;

		System.assertEquals(null, event.Start_Date__c);
		System.assertEquals(null, event.End_Date__c);

		event.Start_Date__c = Datetime.now().addDays(-1);
		event.End_Date__c = Datetime.now().addDays(1);

		System.assertEquals('', SchedulerController.updateEvent(new Map<String, Object> {
			'Id' => event.Id,
			'Start_Date__c' => Datetime.now().addDays(-1),
			'End_Date__c' => Datetime.now().addDays(1)
		}, [
			SELECT Id
			FROM Scheduler_Fields__mdt
			WHERE DeveloperName = 'Default'
			LIMIT 1
		].Id));

		event = [
			SELECT Id, Start_Date__c, End_Date__c
			FROM SP_Event__c
			WHERE Id = :event.Id
		];

		System.assertNotEquals(null, event.Start_Date__c);
		System.assertNotEquals(null, event.End_Date__c);
	}

	@IsTest
	private static void getPicklistDataTest() {
		String data = SchedulerController.getPicklistData(null);

		Map<String, Object> parsedData = (Map<String, Object>)JSON.deserializeUntyped(data);

		System.assert(parsedData.containsKey('hotels'));
		System.assert(parsedData.containsKey('types'));
	}

	@IsTest
	private static void testUpdateEvent_Resource() {
		SP_Resource__c resource = [
				SELECT Id
				FROM SP_Resource__c
				LIMIT 1
		];

		insert new SP_Resource_Opening_Hours__c(
				Name = 'Test',
				Resource__c = resource.Id,
				Days__c = 'Monday;Tuesday;Wednesday;Thursday;Friday;Saturday;Sunday',
				Start_Time__c = Time.newInstance(0, 0, 0, 0),
				End_Time__c = Time.newInstance(23, 59, 59, 59)
		);


		SP_Event__c event = new SP_Event__c(
				Name = 'Test',
				Parent_Resource__c = resource.Id
		);

		insert event;

		System.assertEquals(null, event.Start_Date__c);
		System.assertEquals(null, event.End_Date__c);

		event.Start_Date__c = Datetime.now().addDays(-1);
		event.End_Date__c = Datetime.now().addDays(1);

		event = [
				SELECT Id, Start_Date__c, End_Date__c
				FROM SP_Event__c
				WHERE Id = :event.Id
		];

	}
	@IsTest
	private static void checkResourceBookableTest() {
		SP_Resource__c resource = [
				SELECT Id
				FROM SP_Resource__c
				LIMIT 1
		];
		insert new SP_Resource_Opening_Hours__c(
				Name = 'Test',
				Resource__c = resource.Id,
				Days__c = Datetime.now().format('EEEE'),
				Start_Time__c = Time.newInstance(0, 0, 0, 0),
				End_Time__c = Time.newInstance(23, 59, 59, 59)
		);

		Id schedulerFields = [SELECT Id FROM Scheduler_Fields__mdt WHERE DeveloperName = 'Default' LIMIT 1].Id;
		String endTime = '2020-09-06 14:14:00.000Z';
		String startTime = '2020-09-08 18:00:00.000Z';

		String response1 = SchedulerController.checkResourceBookable(null, schedulerFields, endTime, startTime);
		String response2 = SchedulerController.checkResourceBookable(resource.Id, schedulerFields, endTime, startTime);
		startTime = '2020-09-06 12:00:00.000Z';
		String response3 = SchedulerController.checkResourceBookable(resource.Id, schedulerFields, endTime, startTime);
		System.debug('-----------------------------------------------------------------------------');
		System.debug('response1');
		System.debug(response1);
		System.debug('-----------------------------------------------------------------------------');
		System.debug('-----------------------------------------------------------------------------');
		System.debug('response2');
		System.debug(response2);
		System.debug('-----------------------------------------------------------------------------');
		System.debug('-----------------------------------------------------------------------------');
		System.debug('response3');
		System.debug(response3);
		System.debug('-----------------------------------------------------------------------------');
	}
}