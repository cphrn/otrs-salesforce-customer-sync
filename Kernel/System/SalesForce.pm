# --
# Copyright (C) 2019 CIPHRON GmbH, https://ciphron.de/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::SalesForce;

use strict;
use warnings;

use WWW::Salesforce;

our @ObjectDependencies = (
    'Kernel::System::Cache',
    'Kernel::System::Log',
);

=head1 NAME

Kernel::System::SalesForce - salesforce lib

=head1 DESCRIPTION

All salesforce functions.

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $SalesForceObject = $Kernel::OM->Get('Kernel::System::SalesForce');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    my $ConfigObject         = $Kernel::OM->Get('Kernel::Config');

    my $SF_MODULE            = $Param{SF}                           || $ConfigObject->{'SalesForceModule'};
    if ( $SF_MODULE ) {

        my $SF_PROXY         = $Param{SF_PROXY}                     || $ConfigObject->{'SalesForceModule::Proxy'};
        if ( $SF_PROXY ) {
            $WWW::Salesforce::SF_PROXY = $SF_PROXY;
        }

        my $SF_URI           = $Param{SF_URI}                       || $ConfigObject->{'SalesForceModule::BaseUrl'};
        if ( $SF_URI ) {
            $WWW::Salesforce::SF_URI = $SF_URI;
        }

        my $SF_PREFIX        = $Param{SF_PREFIX}                    || $ConfigObject->{'SalesForceModule::Prefix'};
        if ( $SF_PREFIX ) {
            $WWW::Salesforce::SF_PREFIX = $SF_PREFIX;
        }

        my $SF_SOBJECT_URI   = $Param{SF_SOBJECT_URI}               || $ConfigObject->{'SalesForceModule::SObjectUrl'};
        if ( $SF_SOBJECT_URI ) {
            $WWW::Salesforce::SF_SOBJECT_URI = $SF_SOBJECT_URI;
        }

        my $SF_URIM          = $Param{SF_URIM}                      || $ConfigObject->{'SalesForceModule::MetaDataUrl'};
        if ( $SF_URIM ) {
            $WWW::Salesforce::SF_URIM = $SF_URIM;
        }

        my $SF_APIVERSION    = $Param{SF_APIVERSION}                || $ConfigObject->{'SalesForceModule::APIVersion'};
        if ( $SF_APIVERSION ) {
            $WWW::Salesforce::SF_APIVERSION = $SF_APIVERSION;
        }

        my $WEB_PROXY        = $Param{WEB_PROXY}                    || $ConfigObject->{'SalesForceModule::WebProxy'};
        if ( $WEB_PROXY ) {
            $WWW::Salesforce::WEB_PROXY = $WEB_PROXY;
        }

        my $SF_AUTHUSER      = $Param{SF_AUTHUSER}                  || $ConfigObject->{'SalesForceModule::AuthUser'};
        my $SF_AUTHPASSWORD  = $Param{SF_AUTHPASSWORD}              || $ConfigObject->{'SalesForceModule::AuthPassword'};
        my $SF_AUTHSECTOKEN  = $Param{SF_AUTHSECTOKEN}              || $ConfigObject->{'SalesForceModule::AuthSecToken'};

        if (
            $SF_AUTHUSER
            && $SF_AUTHPASSWORD
            && $SF_AUTHSECTOKEN
        ) {
            eval {
                $Self->{Auth} = WWW::Salesforce->login(
                    'username' => $SF_AUTHUSER,
                    'password' => "$SF_AUTHPASSWORD$SF_AUTHSECTOKEN",
                );
            } or do {
                my $Error = $@;
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "Could not login to salesforce (Error: $Error)",
                );
            }
        }
    }

    return $Self;
}

=head2 ConvertLead()

Converts a Lead into an Account, Contact, or (optionally) an Opportunity

    my $Lead = $SalesForceObject->ConvertLead(
        LeadID        => [ 2345, 5678, ],
        ContactID     => [ 9876, 7541, ], or (AccountID | OpportunityID)
    );

