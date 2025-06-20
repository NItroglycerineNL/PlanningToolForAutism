#!/bin/bash
##########################################
#                                        #
# Generate HTML page for autism planning #
#                                        #
##########################################
#
# This script is build to generate a planning for 2 children, both with autism.
# The script uses css to organise the data.
# I am no CSS wizard, please feel free to improve and share.
# 
# The logic behind displaying the schema's: 
# 15 minutes before the first activity of the day, the schema HTML is generated announcing the start of the day
# During the day, the current activity is displayed first, followed by the next 4 activities
# The starting time of the next activity is used as end of the previous activity
# When there are less than 4 upcoming activities, the remaining cells are empty
# 5 minutes after the "start" of bedtime the HDMI port is turned off,
# 15 minutes before first activity the screen is turned on
#
#
# The following inputs and settings are expected:
# - Two planning files in the format [time];<filename icon>;<activity>
# - Directory with the icons
# - Permissions to write the HTML file to your webserver HTML location (default /var/www/html)
# - Crontab execution every minute
#
# My current setup: 
# Main location: raspberry pi 4 4GB with raspbian 64, apache2 and large screen television
# Secondary locations: raspberry pi zero 2W with 15" screen 
# The devices are constantly on, hence the black html page during bedtimes.
# The icons and planning files are stored on an external location (Synology NAS share),
# which can easily be accessed with a laptop, tablet or phone for planning modifications.
#
# There is a second script that copies at 1 minute before midnight the default planning back to the current planning,
# so that an  ad-hoc planning changes during the day will be gone next week around.
#
# This script was written for a Dutch environment,
# hence the day's expected in Dutch and some locations are in Dutch as well.
#
#####################################################################
# Date       | Version | Remarks
# -----------+---------+---------------------------------------------
# 30 Mar '25 | 0.1     | Start of initial version
# -----------+---------+---------------------------------------------
# 3 Jun '25  | 1.0     | Official working version
# -----------+---------+---------------------------------------------
#####################################################################
#set -xv

activate () {
    SCREEN="${1}"

    if [ "${SCREEN}" = "main" ]
    then
       WAYLAND_DISPLAY="wayland-1" wlr-randr --output ${CURPORT} --on --mode ${RESOLUTION}
       echo "0" > ${CURHDMI}
    elif [ "${SCREEN}" = "${NAME1}" ]
    then
#       ssh autisme@${IP1} "echo 0 > /home/autisme/HDMI.state"
       echo "" > /dev/null
    elif [ "${SCREEN}" = "${NAME2}" ]
    then
#       ssh autisme@${IP2} "echo 0 > /home/autisme/HDMI.state"
       echo "" > /dev/null
    fi
        
}

deactivate () {
    SCREEN="${1}"

    if [ "${SCREEN}" = "main" ]
    then
       WAYLAND_DISPLAY="wayland-1" wlr-randr --output ${CURPORT} --off
       echo "1" > ${CURHDMI}
    elif [ "${SCREEN}" = "${NAME1}" ]
    then
#       ssh autisme@${IP1} "echo 1 > /home/autisme/HDMI.state"
       echo "" > /dev/null
    elif [ "${SCREEN}" = "${NAME2}" ]
    then
#       ssh autisme@${IP2} "echo 1 > /home/autisme/HDMI.state"
       echo "" > /dev/null
    fi

}

RUNDIR=<PATH TO DIRECTORY WHERE THIS SCRIPT RESIDES>
ICONDIR=<PATH TO WHERE HTML FILE GRABS ITS ICONS FROM, FOR INSTANCE /var/ww/html/images>
MOUNTEDDIR=<PATH TO CENTRAL PLACE WHERE DAILY SCHEDULES ARE STORED - FOR INSTANCE ON A SAMBA SHARE OR NAS SHARED FOLDER>
STANDARDPLANNINGDIR=<PATH TO A CENTRAL PLACE WHERE THE DEFAULT DAILY SCHEDULES ARE STORED - IT IS HANDY IF THIS IS A SUBDIR OF MOUNTEDDIR>
 
CURHDMI=$(cat ${RUNDIR}/HDMI.state)
RESOLUTION="3840x2160"
CURPORT="HDMI-A-2"

CURDAY=$(date '+%A')
NAME1="CHILD1"
NAME1LOW="child1"
NAME2="CHILD2"
NAME2LOW="child2"
#Define IP adresses for remote hosts that shows the planning for remote activation/deactivation of screen
#Do verify if the screen attached to the remote host is able to be controlled from the command line
#This script initiatlly uses WAYLAND for the remote control
IP1="<IP to remote LINUX host 1 that shows planning>"
IP2="<IP to remove Linux host 2 that shows planning>"
SCHEMA1=${RUNDIR}/${CURDAY}_${NAME1}
SCHEMA1DOS=${RUNDIR}/${CURDAY}_${NAME1}.txt
SCHEMA1ZR=${CURDAY}_${NAME1}.txt
SCHEMA2=${RUNDIR}/${CURDAY}_${NAME2}
SCHEMA2DOS=${RUNDIR}/${CURDAY}_${NAME2}.txt
SCHEMA2ZR=${CURDAY}_${NAME2}.txt
TEMPSCHEMA1=${RUNDIR}/SCHEMA1.$$
TEMPSCHEMA2=${RUNDIR}/SCHEMA2.$$
SAVESCHEMA1=${RUNDIR}/SCHEMA1.SAVE
SAVESCHEMA2=${RUNDIR}/SCHEMA2.SAVE
BEDTIME1STATE=$(cat ${RUNDIR}/TIME4BED_${NAME1})
BEDTIME2STATE=$(cat ${RUNDIR}/TIME4BED_${NAME2})

#CSS COLORS
COLORRED="red"
COLORBLUE="blue"
COLORGREEN="green"
COLORPURPLE="purple"
COLORYELLOW="yellow"
COLORWHITE="white"

#Copy the script from the mounted location over the current used one.
#Deactivate this if it is not applicable for your situation
cp ${MOUNTEDDIR}/${SCHEMA1ZR} ${SCHEMA1DOS}
dos2unix -n ${SCHEMA1DOS} ${SCHEMA1} 2>/dev/null 
cp ${MOUNTEDDIR}/${SCHEMA2ZR} ${SCHEMA2DOS}
dos2unix -n ${SCHEMA2DOS} ${SCHEMA2} 2>/dev/null

