# Author: Ian Farr (C) 2020
# this file is licensed under the MIT license.

##
#### things you can mess with

# the amount of time the script will "pause" before looking for new save's to backup. Default = 30 (seconds)
$sleepSeconds = 300

# should we backup autosaves? default true
$autoSaves = $true

# should we backup quicksaves? default true
$quickSaves = $true

# should we backup normal saves? default true
$normalSaves = $true

# controls if the companion script (backup_mgmt.ps1) is called to check
#   if there are any backup files that need to be aged out/cleaned up
$ageOutBackups = $false

# controls how many old backup set names we keep
$backupSetNameHistory = 10

##
#### things you shouldn't need to mess with
$x4MyDocRoot = ([Environment]::GetFolderPath('MyDocuments')) + "\Egosoft\X4"

# find the X4 save's folder parent
$x4MyDocRootFolders = Get-ChildItem -Path $x4MyDocRoot

# we choose the first folder under MyDocuments\Egosoft\X4 that has a chilc "save" folder
# this is most likely where all our saves are (Default X4 save location)
# in case this is not where your save folders are, you may have to adjust manually
$x4SaveLocation = $null

# if you set the location of the $x4SaveLocation variable manually
#   please comment our this foreach section
foreach ($folder in $x4MyDocRootFolders) {
    if (Test-Path -Path ($folder.FullName + "\save"))  {
        $x4SaveLocation = $folder.FullName + "\save"
        break
    }
}

##
#### things you should not mess with unless you know what you are doing follow

#####  Functions
<#
.SYNOPSIS
Writes the Backup Set Name cache to disk

.DESCRIPTION
Writes the Backup Set Name cache to disk

.PARAMETER backupSetNames
Parameter a string array containing a list or previous backup set names
#>
function Write-JsonCache {
    Param (
        [Parameter(Mandatory=$true, Position=0)]
        [string[]] $BackupSetNames,
        [Parameter(Mandatory=$true, Position=1)]
        [string] $CacheFileFullPath
    )
    ConvertTo-Json  $BackupSetNames > $CacheFileFullPath
}

##### End Functions

if ($null -eq $x4SaveLocation) {
    Write-Host "Error finding X4 Save folder, you might have to set the '`$x4SaveLocation' variable manually"
    Exit 1
}

$curFolder = (Get-Location).path
$backupFolder = $curFolder + "\backups"
$cacheFile = $backupFolder + "\.cache.json"
$bsnCacheFile = $backupFolder + "\.bsncache.json"

# Make sure that our backup folder exists
if ( -not (Test-Path -Path $backupFolder) ) {
    New-Item -Path $backupFolder -ItemType "Directory" | Out-Null
}

$outerloop = $true
while ($outerloop) {
    $inputloop = $true
    $exit = $false
    $inputLoopError = $false
    # loop forever until we get a clean backup set name, or an exit command
    while ($inputloop) {
        Clear-Host
        Write-Host "Welcome to the X4 auto/quick save backup utility"
        Write-Host "------------------------------------------------"
        Write-Host "Type 'exit' without the quotes to exit"
        Write-Host
        
        # Get Previous Backup Set Name Cache
        # since this only happens on program start on when choosing a new backup set name, we just read it from disk every time we get here
        # this shouldn't cause any IO issues, as it's a manual selection process anyways
        # this way we are sure we have the latest BSN cache as well
        $bsnCacheContent = $null
        if (Test-Path -Path $bsnCacheFile) {
            $bsnCacheContent = Get-Content -Raw -Path $bsnCacheFile | ConvertFrom-Json
        }

        # if there are no Backup Set Name Cache's initialize a new blank array
        if ($null -eq $bsnCacheContent) {
            $bsnCacheContent = @()
        }

        # see if we should display the error text
        if ($inputLoopError) {
            Write-Host -ForegroundColor Red "Note: Backup Set names can only contain alpha numeric text"
            $inputLoopError = $false
        }

        # if we have previous Backup Set Names, display them now
        if ($bsnCacheContent.Length -gt 0) {
            Write-Host
            Write-Host "Backup Set Name History:"
            for ($i=0; $i -lt $bsnCacheContent.Length; $i++) {
                Write-Host -NoNewline -ForegroundColor Green "  $($i+1)  "
                Write-Host -ForegroundColor White "$($bsnCacheContent[$i])"
            }
            Write-Host
        }

        $backupSetName = Read-Host -Prompt 'Enter a new Backup Set Name or numeric Index'
        if ($backupSetName.ToLower() -eq 'exit') {
            $inputloop = $false
            $exit = $true
            continue
        }
        if ($backupSetName -match '[^a-zA-Z0-9 ]') {
            $inputLoopError = $true
            continue
        }
        if ($null -ne $backupSetName -and $backupSetName.Length -gt 0) {
            $inputloop = $false
            
            # if we just have a numeric index, get the corresponding BSN
            if ($backupSetName -match '[0-9]+$') {
                $selectedIndex = [int]$backupSetName - 1
                if ($selectedIndex -lt $bsnCacheContent.Length -and $selectedIndex -ge 0) {
                    $backupSetName = $bsnCacheContent[$selectedIndex]
                }
            }

            # if the new backup set name isn't in the cache, add it and persist the file
            # this is a case insensitive match operation, but will keep the initial case that was entered
            # we prepend the names on the list
            if (-not ($bsnCacheContent -contains $backupSetName) ) {
                $bsnCacheContent = ,$backupSetName + $bsnCacheContent
                if ($bsnCacheContent.Length -gt $backupSetNameHistory) {
                    $tempArr = @()
                    for ($i=0; $i -lt $backupSetNameHistory; $i++) {
                        $tempArr += $bsnCacheContent[$i]
                    }
                    $bsnCacheContent = $tempArr
                }
                Write-JsonCache -BackupSetNames $bsnCacheContent -CacheFileFullPath $bsnCacheFile
            }

            continue
        }
    }

    if ($exit) {
        $outerloop = $false
        continue
    }

    $innerloop = $true
    while ($innerloop) {
        # we detect any changes to the cache file and only re-write if there are changes to it
        $detectChange = $false

        # Get Previous Backup Cache content
        $cacheContent = $null
        if (Test-Path -Path $cacheFile) {
            $cacheContent = Get-Content -Raw -Path $cacheFile | ConvertFrom-Json
        }

        # make sure our cache content looks good
        # fix non-exitent paths, try to recover from directory moves
        if ( $null -ne $cacheContent ) {
            for ( $i=0;$i -lt $cacheContent.Length; $i++ ) {
                # see of the backup path is valid
                $backup = $cacheContent[$i]
                if ( $null -ne $backup.BackedUpFileFullName -and (Test-Path -Path $backup.BackedUpFileFullName) ) {
                    continue
                }
                
                # file is not at the expected location
                # see if we have simply moved backup directories and update accordingly
                if ( Test-Path -Path ($backupFolder + "\" + $backup.BackedUpFileName) ) {
                    $cacheContent[$i].BackedUpFileFullName = $backupFolder + "\" + $backup.BackedUpFileName
                    $detectChange = $true
                } else {
                    # no idea where it is...we tried
                    $cacheContent[$i].BackedUpFileFullName = "missing"
                    $detectChange = $true
                }
            }
        }

        Clear-Host
        Write-Host "Backup Set Name: $backupSetName"
        Write-Host

        $saves = @()

        if ($autoSaves) {
            $saves += Get-ChildItem -Path $x4SaveLocation -Filter "autosave*"
        }
        
        if ($quickSaves) {
            $saves += Get-ChildItem -Path $x4SaveLocation -Filter "quicksave*"
        }

        if ($normalSaves) {
            $saves += Get-ChildItem -Path $x4SaveLocation -Filter "save*"
        }
        
        # regenerate the cache file
        $cache = @()
        
        foreach ($file in $saves) {
            Write-Host "$($file.Name):"
            $curFile = "" | Select-Object Name,FullName,Length,LastWriteTimeUtc,BackedUpFileName,BackedUpFileFullName
            $curFile.Name = $file.Name
            $curFile.FullName = $file.FullName
            $curFile.Length = $file.Length
            $curFile.LastWriteTimeUtc = $file.LastWriteTimeUtc
        
            # check to see if we have this save in our cache
            # if we do, we do not back it up again
            if ( $null -ne $cacheContent ) {
                $match = $false
                $backupName = ""
                $backupFullName = ""
                foreach ( $backup in $cacheContent) {
                    if ($backup.Name -eq $file.Name -and $backup.LastWriteTimeUtc.ToString() -eq $file.LastWriteTimeUtc.ToString() -and $backup.Length -eq $file.Length) {
                        $match = $true
                        $backupName = $backup.BackedUpFileName
                        $backupFullName = $backup.BackedUpFileFullName
                        break
                    }
                }
                # if there is a match, we break out of the $cacheContent foreach loop, and continue with the next $file foreach loop
                if ($match) { 
                    Write-Host "    State: Already Backed Up, Skipping"
                    Write-Host "    Backup Name: $backupName"
                    $curFile.BackedUpFileName = $backupName
                    $curFile.BackedUpFileFullName = $backupFullName
                    $cache += $curFile
                    continue
                }
            }
        
            # there is no cache for this save, back it up
            $saveType = "save"
            if ($file.Name.Contains("quicksave")) {
                $saveType = "quicksave"
            }
            if ($file.Name.Contains("autosave")) {
                $saveType = "autosave"
            }

            # extract the current index details, and append it to saveType

            # quickSave doesn't have an index - there is only one, so we just need to get the save/autosave index
            # quickSave doesn't have an underscore in it's name, so we look for that, which means it's an autosave ot a save
            if ($file.Name.Contains('_')) {
                # $fileNameSplit[0] = autosave_##, save_###
                $fileNameSplit = $file.Name.Split('.')
                
                # $fileNameIndexSplit[0] = autosave, save
                # $fileNameIndexSplit[1] = ## (this is the index we are after)
                $fileNameIndexSplit = $fileNameSplit.Split("_")

                # append the index to saveType
                $saveType += '_' + $fileNameIndexSplit[1]
            }
            
            $destinationName = "$($backupSetName)-" + $file.LastWriteTimeUtc.Year + "." + $("{0:00}" -f ($file.LastWriteTimeUtc.Month)) + "." + $("{0:00}" -f ($file.LastWriteTimeUtc.Day)) + "-" + $("{0:00}" -f ($file.LastWriteTimeUtc.Hour)) + "." + $("{0:00}" -f ($file.LastWriteTimeUtc.Minute)) + "." + $("{0:00}" -f ($file.LastWriteTimeUtc.Second)) + '-' + $saveType + ".xml.gz"
            $destinationFullName = $backupFolder + "\" + $destinationName
            
            if (-not (Test-Path -Path $destinationName)) {
                Copy-Item -Path $curFile.FullName -Destination $destinationFullName
                Write-Host "    State: Not Backed Up"
                Write-Host -ForegroundColor Green "    Backing up to: $destinationName"
                $curFile.BackedUpFileName = $destinationName
                $curFile.BackedUpFileFullName = $destinationFullName
                $detectChange = $true
            } else {
                Write-Host "$destinationFullName already exists...skipping"
            }
            $cache += $curFile
        }
        
        # if there have been changes, record the new cache file
        if ($detectChange) {
            $cache | ConvertTo-Json > $cacheFile
        }

        if ($ageOutBackups) {
            Write-Host
            & $curFolder\backup_mgmt.ps1
        }

        Write-Host
        Write-Host "Press F12 to switch to another backup set name"
        Write-Host "Sleeping for $sleepSeconds seconds..."

        $curSleep = $sleepSeconds
        while ($curSleep -gt 0) {
            Write-Host -NoNewLine "$("{0:000}" -f $curSleep)            "
            $Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates 0,$Host.UI.RawUI.CursorPosition.Y
            $curSleep -= 1
            Start-Sleep -Seconds 1
            if ([console]::KeyAvailable) {
                $key = [System.Console]::ReadKey() 
    
                switch ( $key.key) {
                    F12 { $innerloop = $false; $curSleep = 0 }
                }
            }
        }
    }
}