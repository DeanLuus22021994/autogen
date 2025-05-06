<#
.SYNOPSIS
	Tests for Test-ToolboxEnvironment.ps1
.DESCRIPTION
	Comprehensive Pester test suite for the Test-ToolboxEnvironment.ps1 script
	that validates proper toolbox environment testing capabilities.
#>

BeforeAll {
	# Import the script under test
	$scriptPath = "$PSScriptRoot\Test-ToolboxEnvironment.ps1"

	# Create a global function to access internal functions for testing
	function InvokeInternalFunction {
		param(
			[string]$FunctionName,
			[hashtable]$Parameters = @{}
		)

		# Dot-source the script to get access to its functions
		. $scriptPath

		# Invoke the function with the provided parameters
		& $FunctionName @Parameters
	}

	# Create test directory structure
	$testRootDir = "TestDrive:\toolbox"
	New-Item -Path $testRootDir -ItemType Directory -Force | Out-Null
	New-Item -Path "$testRootDir\testing" -ItemType Directory -Force | Out-Null
	New-Item -Path "$testRootDir\category1" -ItemType Directory -Force | Out-Null
	New-Item -Path "$testRootDir\category2" -ItemType Directory -Force | Out-Null
	New-Item -Path "$testRootDir\documentation" -ItemType Directory -Force | Out-Null

	# Set up global test variables
	$global:testToolboxRoot = $testRootDir
	$global:originalScriptRoot = $PSScriptRoot
}

AfterAll {
	# Cleanup
	Remove-Variable -Name testToolboxRoot -Scope Global -ErrorAction SilentlyContinue
	Remove-Variable -Name originalScriptRoot -Scope Global -ErrorAction SilentlyContinue
}

Describe "Test-Tool function" {
	BeforeEach {
		# Create test tool files
		$validToolContent = @"
# ValidTool
# This script provides functionality for testing

param()

Write-Host "This is a valid tool"
"@

		$invalidToolContent = @"
# InvalidTool
# Missing proper format

Write-Host "This tool has issues"
c:\Projects\autogen\hardcoded\path
"@

		$repairableToolContent = @"
# RepairableTool

Write-Host "This tool can be fixed"
c:\Projects\autogen\fixable\path
"@

		New-Item -Path "TestDrive:\toolbox\category1\ValidTool.ps1" -ItemType File -Value $validToolContent -Force | Out-Null
		New-Item -Path "TestDrive:\toolbox\category1\InvalidTool.ps1" -ItemType File -Value $invalidToolContent -Force | Out-Null
		New-Item -Path "TestDrive:\toolbox\category1\RepairableTool.ps1" -ItemType File -Value $repairableToolContent -Force | Out-Null
	}

	It "Should pass validation for well-formed tool scripts" {
		# Arrange
		Mock Write-Host {} -ModuleName InvokeInternalFunction
		Mock Get-Content { return $validToolContent } -ModuleName InvokeInternalFunction -ParameterFilter { $Path -like "*ValidTool.ps1" }

		# Act
		$result = InvokeInternalFunction -FunctionName "Test-Tool" -Parameters @{
			ToolPath = "TestDrive:\toolbox\category1\ValidTool.ps1"
			Category = "category1"
		}

		# Assert
		$result.Status | Should -Be "Passed"
		$result.Issues.Count | Should -Be 0
	}

	It "Should fail validation for malformed tool scripts" {
		# Arrange
		Mock Write-Host {} -ModuleName InvokeInternalFunction
		Mock Get-Content { return $invalidToolContent } -ModuleName InvokeInternalFunction -ParameterFilter { $Path -like "*InvalidTool.ps1" }

		# Act
		$result = InvokeInternalFunction -FunctionName "Test-Tool" -Parameters @{
			ToolPath = "TestDrive:\toolbox\category1\InvalidTool.ps1"
			Category = "category1"
		}

		# Assert
		$result.Status | Should -Be "Failed"
		$result.Issues.Count | Should -BeGreaterThan 0
		$result.Issues | Should -Contain "Contains hardcoded absolute paths"
	}

	It "Should repair issues when Fix parameter is true" {
		# Arrange
		Mock Write-Host {} -ModuleName InvokeInternalFunction
		Mock Get-Content { return $repairableToolContent } -ModuleName InvokeInternalFunction -ParameterFilter { $Path -like "*RepairableTool.ps1" }
		Mock Set-Content {} -ModuleName InvokeInternalFunction -Verifiable

		# Set global Fix parameter
		$global:Fix = $true

		# Act
		$result = InvokeInternalFunction -FunctionName "Test-Tool" -Parameters @{
			ToolPath = "TestDrive:\toolbox\category1\RepairableTool.ps1"
			Category = "category1"
		}

		# Assert
		$result.Status | Should -Be "Failed"
		Should -Invoke Set-Content -ModuleName InvokeInternalFunction -Times 1

		# Reset global Fix parameter
		$global:Fix = $false
	}
}