=cut

sub ConvertLead {
    my ( $Self, %Param ) = @_;

    # check auth
    if ( !$Self->{Auth} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Check: SalesForceModule Configuration!',
        );
        return;
    }

    # check needed stuff
    if ( !$Param{LeadID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need: LeadID!',
        );
        return;
    }

    # check valid ref type
    for (qw( LeadID ContactID AccountID OpportunityID )) {
        if ( $Param{$_} && ref($Param{$_}) ne 'ARRAY' ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Not a Array Reference: $_!"
            );
            return;
        }
    }

    my $Result = $Self->{Auth}->ConvertLead(
        leadId        => $Param{LeadID},
        contactId     => $Param{ContactID},
        accountId     => $Param{AccountID},
        opportunityId => $Param{OpportunityID},
    )
    ->result();

    return $Result;
}

=head2 Create()

Adds one new individual objects to your organization's data
This takes as input a HASH containing the fields (the keys of the hash)
and the values of the record you wish to add to your organization
The hash must contain the 'type' key in order to identify the type of the record to add

    my $Created = $SalesForceObject->Create(
        Type    => 'Account',
        Name    => 'Test',
        ...                  # see other fields in tables
    );

=cut

sub Create {
    my ( $Self, %Param ) = @_;

    # check auth
    if ( !$Self->{Auth} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Check: SalesForceModule Configuration!',
        );
        return;
    }

    # check needed stuff
    for (qw( Type Name )) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need: $_!"
            );
            return;
        }
    }

    my $Result = $Self->{Auth}->Create(
        type => $Param{Type},
        name => $Param{Name},
    )
    ->result();

    return $Result;
}

=head2 Delete()

Deletes one or more individual objects from your organization's data
This subroutine takes as input an array of SCALAR values, where each SCALAR is an sObjectId

    my $Deleted = $SalesForceObject->Delete(
       IDs => [ '0011i000007KbwPAAS', ],
    );

=cut

sub Delete {
    my ( $Self, %Param ) = @_;

    # check auth
    if ( !$Self->{Auth} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Check: SalesForceModule Configuration!',
        );
        return;
    }

    # check needed stuff
    if ( !$Param{IDs} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need: IDs!',
        );
        return;
    }

    # check valid ref type
    if ( ref($Param{IDs}) ne 'ARRAY' ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Not a Array Reference: IDs!"
        );
        return;
    }

    my $Result = $Self->{Auth}->delete(
        ids => $Param{IDs},
    )
    ->result();

    return $Result;
}

=head2 DescribeGlobal()

Retrieves a list of available objects for your organization's data
You can then iterate through this list and use describeSObject() to obtain metadata about individual objects

    my $ObjectList = $SalesForceObject->DescribeGlobal();

=cut

sub DescribeGlobal {
    my ( $Self, %Param ) = @_;

    # check auth
    if ( !$Self->{Auth} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Check: SalesForceModule Configuration!',
        );
        return;
    }

    my $Result = $Self->{Auth}->describeGlobal()->result();

    return $Result;
}

=head2 DescribeLayout()

Describes metadata about a given page layout, including layouts for edit and display-only views and record type mappings

    my $MetaData = $SalesForceObject->DescribeLayout(
        Type => 'Account',
    );

=cut

sub DescribeLayout {
    my ( $Self, %Param ) = @_;

    # check auth
    if ( !$Self->{Auth} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Check: SalesForceModule Configuration!',
        );
        return;
    }

    # check needed stuff
    if ( !$Param{Type} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need: Type!',
        );
        return;
    }

    my $Result = $Self->{Auth}->describeLayout(
        type => $Param{Type},
    )
    ->result();

    return $Result;
}

=head2 DescribeSObject()

Describes metadata (field list and object properties) for the specified object

    my $MetaData = $SalesForceObject->DescribeSObject(
        Type => 'Account',
    );

=cut

