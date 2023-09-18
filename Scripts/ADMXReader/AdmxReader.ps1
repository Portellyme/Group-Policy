<#
.SYNOPSIS
	ADMX Policy information converter.
.DESCRIPTION
	Converts the ADMX XML format to a more readable file with policy and registry information.
	By default the script will look for the language files (ADML) in the BCP 47 Code language folder 
.OUTPUTS
	Policy information file stored in the root of the provided policy directory.
.NOTES
  	Version:        1.0
  	
	Based upon this reference material: 
		https://technet.microsoft.com/en-us/library/cc731761(v=ws.10).aspx	(Associating .admx and .adml Parameter Information)
		https://technet.microsoft.com/en-us/library/cc771659(v=ws.10).aspx (ADMX syntax)
        https://technet.microsoft.com/en-us/library/cc753471(v=ws.10).aspx (Group Policy ADMX Syntax Reference Guide)
		https://msdn.microsoft.com/en-us/library/dn606024(v=vs.85).aspx (more recent syntax) 

		https://learn.microsoft.com/en-us/globalization/locale/locale (Locale and culture awareness)
#>




######################
#region Function Declaration 
######################
function Get-ScriptDirectory
{
	[OutputType([string])]
	param ()
	if ($null -ne $hostinvocation)
	{
		Split-Path $hostinvocation.MyCommand.path
	}
	else
	{
		Split-Path $script:MyInvocation.MyCommand.Path
	}
}


#endregion


#region Classes


#endregion


#region Global Declaration 
[string]$ScriptDirectory = Get-ScriptDirectory
[string]$ScriptName = ($MyInvocation.MyCommand.Name.Split("."))[0]

[string]$ADMXFolder = "C:\temp\Admx"
[string]$OutputFile = [System.IO.Path]::Combine($ScriptDirectory, $SourceAdmx, ".csv")
[hashtable]$Languages = @{
	base	 = "en-US"
	addition = "fr-FR, de-DE"
}
#endregion 



#region Main
If (!(Test-Path -Path $ADMXFolder))
{
	Throw "Policy Directory $ADMXFolder NOT Found. Script Execution STOPPED."
}

# Checking for the Windows supportedOn vendor definition files
If (Test-Path("$ADMXFolder\en-US\Windows.adml"))
{
	[xml]$supportedOnWindowsTableFile = Get-Content "$ADMXFolder\en-US\Windows.adml"
}


# Creating the ADMX file list and language to process
# If the corresponding AMDL file does not exist in en-US the ADMX will not be processed.
# Only the en-US ADML file is mandatory.
# Retrieving all the ADMX files
$AdmxFiles = Get-ChildItem $ADMXFolder -filter *.admx

$Admxlist = [System.Collections.Hashtable]::new()

ForEach ($file In $AdmxFiles)
{
	#Test base Language Files
	If (Test-Path("$ADMXFolder\$($Languages.base)\$($file.BaseName).adml"))
	{
		$Admxlist.Add($file.Basename,$file.FullName)
	}
	
}
Write-Output ($Admxlist.Count.ToString() + " ADMX files to process in """ + $ADMXFolder + """")




#endregion 


