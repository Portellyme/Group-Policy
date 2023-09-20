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
Import-Module AdmxTracker
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

Class PolicyDefinitions   {
	
	# Properties
	[string]$AdmxName
	[string]$LCID
	[System.Xml.XmlNodeList]$SupportedOnDefChilds
	[System.Xml.XmlNodeList]$CategoryChilds
	[System.Xml.XmlNodeList]$PoliciesChilds
	[System.Xml.XmlNodeList]$StringTableChilds
	[System.Xml.XmlNodeList]$PresentationTableChilds
	
	<#
		$supportedOnDefChilds = $AdmxData.policyDefinitions.supportedOn.definitions.ChildNodes	
		$categoryChilds = $AdmxData.policyDefinitions.categories.ChildNodes
		$policiesChilds = $AdmxData.PolicyDefinitions.policies.ChildNodes

		$stringTableChilds = $Admxlang.policyDefinitionResources.resources.stringTable.ChildNodes
		$presentationTableChilds = $Admxlang.policyDefinitionResources.resources.presentationTable.ChildNodes
	
	XmlDocument
	#>

# Constructors
PolicyDefinitions ([string]$AdmxName, [string]$LCID,[System.Xml.XmlDocument]$AdmxData, [System.Xml.XmlDocument]$Admxlang) {
		$this.AdmxName = $AdmxName
		$this.LCID = $LCID
		$this.SupportedOnDefChilds = $AdmxData.policyDefinitions.supportedOn.definitions.ChildNodes
		$this.CategoryChilds = $AdmxData.policyDefinitions.categories.ChildNodes
		$this.PoliciesChilds = $AdmxData.PolicyDefinitions.policies.ChildNodes
		$this.StringTableChilds = $Admxlang.policyDefinitionResources.resources.stringTable.ChildNodes
		$this.PresentationTableChilds = $Admxlang.policyDefinitionResources.resources.presentationTable.ChildNodes
		
}

#Methods

}


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

#Create Lists used script GLOBAL
#$ListSupportedOn = [System.Collections.Generic.List`1[Object]]::new()
$ListPoliciesDefinitions = [System.Collections.Generic.List`1[Object]]::new()
$VendorSupportedOn = [System.Collections.Hashtable]::new()

#endregion 



#region Main
If (!(Test-Path -Path $ADMXFolder))
{
	Throw "Policy Directory $ADMXFolder NOT Found. Script Execution STOPPED."
}

#region ADMXfilelist
# Creating the ADMX file list and language to process
# If the corresponding AMDL file does not exist in en-US the ADMX will not be processed.
# Only the en-US ADML file is mandatory.
# Retrieving all the ADMX files
$Admxlist = [System.Collections.Hashtable]::new()
$AdmxFiles = Get-ChildItem $ADMXFolder -filter *.admx

If ($AdmxFiles -eq $null)
{
	Throw "No Admx Policy file found. Script Execution STOPPED."
}

ForEach ($file In $AdmxFiles)
{
	#Test base Language Files
	If (Test-Path("$ADMXFolder\$($Languages.base)\$($file.BaseName).adml"))
	{
		$LocaleIDlist = [system.Collections.Generic.List`1[string]]::new()
		$LocaleIDlist.Add($Languages.base)
		$Admxlist.Add($file.Basename, @{
				AdmxName	 = $file.Basename
				AdmxFullname = $file.FullName
				LocalID	     = $LocaleIDlist
			})
		
		
		ForEach ($lcid In $Languages.extended)
		{
			If (Test-Path("$ADMXFolder\$lcid\$($file.BaseName).adml"))
			{
				$Admxlist.$($file.Basename).LocalID.Add($lcid)
			}
		}
	}
	
}
Write-Output ($Admxlist.Count.ToString() + " ADMX files to process in """ + $ADMXFolder + """")
#endregion ADMXfilelist

#region SupportedOn
# Checking for Vendor supportedOn Files
# Checking for the Windows supportedOn vendor definition files
If (Test-Path("$ADMXFolder\en-US\Windows.adml"))
{
	[xml]$supportedOnWindowsTableFile = Get-Content "$ADMXFolder\en-US\Windows.adml" @paramGetContent
	# Updating the SupportedOn list with the  Windows supportedOn information from the Windows.ADMX file
	If ($supportedOnWindowsTableFile -ne $null)
	{
		$VendorSupportedOn.Add('Windows',@{})
		$supportedOnWindowsTableFile.policyDefinitionResources.resources.stringTable.ChildNodes | ForEach-Object{ $VendorSupportedOn.Windows[$_.id] = $_.'#text' }
	}
}

#endregion SupportedOn


ForEach ($key In $Admxlist.keys)
{
	$AdmxName = $Admxlist.$key.AdmxName
	$AdmxFile = $Admxlist.$key.AdmxFullname
	
	#Proces each file in the directory
	Write-Output ("**** Pre Processing ADMX " + $AdmxName)
	
	[xml]$AdmxData = Get-Content "$AdmxFile" @paramGetContent

	
	# Retrieve all information from the specific ADMX file
#	$supportedOnDefChilds = $AdmxData.policyDefinitions.supportedOn.definitions.ChildNodes
#	
#	$policiesChilds = $AdmxData.PolicyDefinitions.policies.ChildNodes
#	
#	$categoryChilds = $AdmxData.policyDefinitions.categories.ChildNodes
	
	ForEach ($lcid In $Admxlist.$key.LocalID)
	{
		$AdmxlangPath = ([system.io.path]::Combine($ADMXFolder, $lcid, $AdmxName + ".adml"))
		[xml]$Admxlang = Get-Content -path $AdmxlangPath @paramGetContent
		
		# Retrieve all information from the specific ADML file
#		$stringTableChilds = $Admxlang.policyDefinitionResources.resources.stringTable.ChildNodes
		#		$presentationTableChilds = $Admxlang.policyDefinitionResources.resources.presentationTable.ChildNodes
		
		$ListPoliciesDefinitions.Add([PolicyDefinitions]::new($AdmxName, $lcid, $AdmxData, $Admxlang))
		

	}
	
	
	
}


#endregion 


