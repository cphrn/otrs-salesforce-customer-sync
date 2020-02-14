# --
# Copyright (C) 2019 CIPHRON GmbH, https://ciphron.de/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Admin::SalesForce::SyncCompanies;

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
    "Kernel::System::CustomerCompany",
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
        Name        => 'companies-limit',
        Description => "Limit to get companies.",
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/^[1-9][0-9]?$|^2000$/smx,
    );
    $Self->AddOption(
        Name        => 'companies-delete-old',
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

    $Self->Print("<yellow>Sync salesforce companies data...</yellow>\n");

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

    my $SalesForceObject      = $Kernel::OM->Get("Kernel::System::SalesForce");
    my $CustomerCompanyObject = $Kernel::OM->Get("Kernel::System::CustomerCompany");
    my $ConfigObject          = $Kernel::OM->Get("Kernel::Config");

    my @Fields = (
        "Account.Id",
        "Account.Name",
    );

    my $AddAttributesToParams = $ConfigObject->{'SalesForceModule::Companies::AddAttributesToParams'};
    if ( $AddAttributesToParams ) {
        for my $AddAttribute ( values %{ $AddAttributesToParams } ) {
            if ( $AddAttribute ne '' ) {
                push ( @Fields, $AddAttribute );
            }
        }
    }

    my $FieldString           = join(", ", @Fields);
    my $Query                 = "SELECT $FieldString FROM Account ";

    my $Where                 = $ConfigObject->{'SalesForceModule::Companies::Where'};
    if ( $Where ) {
        $Query                .= "Where $Where ";
    }

    my $Limit                 = $Self->GetOption('companies-limit') || $ConfigObject->{'SalesForceModule::Companies::Limit'};
    if ( $Limit ) {
        $Query                .= "GROUP BY $FieldString LIMIT $Limit ";
    }

    my $Results               = $SalesForceObject->DoQuery(
        Query => $Query,
    );

    my @CompanyIDs = ();
    my $IsValid = $Self->GetOption('valid-data') || $ConfigObject->{'SalesForceModule::ValidData'};
    for my $Item ( @{ $Results } ) {

        if (
            $IsValid &&
            $Item->{Name} =~ /^\*/
        ) {
            next;
        }

        $Item->{Id}        = $Item->{Id}[0];
        my $CompanyName    = $Item->{Name} . " (" . $Item->{Id} . ")";

        my %Exist = $CustomerCompanyObject->CustomerCompanyGet(
            CustomerID => $Item->{Id},
        );
        push (@CompanyIDs, $Item->{Id});

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
        if ( %Exist ) {
            $Success = $CustomerCompanyObject->CustomerCompanyUpdate(
                CustomerCompanyID       => $Item->{Id},
                CustomerID              => $Item->{Id},
                CustomerCompanyName     => $CompanyName,
                ValidID                 => 1,
                UserID                  => 1,
                %AddParams,
            );
        } else {
            $Success = $CustomerCompanyObject->CustomerCompanyAdd(
                CustomerID              => $Item->{Id},
                CustomerCompanyName     => $CompanyName,
                ValidID                 => 1,
                UserID                  => 1,
                %AddParams,
            );
        }
    }

    my $DeleteOld  = $Self->GetOption('companies-delete-old') || $ConfigObject->{'SalesForceModule::Companies::DeleteOld'};
    if ( !$Limit && $DeleteOld ) {
        my %Result = $CustomerCompanyObject->CustomerCompanyList(
            Search => $DeleteOld,
            Valid  => 0,
            Limit  => 0,
        );
        for my $DBCompanyID ( keys %Result ) {
            if ( !( grep { /\Q$DBCompanyID\E/ } @CompanyIDs ) ) {
                $Kernel::OM->Get('Kernel::System::DB')->Do(
                    SQL  => "delete from customer_company where customer_id = ?",
                    Bind => [ \$DBCompanyID ]
                );
            }
        }
    }

    # status log
    $Kernel::OM->Get("Kernel::System::Log")->Log(
        Priority => "info",
        Message  => "Import of Companies finished."
    );

    $Self->Print("<green>Import of Companies finished.<green>\n");

    return $Self->ExitCodeOk();
}

1;
