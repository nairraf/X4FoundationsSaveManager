
# X4 Foundations Save Manager

The purpose of X4 Foundation Save Manager is to automatically back-up your saves files. X4 Foundations will keep a single copy of each save type:

* autosave
* quicksave
* save (normal save)

Whenever a save is initiated, it simply overwrites the save of that type. It's up to you to manage the save files so that you can go back in time shoud something get corrupt. This is what happened to me once, so this idea was born so that I wouldn't have to do anything manually. This script simply executes in a loop, and looks for any new saves that need to be backed up, and then backs it up for you using a naming convention which will make it easier for you to see what it was should you ever want to revert to that save. 

This script is in no way affiliated with X4 foundations and/or egosoft.

## Features

The Save Manager is a powershell script that executes in the background and uses extremely little CPU and compares any existing save files with what has already been backed up using the last modified time of the save file, and simply backs up any saves files that change. It can exist anywhere on your system, this way you can easily decide where the backups are stored. It is suggested to use a large HDD to store all your backups, it is not nescesary to store these on an SSD.

* when executed, runs forever in the background in a loop.
* You can define how long the script will sleep before executing the next loop to look for any new save files to backup
* has a concept of "Backup Sets" that let you "tag" the save files with whatever you want to help identify those save files
  * Backup Set Names are defined at runtime. The save manager will prompt you to enter one before it does anything
  * You can easily change the Backup Set Names without terminating and re-launching. Simply Press F12 while this script is sleeping and you can enter a new tag. This way should you want to switch to another playthrough, you can tag that playthrough differently to easily identify which backups are for which playthroughs. 
* each backup has the following naming convention:
  * <tag>-<savetype>_YYYY.MM.DD_HH.MM.SS.xml.gz
  * Example: FRFPlaythough-autosave_2020.07.14_22.37.56.xml.gz
    * 'FRFPlaythough' is a user defined tag specified at runtime. 
* easy installation, just copy to any directory on your system, and as long as your save files are in the default location (My Documents\EgoSoft\X4\######\save), then the script should be able to auto-locate the save files, and auto-detect the current directory. Backups will be placed in a subfolder of whatever dierctory you placed the script in. It does not need to reside in the X4 "save" folder
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
  * By Default Normal Saves (saves) are not aged, but this can be chaned in the script easily
  * all auto/quick/normal saves are kept for the current day - however many are detected and backed up
  * after the current day according to UTC time, then saves are aged out according to the settings that can be defined in the backup_mgmt.ps1 script
  * You can choose how many saves should be kept per day per savetype per backup set. By default this is 3. Possible values:
    * 1: just the most recent one of each previous day per savetype per backup set is kept
    * 2: the most recent one and the oldest one of each previous day per savetype per backup set is kept
    * 3: the most recent, the oldest, and the one closest to the middle of each previous day per savetype per backup set is kept
    * 4+: like 3, but more saves are kept between the middle and oldest/newest. Right now the logic is to work it's way outward in each direction starting from the middle, but I plan to change this.
  * It will attempt to keep the configured amount of files as long as there are enough files to do so, If there isn't enough files to action in (fewer than the configured amount to keep), then it simply keeps the existing files.
  * All files per configured savetype will age out according to the global setting.

  ## Installation

  Simply copy the scripts to any directory of your choosing anywhere on your system, and the backups will be placed in a "backups" subdirectory that will be created on the first runtime.