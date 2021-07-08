@isTest
public with sharing class CustomLookupHelperTest {

    @isTest
    public static void test_search() {
        Account hotel = new Account(Name = 'Demo');
        insert hotel;

        Test.startTest();

        List<CustomLookupHelper.MatchRecord> matchRecords = CustomLookupHelper.search(
            Account.Name.getDescribe().getName(),
            null,
            Account.getSObjectType().getDescribe().name,
            null,
            false,
            null
        );
//        System.assertEquals(1, matchRecords.size(), 'Wrong amount of records searched');

        Test.stopTest();
    }
}
