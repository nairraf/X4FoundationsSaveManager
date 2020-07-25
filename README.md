
# X4 Foundations Save Manager

The purpose of X4 Foundation Save Manager is to automatically back-up your saves files. X4 Foundations will keep a single copy of each save type, with the exception of autosave, which rotates between 3 autosaves:

* autosave
* quicksave
* save (normal save)

Whenever a save is initiated, it simply overwrites the save of that type. It's up to you to manage the save files so that you can go back in time shoud something get corrupt. This is what happened to me once, so this idea was born so that I wouldn't have to do anything manually. This script simply executes in a loop, and looks for any new saves that need to be backed up, and then backs it up for you using a naming convention which will make it easier for you to see what it was should you ever want to revert to that save. 

This script is in no way affiliated with X4 foundations and/or egosoft.

## Overview

The Save Manager is a powershell script that executes in the background and uses extremely little CPU and compares any existing save files with what has already been backed up using the last modified time and size of the save file, and simply backs up any saves files that change. It can exist anywhere on your system, this way you can easily decide where the backups are stored. It is suggested to use a large HDD to store all your backups, it is not nescesary to store these on an SSD.

## Features

* when executed, runs forever in the background in a loop.
* You can define how long the script will sleep before executing the next loop to look for any new save files to backup
  * By default the script will sleep for 300 seconds (5 minutes) between each loop
* has a concept of "Backup Sets" that let you "tag" the save files with whatever you want to help identify those save files
  * Backup Set Names are defined at runtime. The save manager will prompt you to enter one before it does anything
  * You can easily change the Backup Set Names without terminating and re-launching. Simply Press F12 while this script is sleeping and you can enter a new tag. This way should you want to switch to another playthrough, you can tag that playthrough differently to easily identify which backups are for which playthroughs. 
* each backup has the following naming convention:
  * `<tag>`-YYYY.MM.DD-HH.MM.SS-`<savetype>_<Index##>`.xml.gz
  * Example: FRF Payback-2020.05.05-03.45.30-save_001.xml.gz
    * 'FRF Payback' is a user defined tag specified at runtime. 
* easy installation, just copy to any directory on your system, and as long as your save files are in the default location (My Documents\EgoSoft\X4\######\save), then the script should be able to auto-locate the save files, and auto-detect the current directory. Backups will be placed in a subfolder of whatever dierctory you placed the script in. It does not need to reside in the X4 "save" folder, in fact it is recommended that you don't do this, but you can if you want.
* All times are tracked in UTC, and nothing should be locale dependant, so should work on any windows 10 installation
  * Locals Tested so far:
    * English-US
    * English-CA
    * French-CA
    * English-UK
* Has a companion script that will age out the backups according to a few rules:
  * Max lifetime in days for any backup
  * which savetypes will it auto-age out files for. By default it will only age out:
    * autosaves
    * quicksaves
    * Normal Saves (saves)
      * By Default normal saves are not aged, but this can be chaned in the script easily
  * all auto/quick/normal saves are kept for the current day - however many are detected and backed up
  * after the current day according to UTC time, then, if enabled, saves are aged out according to the settings that can be defined in the backup_mgmt.ps1 script
    * By default all aging out is disabled. you must manually enable this. By manually enabling this setting you are agreeing to the fact that saves will be deleted from your system. Once deleted, they are gone. Please read the configuration section so that you understand and are comfortable with enabling this setting.
    * You can choose how many saves should be kept per day per savetype per backup set. By default this is 3. Possible values:
      * 1: just the most recent one of each previous day per savetype per backup set is kept
      * 2: the most recent one and the oldest one of each previous day per savetype per backup set is kept
      * 3: the most recent, the oldest, and the one closest to the middle of each previous day per savetype per backup set is kept
        * this is the default setting
      * 4+: the most recent and the oldest are kept. All other saves for that day and savetype and set are then sorted by time and backups evenly distributed throughout that day/set are selected to be saved.
        * Example: let's imagine that there are 23 autosaves for a backup set called "ARG", and you have configured things to keep 5 backups. The followng backups are kept
          * the oldest (first backup of that day according to UTC date/time)
          * the newest (the last backup of that day according to UTC date/time)
          * the algorithm will then devide the remaining backups (21) by the amount of backups desired to keep (5-2 (because we already kept the oldest and newest) = 3 in this case) and then skips through the backups in chronological order selecting the appropriate indexes (21/3 (rounded to the closes integer if needed) = 7), so backups at indexes 6, 13, 20 will also be kept (index 6 is the 7'th save for that day). While the algorithm does a few extra things to try and make sure it can accomodate multiple scenarios (not all division is clean, like it is in this example), that's the general idea of what it does and how it selects backups to keep. The idea is to get samples of your backups throughout the day and a sort-of even way. In this case you end up having two saves close together at the end of the day (20 and 22), but depending on the amount of saves available, and the desired number of backups to keep, things will change.
  * All files per configured savetype will age out according to the global setting.

## Installation

Simply copy the scripts to any directory of your choosing anywhere on your system, and the backups will be placed in a "backups" subdirectory that will be created on the first runtime.

## Configuration

### backup_saves.ps1

This is the main script that is responsible for backing up the saves. At the top of the script you will see a few variables that can be tweaked to your liking:

```powershell
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
```

### backup_mgmt.ps1

This is the script that is responsible for aging out backups. If `$ageOutBackups` is set to true, then the following options are used to control which backups are aged out and deleted. Note: that if you enable `$ageOutBackups` that you are agreeing to the fact that backup files will be deleted from your computer with no way of retreiving them once they have been deleted.

The following options are available:
```powershell
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
```

`$maintenanceHours` is used to control how often the aging of backups is run. This way it is not called all the time needlessly saving those valuable CPU cycles, even though it's not very CPU intensive at all. With many backups it be more memory and disk intensive, but shouldn't be too heavy, as many hundreds of backup files have been tested and an HDD handles it easily.

## Running the Scripts

You can execute the `backup_save.ps1` through powershell, or you can just click on the included batch file `X4 Foundations Save Manager.bat` which will do that for you, and also set the powershell execution policy just for this powershell process only. *Note:* it will not change the powershell execution policy at the system level, whatever you have that set to. If you don't know that the execution policy does, then the batch file method might be the better way to go for you.

## Screenshots

Please checkout the [screenshots](screenshots) for a step-by-step walk through of how the scripts work.

[screenshots/01-Welcome-BackupSetName.png](Initial Welcome Screen)

## License

This Project is licensed under the MIT License - see [LICENSE](LICENSE)

## Privacy

This script does not collect any information, and does not send any information to any sources. All information it gathers is kept locally on your computer in the backup folder that will get created when it's run. There are two files which you can examine to see what king of information is collected:

* backups\.cache.json
* backups\.maintenance.json

The `.maintenance.json` file is only created if the maintenance (`$ageOutBackups`) is enabled. If these files are deleted, they will be re-created whenever you run the program. Please note that if the `.cache.json` file is deleted, then all the saves will be re-backed up, as the script will think this is the first time it has run. 