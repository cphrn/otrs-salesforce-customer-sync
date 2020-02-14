# --
# Copyright (C) 2019 CIPHRON GmbH, https://ciphron.de/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Admin::SalesForce::SyncCustomers;

use strict;
use warnings;
use utf8;

use Kernel::System::ObjectManager;

use parent qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    "Kernel::Config",
    "Kernel::System::DB",
    "Kernel::System::Log",
    "Kernel::System::SalesForce",
    "Kernel::System::CustomerUser",
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Sync salesforce customer data.');
    $Self->AddOption(
        Name        => 'sf',
        Description => "Activate salesforce module.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/^1$/smx,
    );
    $Self->AddOption(
        Name        => 'auth-user',
        Description => "User name for authentication.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'auth-password',
        Description => "Password for authentication.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'auth-security-token',
        Description => "Security token for authentication.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'auth-proxy',
        Description => "Proxy for authentication.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'auth-api-version',
        Description => "API version for authentication.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'auth-baseurl',
        Description => "BaseUrl for authentication.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'auth-prefix',
        Description => "Prefix for authentication.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'auth-sobjecturl',
        Description => "SObjectUrl for authentication.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'auth-metadataurl',
        Description => "MetaDataUrl for authentication.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'auth-webproxy',
        Description => "WebProxy for authentication.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'customers-limit',
        Description => "Limit to get customers.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/^[1-9][0-9]?$|^2000$/smx,
    );
    $Self->AddOption(
        Name        => 'customers-delete-old',
        Description => "Search string to delete old entries after sync.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'valid-data',
        Description => "Get only valid data.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/^(1|0)$/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Sync salesforce customers data...</yellow>\n");

    my $CacheObject = $Kernel::OM->Get("Kernel::System::Cache");
    $CacheObject->CleanUp();

    local $Kernel::OM = Kernel::System::ObjectManager->new(
        'Kernel::System::SalesForce' => {
            SF              => $Self->GetOption('sf'),
            SF_PROXY        => $Self->GetOption('auth-proxy'),
            SF_URI          => $Self->GetOption('auth-baseurl'),
            SF_PREFIX       => $Self->GetOption('auth-prefix'),
            SF_SOBJECT_URI  => $Self->GetOption('auth-sobjecturl'),
            SF_URIM         => $Self->GetOption('auth-metadataurl'),
            SF_APIVERSION   => $Self->GetOption('auth-api-version'),
            WEB_PROXY       => $Self->GetOption('auth-webproxy'),
            SF_AUTHUSER     => $Self->GetOption('auth-user'),
            SF_AUTHPASSWORD => $Self->GetOption('auth-password'),
            SF_AUTHSECTOKEN => $Self->GetOption('auth-security-token'),
        },
    );

    my $SalesForceObject   = $Kernel::OM->Get("Kernel::System::SalesForce");
    my $CustomerUserObject = $Kernel::OM->Get("Kernel::System::CustomerUser");
    my $ConfigObject       = $Kernel::OM->Get("Kernel::Config");

    my @Fields = (
        "Owner.Id",
        "Owner.Name",
        "Owner.FirstName",
        "Owner.LastName",
        "Owner.Email",
    );

    my $AddAttributesToParams    = $ConfigObject->{'SalesForceModule::Customers::AddAttributesToParams'};
    if ( $AddAttributesToParams ) {
        for my $AddAttribute ( values %{ $AddAttributesToParams } ) {
            if ( $AddAttribute ne '' ) {
                push ( @Fields, $AddAttribute );
            }
        }
    }

    my $FieldString     = join(", ", @Fields);
    my $Query           = "SELECT $FieldString FROM Account ";

    my $Where                 = $ConfigObject->{'SalesForceModule::Customers::Where'};
    if ( $Where ) {
        $Query                .= "Where $Where ";
    }

    my $Limit           = $Self->GetOption('customers-limit') || $ConfigObject->{'SalesForceModule::Customers::Limit'};
    if ( $Limit ) {
        $Query .= " GROUP BY $FieldString LIMIT $Limit ";
    }

    my $Results = $SalesForceObject->DoQuery(
        Query => $Query,
    );

    my @Data;
    if ( $Results ) {
        @Data = @{ $Results };
        if ( !$Limit ) {
            my %Unique;
            my $Index    = scalar @Data;
            my @List     = @Data;
            @Data        = ();
            for my $Element (0 .. $Index - 1) {
                my @Item = grep !$Unique{$_->{Id}[0]}++, $List[$Element]->{Owner};
                push (@Data, @Item);
            }
        }
    }

    my @CustomerUserIDs = ();
    my $IsValid = $Self->GetOption('valid-data') || $ConfigObject->{'SalesForceModule::ValidData'};
    for my $Item ( @Data ) {

        if (
            $IsValid &&
            $Item->{Name} =~ /^\*/
        ) {
            next;
        }

        $Item->{Id}       = $Item->{Id}[0];
        my $Email         = $Item->{Email};

        my %Exist = $CustomerUserObject->CustomerUserDataGet(
            User => $Item->{Id},
        );

        my $UCIDQuery = "SELECT Account.Id, Account.Name FROM Account WHERE Owner.Id = '".$Item->{Id}."'";
        my $UCIDData  = $SalesForceObject->DoQuery(
            Query => $UCIDQuery,
        );

        my @UCIDs;
        for my $UCIDItem ( @{ $UCIDData } ) {

            if (
                $IsValid &&
                $UCIDItem->{Name} =~ /^\*/
            ) {
                next;
            }

            push (@UCIDs, $UCIDItem->{Id}[0] );
        }
        my $UCIDString = join(";", @UCIDs);

        push (@CustomerUserIDs, $Item->{Id});

        my %AddParams;
        if ( $AddAttributesToParams ) {
            for my $AddParam ( keys %{ $AddAttributesToParams } ) {
                my $AddValue = $AddAttributesToParams->{$AddParam};
                if ( $AddValue ne '' ) {
                    $AddValue =~ s/(.*\.\.?)//;
                    if ( defined( $Item->{$AddValue} ) ) {
                        $AddParams{$AddParam} = $Item->{$AddValue};
                    }
                }
            }
        }

        my $Success;
        my $DefaultCustomerID = $ConfigObject->{'SalesForceModule::Customers::DefaultCustomerID'} || 1;
        if ( %Exist ) {
            $Success = $CustomerUserObject->CustomerUserUpdate(
                Source          => "CustomerUser",
                ID              => $Item->{Id},
                UserLogin       => $Item->{Id},
                UserFirstname   => $Item->{FirstName},
                UserLastname    => $Item->{LastName},
                UserEmail       => $Email,
                UserCustomerID  => $DefaultCustomerID,
                UserCustomerIDs => $UCIDString,
                ValidID         => 1,
                UserID          => 1,
                %AddParams,
            );
        } else {
            $Success = $CustomerUserObject->CustomerUserAdd(
                Source          => "CustomerUser",
                UserLogin       => $Item->{Id},
                UserFirstname   => $Item->{FirstName},
                UserLastname    => $Item->{LastName},
                UserEmail       => $Email,
                UserCustomerID  => $DefaultCustomerID,
                UserCustomerIDs => $UCIDString,
                ValidID         => 1,
                UserID          => 1,
                %AddParams,
            );
        }

        if ( $Success ) {
            for my $PrefKey ( keys %AddParams ) {
                my $Success = $CustomerUserObject->SetPreferences(
                    Key    => $PrefKey,
                    Value  => $Item->{$AddParams{$PrefKey}},
                    UserID => $Item->{Id},
                );
            }
        }
    }

    my $DeleteOld  = $Self->GetOption('customers-delete-old') || $ConfigObject->{'SalesForceModule::Customers::DeleteOld'};
    if ( !$Limit && $DeleteOld ) {
        my %Result = $CustomerUserObject->CustomerSearch(
            UserLogin => $DeleteOld,
            Valid     => 0,
            Limit     => 0,
        );
        for my $DBCustomerUserID ( keys %Result ) {
            if ( !( grep { /\Q$DBCustomerUserID\E/ } @CustomerUserIDs ) ) {
                $Kernel::OM->Get('Kernel::System::DB')->Do(
                    SQL  => "delete from customer_user where login = ?",
                    Bind => [ \$DBCustomerUserID ]
                );
            }
        }
    }

    # status log
    $Kernel::OM->Get("Kernel::System::Log")->Log(
        Priority => "info",
        Message  => "Import of Customers finished."
    );

    $Self->Print("<green>Import of Customers finished.<green>\n");

    return $Self->ExitCodeOk();
}

1;