sub DescribeSObject {
    my ( $Self, %Param ) = @_;

    # check auth
    if ( !$Self->{Auth} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Check: SalesForceModule Configuration!',
        );
        return;
    }

    # check needed stuff
    if ( !$Param{Type} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need: Type!',
        );
        return;
    }

    my $Result = $Self->{Auth}->describeSObject(
        type => $Param{Type},
    )
    ->result();

    return $Result;
}

=head2 DescribeSObjects()

An array based version of DescribeSObject;
describes metadata (field list and object properties) for the specified object or array of objects

    my $MetaData = $SalesForceObject->DescribeSObjects(
        Type => [ 'Account','Contact','CustomObject__c', ],
    );

=cut

sub DescribeSObjects {
    my ( $Self, %Param ) = @_;

    # check auth
    if ( !$Self->{Auth} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Check: SalesForceModule Configuration!',
        );
        return;
    }

    # check needed stuff
    if ( !$Param{Type} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need: Type!',
        );
        return;
    }

    # check valid ref type
    if ( ref($Param{Type}) ne 'ARRAY' ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Not a Array Reference: Type!"
        );
        return;
    }

    my $Result = $Self->{Auth}->describeSObjects(
        type => $Param{Type},
    )
    ->result();

    return $Result;
}

=head2 DescribeTabs()

Use the DescribeTabs call to obtain information about the standard and custom apps to which the logged-in user has access
The DescribeTabs call returns the minimum required metadata that can be used to render apps in another user interface
Typically this call is used by partner applications to render Salesforce data in another user interface

    my $MetaData = $SalesForceObject->DescribeTabs();

=cut

sub DescribeTabs {
    my ( $Self, %Param ) = @_;

    # check auth
    if ( !$Self->{Auth} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Check: SalesForceModule Configuration!',
        );
        return;
    }

    my $Result = $Self->{Auth}->describeTabs()->result();

    return $Result;
}

=head2 GetSessionID()

Gets the Salesforce SID

    my $SID = $SalesForceObject->GetSessionID();

=cut

sub GetSessionID {
    my ( $Self, %Param ) = @_;

    # check auth
    if ( !$Self->{Auth} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Check: SalesForceModule Configuration!',
        );
        return;
    }

    my $Result = $Self->{Auth}->get_session_id();

    return $Result;
}

=head2 GetUserID()

Gets the Salesforce UID

    my $UID = $SalesForceObject->GetUserID();

=cut

sub GetUserID {
    my ( $Self, %Param ) = @_;

    # check auth
    if ( !$Self->{Auth} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Check: SalesForceModule Configuration!',
        );
        return;
    }

    my $Result = $Self->{Auth}->get_user_id();

    return $Result;
}

=head2 GetUserName()

Gets the Salesforce Username

    my $Username = $SalesForceObject->GetUserName();

=cut

sub GetUserName {
    my ( $Self, %Param ) = @_;

    # check auth
    if ( !$Self->{Auth} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Check: SalesForceModule Configuration!',
        );
        return;
    }

    my $Result = $Self->{Auth}->get_username();

    return $Result;
}

=head2 GetUserInfo()

Retrieves personal information for the user associated with the current session

    my $UserInfo = $SalesForceObject->GetUserInfo();

=cut

sub GetUserInfo {
    my ( $Self, %Param ) = @_;

    # check auth
    if ( !$Self->{Auth} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Check: SalesForceModule Configuration!',
        );
        return;
    }

    my $Result = $Self->{Auth}->getUserInfo()->result();

    return $Result;
}

=head2 ResetPassword()

Changes a user's password to a server-generated value

    my $Password = $SalesForceObject->ResetPassword(
        UserID => 5,
    );

=cut

sub ResetPassword {
    my ( $Self, %Param ) = @_;

    # check auth
    if ( !$Self->{Auth} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Check: SalesForceModule Configuration!',
        );
        return;
    }

    # check needed stuff
    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need: UserID!"
        );
        return;
    }

    my $Result = $Self->{Auth}->resetPassword(
        userId => $Param{UserID},
    )
    ->result();

    return $Result;
}