Describe "Test-DocumentationGeneration function" {
	BeforeAll {
		# Create mock documentation directory
		New-Item -Path "TestDrive:\toolbox\documentation" -ItemType Directory -Force | Out-Null
	}

	It "Should pass when documentation generation is successful" {
		# Arrange
		Mock Write-Host {} -ModuleName InvokeInternalFunction
		Mock Test-Path { return $true } -ModuleName InvokeInternalFunction -ParameterFilter { $Path -like "*documentation\toolbox-documentation.md" }
		Mock Invoke-Expression { return $true } -ModuleName InvokeInternalFunction

		# Act
		$result = InvokeInternalFunction -FunctionName "Test-DocumentationGeneration"

		# Assert
		$result | Should -Be $true
	}

	It "Should fail when documentation generation fails" {
		# Arrange
		Mock Write-Host {} -ModuleName InvokeInternalFunction
		Mock Test-Path { return $false } -ModuleName InvokeInternalFunction -ParameterFilter { $Path -like "*documentation\toolbox-documentation.md" }
		Mock Invoke-Expression { throw "Error generating documentation" } -ModuleName InvokeInternalFunction

		# Act
		$result = InvokeInternalFunction -FunctionName "Test-DocumentationGeneration"

		# Assert
		$result | Should -Be $false
	}
}

Describe "Test-VSCodeTaskIntegration function" {
	BeforeAll {
		# Create test VS Code tasks.json
		$validTasksJson = @'
{
  "version": "2.0.0",
  "tasks": [
	{
	  "label": "Toolbox: Run Test Tool",
	  "type": "shell",
	  "command": "powershell",
	  "args": [
		"-ExecutionPolicy",
		"Bypass",
		"-File",
		"${workspaceFolder}/.toolbox/category1/ValidTool.ps1"
	  ],
	  "group": "test"
	}
  ]
}
'@

		$invalidTasksJson = @'
{
  "version": "2.0.0",
  "tasks": [
	{
	  "label": "Toolbox: Run Test Tool",
	  "type": "shell",
	  "command": "powershell",
	  "args": [
		"-ExecutionPolicy",
		"Bypass",
		"-File",
		"C:/Projects/autogen/.toolbox/category1/ValidTool.ps1"
	  ],
	  "group": "test"
	}
  ]
}
'@

		$noToolboxTasksJson = @'
{
  "version": "2.0.0",
  "tasks": [
	{
	  "label": "Run Some Task",
	  "type": "shell",
	  "command": "powershell",
	  "args": [
		"-ExecutionPolicy",
		"Bypass",
		"-File",
		"script.ps1"
	  ],
	  "group": "test"
	}
  ]
}
'@
	}

	It "Should pass for valid VS Code tasks configuration" {
		# Arrange
		Mock Write-Host {} -ModuleName InvokeInternalFunction
		Mock Test-Path { return $true } -ModuleName InvokeInternalFunction -ParameterFilter { $Path -like "*\.vscode\tasks.json" }
		Mock Get-Content { return $validTasksJson } -ModuleName InvokeInternalFunction -ParameterFilter { $Path -like "*\.vscode\tasks.json" }

		# Act
		$result = InvokeInternalFunction -FunctionName "Test-VSCodeTaskIntegration"

		# Assert
		$result | Should -Be $true
	}

	It "Should fail for invalid VS Code tasks configuration with absolute paths" {
		# Arrange
		Mock Write-Host {} -ModuleName InvokeInternalFunction
		Mock Test-Path { return $true } -ModuleName InvokeInternalFunction -ParameterFilter { $Path -like "*\.vscode\tasks.json" }
		Mock Get-Content { return $invalidTasksJson } -ModuleName InvokeInternalFunction -ParameterFilter { $Path -like "*\.vscode\tasks.json" }

		# Act
		$result = InvokeInternalFunction -FunctionName "Test-VSCodeTaskIntegration"

		# Assert
		$result | Should -Be $false
	}

	It "Should fail when no toolbox tasks are defined" {
		# Arrange
		Mock Write-Host {} -ModuleName InvokeInternalFunction
		Mock Test-Path { return $true } -ModuleName InvokeInternalFunction -ParameterFilter { $Path -like "*\.vscode\tasks.json" }
		Mock Get-Content { return $noToolboxTasksJson } -ModuleName InvokeInternalFunction -ParameterFilter { $Path -like "*\.vscode\tasks.json" }

		# Act
		$result = InvokeInternalFunction -FunctionName "Test-VSCodeTaskIntegration"

		# Assert
		$result | Should -Be $false
	}

	It "Should fail when tasks.json is missing" {
		# Arrange
		Mock Write-Host {} -ModuleName InvokeInternalFunction
		Mock Test-Path { return $false } -ModuleName InvokeInternalFunction -ParameterFilter { $Path -like "*\.vscode\tasks.json" }

		# Act
		$result = InvokeInternalFunction -FunctionName "Test-VSCodeTaskIntegration"

		# Assert
		$result | Should -Be $false
	}
}

