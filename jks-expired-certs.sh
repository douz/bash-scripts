#!/bin/bash

#Declare initial variables
CURRENT_YEAR=`date '+%Y'`
CURRENT_MONTH=`date '+%m'`
CURRENT_DAY=`date '+%d'`

#Display command usage function##
exit_usage () {
    cat <<EOF
    COMMAND USAGE
    $0 -k keystore_path -p keystore_password

    Author: Douglas Barahona - douglas.barahona@me.com
EOF
    exit 1
}

#read and process arguments
while getopts ":k:p:" opt
do
    case $opt in
        k ) KEYSTORE=$OPTARG ;;
        p ) STORE_PASS=$OPTARG ;;
        \? ) echo "Invalid option -$OPTARG"
            exit_usage ;;
        : ) echo "Option -$OPTARG requires an argument"
            exit_usage ;;
    esac
done

#Display usage if no options specified
if ((OPTIND==1)) ; then
    exit_usage
fi

shift $((OPTIND-1))

#Validate if keystore and password options where provided
if [ -z "$KEYSTORE" ] || [ -z "$STORE_PASS" ] ; then
    echo "You need to providad a keystore and its password"
    exit_usage
fi

#Validate if the keystore can be access
keytool -list -keystore "${KEYSTORE}" -storepass "${STORE_PASS}" 2>&1 > /dev/null
if [ $? -gt 0 ] ; then
    echo "Error opening the keystore"
    exit 1
fi

#Get certificates list from keystore
CERTS_LIST=`keytool -list -v -keystore "${KEYSTORE}" -storepass "${STORE_PASS}" | grep "Alias name" | awk '{print $3}'`

#Loop through certificate list
for CERT_ALIAS in $CERTS_LIST ; do
    EXPIRATION_YEAR=`keytool -list -v -keystore "${KEYSTORE}" -storepass "${STORE_PASS}" -alias "${CERT_ALIAS}" | grep "until" | awk '{print $15}'`
    EXPIRATION_MONTH=`keytool -list -v -keystore "${KEYSTORE}" -storepass "${STORE_PASS}" -alias "${CERT_ALIAS}" | grep "until" | awk '{print $11}'`
    EXPIRATION_DAY=`keytool -list -v -keystore "${KEYSTORE}" -storepass "${STORE_PASS}" -alias "${CERT_ALIAS}" | grep "until" | awk '{print $12}'`

    #Convert EXPIRATION_MONTH to number
    case $EXPIRATION_MONTH in
        Jan) EXPIRATION_MONTH=01 ;;
        Feb) EXPIRATION_MONTH=02 ;;
        Mar) EXPIRATION_MONTH=03 ;;
        Apr) EXPIRATION_MONTH=04 ;;
        May) EXPIRATION_MONTH=05 ;;
        Jun) EXPIRATION_MONTH=06 ;;
        Jul) EXPIRATION_MONTH=07 ;;
        Aug) EXPIRATION_MONTH=08 ;;
        Sep) EXPIRATION_MONTH=09 ;;
        Oct) EXPIRATION_MONTH=10 ;;
        Nov) EXPIRATION_MONTH=11 ;;
        Dec) EXPIRATION_MONTH=12 ;;
    esac

    #True if expiration Year and Month are lower/equal than current
    if [ ${EXPIRATION_YEAR} -le ${CURRENT_YEAR} ] && [ ${EXPIRATION_MONTH} -le ${CURRENT_MONTH} ] ; then
        #True if expiration month is lower than current or expiration month is equal to current and expiration day is lower/equal than current
        if [ ${EXPIRATION_MONTH} -lt ${CURRENT_MONTH} ] || ([ ${EXPIRATION_MONTH} -eq ${CURRENT_MONTH} ] && [ ${EXPIRATION_DAY} -le ${CURRENT_DAY} ]) ; then
            echo "Alias: $CERT_ALIAS Expired on $EXPIRATION_MONTH $EXPIRATION_DAY, $EXPIRATION_YEAR"
        fi
    fi

done