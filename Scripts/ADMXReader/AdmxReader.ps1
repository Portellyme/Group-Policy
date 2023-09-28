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
Enum PolicyClass {
	User = 1
	Machine = 2
}

Class Policy{
	
	# Properties
	[string]$Name
	[PolicyClass]$Class
	[string]$Admx
	[system.Xml.XmlElement]$PolicyXml
	[string]$ParentCategoryID
	[string]$ParentCategory
	[string]$DisplayNameId
	[string]$DisplayName
	[string]$ExplainTextId
	[string]$ExplainText
	[string]$SupportedOnVendor
	[string]$SupportedOnId
	[string]$SupportedOn
	[string]$Type
	[string]$Label
	[string]$RegistryHive
	[string]$RegistryKey
	[string]$RegistryValueName
	[string]$RegistryValueType
	[string]$RegistryDisplayName
	[String]$RegistryValue
	
	
	# Constructors
	Policy()
	{
		
	}
	
	Policy([string]$Admx, [string]$Name,[system.Xml.XmlElement]$Policy)
	{
		$this.Init($Admx, $Name, $Policy)
	}
	
	Policy([string]$Admx, [string]$Name, [system.Xml.XmlElement]$Policy, [string]$Class)
	{
		$this.Init($Admx, $Name, $Policy, $Class)
	}

	# methods
	# Hidden, chained helper methods that the constructors must call.
	Hidden Init([string]$Admx, [string]$Name, [system.Xml.XmlElement]$Policy)
	{
		$this.Init($Admx, $Name,$Policy, $Policy.Class)
	}
	
	Hidden Init([string]$Admx, [string]$Name, [system.Xml.XmlElement]$Policy, [string]$Class)
	{
		$this.Name = $Name
		$this.Class = $Class
		$this.Admx = $Admx
		$this.DisplayNameId = $Policy.displayname.substring(9).TrimEnd(')')
		$this.ExplainTextId = $Policy.ExplainText.substring(9).TrimEnd(')')
		
		$this.ParentCategoryID = $Policy.parentCategory.ref
		$this.RegistryKey = $Policy.key
		$this.RegistryHive = $this.GetHive($Class)
		$this.RegistryValueName = $Policy.valueName
		$this.Get_SupportedOn($Policy.supportedOn)
		$this.PolicyXml = $Policy
	}
	
	[string] GetHive([string]$PolicyClass)
	{
		$RegHive = ""
		If ($PolicyClass -eq "User") { $RegHive = "HKEY_CURRENT_USER" }
		If ($PolicyClass -eq "Machine") { $RegHive = "HKEY_LOCAL_MACHINE" }
		#fallback & compatibility - By default the "Both" Class should be catch to create one policy in each class 
		If ($PolicyClass -eq "Both") { $RegHive = "HKEY_LOCAL_MACHINE" }
		
		return $RegHive
	}
	
	[void] Get_SupportedOn([system.Xml.XmlElement]$SupportedOnRef)
	{
		If ($SupportedOnRef.ref.Contains(":"))
		{
			$this.SupportedOnVendor = $SupportedOnRef.ref.split(":")[0].ToLower()
			$this.SupportedOnId = $SupportedOnRef.ref.split(":")[1]
		}
	}
	
}

#Laziness
Class PolicyData{
	
	# Properties
	[string]$Name
	[string]$Class
	[string]$Admx
	[string]$LCID
	[string]$ParentCategory
	[string]$DisplayName
	[string]$ExplainText
	[string]$SupportedOn
	[string]$Type
	[string]$Label
	[string]$RegistryHive
	[string]$RegistryKey
	[string]$RegistryValueName
	[string]$RegistryValueType
	[string]$RegistryDisplayName
	[String]$RegistryValue
	
	# Constructors
	PolicyData([object]$Policy, [string]$LCID)
	{
		$This.Name = $Policy.Name
		$This.Class = $Policy.Class.ToString()
		$This.Admx = $Policy.Admx
		$this.LCID = $LCID
		$This.ParentCategory = $Policy.ParentCategory
		$This.DisplayName = $Policy.DisplayName
		$This.ExplainText = $Policy.ExplainText
		$This.SupportedOn = $Policy.SupportedOn
		$This.Type = $Policy.Type
		$This.Label = $Policy.Label
		$This.RegistryHive = $Policy.RegistryHive
		$This.RegistryKey = $Policy.RegistryKey
		$This.RegistryValueName = $Policy.RegistryValueName
		$This.RegistryValueType = $Policy.RegistryValueType
		$This.RegistryDisplayName = $Policy.RegistryDisplayName
		$This.RegistryValue = $Policy.RegistryValue
	}
}


