DEPENDENCIES
----

You need to install the perl module "WWW::Salesforce".

For example via cpanm:

```
cpanm WWW::Salesforce
```


SOAP-API (WITH SYNC SCRIPTS)
----




AVAILABLE API
----

    • ConvertLead()         - Converts a Lead into an Account, Contact, or (optionally) an Opportunity
    • Create()              - Adds one new individual objects to your organization's data
    • Delete()              - Deletes one or more individual objects from your organization's data
    • DescribeGlobal()      - Retrieves a list of available objects for your organization's data
    • DescribeLayout()      - Describes metadata about a given page layout, including layouts for edit and display-only views and record type mappings
    • DescribeSObject()     - Describes metadata (field list and object properties) for the specified object
    • DescribeSObjects()    - An array based version of DescribeSObject()
    • DescribeTabs()        - Use the DescribeTabs call to obtain information about the standard and custom apps to which the logged-in user has access
    • GetSessionID()        - Gets the Salesforce SID
    • GetUserID()           - Gets the Salesforce UID
    • GetUserName()         - Gets the Salesforce Username
    • GetUserInfo()         - Retrieves personal information for the user associated with the current session
    • ResetPassword()       - Changes a user's password to a server-generated value
    • SetPassword()         - Sets the specified user's password to the specified value
    • Logout()              - Ends the session for the logged-in user issuing the call
    • GetServerTimeStamp()  - Retrieves the current system timestamp (GMT) from the Salesforce web service
    • SFDate()              - Converts the current system time in Epoch seconds to the date format that Salesforce likes
    • GetDeleted()          - Retrieves the list of individual objects that have been deleted within the given time span for the specified object
    • GetUpdated()          - Retrieves the list of individual objects that have been updated (added or changed)
    • Query()               - Executes a query against the specified object and returns data that matches the specified criteria
    • DoQuery()             - Returns a reference to an array of hash refs (similar to Query)
    • QueryAll()            - Executes a query against the specified object and returns data that matches the specified criteria including archived and deleted objects
    • DoQueryAll()          - Returns a reference to an array of hash refs (similar to QueryAll)
    • QueryMore()           - Retrieves the next batch of objects from a query or queryAll
    • Search()              - Use search() to search for records based on a search string
    • GetFieldList()        - Returns a ref to an array of hash refs for each field name Field name keyed as 'name'
    • GetTables()           - Returns a ref to an array of hash refs for each field name Field name keyed as 'name'
    • Retrieve()            - Use the Retrieve() call to retrieve individual records from an object
    • Update()              - Updates one or more existing objects in your organization's data
    • UpSert()              - Updates or inserts one or more objects in your organization's data
    • DescribeMetadata()    - Get some metadata info about your instance
    • RetrieveMetadata()    - Retrieve some metadata info about your instance
    • CheckAsyncStatus()    - Check whether or not an asynchronous metadata call or declarative metadata call has completed
    • CheckRetrieveStatus() - Checks the status of the declarative metadata call retrieve() and returns the zip file contents
    • GetErrorDetails()     - Returns a hash with information about errors from API calls - only useful if ($res->valueof('//success') ne 'true')



CUSTOMER DATA SYNC SCRIPTS
----

Execute via Commandline or Cronjob (OTRS SysConfig).

    • SyncCompanies.pm     - Synchronize customer companies into OTRS
    • SyncCustomers.pm     - Synchronize customer users into OTRS



CUSTOMER DATA SYNC VIA COMMANDLINE EXAMPLE
----

Fetch all customer data using salesforce SOAP API.



COMMANDS
-------------------------

    • perl /opt/otrs/bin/otrs.Console.pl Admin::SalesForce::SyncCompanies --companies-limit 1
    • perl /opt/otrs/bin/otrs.Console.pl Admin::SalesForce::SyncCustomers --customers-limit 1


For more information see pdf documentation.



RESPONSE API EXAMPLE
-------------------------

    bless( {
        'type' => 'Account',
        'Owner' => bless( {
                        'Id' => [
                                    '0050Y0000037aCXQAY',
                                    '0050Y0000037aCXQAY'
                                ],
                        'type' => 'User'
                    }, 'sObject' ),
        'Id' => undef
    }, 'sObject' ),


*Contact us on https://ciphron.de/