=head2 SetPassword()

Sets the specified user's password to the specified value

    my $Password = $SalesForceObject->SetPassword(
        UserID   => 5,
        Password => 'Test',
    );

=cut

sub SetPassword {
    my ( $Self, %Param ) = @_;

    # check auth
    if ( !$Self->{Auth} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Check: SalesForceModule Configuration!',
        );
        return;
    }

    # check needed stuff
    for (qw( UserID Password )) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need: $_!"
            );
            return;
        }
    }

    my $Result = $Self->{Auth}->setPassword(
        userId   => $Param{UserID},
        password => $Param{Password},
    )
    ->result();

    return $Result;
}

=head2 Logout()

Ends the session for the logged-in user issuing the call

Useful to avoid hitting the limit of ten open sessions per login

    my $Success = $SalesForceObject->Logout();

=cut

sub Logout {
    my ( $Self, %Param ) = @_;

    # check auth
    if ( !$Self->{Auth} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Check: SalesForceModule Configuration!',
        );
        return;
    }

    my $Result = $Self->{Auth}->logout()->result();

    return $Result;
}

=head2 GetServerTimeStamp()

Retrieves the current system timestamp (GMT) from the Salesforce web service

    my $TimeStamp = $SalesForceObject->GetServerTimeStamp();

=cut

sub GetServerTimeStamp {
    my ( $Self, %Param ) = @_;

    # check auth
    if ( !$Self->{Auth} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Check: SalesForceModule Configuration!',
        );
        return;
    }

    my $Result = $Self->{Auth}->getServerTimestamp()->result();

    return $Result;
}

=head2 SFDate()

Converts the current system time in Epoch seconds to the date format that Salesforce likes

    my $SFDate = $SalesForceObject->SFDate();

=cut

sub SFDate {
    my ( $Self, %Param ) = @_;

    # check auth
    if ( !$Self->{Auth} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Check: SalesForceModule Configuration!',
        );
        return;
    }

    my $Result = $Self->{Auth}->sf_date();

    return $Result;
}

=head2 GetDeleted()

Retrieves the list of individual objects that have been deleted within the given time span for the specified object

    my $DeletedList = $SalesForceObject->GetDeleted(
        Type  => 'Account',
        Start => '2019-04-09T11:01:00.000Z',
        End   => '2019-04-11T08:42:00.000Z',
    );

=cut

sub GetDeleted {
    my ( $Self, %Param ) = @_;

    # check auth
    if ( !$Self->{Auth} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Check: SalesForceModule Configuration!',
        );
        return;
    }

    # check needed stuff
    for (qw( Type Start End )) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need: $_!"
            );
            return;
        }
    }

    my $Result = $Self->{Auth}->getDeleted(
        type  => $Param{Type},
        start => $Param{Start},
        end   => $Param{End},
    )
    ->result();

    return $Result;
}

=head2 GetUpdated()

Retrieves the list of individual objects that have been updated (added or changed)
within the given time span for the specified object

    my $UpdatedList = $SalesForceObject->GetUpdated(
        Type  => 'Account',
        Start => '2019-04-09T11:01:00.000Z',
        End   => '2019-04-11T08:42:00.000Z',
    );

=cut

sub GetUpdated {
    my ( $Self, %Param ) = @_;

    # check auth
    if ( !$Self->{Auth} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Check: SalesForceModule Configuration!',
        );
        return;
    }

    # check needed stuff
    for (qw( Type Start End )) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need: $_!"
            );
            return;
        }
    }

    my $Result = $Self->{Auth}->getUpdated(
        type  => $Param{Type},
        start => $Param{Start},
        end   => $Param{End},
    )
    ->result();

    return $Result;
}

=head2 Query()

Executes a query against the specified object and returns data that matches the specified criteria

    my $Data = $SalesForceObject->Query(
        Query => 'SELECT Id, Name FROM Account',
        Limit => 10,       # optional, specify count of results
    );