Class PolicyDefinitions   {
	
	# Properties
	[string]$AdmxName
	[string]$LCID
	[System.Xml.XmlNodeList]$AdmxSupportedOnDef
	[System.Collections.Hashtable]$AdmxCategory = [System.Collections.Hashtable]::new()
	[System.Xml.XmlNodeList]$AdmxPolicyDefinitions
	[System.Collections.Hashtable]$AdmlStringTable = [System.Collections.Hashtable]::new()
	[System.Xml.XmlNodeList]$AdmlPresentationTable
	[System.Collections.Generic.List`1[Object]]$Policies = [System.Collections.Generic.List`1[Object]]::new()
	
	
	# Constructors
	PolicyDefinitions ([string]$AdmxName, [string]$LCID, [System.Xml.XmlDocument]$AdmxData, [System.Xml.XmlDocument]$Admxlang)
	{
		$this.AdmxName = $AdmxName
		$this.LCID = $LCID
		$this.AdmxSupportedOnDef = $AdmxData.policyDefinitions.supportedOn.definitions.ChildNodes
		$this.AdmxPolicyDefinitions = $AdmxData.PolicyDefinitions.policies.ChildNodes
		$this.Set_AdmxCategory($AdmxData)
		$this.Set_StringTable($Admxlang)
		$this.AdmlPresentationTable = $Admxlang.policyDefinitionResources.resources.presentationTable.ChildNodes
		
		$this.ParsePolicies()
	}
	
	#Methods
	[void]ParsePolicies()
	{
		foreach ($policy in $this.AdmxPolicyDefinitions) {
			#If policy name 
			If ($policy -eq $null)
			{
				continue
			}
			If ($policy.name -eq "#comment")
			{
				Continue
				#"Comment policies ChildNode found, node NOT processed"
			}
			#if policy is available in both class (User & Machine) we duplicate the policy
			If ($policy.Class -eq "Both")
			{
				$this.Policies.Add([Policy]::new($this.AdmxName, $Policy.name, $policy, "User"))
				$this.Policies.Add([Policy]::new($this.AdmxName, $Policy.name, $policy, "Machine"))
			}
			Else
			{
				$this.Policies.Add([Policy]::new($this.AdmxName, $Policy.name, $policy))
			}
		}
	}
	
	[void]Set_StringTable([System.Xml.XmlDocument]$Admxlang)
	{
		$Admxlang.policyDefinitionResources.resources.stringTable.string | ForEach-Object { $this.AdmlStringTable[$_.id] = $_.'#text'.Trim() }
	}
	
	[void]Set_AdmxCategory([System.Xml.XmlDocument]$AdmxData)
	{
		$AdmxData.policyDefinitions.categories.ChildNodes | ForEach-Object { $this.AdmxCategory[$_.name] = $_.displayName.substring(9).TrimEnd(')') }
	}
}


#endregion

#PSDebug
$DebugPreference = [System.Management.Automation.ActionPreference]::Continue
$StopWatch = [System.Diagnostics.Stopwatch]::new()
$StopWatch.Start()

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
$ListPoliciesDefinitions = [System.Collections.Generic.List`1[Object]]::new()
$VendorSupportedOn = [System.Collections.Hashtable]::new()
$PolicyDataTable = [System.Collections.Generic.List`1[Object]]::new()

#endregion 


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
		#Using only lowercases for this hashtable keys
		$VendorSupportedOn.Add('windows',@{})
		$supportedOnWindowsTableFile.policyDefinitionResources.resources.stringTable.ChildNodes | ForEach-Object{ $VendorSupportedOn.windows[$_.id] = $_.'#text' }
	}
}

#endregion SupportedOn

#region Policy Object
#Create the main policies definition objects 
ForEach ($key In $Admxlist.keys)
{
	$AdmxName = $Admxlist.$key.AdmxName
	$AdmxFile = $Admxlist.$key.AdmxFullname
	
	#Proces each file in the directory
	Write-Output ("**** Pre Processing " + $AdmxName + " ADMX")
	
	[xml]$AdmxData = Get-Content "$AdmxFile" @paramGetContent
	
	ForEach ($lcid In $Admxlist.$key.LocalID)
	{
		$AdmxlangPath = ([system.io.path]::Combine($ADMXFolder, $lcid, $AdmxName + ".adml"))
		[xml]$Admxlang = Get-Content -path $AdmxlangPath @paramGetContent
		
		# Retrieve all information from the specific ADMX and ADML file
		$ListPoliciesDefinitions.Add([PolicyDefinitions]::new($AdmxName, $lcid, $AdmxData, $Admxlang))
	}

}

Write-Debug -Message "Loading in $($StopWatch.Elapsed.Milliseconds) Milliseconds"
$StopWatch.Restart()
#endregion

