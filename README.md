# PlanningToolForAutism

Welcome to the Planning Tool for Autism repository.
As a father (with autism as well) of 2 lovely children, both with their own challenges due to their autism, we use icons a lot to structure the days and to offer predictability. 
Creating a new planning every day is a big task, especially when done by hand. Searching for a method to help with the planning, I came across a lot of commercial planning tools. 
They have their own spot on their own merits, but the ones I scanned didn't offer the way we planned by hand. To ease our children into the new planning method, as little changes to the current way of working are needed.

As an IT professional I use to write some bash scripts to automate tasks for my clients. I set on a path to use my professional knowledge for this project. I am no professional 
programmer or coder, and I only know bash. I assume other languages (like perl of C) would create a better / more slick / faster program, but I have to work with the tools I have 
at my disposal.

The bash program creates three html pages - a main page with the schedules for both children and a page for each child on their own. It is currently running on a raspberry pi 4 
and takes about 8 seconds to run, every minute by the crontab. The program uses several input files, temporary files and storage files to keep track of the schedules. 
For schedules Windows formatted text files are used - they are translated to unix files before opening. Therefor special characters and accents are not advised to use. 
The program is written in such a way that it expects an (external) storage location for the schedules. For this I have used a samba share on our NAS. On this storage location 
a list of all the schedules - one for each day for each child - is stored: one as a working copy and one as the original schedule. The "working copy" one is checked against the 
local copy of this file on the raspberry pi and when it is altered since the last run it is copied over the local one and transcoded by dos2unix to remove the end of line characters. 
At the end of the day, the original schedule is copied over the working copy, ready for a new week. With this method you can change the schedule on the fly - changes will be visible
in a minute after saving - and allow for small modifications on day-to-day basis (say a doctor’s appointment). If you want the changes to be saved for future schedules, also modify the original schedule.

The schedule is built with a 5 minute interval with an increment minute from midnight-timeline. Minute by minute planning is possible, it does require the correct number of minutes since midnight.

The program is written to display a schedule for two children. If you want to alter this, a good look at the css file to have the html formatted properly. The html shows the current
and a maximum of 6 upcoming tasks along with a appropriate icon. I only provide 1 icon with the program, the icon used when the icon the task is linking to can't be found. 
A good source for free icons for these schedules is the site of sclera.be by the URL sclera.be/nl/picto/downloads. I have no affiliation with this website or company; I just downloaded my icons from there.
A limit of the current way of working is that the previous task is no longer visible once the time for the new task has reached. This might cause confusion or worse.
The program is currently tested and run in our home environment, experiences and feature requests will be implemented into the code in future versions.

The program can display 6 different colors by default: white (default), red, blue, green, yellow and purple, the background of the html is black. If you want to change the background, alter the css file.
Also make sure to alter the default color in case it becomes unreadable.

Feel free to adapt the program for your own situation, if you make improvements that you feel like sharing with the world upload it to your code sharing solution of choice or send it by mail 
to autisme @ famvanginkel . nl . This address can also be used for questions, spam or commercial outreach is not appreciated.
The files are all provided under the GNU GPLv3 license. Distribution of closed source versions are prohibited by such.


