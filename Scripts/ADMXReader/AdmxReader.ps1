
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
Class PolicyDefinition   {
	
	# Properties
	[string]$AdmxName
	[string]$LCID
	[System.Xml.XmlNamespaceManager]$AdmxNamespace
	[System.Xml.XmlNamespaceManager]$AdmlNamespace
	[System.Collections.Hashtable]$AdmxCategories = [System.Collections.Hashtable]::new()
	[System.Xml.XmlNodeList]$Policies
#	[System.Collections.Hashtable]$AdmlStringTable = [System.Collections.Hashtable]::new()
#	[System.Xml.XmlNodeList]$AdmlPresentationTable

#	[System.Collections.Generic.List`1[Object]]$Policies = [System.Collections.Generic.List`1[Object]]::new()
	
	
	# Constructors
	PolicyDefinition ([string]$AdmxName, [string]$LCID, [System.Xml.XmlDocument]$AdmxData, [System.Xml.XmlDocument]$AdmlData)
	{
		$this.AdmxName = $AdmxName
		$this.LCID = $LCID
		$this.AdmxNamespace = $this.Get_XmlNamespaceManager($AdmxData, "admns", $null)
		$this.AdmlNamespace = $this.Get_XmlNamespaceManager($AdmlData, "admns", $null)		
		$this.Set_AdmxCategory($AdmxData)
		$this.Policies = $AdmxData.PolicyDefinitions.policies.ChildNodes

#		$this.Set_StringTable($Admxlang)
#		$this.AdmlPresentationTable = $Admxlang.policyDefinitionResources.resources.presentationTable.ChildNodes
#		

#		
#		
#		$this.ParsePolicies()
	}
	
	#Methods
	[System.Xml.XmlNamespaceManager]Get_XmlNamespaceManager([xml]$XmlDocument, [string]$NamespacePrefix, [string]$NamespaceURI)
	{
		# If a Namespace URI is not given, use the Xml default namespace.
		If ([string]::IsNullOrEmpty($NamespaceURI)) { $NamespaceURI = $XmlDocument.DocumentElement.NamespaceURI }
		
		# If a Namespace Prefix is not given, use the ns default namespace.
		If ([string]::IsNullOrEmpty($NamespacePrefix)) { $NamespacePrefix = "ns" }
		
		# In order for SelectSingleNode() to actually work, we need to use the fully qualified node path along with an Xml Namespace Manager.
		[System.Xml.XmlNamespaceManager]$xmlNsManager = [System.Xml.XmlNamespaceManager]::new($XmlDocument.NameTable)
		$xmlNsManager.AddNamespace($NamespacePrefix, $NamespaceURI)
		
		Return $xmlNsManager
	}
	
	
	[void]Set_AdmxCategory([System.Xml.XmlDocument]$AdmxData)
	{
		$AdmxData.policyDefinitions.categories.ChildNodes | ForEach-Object { $this.AdmxCategories[$_.name] = $_.displayName.substring(9).TrimEnd(')') }
	}
	
	#	[void]ParsePolicies()
#	{
#		ForEach ($policy In $this.AdmxPolicyDefinitions)
#		{
#			#If policy name 
#			If ($policy -eq $null)
#			{
#				Continue
#			}
#			If ($policy.name -eq "#comment")
#			{
#				Continue
#				#"Comment policies ChildNode found, node NOT processed"
#			}
#			#if policy is available in both class (User & Machine) we duplicate the policy
#			If ($policy.Class -eq "Both")
#			{
#				$this.Policies.Add([Policy]::new($this.AdmxName, $Policy.name, $policy, "User"))
#				$this.Policies.Add([Policy]::new($this.AdmxName, $Policy.name, $policy, "Machine"))
#			}
#			Else
#			{
#				$this.Policies.Add([Policy]::new($this.AdmxName, $Policy.name, $policy))
#			}
#		}
#	}
	
#	[void]Set_StringTable([System.Xml.XmlDocument]$Admxlang)
#	{
#		$Admxlang.policyDefinitionResources.resources.stringTable.string | ForEach-Object { $this.AdmlStringTable[$_.id] = $_.'#text'.Trim() }
#	}
#	

	

	
}

#endregion

#region PSDebug
#PSDebug
$DebugPreference = [System.Management.Automation.ActionPreference]::Continue
$StopWatch = [System.Diagnostics.Stopwatch]::new()
$StopWatch.Start()
#endregion PSDebug



