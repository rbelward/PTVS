# PyVot
# Copyright(c) Microsoft Corporation
# All rights reserved.
# 
# Licensed under the Apache License, Version 2.0 (the License); you may not use
# this file except in compliance with the License. You may obtain a copy of the
# License at http://www.apache.org/licenses/LICENSE-2.0
# 
# THIS CODE IS PROVIDED ON AN  *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS
# OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION ANY
# IMPLIED WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR PURPOSE,
# MERCHANTABLITY OR NON-INFRINGEMENT.
# 
# See the Apache Version 2.0 License for specific language governing
# permissions and limitations under the License.

<#
.SYNOPSIS
    Builds Pyvot and runs its tests in the requested interpreter version(s)
.EXAMPLE
    Test-Pyvot.ps1 3.2
.EXAMPLE
	Test-Pyvot.ps1 (3.2, 2.7)
.NOTES
    This script must reside alongside Find-Python.ps1 inside the Pyvot source root
	The current working directory does not matter.
#>

param ([string[]] $interpreterVersions = ("3.2", "2.7"))

$ErrorActionPreference = "Stop";

function Test-Pyvot() {
	param ( [ValidateScript({Test-Path $_})] 
			[string] $pythondir,
			[ValidatePattern('[23].\d')]
			[string] $version)

	function log() { process { write-host $_ -foregroundcolor green; } }

	$python = Join-Path $pythondir "python.exe";
	"Using Python interpreter at $python" | log;
	
	$is_py3 = $version -match "3.\d";
	"`tPython 3: $is_py3" | log;
	
	if ($is_py3) { $build_dir = ".\build-py3"; } else { $build_dir = ".\build-py2"; }
	"Building python source into $build_dir\lib" | log
	if (-not (test-path -PathType leaf "setup.py")) { throw "This script must be located in the Pyvot source root"; }
	& $python setup.py build_py
	if (-not $?) { throw "setup.py failed with code $LastExitCode; check output above"; }
	if (-not (test-path -PathType container "$build_dir\lib\xl")) { throw "setup.py should have put the 'xl' package in $build_dir\lib"; }

	"Copying test suite to $build_dir" | log
	if (test-path -PathType container "$build_dir\test") { rm -recurse -force "$build_dir\test" }
	copy-item -Recurse -Container .\test $build_dir;

	if ($is_py3) {
		"Running 2to3 on tests" | log
		& $python $pythondir"\Tools\Scripts\2to3.py" -w "$build_dir\test\TestXl.py";
		if (-not $?) { throw "2to3 conversion failed"; }
	} else {
		"Skipping 2to3 conversion (2.x interpreter)" | log;
	}

	"Starting tests" | log
	$env:PYTHONPATH = ".\build-py3\lib\";
	& $python "$build_dir\test\TestXl.py";
	if (-not $?) { throw "Tests failed"; }

	"Tests passed (interpreter: $python)" | log

}

Set-Location (Split-Path ($MyInvocation.MyCommand.Path))
. .\Find-Python.ps1
$interpreterVersions |% { Test-Pyvot (Find-Python-InstallPath $_) $_ };