HTMLDIRMAIN=/var/www/html
HTMLTEMPDIR=${RUNDIR}/html
OUTPUT=index.html
OUTPUTCHILD1=${NAME1LOW}.html
OUTPUTCHILD2=${NAME2LOW}.html
BLANK="blanco.png"

#Put backup files with default values back for further replacements
cp ${HTMLTEMPDIR}/${OUTPUT}.backup ${HTMLTEMPDIR}/${OUTPUT}
cp ${HTMLTEMPDIR}/${OUTPUTCHILD1}.backup ${HTMLTEMPDIR}/${OUTPUTCHILD1}
cp ${HTMLTEMPDIR}/${OUTPUTCHILD2}.backup ${HTMLTEMPDIR}/${OUTPUTCHILD2}

CURTIME=$(expr $(date "+%H") \* 60 + $(date "+%M"))

GETUP1=$(grep "Getup" ${SCHEMA1} | awk -F\; '{print $2}')
GETUP2=$(grep "Getup" ${SCHEMA2} | awk -F\; '{print $2}')

BEDTIME1=$(grep "Time for bed" ${SCHEMA1} | awk -F\; '{print $2}')
BEDTIME2=$(grep "Time for bed" ${SCHEMA1} | awk -F\; '{print $2}')
TIMEMIN10=$(expr ${CURTIME} - 10)
TIMEPLUS5=$(expr ${CURTIME} + 5)
CURRENTTIME=$(date "+%R")

STATEGETUP1=0
STATEGETUP2=0
STATEBEDTIME1=0
STATEBEDTIME2=0

# Determine if it is still bedtime
if [ ${BEDTIME1STATE} -eq 1 ]
then
   # Last reported state is bedtime
   if [ ${GETUP1} -lt ${TIMEMIN10} ] || [ ${BEDTIME1} -gt ${TIMEPLUS5} ]
   then
      # Current time is earlier than 10 minutes before time to get up
      export STATEBEDTIME1=1
   elif [ ${GETUP1} -eq ${TIMEMIN10} ]
   then
      # Current time is exactly 10 minutes before time to get up
      # Activate main screen and child screen
      # Start building webpage schema for child
      activate "main"
      #activate "${NAME1}" 
      export STATEGETUP1=1
      echo 0 > ${RUNDIR}/BEDTIJD_${NAME1}
   fi
else
   # According to state not yet bedtime, check if bedtime was announced 5 minutes ago
   if [ ${BEDTIME1} -eq ${TIMEPLUS5} ]
   then
      #deactivate "${NAME1}"
      export STATEBEDTIME1=1
      echo 1 > ${RUNDIR}/BEDTIJD_${NAME1}
   fi
fi

if [ ${BEDTIME2STATE} -eq 1 ]
then
   # Last reported state is bedtime
   if [ ${GETUP2} -lt ${TIMEMIN10} ] || [ ${BEDTIME2} -gt ${TIMEPLUS5} ]
   then
      # Current time is earlier than 10 minutes before time to get up
      export STATEBEDTIME2=1
   elif [ ${GETUP2} -eq ${TIMEMIN10} ]
   then
      # Current time is exactly 10 minutes before time to get up
      # Activate main screen and child screen
      # Start building webpage schema for child
      activate "main"
      #activate "${NAME2}" 
      export STATEGETUP2=1
      echo 0 > ${RUNDIR}/BEDTIJD_${NAME2}
   fi
else
   # According to state not yet bedtime, check if bedtime was announced 5 minutes ago
   if [ ${BEDTIME2} -eq ${TIMEPLUS5} ]
   then
      #deactivate "${NAME2}"
      export STATEBEDTIME2=1
      echo 1 > ${RUNDIR}/BEDTIJD_${NAME2}
   fi
fi

# Start of a new day. This places the time at the moment of getting up,
# so the first action and its succession actions are displayed.
if [ ${CURTIME} -lt ${GETUP1} ] || [ ${CURTIME} -lt ${GETUP2} ]
then
   if [ ${GETUP1} -ge ${GETUP2} ]
   then
      CURTIME=${GETUP1}
   else
      CURTIME=${GETUP2}
   fi
fi

CURTIMECHILD1=0
CURTIMECHILD2=0

# This routine expects the schema to use a 5 minute activity interval.
# If the current time is not a multiple of 5, it rounds down to the last multiple.
# If the current time is used in the schema, it uses this as first time from the schema, otherwise the rounded down number.

if [ "$(grep ${CURTIME} ${SCHEMA1})" = "" ]
then
   LASTCHAR1="${CURTIME:0-1}"
   if [ ${LASTCHAR1} -lt 5 ]
   then
      export CURTIMECHILD1=$(echo ${CURTIME%?}0)
   else
      export CURTIMECHILD1=$(echo ${CURTIME%?}5)
   fi
else
   export CURTIMECHILD1=${CURTIME}
fi

if [ "$(grep ${CURTIME} ${SCHEMA2})" = "" ]
then
   LASTCHAR2="${CURTIME:0-1}"
   if [ ${LASTCHAR2} -lt 5 ]
   then
      export CURTIMECHILD2=$(echo ${CURTIME%?}0)
   else
      export CURTIMECHILD2=$(echo ${CURTIME%?}5)
   fi
else
   export CURTIMECHILD2=${CURTIME}
fi

# Create snip from schema for quicker walking through
LINEA=$(wc -l ${SCHEMA1}| awk '{print $1}')
LINEB=$(grep -n ${CURTIMECHILD1} ${SCHEMA1} | awk -F\: '{print $1}')
LINENR=$(expr ${LINEA} - ${LINEB} + 1)
COUNTER1=0
touch ${TEMPSCHEMA1}

