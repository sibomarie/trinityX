
######################################################################
# Trinity X
# Copyright (c) 2016  ClusterVision B.V.
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License (included with the sources) for more
# details.
######################################################################


# Setup the /etc/hosts file

# The CentOS installer doesn't update the hosts file for some reason (maybe
# because of multiple interfaces?). We have to do it ourselves or nothing will
# resolve and lots o' stuff will break.

# Display the variables that we will need

display_var HA CTRL{1,2,}_{HOSTNAME,IP} HOSTNAME


#---------------------------------------

# Are we running in an HA pair?
# Are all the values set?
# And on the way, sanitize the value of HA as it will end up in the .sh file

if flag_is_unset HA ; then

    echo_info 'Non-HA configuration, adjusting the hostname and IP variables'
    HA=0

    if flag_is_unset CTRL1_HOSTNAME || flag_is_unset CTRL1_IP; then
        echo_error 'Fatal error: missing hostname or IP value!'
        exit 234
    fi

    CTRL_HOSTNAME=$CTRL1_HOSTNAME
    CTRL_IP=$CTRL1_IP

    unset CTRL2_HOSTNAME CTRL2_IP

else

    echo_info 'HA setup selected'
    HA=1

    if flag_is_unset CTRL_HOSTNAME  || flag_is_unset CTRL_IP  || \
       flag_is_unset CTRL1_HOSTNAME || flag_is_unset CTRL1_IP || \
       flag_is_unset CTRL2_HOSTNAME || flag_is_unset CTRL2_IP ; then
        
        echo_error 'Fatal error: missing hostname or IP value(s)!'
        exit 234
    fi

    if [[ "$CTRL_HOSTNAME"  == "$CTRL1_HOSTNAME" || \
          "$CTRL_HOSTNAME"  == "$CTRL2_HOSTNAME" || \
          "$CTRL1_HOSTNAME" == "$CTRL2_HOSTNAME" || \
          "$CTRL_IP"        == "$CTRL1_IP" || \
          "$CTRL_IP"        == "$CTRL2_IP" || \
          "$CTRL1_IP"       == "$CTRL2_IP" ]] ; then
          
        echo_error 'Fatal error: some of the hostnames or IPs are identical!'
        exit 234
    fi
fi


#---------------------------------------

# Get some information about the current host

hname=$(hostname -s)
fname=$(hostname)
[[ "$hname" == "$fname" ]] && unset fname

# List of active interface / IP pairs

ifips="$(ip -o -4 addr show | awk -F '[ :/]+' '/scope global/ {print $2, $4}')"


#---------------------------------------

# Next thing to check: are we really one of the controllers?

case $hname in

    "${CTRL1_HOSTNAME%.*}" )
        ctrlname="$CTRL1_HOSTNAME"
        ctrlip="$CTRL1_IP"
        ;;

    "${CTRL2_HOSTNAME%.*}" )
        ctrlname="$CTRL2_HOSTNAME"
        ctrlip="$CTRL2_IP"
        ;;

    * )
        echo_error "Fatal error: the current hostname doesn't match any of the controller hostnames!"
        exit 234
esac


#---------------------------------------

# Did the user pass an IP address that doesn't match any of our interfaces?

if ! grep -q " ${ctrlip}$" ; then
    echo_warn "The IP defined in the configuration doesn't match any of this machine's IPs:"
    echo "$ifips"
    echo
fi <<< "$ifips"


# At that point we know that:
# - we are one of the two controllers
# - one of our interfaces has the right IP
# - the floating hostname and IP are not the same as those two

# It might be the case that we have another interface up and with the floating
# IP. Should we detect that and exit? There is a valid case for not doing so: an
# engineer might have set up HA already using a separate interface, and it's up
# and running with the floating IP on our machine. It is very much a corner
# case, but let's assume that the engineer knows what (s)he's doing.


#---------------------------------------

# Loop on the pairs and write to the hosts file

append_line /etc/hosts '#  ----  Trinity machines  ----'

for i in CTRL{1,2} ; do

    # in non-HA setups we must skip CTRL2 entirely
    if flag_is_set ${i}_HOSTNAME ; then

        # The joys of indirection in Bash
        tmpname=${i}_HOSTNAME ; tmpname=${!tmpname}
        tmpip=${i}_IP ; tmpip=${!tmpip}

        if [[ "$ctrlname" == "$tmpname" ]] ; then

            # that's the current machine, so better put in all the interfaces
            while read -a ifip ; do

                if [[ "$ctrlip" == "${ifip[1]}" ]] ; then
                    append_line /etc/hosts "${ifip[1]}  ${fname:+$fname }$hname ${hname}-${ifip[0]}"
                else
                    append_line /etc/hosts "${ifip[1]}  ${hname}-${ifip[0]}"
                fi
            done <<< "$ifips"

        else

            # not our machine, just write the data from the env varibales
            append_line /etc/hosts "$tmpip  $tmpname"
        fi
    fi
done


# And if we're HA, we need to add the floating IP too

flag_is_set HA && append_line /etc/hosts "$CTRL_IP  $CTRL_HOSTNAME"


#---------------------------------------

# And finally, write the environment variables to the trinity.sh file

# We may need to run that script before any form of configuration is done, to
# set up /etc/hosts for the shared storage. In that case the .sh file won't
# exist yet, so don't try to write to it.

if [[ -r /etc/trinity.sh ]] ; then
    source /etc/trinity.sh
    for i in HA CTRL{1,2,}_{HOSTNAME,IP} ; do
        if [[ -v $i ]] ; then
            store_variable "${TRIX_SHFILE}" "TRIX_$i" "${!i}"
        else
            # make sure that we're not picking up background noise
            append_line "${TRIX_SHFILE}" "unset $i TRIX_$i"
        fi
    done
fi

