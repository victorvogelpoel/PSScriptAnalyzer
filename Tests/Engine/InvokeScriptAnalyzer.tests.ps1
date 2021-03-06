﻿Import-Module PSScriptAnalyzer
$sa = Get-Command Invoke-ScriptAnalyzer
$directory = Split-Path -Parent $MyInvocation.MyCommand.Path
$singularNouns = "PSUseSingularNouns"
$rules = $singularNouns, "PSUseApprovedVerbs"
$avoidRules = "PSAvoid*"
$useRules = "PSUse*"

Describe "Test available parameters" {
    $params = $sa.Parameters
    Context "Path parameter" {
        It "has a Path parameter" {
            $params.ContainsKey("Path") | Should Be $true
        }
        
        It "accepts string" {
            $params["Path"].ParameterType.FullName | Should Be "System.String"
        }
    }

    Context "CustomizedRulePath parameters" {
        It "has a CustomizedRulePath parameter" {
            $params.ContainsKey("CustomizedRulePath") | Should Be $true
        }

        It "accepts string array" {
            $params["CustomizedRulePath"].ParameterType.FullName | Should Be "System.String[]"
        }
    }

    Context "IncludeRule parameters" {
        It "has an IncludeRule parameter" {
            $params.ContainsKey("IncludeRule") | Should Be $true
        }

        It "accepts string array" {
            $params["IncludeRule"].ParameterType.FullName | Should Be "System.String[]"
        }
    }

    Context "Severity parameters" {
        It "has a severity parameters" {
            $params.ContainsKey("Severity") | Should Be $true
        }

        It "accepts string array" {
            $params["Severity"].ParameterType.FullName | Should Be "System.String[]"
        }
    }
}

Describe "Test Path" {
    Context "When given a single file" {
        It "Has the same effect as without Path parameter" {
            $withPath = Invoke-ScriptAnalyzer $directory\TestScript.ps1
            $withoutPath = Invoke-ScriptAnalyzer -Path $directory\TestScript.ps1
            $withPath.Count -eq $withoutPath.Count | Should Be $true
        }

        It "Does not run rules on script with more than 10 parser errors" {
            $moreThanTenErrors = Invoke-ScriptAnalyzer -ErrorAction SilentlyContinue $directory\CSharp.ps1
            $moreThanTenErrors.Count | Should Be 0
        }
    }

    Context "When given a directory" {
        $withoutPathWithDirectory = Invoke-ScriptAnalyzer -Recurse $directory\RecursionDirectoryTest
        $withPathWithDirectory = Invoke-ScriptAnalyzer -Recurse -Path $directory\RecursionDirectoryTest
    
        It "Has the same count as without Path parameter"{
            $withoutPathWithDirectory.Count -eq $withPathWithDirectory.Count | Should Be $true
        }

        It "Analyzes all the files" {
            $globalVarsViolation = $withPathWithDirectory | Where-Object {$_.RuleName -eq "PSAvoidGlobalVars"}
            $clearHostViolation = $withPathWithDirectory | Where-Object {$_.RuleName -eq "PSAvoidUsingClearHost"}
            $writeHostViolation = $withPathWithDirectory | Where-Object {$_.RuleName -eq "PSAvoidUsingWriteHost"}
            Write-Output $globalVarsViolation.Count
            Write-Output $clearHostViolation.Count
            Write-Output $writeHostViolation.Count
            $globalVarsViolation.Count -eq 1 -and $writeHostViolation.Count -eq 1 | Should Be $true
        }

    }
}

Describe "Test ExcludeRule" {
    Context "When used correctly" {
        It "excludes 1 rule" {
            $noViolations = Invoke-ScriptAnalyzer $directory\..\Rules\BadCmdlet.ps1 -ExcludeRule $singularNouns | Where-Object {$_.RuleName -eq $singularNouns}
            $noViolations.Count | Should Be 0
        }

        It "excludes 3 rules" {
            $noViolations = Invoke-ScriptAnalyzer $directory\..\Rules\BadCmdlet.ps1 -ExcludeRule $rules | Where-Object {$rules -contains $_.RuleName}
            $noViolations.Count | Should Be 0 
        }
    }

    Context "When used incorrectly" {
        It "does not exclude any rules" {
            $noExclude = Invoke-ScriptAnalyzer $directory\..\Rules\BadCmdlet.ps1
            $withExclude = Invoke-ScriptAnalyzer $directory\..\Rules\BadCmdlet.ps1 -ExcludeRule "This is a wrong rule"
            $withExclude.Count -eq $noExclude.Count | Should Be $true
        }
    }

    Context "Support wild card" {
        It "supports wild card exclusions of input rules"{
            $excludeWildCard = Invoke-ScriptAnalyzer $directory\..\Rules\BadCmdlet.ps1 -ExcludeRule $avoidRules | Where-Object {$_.RuleName -match $avoidRules}
        }
    }

}