=cut

sub Query {
    my ( $Self, %Param ) = @_;

    # check auth
    if ( !$Self->{Auth} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Check: SalesForceModule Configuration!',
        );
        return;
    }

    # check needed stuff
    if ( !$Param{Query} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need: Query!"
        );
        return;
    }

    my $Result = $Self->{Auth}->query(
        query  => $Param{Query},
        limit  => $Param{Limit},
    )
    ->result();

    return $Result;
}

=head2 DoQuery()

Returns a reference to an array of hash refs (similar to Query)

    my $Data = $SalesForceObject->DoQuery(
        Query => 'SELECT Id, Name FROM Account',
        Limit => 10,       # optional, specify count of results
    );

=cut

sub DoQuery {
    my ( $Self, %Param ) = @_;

    # check auth
    if ( !$Self->{Auth} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Check: SalesForceModule Configuration!',
        );
        return;
    }

    # check needed stuff
    if ( !$Param{Query} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need: Query!"
        );
        return;
    }

    my $Result = $Self->{Auth}->do_query( $Param{Query}, $Param{Limit} );

    return $Result;
}

=head2 QueryAll()

Executes a query against the specified object
and returns data that matches the specified criteria including archived and deleted objects

    my $Data = $SalesForceObject->QueryAll(
        Query => 'SELECT Id, Name FROM Account',
        Limit => 10,       # optional, specify count of results
    );

=cut

sub QueryAll {
    my ( $Self, %Param ) = @_;

    # check auth
    if ( !$Self->{Auth} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Check: SalesForceModule Configuration!',
        );
        return;
    }

    # check needed stuff
    if ( !$Param{Query} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need: Query!"
        );
        return;
    }

    my $Result = $Self->{Auth}->queryAll(
        query  => $Param{Query},
        limit  => $Param{Limit},
    )
    ->result();

    return $Result;
}

=head2 DoQueryAll()

Returns a reference to an array of hash refs (similar to QueryAll)

    my $Data = $SalesForceObject->DoQueryAll(
        Query => 'SELECT Id, Name FROM Account',
        Limit => 10,       # optional, specify count of results
    );

=cut

sub DoQueryAll {
    my ( $Self, %Param ) = @_;

    # check auth
    if ( !$Self->{Auth} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Check: SalesForceModule Configuration!',
        );
        return;
    }

    # check needed stuff
    if ( !$Param{Query} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need: Query!"
        );
        return;
    }

    my $Result = $Self->{Auth}->do_queryAll( $Param{Query}, $Param{Limit} );

    return $Result;
}

=head2 QueryMore()

Retrieves the next batch of objects from a query or queryAll

    my $Data = $SalesForceObject->QueryMore(
        QueryLocator => '<The handle or string returned by Query>',
        Limit        => 10,       # optional, specify count of results
    );

=cut

sub QueryMore {
    my ( $Self, %Param ) = @_;

    # check auth
    if ( !$Self->{Auth} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Check: SalesForceModule Configuration!',
        );
        return;
    }

    # check needed stuff
    if ( !$Param{QueryLocator} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need: QueryLocator!"
        );
        return;
    }

    my $Result = $Self->{Auth}->queryMore(
        queryLocator => $Param{QueryLocator},
        limit        => $Param{Limit},
    )
    ->result();

    return $Result;
}

=head2 Search()

Use search() to search for records based on a search string

The search() call supports searching custom objects

    my $Data = $SalesForceObject->Search(
        SearchString => 'find {4159017000} in
                         phone fields returning contact(id, phone, firstname, lastname),
                         lead(id, phone, firstname, lastname),
                         account(id, phone, name)
                        ',
    );

=cut

sub Search {
    my ( $Self, %Param ) = @_;

    # check auth
    if ( !$Self->{Auth} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Check: SalesForceModule Configuration!',
        );
        return;
    }

    # check needed stuff
    if ( !$Param{SearchString} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need: SearchString!"
        );
        return;
    }

    my $Result = $Self->{Auth}->search(
        searchString => $Param{SearchString},
    )
    ->result();

    return $Result;
}