#region ADML Data
#Fill the Policies definition with AMDL data
ForEach ($PolicyDefinition In $ListPoliciesDefinitions)
{
	#Process each ADMX for Each language
	Write-Output ("**** Processing " + $PolicyDefinition.AdmxName + " ADMX with " + $PolicyDefinition.LCID + " ADML")
	
	# retrieve DisplayName & ExplainText information
	ForEach ($Policy In $PolicyDefinition.Policies)
	{
		$Policy.DisplayName = $PolicyDefinition.AdmlStringTable.$($Policy.DisplayNameId)
		$Policy.ExplainText = $PolicyDefinition.AdmlStringTable.$($Policy.ExplainTextId)

		#retrieve supportedOn information      
		#Use the native vendor ADML files
		If ($VendorSupportedOn.ContainsKey($Policy.supportedOnVendor))
		{
			$Policy.SupportedOn = $VendorSupportedOn."$($Policy.supportedOnVendor)".$($Policy.SupportedOnId)
		}
		#If there is no Vendor Supported On, try to use the ADML String Table
		Else
		{
			$Policy.SupportedOn = $PolicyDefinition.AdmlStringTable.$($Policy.SupportedOnId)
		}
		
		#retrieving parentCategory
		If ($Policy.ParentCategoryID.Contains(":"))
		{
			$parentCategoryID = $Policy.ParentCategoryID.Split(":")[1]
			$Policy.ParentCategory = $PolicyDefinition.AdmlStringTable.$parentCategoryID
		}
		Else
		# no ':' in categoryParent information, find name in right Category identity
		{
			$parentCategoryID = $PolicyDefinition.AdmxCategory.$($Policy.ParentCategoryID)
			If ($parentCategoryID -ne $null)
			{
				#parentCategory displayname found in Admx category table
				$Policy.ParentCategory = $PolicyDefinition.AdmlStringTable.$parentCategoryID
			}
			Else
			# no display name in category table. Look directly for the parentCategory in the ADML File Stringt table
			{
				$Policy.ParentCategory = $PolicyDefinition.AdmlStringTable.$($Policy.ParentCategoryID)
			}
			
		}
	}
}
Write-Debug -Message "Process AMDL in $($StopWatch.Elapsed.Milliseconds) Milliseconds"
$StopWatch.Restart()
#endregion


#region Registry Data
$RegTypeMatchEvalutor = {
	Param ([string]$match)
	$m = $match
	If ($match.ToLower() -eq 'decimal') { $m = "REG_DWORD" }
	If ($match.ToLower() -eq 'string') { $m = "REG_SZ" }
	
	Return $m
}
$RegTypeRx = [regex]::new("\w+")

#Fill the Policies definition with Registry data
ForEach ($PolicyDefinition In $ListPoliciesDefinitions)
{
	#Process each policy
	Write-Output ("**** Processing " + $PolicyDefinition.AdmxName + " ADMX for registry data")
	

	ForEach ($Policy In $PolicyDefinition.Policies.GetEnumerator())
	{
		# retrieve Enable/Disable boolean registry key value
		If (($Policy.policyXml.enabledValue -ne $null))
		{
			$polValueType = $policy.policyXml.enabledValue.ChildNodes[0].Name
			Switch ($polValueType)
			{
				"string" { $polPossibleValues = $policy.policyXml.enabledValue.string }
				"decimal" { $polPossibleValues = $policy.policyXml.enabledValue.decimal.value.ToString() }
				default { $polPossibleValues = "" }
			}
			$Policy.RegistryValueType = [regex]::Replace($polValueType, $RegTypeRx, $RegTypeMatchEvalutor)
			$Policy.RegistryDisplayName = 'Enabled'
			$Policy.RegistryValue = $polPossibleValues
			
			$PolicyDataTable.Add([policydata]::new($Policy,$PolicyDefinition.LCID))
		}
		
		If (($Policy.policyXML.disabledValue -ne $null))
		{
			$polValueType = $policy.policyXml.disabledValue.ChildNodes[0].Name
			Switch ($polValueType)
			{
				"string" { $polPossibleValues = $policy.policyXml.disabledValue.string }
				"decimal" { $polPossibleValues = $policy.policyXml.disabledValue.decimal.value.ToString() }
				default { $polPossibleValues = "" }
			}
			$Policy.RegistryValueType = [regex]::Replace($polValueType, $RegTypeRx, $RegTypeMatchEvalutor)
			$Policy.RegistryDisplayName = 'Disabled'
			$Policy.RegistryValue = $polPossibleValues
			
			$PolicyDataTable.Add([policydata]::new($Policy,$PolicyDefinition.LCID))
		}
		
		
	}
}


Write-Debug -Message "Process ADMX Registry Data in $($StopWatch.Elapsed.Milliseconds) Milliseconds"
$StopWatch.Stop()
#endregion







#
Break; 
#$ListPoliciesDefinitions[0].ParsePolicies()
$ListPoliciesDefinitions
$ListPoliciesDefinitions[0]
$ListPoliciesDefinitions[1]
$ListPoliciesDefinitions.Policies |ft
$ListPoliciesDefinitions[0].Policies

<#
Processing time 
ADML Loop in script : 5115 ms
49 policies => Class both as duplicate 
194 ms - 18 ms

#>
$ListPoliciesDefinitions.Policies.count

$ListPoliciesDefinitions.Policies | Select-Object -Property SupportedOnVendor, SupportedOnId, SupportedOn | ft