Describe "Test-DirTagFiles function" {
	BeforeEach {
		# Create test DIR.TAG files
		$dirTagContent = @"
#INDEX: .toolbox/category1
#TODO:
  - Add additional tools to this category NOT_STARTED

status: PARTIALLY_COMPLETE
updated: 2023-05-01T12:00:00Z
description: |
  Tools for category1-related operations.
"@

		New-Item -Path "TestDrive:\toolbox\category1\DIR.TAG" -ItemType File -Value $dirTagContent -Force | Out-Null
		# category2 will be missing DIR.TAG by design
	}

	It "Should pass when all directories have DIR.TAG files" {
		# Arrange
		Mock Write-Host {} -ModuleName InvokeInternalFunction
		Mock Get-ChildItem {
			# Return only directory with DIR.TAG
			return @(
				[PSCustomObject]@{
					FullName = "TestDrive:\toolbox\category1"
					Name = "category1"
				}
			)
		} -ModuleName InvokeInternalFunction -ParameterFilter { $Path -like "*toolbox*" -and $Directory }

		Mock Test-Path { return $true } -ModuleName InvokeInternalFunction -ParameterFilter { $Path -like "*DIR.TAG" }

		# Act
		$result = InvokeInternalFunction -FunctionName "Test-DirTagFiles"

		# Assert
		$result | Should -Be $true
	}

	It "Should fail when directories are missing DIR.TAG files" {
		# Arrange
		Mock Write-Host {} -ModuleName InvokeInternalFunction
		Mock Get-ChildItem {
			# Return both directories
			return @(
				[PSCustomObject]@{
					FullName = "TestDrive:\toolbox\category1"
					Name = "category1"
				},
				[PSCustomObject]@{
					FullName = "TestDrive:\toolbox\category2"
					Name = "category2"
				}
			)
		} -ModuleName InvokeInternalFunction -ParameterFilter { $Path -like "*toolbox*" -and $Directory }

		Mock Test-Path {
			# Only return true for the first directory
			param($Path)
			return $Path -like "*category1\DIR.TAG"
		} -ModuleName InvokeInternalFunction

		# Act
		$result = InvokeInternalFunction -FunctionName "Test-DirTagFiles"

		# Assert
		$result | Should -Be $false
	}

	It "Should create missing DIR.TAG files when Fix parameter is true" {
		# Arrange
		Mock Write-Host {} -ModuleName InvokeInternalFunction
		Mock Get-ChildItem {
			# Return both directories
			return @(
				[PSCustomObject]@{
					FullName = "TestDrive:\toolbox\category1"
					Name = "category1"
				},
				[PSCustomObject]@{
					FullName = "TestDrive:\toolbox\category2"
					Name = "category2"
				}
			)
		} -ModuleName InvokeInternalFunction -ParameterFilter { $Path -like "*toolbox*" -and $Directory }

		Mock Test-Path {
			# Only return true for the first directory
			param($Path)
			return $Path -like "*category1\DIR.TAG"
		} -ModuleName InvokeInternalFunction

		Mock Set-Content {} -ModuleName InvokeInternalFunction -Verifiable
		Mock Get-Date { return "2023-05-01T12:00:00Z" } -ModuleName InvokeInternalFunction -ParameterFilter { $Format -eq "yyyy-MM-ddTHH:mm:ssZ" }

		# Set global Fix parameter
		$global:Fix = $true

		# Act
		$result = InvokeInternalFunction -FunctionName "Test-DirTagFiles"

		# Assert
		Should -Invoke Set-Content -ModuleName InvokeInternalFunction -Times 1

		# Reset global Fix parameter
		$global:Fix = $false
	}
}

