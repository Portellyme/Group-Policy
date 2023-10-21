
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
	[System.Collections.Hashtable]$AdmxCategoriesTable = [System.Collections.Hashtable]::new()
	[System.Collections.Hashtable]$AdmxPoliciesTable = [System.Collections.Hashtable]::new()
	[System.Collections.Hashtable]$AdmlStringTable = [System.Collections.Hashtable]::new()
	[System.Collections.Hashtable]$AdmlPresentationTable = [System.Collections.Hashtable]::new()

	[System.Collections.Generic.List`1[Object]]$Policies = [System.Collections.Generic.List`1[Object]]::new()
	
	
	# Constructors
	PolicyDefinition ([string]$AdmxName, [string]$LCID, [System.Xml.XmlDocument]$AdmxData, [System.Xml.XmlDocument]$AdmlData)
	{
		$this.AdmxName = $AdmxName
		$this.LCID = $LCID
		$this.AdmxNamespace = $this.Set_XmlNamespaceManager($AdmxData, "admns", $null)
		$this.AdmlNamespace = $this.Set_XmlNamespaceManager($AdmlData, "admns", $null)
		$this.Set_StringTable($AdmlData)
		$this.Set_PresentationTable($AdmlData)
		
		$this.Set_AdmxCategory($AdmxData)
		$this.Set_Policies($AdmxData)
#		$AdmlData.policyDefinitionResources.resources.presentationTable.ChildNodes | ForEach-Object { $presht.Add($_.id, $_) }
#		$this.AdmlPresentationTable = $AdmlData.policyDefinitionResources.resources.presentationTable.ChildNodes
	}
	
	#Methods
	[System.Xml.XmlNamespaceManager]Set_XmlNamespaceManager([xml]$XmlDocument, [string]$NamespacePrefix, [string]$NamespaceURI)
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
	
	[void]Set_Policies([System.Xml.XmlDocument]$AdmxData)
	{
		$AdmxData.policyDefinitions.policies.ChildNodes | ForEach-Object { $this.AdmxPoliciesTable.Add($_.Name, $_) }
	}
	
	[void]Set_AdmxCategory([System.Xml.XmlDocument]$AdmxData)
	{
		$AdmxData.policyDefinitions.categories.ChildNodes |
		ForEach-Object {
			$displayNameID = $_.displayName.substring(9).TrimEnd(')');
			$lht = @{
				name		  = $_.name;
				displayNameID = $displayNameID;
				displayName   = $this.AdmlStringTable.$displayNameID;
			}
			#			$this.AdmxCategories[$_.name] = $_.displayName.substring(9).TrimEnd(')') }
			$this.AdmxCategoriesTable[$_.name] = $lht
		}
	}
	
	[void]Set_StringTable([System.Xml.XmlDocument]$AdmlData)
	{
		$AdmlData.policyDefinitionResources.resources.stringTable.string | ForEach-Object { $this.AdmlStringTable[$_.id] = $_.'#text'.Trim() }
	}
	
	[void]Set_PresentationTable([System.Xml.XmlDocument]$AdmlData)
	{
	   $AdmlData.policyDefinitionResources.resources.presentationTable.ChildNodes | ForEach-Object { $this.AdmlPresentationTable.Add($_.id, $_) }
	}

}

