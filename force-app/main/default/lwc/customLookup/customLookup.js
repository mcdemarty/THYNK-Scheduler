import search from '@salesforce/apex/CustomLookupHelper.search';
import { api, LightningElement, track, wire } from 'lwc';


export default class customLookup extends LightningElement {

@api isRequired = false;
@api prepopulate = false;
@api record;
@api objName;
@api recordField='';
@api fieldApiName='';
@api iconName;
@api label;
@api filter = '';
@api searchPlaceholder='Search';
@api withoutDuplicates=false;

@track selectedName;
@track records;
@track isValueSelected;
@track blurTimeout;

  searchTerm;
  //css
@track boxClass = 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click slds-has-focus';
@track inputClass = '';

@wire(search, {
    searchTerm : '$searchTerm',
    fieldApiName : '$fieldApiName',
    myObject : '$objName',
    filter : '$filter',
    removeDuplicates : '$withoutDuplicates'
  })
  wiredRecords({ error, data }) {
    if (data) {
      this.error = undefined;
      this.records = data;
    } else if (error) {
      console.log('error');
      this.error = error;
      this.records = undefined;
    }
  }

  connectedCallback() {
    if (this.prepopulate && this.record[this.recordField]) {
      this.setLookupValue(this.record[this.recordField]);
    }
  }

  handleClick() {
    this.searchTerm = '';
    this.inputClass = 'slds-has-focus';
    this.boxClass = 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click slds-has-focus slds-is-open';
  }

  onBlur() {
    this.blurTimeout = setTimeout(() =>  {this.boxClass = 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click slds-has-focus'}, 300);
  }

  onSelect(event) {
    let selectedId = event.currentTarget.dataset.id;
    let selectedName = event.currentTarget.dataset.name;
    const valueSelectedEvent = new CustomEvent('lookupselected', {detail:  selectedId });
    this.dispatchEvent(valueSelectedEvent);
    const dataRetrievedEvent = new CustomEvent('lookupdataretrieved', {detail:  selectedName });
    this.dispatchEvent(dataRetrievedEvent);
    this.isValueSelected = true;
    this.selectedName = selectedName;
    if(this.blurTimeout) {
      clearTimeout(this.blurTimeout);
    }
    this.boxClass = 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click slds-has-focus';
  }

  setLookupValue(value) {
    search({
       searchTerm : '',
       fieldApiName : this.fieldApiName,
       myObject : this.objName,
       filter : this.filter,
       removeDuplicates : this.withoutDuplicates
     })
    .then(records => {
      var selectedRecord = records.find(rec => rec.Id == this.record[this.recordField]);
      this.onSelect({
        currentTarget: {
          dataset: {
            id: selectedRecord.Id,
            name: selectedRecord.Name
          }
        }
      });
  });
  }

@api
  handleRemovePill() {
    this.isValueSelected = false;
    this.searchTerm = '';

    const valueResetEvent = new CustomEvent('lookupreset');
    this.dispatchEvent(valueResetEvent);
  }

  onChange(event) {
    this.searchTerm = event.target.value;
  }

  get hasLabel() {
    return this.label;
  }

}