tail -n ${LINENR} ${SCHEMA1} | while read LINE
do
   TIMESINCEMID=$(echo ${LINE} | awk -F\; '{print $2}')
   PICTO=$(echo ${LINE} | awk -F\; '{print $3}')
   ACTIVITY=$(echo ${LINE} | awk -F\; '{print $4}')
   COLOR=$(echo ${LINE} | awk -F\; '{print $5}')
   if [ "$(echo ${PICTO})" = "" ] && [ ${COUNTER1} = 0 ] && [ ${TIMESINCEMID} -gt ${GETUP1} ]
   then
      #Current found time has no activity. Collect saved one from directory
      cat ${SAVESCHEMA1} >> ${TEMPSCHEMA1}
      let COUNTER1++
   fi
   if [ "$(echo ${PICTO})" != "" ] 
   then
      if [ ${COUNTER1} -eq 0 ]
      then
         if [ ${CURTIME} -gt ${TIMESINCEMID} ]
         then
            TIME="Nu"
         else
            TIME=$(echo ${LINE} | awk -F\; '{print $1}')
         fi
      else
         TIME=$(echo ${LINE} | awk -F\; '{print $1}')
      fi
      PATHANDPICTO="/var/www/html/images/${PICTO}"
      if [ ! -f ${PATHANDPICTO} ]
      then 
         PICTO="NOTFOUND.png"
      fi
      echo "${TIME};${TIMESINCEMID};${PICTO};${ACTIVITY};${COLOR}" >> ${TEMPSCHEMA1}  
      if [ ${COUNTER1} -eq 0 ]
      then
         echo "${TIME};${TIMESINCEMID};${PICTO};${ACTIVITY};${COLOR}" > ${SAVESCHEMA1}  
      fi
      let COUNTER1++
      if [ ${COUNTER1} -eq 7 ]
      then
         break
      fi
   fi
done

# Create snip from schema for quicker walking through
LINEA=$(wc -l ${SCHEMA2}| awk '{print $1}')
LINEB=$(grep -n ${CURTIMECHILD2} ${SCHEMA2} | awk -F\: '{print $1}')
LINENR=$(expr ${LINEA} - ${LINEB} + 1)
COUNTER1=0
touch ${TEMPSCHEMA2}

tail -n ${LINENR} ${SCHEMA2} | while read LINE
do
   TIMESINCEMID=$(echo ${LINE} | awk -F\; '{print $2}')
   PICTO=$(echo ${LINE} | awk -F\; '{print $3}')
   ACTIVITY=$(echo ${LINE} | awk -F\; '{print $4}')
   COLOR=$(echo ${LINE} | awk -F\; '{print $5}')
   if [ "$(echo ${PICTO})" = "" ] && [ ${COUNTER1} = 0 ] && [ ${TIMESINCEMID} -gt ${GETUP2} ]
   then
      #Current found time has no activity. Collect saved one from directory
      cat ${SAVESCHEMA2} >> ${TEMPSCHEMA2}
      let COUNTER1++
   fi
   if [ "$(echo ${PICTO})" != "" ] 
   then
      if [ ${COUNTER1} -eq 0 ]
      then
         if [ ${CURTIME} -gt ${TIMESINCEMID} ]
         then
            TIME="Nu"
         else
            TIME=$(echo ${LINE} | awk -F\; '{print $1}')
         fi
      else
         TIME=$(echo ${LINE} | awk -F\; '{print $1}')
      fi
      PATHANDPICTO="/var/www/html/images/${PICTO}"
      if [ ! -f ${PATHANDPICTO} ]
      then 
         PICTO="NOTFOUND.png"
      fi
      echo "${TIME};${TIMESINCEMID};${PICTO};${ACTIVITY};${COLOR}" >> ${TEMPSCHEMA2}  
      if [ ${COUNTER1} -eq 0 ]
      then
         echo "${TIME};${TIMESINCEMID};${PICTO};${ACTIVITY};${COLOR}" > ${SAVESCHEMA2}  
      fi
      let COUNTER1++
      if [ ${COUNTER1} -eq 7 ]
      then
         break
      fi
   fi
done

#Setting default values to 3 html files
sed -i "s/CURDAY/${CURDAY}/" ${HTMLTEMPDIR}/${OUTPUT}
sed -i "s/CURDAY/${CURDAY}/" ${HTMLTEMPDIR}/${OUTPUTCHILD1}
sed -i "s/CURDAY/${CURDAY}/" ${HTMLTEMPDIR}/${OUTPUTCHILD2}
sed -i "s/CURTIME/${CURRENTTIME}/" ${HTMLTEMPDIR}/${OUTPUT}
sed -i "s/CURTIME/${CURRENTTIME}/" ${HTMLTEMPDIR}/${OUTPUTCHILD1}
sed -i "s/CURTIME/${CURRENTTIME}/" ${HTMLTEMPDIR}/${OUTPUTCHILD2}

