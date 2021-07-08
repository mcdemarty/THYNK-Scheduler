public with sharing class CustomLookupHelper {

    @AuraEnabled(cacheable=true)
    public static List<MatchRecord> search(
        String fieldApiName,
        String searchTerm,
        String myObject,
        String filter,
        Boolean removeDuplicates
    ) {
        String myQuery = null;
        String fieldToFilter = String.isNotBlank(fieldApiName) && fieldApiName != 'Id' ? fieldApiName : 'Name';
        if(filter != null && filter != ''){
            myQuery = 'Select Id, ' + fieldToFilter + ' from '+myObject+' Where ' + fieldToFilter + ' Like  \'%' + searchTerm + '%\' AND '+filter+' LIMIT  5';
        }
        else {
            if(searchTerm == null || searchTerm == ''){
                myQuery = 'Select Id, ' + fieldToFilter + ' from '+myObject+' Where LastViewedDate != NULL ORDER BY LastViewedDate DESC LIMIT  5';
            }
            else {
                myQuery = 'Select Id, ' + fieldToFilter + ' from '+myObject+' Where ' + fieldToFilter + ' Like  \'%' + searchTerm + '%\' LIMIT  5';
            }
        }
        List<sObject> lookUpList = database.query(myQuery);
        Set<String> filteredValues = new Set<String>();

        List<MatchRecord> recordsToReturn = new List<MatchRecord>();

        for (sObject sObj : lookUpList) {
            String fieldValue = (String) sObj.get(fieldToFilter);
            if (String.isNotBlank(fieldValue)) {
                if (removeDuplicates) {
                    if (!filteredValues.contains(fieldValue)) {
                        filteredValues.add(fieldValue);
                        recordsToReturn.add(
                            new MatchRecord(sObj.Id, fieldValue)
                        );
                    }
                } else {
                    recordsToReturn.add(
                        new MatchRecord(sObj.Id, fieldValue)
                    );
                }
            }
        }
        System.debug(recordsToReturn);
        return recordsToReturn;
    }

    public class MatchRecord {
        @AuraEnabled
        public Id Id;
        @AuraEnabled
        public String Name;

        public MatchRecord(Id recordId, String recordName) {
            this.Id = recordId;
            this.Name = recordName;
        }
    }
}