Class Policy{
	
	# Properties
	[string]$Admx
	[string]$LCID
	[string]$Name
	[string]$Class #User, Computer
	[string]$DisplayName
	[string]$Presentation
	[string]$ExplainText
	[string]$ParentCategory
	[string]$SupportedOn
	
	[string]$RegHive #HKEY_CURRENT_USER, HKEY_LOCAL_MACHINE
	[string]$RegPath # SOFTWARE\Policies\Microsoft\OneDrive
	[string]$RegValueName #DisablePersonalSync
	[string]$RegValueType #REG_DWORD, REG_SZ
	[string]$Label
	[string]$RegDisplayName # Enabled Value, Disabled Value, Min Value, Default Value, Max Value
	[String]$RegValue #1, 0, list, Int, 
	
	
	# Constructors
	Policy()
	{	
	}
	
	Policy([System.Collections.Hashtable]$Policy)
	{
		$this.Admx = $Policy.Admx
		$this.LCID = $Policy.LCID
		$this.Name = $Policy.Name
		$this.Class = $policy.class
		$this.DisplayName = $Policy.DisplayName
		$this.ExplainText = $Policy.ExplainText
		$this.Presentation = $Policy.Presentation
		$this.ParentCategory = $Policy.ParentCategory
		$this.SupportedOn = $Policy.SupportedOn
		$this.RegHive = $Policy.RegHive
		$this.RegPath = $Policy.RegPath
		$this.RegValueName = $Policy.RegValueName
	}
	
	#Methods	
	[Object]Clone()
	{
		Return $this.MemberwiseClone()
	}
	
	
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


# Final list of policies 
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
# Checking for Vendor supportedOn Files => To implement when the case will present
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


#region PolicyDefinitionList
#Create the main policies definition objects 
ForEach ($key In $AdmxFileslist.keys)
{
	$AdmxName = $AdmxFileslist.$key.AdmxName
	$AdmxFile = $AdmxFileslist.$key.FileName
	
	#Proces each file in the directory
	Write-Output ("**** Policies definition Processing " + $AdmxName + " ADMX")
	[xml]$AdmxData = Get-Content "$AdmxFile" @paramGetContent
	
	ForEach ($lcid In $AdmxFileslist.$key.LocalID.keys)
	{
		
		$AdmlFilePath = $AdmxFileslist.$key.LocalID.$lcid
		[xml]$AdmlData = Get-Content -path $AdmlFilePath @paramGetContent
		
		#Push all information from the specific ADMX and ADML file in a list
		$PolicyDefinitionList.Add([PolicyDefinition]::new($AdmxName, $lcid, $AdmxData, $AdmlData))
	}
}

Write-Debug -Message "Loading policies definition in $([math]::round($StopWatch.Elapsed.TotalSeconds, 3)) seconds"
$StopWatch.Restart()
#endregion PolicyDefinitionList


#region PoliciesBaseline
#Create Policies list baseline with localization 
ForEach ($PolicyDefinition In $PolicyDefinitionList)
{
#	$PolicyDefinition.Policies.gettype()
	
	Write-Output ("**** Policies localization baseline " + $PolicyDefinition.AdmxName + " " + $PolicyDefinition.LCID)
	ForEach ($key In $PolicyDefinition.AdmxPoliciesTable.keys)
	{
		$Policy = $PolicyDefinition.AdmxPoliciesTable.$key
		
		#region parentCategory
		#retrieving parentCategory
		If ($Policy.ParentCategory.ref.Contains(":"))
		{
			$parentCategoryID = $Policy.ParentCategory.ref.Split(":")[1]
			$ParentCategory = $PolicyDefinition.AdmlStringTable.$parentCategoryID
		}
		Else
		# no ':' in categoryParent information, find name in the generated category table
		{
			$parentCategoryTable = $PolicyDefinition.AdmxCategoriesTable.$($Policy.parentCategory.ref)
			If ($parentCategoryTable.displayName -ne $null)
			{
				#parentCategory displayname found in Adml category table
				$ParentCategory = $parentCategoryTable.displayName
			}
			Else
			# no display name in category table use the parentCategory reference from the ADMX
			{
				$ParentCategory = $Policy.parentCategory.ref
			}
		}
		#endregion parentCategory
		
		#region supportedOn
		#retrieve supportedOn information       
		If ($Policy.supportedOn.ref.Contains(":"))
		{
			$SupportedOnVendor = $Policy.supportedOn.ref.split(":")[0].ToLower()
			$SupportedOnId = $Policy.supportedOn.ref.split(":")[1]
			
			If ($VendorSupportedOn.ContainsKey($SupportedOnVendor))
			{
				$supportedOn = $VendorSupportedOn.$SupportedOnVendor.$SupportedOnId
			}
			#If there is no Vendor Supported On
			Else
			{
				$supportedOn = "Unknown"
			}
		}
		Else
		{
			$supportedOn = "Unknown"
		}
		#endregion supportedOn
		
		#region Class
		If ($policy.class -eq "User")
		{
			$RegHive = "HKEY_CURRENT_USER"
		}
		ElseIf ($policy.class -eq "Machine")
		{
			$RegHive = "HKEY_LOCAL_MACHINE"
		}
		Else
		{
			$RegHive = "HKEY_LOCAL_MACHINE or HKEY_CURRENT_USER"
		}
		#endregion Class
		
		#region PolicyPresentation
		If ($Policy.presentation)
		{
			$Presentation = $Policy.presentation.Substring(15).TrimEnd(')')
		}
		Else
		{
			$Presentation = ""
		}
		#endregion PolicyPresentation
		
		$PolicyTable = @{
			Admx		   = $PolicyDefinition.AdmxName;
			LCID		   = $PolicyDefinition.LCID;
			Name		   = $Policy.Name;
			Class		   = $policy.class;
			DisplayName    = $PolicyDefinition.AdmlStringTable.$($Policy.displayName.substring(9).TrimEnd(')'));
			ExplainText    = $PolicyDefinition.AdmlStringTable.$($Policy.explainText.substring(9).TrimEnd(')'));
			Presentation   = $Presentation;
			ParentCategory = $ParentCategory;
			SupportedOn    = $supportedOn;
			RegHive	       = $RegHive;
			RegPath	       = $Policy.key;
			RegValueName   = $Policy.valueName; #Useful only on Enabled / Disbale value but represent most of the policies configuration
		}
		
		$PolicyDefinition.Policies.Add([policy]::new($PolicyTable))
	}

}
Write-Debug -Message "Parsing policy baseline in $([math]::round($StopWatch.Elapsed.TotalSeconds, 3)) seconds"
$StopWatch.Restart()
#endregion PoliciesBaseline


#region PoliciesCompletion
$RegTypeMatchEvalutor = {
	Param ([string]$match)
	$m = $match
	If ($match.ToLower() -eq 'decimal') { $m = "REG_DWORD" }
	If ($match.ToLower() -eq 'string') { $m = "REG_SZ" }
	
	Return $m
}
$RegTypeRx = [regex]::new("\w+")

$basicNodeNames = @{
	enabled = @{
		node = 'enabledValue';
		Dn   = 'Enabled Value'
	};
	disabled = @{
		node = 'disabledValue';
		Dn   = 'Disabled Value'
	};
}

#complete the policies with the technical values and add them to the "$PolicyDataTable"
ForEach ($PolicyDefinition In $PolicyDefinitionList)
{
	foreach ($Policy in $PolicyDefinition.Policies) {
		$PolName = $Policy.Name
		
		#region BasicPolicy
		#Basic Policy Enabled / disabled value
		ForEach ($key In $basicNodeNames.keys)
		{
			$nodeName = $basicNodeNames.$key.node
			$Node = $PolicyDefinition.AdmxPoliciesTable.$PolName.SelectSingleNode(".//admns:$($nodeName)", $PolicyDefinition.AdmxNamespace)
			If ($Node -ne $null)
			{
				$Valuetype = [regex]::Replace($Node.ChildNodes[0].Name, $RegTypeRx, $RegTypeMatchEvalutor)
				Switch ($Node.ChildNodes[0].Name)
				{
					string {
						$Value = $Node.string
					}
					decimal {
						$Value = $Node.decimal.value.ToString()
					}
					default {
						$Value = ""
					}
				}

				#Not optimized but useful to debug
				$Policy.RegValueType = $Valuetype
				$Policy.RegDisplayName = $basicNodeNames.$key.Dn
				$Policy.RegValue = $Value
				$PolicyDataTable.Add($Policy.clone())
			}
		}
		#endregion BasicPolicy
		
		#region ElementDropdownList
		$element = $PolicyDefinition.AdmxPoliciesTable.$PolName.SelectSingleNode(".//admns:elements", $PolicyDefinition.AdmxNamespace)
		If ($element -ne $null)
		{
			
			ForEach ($Child In $element.Childnodes)
			{
				If ($Child.Name -eq "enum")
				{
					$enum = $Child
					$Pres = $PolicyDefinition.AdmlPresentationTable.$($Policy.Presentation).SelectSingleNode("//admns:*[@refId='$($enum.ID)']", $PolicyDefinition.AdmlNamespace)
#					$PolicyDefinition.AdmlPresentationTable.KFMOptInNoWizard_Pres.SelectSingleNode("//admns:*[@refId='KFMOptInNoWizard_Dropdown']", $PolicyDefinition.AdmlNamespace)
					#"SSIS:Property[@SSIS:Name='Value'
					
					#$Pres = $PolicyDefinition.AdmlPresentationTable.$PolName.Presentation.ChildNodes
#					$Pres = $PolicyDefinition.AdmlPresentationTable.$($Policy.Presentation)
					
					$elementType = $Pres.Name
					$elementLabel = $Pres.InnerText #Label
					#$PolicyDefinition.Policies.where({$_.Name -eq "GPOSetUpdateRing"}).Presentation
					#<dropdownList refId="KFMOptInNoWizard_Dropdown" noSort="true" defaultItem="0">Afficher une notification aux utilisateurs après que des dossiers ont été redirigés :</dropdownList>
#					$elementType
#					$elementLabel
					$Policy.Label = $Pres.InnerText
					$Policy.RegValueName = $enum.valueName
					
					
					foreach ($item in $enum.childnodes ) {
						$Policy.DisplayName = $PolicyDefinition.AdmlStringTable.$($item.displayName.substring(9).TrimEnd(')'));
						
					}
					
					<#
RegValueName   : DONE
RegValueType   : 
Label          : DONE
RegDisplayName : DONE
RegValue       : 
					#>
					
					
#					$Policy.RegValueType = $Valuetype
#					$Policy.RegDisplayName = $basicNodeNames.$key.Dn
#					$Policy.RegValue = $Value
#					$PolicyDataTable.Add($Policy.clone())
					
				}
				
			}
		}
		
		
		#endregion ElementDropdownList
		
#		#$PolicyDefinition.AdmxPoliciesTable.GPOSetUpdateRing.elements.enum
#		$PolicyDefinition.AdmxPoliciesTable.GPOSetUpdateRing.SelectSingleNode(".//admns:elements", $PolicyDefinition.AdmxNamespace)
#		$PolicyDefinition.AdmxPoliciesTable.KFMOptInNoWizard.SelectSingleNode(".//admns:elements", $PolicyDefinition.AdmxNamespace)
		
	}
	
}
Write-Debug -Message "Completin policies technical data in $([math]::round($StopWatch.Elapsed.TotalSeconds, 3)) seconds"
$StopWatch.Restart()
#endregion PoliciesCompletion


Break
<#
"enum"                                                             # represents a enumeration element, process node
                                {
                                    $elementType = "dropdownList"

                                    # Retrieve label, based on element.id and policy.name
                                    $oEnum = (($presentationTableChilds | Where-Object { $_.id -eq $policy.presentation.Substring(15).TrimEnd(')')}).ChildNodes | Where-Object { $_.refId -eq $element.id})

                                    $elementType = $oEnum.Name
                                    $elementLabelText = $oEnum.InnerText
                                                                
                                    # Retrieving the possible items from the dropdownlist
                                    $dropdownListValues = "List items:"
                                    $itemCount = 0
                                    $element.ChildNodes | ForEach-Object {
                                        $item = $_                                                 # represents a set of display names with one value or a set of registry subkey values
                                        If (($item -ne $null) -and ($item.name -ne "#comment"))
                                        {
                                            $itemCount = $itemCount + 1
                                            $itemLabelText = ($stringTableChilds | Where-Object { $_.id -eq $item.displayName.SubString(9).TrimEnd(')') }).InnerText
                                            If ($item.value.string -ne $null)
                                            {
                                                $dropdownListValues = ($dropdownListValues + " `n     """ + $item.value.string + """ = """ + $itemLabelText + """")
                                            }
                                            If ($item.value.decimal -ne $null)
                                            {
                                                $dropdownListValues = ($dropdownListValues + " `n     """ + $item.value.decimal.value + """ = """ + $itemLabelText + """")
                                            }
                                        }
                                    }
                                    # adding the dropdownlist items to the valueName 
                                    $valueName = $element.valueName
                                    If ($element.required -eq "true")
                                    {
                                        $valueName = $valueName + " (required)"
                                    }
                                    Write-Debug "$itemCount items processed"
                                }

#>




$statusTable =@('enabledValue', 'prout', 'disabledValue')

foreach ($state in $statusTable) {
	$statedata = $PolicyDefinition.AdmxPoliciesTable.DisablePersonalSync.SelectSingleNode(".//admns:$($state)", $PolicyDefinition.AdmxNamespace)
	$statedata -eq $null
}

$Node = $PolicyDefinition.AdmxPoliciesTable.DisablePersonalSync.SelectSingleNode(".//admns:enabledValue", $PolicyDefinition.AdmxNamespace)
$Node -eq $null



<#
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



#>