#Looping through the temp schemas to replace default values in index.html
COUNTER1=1
if [ $(wc -l ${TEMPSCHEMA1} | awk '{print $1}') -gt 0 ]
then
   cat ${TEMPSCHEMA1} | while read LINE
   do
      TIME=$(echo ${LINE} |  awk -F\; '{print $1}')
      PICTO=$(echo ${LINE} | awk -F\; '{print $3}')
      ACTIVITY=$(echo ${LINE} | awk -F\; '{print $4}')
      COLOR=$(echo ${LINE} | awk -F\; '{print $5}')
      case ${COLOR} in
         R) COLORTOBE=${COLORRED}
         ;;
         B) COLORTOBE=${COLORBLUE}
         ;;
         G) COLORTOBE=${COLORGREEN}
         ;;
         P) COLORTOBE=${COLORPURPLE}
         ;;
         E) COLORTOBE=${COLORYELLOW}
         ;;
         *) COLORTOBE=${COLORWHITE}
         ;;
      esac

      case ${COUNTER1} in
         1)
           if [ "$(echo ${ACTIVITY})" != "" ]
           then
              sed -i "s/CHILD1TIME1/${TIME}/" ${HTMLTEMPDIR}/${OUTPUT} 
              sed -i "s/CHILD1TIME1/${TIME}/" ${HTMLTEMPDIR}/${OUTPUTCHILD1}
              sed -i "s/CHILD1PICTO1/${PICTO}/" ${HTMLTEMPDIR}/${OUTPUT} 
              sed -i "s/CHILD1PICTO1/${PICTO}/" ${HTMLTEMPDIR}/${OUTPUTCHILD1}
              sed -i "s/CHILD1DESC1/${ACTIVITY}/" ${HTMLTEMPDIR}/${OUTPUT} 
              sed -i "s/CHILD1DESC1/${ACTIVITY}/" ${HTMLTEMPDIR}/${OUTPUTCHILD1}
           else
              sed -i "s/CHILD1TIME1//" ${HTMLTEMPDIR}/${OUTPUT} 
              sed -i "s/CHILD1TIME1//" ${HTMLTEMPDIR}/${OUTPUTCHILD1}
              sed -i "s/CHILD1PICTO1/${BLANK}/" ${HTMLTEMPDIR}/${OUTPUT} 
              sed -i "s/CHILD1PICTO1/${BLANK}/" ${HTMLTEMPDIR}/${OUTPUTCHILD1}
              sed -i "s/CHILD1DESC1//" ${HTMLTEMPDIR}/${OUTPUT} 
              sed -i "s/CHILD1DESC1//" ${HTMLTEMPDIR}/${OUTPUTCHILD1}
           fi
           sed -i "s/C101/${COLORTOBE}/" ${HTMLTEMPDIR}/${OUTPUT} 
           sed -i "s/C101/${COLORTOBE}/" ${HTMLTEMPDIR}/${OUTPUTCHILD1} 
         ;;
         2)
           if [ "$(echo ${ACTIVITY})" != "" ]
           then
              sed -i "s/CHILD1TIME2/${TIME}/" ${HTMLTEMPDIR}/${OUTPUT} 
              sed -i "s/CHILD1TIME2/${TIME}/" ${HTMLTEMPDIR}/${OUTPUTCHILD1}
              sed -i "s/CHILD1PICTO2/${PICTO}/" ${HTMLTEMPDIR}/${OUTPUT} 
              sed -i "s/CHILD1PICTO2/${PICTO}/" ${HTMLTEMPDIR}/${OUTPUTCHILD1}
              sed -i "s/CHILD1DESC2/${ACTIVITY}/" ${HTMLTEMPDIR}/${OUTPUT} 
              sed -i "s/CHILD1DESC2/${ACTIVITY}/" ${HTMLTEMPDIR}/${OUTPUTCHILD1}
           else
              sed -i "s/CHILD1TIME2//" ${HTMLTEMPDIR}/${OUTPUT} 
              sed -i "s/CHILD1TIME2//" ${HTMLTEMPDIR}/${OUTPUTCHILD1}
              sed -i "s/CHILD1PICTO2/${BLANK}/" ${HTMLTEMPDIR}/${OUTPUT} 
              sed -i "s/CHILD1PICTO2/${BLANK}/" ${HTMLTEMPDIR}/${OUTPUTCHILD1}
              sed -i "s/CHILD1DESC2//" ${HTMLTEMPDIR}/${OUTPUT} 
              sed -i "s/CHILD1DESC2//" ${HTMLTEMPDIR}/${OUTPUTCHILD1}
           fi
           sed -i "s/C102/${COLORTOBE}/" ${HTMLTEMPDIR}/${OUTPUT} 
           sed -i "s/C102/${COLORTOBE}/" ${HTMLTEMPDIR}/${OUTPUTCHILD1} 
         ;;
         3)
           if [ "$(echo ${ACTIVITY})" != "" ]
           then
              sed -i "s/CHILD1TIME3/${TIME}/" ${HTMLTEMPDIR}/${OUTPUT} 
              sed -i "s/CHILD1TIME3/${TIME}/" ${HTMLTEMPDIR}/${OUTPUTCHILD1}
              sed -i "s/CHILD1PICTO3/${PICTO}/" ${HTMLTEMPDIR}/${OUTPUT} 
              sed -i "s/CHILD1PICTO3/${PICTO}/" ${HTMLTEMPDIR}/${OUTPUTCHILD1}
              sed -i "s/CHILD1DESC3/${ACTIVITY}/" ${HTMLTEMPDIR}/${OUTPUT} 
              sed -i "s/CHILD1DESC3/${ACTIVITY}/" ${HTMLTEMPDIR}/${OUTPUTCHILD1}
           else
              sed -i "s/CHILD1TIME3//" ${HTMLTEMPDIR}/${OUTPUT} 
              sed -i "s/CHILD1TIME3//" ${HTMLTEMPDIR}/${OUTPUTCHILD1}
              sed -i "s/CHILD1PICTO3/${BLANK}/" ${HTMLTEMPDIR}/${OUTPUT} 
              sed -i "s/CHILD1PICTO3/${BLANK}/" ${HTMLTEMPDIR}/${OUTPUTCHILD1}
              sed -i "s/CHILD1DESC3//" ${HTMLTEMPDIR}/${OUTPUT} 
              sed -i "s/CHILD1DESC3//" ${HTMLTEMPDIR}/${OUTPUTCHILD1}
           fi
           sed -i "s/C103/${COLORTOBE}/" ${HTMLTEMPDIR}/${OUTPUT} 
           sed -i "s/C103/${COLORTOBE}/" ${HTMLTEMPDIR}/${OUTPUTCHILD1} 
         ;;
         4)
           if [ "$(echo ${ACTIVITY})" != "" ]
           then
              sed -i "s/CHILD1TIME4/${TIME}/" ${HTMLTEMPDIR}/${OUTPUT} 
              sed -i "s/CHILD1TIME4/${TIME}/" ${HTMLTEMPDIR}/${OUTPUTCHILD1}
              sed -i "s/CHILD1PICTO4/${PICTO}/" ${HTMLTEMPDIR}/${OUTPUT} 
              sed -i "s/CHILD1PICTO4/${PICTO}/" ${HTMLTEMPDIR}/${OUTPUTCHILD1}
              sed -i "s/CHILD1DESC4/${ACTIVITY}/" ${HTMLTEMPDIR}/${OUTPUT} 
              sed -i "s/CHILD1DESC4/${ACTIVITY}/" ${HTMLTEMPDIR}/${OUTPUTCHILD1}
           else
              sed -i "s/CHILD1TIME4//" ${HTMLTEMPDIR}/${OUTPUT} 
              sed -i "s/CHILD1TIME4//" ${HTMLTEMPDIR}/${OUTPUTCHILD1}
              sed -i "s/CHILD1PICTO4/${BLANK}/" ${HTMLTEMPDIR}/${OUTPUT} 
              sed -i "s/CHILD1PICTO4/${BLANK}/" ${HTMLTEMPDIR}/${OUTPUTCHILD1}
              sed -i "s/CHILD1DESC4//" ${HTMLTEMPDIR}/${OUTPUT} 
              sed -i "s/CHILD1DESC4//" ${HTMLTEMPDIR}/${OUTPUTCHILD1}
           fi
           sed -i "s/C104/${COLORTOBE}/" ${HTMLTEMPDIR}/${OUTPUT} 
           sed -i "s/C104/${COLORTOBE}/" ${HTMLTEMPDIR}/${OUTPUTCHILD1} 
         ;;
         5)
           if [ "$(echo ${ACTIVITY})" != "" ]
           then
              sed -i "s/CHILD1TIME5/${TIME}/" ${HTMLTEMPDIR}/${OUTPUT} 
              sed -i "s/CHILD1TIME5/${TIME}/" ${HTMLTEMPDIR}/${OUTPUTCHILD1}
              sed -i "s/CHILD1PICTO5/${PICTO}/" ${HTMLTEMPDIR}/${OUTPUT} 
              sed -i "s/CHILD1PICTO5/${PICTO}/" ${HTMLTEMPDIR}/${OUTPUTCHILD1}
              sed -i "s/CHILD1DESC5/${ACTIVITY}/" ${HTMLTEMPDIR}/${OUTPUT} 
              sed -i "s/CHILD1DESC5/${ACTIVITY}/" ${HTMLTEMPDIR}/${OUTPUTCHILD1}
           else
              sed -i "s/CHILD1TIME5//" ${HTMLTEMPDIR}/${OUTPUT} 
              sed -i "s/CHILD1TIME5//" ${HTMLTEMPDIR}/${OUTPUTCHILD1}
              sed -i "s/CHILD1PICTO5/${BLANK}/" ${HTMLTEMPDIR}/${OUTPUT} 
              sed -i "s/CHILD1PICTO5/${BLANK}/" ${HTMLTEMPDIR}/${OUTPUTCHILD1}
              sed -i "s/CHILD1DESC5//" ${HTMLTEMPDIR}/${OUTPUT} 
              sed -i "s/CHILD1DESC5//" ${HTMLTEMPDIR}/${OUTPUTCHILD1}
           fi
           sed -i "s/C105/${COLORTOBE}/" ${HTMLTEMPDIR}/${OUTPUT} 
           sed -i "s/C105/${COLORTOBE}/" ${HTMLTEMPDIR}/${OUTPUTCHILD1} 
         ;;
         6)
           if [ "$(echo ${ACTIVITY})" != "" ]
           then
              sed -i "s/CHILD1TIME6/${TIME}/" ${HTMLTEMPDIR}/${OUTPUT} 
              sed -i "s/CHILD1TIME6/${TIME}/" ${HTMLTEMPDIR}/${OUTPUTCHILD1}
              sed -i "s/CHILD1PICTO6/${PICTO}/" ${HTMLTEMPDIR}/${OUTPUT} 
              sed -i "s/CHILD1PICTO6/${PICTO}/" ${HTMLTEMPDIR}/${OUTPUTCHILD1}
              sed -i "s/CHILD1DESC6/${ACTIVITY}/" ${HTMLTEMPDIR}/${OUTPUT} 
              sed -i "s/CHILD1DESC6/${ACTIVITY}/" ${HTMLTEMPDIR}/${OUTPUTCHILD1}
           else
              sed -i "s/CHILD1TIME6//" ${HTMLTEMPDIR}/${OUTPUT} 
              sed -i "s/CHILD1TIME6//" ${HTMLTEMPDIR}/${OUTPUTCHILD1}
              sed -i "s/CHILD1PICTO6/${BLANK}/" ${HTMLTEMPDIR}/${OUTPUT} 
              sed -i "s/CHILD1PICTO6/${BLANK}/" ${HTMLTEMPDIR}/${OUTPUTCHILD1}
              sed -i "s/CHILD1DESC6//" ${HTMLTEMPDIR}/${OUTPUT} 
              sed -i "s/CHILD1DESC6//" ${HTMLTEMPDIR}/${OUTPUTCHILD1}
           fi
           sed -i "s/C106/${COLORTOBE}/" ${HTMLTEMPDIR}/${OUTPUT} 
           sed -i "s/C106/${COLORTOBE}/" ${HTMLTEMPDIR}/${OUTPUTCHILD1} 
         ;;
         7)
           if [ "$(echo ${ACTIVITY})" != "" ]
           then
              sed -i "s/CHILD1TIME7/${TIME}/" ${HTMLTEMPDIR}/${OUTPUT} 
              sed -i "s/CHILD1TIME7/${TIME}/" ${HTMLTEMPDIR}/${OUTPUTCHILD1}
              sed -i "s/CHILD1PICTO7/${PICTO}/" ${HTMLTEMPDIR}/${OUTPUT} 
              sed -i "s/CHILD1PICTO7/${PICTO}/" ${HTMLTEMPDIR}/${OUTPUTCHILD1}
              sed -i "s/CHILD1DESC7/${ACTIVITY}/" ${HTMLTEMPDIR}/${OUTPUT} 
              sed -i "s/CHILD1DESC7/${ACTIVITY}/" ${HTMLTEMPDIR}/${OUTPUTCHILD1}
           else
              sed -i "s/CHILD1TIME7//" ${HTMLTEMPDIR}/${OUTPUT} 
              sed -i "s/CHILD1TIME7//" ${HTMLTEMPDIR}/${OUTPUTCHILD1}
              sed -i "s/CHILD1PICTO7/${BLANK}/" ${HTMLTEMPDIR}/${OUTPUT} 
              sed -i "s/CHILD1PICTO7/${BLANK}/" ${HTMLTEMPDIR}/${OUTPUTCHILD1}
              sed -i "s/CHILD1DESC7//" ${HTMLTEMPDIR}/${OUTPUT} 
              sed -i "s/CHILD1DESC7//" ${HTMLTEMPDIR}/${OUTPUTCHILD1}
           fi
           sed -i "s/C107/${COLORTOBE}/" ${HTMLTEMPDIR}/${OUTPUT} 
           sed -i "s/C107/${COLORTOBE}/" ${HTMLTEMPDIR}/${OUTPUTCHILD1} 
         ;;
      esac
      let COUNTER1++
   done