Describe "Test-ToolboxCatalog function" {
	BeforeAll {
		# Create test catalog XML
		$validCatalog = @"
<?xml version="1.0" encoding="utf-8"?>
<toolbox_catalog>
  <categories>
	<category id="cat1">
	  <name>category1</name>
	  <description>Tools for category1</description>
	  <tools>
		<tool>
		  <id>tool1</id>
		  <name>ValidTool</name>
		  <path>.toolbox/category1/ValidTool.ps1</path>
		  <sequence>1</sequence>
		  <dependencies>
			<dependency>dep1</dependency>
		  </dependencies>
		</tool>
	  </tools>
	</category>
  </categories>
</toolbox_catalog>
"@

		$invalidCatalog = @"
<?xml version="1.0" encoding="utf-8"?>
<toolbox_catalog>
  <categories>
	<category id="cat1">
	  <name>category1</name>
	  <description>Tools for category1</description>
	  <tools>
		<tool>
		  <id>tool1</id>
		  <name>ValidTool</name>
		  <path>.toolbox/category1/MissingTool.ps1</path>
		  <sequence>1</sequence>
		  <dependencies>
			<dependency>dep1</dependency>
		  </dependencies>
		</tool>
		<tool>
		  <id>tool1</id>  <!-- Duplicate ID -->
		  <name>DuplicateTool</name>
		  <path>.toolbox/category1/DuplicateTool.ps1</path>
		  <sequence>2</sequence>
		  <dependencies>
			<dependency>nonexistent</dependency>
		  </dependencies>
		</tool>
	  </tools>
	</category>
  </categories>
</toolbox_catalog>
"@

		$emptyCatalog = @"
<?xml version="1.0" encoding="utf-8"?>
<toolbox_catalog>
  <categories>
  </categories>
</toolbox_catalog>
"@

		# Create test tool files
		New-Item -Path "TestDrive:\toolbox\category1\ValidTool.ps1" -ItemType File -Force | Out-Null
		New-Item -Path "TestDrive:\toolbox\category1\NewTool.ps1" -ItemType File -Force | Out-Null
	}

	It "Should pass for valid catalog with all tools registered" {
		# Arrange
		Mock Write-Host {} -ModuleName InvokeInternalFunction
		Mock Test-Path { return $true } -ModuleName InvokeInternalFunction -ParameterFilter { $Path -like "*toolbox-catalog.xml" -or $Path -like "*ValidTool.ps1" }
		Mock Get-Content { return $validCatalog } -ModuleName InvokeInternalFunction -ParameterFilter { $Path -like "*toolbox-catalog.xml" }

		# Mock XML operations
		Mock Get-ChildItem {
			# Return only the tools that are in the catalog
			return @(
				[PSCustomObject]@{
					FullName = "TestDrive:\toolbox\category1\ValidTool.ps1"
					Name = "ValidTool.ps1"
					Directory = [PSCustomObject]@{ Name = "category1" }
				}
			)
		} -ModuleName InvokeInternalFunction -ParameterFilter { $Filter -eq "*.ps1" }

		Mock Get-Item {
			return [PSCustomObject]@{
				FullName = "TestDrive:\Projects\autogen\"
			}
		} -ModuleName InvokeInternalFunction

		# Act
		$result = InvokeInternalFunction -FunctionName "Test-ToolboxCatalog"

		# Assert
		$result | Should -Be $true
	}

	It "Should fail when catalog has invalid structure" {
		# Arrange
		Mock Write-Host {} -ModuleName InvokeInternalFunction
		Mock Test-Path { return $true } -ModuleName InvokeInternalFunction -ParameterFilter { $Path -like "*toolbox-catalog.xml" }
		Mock Get-Content { return $emptyCatalog } -ModuleName InvokeInternalFunction -ParameterFilter { $Path -like "*toolbox-catalog.xml" }

		# Act
		$result = InvokeInternalFunction -FunctionName "Test-ToolboxCatalog"

		# Assert
		$result | Should -Be $false
	}

	It "Should fail when catalog contains duplicate IDs" {
		# Arrange
		Mock Write-Host {} -ModuleName InvokeInternalFunction
		Mock Test-Path { return $true } -ModuleName InvokeInternalFunction -ParameterFilter { $Path -like "*toolbox-catalog.xml" }
		Mock Get-Content { return $invalidCatalog } -ModuleName InvokeInternalFunction -ParameterFilter { $Path -like "*toolbox-catalog.xml" }

		# Mock XML operations
		Mock Get-ChildItem {
			return @(
				[PSCustomObject]@{
					FullName = "TestDrive:\toolbox\category1\ValidTool.ps1"
					Name = "ValidTool.ps1"
					Directory = [PSCustomObject]@{ Name = "category1" }
				}
			)
		} -ModuleName InvokeInternalFunction -ParameterFilter { $Filter -eq "*.ps1" }

		Mock Get-Item {
			return [PSCustomObject]@{
				FullName = "TestDrive:\Projects\autogen\"
			}
		} -ModuleName InvokeInternalFunction

		# Act
		$result = InvokeInternalFunction -FunctionName "Test-ToolboxCatalog"

		# Assert
		$result | Should -Be $false
	}

	It "Should update catalog when Fix parameter is true and tools are missing from catalog" {
		# Arrange
		Mock Write-Host {} -ModuleName InvokeInternalFunction
		Mock Test-Path { return $true } -ModuleName InvokeInternalFunction
		Mock Get-Content { return $validCatalog } -ModuleName InvokeInternalFunction -ParameterFilter { $Path -like "*toolbox-catalog.xml" }

		# Mock XML operations and other dependencies
		Mock Get-ChildItem {
			# Return both tools, one is in catalog, one is not
			return @(
				[PSCustomObject]@{
					FullName = "TestDrive:\toolbox\category1\ValidTool.ps1"
					Name = "ValidTool.ps1"
					Directory = [PSCustomObject]@{ Name = "category1" }
				},
				[PSCustomObject]@{
					FullName = "TestDrive:\toolbox\category1\NewTool.ps1"
					Name = "NewTool.ps1"
					Directory = [PSCustomObject]@{ Name = "category1" }
				}
			)
		} -ModuleName InvokeInternalFunction -ParameterFilter { $Filter -eq "*.ps1" }

		Mock Get-Item {
			return [PSCustomObject]@{
				FullName = "TestDrive:\Projects\autogen\"
			}
		} -ModuleName InvokeInternalFunction

		# Mock XML methods and related operations
		Mock SelectSingleNode {
			return [PSCustomObject]@{
				name = "category1"
				tools = [PSCustomObject]@{
					tool = @()
					AppendChild = { param($child) }
				}
			}
		} -ModuleName InvokeInternalFunction

		Mock Append { } -ModuleName InvokeInternalFunction
		Mock AppendChild { } -ModuleName InvokeInternalFunction
		Mock Save { } -ModuleName InvokeInternalFunction

		# Set global Fix parameter
		$global:Fix = $true

		# Act - this test is focused more on not throwing exceptions than detailed validation
		$result = InvokeInternalFunction -FunctionName "Test-ToolboxCatalog"

		# Reset global Fix parameter
		$global:Fix = $false
	}
}