#region Global Declaration 
[string]$ScriptDirectory = Get-ScriptDirectory
[string]$ScriptName = ($MyInvocation.MyCommand.Name.Split("."))[0]

[string]$ADMXFolder = "C:\temp\Admx"
[string]$OutputFile = [System.IO.Path]::Combine($ScriptDirectory, $SourceAdmx, ".csv")
$LCIDBase= "en-US"
$LCIDExtended = @("fr-FR", "de-DE")

$paramGetContent = @{
	Encoding = 'UTF8'
}

#Create Lists used script GLOBAL
$AdmxFileslist = [System.Collections.Hashtable]::new()
$VendorSupportedOn = [System.Collections.Hashtable]::new()
$PolicyDefinitionList = [System.Collections.Generic.List`1[Object]]::new()



$PolicyDataTable = [System.Collections.Generic.List`1[Object]]::new()


If (!(Test-Path -Path $ADMXFolder))
{
	Throw "Policy Directory $ADMXFolder NOT Found. Script Execution STOPPED."
}
#endregion 


#region ADMXfilelist
# Creating the ADMX file list and language to process
# If the corresponding AMDL file does not exist in en-US the ADMX will not be processed.
# Only the en-US ADML file is mandatory.
# Retrieving all the ADMX files
$AdmxFiles = Get-ChildItem $ADMXFolder -filter *.admx

If ($AdmxFiles -eq $null)
{
	Throw "No Admx Policy file found. Script Execution STOPPED."
}

ForEach ($file In $AdmxFiles)
{
	#Test base Language Files
	If (Test-Path("$ADMXFolder\$LCIDBase\$($file.BaseName).adml"))
	{
		
		$AdmxFileslist.add($file.BaseName, @{
				AdmxName	 = $file.BaseName;
				FileName = $file.FullName;
				LocalID  = @{
					$LCIDBase = "$ADMXFolder\$LCIDBase\$($file.BaseName).adml";
				}
			})
		
		ForEach ($lcid In $LCIDExtended)
		{
			If (Test-Path("$ADMXFolder\$lcid\$($file.BaseName).adml"))
			{
				$AdmxFileslist.$($file.Basename).LocalID.Add($lcid, "$ADMXFolder\$lcid\$($file.BaseName).adml")
			}
		}
	}
}
Write-Debug -Message "List $($AdmxFileslist.Count.ToString()) file(s) to process in $([math]::round($StopWatch.Elapsed.TotalSeconds, 3)) seconds"
$StopWatch.Restart()
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
		#Using only lowercases for this hashtable keys
		$VendorSupportedOn.Add('windows', @{ })
		$supportedOnWindowsTableFile.policyDefinitionResources.resources.stringTable.ChildNodes | ForEach-Object{ $VendorSupportedOn.windows[$_.id] = $_.'#text' }
	}
}
Write-Debug -Message "Process supported On file(s) in $([math]::round($StopWatch.Elapsed.TotalSeconds, 3)) seconds"
$StopWatch.Restart()
#endregion SupportedOn


#region Policy Object
#Create the main policies definition objects 
ForEach ($key In $AdmxFileslist.keys)
{
	$AdmxName = $AdmxFileslist.$key.AdmxName
	$AdmxFile = $AdmxFileslist.$key.FileName
	
	#Proces each file in the directory
	Write-Output ("**** Pre Processing " + $AdmxName + " ADMX")
	[xml]$AdmxData = Get-Content "$AdmxFile" @paramGetContent
	
	ForEach ($lcid In $AdmxFileslist.$key.LocalID.keys)
	{
		
		$AdmlFilePath = $AdmxFileslist.$key.LocalID.$lcid
		[xml]$AdmlData = Get-Content -path $AdmlFilePath @paramGetContent
		
		#Push all information from the specific ADMX and ADML file in a list
		$PolicyDefinitionList.Add([PolicyDefinition]::new($AdmxName, $lcid, $AdmxData, $Admxlang))
		
<#		
		#Step to add ADMX/ADML Supported On 
		#$this.AdmxSupportedOnDef = $AdmxData.policyDefinitions.supportedOn.definitions.ChildNodes
#>		
	}
	
}

Write-Debug -Message "Loading in $($StopWatch.Elapsed.Milliseconds) Milliseconds"
$StopWatch.Restart()
#endregion


#region Main
$PolicyDefinitionList




#endregion 