Describe "Test IncludeRule" {
    Context "When used correctly" {
        It "includes 1 rule" {
            $violations = Invoke-ScriptAnalyzer $directory\..\Rules\BadCmdlet.ps1 -IncludeRule $singularNouns | Where-Object {$_.RuleName -eq $singularNouns}
            $violations.Count | Should Be 1
        }

        It "includes 2 rules" {
            $violations = Invoke-ScriptAnalyzer $directory\..\Rules\BadCmdlet.ps1 -IncludeRule $rules | Where-Object {$rules -contains $_.RuleName}
            $violations.Count | Should Be 2
        }
    }

    Context "When used incorrectly" {
        It "does not include any rules" {
            $wrongInclude = Invoke-ScriptAnalyzer $directory\..\Rules\BadCmdlet.ps1 -IncludeRule "This is a wrong rule"
            $wrongInclude.Count | Should Be 0
        }
    }

    Context "IncludeRule supports wild card" {
        It "includes 1 wildcard rule"{
            $includeWildcard = Invoke-ScriptAnalyzer $directory\..\Rules\BadCmdlet.ps1 -IncludeRule $avoidRules
            $includeWildcard.Count | Should be 5
        }

        it "includes 2 wildcardrules" {
            $includeWildcard = Invoke-ScriptAnalyzer $directory\..\Rules\BadCmdlet.ps1 -IncludeRule $avoidRules, $useRules 
            $includeWildcard.Count | Should be 7
        }
    }
}

Describe "Test Exclude And Include" {
    It "Exclude and Include different rules" {
        $violations = Invoke-ScriptAnalyzer $directory\TestScript.ps1 -IncludeRule "PSAvoidUsingEmptyCatchBlock" -ExcludeRule "PSAvoidUsingPositionalParameters"
        $violations.Count | Should be 1
    }

    It "Exclude and Include the same rule" {
        $violations = Invoke-ScriptAnalyzer $directory\TestScript.ps1 -IncludeRule "PSAvoidUsingEmptyCatchBlock" -ExcludeRule "PSAvoidUsingEmptyCatchBlock"
        $violations.Count | Should be 0
    }
}

Describe "Test Severity" {
    Context "When used correctly" {
        It "works with one argument" {
            $errors = Invoke-ScriptAnalyzer $directory\TestScript.ps1 -Severity Information
            $errors.Count | Should Be 0
        }

        It "works with 2 arguments" {
            $errors = Invoke-ScriptAnalyzer $directory\TestScript.ps1 -Severity Information, Warning
            $errors.Count | Should Be 2
        }
    }

    Context "When used incorrectly" {
        It "throws error" {
            { Invoke-ScriptAnalyzer -Severity "Wrong" $directory\TestScript.ps1 } | Should Throw
        }
    }
}

Describe "Test CustomizedRulePath" {
    $measureRequired = "CommunityAnalyzerRules\Measure-RequiresModules"
    Context "When used correctly" {
        It "with the module folder path" {
            $customizedRulePath = Invoke-ScriptAnalyzer $directory\TestScript.ps1 -CustomizedRulePath $directory\CommunityAnalyzerRules | Where-Object {$_.RuleName -eq $measureRequired}
            $customizedRulePath.Count | Should Be 1
        }

        It "with the psd1 path" {
            $customizedRulePath = Invoke-ScriptAnalyzer $directory\TestScript.ps1 -CustomizedRulePath $directory\CommunityAnalyzerRules\CommunityAnalyzerRules.psd1 | Where-Object {$_.RuleName -eq $measureRequired}
            $customizedRulePath.Count | Should Be 1

        }

        It "with the psm1 path" {
            $customizedRulePath = Invoke-ScriptAnalyzer $directory\TestScript.ps1 -CustomizedRulePath $directory\CommunityAnalyzerRules\CommunityAnalyzerRules.psm1 | Where-Object {$_.RuleName -eq $measureRequired}
            $customizedRulePath.Count | Should Be 1
        }

        It "with IncludeRule" {
            $customizedRulePathInclude = Invoke-ScriptAnalyzer $directory\TestScript.ps1 -CustomizedRulePath $directory\CommunityAnalyzerRules\CommunityAnalyzerRules.psm1 -IncludeRule "Measure-RequiresModules"
            $customizedRulePathInclude.Count | Should Be 1
        }

        It "with ExcludeRule" {
            $customizedRulePathExclude = Invoke-ScriptAnalyzer $directory\TestScript.ps1 -CustomizedRulePath $directory\CommunityAnalyzerRules\CommunityAnalyzerRules.psm1 -ExcludeRule "Measure-RequiresModules" | Where-Object {$_.RuleName -eq $measureRequired}
            $customizedRulePathExclude.Count | Should be 0
        }
    }

    Context "When used incorrectly" {
        It "file cannot be found" {
            $wrongRule = Invoke-ScriptAnalyzer $directory\TestScript.ps1 -CustomizedRulePath "This is a wrong rule" 3>&1 | Select-Object -First 1
            $wrongRule | Should Match "Cannot find rule extension 'This is a wrong rule'."
        }
    }
}