=head2 GetFieldList()

Returns a ref to an array of hash refs for each field name Field name keyed as 'name'

    my $Data = $SalesForceObject->GetFieldList(
        TableName => 'Account',
    );

=cut

sub GetFieldList {
    my ( $Self, %Param ) = @_;

    # check auth
    if ( !$Self->{Auth} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Check: SalesForceModule Configuration!',
        );
        return;
    }

    # check needed stuff
    if ( !$Param{TableName} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need: TableName!"
        );
        return;
    }

    my $Result = $Self->{Auth}->get_field_list( $Param{TableName} );

    return $Result;
}

=head2 GetTables()

Returns a ref to an array of hash refs for each field name Field name keyed as 'name'

    my $Data = $SalesForceObject->GetTables();

=cut

sub GetTables {
    my ( $Self, %Param ) = @_;

    # check auth
    if ( !$Self->{Auth} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Check: SalesForceModule Configuration!',
        );
        return;
    }

    my $Result = $Self->{Auth}->get_tables();

    return $Result;
}

=head2 Retrieve()

Use the Retrieve() call to retrieve individual records from an object

    my $Records = $SalesForceObject->Retrieve(
        Fields => 'ID, Name, Website',
        Type   => 'Account',
        IDs    => [ '0011i000007KbwNAAS', ],  # IDs List of the Object
    );

=cut

sub Retrieve {
    my ( $Self, %Param ) = @_;

    # check auth
    if ( !$Self->{Auth} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Check: SalesForceModule Configuration!',
        );
        return;
    }

    # check needed stuff
    for (qw( Fields Type IDs )) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need: $_!"
            );
            return;
        }
    }

    # check valid ref type
    if ( ref($Param{IDs}) ne 'ARRAY' ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Not a Array Reference: IDs!"
        );
        return;
    }

    my $Result = $Self->{Auth}->retrieve(
        fields => $Param{Fields},
        type   => $Param{Type},
        ids    => $Param{IDs},
    )
    ->result();

    return $Result;
}

=head2 Update()

Updates one or more existing objects in your organization's data
This subroutine takes as input a type value which names the type of object to update (e.g. Account, User)
and one or more perl HASH references containing the fields (the keys of the hash)
and the values of the record that will be updated

The hash must contain the 'Id' key in order to identify the record to update

    my $Updated = $SalesForceObject->Update(
        Type   => 'Account',
        Data   => {
            id   => '0011i0000080mbDAAQ',
            name => 'TestUpdate',
            ...                           # see other fields in table
        }
    );

=cut

sub Update {
    my ( $Self, %Param ) = @_;

    # check auth
    if ( !$Self->{Auth} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Check: SalesForceModule Configuration!',
        );
        return;
    }

    # check needed stuff
    for (qw( Type Data )) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need: $_!"
            );
            return;
        }
    }

    # check valid ref type
    if ( ref($Param{Data}) ne 'HASH' ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Not a Hash Reference: Data!"
        );
        return;
    }

    if ( !$Param{Data}->{id} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need: 'id' in Data!"
        );
        return;
    }

    my $Result = $Self->{Auth}->update(
        type   => $Param{Type},
        $Param{Data},
    )
    ->result();

    return $Result;
}

=head2 UpSert()

Updates or inserts one or more objects in your organization's data
If the data doesn't exist on Salesforce, it will be inserted
If it already exists it will be updated

This subroutine takes as input a type value which names the type of object to update (e.g. Account, User)
It also takes a key value which specifies the unique key Salesforce should use to determine if it needs to update or insert
If key is not given it will default to 'Id' which is Salesforce's own internal unique ID
This key can be any of Salesforce's default fields or an custom field marked as an external key

