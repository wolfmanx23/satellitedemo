########################valida host vs WDC

#!/bin/bash

###########
# Validation on controla plane
############
sudo yum install ntpdate -y
sudo yum install telnet -y
sudo yum install -y nc

TIMEOUT=5
REMOTEPORT=443

for REMOTEHOST in 169.63.123.154 169.60.13.162 52.117.93.26
        do
          	echo "************************Validations for REMOTE HOST: ${REMOTEHOST}"
                REMOTEPORT=443

                ping  $REMOTEHOST -c 5 -q

                if nc -w $TIMEOUT -z $REMOTEHOST $REMOTEPORT; then
                    echo "I was able to connect to ${REMOTEHOST}:${REMOTEPORT}"
                else
                    echo "Connection to ${REMOTEHOST}:${REMOTEPORT} failed. Exit code from Netcat was ($?)."
                fi

        done
for REMOTEHOST in 169.63.123.154 169.60.13.162 52.117.93.26
        do
                echo "************************Validations for REMOTE HOST: ${REMOTEHOST}"
                echo " Note: if appears a message, there is an active UDP connection"

                for REMOTEPORT in {30000..32767}
                do
                        echo "Status for UDP port: ${REMOTEPORT}"
                        netstat -a | grep REMOTEPORT
                done
        done



REMOTEHOST=s3.us.cloud-object-storage.appdomain.cloud
REMOTEPORT=443
echo "************************Validations for REMOTE HOST: ${REMOTEHOST}"

if nc -w $TIMEOUT -z $REMOTEHOST $REMOTEPORT; then
   echo "I was able to connect to ${REMOTEHOST}:${REMOTEPORT}"
else
   echo "Connection to ${REMOTEHOST}:${REMOTEPORT} failed. Exit code from Netcat was ($?)."
fi
for REMOTEHOST in 169.54.80.106 169.54.126.219 169.53.167.50 169.53.171.210 52.117.88.42 169.47.162.130
        do
                echo "************************Validations for REMOTE HOST: ${REMOTEHOST}"
                REMOTEPORT=443

                ping  $REMOTEHOST -c 5 -q

                if nc -w $TIMEOUT -z $REMOTEHOST $REMOTEPORT; then
                    echo "I was able to connect to ${REMOTEHOST}:${REMOTEPORT}"
                else
                    echo "Connection to ${REMOTEHOST}:${REMOTEPORT} failed. Exit code from Netcat was ($?)."
                fi

        done

REMOTEHOST=iam.bluemix.net
REMOTEPORT=443

echo "************************Validations for REMOTE HOST: ${REMOTEHOST}"
if nc -w $TIMEOUT -z $REMOTEHOST $REMOTEPORT; then
   echo "I was able to connect to ${REMOTEHOST}:${REMOTEPORT}"
else
   echo "Connection to ${REMOTEHOST}:${REMOTEPORT} failed. Exit code from Netcat was ($?)."
fi


REMOTEHOST=iam.cloud.ibm.com
REMOTEPORT=443

if nc -w $TIMEOUT -z $REMOTEHOST $REMOTEPORT; then
   echo "I was able to connect to ${REMOTEHOST}:${REMOTEPORT}"
else
   echo "Connection to ${REMOTEHOST}:${REMOTEPORT} failed. Exit code from Netcat was ($?)."
fi

for REMOTEHOST in 169.60.112.74 169.55.109.114 169.62.3.82
        do
          	echo "************************Validations for REMOTE HOST: ${REMOTEHOST}"
                for REMOTEPORT in 443 6443
                        do
                          	ping -c 3 -q $REMOTEHOST $REMOTEPORT

                                if nc -w $TIMEOUT -z $REMOTEHOST $REMOTEPORT; then
                                        echo "I was able to connect to ${REMOTEHOST}:${REMOTEPORT}"
                                else
                                    	echo "Connection to ${REMOTEHOST}:${REMOTEPORT} failed. "
                                        echo "Exit code from Netcat was ($?)."
                                fi
                        done

        done
for REMOTEHOST in 169.61.98.203 169.47.34.203 169.60.121.243
        do
          	echo "************************Validations for REMOTE HOST: ${REMOTEHOST}"
                for REMOTEPORT in 443 80
                        do
                          	echo ">>>>>>>>>>>>> Validations for PORT: ${REMOTEPORT}"

                                if nc -w $TIMEOUT -z $REMOTEHOST $REMOTEPORT; then
                                        echo "I was able to connect to ${REMOTEHOST}:${REMOTEPORT}"
                                else
                                    	echo "Connection to ${REMOTEHOST}:${REMOTEPORT} failed."
                                        echo "Exit code from Netcat was ($?)."
                                fi
                        done

        done

########################################
## Cloud Flare validation
########################################

echo "************************ CLOUD FLARE VALIDATIONS ************************"
for REMOTEHOST in 103.21.244 103.22.200 103.31.4 104.16.0 104.24.0 108.162.192 131.0.72.0 141.101.64 162.158.0
do

        for REMOTENODE in {1..255}
        do
          	for REMOTEPORT in 443 80
            do
            	echo "************************Validations for REMOTE HOST: $REMOTEHOST.$REMOTENODE $REMOTEPORT ***********"

                  if nc -w $TIMEOUT -z $REMOTEHOST.$REMOTENODE $REMOTEPORT; then
                          echo "I was able to connect to  $REMOTEHOST.$REMOTENODE:$REMOTEPORT"
                  else
                        echo "Connection to ${REMOTEHOST}:${REMOTENODE}:${REMOTEPORT} failed."
                          echo "Exit code from Netcat was ($?)."
                  fi
            done
      done
done

########################################
# NTP Validation
########################################

echo "************************ NTP VALIDATIONS ************************"

 ntpdate -q 0.rhel.pool.ntp.org
 ntpdate -q 1.rhel.pool.ntp.org
 ntpdate -q 2.rhel.pool.ntp.org
 ntpdate -q 3.rhel.pool.ntp.org

echo "********************** UDP Validation for 123 Port ******************"
netstat -a | grep 123

for REMOTEHOST in 0.rhel.pool.ntp.org 1.rhel.pool.ntp.org 2.rhel.pool.ntp.org 3.rhel.pool.ntp.org
        do
          	echo "************************Validations for REMOTE HOST: ${REMOTEHOST}"
                echo " Note: if appears a message, there is an active UDP connection"
                REMOTEPORT=123
                        echo "Status for UDP port: 4${REMOTEPORT}"
                        netstat -a | grep $REMOTEPORT
        done