fi
sed -i "s/CHILD1TIME[1234567]//" ${HTMLTEMPDIR}/${OUTPUT} 
sed -i "s/CHILD1TIME[1234567]//" ${HTMLTEMPDIR}/${OUTPUTCHILD1}
sed -i "s/CHILD1PICTO[1234567]/${BLANK}/" ${HTMLTEMPDIR}/${OUTPUT} 
sed -i "s/CHILD1PICTO[1234567]/${BLANK}/" ${HTMLTEMPDIR}/${OUTPUTCHILD1}
sed -i "s/CHILD1DESC[234567]//" ${HTMLTEMPDIR}/${OUTPUT}
sed -i "s/CHILD1DESC[234567]//" ${HTMLTEMPDIR}/${OUTPUTCHILD1}
sed -i "s/C10[1234567]/${COLORWHITE}/g" ${HTMLTEMPDIR}/${OUTPUT}
sed -i "s/C10[1234567]/${COLORWHITE}/g" ${HTMLTEMPDIR}/${OUTPUTCHILD1}
if [ "$(grep CHILD1DESC1 ${HTMLTEMPDIR}/${OUTPUT})" != "" ]
then
   sed -i "s/CHILD1DESC1/Bedtijd/" ${HTMLTEMPDIR}/${OUTPUT}
   sed -i "s/CHILD1DESC1/Bedtijd/" ${HTMLTEMPDIR}/${OUTPUTCHILD1}