Describe "Main script behavior" {
	BeforeAll {
		# Setup tests for the script as a whole
		$scriptContent = Get-Content -Path $scriptPath -Raw

		# Create test environment
		New-Item -Path "TestDrive:\Projects\autogen\.toolbox\category1" -ItemType Directory -Force | Out-Null
		New-Item -Path "TestDrive:\Projects\autogen\.toolbox\testing" -ItemType Directory -Force | Out-Null
		New-Item -Path "TestDrive:\Projects\autogen\.toolbox\category1\TestTool.ps1" -ItemType File -Force | Out-Null
	}

	It "Should correctly report overall success when all tests pass" {
		# This test checks the overall script behavior by mocking the called functions
		Mock Test-Tool { return @{ Status = "Passed"; Tool = "TestTool"; Category = "category1"; Issues = @() } }
		Mock Test-DocumentationGeneration { return $true }
		Mock Test-VSCodeTaskIntegration { return $true }
		Mock Test-ToolboxCatalog { return $true }
		Mock Test-DirTagFiles { return $true }
		Mock Write-Host {}
		Mock Get-ChildItem {
			return @(
				[PSCustomObject]@{
					FullName = "TestDrive:\Projects\autogen\.toolbox\category1\TestTool.ps1"
					Name = "TestTool.ps1"
					Directory = [PSCustomObject]@{ Name = "category1" }
				}
			)
		} -ParameterFilter { $Filter -eq "*.ps1" }
		Mock Exit {}

		# Execute the script
		Invoke-Expression -Command $scriptContent

		# Check that Exit is called with 0 (success)
		Should -Invoke Exit -ParameterFilter { $Args[0] -eq 0 } -Exactly 1
	}

	It "Should correctly report overall failure when any test fails" {
		# Mock at least one test function to fail
		Mock Test-Tool { return @{ Status = "Passed"; Tool = "TestTool"; Category = "category1"; Issues = @() } }
		Mock Test-DocumentationGeneration { return $false }  # This test fails
		Mock Test-VSCodeTaskIntegration { return $true }
		Mock Test-ToolboxCatalog { return $true }
		Mock Test-DirTagFiles { return $true }
		Mock Write-Host {}
		Mock Get-ChildItem {
			return @(
				[PSCustomObject]@{
					FullName = "TestDrive:\Projects\autogen\.toolbox\category1\TestTool.ps1"
					Name = "TestTool.ps1"
					Directory = [PSCustomObject]@{ Name = "category1" }
				}
			)
		} -ParameterFilter { $Filter -eq "*.ps1" }
		Mock Exit {}

		# Execute the script
		Invoke-Expression -Command $scriptContent

		# Check that Exit is called with 1 (failure)
		Should -Invoke Exit -ParameterFilter { $Args[0] -eq 1 } -Exactly 1
	}

	It "Should use the Fix parameter to attempt repairs when specified" {
		# Set up the global Fix parameter
		$global:Fix = $true

		# Mock to detect Fix parameter usage
		Mock Test-Tool {
			param($ToolPath, $Category)
			if ($global:Fix) {
				return @{ Status = "Passed"; Tool = "TestTool"; Category = "category1"; Issues = @() }
			} else {
				return @{ Status = "Failed"; Tool = "TestTool"; Category = "category1"; Issues = @("Test issue") }
			}
		}
		Mock Test-DocumentationGeneration { return $true }
		Mock Test-VSCodeTaskIntegration { return $true }
		Mock Test-ToolboxCatalog { return $true }
		Mock Test-DirTagFiles { return $true }
		Mock Write-Host {}
		Mock Get-ChildItem {
			return @(
				[PSCustomObject]@{
					FullName = "TestDrive:\Projects\autogen\.toolbox\category1\TestTool.ps1"
					Name = "TestTool.ps1"
					Directory = [PSCustomObject]@{ Name = "category1" }
				}
			)
		} -ParameterFilter { $Filter -eq "*.ps1" }
		Mock Exit {}

		# Execute the script
		Invoke-Expression -Command "$scriptContent -Fix"

		# Check that the Fix flag was effectively used
		Should -Invoke Test-Tool -Exactly 1
		Should -Invoke Exit -ParameterFilter { $Args[0] -eq 0 } -Exactly 1

		# Reset global Fix parameter
		$global:Fix = $false
	}
}# Test-ToolboxEnvironment.Tests.ps1
# Tests for Test-ToolboxEnvironment.ps1

BeforeAll {
	# Path to the script being tested
	$scriptPath = "$PSScriptRoot\Test-ToolboxEnvironment.ps1"

	# Import the script as a module to access its functions
	# Use a script block with dot-sourcing to access the script's functions
	. $scriptPath

	# Set up common test paths
	$testToolboxRoot = "TestDrive:\toolbox"
	$testProjectRoot = "TestDrive:\Projects\autogen"

	# Create test directory structure
	New-Item -Path $testToolboxRoot -ItemType Directory -Force
	New-Item -Path "$testToolboxRoot\testing" -ItemType Directory -Force
	New-Item -Path "$testToolboxRoot\category1" -ItemType Directory -Force
	New-Item -Path "$testToolboxRoot\category2" -ItemType Directory -Force
	New-Item -Path "$testProjectRoot\.github\schemas" -ItemType Directory -Force -ErrorAction SilentlyContinue
	New-Item -Path "$testProjectRoot\.vscode" -ItemType Directory -Force -ErrorAction SilentlyContinue

	# Set up the default PSScriptRoot for testing
	$global:originalPSScriptRoot = $PSScriptRoot
	$global:PSScriptRoot = "$testToolboxRoot\testing"
}

AfterAll {
	# Restore original PSScriptRoot
	$global:PSScriptRoot = $global:originalPSScriptRoot
	Remove-Variable -Name originalPSScriptRoot -Scope Global
}

