﻿# this is a Pester test file

#Region Further Reading
  # http://www.powershellmagazine.com/2014/03/27/testing-your-powershell-scripts-with-pester-assertions-and-more/
#End Region
#Region LoadScript
  # load the script file into memory
  # attention: make sure the script only contains function definitions
  # and no active code. The entire script will be executed to load
  # all functions into memory
  . ($PSCommandPath -replace '\.tests\.ps1$', '.ps1')
#End region

# describes the function Get-PSGalleryModule
Describe 'Get-PSGalleryModule' {

  # scenario 1: call the function without arguments
  Context 'Running without arguments'   {
    # test 1: it does not throw an exception:
    It 'runs without errors' {
      # Gotcha: to use the "Should Not Throw" assertion,
      # make sure you place the command in a 
      # ScriptBlock (braces):
      { Get-PSGalleryModule } | Should Not Throw
    }
    It 'does something' {
      # call function Get-PSGalleryModule and pipe the result to an assertion
      # Example:
      # Get-PSGalleryModule | Should Be 'Expected Output'
      # Hint: 
      # Once you typed "Should", press CTRL+J to see
      # available code snippets. You can also click anywhere
      # inside a "Should" and press CTRL+J to change assertion.
      # However, make sure the module "Pester" is
      # loaded to see the snippets. If the module is not loaded yet,
      # no snippets will show.
    }
    # test 2: it returns nothing ($null):
    It 'does not return anything'     {
      Get-PSGalleryModule | Should BeNullOrEmpty 
    }
  }
}
