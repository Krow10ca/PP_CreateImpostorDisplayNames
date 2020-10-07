<#
.SYNOPSIS
	This script extracts information from the on-prem AD and formats an output CSV for importing into the Proofpoint Impostor Display Name configuration.
.DESCRIPTION
	Proofpoint provides an anti-spam protection called Impostor Display Names. This protection identifies incoming messages that have the same display name as an entry on the list, marks the message as an impostor,
	and quarantines the message. While this protection is susceptible for false positives, especially from users that send mail from their personal accounts to corporate messages, it has provided a net benefit to
	our organization.
	
	This script reads information from the on-prem AD, and creates a CSV suitable for import into the Proofpoint system containing several variants of the display name including First Name Last Name (John Smith),
	Last Name First Name (Smith John), and First Inital Last Name (jsmith)
.PARAMETER outfile
    This parameter specifies the path and filename to use for the resulting CSV. The default filename is impostordisplaynames.csv
.PARAMETER maildomain
    The email domain is used to limit collection of users from the AD to those with email addresses in the specified domain 
.PARAMETER ignoreblanks
    Activating this switch will ignore accounts that have blank first and/or last names
.EXAMPLE
	.\CreateImpostorDisplayNames.ps1
	Runs the script using the default settings
.EXAMPLE
	.\ScriptName.ps1 -outfile c:\temp\pp_displaynames.csv -emaildomain gmail.com
	Runs the script and outputs the created display names into the file pp_displaynames.csv in the C:\Temp folder
.NOTES
	Additional notes regarding the script

	Script:		CreateImpostorDisplayNames.ps1
	Author:		Mike Daniels
	
	Changelog
		0.1		Initial version of the script to extract AD info and generate an output CSV file
#>

[CmdletBinding()]

Param(
  [string]$outfile = "impostordisplaynames.csv",
  [string]$maildomain = "genericdomain.com",
  [switch]$ignoreblanks = $false
)

# Start of script

# Get AD users with email addresses that contain the domain specified in $emaildomain
Write-Verbose "Getting AD users"
$mailusers = Get-ADUser -filter "mail -like '*$maildomain'" -Properties * | Select-Object SamAccountName,GivenName,Surname,mailNickname

Write-Verbose "Start processing retrieved users"

# Start new array to store user string results
$csvoutput = @()

ForEach ($mailuser in $mailusers)
{

	# Check if user is not a full mail user, skip if true
	If ($($mailuser.mailNickname) -eq $null)
	{
		Write-Verbose "mailNickname for $($mailuser.SamAccountName) is blank, skipping"
		Continue
	}
	
	# If -ignoreblanks switch is included, check for blank first or last name
	If ($ignoreblanks)
	{
		If ($($mailuser.GivenName) -eq $null -Or $($mailuser.Surname) -eq $null)
		{
			Write-Verbose "Given name or surname for $($mailuser.SamAccountName) is blank, skipping"
			Continue
		}
	}
	
	Write-Verbose "Creating Proofpoint impostor names string for $($mailuser.SamAccountName): $($mailuser.mailNickname),$($mailuser.GivenName) $($mailuser.Surname),$($mailuser.Surname) $($mailuser.GivenName)"
	$displaynamestring = "$($mailuser.mailNickname),$($mailuser.GivenName) $($mailuser.Surname),$($mailuser.Surname) $($mailuser.GivenName)"
	
	# Add display names to the csvoutput array
	$csvoutput += New-Object PSObject -Property @{
			'Display Names' = $displaynamestring
			'Permitted External Email Addresses' = $null
			}

}

# Format and sort display names results array then export to CSV file
Write-Verbose "Formatting and sorting results, then exporting to CSV"
$csvoutput = $csvoutput | Select 'Display Names','Permitted External Email Addresses' | Sort 'Display Names'
$csvoutput | Export-Csv $outfile -NoTypeInformation