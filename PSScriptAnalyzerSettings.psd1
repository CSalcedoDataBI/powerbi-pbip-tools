@{
    # PSScriptAnalyzer settings for this repo.
    # Used by .github/workflows/validate.yml and runnable locally:
    #   Invoke-ScriptAnalyzer -Path skills -Recurse -Settings PSScriptAnalyzerSettings.psd1

    IncludeDefaultRules = $true

    ExcludeRules = @(
        # The scripts here are interactive CLI tools whose whole job is printing a
        # color report to a human at a terminal, so Write-Host is deliberate.
        #
        # It is NOT harmless, though: Write-Host writes to the information stream,
        # which means the output cannot be captured with a plain 2>&1 — that silently
        # broke tests/smoke-test.ps1 while it was being written, and the test now needs
        # *>&1 to work at all. Anything that wants to consume these scripts
        # programmatically hits the same wall.
        #
        # Excluded here so the one real warning is not buried under seven of these.
        # Tracked separately for a proper fix (Write-Output / Write-Information).
        'PSAvoidUsingWriteHost'
    )
}