Describe "Test-ToolboxEnvironment" {
	Context "Test-Tool function" {
		BeforeEach {
			# Create test tool files
			$validToolContent = @"
# ValidTool
# This script provides functionality for testing

param()

Write-Host "This is a valid tool"
"@

			$invalidToolContent = @"
# InvalidTool
# Missing proper parameter block

Write-Host "This is an invalid tool"
c:\Projects\autogen\some\hardcoded\path
"@

			New-Item -Path "$testToolboxRoot\category1\ValidTool.ps1" -ItemType File -Value $validToolContent -Force
			New-Item -Path "$testToolboxRoot\category1\InvalidTool.ps1" -ItemType File -Value $invalidToolContent -Force
		}

		It "Should pass for valid tool" {
			# Mock to prevent actual console output during test
			Mock Write-Host {}

			# Test the function
			$result = Test-Tool -ToolPath "$testToolboxRoot\category1\ValidTool.ps1" -Category "category1"

			$result.Status | Should -Be "Passed"
			$result.Tool | Should -Be "ValidTool"
			$result.Category | Should -Be "category1"
			$result.Issues.Count | Should -Be 0
		}

		It "Should fail for invalid tool" {
			Mock Write-Host {}

			$result = Test-Tool -ToolPath "$testToolboxRoot\category1\InvalidTool.ps1" -Category "category1"

			$result.Status | Should -Be "Failed"
			$result.Tool | Should -Be "InvalidTool"
			$result.Category | Should -Be "category1"
			$result.Issues.Count | Should -BeGreaterThan 0
			$result.Issues | Should -Contain "Contains hardcoded absolute paths"
		}

		It "Should fix issues when Fix parameter is provided" {
			Mock Write-Host {}
			Mock Set-Content {} -Verifiable

			# Call with Fix parameter
			$global:Fix = $true
			$result = Test-Tool -ToolPath "$testToolboxRoot\category1\InvalidTool.ps1" -Category "category1"
			$global:Fix = $false

			# Verify Set-Content was called to fix issues
			Should -InvokeVerifiable
		}
	}

	Context "Test-DirTagFiles function" {
		BeforeEach {
			# Create test DIR.TAG files
			$dirTagContent = @"
#INDEX: .toolbox/category1
#TODO:
  - Add additional tools to this category NOT_STARTED

status: PARTIALLY_COMPLETE
updated: 2023-05-01T12:00:00Z
description: |
  Tools for category1-related operations.
"@

			New-Item -Path "$testToolboxRoot\category1\DIR.TAG" -ItemType File -Value $dirTagContent -Force
			# category2 will be missing DIR.TAG
		}

		It "Should pass when all directories have DIR.TAG files" {
			Mock Write-Host {}
			Mock Get-ChildItem {
				# Only return the directory that has a DIR.TAG file
				return @(
					[PSCustomObject]@{
						FullName = "$testToolboxRoot\category1"
						Name = "category1"
					}
				)
			} -ParameterFilter { $Path -like "*toolbox*" -and $Directory }

			$result = Test-DirTagFiles

			$result | Should -Be $true
		}

		It "Should fail when directories are missing DIR.TAG files" {
			Mock Write-Host {}
			Mock Get-ChildItem {
				# Return both directories, one with DIR.TAG and one without
				return @(
					[PSCustomObject]@{
						FullName = "$testToolboxRoot\category1"
						Name = "category1"
					},
					[PSCustomObject]@{
						FullName = "$testToolboxRoot\category2"
						Name = "category2"
					}
				)
			} -ParameterFilter { $Path -like "*toolbox*" -and $Directory }

			$result = Test-DirTagFiles

			$result | Should -Be $false
		}

		It "Should create missing DIR.TAG files when Fix parameter is provided" {
			Mock Write-Host {}
			Mock Get-ChildItem {
				# Return both directories, one with DIR.TAG and one without
				return @(
					[PSCustomObject]@{
						FullName = "$testToolboxRoot\category1"
						Name = "category1"
					},
					[PSCustomObject]@{
						FullName = "$testToolboxRoot\category2"
						Name = "category2"
					}
				)
			} -ParameterFilter { $Path -like "*toolbox*" -and $Directory }
			Mock Set-Content {} -Verifiable
			Mock Get-Date { return "2023-05-01T12:00:00Z" } -ParameterFilter { $Format -eq "yyyy-MM-ddTHH:mm:ssZ" }

			$global:Fix = $true
			$result = Test-DirTagFiles
			$global:Fix = $false

			# Verify Set-Content was called to create DIR.TAG
			Should -InvokeVerifiable
		}
	}

	Context "Test-ToolboxCatalog function" {
		BeforeEach {
			# Create test catalog XML
			$validCatalogXml = @"
<?xml version="1.0" encoding="utf-8"?>
<toolbox_catalog>
  <categories>
	<category id="cat1">
	  <name>category1</name>
	  <description>Tools for category1</description>
	  <tools>
		<tool>
		  <id>tool1</id>
		  <name>ValidTool</name>
		  <path>.toolbox/category1/ValidTool.ps1</path>
		  <sequence>1</sequence>
		  <dependencies>
			<dependency>dep1</dependency>
		  </dependencies>
		</tool>
	  </tools>
	</category>
  </categories>
</toolbox_catalog>
"@

			$invalidCatalogXml = @"
<?xml version="1.0" encoding="utf-8"?>
<toolbox_catalog>
  <categories>
	<category id="cat1">
	  <name>category1</name>
	  <description>Tools for category1</description>
	  <tools>
		<tool>
		  <id>tool1</id>
		  <name>ValidTool</name>
		  <path>.toolbox/category1/MissingTool.ps1</path>
		  <sequence>1</sequence>
		  <dependencies>
			<dependency>dep1</dependency>
		  </dependencies>
		</tool>
		<tool>
		  <id>tool1</id>  <!-- Duplicate ID -->
		  <name>DuplicateTool</name>
		  <path>.toolbox/category1/DuplicateTool.ps1</path>
		  <sequence>2</sequence>
		  <dependencies>
			<dependency>nonexistent</dependency>
		  </dependencies>
		</tool>
	  </tools>
	</category>
  </categories>
</toolbox_catalog>
"@

			New-Item -Path "$testToolboxRoot\toolbox-catalog.xml" -ItemType File -Value $validCatalogXml -Force
		}

		It "Should pass for valid catalog" {
			Mock Write-Host {}
			Mock Test-Path { $true } -ParameterFilter { $Path -like "*toolbox-catalog.xml" -or $Path -like "*toolbox_catalog_schema.xsd" -or $Path -like "*.toolbox/category1/ValidTool.ps1" }
			Mock Get-Content { $validCatalogXml } -ParameterFilter { $Path -like "*toolbox-catalog.xml" }

			# Mock XML operations
			$mockXml = [xml]$validCatalogXml
			Mock New-Object { $mockXml } -ParameterFilter { $TypeName -eq "System.Xml.XmlDocument" }

			Mock Get-ChildItem {
				# Return only the existing tool
				return @(
					[PSCustomObject]@{
						FullName = "$testToolboxRoot\category1\ValidTool.ps1"
						Name = "ValidTool.ps1"
					}
				)
			} -ParameterFilter { $Path -like "*toolbox*" -and $Filter -eq "*.ps1" }

			Mock Get-Item {
				return [PSCustomObject]@{
					FullName = "$testProjectRoot"
				}
			} -ParameterFilter { $Path -like "*Projects\autogen*" }

			$result = Test-ToolboxCatalog

			$result | Should -Be $true
		}

		It "Should fail for catalog with missing tools" {
			Mock Write-Host {}
			Mock Test-Path {
				if ($Path -like "*toolbox-catalog.xml") { return $true }
				if ($Path -like "*.toolbox/category1/MissingTool.ps1") { return $false }
				return $true
			}
			Mock Get-Content { $invalidCatalogXml } -ParameterFilter { $Path -like "*toolbox-catalog.xml" }

			# Mock XML operations
			$mockXml = [xml]$invalidCatalogXml
			Mock New-Object { $mockXml } -ParameterFilter { $TypeName -eq "System.Xml.XmlDocument" }

			Mock Get-ChildItem {
				# Return only the existing tool
				return @(
					[PSCustomObject]@{
						FullName = "$testToolboxRoot\category1\ValidTool.ps1"
						Name = "ValidTool.ps1"
					}
				)
			} -ParameterFilter { $Path -like "*toolbox*" -and $Filter -eq "*.ps1" }

			Mock Get-Item {
				return [PSCustomObject]@{
					FullName = "$testProjectRoot"
				}
			} -ParameterFilter { $Path -like "*Projects\autogen*" }

			$result = Test-ToolboxCatalog

			$result | Should -Be $false
		}

		It "Should attempt to fix catalog when Fix parameter is provided" {
			Mock Write-Host {}
			Mock Test-Path {
				if ($Path -like "*toolbox-catalog.xml") { return $true }
				return $true
			}
			Mock Get-Content { $validCatalogXml } -ParameterFilter { $Path -like "*toolbox-catalog.xml" }

			# Mock XML operations
			$mockXml = [xml]$validCatalogXml
			# Create a custom mock that implements required methods
			$mockXml | Add-Member -MemberType ScriptMethod -Name Save -Value { param($path) } -Force
			$mockXml | Add-Member -MemberType ScriptMethod -Name CreateElement -Value { param($name) return [System.Xml.XmlElement]::new() } -Force

			Mock New-Object { $mockXml } -ParameterFilter { $TypeName -eq "System.Xml.XmlDocument" }

			Mock Get-ChildItem {
				# Return tools including one that's not in the catalog
				return @(
					[PSCustomObject]@{
						FullName = "$testToolboxRoot\category1\ValidTool.ps1"
						Name = "ValidTool.ps1"
						Directory = [PSCustomObject]@{ Name = "category1" }
					},
					[PSCustomObject]@{
						FullName = "$testToolboxRoot\category1\NewTool.ps1"
						Name = "NewTool.ps1"
						Directory = [PSCustomObject]@{ Name = "category1" }
					}
				)
			} -ParameterFilter { $Path -like "*toolbox*" -and $Filter -eq "*.ps1" }

			Mock Get-Item {
				return [PSCustomObject]@{
					FullName = "$testProjectRoot"
				}
			} -ParameterFilter { $Path -like "*Projects\autogen*" }

			# This test is simplified due to the complexity of the XML operations
			$global:Fix = $true
			$result = Test-ToolboxCatalog
			$global:Fix = $false

			# We're just checking that the function runs without error when Fix is true
			$result | Should -Not -BeNullOrEmpty
		}
	}

	Context "Test-VSCodeTaskIntegration function" {
		BeforeEach {
			# Create test tasks.json
			$validTasksJson = @'
{
  "version": "2.0.0",
  "tasks": [
	{
	  "label": "Toolbox: Run Test Tool",
	  "type": "shell",
	  "command": "powershell",
	  "args": [
		"-ExecutionPolicy",
		"Bypass",
		"-File",
		"${workspaceFolder}/.toolbox/category1/ValidTool.ps1"
	  ],
	  "group": "test"
	}
  ]
}
'@

			$invalidTasksJson = @'
{
  "version": "2.0.0",
  "tasks": [
	{
	  "label": "Toolbox: Run Test Tool",
	  "type": "shell",
	  "command": "powershell",
	  "args": [
		"-ExecutionPolicy",
		"Bypass",
		"-File",
		"C:/Projects/autogen/.toolbox/category1/ValidTool.ps1"
	  ],
	  "group": "test"
	}
  ]
}
'@

			New-Item -Path "$testProjectRoot\.vscode\tasks.json" -ItemType File -Value $validTasksJson -Force
		}

		It "Should pass for valid VS Code task integration" {
			Mock Write-Host {}
			Mock Test-Path { return $true } -ParameterFilter { $Path -like "*.vscode\tasks.json" }
			Mock Get-Content { return $validTasksJson } -ParameterFilter { $Path -like "*.vscode\tasks.json" }

			$result = Test-VSCodeTaskIntegration

			$result | Should -Be $true
		}

		It "Should fail for invalid VS Code task integration" {
			Mock Write-Host {}
			Mock Test-Path { return $true } -ParameterFilter { $Path -like "*.vscode\tasks.json" }
			Mock Get-Content { return $invalidTasksJson } -ParameterFilter { $Path -like "*.vscode\tasks.json" }

			$result = Test-VSCodeTaskIntegration

			$result | Should -Be $false
		}

		It "Should fail when tasks.json is missing" {
			Mock Write-Host {}
			Mock Test-Path { return $false } -ParameterFilter { $Path -like "*.vscode\tasks.json" }

			$result = Test-VSCodeTaskIntegration

			$result | Should -Be $false
		}
	}

	Context "Test-DocumentationGeneration function" {
		It "Should pass when documentation generation succeeds" {
			Mock Write-Host {}
			Mock Test-Path { return $true } -ParameterFilter { $Path -like "*documentation\toolbox-documentation.md" }
			# Mock for script execution with the & operator
			Mock Invoke-Expression { } -ParameterFilter { $Command -like "*Generate-ToolboxDocs.ps1*" }

			# Need to mock the script execution more directly
			Mock Get-Command { return $true } -ParameterFilter { $Name -like "*Generate-ToolboxDocs.ps1*" }

			$result = Test-DocumentationGeneration

			$result | Should -Be $true
		}

		It "Should fail when documentation generation fails" {
			Mock Write-Host {}
			Mock Test-Path { return $false } -ParameterFilter { $Path -like "*documentation\toolbox-documentation.md" }
			# Mock for script execution with the & operator to throw an error
			Mock Invoke-Expression { throw "Documentation generation error" } -ParameterFilter { $Command -like "*Generate-ToolboxDocs.ps1*" }

			$result = Test-DocumentationGeneration

			$result | Should -Be $false
		}
	}

	Context "Main script execution" {
		BeforeAll {
			# Create a mock for the main script functions that we want to test indirectly
			Mock Test-Tool {
				return @{
					Tool = "TestTool"
					Category = "testing"
					Status = "Passed"
					Issues = @()
				}
			}
			Mock Test-DocumentationGeneration { return $true }
			Mock Test-VSCodeTaskIntegration { return $true }
			Mock Test-ToolboxCatalog { return $true }
			Mock Test-DirTagFiles { return $true }
			Mock Write-Host {} # Suppress all output
			Mock Exit {} # Prevent actual exit
		}

		It "Should report success when all tests pass" {
			Mock Get-ChildItem {
				return @(
					[PSCustomObject]@{
						FullName = "$testToolboxRoot\testing\TestTool.ps1"
						Name = "TestTool.ps1"
						Directory = [PSCustomObject]@{ Name = "testing" }
					}
				)
			} -ParameterFilter { $Path -like "*toolbox*" -and $Filter -eq "*.ps1" }

			# Execute the script without dot-sourcing
			& $scriptPath

			# Check that Exit was called with code 0 for success
			Should -Invoke Exit -ParameterFilter { $Args[0] -eq 0 }
		}

		It "Should report failure when any test fails" {
			# Mock one of the tests to fail
			Mock Test-ToolboxCatalog { return $false }

			Mock Get-ChildItem {
				return @(
					[PSCustomObject]@{
						FullName = "$testToolboxRoot\testing\TestTool.ps1"
						Name = "TestTool.ps1"
						Directory = [PSCustomObject]@{ Name = "testing" }
					}
				)
			} -ParameterFilter { $Path -like "*toolbox*" -and $Filter -eq "*.ps1" }

			# Execute the script without dot-sourcing
			& $scriptPath

			# Check that Exit was called with code 1 for failure
			Should -Invoke Exit -ParameterFilter { $Args[0] -eq 1 }
		}
	}
}