fi
 
################

#Looping through the temp schemas to replace default values in index.html
COUNTER2=1
if [ $(wc -l ${TEMPSCHEMA2} | awk '{print $1}') -gt 0 ]
then
   cat ${TEMPSCHEMA2} | while read LINE
   do
      TIME=$(echo ${LINE} |  awk -F\; '{print $1}')
      PICTO=$(echo ${LINE} | awk -F\; '{print $3}')
      ACTIVITY=$(echo ${LINE} | awk -F\; '{print $4}')
      COLOR=$(echo ${LINE} | awk -F\; '{print $5}')
      case ${COLOR} in
         R) COLORTOBE=${COLORRED}
         ;;
         B) COLORTOBE=${COLORBLUE}
         ;;
         G) COLORTOBE=${COLORGREEN}
         ;;
         P) COLORTOBE=${COLORPURPLE}
         ;;
         E) COLORTOBE=${COLORYELLOW}
         ;;
         *) COLORTOBE=${COLORWHITE}
         ;;
      esac

      case ${COUNTER2} in
         1)
           if [ "$(echo ${ACTIVITY})" != "" ]
           then
              sed -i "s/CHILD2TIME1/${TIME}/" ${HTMLTEMPDIR}/${OUTPUT}
              sed -i "s/CHILD2TIME1/${TIME}/" ${HTMLTEMPDIR}/${OUTPUTCHILD2}
              sed -i "s/CHILD2PICTO1/${PICTO}/" ${HTMLTEMPDIR}/${OUTPUT}
              sed -i "s/CHILD2PICTO1/${PICTO}/" ${HTMLTEMPDIR}/${OUTPUTCHILD2}
              sed -i "s/CHILD2DESC1/${ACTIVITY}/" ${HTMLTEMPDIR}/${OUTPUT}
              sed -i "s/CHILD2DESC1/${ACTIVITY}/" ${HTMLTEMPDIR}/${OUTPUTCHILD2}
           else
              sed -i "s/CHILD2TIME1//" ${HTMLTEMPDIR}/${OUTPUT}
              sed -i "s/CHILD2TIME1//" ${HTMLTEMPDIR}/${OUTPUTCHILD2}
              sed -i "s/CHILD2PICTO1/${BLANK}/" ${HTMLTEMPDIR}/${OUTPUT}
              sed -i "s/CHILD2PICTO1/${BLANK}/" ${HTMLTEMPDIR}/${OUTPUTCHILD2}
              sed -i "s/CHILD2DESC1//" ${HTMLTEMPDIR}/${OUTPUT}
              sed -i "s/CHILD2DESC1//" ${HTMLTEMPDIR}/${OUTPUTCHILD2}
           fi
           sed -i "s/C201/${COLORTOBE}/" ${HTMLTEMPDIR}/${OUTPUT} 
           sed -i "s/C201/${COLORTOBE}/" ${HTMLTEMPDIR}/${OUTPUTCHILD2} 
         ;;
         2)
           if [ "$(echo ${ACTIVITY})" != "" ]
           then
              sed -i "s/CHILD2TIME2/${TIME}/" ${HTMLTEMPDIR}/${OUTPUT}
              sed -i "s/CHILD2TIME2/${TIME}/" ${HTMLTEMPDIR}/${OUTPUTCHILD2}
              sed -i "s/CHILD2PICTO2/${PICTO}/" ${HTMLTEMPDIR}/${OUTPUT}
              sed -i "s/CHILD2PICTO2/${PICTO}/" ${HTMLTEMPDIR}/${OUTPUTCHILD2}
              sed -i "s/CHILD2DESC2/${ACTIVITY}/" ${HTMLTEMPDIR}/${OUTPUT}
              sed -i "s/CHILD2DESC2/${ACTIVITY}/" ${HTMLTEMPDIR}/${OUTPUTCHILD2}
           else
              sed -i "s/CHILD2TIME2//" ${HTMLTEMPDIR}/${OUTPUT}
              sed -i "s/CHILD2TIME2//" ${HTMLTEMPDIR}/${OUTPUTCHILD2}
              sed -i "s/CHILD2PICTO2/${BLANK}/" ${HTMLTEMPDIR}/${OUTPUT}
              sed -i "s/CHILD2PICTO2/${BLANK}/" ${HTMLTEMPDIR}/${OUTPUTCHILD2}
              sed -i "s/CHILD2DESC2//" ${HTMLTEMPDIR}/${OUTPUT}
              sed -i "s/CHILD2DESC2//" ${HTMLTEMPDIR}/${OUTPUTCHILD2}
           fi
           sed -i "s/C202/${COLORTOBE}/" ${HTMLTEMPDIR}/${OUTPUT} 
           sed -i "s/C202/${COLORTOBE}/" ${HTMLTEMPDIR}/${OUTPUTCHILD2} 
         ;;
         3)
           if [ "$(echo ${ACTIVITY})" != "" ]
           then
              sed -i "s/CHILD2TIME3/${TIME}/" ${HTMLTEMPDIR}/${OUTPUT}
              sed -i "s/CHILD2TIME3/${TIME}/" ${HTMLTEMPDIR}/${OUTPUTCHILD2}
              sed -i "s/CHILD2PICTO3/${PICTO}/" ${HTMLTEMPDIR}/${OUTPUT}
              sed -i "s/CHILD2PICTO3/${PICTO}/" ${HTMLTEMPDIR}/${OUTPUTCHILD2}
              sed -i "s/CHILD2DESC3/${ACTIVITY}/" ${HTMLTEMPDIR}/${OUTPUT}
              sed -i "s/CHILD2DESC3/${ACTIVITY}/" ${HTMLTEMPDIR}/${OUTPUTCHILD2}
           else
              sed -i "s/CHILD2TIME3//" ${HTMLTEMPDIR}/${OUTPUT}
              sed -i "s/CHILD2TIME3//" ${HTMLTEMPDIR}/${OUTPUTCHILD2}
              sed -i "s/CHILD2PICTO3/${BLANK}/" ${HTMLTEMPDIR}/${OUTPUT}
              sed -i "s/CHILD2PICTO3/${BLANK}/" ${HTMLTEMPDIR}/${OUTPUTCHILD2}
              sed -i "s/CHILD2DESC3//" ${HTMLTEMPDIR}/${OUTPUT}
              sed -i "s/CHILD2DESC3//" ${HTMLTEMPDIR}/${OUTPUTCHILD2}
           fi
           sed -i "s/C203/${COLORTOBE}/" ${HTMLTEMPDIR}/${OUTPUT} 
           sed -i "s/C203/${COLORTOBE}/" ${HTMLTEMPDIR}/${OUTPUTCHILD2} 
         ;;
         4)
           if [ "$(echo ${ACTIVITY})" != "" ]
           then
              sed -i "s/CHILD2TIME4/${TIME}/" ${HTMLTEMPDIR}/${OUTPUT}
              sed -i "s/CHILD2TIME4/${TIME}/" ${HTMLTEMPDIR}/${OUTPUTCHILD2}
              sed -i "s/CHILD2PICTO4/${PICTO}/" ${HTMLTEMPDIR}/${OUTPUT}
              sed -i "s/CHILD2PICTO4/${PICTO}/" ${HTMLTEMPDIR}/${OUTPUTCHILD2}
              sed -i "s/CHILD2DESC4/${ACTIVITY}/" ${HTMLTEMPDIR}/${OUTPUT}
              sed -i "s/CHILD2DESC4/${ACTIVITY}/" ${HTMLTEMPDIR}/${OUTPUTCHILD2}
           else
              sed -i "s/CHILD2TIME4//" ${HTMLTEMPDIR}/${OUTPUT}
              sed -i "s/CHILD2TIME4//" ${HTMLTEMPDIR}/${OUTPUTCHILD2}
              sed -i "s/CHILD2PICTO4/${BLANK}/" ${HTMLTEMPDIR}/${OUTPUT}
              sed -i "s/CHILD2PICTO4/${BLANK}/" ${HTMLTEMPDIR}/${OUTPUTCHILD2}
              sed -i "s/CHILD2DESC4//" ${HTMLTEMPDIR}/${OUTPUT}
              sed -i "s/CHILD2DESC4//" ${HTMLTEMPDIR}/${OUTPUTCHILD2}
           fi
           sed -i "s/C204/${COLORTOBE}/" ${HTMLTEMPDIR}/${OUTPUT} 
           sed -i "s/C204/${COLORTOBE}/" ${HTMLTEMPDIR}/${OUTPUTCHILD2} 
         ;;
         5)
           if [ "$(echo ${ACTIVITY})" != "" ]
           then
              sed -i "s/CHILD2TIME5/${TIME}/" ${HTMLTEMPDIR}/${OUTPUT}
              sed -i "s/CHILD2TIME5/${TIME}/" ${HTMLTEMPDIR}/${OUTPUTCHILD2}
              sed -i "s/CHILD2PICTO5/${PICTO}/" ${HTMLTEMPDIR}/${OUTPUT}
              sed -i "s/CHILD2PICTO5/${PICTO}/" ${HTMLTEMPDIR}/${OUTPUTCHILD2}
              sed -i "s/CHILD2DESC5/${ACTIVITY}/" ${HTMLTEMPDIR}/${OUTPUT}
              sed -i "s/CHILD2DESC5/${ACTIVITY}/" ${HTMLTEMPDIR}/${OUTPUTCHILD2}
           else
              sed -i "s/CHILD2TIME5//" ${HTMLTEMPDIR}/${OUTPUT}
              sed -i "s/CHILD2TIME5//" ${HTMLTEMPDIR}/${OUTPUTCHILD2}
              sed -i "s/CHILD2PICTO5/${BLANK}/" ${HTMLTEMPDIR}/${OUTPUT}
              sed -i "s/CHILD2PICTO5/${BLANK}/" ${HTMLTEMPDIR}/${OUTPUTCHILD2}
              sed -i "s/CHILD2DESC5//" ${HTMLTEMPDIR}/${OUTPUT}
              sed -i "s/CHILD2DESC5//" ${HTMLTEMPDIR}/${OUTPUTCHILD2}
           fi
           sed -i "s/C205/${COLORTOBE}/" ${HTMLTEMPDIR}/${OUTPUT} 
           sed -i "s/C205/${COLORTOBE}/" ${HTMLTEMPDIR}/${OUTPUTCHILD2} 
         ;;
         6)
           if [ "$(echo ${ACTIVITY})" != "" ]
           then
              sed -i "s/CHILD2TIME6/${TIME}/" ${HTMLTEMPDIR}/${OUTPUT}
              sed -i "s/CHILD2TIME6/${TIME}/" ${HTMLTEMPDIR}/${OUTPUTCHILD2}
              sed -i "s/CHILD2PICTO6/${PICTO}/" ${HTMLTEMPDIR}/${OUTPUT}
              sed -i "s/CHILD2PICTO6/${PICTO}/" ${HTMLTEMPDIR}/${OUTPUTCHILD2}
              sed -i "s/CHILD2DESC6/${ACTIVITY}/" ${HTMLTEMPDIR}/${OUTPUT}
              sed -i "s/CHILD2DESC6/${ACTIVITY}/" ${HTMLTEMPDIR}/${OUTPUTCHILD2}
           else
              sed -i "s/CHILD2TIME6//" ${HTMLTEMPDIR}/${OUTPUT}
              sed -i "s/CHILD2TIME6//" ${HTMLTEMPDIR}/${OUTPUTCHILD2}
              sed -i "s/CHILD2PICTO6/${BLANK}/" ${HTMLTEMPDIR}/${OUTPUT}
              sed -i "s/CHILD2PICTO6/${BLANK}/" ${HTMLTEMPDIR}/${OUTPUTCHILD2}
              sed -i "s/CHILD2DESC6//" ${HTMLTEMPDIR}/${OUTPUT}
              sed -i "s/CHILD2DESC6//" ${HTMLTEMPDIR}/${OUTPUTCHILD2}
           fi
           sed -i "s/C206/${COLORTOBE}/" ${HTMLTEMPDIR}/${OUTPUT} 
           sed -i "s/C206/${COLORTOBE}/" ${HTMLTEMPDIR}/${OUTPUTCHILD2} 
         ;;
         7)
           if [ "$(echo ${ACTIVITY})" != "" ]
           then
              sed -i "s/CHILD2TIME7/${TIME}/" ${HTMLTEMPDIR}/${OUTPUT}
              sed -i "s/CHILD2TIME7/${TIME}/" ${HTMLTEMPDIR}/${OUTPUTCHILD2}
              sed -i "s/CHILD2PICTO7/${PICTO}/" ${HTMLTEMPDIR}/${OUTPUT}
              sed -i "s/CHILD2PICTO7/${PICTO}/" ${HTMLTEMPDIR}/${OUTPUTCHILD2}
              sed -i "s/CHILD2DESC7/${ACTIVITY}/" ${HTMLTEMPDIR}/${OUTPUT}
              sed -i "s/CHILD2DESC7/${ACTIVITY}/" ${HTMLTEMPDIR}/${OUTPUTCHILD2}
           else
              sed -i "s/CHILD2TIME7//" ${HTMLTEMPDIR}/${OUTPUT}
              sed -i "s/CHILD2TIME7//" ${HTMLTEMPDIR}/${OUTPUTCHILD2}
              sed -i "s/CHILD2PICTO7/${BLANK}/" ${HTMLTEMPDIR}/${OUTPUT}
              sed -i "s/CHILD2PICTO7/${BLANK}/" ${HTMLTEMPDIR}/${OUTPUTCHILD2}
              sed -i "s/CHILD2DESC7//" ${HTMLTEMPDIR}/${OUTPUT}
              sed -i "s/CHILD2DESC7//" ${HTMLTEMPDIR}/${OUTPUTCHILD2}
           fi
           sed -i "s/C207/${COLORTOBE}/" ${HTMLTEMPDIR}/${OUTPUT} 
           sed -i "s/C207/${COLORTOBE}/" ${HTMLTEMPDIR}/${OUTPUTCHILD2} 
         ;;
      esac
      let COUNTER2++
   done