Finally, this method takes one or more perl HASH references containing the fields (the keys of the hash)
and the values of the record that will be updated

    my $UpSerted = $SalesForceObject->UpSert(
        Type => 'Account',
        Key  => '',                       # optional, specify unique key
        Data => {
            id   => '0011i0000080mbDAAQ', # need for update
            name => 'TestUpSert',         # need for create
            ...                           # see other fields in table
        }
    );

=cut

sub UpSert {
    my ( $Self, %Param ) = @_;

    # check auth
    if ( !$Self->{Auth} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Check: SalesForceModule Configuration!',
        );
        return;
    }

    # check needed stuff
    for (qw( Type Data )) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need: $_!"
            );
            return;
        }
    }

    # check valid ref type
    if ( ref($Param{Data}) ne 'HASH' ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Not a Hash Reference: Data!"
        );
        return;
    }

    if ( !$Param{Data}->{id} && !$Param{Data}->{name} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need: 'id' or 'name' in Data!"
        );
        return;
    }

    my $Result = $Self->{Auth}->upsert(
        type   => $Param{Type},
        key    => $Param{Key},
        $Param{Data},
    )
    ->result();

    return $Result;
}

=head2 DescribeMetadata()

Get some metadata info about your instance

    my $Metadata = $SalesForceObject->DescribeMetadata();

=cut

sub DescribeMetadata {
    my ( $Self, %Param ) = @_;

    # check auth
    if ( !$Self->{Auth} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Check: SalesForceModule Configuration!',
        );
        return;
    }

    my $Result = $Self->{Auth}->describeMetadata()->result();

    return $Result;
}

=head2 RetrieveMetadata()

Retrieve some metadata info about your instance

    my $Metadata = $SalesForceObject->RetrieveMetadata();

=cut

sub RetrieveMetadata {
    my ( $Self, %Param ) = @_;

    # check auth
    if ( !$Self->{Auth} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Check: SalesForceModule Configuration!',
        );
        return;
    }

    my $Result = $Self->{Auth}->retrieveMetadata()->result();

    return $Result;
}

=head2 CheckAsyncStatus()

Check whether or not an asynchronous metadata call or declarative metadata call has completed

    my $Status = $SalesForceObject->CheckAsyncStatus(
        PID => 5,
    );

=cut

sub CheckAsyncStatus {
    my ( $Self, %Param ) = @_;

    # check auth
    if ( !$Self->{Auth} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Check: SalesForceModule Configuration!',
        );
        return;
    }

    # check needed stuff
    if ( !$Param{PID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need: PID!"
        );
        return;
    }

    my $Result = $Self->{Auth}->checkAsyncStatus( $Param{PID} )->result();

    return $Result;
}

=head2 CheckRetrieveStatus()

Checks the status of the declarative metadata call retrieve() and returns the zip file contents

    my $Status = $SalesForceObject->CheckRetrieveStatus(
        PID => 5,
    );

=cut

sub CheckRetrieveStatus {
    my ( $Self, %Param ) = @_;

    # check auth
    if ( !$Self->{Auth} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Check: SalesForceModule Configuration!',
        );
        return;
    }

    # check needed stuff
    if ( !$Param{PID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need: PID!"
        );
        return;
    }

    my $Result = $Self->{Auth}->checkRetrieveStatus( $Param{PID} )->result();

    return $Result;
}

=head2 GetErrorDetails()

Returns a hash with information about errors from API calls - only useful if ($res->valueof('//success') ne 'true')

    my $Status = $SalesForceObject->GetErrorDetails(
        Result => <API Result>,
    );

=cut

sub GetErrorDetails {
    my ( $Self, %Param ) = @_;

    # check auth
    if ( !$Self->{Auth} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Check: SalesForceModule Configuration!',
        );
        return;
    }

    # check needed stuff
    if ( !$Param{Result} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need: Result!"
        );
        return;
    }

    my $Result = $Self->{Auth}->getErrorDetails( $Param{Result} )->result();

    return $Result;
}

1;

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (L<https://otrs.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (GPL). If you
did not receive this file, see L<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut