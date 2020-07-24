# Author: Ian Farr (C) 2020
# this file is licensed under the MIT license.

##
#### things you can mess with
$prevDayBackupFiles = 3 # how many files to keep for the previous days per backup set?
                        # if 1, the most recent file for that day is kept
                        # if 2, then keep the most recent one, and the oldest one for that day
                        # if 3, then keep the most recent one, the oldest one, and one in the middle for that day
                        # if 4+, keep newest, oldest, and backups evenly distributed for that day

$oldDays = 30           # how many previous days to keep for all backup sets?
$deleteAutoSaves = $true    # which save types do we want to cleanup/delete when they age out?
$deleteQuickSaves = $true
$deleteNormalSaves = $false
$maintenanceHours = 12   # an interval in hours; maintenance will be performed every N hours

##
#### things you should not mess with unless you know what you are doing follow
$curFolder = (Get-Location).path
$backupFolder = $curFolder + "\backups"
$maintenanceFile = $backupFolder + "\.maintenance.json"

if (-not (Test-Path -Path $maintenanceFile)) {
    New-Item -Path $maintenanceFile -ItemType "file"
}

$maintenanceContent = Get-Content -Raw -Path $maintenanceFile | ConvertFrom-Json

$performMaintenance = $false
$curDateUTC = (Get-Date).ToUniversalTime()
$curYMD = $curDateUTC.ToString('yyyy-MM-dd')
# if we have a blank maintenance file, then we have never performed maintenance before
# so perform maintenance. If we do have content in the maintenance file then
# check to see if the current time is greater than last time + maintenanceHours interval
# if the delta is greater, then it's time to perform maintenance again
if ($null -eq $maintenanceContent) {
    $performMaintenance = $true
} else {
    $lastmaintenanceDate = $maintenanceContent.Value
    $nextmaintenanceTime = $lastmaintenanceDate + (New-TimeSpan -Hours $maintenanceHours)
    if ( $curDateUTC -gt $nextmaintenanceTime) {
        $performMaintenance = $true
    }
}

# perform our maintenance tasks if it's time
if ($performMaintenance) {
    Write-Host "Maintenance is now being performed..."
    # get all the backup files we have
    $backupFiles = Get-ChildItem -Path $backupFolder -Filter "*.xml.gz"

    # blank hastable to hold the details of all our backup files
    # use use a hashtable for easy indexing when needing to modify item properties
    $backupFilesDetails = @{}

    # find all our backupset names and backup file details
    # index everything into the backupFilesDetails array
    # all decisions will be taken using the backupFilesDetails array that we build here
    Write-Host "    Gathering Backup File Details..."
    foreach ($backup in $backupFiles) {
        $curFileDetail = "" | Select-Object Name,FullName,BackupSet,Date,DateTime,SaveType,Delete
        $curFileDetail.Name = $backup.Name
        $curFileDetail.FullName = $backup.FullName

        # example file name: FRF-autosave_2020.07.22_23.56.55.xml.gz
        #   setSplit[0] = FRF = user defined backup set name
        #   setSplit[1] = autosave_2020.07.22_23.56.55.xml.gz
        $setSplit = $backup.Name.Split("-")
        $curFileDetail.BackupSet = $setSplit[0]

        # saveTypeSplit[0] = autosave = Savetype
        # saveTypeSplit[1] = 2020.07.22 = YYYY.MM.DD
        # saveTypeSplit[2] = 23.56.55.xml.gz = HH.MM.SS.xml.gz
        $saveTypeSplit = $setSplit[1].Split("_")
        $curFileDetail.SaveType = $saveTypeSplit[0]
        
        # to build a date object based on UTC, we first must extract the YYYY.MM.DD and HH.MM.SS portions 
        # from saveTypeSplit[1] and saveTypeSplit[2]
        # dateSplit[0] = 2020 = YYYY
        # dateSplit[1] = 07 = MM
        # dateSplit[2] = 22 = DD
        # timeSplit[0] = 23 = HH
        # timeSplit[1] = 56 = MM
        # timeSplit[2] = 55 = SS
        # timeSplit[3] amd [4] we don't care about (xml, and gz respectively)
        $dateSplit = $saveTypeSplit[1].Split(".")
        $timeSplit = $saveTypeSplit[2].Split(".")
        
        # UniversalSortableDateTimePattern Format = 'YYYY-MM-DD HH:MM:SSZ'
        # Z = Zulu time (UTC)
        $dateString = $dateSplit[0] + '-' + $dateSplit[1] + '-' + $dateSplit[2] + ' '
        $dateString += $timeSplit[0] + ':' + $timeSplit[1] + ':' + $timeSplit[2] + 'Z'
        # build and assign our UTC date object representing the time the file was last updated/backed up
        $curFileDetail.DateTime = ([datetime](Get-Date -Format (Get-Culture).DateTimeFormat.UniversalSortableDateTimePattern -Date $dateString)).ToUniversalTime()
        $curFileDetail.Date = $dateSplit[0] + '-' + $dateSplit[1] + '-' + $dateSplit[2]

        # by default we do not delete
        $curFileDetail.Delete = $false

        # is this file too old? if so mark it for deletion right away
        if ($curFileDetail.Date -lt $curDateUTC - (New-TimeSpan -Days $oldDays) ) {
            if ($curFileDetail.SaveType.ToLower() -eq 'autosave' -and $deleteAutoSaves -eq $true) {
                $curFileDetail.Delete = $true
            }
            if ($curFileDetail.SaveType.ToLower() -eq 'quicksave' -and $deleteQuickSaves -eq $true) {
                $curFileDetail.Delete = $true
            }
            if ($curFileDetail.SaveType.ToLower() -eq 'save' -and $deleteNormalSaves -eq $true) {
                $curFileDetail.Delete = $true
            }
        }

        $backupFilesDetails[$curFileDetail.Name] = $curFileDetail
    }

    # TODO: cleanup all previous days files. Reduce to 1, 2, 3, or more files per day until they age out. 
    #       Use PowerShell Group-Object to loop over the $backupFilesDetails array and group by backup set, save type, and date
    #       then order the backups by time per unique date, choosing the appropriate ones to keep and the rest get flushed

    # First we Group by backup Sets so we can keep backups per backup set
    $backupSets = $backupFilesDetails.Values | Group-Object -Property BackupSet
    foreach ($set in $backupSets) {
        # group by save type. Name is one of: save, autosave, quicksave
        $saveTypes = $set.Group | Group-Object -Property SaveType
        foreach ($saveType in $saveTypes) {
            # test to see if we are configured to delete these save types
            if ($saveType.Name.ToLower() -eq "save" -and $deleteNormalSaves -eq $false) {
                # we are not configured to delete these save types - so skip them
                continue
            }
            if ($saveType.Name.ToLower() -eq "autosave" -and $deleteAutoSaves -eq $false) {
                # we are not configured to delete these save types - so skip them
                continue
            }
            if ($saveType.Name.ToLower() -eq "quicksave" -and $deleteQuickSaves -eq $false) {
                # we are not configured to delete these save types - so skip them
                continue
            }
            
            # if we get here, we are configured to process this save type
            # further group by date
            $saveTypeByDate = $saveType.Group | Group-Object -Property Date
            # loop through all the dates.
            foreach ($day in $saveTypeByDate) {
                # if it's the current date, we just keep them all
                if ($day.Name -eq $curYMD) {
                    continue
                }
                # for any other date, sort them, and keep $prevDayBackupFiles worth
                # if $prevDayBackupFiles = 
                #   1   - keep the most recent one
                #   2   - keep the oldest and the most recent one
                #   3   - Keep the oldest and the most recent one, and another in the middle
                #   4+  - Keep the oldest, newest, and others evenly distributed throughout that day
                $daySorted = $day.Group | Sort-Object -Property DateTime
                
                # days = 1
                # we keep the most recent save, mark all the rest for deletion
                if ($prevDayBackupFiles -eq 1 -and $daySorted.Length -gt $prevDayBackupFiles) {
                    $max = $daySorted.Length - 1
                    for ($i=0; $i -le $max; $i++) {
                        if ($i -lt $max) {
                            $backupFilesDetails[$($daySorted[$i].Name)].Delete = $true
                            $daySorted[$i].Delete = $true
                        }
                    }
                }

                # days = 2
                # we keep the most recent save, and oldest save, mark all the rest for deletion
                if ($prevDayBackupFiles -eq 2 -and $daySorted.Length -gt $prevDayBackupFiles) {
                    $max = $daySorted.Length - 1
                    for ($i=0; $i -le $max; $i++) {
                        if ($i -gt 0 -and $i -lt $max) {
                            $backupFilesDetails[$($daySorted[$i].Name)].Delete = $true
                        }
                    }
                }

                # days = 3 or more
                # if days = 3 then we keep the most recent save, and oldest save, and the middle one
                # if days = 4+, then we keep the most recent, oldest, and others evenly distributed throughout the array/day
                if ($prevDayBackupFiles -ge 3 -and $daySorted.Length -gt $prevDayBackupFiles) {
                    $max = $daySorted.Length
                    # figure out the middle
                    if ($max % 2 -eq 0) {
                        $middle = [int]$max/2
                    } else {
                        $middle = [int]([math]::truncate($max/2)+1)
                    }
                    
                    # build our center indexes we will keep
                    $indexesToKeep = @()
                    # we always keep the first element (oldest) and the last element (newest)
                    $indexesToKeep += 0
                    $indexesToKeep += $max - 1
                    if ( $prevDayBackupFiles -eq 3 ) {
                        # 3 backups per day were specified, so we just take the middle one
                        $indexesToKeep += $middle
                    } else {
                        # we have more than 3 backups per day to save
                        # we take the size of the array - 2 (because we always take the first and last)
                        # we then divide that by prevDayBackupFiles -2 (because we always take the first and last)
                        # that becomes our base index which we keep (rounded to nearest int). 
                        # we also use the base to increment our index value which let's us skip through the array
                        # taking evenly distributed indexes which are rounded - and we add to the $indexesToKeep array
                        # we delete all other indexes
                        $baseIndex = ( ($max - 2) / ($prevDayBackupFiles - 2))
                        # minus one off the base Index because array indexes are 0 based
                        $base = $baseIndex - 1
                        while ($base -lt ($max-1) -and $indexesToKeep.Length -le $prevDayBackupFiles) {
                            $candidateIndex = [int]([math]::round($base))
                            if (-not $indexesToKeep.Contains($candidateIndex)) {
                                $indexesToKeep += $candidateIndex
                            }
                            $base += $baseIndex
                        }
                    }

                    # mark all our entries for deletion except for oldest, newest, and our indexesToKeep
                    for ($i=0; $i -lt $max; $i++) {
                        if (-not $indexesToKeep.Contains($i)) {
                            $backupFilesDetails[$($daySorted[$i].Name)].Delete = $true
                            #$daySorted[$i].Delete = $true
                        }
                    }
                }
            }
        }
    }

    Write-Host "    Now Deleting Old Backup Files..."
    $backupFilesDetails.Values | Where-Object {$_.Delete -eq $true} | ForEach-Object { Write-Host "      Deleting $($_.Name)"; Remove-Item -Path $_.FullName -Force }

    Write-Host "Maintenance Completed"
    Write-Host
    $curDateUTC | ConvertTo-Json > $maintenanceFile
} else {
    Write-Host "No Maintenance needed, it's not time yet.."
}