fi
#No values to show - past bedtime
sed -i "s/CHILD2TIME[1234567]//" ${HTMLTEMPDIR}/${OUTPUT}
sed -i "s/CHILD2TIME[1234567]//" ${HTMLTEMPDIR}/${OUTPUTCHILD2}
sed -i "s/CHILD2PICTO[1234567]/${BLANK}/" ${HTMLTEMPDIR}/${OUTPUT}
sed -i "s/CHILD2PICTO[1234567]/${BLANK}/" ${HTMLTEMPDIR}/${OUTPUTCHILD2}
sed -i "s/CHILD2DESC[234567]//" ${HTMLTEMPDIR}/${OUTPUT}
sed -i "s/CHILD2DESC[234567]//" ${HTMLTEMPDIR}/${OUTPUTCHILD2}
sed -i "s/C20[1234567]/${COLORWHITE}/g" ${HTMLTEMPDIR}/${OUTPUT}
sed -i "s/C20[1234567]/${COLORWHITE}/g" ${HTMLTEMPDIR}/${OUTPUTCHILD2}
if [ "$(grep CHILD2DESC1 ${HTMLTEMPDIR}/${OUTPUT})" != "" ]
then
   sed -i "s/CHILD2DESC1/Bedtijd/" ${HTMLTEMPDIR}/${OUTPUT}
   sed -i "s/CHILD2DESC1/Bedtijd/" ${HTMLTEMPDIR}/${OUTPUTCHILD2}
