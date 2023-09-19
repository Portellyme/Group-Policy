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
$Languages = @{
	base	 = "en-US"
	extended = @("fr-FR", "de-DE")
}

$paramGetContent = @{
	Encoding = 'UTF8'
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
	[xml]$supportedOnWindowsTableFile = Get-Content "$ADMXFolder\en-US\Windows.adml" @paramGetContent
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
		$LocaleIDlist = [system.Collections.Generic.List`1[string]]::new()
		$LocaleIDlist.Add($Languages.base)
		$Admxlist.Add($file.Basename, @{
				AdmxName = $file.Basename
				AdmxFullname = $file.FullName
				LocalID  = $LocaleIDlist
			})
		
		
		foreach ($lcid in $Languages.extended) {
			If (Test-Path("$ADMXFolder\$lcid\$($file.BaseName).adml"))
			{
				$Admxlist.$($file.Basename).LocalID.Add($lcid)
			}
		}
	}
	
}
Write-Output ($Admxlist.Count.ToString() + " ADMX files to process in """ + $ADMXFolder + """")
#	
#$Admxlist
#$Admxlist.OneDrive
#$Admxlist.OneDrive.localID

ForEach ($key In $Admxlist.keys)
{
	$AdmxName = $Admxlist.$key.AdmxName
	$AdmxFile = $Admxlist.$key.AdmxFullname
	
	#Proces each file in the directory
	Write-Output ("*** Processing ADMX " + $AdmxName)
	

	
	[xml]$AdmxData = Get-Content "$AdmxFile" @paramGetContent

	
	# Retrieve all information from the specific ADMX file
	$supportedOnDefChilds = $AdmxData.policyDefinitions.supportedOn.definitions.ChildNodes	
	$categoryChilds = $data.policyDefinitions.categories.ChildNodes
	
	ForEach ($lcid In $Admxlist.$key.LocalID)
	{
		$AdmxlangPath = ([system.io.path]::Combine($ADMXFolder, $lcid, $AdmxName + ".adml"))
		[xml]$Admxlang = Get-Content -path $AdmxlangPath @paramGetContent
		
		# Retrieve all information from the specific ADML file
		$stringTableChilds = $Admxlang.policyDefinitionResources.resources.stringTable.ChildNodes
		$presentationTableChilds = $Admxlang.policyDefinitionResources.resources.presentationTable.ChildNodes
	}
	
	
	
}


#endregion 