fi

cp ${HTMLTEMPDIR}/${OUTPUT} ${HTMLDIRMAIN}
cp ${HTMLTEMPDIR}/${OUTPUTCHILD1} ${HTMLDIRMAIN}
cp ${HTMLTEMPDIR}/${OUTPUTCHILD2} ${HTMLDIRMAIN}

rm ${TEMPSCHEMA1} ${TEMPSCHEMA2}

# Put back the default schema for the past day at 23:59
if [ ${CURTIME} -eq 1439 ]
then
   cp ${STANDARDPLANNINGDIR}/${CURDAY}_${NAME1} ${MOUNTEDDIR} 
   cp ${STANDARDPLANNINGDIR}/${CURDAY}_${NAME2} ${MOUNTEDDIR} 
   cp ${STANDARDPLANNINGDIR}/${CURDAY}_${NAME1} ${RUNDIR} 
   cp ${STANDARDPLANNINGDIR}/${CURDAY}_${NAME2} ${RUNDIR} 
   cp ${MOUNTEDDIR}/${SCHEMA1ZR} ${SCHEMA1DOS}
   cp ${MOUNTEDDIR}/${SCHEMA2ZR} ${SCHEMA2DOS}
   dos2unix -n ${SCHEMA1DOS} ${SCHEMA1} 2>/dev/null 
   dos2unix -n ${SCHEMA2DOS} ${SCHEMA2} 2>/dev/null
fi
